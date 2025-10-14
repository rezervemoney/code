// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./BaseTest.sol";
import "../../contracts/core/AppVeStaking.sol";
import "../../contracts/libraries/PermissionedERC20Factory.sol";
import "../../contracts/mocks/MockERC20.sol";

contract AppVeStakingTest is BaseTest {
    AppVeStaking public veStaking;
    PermissionedERC20Factory public factory;

    uint256 public constant MAX_LOCK_DURATION = 6 * 30 days; // 6 months
    uint256 public constant LOCK_AMOUNT = 1000e18;
    uint256 public constant LOCK_DURATION = 30 days;

    event Locked(address indexed user, address indexed receiver, uint256 amount, uint256 duration);
    event Unlocked(address indexed user, uint256 tokenId, uint256 amount);
    event LockDurationIncreased(address indexed user, uint256 tokenId, uint256 duration);
    event LockAmountIncreased(address indexed user, uint256 tokenId, uint256 amount);
    event PositionTransferred(address indexed from, address indexed to, uint256 tokenId, uint256 amount);
    event PositionBlacklisted(uint256 tokenId);

    function setUp() public {
        setUpBaseTest();

        vm.startPrank(owner);

        // Deploy factory
        factory = new PermissionedERC20Factory();

        // Deploy veStaking contract as proxy
        veStaking = new AppVeStaking();
        veStaking.initialize(address(app), address(factory), address(authority));

        // Add veStaking as policy to allow minting voting power tokens
        authority.addPolicy(address(veStaking));

        // Mint RZR tokens to users
        app.mint(user1, 100000e18);
        app.mint(user2, 100000e18);
        app.mint(user3, 100000e18);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Initialize() public view {
        assertEq(address(veStaking.rzr()), address(app));
        assertEq(address(veStaking.authority()), address(authority));
        assertEq(veStaking.lastId(), 1);
        assertEq(veStaking.totalLocked(), 0);
        assertEq(veStaking.name(), "RZR Staking Position");
        assertEq(veStaking.symbol(), "RZR-POS");
        assertEq(veStaking.MAX_LOCK_DURATION(), MAX_LOCK_DURATION);
    }

    function test_VotingPowerTokenInitialized() public view {
        assertNotEq(address(veStaking.votingPowerToken()), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                            LOCK TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Lock() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 duration = LOCK_DURATION;
        uint256 expectedVotingPower = amount * duration / MAX_LOCK_DURATION;

        vm.startPrank(user1);
        app.approve(address(veStaking), amount);

        vm.expectEmit(true, true, false, true);
        emit Locked(user1, user1, amount, duration);

        veStaking.lock(amount, duration, user1);

        vm.stopPrank();

        // Verify NFT minted
        assertEq(veStaking.lastId(), 2);
        assertEq(veStaking.ownerOf(2), user1);
        assertEq(veStaking.balanceOf(user1), 1);

        // Verify lock data
        (uint256 lockedAmount, uint256 lockedDuration, uint256 votingPower, uint256 lockStartDate, uint256 lockEndDate)
        = veStaking.locks(2);

        assertEq(lockedAmount, amount);
        assertEq(lockedDuration, duration);
        assertEq(votingPower, expectedVotingPower);
        assertEq(lockStartDate, block.timestamp);
        assertEq(lockEndDate, block.timestamp + duration);

        // Verify total locked
        assertEq(veStaking.totalLocked(), amount);

        // Verify voting power minted
        assertEq(veStaking.votingPowerToken().balanceOf(user1), expectedVotingPower);
    }

    function test_Lock_DifferentReceiver() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 duration = LOCK_DURATION;

        vm.startPrank(user1);
        app.approve(address(veStaking), amount);

        vm.expectEmit(true, true, false, true);
        emit Locked(user1, user2, amount, duration);

        veStaking.lock(amount, duration, user2);

        vm.stopPrank();

        // user2 should own the NFT
        assertEq(veStaking.ownerOf(2), user2);
        assertEq(veStaking.balanceOf(user2), 1);

        // user2 should have voting power
        uint256 expectedVotingPower = amount * duration / MAX_LOCK_DURATION;
        assertEq(veStaking.votingPowerToken().balanceOf(user2), expectedVotingPower);
    }

    function test_Lock_MaxDuration() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 duration = MAX_LOCK_DURATION;
        uint256 expectedVotingPower = amount; // Full voting power at max duration

        vm.startPrank(user1);
        app.approve(address(veStaking), amount);

        veStaking.lock(amount, duration, user1);

        vm.stopPrank();

        assertEq(veStaking.votingPowerToken().balanceOf(user1), expectedVotingPower);
    }

    function test_Lock_MultipleLocks() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 duration = LOCK_DURATION;

        // User1 creates first lock
        vm.startPrank(user1);
        app.approve(address(veStaking), amount * 2);
        veStaking.lock(amount, duration, user1);
        veStaking.lock(amount, duration, user1);
        vm.stopPrank();

        // User2 creates lock
        vm.startPrank(user2);
        app.approve(address(veStaking), amount);
        veStaking.lock(amount, duration, user2);
        vm.stopPrank();

        assertEq(veStaking.lastId(), 4);
        assertEq(veStaking.balanceOf(user1), 2);
        assertEq(veStaking.balanceOf(user2), 1);
        assertEq(veStaking.totalLocked(), amount * 3);
    }

    function test_RevertWhen_LockZeroAmount() public {
        vm.startPrank(user1);
        app.approve(address(veStaking), LOCK_AMOUNT);

        vm.expectRevert("Amount must be greater than 0");
        veStaking.lock(0, LOCK_DURATION, user1);

        vm.stopPrank();
    }

    function test_RevertWhen_LockZeroDuration() public {
        vm.startPrank(user1);
        app.approve(address(veStaking), LOCK_AMOUNT);

        vm.expectRevert("Duration must be greater than 0");
        veStaking.lock(LOCK_AMOUNT, 0, user1);

        vm.stopPrank();
    }

    function test_RevertWhen_LockExceedsMaxDuration() public {
        vm.startPrank(user1);
        app.approve(address(veStaking), LOCK_AMOUNT);

        vm.expectRevert("Max lock duration exceeded");
        veStaking.lock(LOCK_AMOUNT, MAX_LOCK_DURATION + 1, user1);

        vm.stopPrank();
    }

    function test_RevertWhen_LockInvalidReceiver() public {
        vm.startPrank(user1);
        app.approve(address(veStaking), LOCK_AMOUNT);

        vm.expectRevert("Invalid receiver address");
        veStaking.lock(LOCK_AMOUNT, LOCK_DURATION, address(0));

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            UNLOCK TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Unlock() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 duration = LOCK_DURATION;

        // Create lock
        vm.startPrank(user1);
        app.approve(address(veStaking), amount);
        veStaking.lock(amount, duration, user1);
        uint256 tokenId = veStaking.lastId();
        vm.stopPrank();

        uint256 votingPowerBefore = veStaking.votingPowerToken().balanceOf(user1);

        // Warp to end of lock
        vm.warp(block.timestamp + duration + 1);

        // Unlock
        vm.startPrank(user1);
        uint256 balanceBefore = app.balanceOf(user1);

        vm.expectEmit(true, false, false, true);
        emit Unlocked(user1, tokenId, amount);

        veStaking.unlock(tokenId);

        uint256 balanceAfter = app.balanceOf(user1);
        vm.stopPrank();

        // Verify RZR returned
        assertEq(balanceAfter - balanceBefore, amount);

        // Verify NFT burned
        vm.expectRevert();
        veStaking.ownerOf(tokenId);
        assertEq(veStaking.balanceOf(user1), 0);

        // Verify voting power burned
        assertEq(veStaking.votingPowerToken().balanceOf(user1), 0);
        assertEq(votingPowerBefore, amount * duration / MAX_LOCK_DURATION);

        // Verify total locked decreased
        assertEq(veStaking.totalLocked(), 0);

        // Verify lock data deleted
        (uint256 lockedAmount,,,,) = veStaking.locks(tokenId);
        assertEq(lockedAmount, 0);
    }

    function test_Unlock_AtExactEndTime() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 duration = LOCK_DURATION;

        vm.startPrank(user1);
        app.approve(address(veStaking), amount);
        veStaking.lock(amount, duration, user1);
        uint256 tokenId = veStaking.lastId();
        vm.stopPrank();

        // Warp to exact end time
        vm.warp(block.timestamp + duration);

        // Should succeed at exact end time
        vm.prank(user1);
        veStaking.unlock(tokenId);

        assertEq(veStaking.totalLocked(), 0);
    }

    function test_RevertWhen_UnlockBeforeEnd() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 duration = LOCK_DURATION;

        vm.startPrank(user1);
        app.approve(address(veStaking), amount);
        veStaking.lock(amount, duration, user1);
        uint256 tokenId = veStaking.lastId();

        vm.expectRevert("Lock not ended");
        veStaking.unlock(tokenId);

        vm.stopPrank();
    }

    function test_RevertWhen_UnlockNotOwner() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 duration = LOCK_DURATION;

        vm.startPrank(user1);
        app.approve(address(veStaking), amount);
        veStaking.lock(amount, duration, user1);
        uint256 tokenId = veStaking.lastId();
        vm.stopPrank();

        vm.warp(block.timestamp + duration + 1);

        // User2 tries to unlock user1's position
        vm.startPrank(user2);
        vm.expectRevert("Not owner or approved");
        veStaking.unlock(tokenId);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    INCREASE LOCK DURATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_IncreaseLockDuration() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 initialDuration = LOCK_DURATION;
        uint256 additionalDuration = 15 days;

        // Create lock
        vm.startPrank(user1);
        app.approve(address(veStaking), amount);
        veStaking.lock(amount, initialDuration, user1);
        uint256 tokenId = veStaking.lastId();

        uint256 votingPowerBefore = veStaking.votingPowerToken().balanceOf(user1);

        // Increase duration
        vm.expectEmit(true, false, false, true);
        emit LockDurationIncreased(user1, tokenId, initialDuration + additionalDuration);

        veStaking.increaseLockDuration(tokenId, additionalDuration);

        vm.stopPrank();

        // Verify lock updated
        (uint256 lockedAmount, uint256 lockedDuration, uint256 votingPower, uint256 lockStartDate, uint256 lockEndDate)
        = veStaking.locks(tokenId);

        assertEq(lockedAmount, amount);
        assertEq(lockedDuration, initialDuration + additionalDuration);
        assertEq(lockEndDate, lockStartDate + initialDuration + additionalDuration);

        // Verify voting power increased
        uint256 votingPowerAfter = veStaking.votingPowerToken().balanceOf(user1);
        assertGt(votingPowerAfter, votingPowerBefore);
        assertEq(votingPowerAfter, votingPower);

        uint256 expectedVotingPower = amount * (initialDuration + additionalDuration) / MAX_LOCK_DURATION;
        assertEq(votingPowerAfter, expectedVotingPower);
    }

    function test_IncreaseLockDuration_ToMax() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 initialDuration = 30 days;

        vm.startPrank(user1);
        app.approve(address(veStaking), amount);
        veStaking.lock(amount, initialDuration, user1);
        uint256 tokenId = veStaking.lastId();

        // Increase to max
        uint256 additionalDuration = MAX_LOCK_DURATION - initialDuration;
        veStaking.increaseLockDuration(tokenId, additionalDuration);

        vm.stopPrank();

        // Verify voting power is now 1:1 with amount
        assertEq(veStaking.votingPowerToken().balanceOf(user1), amount);
    }

    function test_RevertWhen_IncreaseLockDurationExceedsMax() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 initialDuration = MAX_LOCK_DURATION - 10 days;

        vm.startPrank(user1);
        app.approve(address(veStaking), amount);
        veStaking.lock(amount, initialDuration, user1);
        uint256 tokenId = veStaking.lastId();

        vm.expectRevert("Max lock duration exceeded");
        veStaking.increaseLockDuration(tokenId, 15 days);

        vm.stopPrank();
    }

    function test_RevertWhen_IncreaseLockDurationAfterExpiry() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 duration = LOCK_DURATION;

        vm.startPrank(user1);
        app.approve(address(veStaking), amount);
        veStaking.lock(amount, duration, user1);
        uint256 tokenId = veStaking.lastId();
        vm.stopPrank();

        // Warp past end
        vm.warp(block.timestamp + duration + 1);

        vm.startPrank(user1);
        vm.expectRevert("Lock ended");
        veStaking.increaseLockDuration(tokenId, 10 days);
        vm.stopPrank();
    }

    function test_RevertWhen_IncreaseLockDurationNotOwner() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 duration = LOCK_DURATION;

        vm.startPrank(user1);
        app.approve(address(veStaking), amount);
        veStaking.lock(amount, duration, user1);
        uint256 tokenId = veStaking.lastId();
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert("Not owner or approved");
        veStaking.increaseLockDuration(tokenId, 10 days);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    INCREASE LOCK AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_IncreaseLockAmount() public {
        uint256 initialAmount = LOCK_AMOUNT;
        uint256 additionalAmount = 500e18;
        uint256 duration = LOCK_DURATION;

        // Create lock
        vm.startPrank(user1);
        app.approve(address(veStaking), initialAmount + additionalAmount);
        veStaking.lock(initialAmount, duration, user1);
        uint256 tokenId = veStaking.lastId();

        uint256 votingPowerBefore = veStaking.votingPowerToken().balanceOf(user1);

        // Increase amount
        vm.expectEmit(true, false, false, true);
        emit LockAmountIncreased(user1, tokenId, additionalAmount);

        veStaking.increaseLockAmount(tokenId, additionalAmount);

        vm.stopPrank();

        // Verify lock updated
        (uint256 lockedAmount, uint256 lockedDuration, uint256 votingPower,,) = veStaking.locks(tokenId);

        assertEq(lockedAmount, initialAmount + additionalAmount);
        assertEq(lockedDuration, duration);

        // Verify voting power increased
        uint256 votingPowerAfter = veStaking.votingPowerToken().balanceOf(user1);
        assertGt(votingPowerAfter, votingPowerBefore);
        assertEq(votingPowerAfter, votingPower);

        uint256 expectedVotingPower = (initialAmount + additionalAmount) * duration / MAX_LOCK_DURATION;
        assertEq(votingPowerAfter, expectedVotingPower);

        // Verify total locked increased
        assertEq(veStaking.totalLocked(), initialAmount + additionalAmount);
    }

    function test_IncreaseLockAmount_AnyoneCanIncrease() public {
        uint256 initialAmount = LOCK_AMOUNT;
        uint256 additionalAmount = 500e18;
        uint256 duration = LOCK_DURATION;

        // User1 creates lock
        vm.startPrank(user1);
        app.approve(address(veStaking), initialAmount);
        veStaking.lock(initialAmount, duration, user1);
        uint256 tokenId = veStaking.lastId();
        vm.stopPrank();

        // User2 increases user1's lock amount (this is allowed)
        vm.startPrank(user2);
        app.approve(address(veStaking), additionalAmount);
        veStaking.increaseLockAmount(tokenId, additionalAmount);
        vm.stopPrank();

        // Verify lock updated and voting power goes to user1
        (uint256 lockedAmount,,,,) = veStaking.locks(tokenId);
        assertEq(lockedAmount, initialAmount + additionalAmount);

        uint256 expectedVotingPower = (initialAmount + additionalAmount) * duration / MAX_LOCK_DURATION;
        assertEq(veStaking.votingPowerToken().balanceOf(user1), expectedVotingPower);
    }

    function test_IncreaseLockAmount_Multiple() public {
        uint256 initialAmount = LOCK_AMOUNT;
        uint256 duration = LOCK_DURATION;

        vm.startPrank(user1);
        app.approve(address(veStaking), initialAmount + 1000e18);
        veStaking.lock(initialAmount, duration, user1);
        uint256 tokenId = veStaking.lastId();

        // First increase
        veStaking.increaseLockAmount(tokenId, 300e18);

        // Second increase
        veStaking.increaseLockAmount(tokenId, 200e18);

        vm.stopPrank();

        // Verify final amount
        (uint256 lockedAmount,,,,) = veStaking.locks(tokenId);
        assertEq(lockedAmount, initialAmount + 500e18);

        uint256 expectedVotingPower = (initialAmount + 500e18) * duration / MAX_LOCK_DURATION;
        assertEq(veStaking.votingPowerToken().balanceOf(user1), expectedVotingPower);
    }

    /*//////////////////////////////////////////////////////////////
                        NFT FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_NFTTransfer() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 duration = LOCK_DURATION;

        vm.startPrank(user1);
        app.approve(address(veStaking), amount);
        veStaking.lock(amount, duration, user1);
        uint256 tokenId = veStaking.lastId();

        uint256 votingPower = veStaking.votingPowerToken().balanceOf(user1);

        // Transfer NFT to user2
        vm.expectEmit(true, true, false, true);
        emit PositionTransferred(user1, user2, tokenId, votingPower);

        veStaking.transferFrom(user1, user2, tokenId);

        vm.stopPrank();

        // Verify ownership transferred
        assertEq(veStaking.ownerOf(tokenId), user2);
        assertEq(veStaking.balanceOf(user1), 0);
        assertEq(veStaking.balanceOf(user2), 1);

        // Voting power now transfers WITH the NFT
        assertEq(veStaking.votingPowerToken().balanceOf(user1), 0);
        assertEq(veStaking.votingPowerToken().balanceOf(user2), votingPower);
    }

    function test_ApprovedCanUnlock() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 duration = LOCK_DURATION;

        vm.startPrank(user1);
        app.approve(address(veStaking), amount);
        veStaking.lock(amount, duration, user1);
        uint256 tokenId = veStaking.lastId();

        // Approve user2
        veStaking.setApprovalForAll(user2, true);
        vm.stopPrank();

        // Warp to end
        vm.warp(block.timestamp + duration + 1);

        // User2 can unlock
        vm.prank(user2);
        veStaking.unlock(tokenId);

        assertEq(veStaking.totalLocked(), 0);
    }

    function test_ApprovedCanIncreaseDuration() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 duration = LOCK_DURATION;

        vm.startPrank(user1);
        app.approve(address(veStaking), amount);
        veStaking.lock(amount, duration, user1);
        uint256 tokenId = veStaking.lastId();

        // Approve user2
        veStaking.setApprovalForAll(user2, true);
        vm.stopPrank();

        // User2 can increase duration
        vm.prank(user2);
        veStaking.increaseLockDuration(tokenId, 10 days);

        (, uint256 lockedDuration,,,) = veStaking.locks(tokenId);
        assertEq(lockedDuration, duration + 10 days);
    }

    /*//////////////////////////////////////////////////////////////
                        ENUMERABLE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_TokenEnumeration() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 duration = LOCK_DURATION;

        // User1 creates 3 locks
        vm.startPrank(user1);
        app.approve(address(veStaking), amount * 3);
        veStaking.lock(amount, duration, user1);
        veStaking.lock(amount, duration, user1);
        veStaking.lock(amount, duration, user1);
        vm.stopPrank();

        assertEq(veStaking.balanceOf(user1), 3);
        assertEq(veStaking.tokenOfOwnerByIndex(user1, 0), 2);
        assertEq(veStaking.tokenOfOwnerByIndex(user1, 1), 3);
        assertEq(veStaking.tokenOfOwnerByIndex(user1, 2), 4);
        assertEq(veStaking.totalSupply(), 3);
    }

    /*//////////////////////////////////////////////////////////////
                        VOTING POWER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_VotingPowerCalculation() public view {
        // Test various durations
        uint256 amount = 1000e18;

        // 1 month = ~1/6 of max
        uint256 vp1Month = veStaking.votingPower(amount, 30 days);
        assertEq(vp1Month, amount * 30 days / MAX_LOCK_DURATION);

        // 3 months = 1/2 of max
        uint256 vp3Months = veStaking.votingPower(amount, 90 days);
        assertEq(vp3Months, amount * 90 days / MAX_LOCK_DURATION);

        // Max duration = full voting power
        uint256 vpMax = veStaking.votingPower(amount, MAX_LOCK_DURATION);
        assertEq(vpMax, amount);
    }

    function test_VotingPowerScalesLinearly() public view {
        uint256 amount = 1000e18;
        uint256 duration1 = 30 days;
        uint256 duration2 = 60 days;

        uint256 vp1 = veStaking.votingPower(amount, duration1);
        uint256 vp2 = veStaking.votingPower(amount, duration2);

        // Double duration should approximately double voting power (accounting for rounding)
        assertApproxEqAbs(vp2, vp1 * 2, 1);
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_LockWithMinimalDuration() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 duration = 1; // 1 second

        vm.startPrank(user1);
        app.approve(address(veStaking), amount);
        veStaking.lock(amount, duration, user1);
        uint256 tokenId = veStaking.lastId();
        vm.stopPrank();

        // Should succeed with minimal voting power
        uint256 votingPower = veStaking.votingPowerToken().balanceOf(user1);
        assertGt(votingPower, 0);

        // Can unlock immediately after 1 second
        vm.warp(block.timestamp + 1);
        vm.prank(user1);
        veStaking.unlock(tokenId);
    }

    function test_MultipleUsersIndependentLocks() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 duration = LOCK_DURATION;

        // User1 locks
        vm.startPrank(user1);
        app.approve(address(veStaking), amount);
        veStaking.lock(amount, duration, user1);
        vm.stopPrank();

        // User2 locks with different duration
        vm.startPrank(user2);
        app.approve(address(veStaking), amount);
        veStaking.lock(amount, duration * 2, user2);
        vm.stopPrank();

        // User3 locks with max duration
        vm.startPrank(user3);
        app.approve(address(veStaking), amount);
        veStaking.lock(amount, MAX_LOCK_DURATION, user3);
        vm.stopPrank();

        // Verify voting powers are different
        uint256 vp1 = veStaking.votingPowerToken().balanceOf(user1);
        uint256 vp2 = veStaking.votingPowerToken().balanceOf(user2);
        uint256 vp3 = veStaking.votingPowerToken().balanceOf(user3);

        assertLt(vp1, vp2);
        assertLt(vp2, vp3);
        assertEq(vp3, amount); // Max duration gives 1:1 voting power
    }

    function test_TotalLockedTracking() public {
        uint256 amount1 = 1000e18;
        uint256 amount2 = 2000e18;
        uint256 amount3 = 1500e18;
        uint256 duration = LOCK_DURATION;

        // Multiple locks
        vm.prank(user1);
        app.approve(address(veStaking), amount1);
        vm.prank(user1);
        veStaking.lock(amount1, duration, user1);

        assertEq(veStaking.totalLocked(), amount1);

        vm.prank(user2);
        app.approve(address(veStaking), amount2);
        vm.prank(user2);
        veStaking.lock(amount2, duration, user2);

        assertEq(veStaking.totalLocked(), amount1 + amount2);

        vm.prank(user3);
        app.approve(address(veStaking), amount3);
        vm.prank(user3);
        veStaking.lock(amount3, duration, user3);

        assertEq(veStaking.totalLocked(), amount1 + amount2 + amount3);

        // Unlock one
        vm.warp(block.timestamp + duration + 1);
        vm.prank(user1);
        veStaking.unlock(2);

        assertEq(veStaking.totalLocked(), amount2 + amount3);
    }

    function test_IncreaseLockAfterPartialDuration() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 duration = 60 days;

        vm.startPrank(user1);
        app.approve(address(veStaking), amount * 2);
        veStaking.lock(amount, duration, user1);
        uint256 tokenId = veStaking.lastId();

        // Warp halfway through lock
        vm.warp(block.timestamp + 30 days);

        // Increase amount (should still work)
        veStaking.increaseLockAmount(tokenId, amount);

        vm.stopPrank();

        // Verify increased
        (uint256 lockedAmount,,,,) = veStaking.locks(tokenId);
        assertEq(lockedAmount, amount * 2);
    }

    /*//////////////////////////////////////////////////////////////
                        BLACKLIST TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Blacklist() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 duration = LOCK_DURATION;

        // Create lock
        vm.startPrank(user1);
        app.approve(address(veStaking), amount);
        veStaking.lock(amount, duration, user1);
        uint256 tokenId = veStaking.lastId();
        vm.stopPrank();

        // Owner blacklists position
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit PositionBlacklisted(tokenId);
        veStaking.blacklist(tokenId);

        // Verify blacklisted
        assertTrue(veStaking.blacklisted(tokenId));
    }

    function test_RevertWhen_BlacklistedUnlock() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 duration = LOCK_DURATION;

        // Create lock
        vm.startPrank(user1);
        app.approve(address(veStaking), amount);
        veStaking.lock(amount, duration, user1);
        uint256 tokenId = veStaking.lastId();
        vm.stopPrank();

        // Blacklist
        vm.prank(owner);
        veStaking.blacklist(tokenId);

        // Try to unlock after duration
        vm.warp(block.timestamp + duration + 1);

        vm.startPrank(user1);
        vm.expectRevert("Blacklisted");
        veStaking.unlock(tokenId);
        vm.stopPrank();
    }

    function test_RevertWhen_BlacklistedIncreaseDuration() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 duration = LOCK_DURATION;

        // Create lock
        vm.startPrank(user1);
        app.approve(address(veStaking), amount);
        veStaking.lock(amount, duration, user1);
        uint256 tokenId = veStaking.lastId();
        vm.stopPrank();

        // Blacklist
        vm.prank(owner);
        veStaking.blacklist(tokenId);

        // Try to increase duration
        vm.startPrank(user1);
        vm.expectRevert("Blacklisted");
        veStaking.increaseLockDuration(tokenId, 10 days);
        vm.stopPrank();
    }

    function test_RevertWhen_BlacklistedTransfer() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 duration = LOCK_DURATION;

        // Create lock
        vm.startPrank(user1);
        app.approve(address(veStaking), amount);
        veStaking.lock(amount, duration, user1);
        uint256 tokenId = veStaking.lastId();
        vm.stopPrank();

        // Blacklist
        vm.prank(owner);
        veStaking.blacklist(tokenId);

        // Try to transfer
        vm.startPrank(user1);
        vm.expectRevert("Blacklisted");
        veStaking.transferFrom(user1, user2, tokenId);
        vm.stopPrank();
    }

    function test_RevertWhen_BlacklistNotAuthorized() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 duration = LOCK_DURATION;

        vm.startPrank(user1);
        app.approve(address(veStaking), amount);
        veStaking.lock(amount, duration, user1);
        uint256 tokenId = veStaking.lastId();
        vm.stopPrank();

        // User1 tries to blacklist (not guardian/governor)
        vm.startPrank(user1);
        vm.expectRevert();
        veStaking.blacklist(tokenId);
        vm.stopPrank();
    }

    function test_BlacklistDoesNotAffectIncreaseLockAmount() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 duration = LOCK_DURATION;

        // Create lock
        vm.startPrank(user1);
        app.approve(address(veStaking), amount * 2);
        veStaking.lock(amount, duration, user1);
        uint256 tokenId = veStaking.lastId();
        vm.stopPrank();

        // Blacklist
        vm.prank(owner);
        veStaking.blacklist(tokenId);

        // Anyone can still increase lock amount (no blacklist check)
        vm.startPrank(user2);
        app.approve(address(veStaking), amount);
        veStaking.increaseLockAmount(tokenId, amount);
        vm.stopPrank();

        // Verify increased
        (uint256 lockedAmount,,,,) = veStaking.locks(tokenId);
        assertEq(lockedAmount, amount * 2);
    }

    /*//////////////////////////////////////////////////////////////
                    VOTING POWER TRANSFER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_VotingPowerTransfersWithNFT() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 duration = LOCK_DURATION;

        // User1 creates lock
        vm.startPrank(user1);
        app.approve(address(veStaking), amount);
        veStaking.lock(amount, duration, user1);
        uint256 tokenId = veStaking.lastId();

        uint256 votingPower = veStaking.votingPowerToken().balanceOf(user1);
        assertGt(votingPower, 0);

        // Transfer to user2
        veStaking.transferFrom(user1, user2, tokenId);
        vm.stopPrank();

        // Voting power transferred to user2
        assertEq(veStaking.votingPowerToken().balanceOf(user1), 0);
        assertEq(veStaking.votingPowerToken().balanceOf(user2), votingPower);

        // User2 can now transfer to user3
        vm.startPrank(user2);
        veStaking.transferFrom(user2, user3, tokenId);
        vm.stopPrank();

        // Voting power transferred to user3
        assertEq(veStaking.votingPowerToken().balanceOf(user2), 0);
        assertEq(veStaking.votingPowerToken().balanceOf(user3), votingPower);
    }

    function test_VotingPowerAfterTransferAndUnlock() public {
        uint256 amount = LOCK_AMOUNT;
        uint256 duration = LOCK_DURATION;

        // User1 creates lock
        vm.startPrank(user1);
        app.approve(address(veStaking), amount);
        veStaking.lock(amount, duration, user1);
        uint256 tokenId = veStaking.lastId();

        // Transfer to user2
        veStaking.transferFrom(user1, user2, tokenId);
        vm.stopPrank();

        // Warp to unlock time
        vm.warp(block.timestamp + duration + 1);

        // User2 can unlock and voting power is burned from user2
        vm.prank(user2);
        veStaking.unlock(tokenId);

        // Verify voting power burned
        assertEq(veStaking.votingPowerToken().balanceOf(user1), 0);
        assertEq(veStaking.votingPowerToken().balanceOf(user2), 0);

        // RZR goes to user2 (current owner)
        assertGt(app.balanceOf(user2), 0);
    }
}
