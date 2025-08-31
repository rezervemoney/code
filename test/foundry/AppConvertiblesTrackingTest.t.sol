// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../contracts/core/AppConvertibles.sol";
import "../../contracts/core/AppAccessControlled.sol";
import "../../contracts/core/AppAuthority.sol";
import "../../contracts/core/AppOracle.sol";
import "../../contracts/core/AppTreasury.sol";
import "../../contracts/core/RZR.sol";
import "../../contracts/interfaces/IOracleV2.sol";
import "../../contracts/mocks/MockERC20.sol";
import "../../contracts/mocks/MockOracle.sol";
import "../../contracts/mocks/MockOracleV2.sol";
import "../../contracts/mocks/MockEndpoint.sol";

contract AppConvertiblesTrackingTest is Test {
    AppConvertibles public convertibles;
    AppAuthority public authority;
    AppOracle public appOracle;
    AppTreasury public treasury;
    RZR public rzr;
    MockERC20 public usdc;
    MockERC20 public weth;
    MockOracleV2 public twapOracle;

    address public governor = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public user3 = address(0x4);

    uint256 public constant USDC_AMOUNT = 1000e6;
    uint256 public constant WETH_AMOUNT = 10e18;
    uint256 public constant LOCK_DURATION = 365 days;

    event Staked(
        address indexed receiver,
        uint256 indexed tokenId,
        uint256 amount,
        uint256 conversionAmount,
        uint256 lockDuration,
        uint256 price,
        uint256 conversionPrice,
        uint256 fixedInterestRate
    );

    event Converted(
        address indexed user, uint256 indexed tokenId, uint256 amountStaked, uint256 conversionAmount, uint256 twapPrice
    );

    event Redeemed(
        address indexed user,
        uint256 indexed tokenId,
        uint256 amountStaked,
        uint256 conversionAmount,
        uint256 interestAccumulated
    );

    event PositionSplit(
        address indexed user,
        uint256 indexed originalTokenId,
        uint256 indexed newTokenId,
        uint256 originalAmountStaked,
        uint256 splitAmountStaked,
        uint256 originalConvertibleAmount,
        uint256 splitConvertibleAmount,
        uint256 percentageE18
    );

    event PositionTransferred(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId,
        uint256 stakingPower,
        uint256 amountConvertible
    );

    function setUp() public {
        // Deploy mock tokens
        usdc = new MockERC20("USDC", "USDC");
        weth = new MockERC20("Wrapped ETH", "WETH");

        vm.warp(block.timestamp + 10 days);

        // Set decimals for mock tokens
        usdc.setDecimals(6);
        weth.setDecimals(18);

        // Deploy mock oracles
        twapOracle = new MockOracleV2(0, 1e18, address(usdc));

        // Deploy authority
        authority = new AppAuthority();

        MockEndpoint lz = new MockEndpoint();

        // Deploy RZR token
        rzr = new RZR(address(lz), address(authority));

        // Deploy treasury
        treasury = new AppTreasury();

        // Deploy app oracle
        appOracle = new AppOracle();

        // Deploy convertibles
        convertibles = new AppConvertibles();

        // Initialize contracts
        treasury.initialize(address(rzr), address(appOracle), address(authority));
        appOracle.initialize(address(authority), address(rzr));
        convertibles.initialize(address(rzr), address(appOracle), address(twapOracle), address(authority));

        // Set up roles - use grantRole instead of setGovernor
        // vm.startPrank(address(authority));
        authority.grantRole(authority.GOVERNOR_ROLE(), governor);
        authority.grantRole(authority.GUARDIAN_ROLE(), governor);
        authority.grantRole(authority.POLICY_ROLE(), governor);
        authority.grantRole(authority.RESERVE_MANAGER_ROLE(), governor);
        authority.grantRole(authority.EXECUTOR_ROLE(), governor);
        // vm.stopPrank();

        // Update AppOracle with the pre-configured oracle
        appOracle.updateOracle(address(usdc), address(twapOracle), 1 days);
        appOracle.updateOracle(address(weth), address(twapOracle), 1 days);

        // Enable tokens in convertibles
        vm.startPrank(governor);
        convertibles.enableToken(
            usdc,
            0.05e18, // 5% min conversion premium
            0.2e18, // 20% max conversion premium
            0.05e18, // 5% min fixed interest rate
            0.15e18, // 15% max fixed interest rate
            1000000e6 // 1M USDC debt cap
        );

        convertibles.enableToken(
            weth,
            0.05e18, // 5% min conversion premium
            0.2e18, // 20% max conversion premium
            0.05e18, // 5% min fixed interest rate
            0.15e18, // 15% max fixed interest rate
            10000e18 // 10K WETH debt cap
        );
        vm.stopPrank();

        // Mint tokens to users
        usdc.mint(user1, USDC_AMOUNT * 10);
        usdc.mint(user2, USDC_AMOUNT * 10);
        usdc.mint(user3, USDC_AMOUNT * 10);
        weth.mint(user1, WETH_AMOUNT * 10);
        weth.mint(user2, WETH_AMOUNT * 10);
        weth.mint(user3, WETH_AMOUNT * 10);

        // Approve convertibles contract
        vm.startPrank(user1);
        usdc.approve(address(convertibles), type(uint256).max);
        weth.approve(address(convertibles), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        usdc.approve(address(convertibles), type(uint256).max);
        weth.approve(address(convertibles), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user3);
        usdc.approve(address(convertibles), type(uint256).max);
        weth.approve(address(convertibles), type(uint256).max);
        vm.stopPrank();
    }

    function test_StakeTrackingTokensMatch() public {
        vm.startPrank(user1);

        // Get initial balances
        uint256 initialUsdcBalance = usdc.balanceOf(user1);
        uint256 initialStakingPowerBalance = convertibles.stakingPowerToken().balanceOf(user1);
        uint256 initialRzrTrackingBalance = convertibles.rzrTrackingToken().balanceOf(user1);
        uint256 initialTrackingTokenBalance = convertibles.variables(usdc).trackingToken.balanceOf(user1);

        // Stake USDC
        (uint256 tokenId,, uint256 conversionAmount,,, uint256 stakingPower) =
            convertibles.stake(usdc, USDC_AMOUNT, LOCK_DURATION, user1);

        // Verify tracking token balances match position values
        assertEq(
            convertibles.stakingPowerToken().balanceOf(user1),
            initialStakingPowerBalance + stakingPower,
            "Staking power token balance mismatch"
        );

        assertEq(
            convertibles.rzrTrackingToken().balanceOf(user1),
            initialRzrTrackingBalance + conversionAmount,
            "RZR tracking token balance mismatch"
        );

        assertEq(
            convertibles.variables(usdc).trackingToken.balanceOf(user1),
            initialTrackingTokenBalance + USDC_AMOUNT,
            "USDC tracking token balance mismatch"
        );

        // Verify position data matches tracking tokens
        AppConvertibles.Position memory position = convertibles.positions(tokenId);
        assertEq(position.stakingPower, stakingPower, "Position staking power mismatch");
        assertEq(position.amountConvertible, conversionAmount, "Position convertible amount mismatch");
        assertEq(position.amountStaked, USDC_AMOUNT, "Position staked amount mismatch");

        vm.stopPrank();
    }

    function test_ConvertTrackingTokensMatch() public {
        vm.startPrank(user1);

        // Stake USDC first
        (uint256 tokenId,, uint256 conversionAmount,,, uint256 stakingPower) =
            convertibles.stake(usdc, USDC_AMOUNT, LOCK_DURATION, user1);

        // Get balances before conversion
        uint256 balanceBeforeStakingPower = convertibles.stakingPowerToken().balanceOf(user1);
        uint256 balanceBeforeRzrTracking = convertibles.rzrTrackingToken().balanceOf(user1);
        uint256 balanceBeforeUsdcTracking = convertibles.variables(usdc).trackingToken.balanceOf(user1);
        uint256 balanceBeforeRzr = rzr.balanceOf(user1);

        // Wait for minimum bond duration
        vm.warp(block.timestamp + 8 days);

        // Set TWAP price above conversion price to allow conversion
        (uint256 conversionPrice,,) = convertibles.getOfferings(usdc, USDC_AMOUNT, LOCK_DURATION);
        twapOracle.setPrice(0, conversionPrice + 1e18);

        // Convert position
        convertibles.convert(tokenId);

        // Verify tracking tokens are burned correctly
        assertEq(
            convertibles.stakingPowerToken().balanceOf(user1),
            balanceBeforeStakingPower - stakingPower,
            "Staking power token not burned correctly"
        );

        assertEq(
            convertibles.rzrTrackingToken().balanceOf(user1),
            balanceBeforeRzrTracking - conversionAmount,
            "RZR tracking token not burned correctly"
        );

        assertEq(
            convertibles.variables(usdc).trackingToken.balanceOf(user1),
            balanceBeforeUsdcTracking - USDC_AMOUNT,
            "USDC tracking token not burned correctly"
        );

        // Verify RZR tokens are minted
        assertEq(rzr.balanceOf(user1), balanceBeforeRzr + conversionAmount, "RZR tokens not minted correctly");

        vm.stopPrank();
    }

    function test_RedeemTrackingTokensMatch() public {
        vm.startPrank(user1);

        // Stake USDC first
        (uint256 tokenId,, uint256 conversionAmount,,, uint256 stakingPower) =
            convertibles.stake(usdc, USDC_AMOUNT, LOCK_DURATION, user1);

        // Get balances before redemption
        uint256 balanceBeforeStakingPower = convertibles.stakingPowerToken().balanceOf(user1);
        uint256 balanceBeforeRzrTracking = convertibles.rzrTrackingToken().balanceOf(user1);
        uint256 balanceBeforeUsdcTracking = convertibles.variables(usdc).trackingToken.balanceOf(user1);
        uint256 balanceBeforeUsdc = usdc.balanceOf(user1);

        // Wait for lock duration to complete
        vm.warp(block.timestamp + LOCK_DURATION + 1);

        // Redeem position
        convertibles.redeem(tokenId);

        // Verify tracking tokens are burned correctly
        assertEq(
            convertibles.stakingPowerToken().balanceOf(user1),
            balanceBeforeStakingPower - stakingPower,
            "Staking power token not burned correctly on redemption"
        );

        assertEq(
            convertibles.rzrTrackingToken().balanceOf(user1),
            balanceBeforeRzrTracking - conversionAmount,
            "RZR tracking token not burned correctly on redemption"
        );

        assertEq(
            convertibles.variables(usdc).trackingToken.balanceOf(user1),
            balanceBeforeUsdcTracking - USDC_AMOUNT,
            "USDC tracking token not burned correctly on redemption"
        );

        // Verify USDC is returned with interest
        uint256 interestAccumulated = _calculateInterest(USDC_AMOUNT, 0.15e18, LOCK_DURATION);
        assertEq(
            usdc.balanceOf(user1),
            balanceBeforeUsdc + USDC_AMOUNT + interestAccumulated,
            "USDC not returned with interest correctly"
        );

        vm.stopPrank();
    }

    function test_SplitTrackingTokensMatch() public {
        vm.startPrank(user1);

        // Stake USDC first
        (uint256 tokenId,, uint256 conversionAmount,,, uint256 stakingPower) =
            convertibles.stake(usdc, USDC_AMOUNT, LOCK_DURATION, user1);

        // Get balances before split
        uint256 balanceBeforeStakingPower = convertibles.stakingPowerToken().balanceOf(user1);
        uint256 balanceBeforeRzrTracking = convertibles.rzrTrackingToken().balanceOf(user1);
        uint256 balanceBeforeUsdcTracking = convertibles.variables(usdc).trackingToken.balanceOf(user1);

        // Split position 50/50
        uint256 splitPercentage = 0.5e18;
        convertibles.split(tokenId, splitPercentage);

        // Get new token ID
        uint256 newTokenId = convertibles.lastId();

        // Verify original position tracking tokens are reduced
        AppConvertibles.Position memory originalPosition = convertibles.positions(tokenId);
        assertEq(
            originalPosition.stakingPower,
            stakingPower * (1e18 - splitPercentage) / 1e18,
            "Original position staking power not reduced correctly"
        );

        assertEq(
            originalPosition.amountConvertible,
            conversionAmount * (1e18 - splitPercentage) / 1e18,
            "Original position convertible amount not reduced correctly"
        );

        assertEq(
            originalPosition.amountStaked,
            USDC_AMOUNT * (1e18 - splitPercentage) / 1e18,
            "Original position staked amount not reduced correctly"
        );

        // Verify new position tracking tokens are correct
        AppConvertibles.Position memory newPosition = convertibles.positions(newTokenId);
        assertEq(
            newPosition.stakingPower, stakingPower * splitPercentage / 1e18, "New position staking power not correct"
        );

        assertEq(
            newPosition.amountConvertible,
            conversionAmount * splitPercentage / 1e18,
            "New position convertible amount not correct"
        );

        assertEq(
            newPosition.amountStaked, USDC_AMOUNT * splitPercentage / 1e18, "New position staked amount not correct"
        );

        // Verify total tracking token balances remain the same
        assertEq(
            convertibles.stakingPowerToken().balanceOf(user1),
            balanceBeforeStakingPower,
            "Total staking power token balance changed after split"
        );

        assertEq(
            convertibles.rzrTrackingToken().balanceOf(user1),
            balanceBeforeRzrTracking,
            "Total RZR tracking token balance changed after split"
        );

        assertEq(
            convertibles.variables(usdc).trackingToken.balanceOf(user1),
            balanceBeforeUsdcTracking,
            "Total USDC tracking token balance changed after split"
        );

        vm.stopPrank();
    }

    function test_TransferTrackingTokensMatch() public {
        vm.startPrank(user1);

        // Stake USDC first
        (uint256 tokenId,, uint256 conversionAmount,,, uint256 stakingPower) =
            convertibles.stake(usdc, USDC_AMOUNT, LOCK_DURATION, user1);

        // Get balances before transfer
        uint256 user1StakingPowerBefore = convertibles.stakingPowerToken().balanceOf(user1);
        uint256 user1RzrTrackingBefore = convertibles.rzrTrackingToken().balanceOf(user1);
        uint256 user1UsdcTrackingBefore = convertibles.variables(usdc).trackingToken.balanceOf(user1);

        uint256 user2StakingPowerBefore = convertibles.stakingPowerToken().balanceOf(user2);
        uint256 user2RzrTrackingBefore = convertibles.rzrTrackingToken().balanceOf(user2);
        uint256 user2UsdcTrackingBefore = convertibles.variables(usdc).trackingToken.balanceOf(user2);

        // Transfer position to user2
        convertibles.transferFrom(user1, user2, tokenId);

        // Verify tracking tokens are transferred correctly
        assertEq(
            convertibles.stakingPowerToken().balanceOf(user1),
            user1StakingPowerBefore - stakingPower,
            "User1 staking power token not transferred correctly"
        );

        assertEq(
            convertibles.rzrTrackingToken().balanceOf(user1),
            user1RzrTrackingBefore - conversionAmount,
            "User1 RZR tracking token not transferred correctly"
        );

        assertEq(
            convertibles.variables(usdc).trackingToken.balanceOf(user1),
            user1UsdcTrackingBefore - USDC_AMOUNT,
            "User1 USDC tracking token not transferred correctly"
        );

        assertEq(
            convertibles.stakingPowerToken().balanceOf(user2),
            user2StakingPowerBefore + stakingPower,
            "User2 staking power token not received correctly"
        );

        assertEq(
            convertibles.rzrTrackingToken().balanceOf(user2),
            user2RzrTrackingBefore + conversionAmount,
            "User2 RZR tracking token not received correctly"
        );

        assertEq(
            convertibles.variables(usdc).trackingToken.balanceOf(user2),
            user2UsdcTrackingBefore + USDC_AMOUNT,
            "User2 USDC tracking token not received correctly"
        );

        // Verify position ownership changed
        assertEq(convertibles.ownerOf(tokenId), user2, "Position ownership not transferred");

        vm.stopPrank();
    }

    function test_TotalConvertibleTracking() public {
        vm.startPrank(user1);

        // Get initial total convertible
        uint256 initialTotalConvertible = convertibles.totalConvertible();

        // Stake USDC
        (uint256 tokenId1,, uint256 conversionAmount1,,,) = convertibles.stake(usdc, USDC_AMOUNT, LOCK_DURATION, user1);

        // Verify total convertible increased
        assertEq(
            convertibles.totalConvertible(),
            initialTotalConvertible + conversionAmount1,
            "Total convertible not increased after stake"
        );

        // Stake more USDC
        (uint256 tokenId2,, uint256 conversionAmount2,,,) = convertibles.stake(usdc, USDC_AMOUNT, LOCK_DURATION, user1);

        // Verify total convertible increased again
        assertEq(
            convertibles.totalConvertible(),
            initialTotalConvertible + conversionAmount1 + conversionAmount2,
            "Total convertible not increased after second stake"
        );

        // Convert first position
        vm.warp(block.timestamp + 8 days);
        (uint256 conversionPrice,,) = convertibles.getOfferings(usdc, USDC_AMOUNT, LOCK_DURATION);
        twapOracle.setPrice(0, conversionPrice + 1e18);
        convertibles.convert(tokenId1);

        // Verify total convertible decreased
        assertEq(
            convertibles.totalConvertible(),
            initialTotalConvertible + conversionAmount2,
            "Total convertible not decreased after conversion"
        );

        // Redeem second position
        vm.warp(block.timestamp + LOCK_DURATION + 1);
        convertibles.redeem(tokenId2);

        // Verify total convertible decreased to initial value
        assertEq(
            convertibles.totalConvertible(),
            initialTotalConvertible,
            "Total convertible not reset to initial value after redemption"
        );

        vm.stopPrank();
    }

    function test_MultipleTokensTracking() public {
        vm.startPrank(user1);

        // Stake USDC
        (uint256 usdcTokenId,, uint256 usdcConversionAmount,,, uint256 usdcStakingPower) =
            convertibles.stake(usdc, USDC_AMOUNT, LOCK_DURATION, user1);

        // Stake WETH
        (uint256 wethTokenId,, uint256 wethConversionAmount,,, uint256 wethStakingPower) =
            convertibles.stake(weth, WETH_AMOUNT, LOCK_DURATION, user1);

        // Verify USDC tracking tokens
        assertEq(
            convertibles.variables(usdc).trackingToken.balanceOf(user1),
            USDC_AMOUNT,
            "USDC tracking token balance incorrect"
        );

        // Verify WETH tracking tokens
        assertEq(
            convertibles.variables(weth).trackingToken.balanceOf(user1),
            WETH_AMOUNT,
            "WETH tracking token balance incorrect"
        );

        // Verify combined staking power
        assertEq(
            convertibles.stakingPowerToken().balanceOf(user1),
            usdcStakingPower + wethStakingPower,
            "Combined staking power incorrect"
        );

        // Verify combined RZR tracking tokens
        assertEq(
            convertibles.rzrTrackingToken().balanceOf(user1),
            usdcConversionAmount + wethConversionAmount,
            "Combined RZR tracking tokens incorrect"
        );

        vm.stopPrank();
    }

    function test_InterestClaimingTracking() public {
        vm.startPrank(user1);

        // Stake USDC
        (uint256 tokenId,,,,,) = convertibles.stake(usdc, USDC_AMOUNT, LOCK_DURATION, user1);

        // Get initial balances
        uint256 initialUsdcBalance = usdc.balanceOf(user1);
        uint256 initialTrackingTokenBalance = convertibles.variables(usdc).trackingToken.balanceOf(user1);

        // Wait some time and claim interest
        vm.warp(block.timestamp + 180 days);

        (uint256 interestClaimed,) = convertibles.claimInterest(tokenId);

        // Verify USDC balance increased by interest
        assertEq(
            usdc.balanceOf(user1),
            initialUsdcBalance + interestClaimed,
            "USDC balance not increased by claimed interest"
        );

        // Verify tracking token balance unchanged (interest doesn't affect tracking tokens)
        assertEq(
            convertibles.variables(usdc).trackingToken.balanceOf(user1),
            initialTrackingTokenBalance,
            "Tracking token balance changed after interest claim"
        );

        vm.stopPrank();
    }

    function test_EdgeCaseZeroAmounts() public {
        vm.startPrank(user1);

        // Try to stake 0 amount (should revert)
        vm.expectRevert("Invalid amount");
        convertibles.stake(usdc, 0, LOCK_DURATION, user1);

        // Try to split with 0 percentage (should revert)
        vm.startPrank(user1);
        (uint256 tokenId,,,,,) = convertibles.stake(usdc, USDC_AMOUNT, LOCK_DURATION, user1);

        vm.expectRevert("Invalid percentage");
        convertibles.split(tokenId, 0);

        vm.expectRevert("Invalid percentage");
        convertibles.split(tokenId, 1e18);

        vm.stopPrank();
    }

    function test_BasicSetup() public {
        // This test just verifies the basic setup works
        assertEq(address(convertibles.authority()), address(authority));
        assertEq(address(convertibles.rzr()), address(rzr));
        assertEq(address(convertibles.oracle()), address(appOracle));
        assertEq(convertibles.lastId(), 0);
        assertEq(convertibles.totalConvertible(), 0);
    }

    // Helper function to calculate interest
    function _calculateInterest(uint256 amount, uint256 interestRatePerYear, uint256 duration)
        internal
        pure
        returns (uint256)
    {
        return amount * interestRatePerYear * duration / 1e18 / 365 days;
    }
}
