// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "./IApp.sol";
import "./IPermissionedERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

/// @title IAppOptions
/// @notice Interface for the AppOptions contract that manages RZR token option offerings
/// @dev Extends ERC721Enumerable to represent each option position as an NFT
interface IAppOptions is IERC721Enumerable {
    /// @notice Represents an individual option position held by a user
    /// @dev Each position is represented as an ERC721 token
    struct Position {
        /// @notice The ID of the offering this position belongs to
        uint256 offeringId;
        /// @notice Total amount of quote tokens used to fill this position
        uint256 quoteAmountFilled;
        /// @notice Amount of quote tokens that have been redeemed
        uint256 quoteAmountRedeemed;
        /// @notice Amount of quote tokens that have been exercised
        uint256 quoteAmountExercised;
        /// @notice Amount of RZR tokens allocated to this position
        uint256 rzrAmountAllocated;
        /// @notice Amount of RZR tokens that have been redeemed
        uint256 rzrAmountRedeemed;
        /// @notice Amount of RZR tokens that have been exercised
        uint256 rzrAmountExercised;
    }

    /// @notice Represents an option offering campaign
    /// @dev Defines the terms and conditions for an option offering period
    struct Offering {
        /// @notice The ERC20 token accepted as payment for this offering
        IERC20 quoteToken;
        /// @notice Whether this offering is currently active and accepting purchases
        bool enabled;
        /// @notice Timestamp when the offering ends
        uint256 dateEnd;
        /// @notice Timestamp when the offering starts
        uint256 dateStart;
        /// @notice Maximum amount of quote tokens that can be collected in this offering
        uint256 maxQuoteToken;
        /// @notice Current amount of quote tokens that have been filled
        uint256 filled;
        /// @notice Price in quote tokens to redeem the option (without exercising)
        uint256 redemptionPrice;
    }

    /// @notice Emitted when a new option offering is created
    /// @param offeringId The unique identifier for the newly created offering
    /// @param quoteToken The ERC20 token accepted as payment for this offering
    /// @param dateEnd Timestamp when the offering ends
    /// @param dateStart Timestamp when the offering starts
    /// @param maxQuoteToken Maximum amount of quote tokens that can be collected
    /// @param redemptionPrice Price in quote tokens to redeem the option
    event OfferingCreated(
        uint256 indexed offeringId,
        IERC20 quoteToken,
        uint256 dateEnd,
        uint256 dateStart,
        uint256 maxQuoteToken,
        uint256 redemptionPrice
    );

    /// @notice Emitted when a user buys an option position
    /// @param offeringId The ID of the offering being purchased from
    /// @param positionId The unique identifier for the newly created position (ERC721 token ID)
    /// @param receiver The address receiving the option position NFT
    /// @param quoteAmountFilled Amount of quote tokens used to purchase the option
    /// @param rzrAmountAllocated Amount of RZR tokens allocated to this position
    /// @param redemptionPrice The redemption price for this option
    event OptionBought(
        uint256 indexed offeringId,
        uint256 indexed positionId,
        address indexed receiver,
        uint256 quoteAmountFilled,
        uint256 rzrAmountAllocated,
        uint256 redemptionPrice
    );

    /// @notice Emitted when a user redeems their option position
    /// @param positionId The ID of the position being redeemed
    /// @param redeemer The address redeeming the option
    /// @param quoteAmountRedeemed Amount of quote tokens returned to the redeemer
    /// @param rzrAmountRedeemed Amount of RZR tokens returned from the position
    event OptionRedeemed(
        uint256 indexed positionId, address indexed redeemer, uint256 quoteAmountRedeemed, uint256 rzrAmountRedeemed
    );

    /// @notice Emitted when a user exercises their option position
    /// @param positionId The ID of the position being exercised
    /// @param exerciser The address exercising the option
    /// @param quoteAmountExercised Amount of quote tokens used to exercise the option
    /// @param rzrAmountExercised Amount of RZR tokens received from exercising
    event OptionExercised(
        uint256 indexed positionId, address indexed exerciser, uint256 quoteAmountExercised, uint256 rzrAmountExercised
    );

    /// @notice Emitted when an offering is canceled
    /// @param offeringId The ID of the offering being canceled
    event OfferingCanceled(uint256 indexed offeringId);

    /// @notice Returns the RZR token contract
    /// @return The IApp interface for the RZR token
    function rzr() external view returns (IApp);

    /// @notice Returns the RZR tracking token contract used for option accounting
    /// @return The IPermissionedERC20 interface for the tracking token
    function rzrTrackingToken() external view returns (IPermissionedERC20);

    /// @notice Returns the ID of the last created position
    /// @return The most recent position ID
    function lastPositionId() external view returns (uint256);

    /// @notice Returns the ID of the last created offering
    /// @return The most recent offering ID
    function lastOfferingId() external view returns (uint256);

    /// @notice Creates a new option offering
    /// @param quoteToken The ERC20 token to accept as payment
    /// @param dateEnd Timestamp when the offering ends
    /// @param dateStart Timestamp when the offering starts
    /// @param maxQuoteToken Maximum amount of quote tokens that can be collected
    /// @param redemptionPrice Price in quote tokens to redeem the option
    /// @return offeringId The unique identifier for the newly created offering
    function createOffering(
        IERC20 quoteToken,
        uint256 dateEnd,
        uint256 dateStart,
        uint256 maxQuoteToken,
        uint256 redemptionPrice
    ) external returns (uint256 offeringId);

    /// @notice Cancels an existing offering
    /// @param offeringId The ID of the offering to cancel
    function cancelOffering(uint256 offeringId) external;

    /// @notice Purchases an option position from an active offering
    /// @param offeringId The ID of the offering to purchase from
    /// @param quoteAmount Amount of quote tokens to spend on the option
    /// @param receiver Address that will receive the option position NFT
    function buy(uint256 offeringId, uint256 quoteAmount, address receiver) external;

    /// @notice Redeems an option position to recover quote tokens without exercising
    /// @param positionId The ID of the position to redeem
    /// @param percentageE18 Percentage of the position to redeem (in 18 decimal fixed point, where 1e18 = 100%)
    function redeem(uint256 positionId, uint256 percentageE18) external;

    /// @notice Exercises an option position to receive RZR tokens
    /// @param positionId The ID of the position to exercise
    /// @param percentageE18 Percentage of the position to exercise (in 18 decimal fixed point, where 1e18 = 100%)
    function excercise(uint256 positionId, uint256 percentageE18) external;

    /// @notice Retrieves the details of a specific position
    /// @param positionId The ID of the position to query
    /// @return The Position struct containing all position details
    function getPosition(uint256 positionId) external view returns (Position memory);

    /// @notice Retrieves the details of a specific offering
    /// @param offeringId The ID of the offering to query
    /// @return The Offering struct containing all offering details
    function getOffering(uint256 offeringId) external view returns (Offering memory);
}
