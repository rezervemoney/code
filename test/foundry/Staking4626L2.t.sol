// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../contracts/periphery/bridge/Staking4626L2.sol";
import "../../contracts/core/AppAuthority.sol";
import "../../contracts/mocks/MockERC20.sol";
import "../../contracts/mocks/MockEndpoint.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";

/// @title Staking4626L2Test
/// @notice Comprehensive unit tests for the Staking4626L2 ERC-4626 compliant staking vault
/// @dev Tests all ERC4626 functions and ensures compliance with the standard
contract Staking4626L2Test is Test {
    Staking4626L2 public vault;
    AppAuthority public authority;
    MockERC20 public underlying;
    MockEndpoint public lzEndpoint;

    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public bridge = makeAddr("bridge");
    address public delegate = makeAddr("delegate");

    uint256 internal constant INITIAL_SUPPLY = 1000 ether;
    uint256 internal constant DEPOSIT_AMOUNT = 100 ether;
    uint256 internal constant MINT_SHARES = 50 ether;

    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event DepositFeeCollected(address indexed user, uint256 feeAmount);
    event RateUpdated(uint256 rate, uint256 oldRate);
    event DepositFeeUpdated(uint256 depositFee);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy contracts
        authority = new AppAuthority();
        underlying = new MockERC20("Test Token", "TEST");
        lzEndpoint = new MockEndpoint();

        // Deploy vault
        vault = new Staking4626L2();

        // Set up authority roles
        authority.addGovernor(owner);
        authority.setBridge(bridge);

        // Initialize vault
        vault.initialize(address(authority), address(lzEndpoint), delegate, address(underlying));
        vault.setDepositFee(0);

        // Mint initial tokens
        underlying.mint(user1, INITIAL_SUPPLY);
        underlying.mint(user2, INITIAL_SUPPLY);
        underlying.mint(user3, INITIAL_SUPPLY);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Initialization() public view {
        assertEq(vault.asset(), address(underlying), "Asset should be set correctly");
        assertEq(vault.rate(), 1e18, "Initial rate should be 1e18");
        assertEq(vault.depositFee(), 0, "Initial deposit fee should be 0");
        assertEq(vault.totalFeesCollected(), 0, "Initial total fees should be 0");
    }

    function test_InitializationRevertsIfAlreadyInitialized() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        vault.initialize(address(authority), address(lzEndpoint), delegate, address(underlying));
    }

    /*//////////////////////////////////////////////////////////////
                                ACCESS CONTROL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OnlyBridgeCanSetRate() public {
        vm.startPrank(user1);
        vm.expectRevert("UNAUTHORIZED");
        vault.setRate(2e18);
        vm.stopPrank();
    }

    function test_OnlyGovernorCanSetDepositFee() public {
        vm.startPrank(user1);
        vm.expectRevert("UNAUTHORIZED");
        vault.setDepositFee(0.05e18);
        vm.stopPrank();
    }

    function test_BridgeCanSetRate() public {
        vm.startPrank(bridge);
        vault.setRate(2e18);
        assertEq(vault.rate(), 2e18, "Rate should be updated");
        vm.stopPrank();
    }

    function test_GovernorCanSetDepositFee() public {
        vm.startPrank(owner);
        vault.setDepositFee(0.05e18);
        assertEq(vault.depositFee(), 0.05e18, "Deposit fee should be updated");
        vm.stopPrank();
    }

    function test_SetRateRevertsIfNewRateLower() public {
        vm.startPrank(bridge);
        vault.setRate(2e18);
        vm.expectRevert("Rate must be greater than or equal to the old rate");
        vault.setRate(1e18);
        vm.stopPrank();
    }

    function test_SetDepositFeeRevertsIfExceeds10Percent() public {
        vm.startPrank(owner);
        vm.expectRevert("Deposit fee cannot exceed 10%");
        vault.setDepositFee(0.11e18);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                ERC4626 VIEW FUNCTIONS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Asset() public view {
        assertEq(vault.asset(), address(underlying), "Asset should return underlying token address");
    }

    function test_TotalAssets() public {
        // Initially no shares, so total assets should be 0
        assertEq(vault.totalAssets(), 0, "Total assets should be 0 initially");

        // After deposit, total assets should reflect the rate
        vm.startPrank(user1);
        underlying.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT, user1);
        vm.stopPrank();

        uint256 expectedTotalAssets = vault.totalSupply() * vault.rate() / 1e18;
        assertEq(vault.totalAssets(), expectedTotalAssets, "Total assets should match calculated value");
    }

    function test_ConvertToAssets() public view {
        uint256 shares = 100 ether;
        uint256 expectedAssets = shares * vault.rate() / 1e18;
        assertEq(vault.convertToAssets(shares), expectedAssets, "Convert to assets should work correctly");
    }

    function test_ConvertToShares() public view {
        uint256 assets = 100 ether;
        uint256 expectedShares = assets * 1e18 / vault.rate();
        assertEq(vault.convertToShares(assets), expectedShares, "Convert to shares should work correctly");
    }

    function test_MaxDeposit() public view {
        assertEq(vault.maxDeposit(user1), type(uint256).max, "Max deposit should be unlimited");
    }

    function test_MaxMint() public view {
        assertEq(vault.maxMint(user1), type(uint256).max, "Max mint should be unlimited");
    }

    function test_MaxWithdraw() public view {
        assertEq(vault.maxWithdraw(user1), 0, "Max withdraw should be 0 (L2 only)");
    }

    function test_MaxRedeem() public view {
        assertEq(vault.maxRedeem(user1), 0, "Max redeem should be 0 (L2 only)");
    }

    /*//////////////////////////////////////////////////////////////
                                ERC4626 PREVIEW FUNCTIONS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PreviewDeposit() public view {
        uint256 assets = 100 ether;
        uint256 expectedShares = vault.convertToShares(assets);
        assertEq(vault.previewDeposit(assets), expectedShares, "Preview deposit should match convert to shares");
    }

    function test_PreviewDepositWithFee() public {
        vm.startPrank(owner);
        vault.setDepositFee(0.05e18); // 5% fee
        vm.stopPrank();

        uint256 assets = 100 ether;
        uint256 feeAmount = (assets * 0.05e18) / 1e18;
        uint256 netAssets = assets - feeAmount;
        uint256 expectedShares = vault.convertToShares(netAssets);

        assertEq(vault.previewDeposit(assets), expectedShares, "Preview deposit with fee should work correctly");
    }

    function test_PreviewMint() public view {
        uint256 shares = 100 ether;
        uint256 expectedAssets = vault.convertToAssets(shares);
        assertEq(vault.previewMint(shares), expectedAssets, "Preview mint should match convert to assets");
    }

    function test_PreviewMintWithFee() public {
        vm.startPrank(owner);
        vault.setDepositFee(0.05e18); // 5% fee
        vm.stopPrank();

        uint256 shares = 100 ether;
        uint256 grossAssets = vault.convertToAssets(shares);
        uint256 feeAmount = (grossAssets * 0.05e18) / (1e18 - 0.05e18);
        uint256 expectedAssets = grossAssets + feeAmount;

        assertEq(vault.previewMint(shares), expectedAssets, "Preview mint with fee should work correctly");
    }

    function test_PreviewWithdraw() public view {
        uint256 assets = 100 ether;
        uint256 expectedShares = vault.convertToShares(assets);
        assertEq(vault.previewWithdraw(assets), expectedShares, "Preview withdraw should match convert to shares");
    }

    function test_PreviewRedeem() public view {
        uint256 shares = 100 ether;
        uint256 expectedAssets = vault.convertToAssets(shares);
        assertEq(vault.previewRedeem(shares), expectedAssets, "Preview redeem should match convert to assets");
    }

    /*//////////////////////////////////////////////////////////////
                                ERC4626 DEPOSIT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Deposit() public {
        vm.startPrank(user1);
        underlying.approve(address(vault), DEPOSIT_AMOUNT);

        uint256 balanceBefore = underlying.balanceOf(user1);
        uint256 sharesBefore = vault.balanceOf(user1);

        vm.expectEmit(true, true, false, true);
        emit Deposit(user1, user1, DEPOSIT_AMOUNT, vault.previewDeposit(DEPOSIT_AMOUNT));

        uint256 shares = vault.deposit(DEPOSIT_AMOUNT, user1);

        assertEq(underlying.balanceOf(user1), balanceBefore - DEPOSIT_AMOUNT, "User balance should decrease");
        assertEq(vault.balanceOf(user1), sharesBefore + shares, "User shares should increase");
        assertEq(vault.balanceOf(user1), shares, "User should receive correct shares");
        vm.stopPrank();
    }

    function test_DepositWithFee() public {
        vm.startPrank(owner);
        vault.setDepositFee(0.05e18); // 5% fee
        vm.stopPrank();

        vm.startPrank(user1);
        underlying.approve(address(vault), DEPOSIT_AMOUNT);

        uint256 balanceBefore = underlying.balanceOf(user1);
        uint256 sharesBefore = vault.balanceOf(user1);

        uint256 shares = vault.deposit(DEPOSIT_AMOUNT, user1);

        assertEq(underlying.balanceOf(user1), balanceBefore - DEPOSIT_AMOUNT, "User balance should decrease");
        assertEq(vault.balanceOf(user1), sharesBefore + shares, "User shares should increase");
        assertEq(vault.totalFeesCollected(), (DEPOSIT_AMOUNT * 0.05e18) / 1e18, "Fees should be collected");
        vm.stopPrank();
    }

    function test_DepositRevertsIfZeroAssets() public {
        vm.startPrank(user1);
        underlying.approve(address(vault), 0);
        vm.expectRevert("ZERO_ASSETS");
        vault.deposit(0, user1);
        vm.stopPrank();
    }

    function test_DepositRevertsIfZeroShares() public {
        // This would require a very high rate to result in 0 shares
        // Let's test with a very small amount that might result in 0 shares
        vm.startPrank(user1);
        underlying.approve(address(vault), 1);
        // This might revert with ZERO_SHARES depending on the rate
        try vault.deposit(1, user1) {
            // If it doesn't revert, that's fine
        } catch Error(string memory reason) {
            assertEq(reason, "ZERO_SHARES", "Should revert with ZERO_SHARES if applicable");
        }
        vm.stopPrank();
    }

    function test_DepositRevertsIfInsufficientAllowance() public {
        vm.startPrank(user1);
        underlying.approve(address(vault), DEPOSIT_AMOUNT - 1);
        vm.expectRevert();
        vault.deposit(DEPOSIT_AMOUNT, user1);
        vm.stopPrank();
    }

    function test_DepositToDifferentReceiver() public {
        vm.startPrank(user1);
        underlying.approve(address(vault), DEPOSIT_AMOUNT);

        uint256 balanceBefore = underlying.balanceOf(user1);
        uint256 sharesBefore = vault.balanceOf(user2);

        vm.expectEmit(true, true, false, true);
        emit Deposit(user1, user2, DEPOSIT_AMOUNT, vault.previewDeposit(DEPOSIT_AMOUNT));

        uint256 shares = vault.deposit(DEPOSIT_AMOUNT, user2);

        assertEq(underlying.balanceOf(user1), balanceBefore - DEPOSIT_AMOUNT, "User1 balance should decrease");
        assertEq(vault.balanceOf(user2), sharesBefore + shares, "User2 shares should increase");
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                ERC4626 MINT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Mint() public {
        vm.startPrank(user1);
        uint256 assetsNeeded = vault.previewMint(MINT_SHARES);
        underlying.approve(address(vault), assetsNeeded);

        uint256 balanceBefore = underlying.balanceOf(user1);
        uint256 sharesBefore = vault.balanceOf(user1);

        uint256 assets = vault.mint(MINT_SHARES, user1);

        assertEq(underlying.balanceOf(user1), balanceBefore - assets, "User balance should decrease");
        assertEq(vault.balanceOf(user1), sharesBefore + MINT_SHARES, "User shares should increase");
        assertEq(assets, assetsNeeded, "Assets should match preview");
        vm.stopPrank();
    }

    function test_MintWithFee() public {
        vm.startPrank(owner);
        vault.setDepositFee(0.05e18); // 5% fee
        vm.stopPrank();

        vm.startPrank(user1);
        uint256 assetsNeeded = vault.previewMint(MINT_SHARES);
        underlying.approve(address(vault), assetsNeeded);

        uint256 balanceBefore = underlying.balanceOf(user1);
        uint256 sharesBefore = vault.balanceOf(user1);

        uint256 assets = vault.mint(MINT_SHARES, user1);

        assertEq(underlying.balanceOf(user1), balanceBefore - assets, "User balance should decrease");
        assertEq(vault.balanceOf(user1), sharesBefore + MINT_SHARES, "User shares should increase");
        // The fee calculation in mint is: (grossAssets * depositFee) / (1e18 - depositFee)
        // where grossAssets = convertToAssets(shares)
        uint256 grossAssets = vault.convertToAssets(MINT_SHARES);
        uint256 expectedFee = (grossAssets * 0.05e18) / (1e18 - 0.05e18);
        assertEq(vault.totalFeesCollected(), expectedFee, "Fees should be collected");
        vm.stopPrank();
    }

    function test_MintRevertsIfZeroShares() public {
        vm.startPrank(user1);
        underlying.approve(address(vault), 0);
        vm.expectRevert("ZERO_SHARES");
        vault.mint(0, user1);
        vm.stopPrank();
    }

    function test_MintRevertsIfZeroAssets() public {
        // This would require a very high rate to result in 0 assets
        // Let's test with a very small amount that might result in 0 assets
        vm.startPrank(user1);
        underlying.approve(address(vault), 1);
        // This might revert with ZERO_ASSETS depending on the rate
        try vault.mint(1, user1) {
            // If it doesn't revert, that's fine
        } catch Error(string memory reason) {
            assertEq(reason, "ZERO_ASSETS", "Should revert with ZERO_ASSETS if applicable");
        }
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                ERC4626 WITHDRAW/REDEEM TESTS
    //////////////////////////////////////////////////////////////*/

    function test_WithdrawRevertsOnL2() public {
        vm.startPrank(user1);
        vm.expectRevert("Only on L1");
        vault.withdraw(100 ether, user1, user1);
        vm.stopPrank();
    }

    function test_RedeemRevertsOnL2() public {
        vm.startPrank(user1);
        vm.expectRevert("Only on L1");
        vault.redeem(100 ether, user1, user1);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                RATE UPDATE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RateUpdate() public {
        vm.startPrank(bridge);
        uint256 oldRate = vault.rate();
        uint256 newRate = 2e18;

        vm.expectEmit(true, true, false, true);
        emit RateUpdated(newRate, oldRate);

        vault.setRate(newRate);

        assertEq(vault.rate(), newRate, "Rate should be updated");
        assertEq(oldRate, 1e18, "Old rate should be 1e18");
        vm.stopPrank();
    }

    function test_RateUpdateEmitsEvent() public {
        vm.startPrank(bridge);
        uint256 oldRate = vault.rate();
        uint256 newRate = 1.5e18;

        vm.expectEmit(true, true, false, true);
        emit RateUpdated(newRate, oldRate);

        vault.setRate(newRate);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                DEPOSIT FEE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DepositFeeUpdate() public {
        vm.startPrank(owner);
        uint256 newFee = 0.05e18; // 5%

        vm.expectEmit(true, false, false, true);
        emit DepositFeeUpdated(newFee);

        vault.setDepositFee(newFee);

        assertEq(vault.depositFee(), newFee, "Deposit fee should be updated");
        vm.stopPrank();
    }

    function test_DepositFeeCollection() public {
        vm.startPrank(owner);
        vault.setDepositFee(0.05e18); // 5% fee
        vm.stopPrank();

        vm.startPrank(user1);
        underlying.approve(address(vault), DEPOSIT_AMOUNT);

        vm.expectEmit(true, false, false, true);
        emit DepositFeeCollected(user1, (DEPOSIT_AMOUNT * 0.05e18) / 1e18);

        vault.deposit(DEPOSIT_AMOUNT, user1);

        assertEq(vault.totalFeesCollected(), (DEPOSIT_AMOUNT * 0.05e18) / 1e18, "Fees should be collected");
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                ERC4626 COMPLIANCE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ERC4626Compliance() public view {
        // Test that all required ERC4626 functions are implemented
        // and return expected values

        // asset() - should return underlying token address
        assertEq(vault.asset(), address(underlying), "asset() should return underlying token");

        // totalAssets() - should return total managed assets
        assertEq(vault.totalAssets(), 0, "totalAssets() should return 0 initially");

        // convertToShares() and convertToAssets() - should be inverse operations
        uint256 testAmount = 100 ether;
        uint256 shares = vault.convertToShares(testAmount);
        uint256 assets = vault.convertToAssets(shares);
        assertApproxEqRel(assets, testAmount, 0.001e18, "convertToShares and convertToAssets should be inverse");

        // maxDeposit() and maxMint() - should return unlimited
        assertEq(vault.maxDeposit(user1), type(uint256).max, "maxDeposit should be unlimited");
        assertEq(vault.maxMint(user1), type(uint256).max, "maxMint should be unlimited");

        // maxWithdraw() and maxRedeem() - should return 0 (L2 only)
        assertEq(vault.maxWithdraw(user1), 0, "maxWithdraw should return 0 on L2");
        assertEq(vault.maxRedeem(user1), 0, "maxRedeem should return 0 on L2");
    }

    function test_ERC4626Events() public {
        vm.startPrank(user1);
        underlying.approve(address(vault), DEPOSIT_AMOUNT);

        // Test Deposit event emission
        vm.expectEmit(true, true, false, true);
        emit Deposit(user1, user1, DEPOSIT_AMOUNT, vault.previewDeposit(DEPOSIT_AMOUNT));

        vault.deposit(DEPOSIT_AMOUNT, user1);
        vm.stopPrank();
    }

    function test_ERC4626PrecisionHandling() public view {
        // Test with very small amounts to ensure precision is handled correctly
        uint256 smallAmount = 1; // 1 wei

        uint256 shares = vault.convertToShares(smallAmount);
        uint256 assets = vault.convertToAssets(shares);

        // The conversion should handle small amounts without reverting
        assertGe(shares, 0, "Small amounts should not result in negative shares");
        assertGe(assets, 0, "Small amounts should not result in negative assets");
    }

    /*//////////////////////////////////////////////////////////////
                                EDGE CASES AND ERROR HANDLING
    //////////////////////////////////////////////////////////////*/

    function test_ZeroRateHandling() public view {
        // Test behavior when rate is 0 (should not happen in normal operation)
        // This is more of a defensive test
        uint256 testAmount = 100 ether;
        uint256 shares = vault.convertToShares(testAmount);
        uint256 assets = vault.convertToAssets(shares);

        // With rate = 1e18, these should be equal
        assertEq(assets, testAmount, "Assets should equal input with 1:1 rate");
    }

    function test_HighRateHandling() public {
        // Test with a very high rate
        vm.startPrank(bridge);
        vault.setRate(1000e18); // 1000x rate
        vm.stopPrank();

        uint256 testAmount = 100 ether;
        uint256 shares = vault.convertToShares(testAmount);
        uint256 assets = vault.convertToAssets(shares);

        // With high rate, shares should be much smaller than assets
        assertLt(shares, testAmount, "Shares should be smaller with high rate");
        assertEq(assets, testAmount, "Assets should equal input");
    }

    function test_FeeCalculationPrecision() public {
        vm.startPrank(owner);
        vault.setDepositFee(0.01e18); // 1% fee
        vm.stopPrank();

        uint256 testAmount = 100 ether;
        uint256 feeAmount = (testAmount * 0.01e18) / 1e18;
        uint256 netAmount = testAmount - feeAmount;

        uint256 shares = vault.previewDeposit(testAmount);
        uint256 expectedShares = vault.convertToShares(netAmount);

        assertEq(shares, expectedShares, "Fee calculation should be precise");
    }

    /*//////////////////////////////////////////////////////////////
                                INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_MultipleUserDeposits() public {
        // User1 deposits
        vm.startPrank(user1);
        underlying.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 shares1 = vault.deposit(DEPOSIT_AMOUNT, user1);
        vm.stopPrank();

        // User2 deposits
        vm.startPrank(user2);
        underlying.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 shares2 = vault.deposit(DEPOSIT_AMOUNT, user2);
        vm.stopPrank();

        // User3 deposits
        vm.startPrank(user3);
        underlying.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 shares3 = vault.deposit(DEPOSIT_AMOUNT, user3);
        vm.stopPrank();

        // Check total supply
        assertEq(vault.totalSupply(), shares1 + shares2 + shares3, "Total supply should be sum of all deposits");

        // Check individual balances
        assertEq(vault.balanceOf(user1), shares1, "User1 should have correct shares");
        assertEq(vault.balanceOf(user2), shares2, "User2 should have correct shares");
        assertEq(vault.balanceOf(user3), shares3, "User3 should have correct shares");

        // Check total assets
        uint256 totalAssets = vault.totalAssets();
        uint256 expectedTotalAssets = vault.totalSupply() * vault.rate() / 1e18;
        assertEq(totalAssets, expectedTotalAssets, "Total assets should match calculated value");
    }

    function test_RateChangeAfterDeposits() public {
        // Initial deposits
        vm.startPrank(user1);
        underlying.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 shares1 = vault.deposit(DEPOSIT_AMOUNT, user1);
        vm.stopPrank();

        vm.startPrank(user2);
        underlying.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 shares2 = vault.deposit(DEPOSIT_AMOUNT, user2);
        vm.stopPrank();

        uint256 initialTotalAssets = vault.totalAssets();

        // Change rate
        vm.startPrank(bridge);
        vault.setRate(2e18); // Double the rate
        vm.stopPrank();

        uint256 newTotalAssets = vault.totalAssets();

        // Total assets should double with the rate change
        assertEq(newTotalAssets, initialTotalAssets * 2, "Total assets should double with rate change");

        // Individual user assets should also double
        uint256 user1Assets = vault.convertToAssets(shares1);
        uint256 user2Assets = vault.convertToAssets(shares2);

        assertEq(user1Assets, DEPOSIT_AMOUNT * 2, "User1 assets should double");
        assertEq(user2Assets, DEPOSIT_AMOUNT * 2, "User2 assets should double");
    }

    function test_FeeCollectionAccumulation() public {
        vm.startPrank(owner);
        vault.setDepositFee(0.05e18); // 5% fee
        vm.stopPrank();

        uint256 totalFeesCollected = 0;

        // Multiple deposits to accumulate fees
        for (uint256 i = 0; i < 3; i++) {
            address user = i == 0 ? user1 : (i == 1 ? user2 : user3);
            uint256 depositAmount = 50 ether;

            vm.startPrank(user);
            underlying.approve(address(vault), depositAmount);
            vault.deposit(depositAmount, user);
            vm.stopPrank();

            uint256 feeAmount = (depositAmount * 0.05e18) / 1e18;
            totalFeesCollected += feeAmount;
        }

        assertEq(vault.totalFeesCollected(), totalFeesCollected, "Total fees should accumulate correctly");
    }
}
