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
        IAppStaking.StreamingTaxData memory streamingData = staking.streamingTaxData(tokenId);
        
        // Verify streaming tax rate is calculated correctly
        // harbergerTaxRate = 500 (5%), declaredValue = 1000e18
        // streamingTaxRate = (1000e18 * 500) / (10000 * 365 days)
        uint256 expectedStreamingTaxRate = (DECLARED_VALUE * 500) / (10000 * 365 days);
        assertEq(streamingData.streamingTaxRate, expectedStreamingTaxRate);
        assertEq(streamingData.lastTaxCollectionTime, block.timestamp);

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
        (uint256 taxAmount, uint256 timeElapsed) = staking.calculateStreamingTax(tokenId);
        
        // Tax should be approximately 5% of declared value per year
        // Allow for some precision loss in calculations
        assertApproxEqRel(taxAmount, DECLARED_VALUE * 500 / 10000, 0.01e18); // 1% tolerance
        assertEq(timeElapsed, 365 days);

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
        uint256 taxCollected = staking.collectStreamingTax(tokenId);
        
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
        uint256 taxCollected = staking.collectStreamingTax(tokenId);
        
        // Tax should be capped at position amount
        assertEq(taxCollected, smallAmount);
        
        // Position should be completely depleted
        IAppStaking.Position memory position = staking.positions(tokenId);
        assertEq(position.amount, 0);
        assertEq(staking.totalStaked(), 0);

        vm.stopPrank();
    }

    function test_UpdateStreamingTaxRate() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        IAppStaking.StreamingTaxData memory streamingData = staking.streamingTaxData(tokenId);
        uint256 oldRate = streamingData.streamingTaxRate;

        // Update streaming tax rate
        uint256 newRate = oldRate * 2;
        staking.updateStreamingTaxRate(tokenId, newRate);

        // Verify rate was updated
        streamingData = staking.streamingTaxData(tokenId);
        assertEq(streamingData.streamingTaxRate, newRate);

        vm.stopPrank();
    }

    function test_CollectAllStreamingTaxes() public {
        vm.startPrank(owner);

        // Create multiple positions
        app.mint(owner, STAKE_AMOUNT * 3);
        app.approve(address(staking), STAKE_AMOUNT * 3);
        
        (uint256 tokenId1,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);
        (uint256 tokenId2,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE * 2, 0);
        (uint256 tokenId3,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE * 3, 0);

        uint256 initialBurnerBalance = app.balanceOf(address(burner));

        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);

        // Collect all streaming taxes
        uint256 totalTaxCollected = staking.collectAllStreamingTaxes(owner);
        
        // Verify total tax was collected
        assertTrue(totalTaxCollected > 0);
        assertEq(app.balanceOf(address(burner)), initialBurnerBalance + totalTaxCollected);

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
        assertTrue(position.amount >= initialAmount + additionalAmount - (initialAmount * 30 days * 500 / (10000 * 365 days)));

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

        IAppStaking.StreamingTaxData memory streamingData = staking.streamingTaxData(tokenId);
        uint256 initialRate = streamingData.streamingTaxRate;

        // Increase declared value
        uint256 additionalDeclaredValue = 500e18;
        app.mint(owner, additionalDeclaredValue);
        app.approve(address(staking), additionalDeclaredValue);
        staking.increaseDeclaredValue(tokenId, additionalDeclaredValue);

        // Verify streaming tax rate was recalculated
        streamingData = staking.streamingTaxData(tokenId);
        uint256 expectedNewRate = ((DECLARED_VALUE + additionalDeclaredValue) * 500) / (10000 * 365 days);
        assertEq(streamingData.streamingTaxRate, expectedNewRate);
        assertTrue(streamingData.streamingTaxRate > initialRate);

        vm.stopPrank();
    }

    function test_UpdateStreamingTaxRateNotOwner() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        vm.stopPrank();
        vm.startPrank(user1);

        // Try to update streaming tax rate as non-owner - should revert
        vm.expectRevert();
        staking.updateStreamingTaxRate(tokenId, 1000);

        vm.stopPrank();
    }

    function test_StreamingTaxEvents() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Fast forward to accumulate some tax
        vm.warp(block.timestamp + 30 days);

        // Calculate expected tax amount
        (uint256 expectedTaxAmount, ) = staking.calculateStreamingTax(tokenId);

        // Expect StreamingTaxCollected event with actual values
        vm.expectEmit(true, true, false, true);
        emit IAppStaking.StreamingTaxCollected(tokenId, owner, expectedTaxAmount, 0); // timeElapsed is 0 after collection
        staking.collectStreamingTax(tokenId);

        // Update streaming tax rate
        IAppStaking.StreamingTaxData memory streamingData = staking.streamingTaxData(tokenId);
        uint256 newRate = streamingData.streamingTaxRate * 2;

        // Expect StreamingTaxRateUpdated event
        vm.expectEmit(true, false, false, true);
        emit IAppStaking.StreamingTaxRateUpdated(tokenId, streamingData.streamingTaxRate, newRate);
        staking.updateStreamingTaxRate(tokenId, newRate);

        vm.stopPrank();
    }
} 