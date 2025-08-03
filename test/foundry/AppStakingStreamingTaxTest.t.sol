// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./BaseTest.sol";

contract AppStakingStreamingTaxTest is BaseTest {
    uint256 public constant STAKE_AMOUNT = 1000e18;
    uint256 public constant DECLARED_VALUE = 1000e18;
    uint256 public constant REWARD_AMOUNT = 100e18;

    function setUp() public {
        setUpBaseTest();

        vm.startPrank(owner);
        authority.addPolicy(owner);
    }

    function test_StreamingTaxCalculation() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Get streaming tax data
        IAppStaking.Position memory position = staking.positions(tokenId);

        // Verify streaming tax rate is calculated correctly
        // harbergerTaxRate = 500 (5%), declaredValue = 1000e18
        // taxPerSecond = (1000e18 * 500) / (10000 * 365 days)
        uint256 expectedStreamingTaxRate = (DECLARED_VALUE * 500) / (10000 * 365 days);
        assertEq(position.taxPerSecond, expectedStreamingTaxRate);
        assertEq(position.lastTaxCollectionTime, block.timestamp);

        vm.stopPrank();
    }

    function test_StreamingTaxAccumulation() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);

        // Calculate expected streaming tax
        uint256 taxAmount = staking.calculateStreamingTax(tokenId);

        // Tax should be approximately 5% of declared value per year
        // Allow for some precision loss in calculations
        assertApproxEqRel(taxAmount, DECLARED_VALUE * 500 / 10000, 0.01e18); // 1% tolerance

        vm.stopPrank();
    }

    function test_CollectStreamingTax() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        uint256 initialAmount = staking.positions(tokenId).amount;
        uint256 initialBurnerBalance = app.balanceOf(address(burner));

        // Fast forward 6 months
        vm.warp(block.timestamp + 180 days);

        // Collect streaming tax
        (uint256 taxCollected,) = staking.collectStreamingTax(tokenId);

        // Verify tax was collected
        assertTrue(taxCollected > 0);

        // Verify position amount was reduced
        IAppStaking.Position memory position = staking.positions(tokenId);
        assertEq(position.amount, initialAmount - taxCollected);
        assertEq(staking.totalStaked(), initialAmount - taxCollected);

        // Verify tax was sent to burner
        assertEq(app.balanceOf(address(burner)), initialBurnerBalance + taxCollected);

        // Verify tracking tokens were burned
        assertEq(sapp.balanceOf(owner), initialAmount - taxCollected);

        vm.stopPrank();
    }

    function test_CollectStreamingTaxCappedAtPositionAmount() public {
        vm.startPrank(owner);

        // Create position with small amount but large declared value
        uint256 smallAmount = 100e18;
        uint256 largeDeclaredValue = 10000e18;

        app.mint(owner, smallAmount);
        app.approve(address(staking), smallAmount);
        (uint256 tokenId,) = staking.createPosition(owner, smallAmount, largeDeclaredValue, 0);

        // Fast forward many years to accumulate large tax
        vm.warp(block.timestamp + 10 * 365 days);

        // Collect streaming tax
        (uint256 taxCollected,) = staking.collectStreamingTax(tokenId);

        // Tax should be capped at position amount
        assertEq(taxCollected, smallAmount);

        // Position should be completely depleted
        IAppStaking.Position memory position = staking.positions(tokenId);
        assertEq(position.amount, 0);
        assertEq(staking.totalStaked(), 0);

        vm.stopPrank();
    }

    function test_StreamingTaxInPositionOperations() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Fast forward to accumulate some tax
        vm.warp(block.timestamp + 30 days);

        uint256 initialAmount = staking.positions(tokenId).amount;
        uint256 initialBurnerBalance = app.balanceOf(address(burner));

        // Increase amount - should collect streaming tax first
        uint256 additionalAmount = 500e18;
        app.mint(owner, additionalAmount);
        app.approve(address(staking), additionalAmount);
        staking.increaseAmount(tokenId, additionalAmount, 0);

        // Verify streaming tax was collected
        assertTrue(app.balanceOf(address(burner)) > initialBurnerBalance);

        // Verify position amount includes additional amount minus any streaming tax
        IAppStaking.Position memory position = staking.positions(tokenId);
        assertTrue(
            position.amount >= initialAmount + additionalAmount - (initialAmount * 30 days * 500 / (10000 * 365 days))
        );

        vm.stopPrank();
    }

    function test_StreamingTaxInBuyPosition() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Fast forward to accumulate some tax
        vm.warp(block.timestamp + 30 days);

        uint256 initialBurnerBalance = app.balanceOf(address(burner));

        // Switch to buyer
        vm.stopPrank();
        vm.startPrank(user1);

        // Buy position - should collect streaming tax from seller
        // Use owner to mint tokens for user1 since user1 doesn't have permission
        vm.stopPrank();
        vm.startPrank(owner);
        app.mint(user1, DECLARED_VALUE);
        vm.stopPrank();
        vm.startPrank(user1);

        app.approve(address(staking), DECLARED_VALUE);
        staking.buyPosition(tokenId);

        // Verify streaming tax was collected from seller
        assertTrue(app.balanceOf(address(burner)) > initialBurnerBalance + (DECLARED_VALUE * 100 / 10000)); // resell fee

        vm.stopPrank();
    }

    function test_StreamingTaxInSplitPosition() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Fast forward to accumulate some tax
        vm.warp(block.timestamp + 30 days);

        uint256 initialBurnerBalance = app.balanceOf(address(burner));

        // Split position - should collect streaming tax first
        staking.splitPosition(tokenId, 0.5e18, user1);

        // Verify streaming tax was collected
        assertTrue(app.balanceOf(address(burner)) > initialBurnerBalance);

        vm.stopPrank();
    }

    function test_StreamingTaxInMergePositions() public {
        vm.startPrank(owner);

        // Create two positions
        app.mint(owner, STAKE_AMOUNT * 2);
        app.approve(address(staking), STAKE_AMOUNT * 2);

        (uint256 tokenId1,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);
        (uint256 tokenId2,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE * 2, 0);

        // Fast forward to accumulate some tax
        vm.warp(block.timestamp + 30 days);

        uint256 initialBurnerBalance = app.balanceOf(address(burner));

        // Merge positions - should collect streaming tax from both
        staking.mergePositions(tokenId1, tokenId2);

        // Verify streaming tax was collected from both positions
        assertTrue(app.balanceOf(address(burner)) > initialBurnerBalance);

        vm.stopPrank();
    }

    function test_StreamingTaxRateRecalculation() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        IAppStaking.Position memory position = staking.positions(tokenId);
        uint256 initialRate = position.taxPerSecond;

        // Increase declared value
        uint256 additionalDeclaredValue = 500e18;
        app.mint(owner, additionalDeclaredValue);
        app.approve(address(staking), additionalDeclaredValue);
        staking.increaseAmount(tokenId, 0, additionalDeclaredValue);

        // Verify streaming tax rate was recalculated
        position = staking.positions(tokenId);
        uint256 expectedNewRate = ((DECLARED_VALUE + additionalDeclaredValue) * 500) / (10000 * 365 days);
        assertEq(position.taxPerSecond, expectedNewRate);
        assertTrue(position.taxPerSecond > initialRate);

        vm.stopPrank();
    }
}
