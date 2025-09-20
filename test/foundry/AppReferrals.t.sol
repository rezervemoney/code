// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "./BaseTest.sol";
import "../../contracts/core/AppReferrals.sol";
import "../../contracts/core/AppBondDepository.sol";
import "../../contracts/core/AppStaking.sol";
import "../../contracts/core/RZR.sol";
import "../../contracts/core/AppTreasury.sol";
import "../../contracts/core/AppAuthority.sol";
import "../../contracts/mocks/MockERC4626.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract AppReferralsTest is BaseTest {
    AppReferrals public referrals;
    MockERC4626 public mockBond4626;

    address public MERKLE_SERVER = makeAddr("merkle_server");
    address public ALICE = makeAddr("alice");
    address public BOB = makeAddr("bob");
    address public CHARLIE = makeAddr("charlie");

    // Events
    event ReferralCodeRegistered(address indexed referrer, bytes8 code);
    event ReferralRegistered(address indexed referred, bytes8 indexed referrerCode);
    event ReferralStaked(address indexed to, uint256 amount, uint256 declaredValue, bytes8 referralCode);
    event ReferralBondBought(address indexed user, uint256 payout, bytes8 referralCode);
    event ReferralStakedIntoLST(address indexed user, uint256 amount, bytes8 referralCode);
    event RewardsClaimed(address indexed user, uint256 amount, bytes32 root);

    function setUp() public {
        // Setup base contracts
        setUpBaseTest();

        // Deploy mock 4626 vault for bonds
        mockBond4626 = new MockERC4626("Mock Bond Vault", "MBV", mockQuoteToken);

        // Setup referrals contract
        referrals = new AppReferrals();
        referrals.initialize(
            address(app),        // _rzr
            address(mockQuoteToken), // _usdr (using mock token as USDR)
            address(mockBond4626), // _bond4626
            address(treasury),   // _usdtreasury
            address(treasury),   // _appTreasury
            address(staking),    // _staking
            address(staking4626), // _staking4626
            address(authority),   // _authority
            true // _allowReferralCodeRegistration
        );

        // Set merkle server
        vm.startPrank(owner);
        referrals.setMerkleServer(MERKLE_SERVER);
        authority.addPolicy(MERKLE_SERVER);
        vm.stopPrank();

        // Label addresses for better trace output
        vm.label(MERKLE_SERVER, "MERKLE_SERVER");
        vm.label(ALICE, "ALICE");
        vm.label(BOB, "BOB");
        vm.label(CHARLIE, "CHARLIE");
        vm.label(address(mockBond4626), "MockBond4626");
    }

    function test_ReferralCodeGeneration() public {
        // Alice generates a referral code
        vm.startPrank(ALICE);
        bytes8 aliceCode = bytes8(bytes20(ALICE));

        vm.expectEmit(true, true, false, true);
        emit ReferralCodeRegistered(ALICE, aliceCode);
        referrals.registerReferralCode(aliceCode);
        vm.stopPrank();

        // Verify code is registered
        assertEq(referrals.referralCodeToUser(aliceCode), ALICE);
        assertEq(referrals.userToReferralCode(ALICE), aliceCode);
    }

    function test_ReferralCodeGeneration_InvalidCode() public {
        vm.startPrank(ALICE);

        // Test with zero code
        vm.expectRevert("Invalid code");
        referrals.registerReferralCode(bytes8(0));
        vm.stopPrank();
    }

    function test_ReferralCodeGeneration_CodeAlreadyExists() public {
        // Alice registers a code
        vm.startPrank(ALICE);
        bytes8 aliceCode = bytes8(bytes20(ALICE));
        referrals.registerReferralCode(aliceCode);
        vm.stopPrank();

        // Bob tries to register the same code
        vm.startPrank(BOB);
        vm.expectRevert("Code already exists");
        referrals.registerReferralCode(aliceCode);
        vm.stopPrank();
    }

    function test_ReferralCodeGeneration_AlreadyRegistered() public {
        // Alice registers a code
        vm.startPrank(ALICE);
        bytes8 aliceCode = bytes8(bytes20(ALICE));
        referrals.registerReferralCode(aliceCode);
        vm.stopPrank();

        // Alice tries to register another code
        vm.startPrank(ALICE);
        bytes8 anotherCode = bytes8(bytes20(BOB));
        vm.expectRevert("Referral code already registered");
        referrals.registerReferralCode(anotherCode);
        vm.stopPrank();
    }

    function test_ReferralTracking() public {
        // Alice generates a referral code
        vm.startPrank(ALICE);
        bytes8 aliceCode = bytes8(bytes20(ALICE));
        referrals.registerReferralCode(aliceCode);
        vm.stopPrank();

        // Bob uses Alice's referral code to stake on behalf of Charlie
        vm.startPrank(BOB);
        uint256 stakeAmount = 1000e18;
        deal(address(app), BOB, stakeAmount);
        app.approve(address(referrals), stakeAmount);

        vm.expectEmit(true, true, false, true);
        emit ReferralRegistered(CHARLIE, aliceCode);
        vm.expectEmit(true, true, false, true);
        emit ReferralStaked(CHARLIE, stakeAmount, stakeAmount, aliceCode);
        referrals.stakeWithReferral(stakeAmount, stakeAmount, aliceCode, CHARLIE);
        vm.stopPrank();

        // Verify referral is tracked for Charlie (the person being staked for)
        address[] memory aliceReferrals = referrals.getReferrals(ALICE);
        assertEq(aliceReferrals.length, 1);
        assertEq(aliceReferrals[0], CHARLIE);
        assertEq(referrals.trackedReferrals(CHARLIE), aliceCode);
    }

    function test_ReferralTracking_InvalidReferralCode() public {
        // Bob tries to use a non-existent referral code
        vm.startPrank(BOB);
        uint256 stakeAmount = 1000e18;
        deal(address(app), BOB, stakeAmount);
        app.approve(address(referrals), stakeAmount);

        bytes8 invalidCode = bytes8(bytes20(CHARLIE)); // Charlie hasn't registered this code

        // Should not revert, and should still register referral even with invalid code
        vm.expectEmit(true, true, false, true);
        emit ReferralRegistered(CHARLIE, invalidCode);
        vm.expectEmit(true, true, false, true);
        emit ReferralStaked(CHARLIE, stakeAmount, stakeAmount, invalidCode);
        referrals.stakeWithReferral(stakeAmount, stakeAmount, invalidCode, CHARLIE);
        vm.stopPrank();

        // Verify referral is tracked even with invalid code
        address[] memory charlieReferrals = referrals.getReferrals(CHARLIE);
        assertEq(charlieReferrals.length, 0); // Charlie has no referrals since he hasn't registered a code
        assertEq(referrals.trackedReferrals(CHARLIE), invalidCode); // But Charlie is tracked with the invalid code
    }

    function test_ReferralTracking_AlreadyTracked() public {
        // Alice generates a referral code
        vm.startPrank(ALICE);
        bytes8 aliceCode = bytes8(bytes20(ALICE));
        referrals.registerReferralCode(aliceCode);
        vm.stopPrank();

        // Bob uses Alice's referral code to stake for Charlie
        vm.startPrank(BOB);
        uint256 stakeAmount = 1000e18;
        deal(address(app), BOB, stakeAmount);
        app.approve(address(referrals), stakeAmount);
        referrals.stakeWithReferral(stakeAmount, stakeAmount, aliceCode, CHARLIE);
        vm.stopPrank();

        // Bob tries to use a different referral code for Charlie again
        vm.startPrank(BOB);
        bytes8 bobCode = bytes8(bytes20(BOB));
        referrals.registerReferralCode(bobCode);

        uint256 anotherStakeAmount = 500e18;
        deal(address(app), BOB, anotherStakeAmount);
        app.approve(address(referrals), anotherStakeAmount);

        // Should not register new referral since Charlie is already tracked
        referrals.stakeWithReferral(anotherStakeAmount, anotherStakeAmount, bobCode, CHARLIE);
        vm.stopPrank();

        // Verify Charlie is still tracked by Alice, not Bob
        address[] memory aliceReferrals = referrals.getReferrals(ALICE);
        address[] memory bobReferrals = referrals.getReferrals(BOB);
        assertEq(aliceReferrals.length, 1);
        assertEq(aliceReferrals[0], CHARLIE);
        assertEq(bobReferrals.length, 0);
        assertEq(referrals.trackedReferrals(CHARLIE), aliceCode);
    }

    function test_ReferralTracking_OriginalReferrerAlwaysAccounted() public {
        // Alice registers a referral code
        vm.startPrank(ALICE);
        bytes8 aliceCode = bytes8(bytes20(ALICE));
        referrals.registerReferralCode(aliceCode);
        vm.stopPrank();

        // Bob registers a referral code
        vm.startPrank(BOB);
        bytes8 bobCode = bytes8(bytes20(BOB));
        referrals.registerReferralCode(bobCode);
        vm.stopPrank();

        // Bob uses Alice's code to refer Charlie
        vm.startPrank(BOB);
        uint256 stakeAmount = 1000e18;
        deal(address(app), BOB, stakeAmount);
        app.approve(address(referrals), stakeAmount);
        vm.expectEmit(true, true, false, true);
        emit ReferralRegistered(CHARLIE, aliceCode);
        vm.expectEmit(true, true, false, true);
        emit ReferralStaked(CHARLIE, stakeAmount, stakeAmount, aliceCode);
        referrals.stakeWithReferral(stakeAmount, stakeAmount, aliceCode, CHARLIE);
        vm.stopPrank();

        // Dave tries to refer Charlie again using Bob's code
        address DAVE = makeAddr("dave");
        vm.startPrank(DAVE);
        uint256 anotherStakeAmount = 500e18;
        deal(address(app), DAVE, anotherStakeAmount);
        app.approve(address(referrals), anotherStakeAmount);
        // Should not register new referral since Charlie is already tracked
        // Only ReferralStaked should be emitted, with Alice's code
        vm.expectEmit(true, true, false, true);
        emit ReferralStaked(CHARLIE, anotherStakeAmount, anotherStakeAmount, aliceCode);
        referrals.stakeWithReferral(anotherStakeAmount, anotherStakeAmount, bobCode, CHARLIE);
        vm.stopPrank();

        // Verify Charlie is still tracked by Alice, not Bob
        address[] memory aliceReferrals = referrals.getReferrals(ALICE);
        address[] memory bobReferrals = referrals.getReferrals(BOB);
        assertEq(aliceReferrals.length, 1);
        assertEq(aliceReferrals[0], CHARLIE);
        assertEq(bobReferrals.length, 0);
        assertEq(referrals.trackedReferrals(CHARLIE), aliceCode);
        // The referral code returned by a second attempt should be Alice's code
        bytes8 returnedCode = referrals.userToReferralCode(ALICE);
        assertEq(returnedCode, aliceCode);
    }

    function test_MerkleRewards() public {
        // Setup: Alice refers Bob and Charlie
        bytes8 aliceCode = bytes8(bytes20(ALICE));
        vm.prank(ALICE);
        referrals.registerReferralCode(aliceCode);

        // Bob and Charlie stake using Alice's code
        uint256 stakeAmount = 1000e18;

        vm.startPrank(BOB);
        deal(address(app), BOB, stakeAmount);
        app.approve(address(referrals), stakeAmount);
        referrals.stakeWithReferral(stakeAmount, stakeAmount, aliceCode, BOB);
        vm.stopPrank();

        vm.startPrank(CHARLIE);
        deal(address(app), CHARLIE, stakeAmount);
        app.approve(address(referrals), stakeAmount);
        referrals.stakeWithReferral(stakeAmount, stakeAmount, aliceCode, CHARLIE);
        vm.stopPrank();

        // Create merkle tree with rewards
        // Alice gets 100 RZR for referring Bob and Charlie
        uint256 aliceReward = 100e18;
        bytes32[] memory aliceProof = new bytes32[](1);
        aliceProof[0] = keccak256(abi.encodePacked("dummy proof")); // In reality, this would be generated off-chain

        bytes32 aliceLeaf = keccak256(abi.encodePacked(ALICE, aliceReward));
        bytes32 merkleRoot = keccak256(abi.encodePacked(aliceLeaf, aliceProof[0]));

        // Merkle server adds rewards
        vm.startPrank(MERKLE_SERVER);
        deal(address(app), address(referrals), aliceReward);
        referrals.setMerkleRoot(merkleRoot);
        vm.stopPrank();

        // Alice claims her rewards
        vm.startPrank(ALICE);
        IAppReferrals.ClaimRewardsInput[] memory inputs = new IAppReferrals.ClaimRewardsInput[](1);
        inputs[0] = IAppReferrals.ClaimRewardsInput({user: ALICE, amount: aliceReward, proofs: aliceProof});

        referrals.claimRewards(inputs);
        vm.stopPrank();

        // Verify rewards were claimed
        assertEq(referrals.claimedRewards(ALICE), aliceReward);
        assertEq(app.balanceOf(ALICE), aliceReward);
    }

    function test_MerkleRewards_InvalidProof() public {
        uint256 aliceReward = 100e18;

        // Create a valid merkle root with a valid proof
        bytes32[] memory validProof = new bytes32[](1);
        validProof[0] = keccak256(abi.encodePacked("valid proof"));
        bytes32 aliceLeaf = keccak256(abi.encodePacked(ALICE, aliceReward));
        bytes32 merkleRoot = keccak256(abi.encodePacked(aliceLeaf, validProof[0]));

        // Merkle server adds rewards
        vm.startPrank(MERKLE_SERVER);
        deal(address(app), address(referrals), aliceReward);
        referrals.setMerkleRoot(merkleRoot);
        vm.stopPrank();

        // Alice tries to claim with invalid proof (different proof for same leaf)
        vm.startPrank(ALICE);
        bytes32[] memory invalidProof = new bytes32[](1);
        invalidProof[0] = keccak256(abi.encodePacked("invalid proof"));

        IAppReferrals.ClaimRewardsInput[] memory inputs = new IAppReferrals.ClaimRewardsInput[](1);
        inputs[0] = IAppReferrals.ClaimRewardsInput({user: ALICE, amount: aliceReward, proofs: invalidProof});

        vm.expectRevert("Invalid proof");
        referrals.claimRewards(inputs);
        vm.stopPrank();
    }

    function test_CannotClaimTwice() public {
        // Setup same as testMerkleRewards
        bytes8 aliceCode = bytes8(bytes20(ALICE));
        vm.prank(ALICE);
        referrals.registerReferralCode(aliceCode);

        uint256 aliceReward = 100e18;
        bytes32[] memory aliceProof = new bytes32[](1);
        aliceProof[0] = keccak256(abi.encodePacked("dummy proof"));

        bytes32 aliceLeaf = keccak256(abi.encodePacked(ALICE, aliceReward));
        bytes32 merkleRoot = keccak256(abi.encodePacked(aliceLeaf, aliceProof[0]));

        vm.startPrank(MERKLE_SERVER);
        deal(address(app), address(referrals), aliceReward);
        referrals.setMerkleRoot(merkleRoot);
        vm.stopPrank();

        // First claim succeeds
        vm.startPrank(ALICE);
        IAppReferrals.ClaimRewardsInput[] memory inputs = new IAppReferrals.ClaimRewardsInput[](1);
        inputs[0] = IAppReferrals.ClaimRewardsInput({user: ALICE, amount: aliceReward, proofs: aliceProof});
        referrals.claimRewards(inputs);

        // Second claim should fail
        vm.expectRevert("No rewards to claim");
        referrals.claimRewards(inputs);
        vm.stopPrank();
    }

    function test_AddMerkleRoot_OnlyMerkleServer() public {
        uint256 totalRewards = 100e18;
        bytes32 merkleRoot = keccak256(abi.encodePacked("test root"));

        // Non-merkle server tries to add root
        vm.startPrank(ALICE);
        vm.expectRevert("Only merkle server can set merkle root");
        referrals.setMerkleRoot(merkleRoot);
        vm.stopPrank();
    }

    function test_BondWithReferral() public {
        // Alice generates a referral code
        vm.startPrank(ALICE);
        bytes8 aliceCode = bytes8(bytes20(ALICE));
        referrals.registerReferralCode(aliceCode);
        vm.stopPrank();

        // Bob uses Alice's referral code to buy bond on behalf of Charlie
        vm.startPrank(BOB);
        uint256 bondAmount = 100e18;
        deal(address(mockQuoteToken), BOB, bondAmount);
        mockQuoteToken.approve(address(referrals), bondAmount);

        vm.expectEmit(true, true, false, true);
        emit ReferralRegistered(CHARLIE, aliceCode);
        vm.expectEmit(true, true, false, true);
        emit ReferralBondBought(CHARLIE, bondAmount, aliceCode);
        referrals.bondWithReferral(bondAmount, aliceCode, CHARLIE);
        vm.stopPrank();

        // Verify referral is tracked for Charlie (the person the bond was bought for)
        address[] memory aliceReferrals = referrals.getReferrals(ALICE);
        assertEq(aliceReferrals.length, 1);
        assertEq(aliceReferrals[0], CHARLIE);
        assertEq(referrals.trackedReferrals(CHARLIE), aliceCode);
    }

    function test_StakeIntoLSTWithReferral() public {
        // Alice generates a referral code
        vm.startPrank(ALICE);
        bytes8 aliceCode = bytes8(bytes20(ALICE));
        referrals.registerReferralCode(aliceCode);
        vm.stopPrank();

        // Bob uses Alice's referral code to stake into LST on behalf of Charlie
        vm.startPrank(BOB);
        uint256 stakeAmount = 1000e18;
        deal(address(app), BOB, stakeAmount);
        app.approve(address(referrals), stakeAmount);

        vm.expectEmit(true, true, false, true);
        emit ReferralRegistered(CHARLIE, aliceCode);
        vm.expectEmit(true, true, false, true);
        emit ReferralStakedIntoLST(CHARLIE, stakeAmount, aliceCode);
        referrals.stakeIntoLSTWithReferral(stakeAmount, aliceCode, CHARLIE);
        vm.stopPrank();

        // Verify referral is tracked for Charlie (the person being staked for)
        address[] memory aliceReferrals = referrals.getReferrals(ALICE);
        assertEq(aliceReferrals.length, 1);
        assertEq(aliceReferrals[0], CHARLIE);
        assertEq(referrals.trackedReferrals(CHARLIE), aliceCode);
    }

    function test_MultipleReferrals() public {
        // Alice generates a referral code
        vm.startPrank(ALICE);
        bytes8 aliceCode = bytes8(bytes20(ALICE));
        referrals.registerReferralCode(aliceCode);
        vm.stopPrank();

        // Multiple people use Alice's referral code
        address[] memory users = new address[](3);
        users[0] = BOB;
        users[1] = CHARLIE;
        users[2] = makeAddr("dave");

        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            uint256 stakeAmount = 1000e18;
            deal(address(app), users[i], stakeAmount);
            app.approve(address(referrals), stakeAmount);
            referrals.stakeWithReferral(stakeAmount, stakeAmount, aliceCode, users[i]);
            vm.stopPrank();
        }

        // Verify all referrals are tracked
        address[] memory aliceReferrals = referrals.getReferrals(ALICE);
        assertEq(aliceReferrals.length, 3);

        for (uint256 i = 0; i < users.length; i++) {
            assertEq(referrals.trackedReferrals(users[i]), aliceCode);
        }
    }
}
