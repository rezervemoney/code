// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title IAppStaking
/// @notice Interface for the staking system that allows users to stake RZR tokens and earn rewards
/// @dev This interface extends IERC721Enumerable to provide NFT functionality for staking positions
interface IAppStaking is IERC721Enumerable {
    // Structs
    /// @notice Represents a staking position
    /// @param amount Amount of RZR tokens staked in the position
    /// @param declaredValue Self-declared value in RZR for harberger tax
    /// @param rewardPerTokenPaid Last reward per token paid to this position
    /// @param rewards Accumulated rewards for this position
    /// @param withdrawCooldownEnd Timestamp when withdraw cooldown period ends; if 0, position is not in withdraw cooldown
    /// @param withdrawCooldownStart Timestamp when withdraw cooldown period starts; if 0, position is not in withdraw cooldown
    /// @param buyCooldownEnd Timestamp when buy cooldown period ends; if 0, position is not in buy cooldown
    /// @param taxPerSecond Tax rate for this position
    /// @param taxCredit Tax credit for this position
    /// @param lastTaxCollectionTime Timestamp of last tax collection for this position
    struct Position {
        uint256 amount;
        uint256 declaredValue;
        uint256 rewardPerTokenPaid;
        uint256 rewards;
        uint256 withdrawCooldownEnd;
        uint256 withdrawCooldownStart;
        uint256 buyCooldownEnd;
        uint256 taxPerSecond;
        uint256 taxCredit;
        uint256 lastTaxCollectionTime;
    }

    struct Variables {
        uint256 harbergerTaxRate;
        uint256 resellFeeRate;
        uint256 withdrawCooldownPeriod;
        uint256 buyCooldownPeriod;
        uint256 lowDemandThreshold;
        uint256 highDemandThreshold;
        uint256 maxDepositFee;
    }

    /// @notice Emitted when variables are updated
    /// @param variables The new variables
    event VariablesUpdated(Variables variables);

    // Events
    /// @notice Emitted when a new staking position is created
    /// @param tokenId The ID of the created position NFT
    /// @param owner The address of the position owner
    /// @param amount The amount of RZR tokens staked
    /// @param declaredValue The self-declared value for harberger tax
    event PositionCreated(uint256 indexed tokenId, address indexed owner, uint256 amount, uint256 declaredValue);

    /// @notice Emitted when a staking position is sold
    /// @param tokenId The ID of the position NFT
    /// @param seller The address of the seller
    /// @param buyer The address of the buyer
    /// @param price The price paid for the position
    event PositionSold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);

    /// @notice Emitted when rewards are claimed from a position
    /// @param tokenId The ID of the position NFT
    /// @param owner The address of the position owner
    /// @param amount The amount of rewards claimed
    event RewardsClaimed(uint256 indexed tokenId, address indexed owner, uint256 amount);

    /// @notice Emitted when tokens are unstaked from a position
    /// @param tokenId The ID of the position NFT
    /// @param owner The address of the position owner
    /// @param amount The amount of tokens unstaked
    event PositionUnstaked(uint256 indexed tokenId, address indexed owner, uint256 amount);

    /// @notice Emitted when a position enters cooldown period
    /// @param tokenId The ID of the position NFT
    /// @param owner The address of the position owner
    event CooldownStarted(uint256 indexed tokenId, address indexed owner);

    /// @notice Emitted when a position's cooldown period ends
    /// @param tokenId The ID of the position NFT
    /// @param owner The address of the position owner
    event CooldownEnded(uint256 indexed tokenId, address indexed owner);

    /// @notice Emitted when a position is updated
    /// @param tokenId The ID of the position NFT
    /// @param owner The address of the position owner
    /// @param newAmount The new amount of tokens staked
    /// @param newDeclaredValue The new declared value
    event PositionUpdated(uint256 indexed tokenId, address indexed owner, uint256 newAmount, uint256 newDeclaredValue);

    /// @notice Emitted when unstaking is cancelled
    /// @param tokenId The ID of the position NFT
    /// @param owner The address of the position owner
    event UnstakingCancelled(uint256 indexed tokenId, address indexed owner);

    /// @notice Emitted when new rewards are added to the staking pool
    /// @param reward The amount of rewards added
    event RewardAdded(uint256 reward);

    /// @notice Emitted when rewards are paid to a user
    /// @param user The address of the user receiving rewards
    /// @param reward The amount of rewards paid
    event RewardPaid(address indexed user, uint256 reward);

    /// @notice Emitted when upfront tax credit is set for a position
    /// @param tokenId The position ID
    /// @param creditAmount The amount of upfront tax credit set
    event UpfrontTaxCreditSet(uint256 indexed tokenId, uint256 creditAmount);

    /// @notice Emitted when upfront tax credit is consumed
    /// @param tokenId The position ID
    /// @param creditConsumed The amount of credit consumed
    /// @param remainingCredit The remaining credit amount
    event UpfrontTaxCreditConsumed(uint256 indexed tokenId, uint256 creditConsumed, uint256 remainingCredit);

    /// @notice Emitted when a position is split
    /// @param originalTokenId The ID of the original position NFT
    /// @param newTokenId The ID of the new position NFT
    /// @param owner The address of the position owner
    /// @param to The address to which the new position is split
    /// @param splitAmount The amount of tokens split
    /// @param splitDeclaredValue The declared value of the split position
    event PositionSplit(
        uint256 indexed originalTokenId,
        uint256 indexed newTokenId,
        address indexed owner,
        address to,
        uint256 splitAmount,
        uint256 splitDeclaredValue
    );

    /// @notice Emitted when a position is merged
    /// @param survivingTokenId The ID of the surviving position NFT
    /// @param mergedTokenId The ID of the merged position NFT
    /// @param owner The address of the position owner
    /// @param newAmount The new amount of tokens staked in the merged position
    /// @param newDeclaredValue The new declared value for harberger tax in the merged position
    event PositionMerged(
        uint256 indexed survivingTokenId,
        uint256 indexed mergedTokenId,
        address indexed owner,
        uint256 newAmount,
        uint256 newDeclaredValue
    );

    /// @notice Emitted when streaming tax is collected from a position
    /// @param tokenId The ID of the position NFT
    /// @param taxAmount The amount of tax collected
    event StreamingTaxCollected(uint256 indexed tokenId, uint256 taxAmount);

    /// @notice Emitted when streaming tax rate is updated for a position
    /// @param tokenId The ID of the position NFT
    /// @param oldRate The old streaming tax rate
    /// @param newRate The new streaming tax rate
    event StreamingTaxRateUpdated(uint256 indexed tokenId, uint256 oldRate, uint256 newRate);

    /// @notice Initializes the staking contract
    /// @param _appToken The address of the dre token
    /// @param _trackingToken The address of the tracking token
    /// @param _authority The address of the authority contract
    /// @param _burner The address of the burner contract
    function initialize(address _appToken, address _trackingToken, address _authority, address _burner) external;

    /// @notice Sets the variables
    /// @param _variables The new variables
    function setVariables(Variables memory _variables) external;

    /// @notice Gets the variables
    /// @return The variables
    function variables() external view returns (Variables memory);

    // View functions
    /// @notice Gets the last time rewards were applicable
    /// @return The timestamp of the last reward application
    function lastTimeRewardApplicable() external view returns (uint256);

    /// @notice Gets the current reward per token rate
    /// @return The reward per token rate
    function rewardPerToken() external view returns (uint256);

    /// @notice Gets the earned rewards for a specific position
    /// @param tokenId The ID of the position NFT
    /// @return The amount of rewards earned
    function earned(uint256 tokenId) external view returns (uint256);

    /// @notice Gets the total amount of tokens staked
    /// @return The total amount of staked tokens
    function totalStaked() external view returns (uint256);

    // State changing functions
    /// @notice Notifies the contract of new rewards to be distributed
    /// @param reward The amount of rewards to be distributed
    function notifyRewardAmount(uint256 reward) external;

    /// @notice Creates a new staking position
    /// @param _user The address of the user creating the position
    /// @param _amount The amount of tokens to stake
    /// @param _declaredValue The self-declared value for harberger tax
    /// @param _lockEnd The timestamp when the lock period ends
    /// @return tokenId The ID of the created position NFT
    /// @return taxPaid The amount of tax paid for the position
    function createPosition(address _user, uint256 _amount, uint256 _declaredValue, uint256 _lockEnd)
        external
        returns (uint256 tokenId, uint256 taxPaid);

    /// @notice Starts the unstaking process for a position
    /// @param tokenId The ID of the position NFT
    function startUnstaking(uint256 tokenId) external;

    /// @notice Completes the unstaking process for a position
    /// @param tokenId The ID of the position NFT
    function completeUnstaking(uint256 tokenId) external;

    /// @notice Buys a staking position
    /// @param tokenId The ID of the position NFT to buy
    function buyPosition(uint256 tokenId) external;

    /// @notice Claims rewards from a staking position
    /// @param tokenId The ID of the position NFT
    /// @return reward The amount of rewards claimed
    function claimRewards(uint256 tokenId) external returns (uint256 reward);

    /// @notice Increases the amount of tokens staked in a position
    /// @param tokenId The ID of the position NFT
    /// @param additionalAmount The additional amount of tokens to stake
    /// @param addtionalDeclaredValue The additional declared value
    /// @return taxPaid The amount of tax paid for the additional amount
    function increaseAmount(uint256 tokenId, uint256 additionalAmount, uint256 addtionalDeclaredValue)
        external
        returns (uint256 taxPaid);

    /// @notice Cancels the unstaking process for a position
    /// @param tokenId The ID of the position NFT
    function cancelUnstaking(uint256 tokenId) external;

    /// @notice Gets the details of a staking position
    /// @param tokenId The ID of the position NFT
    /// @return The position details
    function positions(uint256 tokenId) external view returns (Position memory);

    /// @notice Sets upfront tax credit for a position (governor only)
    /// @param tokenId The position ID
    /// @param creditAmount The amount of upfront tax credit to set
    function setUpfrontTaxCredit(uint256 tokenId, uint256 creditAmount) external;

    /// @notice Gets the remaining upfront tax credit for a position
    /// @param tokenId The position ID
    /// @return The remaining upfront tax credit
    function getUpfrontTaxCredit(uint256 tokenId) external view returns (uint256);

    /// @notice Gets the current reward rate
    /// @return The current reward rate
    function rewardRate() external view returns (uint256);

    /// @notice Gets the current reward per token rate
    /// @return The current reward per token rate
    function rewardPerTokenStored() external view returns (uint256);

    /// @notice Gets the last time rewards were applicable
    /// @return The timestamp of the last reward application
    function lastUpdateTime() external view returns (uint256);

    /// @notice Gets the current reward rate
    /// @return The current reward rate
    function periodFinish() external view returns (uint256);

    /// @notice Gets the address of the burner contract
    /// @return The address of the burner contract
    function burner() external view returns (address);

    /// @notice Gets the epoch duration
    /// @return The epoch duration
    function EPOCH_DURATION() external view returns (uint256);

    /// @notice Gets the app token
    /// @return The app token
    function appToken() external view returns (IERC20);

    /// @notice Splits a position into two positions, sending the new position to a specified address
    /// @param tokenId The ID of the position to split
    /// @param splitRatio The ratio to split the position
    /// @param to The address to receive the new position
    /// @return newTokenId The ID of the newly created position
    function splitPosition(uint256 tokenId, uint256 splitRatio, address to) external returns (uint256 newTokenId);

    /// @notice Merges two positions owned by the caller into a single position.
    /// @param tokenId1 The ID of the first position NFT (this one will survive).
    /// @param tokenId2 The ID of the second position NFT (this one will be burned).
    /// @return mergedTokenId The ID of the resulting merged position (equals tokenId1)
    function mergePositions(uint256 tokenId1, uint256 tokenId2) external returns (uint256 mergedTokenId);

    /// @notice Collects streaming tax from a position
    /// @param id The ID of the position NFT
    /// @return tax The amount of tax collected
    /// @return credit The amount of credit used
    function collectStreamingTax(uint256 id) external returns (uint256 tax, uint256 credit);

    /// @notice Calculates the streaming tax owed for a position
    /// @param id The ID of the position NFT
    /// @return tax The amount of tax owed
    function calculateStreamingTax(uint256 id) external view returns (uint256 tax);
}
