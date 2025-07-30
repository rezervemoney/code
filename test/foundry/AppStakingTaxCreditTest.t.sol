// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./BaseTest.sol";

contract AppStakingTaxCreditTest is BaseTest {
    uint256 public constant STAKE_AMOUNT = 1000e18;
    uint256 public constant DECLARED_VALUE = 1000e18;
    uint256 public constant CREDIT_AMOUNT = 50e18; // 5% of declared value

    function setUp() public {
        setUpBaseTest();

        vm.startPrank(owner);
        authority.addPolicy(owner);
    }

    function test_SetUpfrontTaxCredit() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Set upfront tax credit
        staking.setUpfrontTaxCredit(tokenId, CREDIT_AMOUNT);

        // Verify credit was set
        IAppStaking.StreamingTaxData memory streamingData = staking.streamingTaxData(tokenId);
        assertTrue(streamingData.hasPaidUpfrontTax);
        assertEq(streamingData.upfrontTaxCredit, CREDIT_AMOUNT);
        assertEq(staking.getUpfrontTaxCredit(tokenId), CREDIT_AMOUNT);

        vm.stopPrank();
    }

    function test_SetUpfrontTaxCreditsBatch() public {
        vm.startPrank(owner);

        // Create multiple positions
        app.mint(owner, STAKE_AMOUNT * 3);
        app.approve(address(staking), STAKE_AMOUNT * 3);
        
        (uint256 tokenId1,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);
        (uint256 tokenId2,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE * 2, 0);
        (uint256 tokenId3,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE * 3, 0);

        // Set credits in batch
        uint256[] memory tokenIds = new uint256[](3);
        uint256[] memory creditAmounts = new uint256[](3);
        
        tokenIds[0] = tokenId1;
        tokenIds[1] = tokenId2;
        tokenIds[2] = tokenId3;
        
        creditAmounts[0] = CREDIT_AMOUNT;
        creditAmounts[1] = CREDIT_AMOUNT * 2;
        creditAmounts[2] = CREDIT_AMOUNT * 3;

        staking.setUpfrontTaxCreditsBatch(tokenIds, creditAmounts);

        // Verify all credits were set
        assertEq(staking.getUpfrontTaxCredit(tokenId1), CREDIT_AMOUNT);
        assertEq(staking.getUpfrontTaxCredit(tokenId2), CREDIT_AMOUNT * 2);
        assertEq(staking.getUpfrontTaxCredit(tokenId3), CREDIT_AMOUNT * 3);

        vm.stopPrank();
    }

    function test_StreamingTaxUsesCreditFirst() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Set upfront tax credit
        staking.setUpfrontTaxCredit(tokenId, CREDIT_AMOUNT);

        uint256 initialAmount = staking.positions(tokenId).amount;
        uint256 initialBurnerBalance = app.balanceOf(address(burner));

        // Fast forward to accumulate streaming tax
        vm.warp(block.timestamp + 30 days);

        // Calculate expected streaming tax
        (uint256 expectedTaxAmount, ) = staking.calculateStreamingTax(tokenId);
        
        // Collect streaming tax
        uint256 taxCollected = staking.collectStreamingTax(tokenId);

        // Verify tax was collected
        assertEq(taxCollected, expectedTaxAmount);

        // Verify credit was consumed first
        uint256 remainingCredit = staking.getUpfrontTaxCredit(tokenId);
        uint256 expectedRemainingCredit = CREDIT_AMOUNT > expectedTaxAmount ? 
            CREDIT_AMOUNT - expectedTaxAmount : 0;
        assertEq(remainingCredit, expectedRemainingCredit);

        // Verify position amount was only reduced by the amount not covered by credit
        uint256 actualTaxPaid = expectedTaxAmount > CREDIT_AMOUNT ? 
            expectedTaxAmount - CREDIT_AMOUNT : 0;
        uint256 expectedPositionAmount = initialAmount - actualTaxPaid;
        assertEq(staking.positions(tokenId).amount, expectedPositionAmount);

        // Verify burner only received the actual tax paid (not covered by credit)
        assertEq(app.balanceOf(address(burner)), initialBurnerBalance + actualTaxPaid);

        vm.stopPrank();
    }

    function test_StreamingTaxFullyCoveredByCredit() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Set large upfront tax credit
        uint256 largeCredit = 1000e18; // Much larger than any streaming tax
        staking.setUpfrontTaxCredit(tokenId, largeCredit);

        uint256 initialAmount = staking.positions(tokenId).amount;
        uint256 initialBurnerBalance = app.balanceOf(address(burner));

        // Fast forward to accumulate streaming tax
        vm.warp(block.timestamp + 30 days);

        // Collect streaming tax
        uint256 taxCollected = staking.collectStreamingTax(tokenId);

        // Verify tax was collected
        assertTrue(taxCollected > 0);

        // Verify position amount was NOT reduced (fully covered by credit)
        assertEq(staking.positions(tokenId).amount, initialAmount);

        // Verify burner did NOT receive any tokens (fully covered by credit)
        assertEq(app.balanceOf(address(burner)), initialBurnerBalance);

        // Verify credit was reduced
        uint256 remainingCredit = staking.getUpfrontTaxCredit(tokenId);
        assertEq(remainingCredit, largeCredit - taxCollected);

        vm.stopPrank();
    }

    function test_StreamingTaxPartiallyCoveredByCredit() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Set partial upfront tax credit
        uint256 partialCredit = 25e18; // Half of expected tax
        staking.setUpfrontTaxCredit(tokenId, partialCredit);

        uint256 initialAmount = staking.positions(tokenId).amount;
        uint256 initialBurnerBalance = app.balanceOf(address(burner));

        // Fast forward to accumulate streaming tax
        vm.warp(block.timestamp + 30 days);

        // Calculate expected streaming tax
        (uint256 expectedTaxAmount, ) = staking.calculateStreamingTax(tokenId);
        
        // Collect streaming tax
        uint256 taxCollected = staking.collectStreamingTax(tokenId);

        // Verify tax was collected
        assertEq(taxCollected, expectedTaxAmount);

        // Verify credit was consumed (either fully or partially)
        uint256 remainingCredit = staking.getUpfrontTaxCredit(tokenId);
        uint256 expectedRemainingCredit = expectedTaxAmount >= partialCredit ? 0 : partialCredit - expectedTaxAmount;
        assertEq(remainingCredit, expectedRemainingCredit);

        // Verify position amount was reduced by the uncovered portion
        uint256 uncoveredTax = expectedTaxAmount > partialCredit ? expectedTaxAmount - partialCredit : 0;
        assertEq(staking.positions(tokenId).amount, initialAmount - uncoveredTax);

        // Verify burner received the uncovered portion
        assertEq(app.balanceOf(address(burner)), initialBurnerBalance + uncoveredTax);

        vm.stopPrank();
    }

    function test_CreditInheritanceOnSplit() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Set upfront tax credit
        staking.setUpfrontTaxCredit(tokenId, CREDIT_AMOUNT);

        // Split position 50/50
        uint256 splitRatio = 0.5e18;
        uint256 newTokenId = staking.splitPosition(tokenId, splitRatio, user1);

        // Verify original position has remaining credit
        uint256 originalCredit = staking.getUpfrontTaxCredit(tokenId);
        assertEq(originalCredit, CREDIT_AMOUNT / 2);

        // Verify new position has proportional credit
        uint256 newCredit = staking.getUpfrontTaxCredit(newTokenId);
        assertEq(newCredit, CREDIT_AMOUNT / 2);

        // Verify both positions have the upfront tax flag
        IAppStaking.StreamingTaxData memory originalData = staking.streamingTaxData(tokenId);
        IAppStaking.StreamingTaxData memory newData = staking.streamingTaxData(newTokenId);
        assertTrue(originalData.hasPaidUpfrontTax);
        assertTrue(newData.hasPaidUpfrontTax);

        vm.stopPrank();
    }

    function test_CreditInheritanceOnMerge() public {
        vm.startPrank(owner);

        // Create two positions
        app.mint(owner, STAKE_AMOUNT * 2);
        app.approve(address(staking), STAKE_AMOUNT * 2);
        
        (uint256 tokenId1,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);
        (uint256 tokenId2,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE * 2, 0);

        // Set upfront tax credits
        staking.setUpfrontTaxCredit(tokenId1, CREDIT_AMOUNT);
        staking.setUpfrontTaxCredit(tokenId2, CREDIT_AMOUNT * 2);

        // Merge positions
        uint256 mergedTokenId = staking.mergePositions(tokenId1, tokenId2);

        // Verify merged position has combined credit
        uint256 mergedCredit = staking.getUpfrontTaxCredit(mergedTokenId);
        assertEq(mergedCredit, CREDIT_AMOUNT + CREDIT_AMOUNT * 2);

        // Verify merged position has the upfront tax flag
        IAppStaking.StreamingTaxData memory mergedData = staking.streamingTaxData(mergedTokenId);
        assertTrue(mergedData.hasPaidUpfrontTax);

        vm.stopPrank();
    }

    function testFail_SetCreditForNonExistentPosition() public {
        vm.startPrank(owner);
        
        // Try to set credit for non-existent position
        staking.setUpfrontTaxCredit(999, CREDIT_AMOUNT);
        
        vm.stopPrank();
    }

    function testFail_SetCreditTwice() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Set credit first time
        staking.setUpfrontTaxCredit(tokenId, CREDIT_AMOUNT);

        // Try to set credit again
        staking.setUpfrontTaxCredit(tokenId, CREDIT_AMOUNT * 2);

        vm.stopPrank();
    }

    function testFail_SetCreditAsNonGovernor() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        vm.stopPrank();
        vm.startPrank(user1);

        // Try to set credit as non-governor
        staking.setUpfrontTaxCredit(tokenId, CREDIT_AMOUNT);

        vm.stopPrank();
    }

    function testFail_SetCreditWithZeroAmount() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Try to set zero credit
        staking.setUpfrontTaxCredit(tokenId, 0);

        vm.stopPrank();
    }

    function test_CalculateUpfrontTaxCredit() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Calculate expected credit (5% of declared value)
        uint256 expectedCredit = (DECLARED_VALUE * 500) / 10000; // 5% = 50e18
        
        // Set credit
        staking.setUpfrontTaxCredit(tokenId, expectedCredit);

        // Verify credit was set correctly
        assertEq(staking.getUpfrontTaxCredit(tokenId), expectedCredit);

        vm.stopPrank();
    }

    function test_SetUpfrontTaxCreditWithRate() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Set credit using a specific tax rate (3% instead of current 5%)
        uint256 customTaxRate = 300; // 3%
        staking.setUpfrontTaxCreditWithRate(tokenId, customTaxRate);

        // Calculate expected credit (3% of declared value)
        uint256 expectedCredit = (DECLARED_VALUE * customTaxRate) / 10000; // 3% = 30e18
        
        // Verify credit was set correctly
        assertEq(staking.getUpfrontTaxCredit(tokenId), expectedCredit);

        vm.stopPrank();
    }

    function test_SetUpfrontTaxCreditWithRateValidation() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Try to set credit with invalid tax rate (over 100%)
        vm.expectRevert("Invalid tax rate");
        staking.setUpfrontTaxCreditWithRate(tokenId, 10001); // 100.01%

        vm.stopPrank();
    }

    function test_StreamingTaxEventsWithCredit() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Set upfront tax credit
        staking.setUpfrontTaxCredit(tokenId, CREDIT_AMOUNT);

        // Fast forward to accumulate streaming tax
        vm.warp(block.timestamp + 30 days);

        // Calculate expected streaming tax
        (uint256 expectedTaxAmount, ) = staking.calculateStreamingTax(tokenId);

        // Expect UpfrontTaxCreditConsumed event
        vm.expectEmit(true, false, false, true);
        emit IAppStaking.UpfrontTaxCreditConsumed(tokenId, Math.min(expectedTaxAmount, CREDIT_AMOUNT), 
            CREDIT_AMOUNT > expectedTaxAmount ? CREDIT_AMOUNT - expectedTaxAmount : 0);
        
        staking.collectStreamingTax(tokenId);

        vm.stopPrank();
    }

    function test_UpfrontTaxCreditSetEvent() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Expect UpfrontTaxCreditSet event
        vm.expectEmit(true, false, false, true);
        emit IAppStaking.UpfrontTaxCreditSet(tokenId, CREDIT_AMOUNT);
        
        staking.setUpfrontTaxCredit(tokenId, CREDIT_AMOUNT);

        vm.stopPrank();
    }
} 