// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./BaseTest.sol";
import "../../contracts/mocks/MockRateProvider.sol";

contract AppTreasuryRevenueTest is BaseTest {
    MockRateProvider public mockRateProvider;
    MockERC20 public revenueAsset;
    address public revenueDestination;
    address public executor;

    event RateProviderRegistered(address indexed asset, address indexed rateProvider, uint256 indexed rateSnapshot);
    event RevenueDestinationSet(address indexed revenueDestination);
    event RevenueCollected(
        address indexed asset, uint256 revenue, uint256 revenueToProtocol, uint256 revenueToTreasury
    );

    function setUp() public {
        setUpBaseTest();
        vm.startPrank(owner);

        // Deploy mock rate provider and revenue asset
        mockRateProvider = new MockRateProvider(1e18); // Initial rate of 1.0
        revenueAsset = new MockERC20("Revenue Asset", "REV");
        revenueDestination = makeAddr("revenueDestination");
        executor = makeAddr("executor");

        // Deploy mock oracle for revenue asset
        MockOracleV2 mockRevenueOracle = new MockOracleV2(0, 1e18, address(revenueAsset)); // 1:1 price
        appOracle.updateOracle(address(revenueAsset), address(mockRevenueOracle), 3600);

        // Set up roles
        authority.addExecutor(executor);
        authority.addReserveDepositor(owner);
        authority.addPolicy(owner);
        authority.addReserveManager(owner);

        // Enable revenue asset in treasury
        treasury.enable(address(revenueAsset));

        // Set revenue destination
        treasury.setRevenueDestination(revenueDestination);

        vm.stopPrank();
    }

    function test_RegisterRateProvider() public {
        vm.startPrank(owner);

        // Register rate provider
        treasury.registerRateProvider(address(revenueAsset), address(mockRateProvider));

        // Verify rate provider is registered
        assertEq(treasury.rateProviders(address(revenueAsset)), address(mockRateProvider));
        assertEq(treasury.rateSnapshots(address(revenueAsset)), 1e18);

        vm.stopPrank();
    }

    function test_RegisterRateProvider_EmitsEvent() public {
        vm.startPrank(owner);

        // Expect event emission
        vm.expectEmit(true, true, true, true);
        emit RateProviderRegistered(address(revenueAsset), address(mockRateProvider), 1e18);

        // Register rate provider
        treasury.registerRateProvider(address(revenueAsset), address(mockRateProvider));

        vm.stopPrank();
    }

    function test_SetRevenueDestination() public {
        address newDestination = makeAddr("newDestination");

        vm.startPrank(owner);

        // Set new revenue destination
        treasury.setRevenueDestination(newDestination);

        // Verify revenue destination is set
        assertEq(treasury.revenueDestination(), newDestination);

        vm.stopPrank();
    }

    function test_SetRevenueDestination_EmitsEvent() public {
        address newDestination = makeAddr("newDestination");

        vm.startPrank(owner);

        // Expect event emission
        vm.expectEmit(true, true, true, true);
        emit RevenueDestinationSet(newDestination);

        // Set new revenue destination
        treasury.setRevenueDestination(newDestination);

        vm.stopPrank();
    }

    function test_CollectRevenue_SingleAsset() public {
        vm.startPrank(owner);

        // Register rate provider
        treasury.registerRateProvider(address(revenueAsset), address(mockRateProvider));

        // Deposit some revenue asset to treasury
        uint256 depositAmount = 1000e18;
        revenueAsset.mint(address(treasury), depositAmount);

        // Increase rate to generate yield (from 1e18 to 1.1e18 = 10% yield)
        mockRateProvider.setRate(1.1e18);

        vm.stopPrank();

        // Collect revenue as executor
        vm.startPrank(executor);

        uint256 revenueDestinationBalanceBefore = revenueAsset.balanceOf(revenueDestination);
        uint256 operationsTreasuryBalanceBefore = revenueAsset.balanceOf(operationsTreasury);

        // Collect revenue
        treasury.collectRevenue(address(revenueAsset));

        // Verify rate snapshot was updated
        assertEq(treasury.rateSnapshots(address(revenueAsset)), 1.1e18);

        // Calculate expected revenue (10% of 1000e18 = 100e18)
        uint256 expectedRevenue = 100e18;

        // With default reserve fee of 0, all revenue goes to protocol
        uint256 expectedRevenueToProtocol = expectedRevenue;
        uint256 expectedRevenueToTreasury = 0;

        // Verify revenue distribution
        assertEq(
            revenueAsset.balanceOf(revenueDestination) - revenueDestinationBalanceBefore, expectedRevenueToProtocol
        );
        assertEq(
            revenueAsset.balanceOf(operationsTreasury) - operationsTreasuryBalanceBefore, expectedRevenueToTreasury
        );

        vm.stopPrank();
    }

    function test_CollectRevenue_WithReserveFee() public {
        vm.startPrank(owner);

        // Set reserve fee to 20% (20 in percentage terms)
        treasury.setReserveFee(20);

        // Register rate provider
        treasury.registerRateProvider(address(revenueAsset), address(mockRateProvider));

        // Deposit some revenue asset to treasury
        uint256 depositAmount = 1000e18;
        revenueAsset.mint(address(treasury), depositAmount);

        // Increase rate to generate yield (from 1e18 to 1.1e18 = 10% yield)
        mockRateProvider.setRate(1.1e18);

        vm.stopPrank();

        // Collect revenue as executor
        vm.startPrank(executor);

        uint256 revenueDestinationBalanceBefore = revenueAsset.balanceOf(revenueDestination);
        uint256 operationsTreasuryBalanceBefore = revenueAsset.balanceOf(operationsTreasury);

        // Collect revenue
        treasury.collectRevenue(address(revenueAsset));

        // Calculate expected revenue (10% of 1000e18 = 100e18)
        uint256 expectedRevenue = 100e18;

        // With 20% reserve fee: 80% to protocol, 20% to treasury
        uint256 expectedRevenueToProtocol = expectedRevenue * 80 / 100; // 80e18
        uint256 expectedRevenueToTreasury = expectedRevenue * 20 / 100; // 20e18

        // Verify revenue distribution
        assertEq(
            revenueAsset.balanceOf(revenueDestination) - revenueDestinationBalanceBefore, expectedRevenueToProtocol
        );
        assertEq(
            revenueAsset.balanceOf(operationsTreasury) - operationsTreasuryBalanceBefore, expectedRevenueToTreasury
        );

        vm.stopPrank();
    }

    function test_CollectRevenue_EmitsEvent() public {
        vm.startPrank(owner);

        // Register rate provider
        treasury.registerRateProvider(address(revenueAsset), address(mockRateProvider));

        // Deposit some revenue asset to treasury
        uint256 depositAmount = 1000e18;
        revenueAsset.mint(address(treasury), depositAmount);

        // Increase rate to generate yield
        mockRateProvider.setRate(1.1e18);

        vm.stopPrank();

        // Collect revenue as executor
        vm.startPrank(executor);

        uint256 expectedRevenue = 100e18;
        uint256 expectedRevenueToProtocol = expectedRevenue;
        uint256 expectedRevenueToTreasury = 0;

        // Expect event emission
        vm.expectEmit(true, true, true, true);
        emit RevenueCollected(
            address(revenueAsset), expectedRevenue, expectedRevenueToProtocol, expectedRevenueToTreasury
        );

        // Collect revenue
        treasury.collectRevenue(address(revenueAsset));

        vm.stopPrank();
    }

    function test_CollectRevenueMultiple() public {
        // Deploy additional assets and rate providers
        MockERC20 revenueAsset2 = new MockERC20("Revenue Asset 2", "REV2");
        MockRateProvider mockRateProvider2 = new MockRateProvider(1e18);

        vm.startPrank(owner);

        // Deploy mock oracle for second revenue asset
        MockOracleV2 mockRevenueOracle2 = new MockOracleV2(0, 1e18, address(revenueAsset2)); // 1:1 price
        appOracle.updateOracle(address(revenueAsset2), address(mockRevenueOracle2), 3600);

        // Enable second asset
        treasury.enable(address(revenueAsset2));

        // Register both rate providers
        treasury.registerRateProvider(address(revenueAsset), address(mockRateProvider));
        treasury.registerRateProvider(address(revenueAsset2), address(mockRateProvider2));

        // Deposit assets to treasury
        uint256 depositAmount = 1000e18;
        revenueAsset.mint(address(treasury), depositAmount);
        revenueAsset2.mint(address(treasury), depositAmount);

        // Increase rates to generate yield (as owner of rate providers)
        mockRateProvider.setRate(1.1e18); // 10% yield

        vm.stopPrank();

        // Set rate for second provider as test contract (owner of mockRateProvider2)
        mockRateProvider2.setRate(1.2e18); // 20% yield

        // Collect revenue for multiple assets as executor
        vm.startPrank(executor);

        address[] memory assets = new address[](2);
        assets[0] = address(revenueAsset);
        assets[1] = address(revenueAsset2);

        uint256 revenueDestinationBalanceBefore = revenueAsset.balanceOf(revenueDestination);
        uint256 revenueDestinationBalance2Before = revenueAsset2.balanceOf(revenueDestination);

        // Collect revenue for multiple assets
        treasury.collectRevenueMultiple(assets);

        // Verify rate snapshots were updated
        assertEq(treasury.rateSnapshots(address(revenueAsset)), 1.1e18);
        assertEq(treasury.rateSnapshots(address(revenueAsset2)), 1.2e18);

        // Calculate expected revenues
        uint256 expectedRevenue1 = 100e18; // 10% of 1000e18
        uint256 expectedRevenue2 = 200e18; // 20% of 1000e18

        // Verify revenue distribution for both assets
        assertEq(revenueAsset.balanceOf(revenueDestination) - revenueDestinationBalanceBefore, expectedRevenue1);
        assertEq(revenueAsset2.balanceOf(revenueDestination) - revenueDestinationBalance2Before, expectedRevenue2);

        vm.stopPrank();
    }

    function test_CollectRevenue_NoYield() public {
        vm.startPrank(owner);

        // Register rate provider
        treasury.registerRateProvider(address(revenueAsset), address(mockRateProvider));

        // Deposit some revenue asset to treasury
        uint256 depositAmount = 1000e18;
        revenueAsset.mint(address(treasury), depositAmount);

        // Don't change rate (no yield generated)

        vm.stopPrank();

        // Collect revenue as executor
        vm.startPrank(executor);

        uint256 revenueDestinationBalanceBefore = revenueAsset.balanceOf(revenueDestination);
        uint256 operationsTreasuryBalanceBefore = revenueAsset.balanceOf(operationsTreasury);

        // Collect revenue
        treasury.collectRevenue(address(revenueAsset));

        // Verify no revenue was distributed (no yield)
        assertEq(revenueAsset.balanceOf(revenueDestination) - revenueDestinationBalanceBefore, 0);
        assertEq(revenueAsset.balanceOf(operationsTreasury) - operationsTreasuryBalanceBefore, 0);

        vm.stopPrank();
    }

    function testRevert_CollectRevenue_NegativeYield() public {
        vm.startPrank(owner);

        // Register rate provider
        treasury.registerRateProvider(address(revenueAsset), address(mockRateProvider));

        // Deposit some revenue asset to treasury
        uint256 depositAmount = 1000e18;
        revenueAsset.mint(address(treasury), depositAmount);

        // Decrease rate (negative yield - this should cause underflow)
        mockRateProvider.setRate(0.9e18);

        vm.stopPrank();

        // Collect revenue as executor - should revert due to underflow
        vm.startPrank(executor);
        vm.expectRevert();
        treasury.collectRevenue(address(revenueAsset));
        vm.stopPrank();
    }

    function test_CollectRevenue_ZeroBalance() public {
        vm.startPrank(owner);

        // Register rate provider
        treasury.registerRateProvider(address(revenueAsset), address(mockRateProvider));

        // Don't deposit any assets (zero balance)

        // Increase rate to generate yield
        mockRateProvider.setRate(1.1e18);

        vm.stopPrank();

        // Collect revenue as executor
        vm.startPrank(executor);

        uint256 revenueDestinationBalanceBefore = revenueAsset.balanceOf(revenueDestination);
        uint256 operationsTreasuryBalanceBefore = revenueAsset.balanceOf(operationsTreasury);

        // Collect revenue
        treasury.collectRevenue(address(revenueAsset));

        // Verify no revenue was distributed (zero balance)
        assertEq(revenueAsset.balanceOf(revenueDestination) - revenueDestinationBalanceBefore, 0);
        assertEq(revenueAsset.balanceOf(operationsTreasury) - operationsTreasuryBalanceBefore, 0);

        // Verify rate snapshot was updated
        assertEq(treasury.rateSnapshots(address(revenueAsset)), 1.1e18);

        vm.stopPrank();
    }

    function testRevert_RegisterRateProvider_NotGovernor() public {
        vm.startPrank(user1);

        // Try to register rate provider without governor role
        vm.expectRevert();
        treasury.registerRateProvider(address(revenueAsset), address(mockRateProvider));

        vm.stopPrank();
    }

    function testRevert_SetRevenueDestination_NotGovernor() public {
        address newDestination = makeAddr("newDestination");

        vm.startPrank(user1);

        // Try to set revenue destination without governor role
        vm.expectRevert();
        treasury.setRevenueDestination(newDestination);

        vm.stopPrank();
    }

    function testRevert_CollectRevenue_NotExecutor() public {
        vm.startPrank(owner);

        // Register rate provider
        treasury.registerRateProvider(address(revenueAsset), address(mockRateProvider));

        // Deposit some revenue asset to treasury
        uint256 depositAmount = 1000e18;
        revenueAsset.mint(address(treasury), depositAmount);

        // Increase rate to generate yield
        mockRateProvider.setRate(1.1e18);

        vm.stopPrank();

        // Try to collect revenue without executor role
        vm.startPrank(user1);
        vm.expectRevert();
        treasury.collectRevenue(address(revenueAsset));
        vm.stopPrank();
    }

    function testRevert_CollectRevenue_NoRateProvider() public {
        vm.startPrank(owner);

        // Don't register rate provider

        // Deposit some revenue asset to treasury
        uint256 depositAmount = 1000e18;
        revenueAsset.mint(address(treasury), depositAmount);

        vm.stopPrank();

        // Try to collect revenue without rate provider
        vm.startPrank(executor);
        vm.expectRevert();
        treasury.collectRevenue(address(revenueAsset));
        vm.stopPrank();
    }

    function testRevert_CollectRevenue_NoRevenueDestination() public {
        vm.startPrank(owner);

        // Register rate provider
        treasury.registerRateProvider(address(revenueAsset), address(mockRateProvider));

        // Clear revenue destination (set to zero address)
        treasury.setRevenueDestination(address(0));

        // Deposit some revenue asset to treasury
        uint256 depositAmount = 1000e18;
        revenueAsset.mint(address(treasury), depositAmount);

        // Increase rate to generate yield
        mockRateProvider.setRate(1.1e18);

        vm.stopPrank();

        // Try to collect revenue without revenue destination
        vm.startPrank(executor);
        vm.expectRevert();
        treasury.collectRevenue(address(revenueAsset));
        vm.stopPrank();
    }

    function test_CollectRevenue_EdgeCase_MaxReserveFee() public {
        vm.startPrank(owner);

        // Set reserve fee to maximum (100%)
        treasury.setReserveFee(1e18);

        // Register rate provider
        treasury.registerRateProvider(address(revenueAsset), address(mockRateProvider));

        // Deposit some revenue asset to treasury
        uint256 depositAmount = 1000e18;
        revenueAsset.mint(address(treasury), depositAmount);

        // Increase rate to generate yield
        mockRateProvider.setRate(1.1e18);

        vm.stopPrank();

        // Collect revenue as executor - should revert due to underflow in contract
        vm.startPrank(executor);
        vm.expectRevert();
        treasury.collectRevenue(address(revenueAsset));
        vm.stopPrank();
    }

    function test_CollectRevenue_EdgeCase_VerySmallYield() public {
        vm.startPrank(owner);

        // Register rate provider
        treasury.registerRateProvider(address(revenueAsset), address(mockRateProvider));

        // Deposit some revenue asset to treasury
        uint256 depositAmount = 1000e18;
        revenueAsset.mint(address(treasury), depositAmount);

        // Increase rate by very small amount (0.01% yield)
        mockRateProvider.setRate(1.0001e18);

        vm.stopPrank();

        // Collect revenue as executor
        vm.startPrank(executor);

        uint256 revenueDestinationBalanceBefore = revenueAsset.balanceOf(revenueDestination);

        // Collect revenue
        treasury.collectRevenue(address(revenueAsset));

        // Calculate expected revenue (0.01% of 1000e18 = 0.1e18)
        uint256 expectedRevenue = 0.1e18;

        // Verify revenue distribution
        assertEq(revenueAsset.balanceOf(revenueDestination) - revenueDestinationBalanceBefore, expectedRevenue);

        vm.stopPrank();
    }

    function test_CollectRevenue_EdgeCase_LargeYield() public {
        vm.startPrank(owner);

        // Register rate provider
        treasury.registerRateProvider(address(revenueAsset), address(mockRateProvider));

        // Deposit some revenue asset to treasury
        uint256 depositAmount = 1000e18;
        revenueAsset.mint(address(treasury), depositAmount);

        // Increase rate by large amount (100% yield)
        mockRateProvider.setRate(2e18);

        vm.stopPrank();

        // Collect revenue as executor
        vm.startPrank(executor);

        uint256 revenueDestinationBalanceBefore = revenueAsset.balanceOf(revenueDestination);

        // Collect revenue
        treasury.collectRevenue(address(revenueAsset));

        // Calculate expected revenue (100% of 1000e18 = 1000e18)
        uint256 expectedRevenue = 1000e18;

        // Verify revenue distribution
        assertEq(revenueAsset.balanceOf(revenueDestination) - revenueDestinationBalanceBefore, expectedRevenue);

        vm.stopPrank();
    }
}
