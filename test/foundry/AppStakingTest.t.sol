// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./BaseTest.sol";

contract AppStakingTest is BaseTest {
    uint256 public constant STAKE_AMOUNT = 1000e18;
    uint256 public constant DECLARED_VALUE = 1000e18;
    uint256 public constant REWARD_AMOUNT = 100e18;
    uint256 public constant HIGH_DEMAND_THRESHOLD_BPS = 8000;
    uint256 public constant LOW_DEMAND_THRESHOLD_BPS = 2000;
    uint256 public constant MAX_DEPOSIT_FEE_BPS = 1000;

    IAppStaking.Variables defaultVariables;

    function setUp() public {
        setUpBaseTest();

        vm.startPrank(owner);
        authority.addPolicy(owner);

        defaultVariables = IAppStaking.Variables({
            highDemandThreshold: HIGH_DEMAND_THRESHOLD_BPS,
            lowDemandThreshold: LOW_DEMAND_THRESHOLD_BPS,
            maxDepositFee: MAX_DEPOSIT_FEE_BPS,
            harbergerTaxRate: 0.05 ether,
            resellFeeRate: 0.01 ether,
            withdrawCooldownPeriod: 3 days,
            buyCooldownPeriod: 86400
        });
        staking.setVariables(defaultVariables);
    }

    function test_Initialize() public view {
        assertEq(address(staking.appToken()), address(app));
        assertEq(address(staking.trackingToken()), address(sapp));
        assertEq(staking.totalStaked(), 0);
    }

    function test_CreatePosition() public {
        vm.startPrank(owner);

        // Mint RZR tokens to owner
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);

        // Create position
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Verify position details
        IAppStaking.Position memory position = staking.positions(tokenId);

        // With streaming tax, the position amount should be the full amount initially
        // (no initial harberger tax deduction, but streaming tax will be collected over time)
        assertEq(position.amount, STAKE_AMOUNT);
        assertEq(position.declaredValue, DECLARED_VALUE);
        assertEq(position.withdrawCooldownEnd, 0);
        assertEq(staking.totalStaked(), STAKE_AMOUNT);
        assertEq(sapp.balanceOf(owner), STAKE_AMOUNT);

        vm.stopPrank();
    }

    function test_StartUnstaking() public {
        vm.startPrank(owner);

        // Create position first
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Start unstaking
        staking.startUnstaking(tokenId);

        // Verify cooldown state
        IAppStaking.Position memory position = staking.positions(tokenId);
        assertTrue(position.withdrawCooldownEnd > 0);
        assertEq(position.withdrawCooldownEnd, block.timestamp + staking.variables().withdrawCooldownPeriod);

        vm.stopPrank();
    }

    function test_CompleteUnstaking() public {
        vm.startPrank(owner);

        // Create position first
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Start and complete unstaking
        staking.startUnstaking(tokenId);

        // Fast forward past cooldown period
        vm.warp(block.timestamp + staking.variables().withdrawCooldownPeriod + 1);

        uint256 balanceBefore = app.balanceOf(owner);
        staking.completeUnstaking(tokenId);

        // Verify tokens returned and position burned
        // With streaming tax, the returned amount will be the position amount minus any streaming tax collected
        // Allow for a more realistic streaming tax allowance (up to 1% of the stake amount)
        assertTrue(app.balanceOf(owner) >= balanceBefore + STAKE_AMOUNT - (STAKE_AMOUNT / 100)); // Allow for up to 1% streaming tax
        assertEq(staking.totalStaked(), 0);
        assertEq(sapp.balanceOf(owner), 0);

        vm.stopPrank();
    }

    function test_ClaimRewards() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Add rewards
        app.mint(owner, REWARD_AMOUNT);
        app.approve(address(staking), REWARD_AMOUNT);
        staking.notifyRewardAmount(REWARD_AMOUNT);

        vm.warp(block.timestamp + 1 days);

        // Claim rewards
        uint256 reward = staking.claimRewards(tokenId);
        assertTrue(reward > 0);

        vm.stopPrank();
    }

    function test_BuyPosition() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // With streaming tax, no initial tax is paid, but some streaming tax may be collected
        uint256 initialBurnerBalance = app.balanceOf(address(burner));

        // Use owner to mint tokens for user1 since user1 doesn't have permission
        app.mint(user1, DECLARED_VALUE);

        // Switch to buyer
        vm.stopPrank();
        vm.startPrank(user1);

        // Buy position
        app.approve(address(staking), DECLARED_VALUE);
        staking.buyPosition(tokenId);

        // Verify ownership transfer
        assertEq(staking.ownerOf(tokenId), user1);
        assertEq(sapp.balanceOf(user1), STAKE_AMOUNT);
        assertEq(sapp.balanceOf(owner), 0);

        // Burner gets resell fee (1% of declared value) plus any streaming tax collected
        assertTrue(app.balanceOf(address(burner)) >= initialBurnerBalance + (DECLARED_VALUE * 100 / 10000));

        vm.stopPrank();
    }

    function test_IncreaseAmount() public {
        vm.startPrank(owner);

        // Create initial position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        IAppStaking.Position memory initialPosition = staking.positions(tokenId);
        assertEq(initialPosition.amount, STAKE_AMOUNT);
        assertEq(initialPosition.declaredValue, DECLARED_VALUE);
        assertEq(staking.totalStaked(), STAKE_AMOUNT);

        // Increase amount
        uint256 additionalAmount = 500e18;
        uint256 additionalDeclaredValue = 50e18;
        app.mint(owner, additionalAmount);
        app.approve(address(staking), additionalAmount);
        staking.increaseAmount(tokenId, additionalAmount, additionalDeclaredValue);

        // Verify position updated
        IAppStaking.Position memory finalPosition = staking.positions(tokenId);
        // With streaming tax, the amount should be the sum minus any streaming tax collected
        assertTrue(finalPosition.amount >= STAKE_AMOUNT + additionalAmount - (STAKE_AMOUNT * 500 / (10000 * 365 days))); // Allow for some streaming tax
        assertEq(finalPosition.declaredValue, DECLARED_VALUE + additionalDeclaredValue);
        assertTrue(staking.totalStaked() >= STAKE_AMOUNT + additionalAmount - (STAKE_AMOUNT * 500 / (10000 * 365 days)));

        vm.stopPrank();
    }

    function test_CancelUnstaking() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Start unstaking
        staking.startUnstaking(tokenId);

        // Cancel unstaking
        staking.cancelUnstaking(tokenId);

        // Verify cooldown cancelled
        IAppStaking.Position memory position = staking.positions(tokenId);
        assertEq(position.withdrawCooldownEnd, 0);

        vm.stopPrank();
    }

    function test_CreatePositionWithZeroAmount_ShouldRevert() public {
        vm.startPrank(owner);
        // This should revert because amount must be greater than 0
        vm.expectRevert("Amount must be greater than 0");
        staking.createPosition(owner, 0, DECLARED_VALUE, 0);
        vm.stopPrank();
    }

    function testRevert_CreatePositionWithZeroValue() public {
        vm.startPrank(owner);
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);

        vm.expectRevert("Declared value must be greater than 0");
        staking.createPosition(owner, STAKE_AMOUNT, 0, 0);
        vm.stopPrank();
    }

    function testRevert_StartUnstakingNotOwner() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        vm.stopPrank();

        // Try to start unstaking as non-owner
        vm.startPrank(user1);
        vm.expectRevert("Not owner");
        staking.startUnstaking(tokenId);
        vm.stopPrank();
    }

    function testRevert_CompleteUnstakingBeforeCooldown() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Start unstaking
        staking.startUnstaking(tokenId);

        // Try to complete before cooldown
        vm.expectRevert("Cooldown not finished");
        staking.completeUnstaking(tokenId);
    }

    function testRevert_BuyOwnPosition() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Try to buy own position
        app.mint(owner, DECLARED_VALUE);
        app.approve(address(staking), DECLARED_VALUE);

        vm.expectRevert();
        staking.buyPosition(tokenId);

        vm.stopPrank();
    }

    function test_RewardDistribution() public {
        vm.startPrank(owner);

        // Create two positions
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId1,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        app.mint(user1, STAKE_AMOUNT);

        vm.stopPrank();
        vm.startPrank(user1);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId2,) = staking.createPosition(user1, STAKE_AMOUNT, DECLARED_VALUE, 0);
        vm.stopPrank();

        // Add rewards
        vm.startPrank(owner);
        app.mint(owner, REWARD_AMOUNT);
        app.approve(address(staking), REWARD_AMOUNT);
        staking.notifyRewardAmount(REWARD_AMOUNT);

        // Fast forward to distribute rewards
        vm.warp(block.timestamp + staking.EPOCH_DURATION());

        // Claim rewards for both positions
        uint256 reward1 = staking.claimRewards(tokenId1);
        vm.stopPrank();

        vm.startPrank(user1);
        uint256 reward2 = staking.claimRewards(tokenId2);

        // Verify rewards are distributed equally
        assertApproxEqAbs(reward1, reward2, 1e18);
        assertApproxEqAbs(reward1 + reward2, REWARD_AMOUNT, 1e18);

        vm.stopPrank();
    }

    function test_TaxDistribution() public {
        vm.startPrank(owner);

        // Create position with high declared value to test tax
        uint256 highValue = 10000e18;
        app.mint(owner, STAKE_AMOUNT + highValue);
        app.approve(address(staking), STAKE_AMOUNT + highValue);
        staking.createPosition(owner, STAKE_AMOUNT, highValue, 0);

        // With streaming tax, no initial tax is paid, but streaming tax will be collected over time
        // The burner balance should be 0 initially since no upfront tax is collected
        assertEq(app.balanceOf(address(burner)), 0);

        vm.stopPrank();
    }

    function test_BuyerCanWithdrawAndClaimRewards() public {
        vm.startPrank(owner);

        // Create initial position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Add rewards before selling
        app.mint(owner, REWARD_AMOUNT);
        app.approve(address(staking), REWARD_AMOUNT);
        staking.notifyRewardAmount(REWARD_AMOUNT);

        // Fast forward to accumulate rewards
        vm.warp(block.timestamp + staking.EPOCH_DURATION());

        // Get earned rewards before selling
        uint256 earnedBefore = staking.earned(tokenId);

        // Prepare buyer
        app.mint(user1, DECLARED_VALUE);
        vm.stopPrank();

        // Buyer purchases the position
        vm.startPrank(user1);
        app.approve(address(staking), DECLARED_VALUE);
        staking.buyPosition(tokenId);

        // Verify buyer owns the position
        assertEq(staking.ownerOf(tokenId), user1);
        // With streaming tax, the sRZR balance may be less than STAKE_AMOUNT due to tax collection
        // The streaming tax is collected during buyPosition, reducing the position amount
        // Allow for a small delta due to streaming tax collection
        assertApproxEqRel(sapp.balanceOf(user1), STAKE_AMOUNT, 0.001e18); // 0.1% tolerance

        // Verify rewards were automatically claimed during purchase
        // Allow for a small delta due to streaming tax collection affecting reward calculations
        assertApproxEqRel(app.balanceOf(user1), earnedBefore, 0.001e18); // 0.1% tolerance

        // Start unstaking process
        staking.startUnstaking(tokenId);

        // Fast forward past cooldown period
        vm.warp(block.timestamp + staking.variables().withdrawCooldownPeriod + 1);

        // Complete unstaking
        uint256 balanceBefore = app.balanceOf(user1);
        staking.completeUnstaking(tokenId);

        // Verify tokens returned to buyer
        // With streaming tax, the returned amount may be less due to tax collection
        // Allow for a more realistic streaming tax allowance (up to 1% of the stake amount)
        assertTrue(app.balanceOf(user1) >= balanceBefore + STAKE_AMOUNT - (STAKE_AMOUNT / 100)); // Allow for up to 1% streaming tax
        assertEq(staking.totalStaked(), 0);
        assertEq(sapp.balanceOf(user1), 0);

        vm.stopPrank();
    }

    function testFuzz_RewardDistribution(uint256 stakeAmount1, uint256 stakeAmount2, uint256 rewardAmount) public {
        // Bound the inputs to reasonable ranges
        stakeAmount1 = bound(stakeAmount1, 1e18, 1000000e18);
        stakeAmount2 = bound(stakeAmount2, 1e18, 1000000e18);
        rewardAmount = bound(rewardAmount, 1e18, 1000000e18);
        uint256 timeElapsed = staking.EPOCH_DURATION();

        vm.startPrank(owner);

        // Create two positions with different amounts
        app.mint(owner, stakeAmount1);
        app.approve(address(staking), stakeAmount1);
        (uint256 tokenId1,) = staking.createPosition(owner, stakeAmount1, stakeAmount1, 0);

        app.mint(user1, stakeAmount2);
        vm.stopPrank();

        vm.startPrank(user1);
        app.approve(address(staking), stakeAmount2);
        (uint256 tokenId2,) = staking.createPosition(user1, stakeAmount2, stakeAmount2, 0);
        vm.stopPrank();

        // Add rewards
        vm.startPrank(owner);
        app.mint(owner, rewardAmount);
        app.approve(address(staking), rewardAmount);
        staking.notifyRewardAmount(rewardAmount);

        // Fast forward by random time
        vm.warp(block.timestamp + timeElapsed);

        // Get earned rewards before claiming
        uint256 earned1 = staking.earned(tokenId1);
        uint256 earned2 = staking.earned(tokenId2);

        // Verify rewards are proportional to stake amounts
        if (stakeAmount1 > 0 && stakeAmount2 > 0) {
            uint256 expectedRatio = (stakeAmount1 * 1e18) / stakeAmount2;
            uint256 actualRatio = (earned1 * 1e18) / earned2;
            assertApproxEqRel(actualRatio, expectedRatio, 0.01e18); // 1% tolerance
        }

        // Claim rewards
        uint256 reward1 = staking.claimRewards(tokenId1);
        vm.stopPrank();

        vm.startPrank(user1);
        uint256 reward2 = staking.claimRewards(tokenId2);

        // Verify total rewards don't exceed notified amount
        assertTrue(reward1 + reward2 <= rewardAmount, "Total rewards exceed notified amount");

        // Verify claimed rewards match earned rewards
        // Allow for streaming tax effects on reward calculations
        assertApproxEqRel(reward1, earned1, 0.01e18, "Claimed rewards don't match earned rewards for position 1");
        assertApproxEqRel(reward2, earned2, 0.01e18, "Claimed rewards don't match earned rewards for position 2");

        vm.stopPrank();
    }

    function testFuzz_PositionOperations(
        uint256 stakeAmount,
        uint256 declaredValue,
        uint256 additionalAmount,
        uint256 additionalValue
    ) public {
        // Bound the inputs to reasonable ranges
        stakeAmount = bound(stakeAmount, 1e18, 1000000e18);
        declaredValue = bound(declaredValue, stakeAmount, stakeAmount * 2);
        additionalAmount = bound(additionalAmount, 1e18, 1000000e18);
        additionalValue = bound(additionalValue, additionalAmount, additionalAmount * 2);

        vm.startPrank(owner);

        // Create initial position
        app.mint(owner, stakeAmount + additionalAmount);
        app.approve(address(staking), stakeAmount + additionalAmount);
        (uint256 tokenId,) = staking.createPosition(owner, stakeAmount, declaredValue, 0);

        // Get initial position details
        IAppStaking.Position memory initialPosition = staking.positions(tokenId);

        // Increase position
        staking.increaseAmount(tokenId, additionalAmount, additionalValue);

        // Get updated position details
        IAppStaking.Position memory finalPosition = staking.positions(tokenId);

        // Verify position was updated correctly
        // With streaming tax, no upfront tax is paid during increaseAmount
        assertApproxEqAbs(
            finalPosition.amount, initialPosition.amount + additionalAmount, 100, "Amount not updated correctly"
        );
        assertApproxEqAbs(
            finalPosition.declaredValue,
            initialPosition.declaredValue + additionalValue,
            100,
            "Declared value not updated correctly"
        );

        // Start unstaking
        staking.startUnstaking(tokenId);

        // Verify cooldown started
        IAppStaking.Position memory position = staking.positions(tokenId);
        assertTrue(position.withdrawCooldownEnd > 0, "Cooldown not started");

        // Cancel unstaking
        staking.cancelUnstaking(tokenId);

        // Verify cooldown cancelled
        IAppStaking.Position memory cooldownPosition = staking.positions(tokenId);
        assertEq(cooldownPosition.withdrawCooldownEnd, 0, "Cooldown not cancelled");

        vm.stopPrank();
    }

    function testFuzz_RewardAccumulation(uint256 stakeAmount, uint256 rewardAmount, uint256 timeBetweenRewards)
        public
    {
        // Bound the inputs to reasonable ranges
        stakeAmount = bound(stakeAmount, 1e18, 1000000e18);
        rewardAmount = bound(rewardAmount, 1e18, 1000000e18);
        timeBetweenRewards = bound(timeBetweenRewards, 1, staking.EPOCH_DURATION() / 2);

        vm.startPrank(owner);

        // Create position
        app.mint(owner, stakeAmount);
        app.approve(address(staking), stakeAmount);
        (uint256 tokenId,) = staking.createPosition(owner, stakeAmount, stakeAmount, 0);

        // Add first reward
        app.mint(owner, rewardAmount);
        app.approve(address(staking), rewardAmount);
        staking.notifyRewardAmount(rewardAmount);

        // Fast forward
        vm.warp(block.timestamp + timeBetweenRewards);

        // Add second reward
        app.mint(owner, rewardAmount);
        app.approve(address(staking), rewardAmount);
        staking.notifyRewardAmount(rewardAmount);

        // Get earned rewards
        uint256 earned = staking.earned(tokenId);

        // Verify rewards don't exceed total notified amount
        assertTrue(earned <= rewardAmount * 2, "Earned rewards exceed total notified amount");

        // Claim rewards
        uint256 claimed = staking.claimRewards(tokenId);

        // Verify claimed amount matches earned amount
        // Allow for streaming tax effects on reward calculations
        assertApproxEqRel(claimed, earned, 0.01e18, "Claimed amount doesn't match earned amount");

        vm.stopPrank();
    }

    function testFuzz_BuyPosition(uint256 stakeAmount, uint256 declaredValue, uint256 rewardAmount) public {
        // Bound the inputs to reasonable ranges
        stakeAmount = bound(stakeAmount, 1e18, 1000000e18);
        declaredValue = bound(declaredValue, stakeAmount, stakeAmount * 2);
        rewardAmount = bound(rewardAmount, 1e18, 1000000e18);

        vm.startPrank(owner);

        // Create initial position
        app.mint(owner, stakeAmount);
        app.approve(address(staking), stakeAmount);
        (uint256 tokenId,) = staking.createPosition(owner, stakeAmount, declaredValue, 0);

        // Add rewards before selling
        app.mint(owner, rewardAmount);
        app.approve(address(staking), rewardAmount);
        staking.notifyRewardAmount(rewardAmount);

        // Fast forward to accumulate rewards
        vm.warp(block.timestamp + staking.EPOCH_DURATION());

        // Get earned rewards before selling
        uint256 earnedBefore = staking.earned(tokenId);

        // Prepare buyer
        app.mint(user1, declaredValue);
        vm.stopPrank();

        // Buyer purchases the position
        vm.startPrank(user1);
        app.approve(address(staking), declaredValue);
        staking.buyPosition(tokenId);

        // Verify buyer owns the position
        assertEq(staking.ownerOf(tokenId), user1, "Position ownership not transferred");
        // With streaming tax, the buyer receives the position amount minus any streaming tax collected
        // Allow for streaming tax effects by using a larger tolerance
        assertApproxEqRel(
            sapp.balanceOf(user1),
            stakeAmount,
            0.01e18, // 1% tolerance for streaming tax effects
            "Tracking tokens not transferred correctly"
        );

        // Verify seller received payment minus fees
        uint256 expectedSellerAmount = declaredValue - ((declaredValue * staking.variables().resellFeeRate) / 1e18);
        assertApproxEqRel(
            app.balanceOf(owner), expectedSellerAmount, 0.0001e18, "Seller did not receive correct amount"
        );

        // Verify rewards were automatically claimed during purchase
        // Allow for streaming tax effects on reward calculations
        assertApproxEqRel(
            app.balanceOf(user1), earnedBefore, 0.01e18, "Rewards not automatically claimed during purchase"
        );

        // Verify no additional rewards to claim
        uint256 earnedAfter = staking.earned(tokenId);
        assertEq(earnedAfter, 0, "Additional rewards found after automatic claim");

        vm.stopPrank();
    }

    function testFuzz_BuyPositionWithRewards(
        uint256 stakeAmount,
        uint256 declaredValue,
        uint256 rewardAmount1,
        uint256 rewardAmount2
    ) public {
        // Bound the inputs to reasonable ranges
        stakeAmount = bound(stakeAmount, 1e18, 1000000e18);
        declaredValue = bound(declaredValue, stakeAmount, stakeAmount * 2);
        rewardAmount1 = bound(rewardAmount1, 1e18, 1000000e18);
        rewardAmount2 = bound(rewardAmount2, 1e18, 1000000e18);

        vm.startPrank(owner);

        // Create initial position
        app.mint(owner, stakeAmount);
        app.approve(address(staking), stakeAmount);
        (uint256 tokenId,) = staking.createPosition(owner, stakeAmount, declaredValue, 0);

        // Add first reward
        app.mint(owner, rewardAmount1);
        app.approve(address(staking), rewardAmount1);
        staking.notifyRewardAmount(rewardAmount1);

        // Fast forward half the epoch
        vm.warp(block.timestamp + staking.EPOCH_DURATION() / 2);

        // Add second reward
        app.mint(owner, rewardAmount2);
        app.approve(address(staking), rewardAmount2);
        staking.notifyRewardAmount(rewardAmount2);

        vm.warp(block.timestamp + staking.EPOCH_DURATION());

        // Get earned rewards before selling
        uint256 earnedBefore = staking.earned(tokenId);
        assertGt(earnedBefore, 0, "No rewards earned before purchase");

        // Prepare buyer
        app.mint(user1, declaredValue);
        vm.stopPrank();

        // Buyer purchases the position
        vm.startPrank(user1);
        app.approve(address(staking), declaredValue);
        staking.buyPosition(tokenId);

        // Verify buyer can claim accumulated rewards
        uint256 earnedAfter = staking.earned(tokenId);
        assertEq(earnedAfter, 0, "Additional rewards found after automatic claim");

        vm.stopPrank();
    }

    function testFuzz_BuyPositionWithUnstaking(uint256 stakeAmount, uint256 declaredValue, uint256 rewardAmount)
        public
    {
        // Bound the inputs to reasonable ranges
        stakeAmount = bound(stakeAmount, 1e18, 1000000e18);
        declaredValue = bound(declaredValue, stakeAmount, stakeAmount * 2);
        rewardAmount = bound(rewardAmount, 1e18, 1000000e18);

        vm.startPrank(owner);

        // Create initial position
        app.mint(owner, stakeAmount);
        app.approve(address(staking), stakeAmount);
        (uint256 tokenId,) = staking.createPosition(owner, stakeAmount, declaredValue, 0);

        // Add rewards
        app.mint(owner, rewardAmount);
        app.approve(address(staking), rewardAmount);
        staking.notifyRewardAmount(rewardAmount);

        // Start unstaking
        staking.startUnstaking(tokenId);

        // Prepare buyer
        app.mint(user1, declaredValue);
        vm.stopPrank();

        // Buyer purchases the position
        vm.startPrank(user1);
        app.approve(address(staking), declaredValue);
        staking.buyPosition(tokenId);

        // Verify unstaking was cancelled
        IAppStaking.Position memory position = staking.positions(tokenId);
        assertEq(position.withdrawCooldownEnd, 0, "Unstaking not cancelled after position transfer");

        // Verify buyer can claim rewards
        uint256 earned = staking.earned(tokenId);
        uint256 claimed = staking.claimRewards(tokenId);
        // Allow for streaming tax effects on reward calculations
        assertApproxEqRel(claimed, earned, 0.01e18, "Buyer could not claim rewards");

        vm.stopPrank();
    }

    function test_SplitPosition() public {
        vm.startPrank(owner);

        // Create initial position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Add rewards before splitting
        app.mint(owner, REWARD_AMOUNT);
        app.approve(address(staking), REWARD_AMOUNT);
        staking.notifyRewardAmount(REWARD_AMOUNT);

        // Fast forward to accumulate rewards
        vm.warp(block.timestamp + staking.EPOCH_DURATION());

        // Get initial position details
        IAppStaking.Position memory initialPosition = staking.positions(tokenId);

        // Split position 50/50
        uint256 splitRatio = 0.5e18; // 50%
        uint256 newTokenId = staking.splitPosition(tokenId, splitRatio, user1);

        // Get final position details
        IAppStaking.Position memory originalPosition = staking.positions(tokenId);
        IAppStaking.Position memory newPosition = staking.positions(newTokenId);

        // Verify original position was reduced correctly
        // With streaming tax, the amounts may be slightly different due to tax collection
        assertTrue(originalPosition.amount <= initialPosition.amount - (initialPosition.amount * splitRatio / 1e18));
        assertEq(
            originalPosition.declaredValue,
            initialPosition.declaredValue - (initialPosition.declaredValue * splitRatio / 1e18)
        );

        // Verify new position was created correctly
        assertTrue(newPosition.amount <= initialPosition.amount * splitRatio / 1e18);
        assertEq(newPosition.declaredValue, initialPosition.declaredValue * splitRatio / 1e18);
        assertEq(newPosition.rewards, 0);
        assertEq(newPosition.rewardPerTokenPaid, staking.rewardPerTokenStored());

        // Verify tracking tokens were transferred correctly
        assertEq(sapp.balanceOf(owner), originalPosition.amount);
        assertEq(sapp.balanceOf(user1), newPosition.amount);

        // Verify NFT ownership
        assertEq(staking.ownerOf(tokenId), owner);
        assertEq(staking.ownerOf(newTokenId), user1);

        vm.stopPrank();
    }

    function testRevert_SplitPositionNotOwner() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        vm.stopPrank();

        // Try to split as non-owner
        vm.startPrank(user1);
        vm.expectRevert("Not owner");
        staking.splitPosition(tokenId, 0.5e18, user2);
        vm.stopPrank();
    }

    function testRevert_SplitPositionInCooldown() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Start unstaking
        staking.startUnstaking(tokenId);

        // Try to split while in cooldown
        vm.expectRevert("Position is in cooldown");
        staking.splitPosition(tokenId, 0.5e18, user1);

        vm.stopPrank();
    }

    function testRevert_SplitPositionInvalidRatio() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Try to split with invalid ratio
        vm.expectRevert("Split ratio must be less than or equal to 100%");
        staking.splitPosition(tokenId, 1.1e18, user1); // 110%

        vm.stopPrank();
    }

    function testFuzz_SplitPosition(
        uint256 stakeAmount,
        uint256 declaredValue,
        uint256 splitRatio,
        uint256 rewardAmount
    ) public {
        // Bound the inputs to reasonable ranges
        stakeAmount = bound(stakeAmount, 1e18, 1000000e18);
        declaredValue = bound(declaredValue, stakeAmount, stakeAmount * 2);
        splitRatio = bound(splitRatio, 1e16, 0.99e18); // Min 1%, Max 99% split
        rewardAmount = bound(rewardAmount, 1e18, 1000000e18);

        vm.startPrank(owner);

        // Create initial position
        app.mint(owner, stakeAmount);
        app.approve(address(staking), stakeAmount);
        (uint256 tokenId,) = staking.createPosition(owner, stakeAmount, declaredValue, 0);

        // Add rewards
        app.mint(owner, rewardAmount);
        app.approve(address(staking), rewardAmount);
        staking.notifyRewardAmount(rewardAmount);

        // Fast forward to accumulate rewards
        vm.warp(block.timestamp + staking.EPOCH_DURATION());

        // Get initial position details
        IAppStaking.Position memory initialPosition = staking.positions(tokenId);

        // Split position
        uint256 newTokenId = staking.splitPosition(tokenId, splitRatio, user1);

        // Get final position details
        IAppStaking.Position memory originalPosition = staking.positions(tokenId);
        IAppStaking.Position memory newPosition = staking.positions(newTokenId);

        // Calculate expected split amounts
        uint256 expectedSplitAmount = (initialPosition.amount * splitRatio) / 1e18;
        uint256 expectedSplitValue = (initialPosition.declaredValue * splitRatio) / 1e18;

        // Verify amounts were split correctly
        // Allow for streaming tax effects on split amounts
        assertApproxEqRel(newPosition.amount, expectedSplitAmount, 0.01e18);
        assertEq(newPosition.declaredValue, expectedSplitValue);
        assertApproxEqRel(originalPosition.amount, initialPosition.amount - expectedSplitAmount, 0.01e18);
        assertEq(originalPosition.declaredValue, initialPosition.declaredValue - expectedSplitValue);

        // Verify tracking tokens were transferred correctly
        assertEq(sapp.balanceOf(owner), originalPosition.amount);
        assertEq(sapp.balanceOf(user1), newPosition.amount);

        // Verify NFT ownership
        assertEq(staking.ownerOf(tokenId), owner);
        assertEq(staking.ownerOf(newTokenId), user1);

        // Verify rewards start fresh for new position
        assertEq(newPosition.rewards, 0);
        assertEq(newPosition.rewardPerTokenPaid, staking.rewardPerTokenStored());

        vm.stopPrank();
    }

    // ============ BUY COOLDOWN TESTS ============

    function test_BuyCooldownInitialization() public view {
        // Test that buy cooldown period is initialized correctly
        assertEq(staking.variables().buyCooldownPeriod, 1 days, "Buy cooldown period not initialized to 1 day");
    }

    function test_BuyPositionSetsCooldown() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Prepare buyer
        app.mint(user1, DECLARED_VALUE);
        vm.stopPrank();

        // Buyer purchases the position
        vm.startPrank(user1);
        app.approve(address(staking), DECLARED_VALUE);
        staking.buyPosition(tokenId);

        // Verify buy cooldown is set
        IAppStaking.Position memory position = staking.positions(tokenId);
        assertTrue(position.buyCooldownEnd > 0, "Position should be in buy cooldown");
        assertEq(
            position.buyCooldownEnd,
            block.timestamp + staking.variables().buyCooldownPeriod,
            "Buy cooldown end time incorrect"
        );

        vm.stopPrank();
    }

    function testRevert_BuyPositionInCooldown() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Prepare first buyer
        app.mint(user1, DECLARED_VALUE);
        vm.stopPrank();

        // First buyer purchases the position
        vm.startPrank(user1);
        app.approve(address(staking), DECLARED_VALUE);
        staking.buyPosition(tokenId);

        // Prepare second buyer
        vm.startPrank(owner);
        app.mint(user2, DECLARED_VALUE);
        vm.stopPrank();

        // Second buyer tries to buy the position while it's in cooldown
        vm.startPrank(user2);
        app.approve(address(staking), DECLARED_VALUE);
        vm.expectRevert("Position in buy cooldown");
        staking.buyPosition(tokenId);

        vm.stopPrank();
    }

    function test_BuyPositionAfterCooldown() public {
        vm.startPrank(owner);
        authority.addPolicy(user1);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Prepare first buyer
        app.mint(user1, DECLARED_VALUE);
        vm.stopPrank();

        // First buyer purchases the position
        vm.startPrank(user1);
        app.approve(address(staking), DECLARED_VALUE);
        staking.buyPosition(tokenId);

        // Fast forward past cooldown period
        vm.warp(block.timestamp + staking.variables().buyCooldownPeriod + 1);

        // Prepare second buyer
        app.mint(user2, DECLARED_VALUE);
        vm.stopPrank();

        // Second buyer should be able to buy the position now
        vm.startPrank(user2);
        app.approve(address(staking), DECLARED_VALUE);
        staking.buyPosition(tokenId);

        // Verify ownership transfer
        assertEq(staking.ownerOf(tokenId), user2, "Position ownership not transferred to second buyer");

        vm.stopPrank();
    }

    function test_SplitPositionInheritsBuyCooldown() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Prepare buyer
        app.mint(user1, DECLARED_VALUE);
        vm.stopPrank();

        // Buyer purchases the position
        vm.startPrank(user1);
        app.approve(address(staking), DECLARED_VALUE);
        staking.buyPosition(tokenId);

        // Split the position while in cooldown
        uint256 splitRatio = 0.5e18; // 50%
        uint256 newTokenId = staking.splitPosition(tokenId, splitRatio, user2);

        // Verify both positions inherit the buy cooldown
        IAppStaking.Position memory position = staking.positions(tokenId);
        assertTrue(position.buyCooldownEnd > 0, "Original position should still be in buy cooldown");
        IAppStaking.Position memory newPosition = staking.positions(newTokenId);
        assertTrue(newPosition.buyCooldownEnd > 0, "Split position should inherit buy cooldown");
        assertEq(
            position.buyCooldownEnd, newPosition.buyCooldownEnd, "Split positions should have same cooldown end time"
        );

        vm.stopPrank();
    }

    function test_MergePositionsCleansUpBuyCooldown() public {
        vm.startPrank(owner);

        // Create two positions
        app.mint(owner, STAKE_AMOUNT * 2);
        app.approve(address(staking), STAKE_AMOUNT * 2);
        (uint256 tokenId1,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);
        (uint256 tokenId2,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Buy both positions to set cooldowns
        app.mint(user1, DECLARED_VALUE * 2);
        vm.stopPrank();

        vm.startPrank(user1);
        app.approve(address(staking), DECLARED_VALUE * 2);
        staking.buyPosition(tokenId1);
        staking.buyPosition(tokenId2);

        // Verify both positions are in cooldown
        IAppStaking.Position memory position1 = staking.positions(tokenId1);
        assertTrue(position1.buyCooldownEnd > 0, "Position 1 should be in buy cooldown");
        IAppStaking.Position memory position2 = staking.positions(tokenId2);
        assertTrue(position2.buyCooldownEnd > 0, "Position 2 should be in buy cooldown");

        // Merge the positions
        uint256 mergedTokenId = staking.mergePositions(tokenId1, tokenId2);

        // Verify merged position is in cooldown (inherits from tokenId1)
        IAppStaking.Position memory mergedPosition = staking.positions(mergedTokenId);
        assertTrue(mergedPosition.buyCooldownEnd > 0, "Merged position should inherit buy cooldown");
        assertEq(
            mergedPosition.buyCooldownEnd,
            position1.buyCooldownEnd,
            "Merged position should inherit cooldown from first position"
        );

        // Verify the burned position's cooldown is cleaned up
        assertEq(staking.getBuyCooldownEnd(tokenId2), 0, "Burned position's buy cooldown should be cleaned up");

        vm.stopPrank();
    }

    function test_CompleteUnstakingCleansUpBuyCooldown() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Prepare buyer
        app.mint(user1, DECLARED_VALUE);
        vm.stopPrank();

        // Buyer purchases the position
        vm.startPrank(user1);
        app.approve(address(staking), DECLARED_VALUE);
        staking.buyPosition(tokenId);

        // Verify buy cooldown is set
        IAppStaking.Position memory position = staking.positions(tokenId);
        assertTrue(position.buyCooldownEnd > 0, "Position should be in buy cooldown");

        // Start unstaking
        staking.startUnstaking(tokenId);

        // Fast forward past withdraw cooldown
        vm.warp(block.timestamp + staking.variables().withdrawCooldownPeriod + 1);

        // Complete unstaking
        staking.completeUnstaking(tokenId);

        // Verify buy cooldown is cleaned up (position is burned)
        assertEq(staking.getBuyCooldownEnd(tokenId), 0, "Buy cooldown should be cleaned up when position is burned");

        vm.stopPrank();
    }

    function test_SetBuyCooldownPeriod() public {
        vm.startPrank(owner);

        uint256 newCooldownPeriod = 2 days;
        uint256 oldCooldownPeriod = staking.variables().buyCooldownPeriod;

        // Set new cooldown period
        defaultVariables.buyCooldownPeriod = newCooldownPeriod;
        staking.setVariables(defaultVariables);

        // Verify the change
        assertEq(staking.variables().buyCooldownPeriod, newCooldownPeriod, "Buy cooldown period not updated");
        assertEq(oldCooldownPeriod, 1 days, "Old cooldown period should be 1 day");

        vm.stopPrank();
    }

    function test_SetBuyCooldownPeriodZero() public {
        vm.startPrank(owner);

        // Try to set zero cooldown period
        defaultVariables.buyCooldownPeriod = 0;
        vm.expectRevert("Invalid buy cooldown period");
        staking.setVariables(defaultVariables);

        vm.stopPrank();
    }

    function test_SetBuyCooldownPeriodNotGovernor() public {
        vm.startPrank(user1);

        // Non-governor tries to set cooldown period
        vm.expectRevert("UNAUTHORIZED");
        defaultVariables.buyCooldownPeriod = 0;
        staking.setVariables(defaultVariables);

        vm.stopPrank();
    }

    function test_BuyCooldownWithDifferentPeriods() public {
        vm.startPrank(owner);
        authority.addPolicy(user1);

        // Set a shorter cooldown period for testing
        defaultVariables.buyCooldownPeriod = 1 hours;
        staking.setVariables(defaultVariables);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Prepare buyer
        app.mint(user1, DECLARED_VALUE);
        vm.stopPrank();

        // Buyer purchases the position
        vm.startPrank(user1);
        app.approve(address(staking), DECLARED_VALUE);
        staking.buyPosition(tokenId);

        // Verify cooldown is set with new period
        assertEq(
            staking.getBuyCooldownEnd(tokenId), block.timestamp + 1 hours, "Buy cooldown end time should use new period"
        );

        // Fast forward past new cooldown period
        vm.warp(block.timestamp + 1 hours + 1);

        // Prepare second buyer
        app.mint(user2, DECLARED_VALUE);
        vm.stopPrank();

        // Second buyer should be able to buy now
        vm.startPrank(user2);
        app.approve(address(staking), DECLARED_VALUE);
        staking.buyPosition(tokenId);

        // Verify ownership transfer
        assertEq(staking.ownerOf(tokenId), user2, "Position ownership not transferred after shorter cooldown");

        vm.stopPrank();
    }

    function testFuzz_BuyCooldown(uint256 stakeAmount, uint256 declaredValue, uint256 cooldownPeriod) public {
        // Bound the inputs to reasonable ranges
        stakeAmount = bound(stakeAmount, 1e18, 1000000e18);
        declaredValue = bound(declaredValue, stakeAmount, stakeAmount * 2);
        cooldownPeriod = bound(cooldownPeriod, 1 hours, 7 days);

        vm.startPrank(owner);
        authority.addPolicy(user1);

        // Set custom cooldown period
        defaultVariables.buyCooldownPeriod = cooldownPeriod;
        staking.setVariables(defaultVariables);

        // Create position
        app.mint(owner, stakeAmount);
        app.approve(address(staking), stakeAmount);
        (uint256 tokenId,) = staking.createPosition(owner, stakeAmount, declaredValue, 0);

        // Prepare buyer
        app.mint(user1, declaredValue);
        vm.stopPrank();

        // Buyer purchases the position
        vm.startPrank(user1);
        app.approve(address(staking), declaredValue);
        staking.buyPosition(tokenId);

        // Verify cooldown is set correctly
        IAppStaking.Position memory position = staking.positions(tokenId);
        assertTrue(position.buyCooldownEnd > 0, "Position should be in buy cooldown");
        assertEq(position.buyCooldownEnd, block.timestamp + cooldownPeriod, "Buy cooldown end time incorrect");

        // Try to buy again immediately (should fail)
        app.mint(user2, declaredValue);
        vm.stopPrank();

        vm.startPrank(user2);
        app.approve(address(staking), declaredValue);
        vm.expectRevert("Position in buy cooldown");
        staking.buyPosition(tokenId);

        vm.stopPrank();
    }

    function test_BuyCooldownWithRewards() public {
        vm.startPrank(owner);
        authority.addPolicy(user1);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Add rewards
        app.mint(owner, REWARD_AMOUNT);
        app.approve(address(staking), REWARD_AMOUNT);
        staking.notifyRewardAmount(REWARD_AMOUNT);

        // Fast forward to accumulate rewards
        vm.warp(block.timestamp + staking.EPOCH_DURATION());

        // Prepare buyer
        app.mint(user1, DECLARED_VALUE);
        vm.stopPrank();

        // Buyer purchases the position
        vm.startPrank(user1);
        app.approve(address(staking), DECLARED_VALUE);
        staking.buyPosition(tokenId);

        // Verify buy cooldown is set and rewards were claimed
        IAppStaking.Position memory position = staking.positions(tokenId);
        assertTrue(position.buyCooldownEnd > 0, "Position should be in buy cooldown");
        assertGt(app.balanceOf(user1), 0, "Buyer should have received rewards");

        // Try to buy again immediately (should fail)
        app.mint(user2, DECLARED_VALUE);
        vm.stopPrank();

        vm.startPrank(user2);
        app.approve(address(staking), DECLARED_VALUE);
        vm.expectRevert("Position in buy cooldown");
        staking.buyPosition(tokenId);

        vm.stopPrank();
    }

    function test_BuyCooldownWithUnstaking() public {
        vm.startPrank(owner);
        authority.addPolicy(user1);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Start unstaking
        staking.startUnstaking(tokenId);

        // Prepare buyer
        app.mint(user1, DECLARED_VALUE);
        vm.stopPrank();

        // Buyer purchases the position (should cancel unstaking)
        vm.startPrank(user1);
        app.approve(address(staking), DECLARED_VALUE);
        staking.buyPosition(tokenId);

        // Verify buy cooldown is set and unstaking was cancelled
        IAppStaking.Position memory position = staking.positions(tokenId);
        assertTrue(position.buyCooldownEnd > 0, "Position should be in buy cooldown");
        assertEq(position.withdrawCooldownEnd, 0, "Unstaking should be cancelled");

        // Try to buy again immediately (should fail)
        app.mint(user2, DECLARED_VALUE);
        vm.stopPrank();

        vm.startPrank(user2);
        app.approve(address(staking), DECLARED_VALUE);
        vm.expectRevert("Position in buy cooldown");
        staking.buyPosition(tokenId);

        vm.stopPrank();
    }

    // ============ INPUT VALIDATION TESTS ============

    function test_CreatePositionWithValidInputs() public {
        vm.startPrank(owner);
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);

        // Create position with valid inputs
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Verify position was created successfully
        assertTrue(tokenId > 0, "Position should be created with valid inputs");
        assertEq(staking.ownerOf(tokenId), owner, "Position should be owned by creator");

        vm.stopPrank();
    }

    function test_CreatePositionWithZeroDeclaredValue_ShouldRevert() public {
        vm.startPrank(owner);
        vm.expectRevert("Declared value must be greater than 0");
        staking.createPosition(owner, STAKE_AMOUNT, 0, 0);
        vm.stopPrank();
    }

    function test_CreatePositionWithBothZero_ShouldRevert() public {
        vm.startPrank(owner);
        vm.expectRevert("Amount must be greater than 0");
        staking.createPosition(owner, 0, 0, 0);
        vm.stopPrank();
    }

    function test_CreatePositionWithVerySmallAmount_ShouldRevert() public {
        vm.startPrank(owner);
        // Mint tokens first so we can test the validation
        app.mint(owner, DECLARED_VALUE);
        app.approve(address(staking), DECLARED_VALUE);
        vm.expectRevert("Amount must be greater than 0");
        staking.createPosition(owner, 0, DECLARED_VALUE, 0);
        vm.stopPrank();
    }

    function test_CreatePositionWithVerySmallDeclaredValue_ShouldRevert() public {
        vm.startPrank(owner);
        // Mint tokens first so we can test the validation
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        vm.expectRevert("Declared value must be greater than 0");
        staking.createPosition(owner, STAKE_AMOUNT, 0, 0);
        vm.stopPrank();
    }

    function test_CreatePositionWithMinimumValidAmounts() public {
        vm.startPrank(owner);

        // Test with minimum valid amounts (1e18 = 1 token)
        uint256 minAmount = 1e18;
        uint256 minDeclaredValue = 1e18;

        app.mint(owner, minAmount);
        app.approve(address(staking), minAmount);

        (uint256 tokenId,) = staking.createPosition(owner, minAmount, minDeclaredValue, 0);

        // Verify position was created successfully
        assertTrue(tokenId > 0, "Position should be created with minimum valid amounts");
        assertEq(staking.ownerOf(tokenId), owner, "Position should be owned by creator");

        vm.stopPrank();
    }

    function test_CreatePositionWithInsufficientBalance_ShouldRevert() public {
        vm.startPrank(owner);

        // Don't mint any tokens, so owner has 0 balance
        app.approve(address(staking), STAKE_AMOUNT);

        // This should revert due to insufficient balance
        vm.expectRevert();
        staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        vm.stopPrank();
    }

    function test_CreatePositionWithInsufficientAllowance_ShouldRevert() public {
        vm.startPrank(owner);

        // Mint tokens but don't approve enough
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT / 2); // Only approve half

        // This should revert due to insufficient allowance
        vm.expectRevert();
        staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        vm.stopPrank();
    }

    function test_CreatePositionWithExactBalance() public {
        vm.startPrank(owner);

        // Mint exactly the amount needed
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);

        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Verify position was created successfully
        assertTrue(tokenId > 0, "Position should be created with exact balance");
        assertEq(staking.ownerOf(tokenId), owner, "Position should be owned by creator");

        vm.stopPrank();
    }

    function test_CreatePositionWithZeroAddress_ShouldRevert() public {
        vm.startPrank(owner);

        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);

        // This should revert due to zero address
        vm.expectRevert();
        staking.createPosition(address(0), STAKE_AMOUNT, DECLARED_VALUE, 0);

        vm.stopPrank();
    }

    function test_CreatePositionWithDifferentBeneficiary() public {
        vm.startPrank(owner);

        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);

        // Create position for a different beneficiary
        (uint256 tokenId,) = staking.createPosition(user1, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Verify position was created for the correct beneficiary
        assertTrue(tokenId > 0, "Position should be created for different beneficiary");
        assertEq(staking.ownerOf(tokenId), user1, "Position should be owned by beneficiary");

        vm.stopPrank();
    }

    function test_DynamicFeeParameters() public view {
        IAppStaking.Variables memory variables = staking.variables();
        assertEq(variables.lowDemandThreshold, LOW_DEMAND_THRESHOLD_BPS, "Low demand threshold not set correctly");
        assertEq(variables.highDemandThreshold, HIGH_DEMAND_THRESHOLD_BPS, "High demand threshold not set correctly");
        assertEq(variables.maxDepositFee, MAX_DEPOSIT_FEE_BPS, "Max deposit fee not set correctly");
    }

    function test_Market_HighDemand() public {
        vm.startPrank(owner);

        // Mint RZR tokens to owner
        app.mint(owner, STAKE_AMOUNT);
        app.mint(user1, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);

        // Tax that user will pay. Initial tax is 0%
        uint256 tax = (staking.getDepositFee() * STAKE_AMOUNT) / 1e18;

        // Create position
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Verify position details
        IAppStaking.Position memory position = staking.positions(tokenId);

        assertEq(position.declaredValue, DECLARED_VALUE);
        assertEq(position.withdrawCooldownEnd, 0);
        assertEq(position.amount, STAKE_AMOUNT);
        assertEq(staking.totalStaked(), STAKE_AMOUNT);
        vm.stopPrank();

        tax = (staking.getDepositFee() * STAKE_AMOUNT) / 1e18; // Tax will be 5%

        vm.startPrank(user1);
        app.approve(address(staking), STAKE_AMOUNT);
        (tokenId,) = staking.createPosition(user1, STAKE_AMOUNT, DECLARED_VALUE, 0);
        vm.stopPrank();

        position = staking.positions(tokenId);
        assertEq(position.amount, STAKE_AMOUNT - tax);
        assertEq(position.declaredValue, DECLARED_VALUE);
        assertEq(position.withdrawCooldownEnd, 0);
    }

    function test_Market_LowDemand() public {
        vm.startPrank(owner);

        // Mint RZR tokens to owner
        app.mint(owner, STAKE_AMOUNT);
        app.mint(user1, STAKE_AMOUNT * 5);

        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);
        vm.stopPrank();

        vm.startPrank(user1);
        app.approve(address(staking), STAKE_AMOUNT);
        uint256 tax = (staking.getDepositFee() * STAKE_AMOUNT) / 1e18; // Tax will be 0%
        (tokenId,) = staking.createPosition(user1, STAKE_AMOUNT, DECLARED_VALUE, 0);
        vm.stopPrank();

        IAppStaking.Position memory position = staking.positions(tokenId);

        assertEq(position.amount, STAKE_AMOUNT - tax);
        assertEq(position.declaredValue, DECLARED_VALUE);
        assertEq(position.withdrawCooldownEnd, 0);

        vm.stopPrank();
    }
}
