// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./BaseTest.sol";
import "../../contracts/core/AppOptions.sol";
import "../../contracts/libraries/PermissionedERC20Factory.sol";
import "../../contracts/mocks/MockERC20.sol";

contract AppOptionsTest is BaseTest {
    AppOptions public options;
    PermissionedERC20Factory public factory;

    uint256 public constant OFFERING_DURATION = 30 days;
    uint256 public constant REDEMPTION_PRICE = 2e18; // 2:1 ratio (2 RZR per 1 quote token)
    uint256 public constant MAX_QUOTE_AMOUNT = 1000e18;
    uint256 public constant WITHDRAWAL_DELAY = 7 days;

    event OfferingCreated(
        uint256 indexed offeringId,
        IERC20 quoteToken,
        uint256 dateEnd,
        uint256 dateStart,
        uint256 maxQuoteToken,
        uint256 redemptionPrice
    );

    event OptionBought(
        uint256 indexed offeringId,
        uint256 indexed positionId,
        address indexed receiver,
        uint256 quoteAmountFilled,
        uint256 rzrAmountAllocated,
        uint256 redemptionPrice
    );

    event OptionRedeemed(
        uint256 indexed positionId, address indexed redeemer, uint256 quoteAmountRedeemed, uint256 rzrAmountRedeemed
    );

    event OptionExercised(
        uint256 indexed positionId, address indexed exerciser, uint256 quoteAmountExercised, uint256 rzrAmountExercised
    );

    event OfferingCanceled(uint256 indexed offeringId);

    function setUp() public {
        setUpBaseTest();

        vm.startPrank(owner);

        // Deploy factory
        factory = new PermissionedERC20Factory();

        // Deploy options contract
        options = new AppOptions(address(authority), address(app), address(factory));

        // Mint RZR tokens to owner for creating offerings
        // Each offering with MAX_QUOTE_AMOUNT and REDEMPTION_PRICE needs 2000e18 RZR
        app.mint(owner, 100000e18);

        // Approve options contract to spend owner's RZR for creating offerings
        app.approve(address(options), type(uint256).max);

        // Mint quote tokens to users
        mockQuoteToken.mint(user1, 10000e18);
        mockQuoteToken.mint(user2, 10000e18);
        mockQuoteToken.mint(user3, 10000e18);

        mockQuoteToken2.mint(user1, 10000e18);
        mockQuoteToken2.mint(user2, 10000e18);
        mockQuoteToken2.mint(user3, 10000e18);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Initialize() public view {
        assertEq(address(options.rzr()), address(app));
        assertEq(address(options.authority()), address(authority));
        assertEq(options.lastPositionId(), 0);
        assertEq(options.lastOfferingId(), 0);
        assertEq(options.name(), "RZR Options");
        assertEq(options.symbol(), "oRZR");
    }

    function test_TrackingTokenInitialized() public view {
        assertNotEq(address(options.rzrTrackingToken()), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                        CREATE OFFERING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CreateOffering() public {
        vm.startPrank(owner);

        uint256 dateStart = block.timestamp;
        uint256 dateEnd = block.timestamp + OFFERING_DURATION;

        vm.expectEmit(true, false, false, true);
        emit OfferingCreated(1, mockQuoteToken, dateEnd, dateStart, MAX_QUOTE_AMOUNT, REDEMPTION_PRICE);

        uint256 offeringId = options.createOffering(
            mockQuoteToken, dateEnd, dateStart, MAX_QUOTE_AMOUNT, REDEMPTION_PRICE, WITHDRAWAL_DELAY
        );

        assertEq(offeringId, 1);
        assertEq(options.lastOfferingId(), 1);

        IAppOptions.Offering memory offering = options.getOffering(offeringId);
        assertEq(address(offering.quoteToken), address(mockQuoteToken));
        assertTrue(offering.enabled);
        assertEq(offering.dateEnd, dateEnd);
        assertEq(offering.dateStart, dateStart);
        assertEq(offering.maxQuoteToken, MAX_QUOTE_AMOUNT);
        assertEq(offering.filled, 0);
        assertEq(offering.redemptionPrice, REDEMPTION_PRICE);

        vm.stopPrank();
    }

    function test_CreateMultipleOfferings() public {
        vm.startPrank(owner);

        uint256 dateStart = block.timestamp;
        uint256 dateEnd = block.timestamp + OFFERING_DURATION;

        uint256 offering1 = options.createOffering(
            mockQuoteToken, dateEnd, dateStart, MAX_QUOTE_AMOUNT, REDEMPTION_PRICE, WITHDRAWAL_DELAY
        );

        uint256 offering2 = options.createOffering(
            mockQuoteToken2,
            dateEnd + 1 days,
            dateStart + 1 days,
            MAX_QUOTE_AMOUNT * 2,
            REDEMPTION_PRICE * 2,
            WITHDRAWAL_DELAY
        );

        assertEq(offering1, 1);
        assertEq(offering2, 2);
        assertEq(options.lastOfferingId(), 2);

        vm.stopPrank();
    }

    function test_RevertWhen_CreateOfferingNotGovernor() public {
        vm.startPrank(user1);

        vm.expectRevert();
        options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        CANCEL OFFERING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CancelOffering() public {
        vm.startPrank(owner);

        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        vm.expectEmit(true, false, false, false);
        emit OfferingCanceled(offeringId);

        options.cancelOffering(offeringId);

        IAppOptions.Offering memory offering = options.getOffering(offeringId);
        assertFalse(offering.enabled);

        vm.stopPrank();
    }

    function test_RevertWhen_CancelOfferingNotAuthorized() public {
        vm.startPrank(owner);

        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        vm.stopPrank();

        vm.startPrank(user1);

        vm.expectRevert();
        options.cancelOffering(offeringId);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            BUY OPTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_BuyOption() public {
        // Create offering
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        // User1 buys option
        uint256 quoteAmount = 100e18;
        uint256 expectedRzrAmount = quoteAmount * REDEMPTION_PRICE / 1e18;

        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);

        vm.expectEmit(true, true, true, true);
        emit OptionBought(offeringId, 1, user1, quoteAmount, expectedRzrAmount, REDEMPTION_PRICE);

        options.buy(offeringId, quoteAmount, user1);

        vm.stopPrank();

        // Verify position
        assertEq(options.lastPositionId(), 1);
        assertEq(options.ownerOf(1), user1);
        assertEq(options.balanceOf(user1), 1);

        IAppOptions.Position memory position = options.getPosition(1);
        assertEq(position.offeringId, offeringId);
        assertEq(position.quoteAmountFilled, quoteAmount);
        assertEq(position.quoteAmountRedeemed, 0);
        assertEq(position.quoteAmountExercised, 0);
        assertEq(position.rzrAmountAllocated, expectedRzrAmount);
        assertEq(position.rzrAmountRedeemed, 0);
        assertEq(position.rzrAmountExercised, 0);

        // Verify offering.filled is correctly updated
        IAppOptions.Offering memory offering = options.getOffering(offeringId);
        assertEq(offering.filled, quoteAmount);
    }

    function test_BuyOption_DifferentReceiver() public {
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        uint256 quoteAmount = 100e18;

        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);
        options.buy(offeringId, quoteAmount, user2);
        vm.stopPrank();

        // user2 should own the position
        assertEq(options.ownerOf(1), user2);
        assertEq(options.balanceOf(user2), 1);
    }

    function test_BuyOption_MultiplePurchases() public {
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        uint256 quoteAmount = 100e18;

        // User1 buys
        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);
        options.buy(offeringId, quoteAmount, user1);
        vm.stopPrank();

        // User2 buys
        vm.startPrank(user2);
        mockQuoteToken.approve(address(options), quoteAmount);
        options.buy(offeringId, quoteAmount, user2);
        vm.stopPrank();

        assertEq(options.lastPositionId(), 2);
        assertEq(options.balanceOf(user1), 1);
        assertEq(options.balanceOf(user2), 1);
    }

    function test_RevertWhen_BuyDisabledOffering() public {
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        vm.prank(owner);
        options.cancelOffering(offeringId);

        uint256 quoteAmount = 100e18;

        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);

        vm.expectRevert("Offering not enabled");
        options.buy(offeringId, quoteAmount, user1);

        vm.stopPrank();
    }

    function test_RevertWhen_BuyBeforeStart() public {
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION + 1 days,
            block.timestamp + 1 days, // starts tomorrow
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        uint256 quoteAmount = 100e18;

        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);

        vm.expectRevert("Offering not started");
        options.buy(offeringId, quoteAmount, user1);

        vm.stopPrank();
    }

    function test_RevertWhen_BuyAfterEnd() public {
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + 1 days,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        // Warp past end date
        vm.warp(block.timestamp + 2 days);

        uint256 quoteAmount = 100e18;

        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);

        vm.expectRevert("Offering ended");
        options.buy(offeringId, quoteAmount, user1);

        vm.stopPrank();
    }

    function test_RevertWhen_BuyExceedsMax() public {
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        uint256 quoteAmount = MAX_QUOTE_AMOUNT + 1;

        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);

        vm.expectRevert("Offering sold out");
        options.buy(offeringId, quoteAmount, user1);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        REDEEM OPTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RedeemOption_FullPosition() public {
        // Setup: Create offering and buy option
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        uint256 quoteAmount = 100e18;
        uint256 expectedRzrAmount = quoteAmount * REDEMPTION_PRICE / 1e18;

        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);
        options.buy(offeringId, quoteAmount, user1);

        uint256 positionId = options.lastPositionId();

        // Mint RZR to options contract so it can burn
        vm.stopPrank();
        vm.prank(owner);
        app.mint(address(options), expectedRzrAmount);

        // Request redemption of full position (100%)
        vm.startPrank(user1);
        options.requestRedemption(positionId, 1e18); // 100%

        // Warp past withdrawal delay
        vm.warp(block.timestamp + WITHDRAWAL_DELAY + 1);

        // Execute redemption
        uint256 balanceBefore = mockQuoteToken.balanceOf(user1);

        vm.expectEmit(true, true, false, true);
        emit OptionRedeemed(positionId, user1, quoteAmount, expectedRzrAmount);

        options.redeem(positionId);

        uint256 balanceAfter = mockQuoteToken.balanceOf(user1);

        vm.stopPrank();

        // Verify user got quote tokens back
        assertEq(balanceAfter - balanceBefore, quoteAmount);

        // Verify position updated
        IAppOptions.Position memory position = options.getPosition(positionId);
        assertEq(position.quoteAmountRedeemed, quoteAmount);
        assertEq(position.rzrAmountRedeemed, expectedRzrAmount);
    }

    function test_RedeemOption_PartialPosition() public {
        // Setup: Create offering and buy option
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        uint256 quoteAmount = 100e18;
        uint256 expectedRzrAmount = quoteAmount * REDEMPTION_PRICE / 1e18;

        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);
        options.buy(offeringId, quoteAmount, user1);

        uint256 positionId = options.lastPositionId();

        vm.stopPrank();
        vm.prank(owner);
        app.mint(address(options), expectedRzrAmount);

        // Request redemption of 50% of position
        vm.startPrank(user1);
        options.requestRedemption(positionId, 0.5e18); // 50%

        // Warp past withdrawal delay
        vm.warp(block.timestamp + WITHDRAWAL_DELAY + 1);

        // Execute redemption
        uint256 balanceBefore = mockQuoteToken.balanceOf(user1);

        options.redeem(positionId);

        uint256 balanceAfter = mockQuoteToken.balanceOf(user1);

        vm.stopPrank();

        // Verify user got 50% of quote tokens back
        assertEq(balanceAfter - balanceBefore, quoteAmount / 2);

        // Verify position updated
        IAppOptions.Position memory position = options.getPosition(positionId);
        assertEq(position.quoteAmountRedeemed, quoteAmount / 2);
        assertEq(position.rzrAmountRedeemed, expectedRzrAmount / 2);
    }

    function test_RedeemOption_MultiplePartialRedemptions() public {
        // Setup: Create offering and buy option
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        uint256 quoteAmount = 100e18;
        uint256 expectedRzrAmount = quoteAmount * REDEMPTION_PRICE / 1e18;

        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);
        options.buy(offeringId, quoteAmount, user1);

        uint256 positionId = options.lastPositionId();

        vm.stopPrank();
        vm.prank(owner);
        app.mint(address(options), expectedRzrAmount);

        // First redemption: 30%
        vm.prank(user1);
        options.requestRedemption(positionId, 0.3e18);
        vm.warp(block.timestamp + WITHDRAWAL_DELAY + 1);
        vm.prank(user1);
        options.redeem(positionId);

        IAppOptions.Position memory position1 = options.getPosition(positionId);
        assertEq(position1.quoteAmountRedeemed, quoteAmount * 30 / 100);

        // Second redemption: 20%
        vm.prank(user1);
        options.requestRedemption(positionId, 0.2e18);
        vm.warp(block.timestamp + WITHDRAWAL_DELAY + 1);
        vm.prank(user1);
        options.redeem(positionId);

        IAppOptions.Position memory position2 = options.getPosition(positionId);
        assertEq(position2.quoteAmountRedeemed, quoteAmount * 50 / 100);
    }

    function test_RevertWhen_RedeemNotOwner() public {
        // Setup: Create offering and buy option
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        uint256 quoteAmount = 100e18;

        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);
        options.buy(offeringId, quoteAmount, user1);

        uint256 positionId = options.lastPositionId();
        vm.stopPrank();

        // User2 tries to redeem user1's position
        vm.startPrank(user2);

        vm.expectRevert("Not owner or approved");
        options.requestRedemption(positionId, 1e18);

        vm.stopPrank();
    }

    function test_RevertWhen_RedeemExceedsPosition() public {
        // Setup: Create offering and buy option
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        uint256 quoteAmount = 100e18;
        uint256 expectedRzrAmount = quoteAmount * REDEMPTION_PRICE / 1e18;

        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);
        options.buy(offeringId, quoteAmount, user1);

        uint256 positionId = options.lastPositionId();

        vm.stopPrank();
        vm.prank(owner);
        app.mint(address(options), expectedRzrAmount);

        // Try to redeem 101%
        vm.startPrank(user1);

        vm.expectRevert("invariant violated: I4");
        options.requestRedemption(positionId, 1.01e18);

        vm.stopPrank();
    }

    function test_RevertWhen_Redeem75PercentTwice() public {
        // Setup: Create offering and buy option
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        uint256 quoteAmount = 100e18;
        uint256 expectedRzrAmount = quoteAmount * REDEMPTION_PRICE / 1e18;

        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);
        options.buy(offeringId, quoteAmount, user1);

        uint256 positionId = options.lastPositionId();

        vm.stopPrank();
        vm.prank(owner);
        app.mint(address(options), expectedRzrAmount);

        // First redemption: 75%
        vm.prank(user1);
        options.requestRedemption(positionId, 0.75e18);
        vm.warp(block.timestamp + WITHDRAWAL_DELAY + 1);
        vm.prank(user1);
        options.redeem(positionId);

        // Verify first redemption succeeded
        IAppOptions.Position memory position1 = options.getPosition(positionId);
        assertEq(position1.quoteAmountRedeemed, quoteAmount * 75 / 100);
        assertEq(position1.rzrAmountRedeemed, expectedRzrAmount * 75 / 100);

        // Try to redeem another 75% (total would be 150%)
        vm.prank(user1);
        options.requestRedemption(positionId, 0.75e18);
        vm.warp(block.timestamp + WITHDRAWAL_DELAY + 1);

        vm.prank(user1);
        vm.expectRevert("invariant violated: I1");
        options.redeem(positionId);
    }

    /*//////////////////////////////////////////////////////////////
                        EXERCISE OPTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ExerciseOption_FullPosition() public {
        // Setup: Create offering and buy option
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        uint256 quoteAmount = 100e18;
        uint256 expectedRzrAmount = quoteAmount * REDEMPTION_PRICE / 1e18;

        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);
        options.buy(offeringId, quoteAmount, user1);

        uint256 positionId = options.lastPositionId();

        // Exercise full position (100%)
        uint256 rzrBalanceBefore = app.balanceOf(user1);

        vm.expectEmit(true, true, false, true);
        emit OptionExercised(positionId, user1, quoteAmount, expectedRzrAmount);

        options.excercise(positionId, 1e18); // 100%

        uint256 rzrBalanceAfter = app.balanceOf(user1);

        vm.stopPrank();

        // Verify user got RZR tokens
        assertEq(rzrBalanceAfter - rzrBalanceBefore, expectedRzrAmount);

        // Verify position updated
        IAppOptions.Position memory position = options.getPosition(positionId);
        assertEq(position.quoteAmountExercised, quoteAmount);
        assertEq(position.rzrAmountExercised, expectedRzrAmount);

        // Verify quote tokens went to treasury
        assertEq(mockQuoteToken.balanceOf(address(treasury)), quoteAmount);
    }

    function test_ExerciseOption_PartialPosition() public {
        // Setup: Create offering and buy option
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        uint256 quoteAmount = 100e18;
        uint256 expectedRzrAmount = quoteAmount * REDEMPTION_PRICE / 1e18;

        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);
        options.buy(offeringId, quoteAmount, user1);

        uint256 positionId = options.lastPositionId();

        // Exercise 25% of position
        uint256 rzrBalanceBefore = app.balanceOf(user1);

        options.excercise(positionId, 0.25e18); // 25%

        uint256 rzrBalanceAfter = app.balanceOf(user1);

        vm.stopPrank();

        // Verify user got 25% of RZR tokens
        assertEq(rzrBalanceAfter - rzrBalanceBefore, expectedRzrAmount / 4);

        // Verify position updated
        IAppOptions.Position memory position = options.getPosition(positionId);
        assertEq(position.quoteAmountExercised, quoteAmount / 4);
        assertEq(position.rzrAmountExercised, expectedRzrAmount / 4);
    }

    function test_ExerciseOption_MultiplePartialExercises() public {
        // Setup: Create offering and buy option
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        uint256 quoteAmount = 100e18;

        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);
        options.buy(offeringId, quoteAmount, user1);

        uint256 positionId = options.lastPositionId();

        // First exercise: 40%
        options.excercise(positionId, 0.4e18);

        IAppOptions.Position memory position1 = options.getPosition(positionId);
        assertEq(position1.quoteAmountExercised, quoteAmount * 40 / 100);

        // Second exercise: 30%
        options.excercise(positionId, 0.3e18);

        IAppOptions.Position memory position2 = options.getPosition(positionId);
        assertEq(position2.quoteAmountExercised, quoteAmount * 70 / 100);

        vm.stopPrank();
    }

    function test_RevertWhen_ExerciseNotOwner() public {
        // Setup: Create offering and buy option
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        uint256 quoteAmount = 100e18;

        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);
        options.buy(offeringId, quoteAmount, user1);

        uint256 positionId = options.lastPositionId();
        vm.stopPrank();

        // User2 tries to exercise user1's position
        vm.startPrank(user2);

        vm.expectRevert("Not owner or approved");
        options.excercise(positionId, 1e18);

        vm.stopPrank();
    }

    function test_RevertWhen_ExerciseExceedsPosition() public {
        // Setup: Create offering and buy option
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        uint256 quoteAmount = 100e18;

        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);
        options.buy(offeringId, quoteAmount, user1);

        uint256 positionId = options.lastPositionId();

        // Try to exercise 150%
        vm.expectRevert("invariant violated: I4");
        options.excercise(positionId, 1.5e18);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    COMBINED REDEEM/EXERCISE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RedeemAndExercise_Combined() public {
        // Setup: Create offering and buy option
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        uint256 quoteAmount = 100e18;
        uint256 expectedRzrAmount = quoteAmount * REDEMPTION_PRICE / 1e18;

        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);
        options.buy(offeringId, quoteAmount, user1);

        uint256 positionId = options.lastPositionId();

        vm.stopPrank();
        vm.prank(owner);
        app.mint(address(options), expectedRzrAmount);

        // Request and execute redemption of 30%
        vm.prank(user1);
        options.requestRedemption(positionId, 0.3e18);
        vm.warp(block.timestamp + WITHDRAWAL_DELAY + 1);
        vm.prank(user1);
        options.redeem(positionId);

        // Exercise 50%
        vm.prank(user1);
        options.excercise(positionId, 0.5e18);

        // Verify position
        IAppOptions.Position memory position = options.getPosition(positionId);
        assertEq(position.quoteAmountRedeemed, quoteAmount * 30 / 100);
        assertEq(position.quoteAmountExercised, quoteAmount * 50 / 100);
        assertEq(position.rzrAmountRedeemed, expectedRzrAmount * 30 / 100);
        assertEq(position.rzrAmountExercised, expectedRzrAmount * 50 / 100);
    }

    function test_RevertWhen_RedeemAndExerciseExceed100Percent() public {
        // Setup: Create offering and buy option
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        uint256 quoteAmount = 100e18;
        uint256 expectedRzrAmount = quoteAmount * REDEMPTION_PRICE / 1e18;

        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);
        options.buy(offeringId, quoteAmount, user1);

        uint256 positionId = options.lastPositionId();

        vm.stopPrank();
        vm.prank(owner);
        app.mint(address(options), expectedRzrAmount);

        // Request and execute redemption of 60%
        vm.prank(user1);
        options.requestRedemption(positionId, 0.6e18);
        vm.warp(block.timestamp + WITHDRAWAL_DELAY + 1);
        vm.prank(user1);
        options.redeem(positionId);

        // Try to exercise 50% (total would be 110%)
        vm.prank(user1);
        vm.expectRevert("invariant violated: I1");
        options.excercise(positionId, 0.5e18);
    }

    /*//////////////////////////////////////////////////////////////
                        NFT FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_NFTOwnership() public {
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        uint256 quoteAmount = 100e18;

        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);
        options.buy(offeringId, quoteAmount, user1);

        uint256 positionId = options.lastPositionId();

        assertEq(options.ownerOf(positionId), user1);
        assertEq(options.balanceOf(user1), 1);

        vm.stopPrank();
    }

    function test_NFTTransfer() public {
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        uint256 quoteAmount = 100e18;

        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);
        options.buy(offeringId, quoteAmount, user1);

        uint256 positionId = options.lastPositionId();

        // Transfer to user2
        options.transferFrom(user1, user2, positionId);

        assertEq(options.ownerOf(positionId), user2);
        assertEq(options.balanceOf(user1), 0);
        assertEq(options.balanceOf(user2), 1);

        vm.stopPrank();
    }

    function test_ApprovedCanRedeem() public {
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        uint256 quoteAmount = 100e18;
        uint256 expectedRzrAmount = quoteAmount * REDEMPTION_PRICE / 1e18;

        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);
        options.buy(offeringId, quoteAmount, user1);

        uint256 positionId = options.lastPositionId();

        // Approve user2
        options.setApprovalForAll(user2, true);

        vm.stopPrank();

        vm.prank(owner);
        app.mint(address(options), expectedRzrAmount);

        // User2 can request and execute redemption
        vm.prank(user2);
        options.requestRedemption(positionId, 0.5e18);
        vm.warp(block.timestamp + WITHDRAWAL_DELAY + 1);
        vm.prank(user2);
        options.redeem(positionId);
    }

    function test_ApprovedCanExercise() public {
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        uint256 quoteAmount = 100e18;

        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);
        options.buy(offeringId, quoteAmount, user1);

        uint256 positionId = options.lastPositionId();

        // Approve user2
        options.setApprovalForAll(user2, true);

        vm.stopPrank();

        // User2 can exercise (but RZR goes to user2, not user1)
        vm.prank(user2);
        options.excercise(positionId, 0.5e18);
    }

    /*//////////////////////////////////////////////////////////////
                        ENUMERABLE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_TokenEnumeration() public {
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        uint256 quoteAmount = 50e18;

        // User1 buys 3 positions
        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount * 3);
        options.buy(offeringId, quoteAmount, user1);
        options.buy(offeringId, quoteAmount, user1);
        options.buy(offeringId, quoteAmount, user1);
        vm.stopPrank();

        assertEq(options.balanceOf(user1), 3);
        assertEq(options.tokenOfOwnerByIndex(user1, 0), 1);
        assertEq(options.tokenOfOwnerByIndex(user1, 1), 2);
        assertEq(options.tokenOfOwnerByIndex(user1, 2), 3);
        assertEq(options.totalSupply(), 3);
    }

    /*//////////////////////////////////////////////////////////////
                        INVARIANT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_InvariantI1_QuoteActionedLessThanFilled() public {
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        uint256 quoteAmount = 100e18;

        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);
        options.buy(offeringId, quoteAmount, user1);

        uint256 positionId = options.lastPositionId();

        // This should violate percentage check
        vm.expectRevert("invariant violated: I4");
        options.requestRedemption(positionId, 1.1e18);

        vm.stopPrank();
    }

    function test_InvariantI2_RzrActionedLessThanAllocated() public {
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        uint256 quoteAmount = 100e18;

        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);
        options.buy(offeringId, quoteAmount, user1);

        uint256 positionId = options.lastPositionId();

        // This should violate I2 if it doesn't revert
        vm.expectRevert("invariant violated: I4");
        options.excercise(positionId, 1.1e18);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        OFFERING FILLED TRACKING TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verifies that offering.filled is correctly persisted to storage
    /// @dev Tests that multiple purchases correctly track the filled amount
    function test_OfferingFilledTracking() public {
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        uint256 quoteAmount = 100e18;

        // User1 buys option
        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);
        options.buy(offeringId, quoteAmount, user1);
        vm.stopPrank();

        // Verify filled is correctly updated
        IAppOptions.Offering memory offering = options.getOffering(offeringId);
        assertEq(offering.filled, quoteAmount);

        // User2 buys more
        uint256 quoteAmount2 = 200e18;
        vm.startPrank(user2);
        mockQuoteToken.approve(address(options), quoteAmount2);
        options.buy(offeringId, quoteAmount2, user2);
        vm.stopPrank();

        // Verify filled is cumulative
        offering = options.getOffering(offeringId);
        assertEq(offering.filled, quoteAmount + quoteAmount2);

        // Verify we can't exceed maxQuoteToken
        uint256 remaining = MAX_QUOTE_AMOUNT - (quoteAmount + quoteAmount2);
        vm.startPrank(user3);
        mockQuoteToken.approve(address(options), remaining + 1);
        vm.expectRevert("Offering sold out");
        options.buy(offeringId, remaining + 1, user3);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ZeroAmountBuy() public {
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), 0);
        options.buy(offeringId, 0, user1);

        IAppOptions.Position memory position = options.getPosition(1);
        assertEq(position.quoteAmountFilled, 0);
        assertEq(position.rzrAmountAllocated, 0);

        vm.stopPrank();
    }

    function test_MultipleOfferingsWithDifferentTokens() public {
        vm.startPrank(owner);

        uint256 offering1 = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        uint256 offering2 = options.createOffering(
            mockQuoteToken2,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE * 2,
            WITHDRAWAL_DELAY
        );

        vm.stopPrank();

        // Buy from offering1
        uint256 quoteAmount = 100e18;
        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);
        options.buy(offering1, quoteAmount, user1);
        vm.stopPrank();

        // Buy from offering2
        vm.startPrank(user2);
        mockQuoteToken2.approve(address(options), quoteAmount);
        options.buy(offering2, quoteAmount, user2);
        vm.stopPrank();

        IAppOptions.Position memory pos1 = options.getPosition(1);
        IAppOptions.Position memory pos2 = options.getPosition(2);

        assertEq(pos1.offeringId, offering1);
        assertEq(pos2.offeringId, offering2);
        assertEq(pos2.rzrAmountAllocated, pos1.rzrAmountAllocated * 2);
    }

    function test_OfferingAtEdgeOfTime() public {
        uint256 exactTime = block.timestamp;

        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken, exactTime + 1, exactTime, MAX_QUOTE_AMOUNT, REDEMPTION_PRICE, WITHDRAWAL_DELAY
        );

        uint256 quoteAmount = 100e18;

        // Should work at exact start time
        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), quoteAmount);
        options.buy(offeringId, quoteAmount, user1);
        vm.stopPrank();

        // Should work at exact end time
        vm.warp(exactTime + 1);

        vm.startPrank(user2);
        mockQuoteToken.approve(address(options), quoteAmount);
        options.buy(offeringId, quoteAmount, user2);
        vm.stopPrank();

        // Should fail after end time
        vm.warp(exactTime + 2);

        vm.startPrank(user3);
        mockQuoteToken.approve(address(options), quoteAmount);
        vm.expectRevert("Offering ended");
        options.buy(offeringId, quoteAmount, user3);
        vm.stopPrank();
    }

    function test_ExactMaxQuoteAmountFill() public {
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        // Fill exactly to the max
        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), MAX_QUOTE_AMOUNT);
        options.buy(offeringId, MAX_QUOTE_AMOUNT, user1);
        vm.stopPrank();

        // Verify the position was created and offering is filled
        assertEq(options.lastPositionId(), 1);
        IAppOptions.Position memory pos = options.getPosition(1);
        assertEq(pos.quoteAmountFilled, MAX_QUOTE_AMOUNT);

        IAppOptions.Offering memory offering = options.getOffering(offeringId);
        assertEq(offering.filled, MAX_QUOTE_AMOUNT);

        // Verify that any additional purchase reverts
        vm.startPrank(user2);
        mockQuoteToken.approve(address(options), 1);
        vm.expectRevert("Offering sold out");
        options.buy(offeringId, 1, user2);
        vm.stopPrank();
    }

    function test_MultiplePurchasesFillToMax() public {
        vm.prank(owner);
        uint256 offeringId = options.createOffering(
            mockQuoteToken,
            block.timestamp + OFFERING_DURATION,
            block.timestamp,
            MAX_QUOTE_AMOUNT,
            REDEMPTION_PRICE,
            WITHDRAWAL_DELAY
        );

        // User1 buys 400e18
        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), 400e18);
        options.buy(offeringId, 400e18, user1);
        vm.stopPrank();

        // User2 buys 300e18
        vm.startPrank(user2);
        mockQuoteToken.approve(address(options), 300e18);
        options.buy(offeringId, 300e18, user2);
        vm.stopPrank();

        // User3 buys exactly remaining 300e18 (total = 1000e18)
        vm.startPrank(user3);
        mockQuoteToken.approve(address(options), 300e18);
        options.buy(offeringId, 300e18, user3);
        vm.stopPrank();

        // Verify offering is exactly filled
        IAppOptions.Offering memory offering = options.getOffering(offeringId);
        assertEq(offering.filled, MAX_QUOTE_AMOUNT);

        // Verify any additional purchase fails
        vm.startPrank(user1);
        mockQuoteToken.approve(address(options), 1);
        vm.expectRevert("Offering sold out");
        options.buy(offeringId, 1, user1);
        vm.stopPrank();
    }
}
