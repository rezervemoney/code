// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../contracts/core/AppConvertibles.sol";
import "../../contracts/core/AppAuthority.sol";
import "../../contracts/core/RZR.sol";
import "../../contracts/mocks/MockERC20.sol";
import "../../contracts/mocks/MockERC4626.sol";
import "../../contracts/mocks/MockPermissionedERC20.sol";
import "../../contracts/mocks/MockOracleV2.sol";
import "../../contracts/mocks/MockEndpoint.sol";
import "../../contracts/interfaces/IAppConvertibles.sol";

contract AppConvertiblesTest is Test {
    AppConvertibles public convertibles;
    AppAuthority public authority;
    RZR public rzr;
    MockERC20 public underlyingToken;
    MockERC4626 public loanToken;
    MockPermissionedERC20 public loanTrackingToken;
    MockPermissionedERC20 public rzrTrackingToken;
    MockOracleV2 public oracle;
    MockOracleV2 public twapOracle;
    MockEndpoint public lz;

    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");

    uint256 public constant STAKE_AMOUNT = 1000e18;
    uint256 public constant LOCK_DURATION_30_DAYS = 30 days;
    uint256 public constant LOCK_DURATION_1_YEAR = 365 days;
    uint256 public constant LOCK_DURATION_4_YEARS = 4 * 365 days;

    function setUp() public {
        vm.warp(block.timestamp + 10 days);

        vm.startPrank(owner);

        // Deploy authority
        authority = new AppAuthority();

        // Deploy underlying token
        underlyingToken = new MockERC20("Underlying Token", "UND");

        // Deploy loan token (ERC4626 vault)
        loanToken = new MockERC4626("Loan Token", "LOAN", underlyingToken);

        // Deploy LayerZero endpoint
        lz = new MockEndpoint();

        // Deploy RZR token
        rzr = new RZR(address(lz), address(authority));

        // Deploy tracking tokens
        loanTrackingToken = new MockPermissionedERC20("Loan Tracking", "lLOAN");
        rzrTrackingToken = new MockPermissionedERC20("RZR Tracking", "lRZR");

        // Deploy oracles
        oracle = new MockOracleV2(0, 1e18, address(underlyingToken)); // 1:1 price
        twapOracle = new MockOracleV2(0, 1.1e18, address(underlyingToken)); // 1.1:1 price

        // Deploy convertibles contract
        convertibles = new AppConvertibles();

        IAppConvertibles.Variables memory vars = IAppConvertibles.Variables({
            minConversionPremium: 0.05e18,
            maxConversionPremium: 0.2e18,
            minFixedInterestRate: 0.01e18,
            maxFixedInterestRate: 0.3e18,
            supplyCap: 0,
            debtCap: 0
        });

        // Initialize convertibles
        convertibles.initialize(
            address(loanToken),
            address(rzr),
            address(loanTrackingToken),
            address(rzrTrackingToken),
            address(oracle),
            address(twapOracle),
            address(authority),
            vars
        );

        // Set up permissions
        authority.addGovernor(owner);
        authority.setTreasury(owner);
        authority.addPolicy(address(convertibles));
        loanTrackingToken.addMinter(address(convertibles));
        loanTrackingToken.addBurner(address(convertibles));
        rzrTrackingToken.addMinter(address(convertibles));
        rzrTrackingToken.addBurner(address(convertibles));

        // Mint underlying tokens to users
        underlyingToken.mint(user1, 10000e18);
        underlyingToken.mint(user2, 10000e18);
        underlyingToken.mint(user3, 10000e18);
        underlyingToken.mint(owner, 1000000e18);

        // Users deposit underlying tokens to get loan tokens
        vm.stopPrank();

        vm.startPrank(user1);
        underlyingToken.approve(address(loanToken), type(uint256).max);
        loanToken.deposit(5000e18, user1);
        vm.stopPrank();

        vm.startPrank(user2);
        underlyingToken.approve(address(loanToken), type(uint256).max);
        loanToken.deposit(5000e18, user2);
        vm.stopPrank();

        vm.startPrank(user3);
        underlyingToken.approve(address(loanToken), type(uint256).max);
        loanToken.deposit(5000e18, user3);
        vm.stopPrank();

        vm.startPrank(owner);
        underlyingToken.approve(address(loanToken), type(uint256).max);
        loanToken.deposit(1000000e18, owner);
        vm.stopPrank();

        // Update oracle timestamps to avoid staleness
        oracle.touchTimestamp();
        twapOracle.touchTimestamp();

        // Label contracts for better trace output
        vm.label(address(convertibles), "Convertibles");
        vm.label(address(authority), "Authority");
        vm.label(address(rzr), "RZR");
        vm.label(address(underlyingToken), "Underlying");
        vm.label(address(loanToken), "Loan Token");
        vm.label(address(loanTrackingToken), "Loan Tracking");
        vm.label(address(rzrTrackingToken), "RZR Tracking");
        vm.label(address(oracle), "Oracle");
        vm.label(address(twapOracle), "TWAP Oracle");
    }

    // ============ CONSTANTS TESTS ============

    function testConstants() public view {
        assertEq(convertibles.MAX_LOCK_DURATION(), 4 * 365 days);
        assertEq(convertibles.MIN_LOCK_DURATION(), 30 days);
        assertEq(convertibles.MAX_ORACLE_STALENESS(), 1 days);
    }

    // ============ INITIALIZATION TESTS ============

    function testInitialization() public view {
        assertEq(address(convertibles.loanToken()), address(loanToken));
        assertEq(address(convertibles.rzr()), address(rzr));
        assertEq(address(convertibles.loanTrackingToken()), address(loanTrackingToken));
        assertEq(address(convertibles.rzrTrackingToken()), address(rzrTrackingToken));
        assertEq(address(convertibles.oracle()), address(oracle));
        assertEq(address(convertibles.twapOracle()), address(twapOracle));
        assertEq(convertibles.lastId(), 0);
        assertEq(convertibles.totalStaked(), 0);
        assertEq(convertibles.totalConvertible(), 0);
        assertEq(convertibles.loanTokenDecimals(), 10 ** (18 - loanToken.decimals()));
    }

    function testCannotInitializeTwice() public {
        IAppConvertibles.Variables memory vars = IAppConvertibles.Variables({
            minConversionPremium: 0.05e18,
            maxConversionPremium: 0.2e18,
            minFixedInterestRate: 0.01e18,
            maxFixedInterestRate: 0.3e18,
            supplyCap: 0,
            debtCap: 0
        });

        vm.expectRevert();
        convertibles.initialize(
            address(loanToken),
            address(rzr),
            address(loanTrackingToken),
            address(rzrTrackingToken),
            address(oracle),
            address(twapOracle),
            address(authority),
            vars
        );
    }

    // ============ VARIABLES TESTS ============

    function testOnlyGovernorCanSetVariables() public {
        vm.startPrank(user1);
        vm.expectRevert();
        convertibles.setVariables(0.1e18, 0.25e18, 2e15, 6e15, 0, 0);
        vm.stopPrank();
    }

    // ============ SUPPLY AND DEBT CAPS TESTS ============

    function testSetSupplyAndDebtCaps() public {
        vm.startPrank(owner);

        // Set specific caps
        convertibles.setVariables(
            0.05e18, // minConversionPremium: 5%
            0.2e18, // maxConversionPremium: 20%
            uint256(0.01e18) / (365 * 86400), // minFixedInterestPerSecond: 0.1% per day
            uint256(0.05e18) / (365 * 86400), // maxFixedInterestPerSecond: 0.5% per day
            5000e18, // supplyCap: 5000 RZR
            10000e18 // debtCap: 10000 loan tokens
        );

        // Verify caps are set correctly
        IAppConvertibles.Variables memory vars = convertibles.variables();
        assertEq(vars.supplyCap, 5000e18);
        assertEq(vars.debtCap, 10000e18);
        vm.stopPrank();
    }

    function testStakeRespectsDebtCap() public {
        // Set a debt cap that's smaller than the stake amount
        vm.startPrank(owner);
        convertibles.setVariables(
            0.05e18, // minConversionPremium: 5%
            0.2e18, // maxConversionPremium: 20%
            uint256(0.01e18) / (365 * 86400), // minFixedInterestPerSecond: 0.1% per day
            uint256(0.05e18) / (365 * 86400), // maxFixedInterestPerSecond: 0.5% per day
            0, // supplyCap: 0 (no cap)
            STAKE_AMOUNT / 2 // debtCap: half of STAKE_AMOUNT
        );
        vm.stopPrank();

        // Try to stake more than the debt cap
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        vm.expectRevert("Debt cap reached");
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user1);
        vm.stopPrank();
    }

    function testStakeRespectsSupplyCap() public {
        // First, get the conversion amount for a stake to set appropriate supply cap
        (,, uint256 conversionAmount) = convertibles.getOfferings(STAKE_AMOUNT, LOCK_DURATION_30_DAYS);

        // Set a supply cap that's smaller than the conversion amount
        vm.startPrank(owner);
        convertibles.setVariables(
            0.05e18, // minConversionPremium: 5%
            0.2e18, // maxConversionPremium: 20%
            0.01e18, // minFixedInterestRate: 1% / year
            0.3e18, // maxFixedInterestRate: 30% / year
            conversionAmount / 2, // supplyCap: half of conversion amount
            0 // debtCap: 0 (no cap)
        );
        vm.stopPrank();

        // Try to stake which would exceed the supply cap
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        vm.expectRevert("Supply cap reached");
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user1);
        vm.stopPrank();
    }

    function testStakeWithinCaps() public {
        // Set caps that allow the stake
        vm.startPrank(owner);
        convertibles.setVariables(
            0.05e18, // minConversionPremium: 5%
            0.2e18, // maxConversionPremium: 20%
            uint256(0.01e18) / (365 * 86400), // minFixedInterestPerSecond: 0.1% per day
            uint256(0.05e18) / (365 * 86400), // maxFixedInterestPerSecond: 0.5% per day
            10000e18, // supplyCap: 10000 RZR (very large)
            10000e18 // debtCap: 10000 loan tokens (very large)
        );
        vm.stopPrank();

        // Stake should succeed
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user1);
        vm.stopPrank();

        // Verify position was created
        assertEq(convertibles.ownerOf(1), user1);
        assertEq(convertibles.totalStaked(), STAKE_AMOUNT);

        // Get the actual conversion amount from the position
        IAppConvertibles.Position memory position = convertibles.positions(1);
        assertEq(convertibles.totalConvertible(), position.amountConvertible);
    }

    function testMultipleStakesRespectCaps() public {
        // Set caps that allow exactly two stakes
        vm.startPrank(owner);
        convertibles.setVariables(
            0.05e18, // minConversionPremium: 5%
            0.2e18, // maxConversionPremium: 20%
            uint256(0.01e18) / (365 * 86400), // minFixedInterestPerSecond: 0.1% per day
            uint256(0.05e18) / (365 * 86400), // maxFixedInterestPerSecond: 0.5% per day
            2000e18, // supplyCap: 2000 RZR (large enough for two stakes)
            STAKE_AMOUNT * 2 // debtCap: exactly two stakes
        );
        vm.stopPrank();

        // First stake should succeed
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user1);
        vm.stopPrank();

        // Second stake should succeed
        vm.startPrank(user2);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_4_YEARS, user2);
        vm.stopPrank();

        // Third stake should fail due to debt cap
        vm.startPrank(user3);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        vm.expectRevert("Debt cap reached");
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user3);
        vm.stopPrank();

        // Verify only two positions were created
        assertEq(convertibles.lastId(), 2);
        assertEq(convertibles.totalStaked(), STAKE_AMOUNT * 2);
    }

    function testCapsResetToZero() public {
        // First set some caps and stake
        vm.startPrank(owner);
        convertibles.setVariables(
            0.05e18, // minConversionPremium: 5%
            0.2e18, // maxConversionPremium: 20%
            uint256(0.01e18) / (365 * 86400), // minFixedInterestPerSecond: 0.1% per day
            uint256(0.05e18) / (365 * 86400), // maxFixedInterestPerSecond: 0.5% per day
            1000e18, // supplyCap: 1000 RZR
            2000e18 // debtCap: 2000 loan tokens
        );
        vm.stopPrank();

        // Stake some amount
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user1);
        vm.stopPrank();

        // Reset caps to zero (no caps)
        vm.startPrank(owner);
        convertibles.setVariables(
            0.05e18, // minConversionPremium: 5%
            0.2e18, // maxConversionPremium: 20%
            uint256(0.01e18) / (365 * 86400), // minFixedInterestPerSecond: 0.1% per day
            uint256(0.05e18) / (365 * 86400), // maxFixedInterestPerSecond: 0.5% per day
            0, // supplyCap: 0 (no cap)
            0 // debtCap: 0 (no cap)
        );
        vm.stopPrank();

        // Should be able to stake again since caps are disabled
        vm.startPrank(user2);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user2);
        vm.stopPrank();

        // Verify both positions exist
        assertEq(convertibles.lastId(), 2);
        assertEq(convertibles.ownerOf(1), user1);
        assertEq(convertibles.ownerOf(2), user2);
    }

    function testConvertReducesCaps() public {
        vm.startPrank(owner);
        convertibles.setVariables(
            0.05e18, // minConversionPremium: 5%
            0.2e18, // maxConversionPremium: 20%
            uint256(0.01e18) / (365 * 86400), // minFixedInterestPerSecond: 0.1% per day
            uint256(0.05e18) / (365 * 86400), // maxFixedInterestPerSecond: 0.5% per day
            1000e18, // supplyCap: 1000 RZR (large enough for one stake)
            STAKE_AMOUNT // debtCap: exactly one stake
        );
        vm.stopPrank();

        // Stake
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user1);
        vm.stopPrank();

        // Wait for minimum lock duration
        vm.warp(block.timestamp + LOCK_DURATION_30_DAYS + 1);

        // Set TWAP price higher than conversion price
        twapOracle.setPrice(0, 10 * 1e18);
        twapOracle.touchTimestamp();
        oracle.touchTimestamp();

        // Convert the position
        vm.startPrank(user1);
        convertibles.convert(1);
        vm.stopPrank();

        // Should be able to stake again since conversion freed up the caps
        vm.startPrank(user2);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user2);
        vm.stopPrank();

        // Verify new position was created
        assertEq(convertibles.lastId(), 2);
        assertEq(convertibles.ownerOf(2), user2);
    }

    function testRedeemReducesCaps() public {
        vm.startPrank(owner);
        convertibles.setVariables(
            0.05e18, // minConversionPremium: 5%
            0.2e18, // maxConversionPremium: 20%
            uint256(0.01e18) / (365 * 86400), // minFixedInterestPerSecond: 0.1% per day
            uint256(0.05e18) / (365 * 86400), // maxFixedInterestPerSecond: 0.5% per day
            1000e18, // supplyCap: 1000 RZR (large enough for one stake)
            STAKE_AMOUNT // debtCap: exactly one stake
        );
        vm.stopPrank();

        // Stake
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user1);
        vm.stopPrank();

        // Wait for minimum lock duration
        vm.warp(block.timestamp + LOCK_DURATION_30_DAYS + 1);

        // Update oracle timestamps
        oracle.touchTimestamp();
        twapOracle.touchTimestamp();

        // Add loan tokens to contract for redemption
        vm.startPrank(owner);
        underlyingToken.mint(address(loanToken), 10000e18);
        loanToken.updateExchangeRate();
        loanToken.transfer(address(convertibles), 10000e18);
        vm.stopPrank();

        // Redeem the position
        vm.startPrank(user1);
        convertibles.redeem(1);
        vm.stopPrank();

        // Should be able to stake again since redemption freed up the caps
        vm.startPrank(user2);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user2);
        vm.stopPrank();

        // Verify new position was created
        assertEq(convertibles.lastId(), 2);
        assertEq(convertibles.ownerOf(2), user2);
    }

    function testSplitRespectsCaps() public {
        vm.startPrank(owner);
        convertibles.setVariables(
            0.05e18, // minConversionPremium: 5%
            0.2e18, // maxConversionPremium: 20%
            uint256(0.01e18) / (365 * 86400), // minFixedInterestPerSecond: 0.1% per day
            uint256(0.05e18) / (365 * 86400), // maxFixedInterestPerSecond: 0.5% per day
            1000e18, // supplyCap: 1000 RZR (large enough for one stake)
            STAKE_AMOUNT // debtCap: exactly one stake
        );
        vm.stopPrank();

        // Stake
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user1);
        vm.stopPrank();

        // Split should succeed since total amounts don't change
        vm.startPrank(user1);
        convertibles.split(1, 0.5e18); // Split 50%
        vm.stopPrank();

        // Verify split worked
        assertEq(convertibles.lastId(), 2);
        assertEq(convertibles.ownerOf(1), user1);
        assertEq(convertibles.ownerOf(2), user1);

        // Total staked should remain the same
        assertEq(convertibles.totalStaked(), STAKE_AMOUNT);

        // Total convertible should remain the same (approximately)
        // Get the actual conversion amounts from both positions
        IAppConvertibles.Position memory position1 = convertibles.positions(1);
        IAppConvertibles.Position memory position2 = convertibles.positions(2);
        assertEq(convertibles.totalConvertible(), position1.amountConvertible + position2.amountConvertible);
    }

    function testCapsWithDifferentLockDurations() public {
        // Set caps that allow exactly one 4-year stake
        vm.startPrank(owner);
        convertibles.setVariables(
            0.05e18, // minConversionPremium: 5%
            0.2e18, // maxConversionPremium: 20%
            uint256(0.01e18) / (365 * 86400), // minFixedInterestPerSecond: 0.1% per day
            uint256(0.05e18) / (365 * 86400), // maxFixedInterestPerSecond: 0.5% per day
            1000e18, // supplyCap: 1000 RZR (large enough for one 4-year stake)
            STAKE_AMOUNT // debtCap: exactly one stake
        );
        vm.stopPrank();

        // 4-year stake should succeed
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_4_YEARS, user1);
        vm.stopPrank();

        // 30-day stake should fail due to debt cap (not supply cap)
        vm.startPrank(user2);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        vm.expectRevert("Debt cap reached");
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user2);
        vm.stopPrank();

        // 1-year stake should fail due to debt cap
        vm.startPrank(user3);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        vm.expectRevert("Debt cap reached");
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_1_YEAR, user3);
        vm.stopPrank();

        // Verify only one position was created
        assertEq(convertibles.lastId(), 1);
        assertEq(convertibles.ownerOf(1), user1);
    }

    function testCapsWithZeroValues() public {
        // Test that zero caps mean no limits
        vm.startPrank(owner);
        convertibles.setVariables(
            0.05e18, // minConversionPremium: 5%
            0.2e18, // maxConversionPremium: 20%
            uint256(0.01e18) / (365 * 86400), // minFixedInterestPerSecond: 0.1% per day
            uint256(0.05e18) / (365 * 86400), // maxFixedInterestPerSecond: 0.5% per day
            0, // supplyCap: 0 (no cap)
            0 // debtCap: 0 (no cap)
        );
        vm.stopPrank();

        // Multiple stakes should succeed
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT * 3);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user1);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_1_YEAR, user1);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_4_YEARS, user1);
        vm.stopPrank();

        // Verify all positions were created
        assertEq(convertibles.lastId(), 3);
        assertEq(convertibles.ownerOf(1), user1);
        assertEq(convertibles.ownerOf(2), user1);
        assertEq(convertibles.ownerOf(3), user1);
    }

    // ============ STAKE TESTS ============

    function testStakeBasic() public {
        uint256 user1BalanceBefore = loanToken.balanceOf(user1);
        uint256 convertiblesBalanceBefore = loanToken.balanceOf(address(convertibles));
        uint256 lastIdBefore = convertibles.lastId();

        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);

        // Don't expect exact event values since they depend on oracle prices
        vm.expectEmit(true, true, false, false);
        emit IAppConvertibles.Staked(user1, 1, STAKE_AMOUNT, 0, LOCK_DURATION_30_DAYS, 0, 0, 0);

        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user1);
        vm.stopPrank();

        // Check balances
        assertEq(loanToken.balanceOf(user1), user1BalanceBefore - STAKE_AMOUNT);
        assertEq(loanToken.balanceOf(address(convertibles)), convertiblesBalanceBefore + STAKE_AMOUNT);

        // Check position
        IAppConvertibles.Position memory position = convertibles.positions(1);
        assertEq(position.amountStaked, STAKE_AMOUNT);
        assertGt(position.amountConvertible, 0);
        assertGt(position.fixedInterestRate, 0);
        assertEq(position.lockDuration, LOCK_DURATION_30_DAYS);
        assertEq(position.lockStartTime, block.timestamp);
        assertGt(position.priceConversion, 0);
        assertGt(position.priceEntry, 0);

        // Check totals
        assertEq(convertibles.totalStaked(), STAKE_AMOUNT);
        assertEq(convertibles.totalConvertible(), position.amountConvertible);
        assertEq(convertibles.lastId(), lastIdBefore + 1);

        // Check NFT ownership
        assertEq(convertibles.ownerOf(1), user1);
    }

    function testStakeWithDifferentLockDurations() public {
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT * 3);

        // Stake with 30 days lock
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user1);
        IAppConvertibles.Position memory position30Days = convertibles.positions(1);

        // Stake with 1 year lock
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_1_YEAR, user1);
        IAppConvertibles.Position memory position1Year = convertibles.positions(2);

        // Stake with 4 years lock
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_4_YEARS, user1);
        IAppConvertibles.Position memory position4Years = convertibles.positions(3);

        vm.stopPrank();

        // Longer lock duration should give higher interest rate
        assertGt(position1Year.fixedInterestRate, position30Days.fixedInterestRate);
        assertGt(position4Years.fixedInterestRate, position1Year.fixedInterestRate);

        // Longer lock duration should give lower conversion premium (better conversion price)
        assertLt(position1Year.priceConversion, position30Days.priceConversion);
        assertLt(position4Years.priceConversion, position1Year.priceConversion);
    }

    function testStakeInvalidLockDuration() public {
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);

        // Too short lock duration
        vm.expectRevert("Invalid lock duration");
        convertibles.stake(STAKE_AMOUNT, 29 days, user1);

        // Too long lock duration
        vm.expectRevert("Invalid lock duration");
        convertibles.stake(STAKE_AMOUNT, 4 * 365 days + 1, user1);

        vm.stopPrank();
    }

    function testStakeInsufficientAllowance() public {
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT - 1);

        vm.expectRevert();
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user1);

        vm.stopPrank();
    }

    // ============ GET OFFERINGS TESTS ============

    function testGetOfferings() public view {
        (uint256 conversionPrice, uint256 conversionAmount, uint256 fixedInterestRate) =
            convertibles.getOfferings(STAKE_AMOUNT, LOCK_DURATION_30_DAYS);

        assertGt(conversionPrice, 0);
        assertGt(conversionAmount, 0);
        assertGt(fixedInterestRate, 0);

        // Test with different lock durations
        (uint256 price30,, uint256 interest30) = convertibles.getOfferings(STAKE_AMOUNT, LOCK_DURATION_30_DAYS);
        (uint256 price1Y,, uint256 interest1Y) = convertibles.getOfferings(STAKE_AMOUNT, LOCK_DURATION_1_YEAR);
        (uint256 price4Y,, uint256 interest4Y) = convertibles.getOfferings(STAKE_AMOUNT, LOCK_DURATION_4_YEARS);

        // Longer duration = higher interest rate
        assertGt(interest1Y, interest30);
        assertGt(interest4Y, interest1Y);

        // Longer duration = lower conversion premium (better price)
        assertLt(price1Y, price30);
        assertLt(price4Y, price1Y);
    }

    // ============ CONVERT TESTS ============

    function testConvert() public {
        // First stake
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user1);
        vm.stopPrank();

        // Wait for minimum lock duration
        vm.warp(block.timestamp + LOCK_DURATION_30_DAYS + 1);

        // Set TWAP price higher than conversion price
        twapOracle.setPrice(0, 10 * 1e18); // 1000% higher to ensure conversion
        twapOracle.touchTimestamp(); // Update timestamp to avoid staleness
        oracle.touchTimestamp(); // Also update main oracle timestamp

        uint256 user1RzrBalanceBefore = rzr.balanceOf(user1);
        uint256 treasuryBalanceBefore = loanToken.balanceOf(owner);
        uint256 totalStakedBefore = convertibles.totalStaked();
        uint256 totalConvertibleBefore = convertibles.totalConvertible();

        vm.startPrank(user1);

        convertibles.convert(1);
        vm.stopPrank();

        // Check balances
        assertGt(rzr.balanceOf(user1), user1RzrBalanceBefore);
        assertEq(loanToken.balanceOf(owner), treasuryBalanceBefore + STAKE_AMOUNT);

        // Check totals
        assertEq(convertibles.totalStaked(), totalStakedBefore - STAKE_AMOUNT);
        assertLt(convertibles.totalConvertible(), totalConvertibleBefore);

        // Check position is burned
        vm.expectRevert();
        convertibles.ownerOf(1);
    }

    function testConvertBeforeMinimumLockDuration() public {
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user1);
        vm.stopPrank();

        // Try to convert before minimum lock duration
        vm.warp(block.timestamp + LOCK_DURATION_30_DAYS - 1);

        // Update oracle timestamps to avoid staleness
        oracle.touchTimestamp();
        twapOracle.touchTimestamp();

        vm.startPrank(user1);
        vm.expectRevert("Not enough time passed");
        convertibles.convert(1);
        vm.stopPrank();
    }

    function testConvertInvalidPrice() public {
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user1);
        vm.stopPrank();

        vm.warp(block.timestamp + LOCK_DURATION_30_DAYS + 1);

        // Set TWAP price lower than conversion price
        IAppConvertibles.Position memory position = convertibles.positions(1);
        twapOracle.setPrice(0, position.priceConversion / 2); // 50% lower to avoid overflow
        twapOracle.touchTimestamp(); // Update timestamp to avoid staleness
        oracle.touchTimestamp(); // Also update main oracle timestamp

        vm.startPrank(user1);
        vm.expectRevert("Invalid conversion price");
        convertibles.convert(1);
        vm.stopPrank();
    }

    function testConvertNotOwner() public {
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user1);
        vm.stopPrank();

        vm.warp(block.timestamp + LOCK_DURATION_30_DAYS + 1);

        vm.startPrank(user2);
        vm.expectRevert("Not owner or approved");
        convertibles.convert(1);
        vm.stopPrank();
    }

    // ============ REDEEM TESTS ============

    function testRedeem() public {
        // First stake
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user1);
        vm.stopPrank();

        // Wait for minimum lock duration
        vm.warp(block.timestamp + LOCK_DURATION_30_DAYS + 1);

        // Update oracle timestamps to avoid staleness
        oracle.touchTimestamp();
        twapOracle.touchTimestamp();

        // Ensure loan token has enough balance by adding more underlying tokens
        vm.startPrank(owner);
        underlyingToken.mint(address(loanToken), 10000e18);
        loanToken.updateExchangeRate(); // Update exchange rate to reflect new assets
        vm.stopPrank();

        uint256 user1BalanceBefore = loanToken.balanceOf(user1);
        uint256 totalStakedBefore = convertibles.totalStaked();
        uint256 totalConvertibleBefore = convertibles.totalConvertible();

        // send some loan tokens to the contract to test redeeming
        vm.prank(owner);
        loanToken.transfer(address(convertibles), 1000000e18); // Much more tokens to cover higher interest

        vm.startPrank(user1);
        convertibles.redeem(1);
        vm.stopPrank();

        // Check balances - should receive staked amount + interest
        assertGt(loanToken.balanceOf(user1), user1BalanceBefore + STAKE_AMOUNT);

        // Check totals
        assertEq(convertibles.totalStaked(), totalStakedBefore - STAKE_AMOUNT);
        assertLt(convertibles.totalConvertible(), totalConvertibleBefore);

        // Check position is burned
        vm.expectRevert();
        convertibles.ownerOf(1);
    }

    function testRedeemBeforeMinimumLockDuration() public {
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user1);
        vm.stopPrank();

        // Try to redeem before minimum lock duration
        vm.warp(block.timestamp + LOCK_DURATION_30_DAYS - 1);

        vm.startPrank(user1);
        vm.expectRevert("Not enough time passed");
        convertibles.redeem(1);
        vm.stopPrank();
    }

    function testRedeemNotOwner() public {
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user1);
        vm.stopPrank();

        vm.warp(block.timestamp + LOCK_DURATION_30_DAYS + 1);

        vm.startPrank(user2);
        vm.expectRevert("Not owner or approved");
        convertibles.redeem(1);
        vm.stopPrank();
    }

    // ============ SPLIT TESTS ============

    function testSplit() public {
        // First stake
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user1);
        vm.stopPrank();

        uint256 lastIdBefore = convertibles.lastId();
        uint256 totalStakedBefore = convertibles.totalStaked();
        uint256 totalConvertibleBefore = convertibles.totalConvertible();

        vm.startPrank(user1);

        // Don't expect exact event values since they depend on oracle prices
        vm.expectEmit(true, true, true, false);
        emit IAppConvertibles.PositionSplit(user1, 1, 2, STAKE_AMOUNT, 0, 0, 0, 0.5e18);

        convertibles.split(1, 0.5e18); // Split 50%
        vm.stopPrank();

        // Check original position
        IAppConvertibles.Position memory position1 = convertibles.positions(1);
        IAppConvertibles.Position memory position2 = convertibles.positions(2);
        assertEq(position1.amountStaked, STAKE_AMOUNT / 2);
        assertApproxEqRel(position1.amountConvertible, position2.amountConvertible, 1e15); // Allow 0.1% tolerance
        assertApproxEqRel(position1.fixedInterestRate, position2.fixedInterestRate, 1e15); // Allow 0.1% tolerance

        // Check new position
        assertEq(position2.amountStaked, STAKE_AMOUNT / 2);
        assertApproxEqRel(position2.amountConvertible, position1.amountConvertible, 1e15); // Allow 0.1% tolerance
        assertApproxEqRel(position2.fixedInterestRate, position1.fixedInterestRate, 1e15); // Allow 0.1% tolerance
        assertEq(position2.priceConversion, position1.priceConversion);

        // Check totals unchanged
        assertEq(convertibles.totalStaked(), totalStakedBefore);
        assertEq(convertibles.totalConvertible(), totalConvertibleBefore);
        assertEq(convertibles.lastId(), lastIdBefore + 1);

        // Check NFT ownership
        assertEq(convertibles.ownerOf(1), user1);
        assertEq(convertibles.ownerOf(2), user1);
    }

    function testSplitInvalidPercentage() public {
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user1);
        vm.stopPrank();

        vm.startPrank(user1);

        // 0% split
        vm.expectRevert("Invalid percentage");
        convertibles.split(1, 0);

        // 100% split
        vm.expectRevert("Invalid percentage");
        convertibles.split(1, 1e18);

        vm.stopPrank();
    }

    function testSplitNotOwner() public {
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user1);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert("Not owner or approved");
        convertibles.split(1, 0.5e18);
        vm.stopPrank();
    }

    // ============ INTEREST ACCRUAL TESTS ============

    function testInterestAccrual() public {
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user1);
        vm.stopPrank();

        // Wait for some time to accrue interest
        vm.warp(block.timestamp + 60 days);

        uint256 user1BalanceBefore = loanToken.balanceOf(user1);

        // send some loan tokens to the contract to test redeeming
        vm.prank(owner);
        loanToken.transfer(address(convertibles), 1000000e18); // Much more tokens to cover higher interest

        vm.startPrank(user1);
        convertibles.redeem(1);
        vm.stopPrank();

        // Should receive more than the original staked amount due to interest
        assertGt(loanToken.balanceOf(user1), user1BalanceBefore + STAKE_AMOUNT);
    }

    // ============ MULTI-YEAR CONVERTIBLE TESTS ============

    function testMultiYearConvertibleInterest() public {
        // Set up a specific interest rate for testing
        vm.startPrank(owner);
        convertibles.setVariables(
            0.05e18, // minConversionPremium: 5%
            0.2e18, // maxConversionPremium: 20%
            0.1e18, // minFixedInterestRate: 10% / year
            0.1e18, // maxFixedInterestRate: 10% / year (same as min for consistent testing)
            0, // supplyCap: 0 (no cap)
            0 // debtCap: 0 (no cap)
        );
        vm.stopPrank();

        uint256 stakeAmount = 1000e18; // 1000 loan tokens
        uint256 lockDuration = LOCK_DURATION_4_YEARS; // 4 years

        // Add tokens to contract for redemption
        vm.startPrank(owner);
        loanToken.transfer(address(convertibles), 100000e18);
        vm.stopPrank();

        // Stake tokens
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), stakeAmount);
        convertibles.stake(stakeAmount, lockDuration, user1);
        vm.stopPrank();

        // Get position details
        IAppConvertibles.Position memory position = convertibles.positions(1);
        assertEq(position.amountStaked, stakeAmount);
        assertEq(position.fixedInterestRate, 0.1e18); // Should be 10% per year
        assertEq(position.lockDuration, lockDuration);

        // Test 1: After 4 years, should have earned some interest
        vm.warp(block.timestamp + LOCK_DURATION_4_YEARS + 1);

        // Update oracle timestamps to avoid staleness
        oracle.touchTimestamp();
        twapOracle.touchTimestamp();

        uint256 balanceBefore1Year = loanToken.balanceOf(user1);
        vm.startPrank(user1);
        convertibles.redeem(1);
        vm.stopPrank();
        uint256 balanceAfter1Year = loanToken.balanceOf(user1);
        uint256 interestEarned1Year = balanceAfter1Year - balanceBefore1Year - stakeAmount;

        // Should have earned some interest
        assertGt(interestEarned1Year, 0);
    }

    function testMultiYearConvertiblePartialMaturity() public {
        // Set up a specific interest rate for testing
        vm.startPrank(owner);
        convertibles.setVariables(
            0.05e18, // minConversionPremium: 5%
            0.2e18, // maxConversionPremium: 20%
            0.1e18, // minFixedInterestRate: 10% / year
            0.1e18, // maxFixedInterestRate: 10% / year (same as min for consistent testing)
            0, // supplyCap: 0 (no cap)
            0 // debtCap: 0 (no cap)
        );
        vm.stopPrank();

        uint256 stakeAmount = 1000e18; // 1000 loan tokens
        uint256 lockDuration = LOCK_DURATION_4_YEARS; // 4 years

        // Test different time periods
        uint256[] memory timePeriods = new uint256[](5);
        timePeriods[0] = 3 * 30 days; // 3 mo
        timePeriods[1] = 9 * 30 days; // 1 year
        timePeriods[2] = 12 * 30 days; // 2 years
        timePeriods[3] = 12 * 30 days; // 3 years
        timePeriods[4] = 12 * 30 days - 1; // 4 years

        uint256[] memory interestEarned = new uint256[](5);

        // Add tokens to contract for redemption
        vm.startPrank(owner);
        // Transfer a smaller amount that the owner can afford
        loanToken.transfer(address(convertibles), 100000e18);
        vm.stopPrank();

        // Create a new position for each test
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), stakeAmount);
        convertibles.stake(stakeAmount, lockDuration, user1);
        vm.stopPrank();

        uint256 balanceBefore = loanToken.balanceOf(user1);

        for (uint256 i = 0; i < timePeriods.length; i++) {
            // Wait for the specified time period
            vm.warp(block.timestamp + timePeriods[i]);

            // Update oracle timestamps to avoid staleness
            oracle.touchTimestamp();
            twapOracle.touchTimestamp();

            vm.prank(user1);
            convertibles.claimInterest(1);
            uint256 balanceAfter = loanToken.balanceOf(user1);
            interestEarned[i] = balanceAfter - balanceBefore;

            // Should have earned some interest
            assertGt(interestEarned[i], 0);
        }

        // Verify that longer periods earn more interest
        assertGt(interestEarned[1], interestEarned[0], "1 year > 0.5 years"); // 1 year > 0.5 years
        assertGt(interestEarned[2], interestEarned[1], "2 years > 1 year"); // 2 years > 1 year
        assertGt(interestEarned[3], interestEarned[2], "3 years > 2 years"); // 3 years > 2 years
        assertGt(interestEarned[4], interestEarned[3], "4 years > 3 years"); // 4 years > 3 years

        // Verify that 4-year interest is approximately 4x the 1-year interest
        assertApproxEqRel(
            interestEarned[4],
            interestEarned[1] * 4,
            1e17,
            "4 years interest should be approximately 4x the 1-year interest"
        ); // 10% tolerance
    }

    function testMultiYearConvertibleDifferentRates() public {
        // Test with different interest rates
        uint256[] memory interestRates = new uint256[](3);
        interestRates[0] = 0.05e18; // 5% per year
        interestRates[1] = 0.15e18; // 15% per year
        interestRates[2] = 0.25e18; // 25% per year

        uint256 stakeAmount = 1000e18; // 1000 loan tokens
        uint256 lockDuration = LOCK_DURATION_4_YEARS; // 4 years

        uint256[] memory interestEarned = new uint256[](3);

        for (uint256 i = 0; i < interestRates.length; i++) {
            // Set the interest rate
            vm.startPrank(owner);
            convertibles.setVariables(
                0.05e18, // minConversionPremium: 5%
                0.2e18, // maxConversionPremium: 20%
                interestRates[i], // minFixedInterestRate
                interestRates[i], // maxFixedInterestRate (same as min for consistent testing)
                0, // supplyCap: 0 (no cap)
                0 // debtCap: 0 (no cap)
            );
            vm.stopPrank();

            // Stake tokens
            vm.startPrank(user1);
            loanToken.approve(address(convertibles), stakeAmount);
            convertibles.stake(stakeAmount, lockDuration, user1);
            vm.stopPrank();

            // Wait full 4 years
            vm.warp(block.timestamp + 4 * 365 days);

            // Update oracle timestamps to avoid staleness
            oracle.touchTimestamp();
            twapOracle.touchTimestamp();

            // Add tokens to contract for redemption
            vm.startPrank(owner);
            // Transfer a smaller amount that the owner can afford
            loanToken.transfer(address(convertibles), 100000e18);
            vm.stopPrank();

            uint256 balanceBefore = loanToken.balanceOf(user1);
            vm.startPrank(user1);
            convertibles.redeem(i + 1);
            vm.stopPrank();
            uint256 balanceAfter = loanToken.balanceOf(user1);
            interestEarned[i] = balanceAfter - balanceBefore - stakeAmount;

            // Should have earned some interest
            assertGt(interestEarned[i], 0);
        }

        // Verify that higher interest rates earn more interest
        assertGt(interestEarned[1], interestEarned[0]); // 15% > 5%
        assertGt(interestEarned[2], interestEarned[1]); // 25% > 15%

        // Verify that the ratio of interest earned is approximately proportional to interest rates
        // 15% should earn approximately 3x more than 5%
        assertApproxEqRel(interestEarned[1], interestEarned[0] * 3, 1e17); // 10% tolerance
        // 25% should earn approximately 5x more than 5%
        assertApproxEqRel(interestEarned[2], interestEarned[0] * 5, 1e17); // 10% tolerance
    }

    function testMultiYearConvertibleEarlyRedemption() public {
        // Set up a specific interest rate for testing
        vm.startPrank(owner);
        convertibles.setVariables(
            0.05e18, // minConversionPremium: 5%
            0.2e18, // maxConversionPremium: 20%
            0.1e18, // minFixedInterestRate: 10% / year
            0.1e18, // maxFixedInterestRate: 10% / year (same as min for consistent testing)
            0, // supplyCap: 0 (no cap)
            0 // debtCap: 0 (no cap)
        );
        vm.stopPrank();

        uint256 stakeAmount = 1000e18; // 1000 loan tokens
        uint256 lockDuration = LOCK_DURATION_4_YEARS; // 4 years

        // Stake tokens
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), stakeAmount);
        convertibles.stake(stakeAmount, lockDuration, user1);
        vm.stopPrank();

        // Test early redemption (before minimum lock duration)
        vm.warp(block.timestamp + LOCK_DURATION_4_YEARS - 1); // Just under 30 days minimum

        // Update oracle timestamps to avoid staleness
        oracle.touchTimestamp();
        twapOracle.touchTimestamp();

        vm.startPrank(user1);
        vm.expectRevert("Not enough time passed");
        convertibles.redeem(1);
        vm.stopPrank();

        // Test redemption right after minimum lock duration
        vm.warp(block.timestamp + 1); // Exactly 4yr

        // Update oracle timestamps to avoid staleness
        oracle.touchTimestamp();
        twapOracle.touchTimestamp();

        // Add tokens to contract for redemption
        vm.startPrank(owner);
        // Transfer a smaller amount that the owner can afford
        loanToken.transfer(address(convertibles), 100000e18);
        vm.stopPrank();

        uint256 balanceBefore = loanToken.balanceOf(user1);
        vm.startPrank(user1);
        convertibles.redeem(1);
        vm.stopPrank();
        uint256 balanceAfter = loanToken.balanceOf(user1);
        uint256 interestEarned = balanceAfter - balanceBefore - stakeAmount;

        // Should have earned some interest (30 days worth)
        assertGt(interestEarned, 0);

        // Create another position and test longer duration for comparison
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), stakeAmount);
        convertibles.stake(stakeAmount, lockDuration, user1);
        vm.stopPrank();

        // Wait 1 year
        vm.warp(block.timestamp + 365 days * 5);

        // Update oracle timestamps to avoid staleness
        oracle.touchTimestamp();
        twapOracle.touchTimestamp();

        balanceBefore = loanToken.balanceOf(user1);
        vm.startPrank(user1);
        convertibles.redeem(2);
        vm.stopPrank();
    }

    // ============ CLAIM INTEREST TESTS ============

    function testMultipleClaimInterestAcrossYears() public {
        // Set up a specific interest rate for testing
        vm.startPrank(owner);
        convertibles.setVariables(
            0.05e18, // minConversionPremium: 5%
            0.2e18, // maxConversionPremium: 20%
            0.1e18, // minFixedInterestRate: 10% / year
            0.1e18, // maxFixedInterestRate: 10% / year (same as min for consistent testing)
            0, // supplyCap: 0 (no cap)
            0 // debtCap: 0 (no cap)
        );
        vm.stopPrank();

        uint256 stakeAmount = 1000e18; // 1000 loan tokens
        uint256 lockDuration = LOCK_DURATION_4_YEARS; // 4 years

        // Add tokens to contract for interest claims
        vm.startPrank(owner);
        loanToken.transfer(address(convertibles), 100000e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 1);

        // Stake tokens
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), stakeAmount);
        convertibles.stake(stakeAmount, lockDuration, user1);
        vm.stopPrank();

        // Get position details
        IAppConvertibles.Position memory position = convertibles.positions(1);
        assertEq(position.amountStaked, stakeAmount);
        assertEq(position.fixedInterestRate, 0.1e18); // Should be 10% per year
        assertEq(position.fixedInterestClaimed, 0); // Should start with 0 claimed

        uint256 user1BalanceBefore = loanToken.balanceOf(user1);
        uint256[] memory interestClaimed = new uint256[](5);

        // Test 1: Claim interest after 3 months
        vm.warp(block.timestamp + 3 * 30 days); // 3 months

        // Update oracle timestamps to avoid staleness
        oracle.touchTimestamp();
        twapOracle.touchTimestamp();

        vm.startPrank(user1);
        (, interestClaimed[0]) = convertibles.claimInterest(1);
        vm.stopPrank();

        // Should have claimed some interest
        assertGt(interestClaimed[0], 0);
        assertGt(loanToken.balanceOf(user1), user1BalanceBefore);

        // Check position state
        position = convertibles.positions(1);
        assertGt(position.fixedInterestClaimed, 0);

        // Test 2: Claim interest after 1 year (wait another 9 months)
        vm.warp(block.timestamp + 9 * 30 days); // Another 9 months (total 1 year)

        // Update oracle timestamps to avoid staleness
        oracle.touchTimestamp();
        twapOracle.touchTimestamp();

        uint256 balanceBefore = loanToken.balanceOf(user1);
        vm.startPrank(user1);
        (, interestClaimed[1]) = convertibles.claimInterest(1);
        vm.stopPrank();

        // Should have claimed more interest
        assertGt(interestClaimed[1], 0);
        assertGt(loanToken.balanceOf(user1), balanceBefore);

        // Test 3: Claim interest after 2 years (wait another year)
        vm.warp(block.timestamp + 365 days); // Another year (total 2 years)

        // Update oracle timestamps to avoid staleness
        oracle.touchTimestamp();
        twapOracle.touchTimestamp();

        balanceBefore = loanToken.balanceOf(user1);
        vm.startPrank(user1);
        (, interestClaimed[2]) = convertibles.claimInterest(1);
        vm.stopPrank();

        // Should have claimed more interest
        assertGt(interestClaimed[2], 0);
        assertGt(loanToken.balanceOf(user1), balanceBefore);

        // Test 4: Claim interest after 3 years (wait another year)
        vm.warp(block.timestamp + 365 days); // Another year (total 3 years)

        // Update oracle timestamps to avoid staleness
        oracle.touchTimestamp();
        twapOracle.touchTimestamp();

        balanceBefore = loanToken.balanceOf(user1);
        vm.startPrank(user1);
        (, interestClaimed[3]) = convertibles.claimInterest(1);
        vm.stopPrank();

        // Should have claimed more interest
        assertGt(interestClaimed[3], 0);
        assertGt(loanToken.balanceOf(user1), balanceBefore);

        // Test 5: Claim interest after 4 years (wait another year)
        vm.warp(block.timestamp + 365 days); // Another year (total 4 years)

        // Update oracle timestamps to avoid staleness
        oracle.touchTimestamp();
        twapOracle.touchTimestamp();

        balanceBefore = loanToken.balanceOf(user1);
        vm.startPrank(user1);
        (, interestClaimed[4]) = convertibles.claimInterest(1);
        vm.stopPrank();

        // Should have claimed more interest
        assertGt(interestClaimed[4], 0);
        assertGt(loanToken.balanceOf(user1), balanceBefore);

        // Test 6: Try to claim interest again immediately (should fail)
        vm.startPrank(user1);
        vm.expectRevert("No interest to claim");
        convertibles.claimInterest(1);
        vm.stopPrank();

        // Verify that longer periods earn more interest
        assertGt(interestClaimed[1], interestClaimed[0], "1 year > 3 months"); // 1 year > 3 months
        assertGt(interestClaimed[2], interestClaimed[1], "2 years > 1 year"); // 2 years > 1 year
        assertGt(interestClaimed[3], interestClaimed[2], "3 years > 2 years"); // 3 years > 2 years
        assertGt(interestClaimed[4], interestClaimed[3], "4 years > 3 years"); // 4 years > 3 years

        // Verify that the total interest claimed is approximately proportional to time
        uint256 totalInterestClaimed =
            interestClaimed[0] + interestClaimed[1] + interestClaimed[2] + interestClaimed[3] + interestClaimed[4];
        // The total should be greater than 0 and proportional to the 4-year period
        assertGt(totalInterestClaimed, 0);
        // Verify that each claim earned some interest
        assertGt(interestClaimed[0], 0, "3 months interest should be greater than 0");
        assertGt(interestClaimed[1], 0, "1 year interest should be greater than 0");
        assertGt(interestClaimed[2], 0, "2 years interest should be greater than 0");
        assertGt(interestClaimed[3], 0, "3 years interest should be greater than 0");
        assertGt(interestClaimed[4], 0, "4 years interest should be greater than 0");
    }

    function testClaimInterestWithDifferentRates() public {
        // Test with different interest rates
        uint256[] memory interestRates = new uint256[](3);
        interestRates[0] = 0.05e18; // 5% per year
        interestRates[1] = 0.15e18; // 15% per year
        interestRates[2] = 0.25e18; // 25% per year

        uint256 stakeAmount = 1000e18; // 1000 loan tokens
        uint256 lockDuration = LOCK_DURATION_4_YEARS; // 4 years

        // Add tokens to contract for interest claims
        vm.startPrank(owner);
        loanToken.transfer(address(convertibles), 100000e18);
        vm.stopPrank();

        uint256[] memory totalInterestClaimed = new uint256[](3);

        for (uint256 i = 0; i < interestRates.length; i++) {
            // Set the interest rate
            vm.startPrank(owner);
            convertibles.setVariables(
                0.05e18, // minConversionPremium: 5%
                0.2e18, // maxConversionPremium: 20%
                interestRates[i], // minFixedInterestRate
                interestRates[i], // maxFixedInterestRate (same as min for consistent testing)
                0, // supplyCap: 0 (no cap)
                0 // debtCap: 0 (no cap)
            );
            vm.stopPrank();

            // Stake tokens
            vm.startPrank(user1);
            loanToken.approve(address(convertibles), stakeAmount);
            convertibles.stake(stakeAmount, lockDuration, user1);
            vm.stopPrank();

            // Wait 2 years
            vm.warp(block.timestamp + 2 * 365 days);

            // Update oracle timestamps to avoid staleness
            oracle.touchTimestamp();
            twapOracle.touchTimestamp();

            // Claim interest
            vm.startPrank(user1);
            (totalInterestClaimed[i],) = convertibles.claimInterest(i + 1);
            vm.stopPrank();

            // Should have claimed some interest
            assertGt(totalInterestClaimed[i], 0);
        }

        // Verify that higher interest rates earn more interest
        assertGt(totalInterestClaimed[1], totalInterestClaimed[0]); // 15% > 5%
        assertGt(totalInterestClaimed[2], totalInterestClaimed[1]); // 25% > 15%

        // Verify that the ratio of interest earned is approximately proportional to interest rates
        // 15% should earn approximately 3x more than 5%
        assertApproxEqRel(totalInterestClaimed[1], totalInterestClaimed[0] * 3, 1e17); // 10% tolerance
        // 25% should earn approximately 5x more than 5%
        assertApproxEqRel(totalInterestClaimed[2], totalInterestClaimed[0] * 5, 1e17); // 10% tolerance
    }

    function testClaimInterestPartialPeriods() public {
        // Set up a specific interest rate for testing
        vm.startPrank(owner);
        convertibles.setVariables(
            0.05e18, // minConversionPremium: 5%
            0.2e18, // maxConversionPremium: 20%
            0.1e18, // minFixedInterestRate: 10% / year
            0.1e18, // maxFixedInterestRate: 10% / year (same as min for consistent testing)
            0, // supplyCap: 0 (no cap)
            0 // debtCap: 0 (no cap)
        );
        vm.stopPrank();

        uint256 stakeAmount = 1000e18; // 1000 loan tokens
        uint256 lockDuration = LOCK_DURATION_4_YEARS; // 4 years

        // Add tokens to contract for interest claims
        vm.startPrank(owner);
        loanToken.transfer(address(convertibles), 100000e18);
        vm.stopPrank();

        // Stake tokens
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), stakeAmount);
        convertibles.stake(stakeAmount, lockDuration, user1);
        vm.stopPrank();

        // Test different time periods
        uint256[] memory timePeriods = new uint256[](5);
        timePeriods[0] = 2 * 30 days; // 2 months
        timePeriods[1] = 4 * 30 days; // 6 months
        timePeriods[2] = 6 * 30 days; // 12 months
        timePeriods[3] = 12 * 30 days; // 24 months
        timePeriods[4] = 24 * 30 days; // 48 months

        uint256[] memory interestClaimed = new uint256[](5);

        for (uint256 i = 0; i < timePeriods.length; i++) {
            // Wait for the specified time period
            vm.warp(block.timestamp + timePeriods[i]);

            // Update oracle timestamps to avoid staleness
            oracle.touchTimestamp();
            twapOracle.touchTimestamp();

            // Claim interest
            vm.startPrank(user1);
            (interestClaimed[i],) = convertibles.claimInterest(1);
            vm.stopPrank();

            // Should have claimed some interest
            assertGt(interestClaimed[i], 0);
        }

        // Verify that longer periods earn more interest
        assertGt(interestClaimed[1], interestClaimed[0], "6 months > 2 months"); // 4 months > 2 months
        assertGt(interestClaimed[2], interestClaimed[1], "14 months > 6 months"); // 8 months > 4 months
        assertGt(interestClaimed[3], interestClaimed[2], "30 months > 14 months"); // 16 months > 8 months
        assertGt(interestClaimed[4], interestClaimed[3], "48 months > 30 months"); // 32 months > 16 months

        // Verify that 32-month interest is approximately 4x the 8-month interest
        assertApproxEqRel(
            interestClaimed[4],
            interestClaimed[2] * 4,
            1e17,
            "48 months interest should be approximately 4x the 12 months interest"
        ); // 10% tolerance
    }

    function testClaimInterestEdgeCases() public {
        // Set up a specific interest rate for testing
        vm.startPrank(owner);
        convertibles.setVariables(
            0.05e18, // minConversionPremium: 5%
            0.2e18, // maxConversionPremium: 20%
            0.1e18, // minFixedInterestRate: 10% / year
            0.1e18, // maxFixedInterestRate: 10% / year (same as min for consistent testing)
            0, // supplyCap: 0 (no cap)
            0 // debtCap: 0 (no cap)
        );
        vm.stopPrank();

        uint256 stakeAmount = 1000e18; // 1000 loan tokens
        uint256 lockDuration = LOCK_DURATION_4_YEARS; // 4 years

        // Add tokens to contract for interest claims
        vm.startPrank(owner);
        loanToken.transfer(address(convertibles), 100000e18);
        vm.stopPrank();

        // Stake tokens
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), stakeAmount);
        convertibles.stake(stakeAmount, lockDuration, user1);
        vm.stopPrank();

        // Test 1: Try to claim interest immediately (should fail)
        vm.startPrank(user1);
        vm.expectRevert("No interest to claim");
        convertibles.claimInterest(1);
        vm.stopPrank();

        // Test 2: Try to claim interest for non-existent position (should fail)
        vm.startPrank(user1);
        vm.expectRevert("Position does not exist");
        convertibles.claimInterest(999);
        vm.stopPrank();

        // Test 3: Try to claim interest from another user's position (should fail)
        vm.startPrank(user2);
        vm.expectRevert("No interest to claim");
        convertibles.claimInterest(1);
        vm.stopPrank();

        // Test 4: Claim interest after minimum time
        vm.warp(block.timestamp + 30 days); // Minimum lock duration

        // Update oracle timestamps to avoid staleness
        oracle.touchTimestamp();
        twapOracle.touchTimestamp();

        vm.startPrank(user1);
        (uint256 interestClaimed,) = convertibles.claimInterest(1);
        vm.stopPrank();

        // Should have claimed some interest
        assertGt(interestClaimed, 0);

        // Test 5: Try to claim interest again immediately (should fail)
        vm.startPrank(user1);
        vm.expectRevert("No interest to claim");
        convertibles.claimInterest(1);
        vm.stopPrank();

        // Test 6: Wait and claim interest again
        vm.warp(block.timestamp + 30 days); // Another 30 days

        // Update oracle timestamps to avoid staleness
        oracle.touchTimestamp();
        twapOracle.touchTimestamp();

        vm.startPrank(user1);
        (uint256 interestClaimed2,) = convertibles.claimInterest(1);
        vm.stopPrank();

        // Should have claimed more interest
        assertGt(interestClaimed2, 0);
    }

    function testClaimInterestAfterPositionTransfer() public {
        // Set up a specific interest rate for testing
        vm.startPrank(owner);
        convertibles.setVariables(
            0.05e18, // minConversionPremium: 5%
            0.2e18, // maxConversionPremium: 20%
            0.1e18, // minFixedInterestRate: 10% / year
            0.1e18, // maxFixedInterestRate: 10% / year (same as min for consistent testing)
            0, // supplyCap: 0 (no cap)
            0 // debtCap: 0 (no cap)
        );
        vm.stopPrank();

        uint256 stakeAmount = 1000e18; // 1000 loan tokens
        uint256 lockDuration = LOCK_DURATION_4_YEARS; // 4 years

        // Add tokens to contract for interest claims
        vm.startPrank(owner);
        loanToken.transfer(address(convertibles), 100000e18);
        vm.stopPrank();

        // Stake tokens
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), stakeAmount);
        convertibles.stake(stakeAmount, lockDuration, user1);
        vm.stopPrank();

        // Wait some time and claim interest
        vm.warp(block.timestamp + 365 days); // 1 year

        // Update oracle timestamps to avoid staleness
        oracle.touchTimestamp();
        twapOracle.touchTimestamp();

        vm.startPrank(user1);
        convertibles.claimInterest(1);
        vm.stopPrank();

        // Transfer position to user2
        vm.startPrank(user1);
        convertibles.transferFrom(user1, user2, 1);
        vm.stopPrank();

        // Wait more time
        vm.warp(block.timestamp + 365 days); // Another year

        // Update oracle timestamps to avoid staleness
        oracle.touchTimestamp();
        twapOracle.touchTimestamp();

        // User2 should be able to claim interest
        uint256 user2BalanceBefore = loanToken.balanceOf(user2);
        vm.startPrank(user2);
        (uint256 interestClaimed2,) = convertibles.claimInterest(1);
        vm.stopPrank();

        // Should have claimed interest
        assertGt(interestClaimed2, 0);
        assertGt(loanToken.balanceOf(user2), user2BalanceBefore);

        // User1 should not be able to claim interest anymore
        vm.startPrank(user1);
        vm.expectRevert("No interest to claim");
        convertibles.claimInterest(1);
        vm.stopPrank();
    }

    // ============ NFT TRANSFER TESTS ============

    function testNFTTransfer() public {
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user1);
        vm.stopPrank();

        uint256 user1TrackingBefore = loanTrackingToken.balanceOf(user1);
        uint256 user2TrackingBefore = loanTrackingToken.balanceOf(user2);

        vm.startPrank(user1);

        // Don't expect exact event values since they depend on oracle prices
        vm.expectEmit(true, true, true, false);
        emit IAppConvertibles.PositionTransferred(user1, user2, 1, STAKE_AMOUNT, 0);

        convertibles.transferFrom(user1, user2, 1);
        vm.stopPrank();

        // Check NFT ownership transferred
        assertEq(convertibles.ownerOf(1), user2);

        // Check tracking tokens transferred
        assertEq(loanTrackingToken.balanceOf(user1), user1TrackingBefore - STAKE_AMOUNT);
        assertEq(loanTrackingToken.balanceOf(user2), user2TrackingBefore + STAKE_AMOUNT);
    }

    // ============ EDGE CASES ============

    function testStakeWithZeroAmount() public {
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), 0);
        vm.expectRevert();
        convertibles.stake(0, LOCK_DURATION_30_DAYS, user1);
        vm.stopPrank();
    }

    function testConvertNonExistentPosition() public {
        vm.startPrank(user1);
        vm.expectRevert();
        convertibles.convert(999);
        vm.stopPrank();
    }

    function testRedeemNonExistentPosition() public {
        vm.startPrank(user1);
        vm.expectRevert();
        convertibles.redeem(999);
        vm.stopPrank();
    }

    function testSplitNonExistentPosition() public {
        vm.startPrank(user1);
        vm.expectRevert();
        convertibles.split(999, 0.5e18);
        vm.stopPrank();
    }

    // ============ INTEGRATION TESTS ============

    function testFullLifecycle() public {
        // 1. User stakes tokens
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user1);
        vm.stopPrank();

        // 2. User splits position
        vm.startPrank(user1);
        convertibles.split(1, 0.3e18); // Split 30%
        vm.stopPrank();

        // 3. Wait for minimum lock duration
        vm.warp(block.timestamp + LOCK_DURATION_30_DAYS + 1);

        // 4. User converts one position
        twapOracle.setPrice(0, 10 * 1e18);
        twapOracle.touchTimestamp(); // Update timestamp to avoid staleness

        vm.startPrank(user1);
        convertibles.convert(1);
        vm.stopPrank();

        // Put some loan tokens in the contract to test redeeming
        vm.prank(owner);
        loanToken.transfer(address(convertibles), 1000000e18); // Much more tokens to cover higher interest

        // 5. User redeems the other position
        vm.startPrank(user1);
        convertibles.redeem(2);
        vm.stopPrank();

        // Verify final state
        assertEq(convertibles.totalStaked(), 0);
        assertEq(convertibles.totalConvertible(), 0);
        assertEq(convertibles.lastId(), 2);
    }

    function testMultipleUsers() public {
        // User 1 stakes
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_30_DAYS, user1);
        vm.stopPrank();

        // User 2 stakes
        vm.startPrank(user2);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_1_YEAR, user2);
        vm.stopPrank();

        // User 3 stakes
        vm.startPrank(user3);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_4_YEARS, user3);
        vm.stopPrank();

        // Check totals
        assertEq(convertibles.totalStaked(), STAKE_AMOUNT * 3);
        assertGt(convertibles.totalConvertible(), 0);
        assertEq(convertibles.lastId(), 3);

        // Check ownership
        assertEq(convertibles.ownerOf(1), user1);
        assertEq(convertibles.ownerOf(2), user2);
        assertEq(convertibles.ownerOf(3), user3);
    }

    // ============ INTEREST CALCULATION TESTS ============

    function testInterestCalculationPerSecond() public {
        // Create a position with known interest rate
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_1_YEAR, user1);
        vm.stopPrank();

        // Get position details
        IAppConvertibles.Position memory position = convertibles.positions(1);
        uint256 interestRatePerSecond = position.fixedInterestRate;

        console.log("Interest rate per second (stored):", interestRatePerSecond);
        console.log("Interest rate per year (calculated):", interestRatePerSecond * 365 days);

        // Test interest after 1 second
        vm.warp(block.timestamp + 1);
        (uint256 interestClaimable,) = convertibles.claimableInterest(1);

        console.log("Interest after 1 second:", interestClaimable);

        // The actual formula is: interestEarnedPerSecond = amount * interestRatePerSecond / 1e18 / 365 days
        // Then: interest = interestEarnedPerSecond * timeElapsed
        uint256 interestEarnedPerSecond = STAKE_AMOUNT * interestRatePerSecond / 1e18 / 365 days;
        uint256 expectedInterest = interestEarnedPerSecond * 1;

        console.log("Expected interest after 1 second:", expectedInterest);

        // Verify the calculation matches our expected formula
        assertApproxEqRel(interestClaimable, expectedInterest, 0.01e18); // 1% tolerance
    }

    function testInterestCalculationPerHour() public {
        // Create a position
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_1_YEAR, user1);
        vm.stopPrank();

        // Get position details
        IAppConvertibles.Position memory position = convertibles.positions(1);
        uint256 interestRatePerSecond = position.fixedInterestRate;

        // Test interest after 1 hour
        vm.warp(block.timestamp + 1 hours);
        (uint256 interestClaimable,) = convertibles.claimableInterest(1);

        console.log("Interest after 1 hour:", interestClaimable);

        // The actual formula: interestEarnedPerSecond = amount * interestRatePerSecond / 1e18 / 365 days
        uint256 interestEarnedPerSecond = STAKE_AMOUNT * interestRatePerSecond / 1e18 / 365 days;
        uint256 expectedInterest = interestEarnedPerSecond * 3600;

        console.log("Expected interest after 1 hour:", expectedInterest);

        // Verify the calculation
        assertApproxEqRel(interestClaimable, expectedInterest, 0.01e18); // 1% tolerance
    }

    function testInterestCalculationPerDay() public {
        // Create a position
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_1_YEAR, user1);
        vm.stopPrank();

        // Get position details
        IAppConvertibles.Position memory position = convertibles.positions(1);
        uint256 interestRatePerSecond = position.fixedInterestRate;

        // Test interest after 1 day
        vm.warp(block.timestamp + 1 days);
        (uint256 interestClaimable,) = convertibles.claimableInterest(1);

        console.log("Interest after 1 day:", interestClaimable);

        // The actual formula: interestEarnedPerSecond = amount * interestRatePerSecond / 1e18 / 365 days
        uint256 interestEarnedPerSecond = STAKE_AMOUNT * interestRatePerSecond / 1e18 / 365 days;
        uint256 expectedInterest = interestEarnedPerSecond * 86400;

        console.log("Expected interest after 1 day:", expectedInterest);

        // Verify the calculation
        assertApproxEqRel(interestClaimable, expectedInterest, 0.01e18); // 1% tolerance
    }

    function testInterestCalculationPerMonth() public {
        // Create a position
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_1_YEAR, user1);
        vm.stopPrank();

        // Get position details
        IAppConvertibles.Position memory position = convertibles.positions(1);
        uint256 interestRatePerSecond = position.fixedInterestRate;

        // Test interest after 30 days (approximately 1 month)
        vm.warp(block.timestamp + 30 days);
        (uint256 interestClaimable,) = convertibles.claimableInterest(1);

        console.log("Interest after 30 days:", interestClaimable);

        // The actual formula: interestEarnedPerSecond = amount * interestRatePerSecond / 1e18 / 365 days
        uint256 interestEarnedPerSecond = STAKE_AMOUNT * interestRatePerSecond / 1e18 / 365 days;
        uint256 expectedInterest = interestEarnedPerSecond * 30 days;

        console.log("Expected interest after 30 days:", expectedInterest);

        // Verify the calculation
        assertApproxEqRel(interestClaimable, expectedInterest, 0.01e18); // 1% tolerance
    }

    function testInterestCalculationPerYear() public {
        // Create a position
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_1_YEAR, user1);
        vm.stopPrank();

        // Get position details
        IAppConvertibles.Position memory position = convertibles.positions(1);
        uint256 interestRatePerSecond = position.fixedInterestRate;

        // Test interest after 1 year
        vm.warp(block.timestamp + 365 days);
        (uint256 interestClaimable,) = convertibles.claimableInterest(1);

        console.log("Interest after 1 year:", interestClaimable);

        // The actual formula: interestEarnedPerSecond = amount * interestRatePerSecond / 1e18 / 365 days
        uint256 interestEarnedPerSecond = STAKE_AMOUNT * interestRatePerSecond / 1e18 / 365 days;
        uint256 expectedInterest = interestEarnedPerSecond * 365 days;

        console.log("Expected interest after 1 year:", expectedInterest);

        // Verify the calculation
        assertApproxEqRel(interestClaimable, expectedInterest, 0.01e18); // 1% tolerance
    }

    function testInterestCalculationWithDifferentStakeAmounts() public {
        vm.prank(owner);
        underlyingToken.mint(user1, 1000000e18);
        vm.prank(user1);
        loanToken.mint(1000000e18, user1);

        uint256[] memory stakeAmounts = new uint256[](3);
        stakeAmounts[0] = 100e18; // 100 tokens
        stakeAmounts[1] = 1000e18; // 1000 tokens
        stakeAmounts[2] = 10000e18; // 10000 tokens

        uint256 timeElapsed = 0;
        uint256 previousInterestClaimable;
        for (uint256 i = 0; i < stakeAmounts.length; i++) {
            timeElapsed += 1 days;

            // Update oracle timestamps to avoid staleness
            oracle.touchTimestamp();
            twapOracle.touchTimestamp();

            // Create position with different stake amount
            vm.startPrank(user1);
            loanToken.approve(address(convertibles), stakeAmounts[i]);
            convertibles.stake(stakeAmounts[i], LOCK_DURATION_1_YEAR, user1);
            vm.stopPrank();

            // Get position details
            IAppConvertibles.Position memory position = convertibles.positions(i + 1);
            uint256 interestRatePerSecond = position.fixedInterestRate / 365 days;

            // Test interest after 1 day
            vm.warp(block.timestamp + 1 days);
            (uint256 interestClaimable,) = convertibles.claimableInterest(i + 1);

            console.log("Stake amount:", stakeAmounts[i]);
            console.log("Interest after 1 day:", interestClaimable);

            // The actual formula: interestEarnedPerSecond = amount * interestRatePerSecond / 1e18 / 365 days
            uint256 interestEarnedPerSecond = stakeAmounts[i] * interestRatePerSecond / 1e18;
            uint256 expectedInterest = interestEarnedPerSecond * 86400;

            // Verify the calculation
            assertApproxEqRel(interestClaimable, expectedInterest, 0.01e18, "Interest calculation should be correct"); // 1% tolerance

            // Verify that interest is proportional to stake amount
            if (i > 0) {
                uint256 ratio = (interestClaimable * 1e18) / stakeAmounts[i];
                uint256 previousRatio = (previousInterestClaimable * 1e18) / stakeAmounts[i - 1];
                assertApproxEqRel(ratio, previousRatio, 0.01e18, "Interest rate should be consistent"); // Interest rate should be consistent
            }

            (previousInterestClaimable,) = convertibles.claimableInterest(i + 1);
        }
    }

    function testInterestCalculationWithDifferentLockDurations() public {
        uint256[] memory lockDurations = new uint256[](3);
        lockDurations[0] = 30 days; // 30 days
        lockDurations[1] = 365 days; // 1 year
        lockDurations[2] = 4 * 365 days; // 4 years

        for (uint256 i = 0; i < lockDurations.length; i++) {
            // Update oracle timestamps to avoid staleness
            oracle.touchTimestamp();
            twapOracle.touchTimestamp();

            // Create position with different lock duration
            vm.startPrank(user1);
            loanToken.approve(address(convertibles), STAKE_AMOUNT);
            convertibles.stake(STAKE_AMOUNT, lockDurations[i], user1);
            vm.stopPrank();

            // Get position details
            IAppConvertibles.Position memory position = convertibles.positions(i + 1);
            uint256 interestRatePerSecond = position.fixedInterestRate;

            console.log("Lock duration:", lockDurations[i]);
            console.log("Interest rate per second:", interestRatePerSecond);
            console.log("Interest rate per year (calculated):", interestRatePerSecond * 365 days);

            // Test interest after 1 day
            vm.warp(block.timestamp + 1 days);
            (uint256 interestClaimable,) = convertibles.claimableInterest(i + 1);

            console.log("Interest after 1 day:", interestClaimable);

            // The actual formula: interestEarnedPerSecond = amount * interestRatePerSecond / 1e18 / 365 days
            uint256 interestEarnedPerSecond = STAKE_AMOUNT * interestRatePerSecond / 1e18 / 365 days;
            uint256 expectedInterest = interestEarnedPerSecond * 86400;

            // Verify the calculation
            assertApproxEqRel(interestClaimable, expectedInterest, 0.01e18); // 1% tolerance
        }
    }

    function testInterestCalculationPrecision() public {
        // Test with very small amounts to check precision
        uint256 smallStake = 1e18; // 1 token

        vm.startPrank(user1);
        loanToken.approve(address(convertibles), smallStake);
        convertibles.stake(smallStake, LOCK_DURATION_1_YEAR, user1);
        vm.stopPrank();

        IAppConvertibles.Position memory position = convertibles.positions(1);
        uint256 interestRatePerSecond = position.fixedInterestRate;

        // Test interest after very short time periods
        uint256[] memory timePeriods = new uint256[](5);
        timePeriods[0] = 1; // 1 second
        timePeriods[1] = 60; // 1 minute
        timePeriods[2] = 3600; // 1 hour
        timePeriods[3] = 86400; // 1 day
        timePeriods[4] = 604800; // 1 week

        uint256 timeElapsed = 0;
        for (uint256 i = 0; i < timePeriods.length; i++) {
            timeElapsed += timePeriods[i];
            vm.warp(block.timestamp + timePeriods[i]);
            (uint256 interestClaimable,) = convertibles.claimableInterest(1);

            // The actual formula: interestEarnedPerSecond = amount * interestRatePerSecond / 1e18 / 365 days
            uint256 interestEarnedPerSecond = smallStake * interestRatePerSecond / 1e18 / 365 days;
            uint256 expectedInterest = interestEarnedPerSecond * timeElapsed;

            console.log("Time period:", timePeriods[i], "seconds");
            console.log("Interest claimed:", interestClaimable);
            console.log("Expected interest:", expectedInterest);

            assertApproxEqRel(interestClaimable, expectedInterest, 0.01e18); // 1% tolerance
        }
    }

    function testInterestCalculationWithLockDurationLimit() public {
        // Create a position
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_1_YEAR, user1);
        vm.stopPrank();

        IAppConvertibles.Position memory position = convertibles.positions(1);
        uint256 interestRatePerSecond = position.fixedInterestRate;
        uint256 lockDuration = position.lockDuration;

        // Test interest after lock duration (should be capped)
        vm.warp(block.timestamp + lockDuration + 1 days);
        (uint256 interestClaimable,) = convertibles.claimableInterest(1);

        console.log("Interest after lock duration + 1 day:", interestClaimable);

        // The actual formula: interestEarnedPerSecond = amount * interestRatePerSecond / 1e18 / 365 days
        uint256 interestEarnedPerSecond = STAKE_AMOUNT * interestRatePerSecond / 1e18 / 365 days;
        uint256 expectedInterest = interestEarnedPerSecond * lockDuration;

        console.log("Expected interest (capped at lock duration):", expectedInterest);

        // Verify the calculation is capped at lock duration
        assertApproxEqRel(interestClaimable, expectedInterest, 0.01e18); // 1% tolerance

        // Verify that additional time doesn't increase interest
        vm.warp(block.timestamp + 30 days);
        (uint256 interestClaimable2,) = convertibles.claimableInterest(1);
        assertEq(interestClaimable2, interestClaimable); // Should be the same
    }

    function testInterestCalculationFormulaVerification() public {
        // This test verifies the exact formula used in the contract
        vm.startPrank(user1);
        loanToken.approve(address(convertibles), STAKE_AMOUNT);
        convertibles.stake(STAKE_AMOUNT, LOCK_DURATION_1_YEAR, user1);
        vm.stopPrank();

        vm.prank(owner);
        underlyingToken.mint(user1, 10000e18);

        IAppConvertibles.Position memory position = convertibles.positions(1);
        uint256 interestRatePerSecond = position.fixedInterestRate / 365 days;

        console.log("Interest rate per second:", interestRatePerSecond);
        console.log("Interest rate per year:", interestRatePerSecond * 365 days);
        console.log("Interest rate per year:", position.fixedInterestRate);

        // Test multiple time periods and verify the formula
        uint256[] memory timePeriods = new uint256[](4);
        timePeriods[0] = 1 hours;
        timePeriods[1] = 1 days;
        timePeriods[2] = 7 days;
        timePeriods[3] = 30 days;

        uint256 timeElapsed = 0;

        for (uint256 i = 0; i < timePeriods.length; i++) {
            timeElapsed += timePeriods[i];
            vm.warp(block.timestamp + timePeriods[i]);
            (uint256 interestClaimable,) = convertibles.claimableInterest(1);

            // Formula: interestEarnedPerSecond = amount * interestRatePerSecond / 1e18 / 365 days
            // Then: interest = interestEarnedPerSecond * timeElapsed
            uint256 interestEarnedPerSecond = STAKE_AMOUNT * position.fixedInterestRate / 365 days / 1e18;
            uint256 expectedInterest = interestEarnedPerSecond * timeElapsed;

            console.log("Time period:", timePeriods[i] / 1 days, "days");
            console.log("Interest claimed:", interestClaimable);
            console.log("Expected interest:", expectedInterest);
            console.log(
                "Difference:",
                interestClaimable > expectedInterest
                    ? interestClaimable - expectedInterest
                    : expectedInterest - interestClaimable
            );

            // Should be exact match for this formula
            assertApproxEqRel(interestClaimable, expectedInterest, 0.01e18);
        }
    }
}
