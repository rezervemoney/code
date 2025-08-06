// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "./BaseTest.sol";

/// @title AccessControlTest
/// @notice Verifies that only the correct roles can invoke privileged functions throughout the protocol.
contract AccessControlTest is BaseTest {
    address governor = owner; // already governor from AppAuthority constructor
    address guardian = makeAddr("guardian");
    address policy = makeAddr("policy");
    address reserveManager = makeAddr("reserveManager");
    address reserveDepositor = makeAddr("reserveDepositor");
    address executor = makeAddr("executor");
    address bondManager = makeAddr("bondManager");

    uint256 internal constant TEST_AMOUNT = 1e17;

    function setUp() public {
        setUpBaseTest();

        // Assign all necessary roles
        vm.startPrank(governor);
        authority.addGuardian(guardian);
        authority.addPolicy(policy);
        authority.addReserveManager(reserveManager);
        authority.addReserveDepositor(reserveDepositor);
        authority.addExecutor(executor);
        authority.addBondManager(bondManager);

        // Enable mockQuoteToken in treasury for deposit/withdraw tests.

        treasury.enable(address(mockQuoteToken));

        // Provide some reserves for deposit tests.
        vm.stopPrank();

        // Mint quote tokens for depositor to use later
        mockQuoteToken.mint(reserveDepositor, 5_000e18);
        vm.prank(reserveDepositor);
        mockQuoteToken.approve(address(treasury), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                         Governor functions
    //////////////////////////////////////////////////////////////*/
    function test_GovernorCanUpdateOracle() external {
        vm.prank(governor);
        appOracle.updateOracle(address(mockQuoteToken3), address(mockOracle3), 3600);
    }

    function test_NonGovernorCannotUpdateOracle() external {
        vm.prank(user1);
        vm.expectRevert("UNAUTHORIZED");
        appOracle.updateOracle(address(mockQuoteToken3), address(mockOracle3), 3600);
    }

    function test_GovernorCanEnableDisableToken() external {
        address token = address(mockQuoteToken2);
        vm.prank(governor);
        treasury.enable(token);
        vm.prank(governor);
        treasury.disable(token);
    }

    /*//////////////////////////////////////////////////////////////
                         Policy functions
    //////////////////////////////////////////////////////////////*/
    function test_PolicyCanMintAndSetReserveFee() external {
        _syncOracles();

        vm.prank(reserveDepositor);
        treasury.deposit(TEST_AMOUNT, address(mockQuoteToken), 0);

        vm.prank(policy);
        treasury.setReserveFee(0.05e18); // 5%
    }

    function test_NonPolicyCannotMint() external {
        vm.prank(user1);
        vm.expectRevert("UNAUTHORIZED");
        treasury.deposit(TEST_AMOUNT, address(mockQuoteToken), 0);
    }

    /*//////////////////////////////////////////////////////////////
                Reserve Depositor / Manager functions
    //////////////////////////////////////////////////////////////*/
    function test_ReserveDepositorCanDeposit() external {
        uint256 amount = 1_000e18;
        vm.prank(reserveDepositor);
        treasury.deposit(amount, address(mockQuoteToken), 0);
    }

    function test_NonDepositorCannotDeposit() external {
        uint256 amount = 1_000e18;
        vm.prank(user1);
        vm.expectRevert("UNAUTHORIZED");
        treasury.deposit(amount, address(mockQuoteToken), 0);
    }

    function test_ReserveManagerCanManage() external {
        uint256 amount = 1_000e18;
        vm.prank(reserveDepositor);
        treasury.deposit(amount, address(mockQuoteToken), 0);

        vm.prank(reserveManager);
        treasury.manage(address(mockQuoteToken), amount / 4, reserveManager);
    }

    function test_NonReserveManagerCannotManage() external {
        vm.prank(user1);
        vm.expectRevert("UNAUTHORIZED");
        treasury.manage(address(mockQuoteToken), 1e18, user1);
    }

    /*//////////////////////////////////////////////////////////////
                         Guardian functions
    //////////////////////////////////////////////////////////////*/
    function test_GovernorCanPauseUnpause() external {
        vm.prank(guardian);
        authority.emergencyPause();
        vm.prank(governor);
        authority.emergencyUnpause();
    }

    function test_NonGuardianCannotPause() external {
        vm.prank(user1);
        vm.expectRevert("Only governor or guardian");
        authority.emergencyPause();
    }

    /*//////////////////////////////////////////////////////////////
                         Executor functions
    //////////////////////////////////////////////////////////////*/
    function test_ExecutorCanSyncReserves() external {
        vm.prank(executor);
        bridgeL1Reader.syncMainnetReserves();
    }

    function test_NonExecutorCannotSyncReserves() external {
        vm.prank(user1);
        vm.expectRevert("UNAUTHORIZED");
        treasury.syncReserves();
    }

    function test_ExecutorCanBurn() external {
        // Ensure total supply is larger than the burn amount
        vm.startPrank(governor);
        app.mint(governor, TEST_AMOUNT * 10);
        app.mint(address(burner), TEST_AMOUNT);
        vm.stopPrank();

        _syncOracles();

        vm.prank(address(bridgeL1Reader));
        treasury.syncReserves();

        vm.prank(executor);
        burner.burn();
    }

    /*//////////////////////////////////////////////////////////////
                         Bond Manager functions
    //////////////////////////////////////////////////////////////*/
    function test_BondManagerCanCreateBond() external {
        uint256 capacity = 1000e18;
        uint256 initPrice = 1.1e18;
        uint256 finalPrice = 0.9e18;
        uint256 dur = 1 days;
        uint256 vestingPeriod = 1 days;
        uint256 stakingLockPeriod = 1 days;
        bool isLoyaltyBond = false;
        vm.prank(bondManager);
        bondDepository.create(
            mockQuoteToken, capacity, initPrice, finalPrice, 0, dur, vestingPeriod, stakingLockPeriod, isLoyaltyBond
        );
    }

    function test_NonBondManagerCannotCreateBond() external {
        vm.prank(user1);
        vm.expectRevert("UNAUTHORIZED");
        bondDepository.create(mockQuoteToken, 1000e18, 1.1e18, 0.9e18, 0, 1 days, 1 days, 1 days, false);
    }
}
