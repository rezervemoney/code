// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./BaseTest.sol";

contract AppTreasuryTest is BaseTest {
    function setUp() public {
        setUpBaseTest();
        vm.startPrank(owner);

        authority.addReserveDepositor(owner);
        authority.addPolicy(owner);
        authority.addReserveManager(owner);
        authority.addReserveDepositor(owner);
    }

    function test_Initialize() public view {
        assertEq(address(treasury.app()), address(app));
        assertEq(treasury.totalReservesUsd(), 0);
    }

    function test_EnableToken() public {
        // Enable a new token
        treasury.enable(address(mockQuoteToken));

        // Verify token is enabled
        assertTrue(treasury.enabledTokens(address(mockQuoteToken)));

        vm.stopPrank();
    }

    function test_DisableToken() public {
        // First enable the token
        treasury.enable(address(mockQuoteToken));

        // Then disable it
        treasury.disable(address(mockQuoteToken));

        // Verify token is disabled
        assertFalse(treasury.enabledTokens(address(mockQuoteToken)));

        vm.stopPrank();
    }

    function test_Deposit() public {
        // Enable token first
        treasury.enable(address(mockQuoteToken));

        // Mint some tokens to owner
        uint256 depositAmount = 1000e18;
        mockQuoteToken.mint(owner, depositAmount);

        // Approve treasury to spend tokens
        mockQuoteToken.approve(address(treasury), depositAmount);

        // Deposit tokens
        uint256 profit = 100e18;
        uint256 dreMinted = treasury.deposit(depositAmount, address(mockQuoteToken), profit);

        // Verify RZR was minted correctly
        assertEq(app.balanceOf(owner), dreMinted, "RZR balance of owner should be equal to RZR minted");
        assertEq(dreMinted, depositAmount - profit, "RZR minted should be equal to deposit amount minus profit");

        // Verify reserves were updated
        assertEq(treasury.totalReservesUsd(), depositAmount, "Total reserves should be equal to deposit amount");

        vm.stopPrank();
    }

    function test_Manage() public {
        // Enable token first
        treasury.enable(address(mockQuoteToken));

        assertEq(app.totalSupply(), 0, "Actual supply should correctly reflect the initial state");

        // First deposit some tokens
        uint256 depositAmount = 1000e18;
        mockQuoteToken.mint(owner, depositAmount);
        mockQuoteToken.approve(address(treasury), depositAmount);
        uint256 profit = 100e18;
        treasury.deposit(depositAmount, address(mockQuoteToken), profit);

        vm.stopPrank();

        vm.startPrank(address(bridgeL1));
        treasury.syncReserves();
        vm.stopPrank();

        vm.startPrank(owner);

        assertEq(treasury.totalReservesUsd(), 1000e18, "Total usd reserves should be equal to deposit amount");
        assertEq(treasury.totalReservesRzr(), 0, "Total rzr reserves should be equal to deposit amount");
        assertEq(app.totalSupply(), 900e18, "Actual supply should be equal to deposit amount");

        // Now manage some tokens
        uint256 manageAmount = 20e18;
        treasury.manage(address(mockQuoteToken), manageAmount, owner);

        // Verify reserves were updated
        assertEq(treasury.totalReservesUsd(), depositAmount - manageAmount);

        // Verify tokens were returned
        assertEq(mockQuoteToken.balanceOf(owner), manageAmount);

        vm.stopPrank();
    }

    function test_AuditReserves() public {
        // Enable token first
        treasury.enable(address(mockQuoteToken));

        // First deposit some tokens
        uint256 depositAmount = 1000e18;
        mockQuoteToken.mint(owner, depositAmount);
        mockQuoteToken.approve(address(treasury), depositAmount);
        uint256 profit = 100e18;
        treasury.deposit(depositAmount, address(mockQuoteToken), profit);

        vm.stopPrank();

        // Audit reserves
        vm.prank(address(bridgeL1));
        treasury.syncReserves();
        vm.startPrank(owner);

        // Verify reserves were calculated correctly
        assertEq(treasury.totalReservesUsd(), depositAmount);

        vm.stopPrank();
    }

    // function test_BackingRatio() public {
    //     // Enable token first
    //     treasury.enable(address(mockQuoteToken));

    //     // First deposit some tokens
    //     uint256 depositAmount = 1000e18;
    //     mockQuoteToken.mint(owner, depositAmount);
    //     mockQuoteToken.approve(address(treasury), depositAmount);
    //     uint256 profit = 100e18;
    //     treasury.deposit(depositAmount, address(mockQuoteToken), profit);

    //     // Calculate backing ratio
    //     uint256 backingRatio = treasury.backingRatioE18();

    //     // Verify backing ratio is correct (should be 1e18 since we deposited 1:1)
    //     assertEq(backingRatio, 1111111111111111111);

    //     vm.stopPrank();
    // }

    function testFail_DepositInvalidToken() public {
        MockERC20 invalidToken = new MockERC20("Invalid Token", "INV");

        // Try to deposit without enabling token first
        uint256 depositAmount = 1000e18;
        invalidToken.mint(owner, depositAmount);
        invalidToken.approve(address(treasury), depositAmount);
        treasury.deposit(depositAmount, address(invalidToken), 0);

        vm.stopPrank();
    }
}
