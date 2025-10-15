// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "./IApp.sol";
import "./IPermissionedERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

/// @title IAppVeStaking
/// @notice Interface for the AppVeStaking contract that manages vote-escrowed RZR token staking
/// @dev Implements a ve-tokenomics model where users lock RZR tokens for voting power
/// @dev Each staking position is represented as an ERC721 NFT that can be transferred, split, or merged
interface IAppVeStaking {
    /// @notice Represents an individual ve staking lock position
    /// @dev Each lock is represented as an ERC721 token
    struct Lock {
        /// @notice Amount of RZR tokens locked in this position
        uint256 amount;
        /// @notice Duration of the lock in seconds
        uint256 duration;
        /// @notice Current voting power of this position (amount * duration / MAX_LOCK_DURATION)
        uint256 votingPower;
        /// @notice Timestamp when the lock was created
        uint256 lockStartDate;
    }

    /// @notice Emitted when a user locks RZR tokens
    /// @param user The address that initiated the lock
    /// @param receiver The address that receives the staking position NFT
    /// @param amount The amount of RZR tokens locked
    /// @param duration The duration of the lock in seconds
    event Locked(address indexed user, address indexed receiver, uint256 amount, uint256 duration);

    /// @notice Emitted when a user unlocks their staking position
    /// @param user The address that unlocked the position
    /// @param tokenId The ID of the position being unlocked
    /// @param amount The amount of RZR tokens returned
    event Unlocked(address indexed user, uint256 tokenId, uint256 amount);

    /// @notice Emitted when a lock's duration is increased
    /// @param user The address that increased the duration
    /// @param tokenId The ID of the position
    /// @param duration The new total duration of the lock
    event LockDurationIncreased(address indexed user, uint256 tokenId, uint256 duration);

    /// @notice Emitted when additional tokens are locked into an existing position
    /// @param user The address that increased the lock amount
    /// @param tokenId The ID of the position
    /// @param amount The additional amount of tokens locked
    event LockAmountIncreased(address indexed user, uint256 tokenId, uint256 amount);

    /// @notice Emitted when a staking position NFT is transferred
    /// @param from The address transferring the position
    /// @param to The address receiving the position
    /// @param tokenId The ID of the position being transferred
    /// @param amount The voting power being transferred with the position
    event PositionTransferred(address indexed from, address indexed to, uint256 tokenId, uint256 amount);

    /// @notice Emitted when a staking position is blacklisted by governance
    /// @param tokenId The ID of the position being blacklisted
    event PositionBlacklisted(uint256 tokenId);

    /// @notice Emitted when a staking position is split into two positions
    /// @param tokenId The original position ID
    /// @param newTokenId The new position ID created from the split
    /// @param owner The owner of the original position
    /// @param to The recipient of the new split position
    /// @param amount The amount of tokens in the new position
    /// @param votingPower The voting power allocated to the new position
    event Split(
        uint256 tokenId,
        uint256 newTokenId,
        address indexed owner,
        address indexed to,
        uint256 amount,
        uint256 votingPower
    );

    /// @notice Emitted when two staking positions are merged into one
    /// @param tokenId1 The ID of the position that receives the merge
    /// @param tokenId2 The ID of the position being merged (will be burned)
    /// @param amount The total amount after merge
    /// @param votingPower The total voting power after merge
    event Merged(uint256 tokenId1, uint256 tokenId2, uint256 amount, uint256 votingPower);

    /// @notice Initializes the contract (upgradeable pattern)
    /// @param _rzr The address of the RZR token contract
    /// @param _tokenFactory The address of the PermissionedERC20Factory for creating voting power tokens
    /// @param _authority The address of the AppAuthority contract
    function initialize(address _rzr, address _tokenFactory, address _authority) external;

    /// @notice Returns the RZR token contract
    /// @return The IERC20 interface for the RZR token
    function rzr() external view returns (IERC20);

    /// @notice Returns the voting power token contract
    /// @dev This token tracks voting power and is non-transferable except through position transfers
    /// @return The IPermissionedERC20 interface for the voting power token
    function votingPowerToken() external view returns (IPermissionedERC20);

    /// @notice Returns the ID of the last created position
    /// @return The most recent position ID
    function lastId() external view returns (uint256);

    /// @notice Returns the total amount of RZR tokens locked across all positions
    /// @return The total locked RZR amount
    function totalLocked() external view returns (uint256);

    /// @notice Retrieves the lock data for a specific position
    /// @param tokenId The ID of the position to query
    /// @return The Lock struct containing all position details
    function locks(uint256 tokenId) external view returns (Lock memory);

    /// @notice Checks if a position is blacklisted
    /// @param tokenId The ID of the position to check
    /// @return True if the position is blacklisted, false otherwise
    function blacklisted(uint256 tokenId) external view returns (bool);

    /// @notice Creates a new lock position by staking RZR tokens
    /// @dev Mints an NFT representing the lock position to the receiver
    /// @dev Voting power is calculated as: amount * duration / MAX_LOCK_DURATION
    /// @param amount The amount of RZR tokens to lock
    /// @param duration The duration of the lock in seconds (must be <= MAX_LOCK_DURATION)
    /// @param receiver The address that will receive the lock position NFT
    function lock(uint256 amount, uint256 duration, address receiver) external;

    /// @notice Unlocks a position and returns the staked RZR tokens
    /// @dev Can only be called after the lock duration has expired
    /// @dev Burns the position NFT and voting power tokens
    /// @param tokenId The ID of the position to unlock
    function unlock(uint256 tokenId) external;

    /// @notice Increases the duration of an existing lock
    /// @dev Increases voting power proportionally to the duration increase
    /// @dev The new total duration cannot exceed MAX_LOCK_DURATION
    /// @param tokenId The ID of the position to extend
    /// @param duration The additional duration to add (in seconds)
    function increaseLockDuration(uint256 tokenId, uint256 duration) external;

    /// @notice Increases the amount of tokens locked in an existing position
    /// @dev Anyone can call this to increase any position's locked amount
    /// @dev Increases voting power proportionally to the amount increase
    /// @dev Voting power is minted to the position owner, not the caller
    /// @param tokenId The ID of the position to increase
    /// @param amount The additional amount of RZR tokens to lock
    function increaseLockAmount(uint256 tokenId, uint256 amount) external;

    /// @notice Splits a lock position into two separate positions
    /// @dev The original position is reduced and a new position is created
    /// @dev Voting power is transferred proportionally from owner to recipient
    /// @param tokenId The ID of the position to split
    /// @param percentageE18 The percentage to split off (in 18 decimals, where 1e18 = 100%)
    /// @param to The address that will receive the new split position
    function split(uint256 tokenId, uint256 percentageE18, address to) external;

    /// @notice Merges two lock positions owned by the same user into one
    /// @dev The second position is burned and its amounts are added to the first
    /// @dev Takes the maximum duration and latest start date of the two positions
    /// @dev Caller must own or be approved for both positions
    /// @param tokenId1 The ID of the position that will receive the merge
    /// @param tokenId2 The ID of the position to merge in (will be burned)
    function merge(uint256 tokenId1, uint256 tokenId2) external;

    /// @notice Blacklists a staking position, preventing most operations
    /// @dev Only callable by guardian or governor
    /// @dev Blacklisted positions cannot be unlocked, transferred, or have duration increased
    /// @dev However, they can still have their locked amount increased
    /// @param tokenId The ID of the position to blacklist
    function blacklist(uint256 tokenId) external;

    /// @notice Calculates voting power for a given amount and duration
    /// @dev Formula: votingPower = amount * duration / MAX_LOCK_DURATION
    /// @dev Maximum voting power (1:1 with amount) is achieved at MAX_LOCK_DURATION
    /// @param amount The amount of RZR tokens
    /// @param duration The lock duration in seconds
    /// @return The calculated voting power
    function votingPower(uint256 amount, uint256 duration) external view returns (uint256);

    /// @notice Calculates voting power for a given lock
    /// @param lock The Lock struct to calculate voting power for
    /// @return The calculated voting power
    function votingPowerOfLock(Lock memory lock) external view returns (uint256);

    /// @notice Returns the maximum allowed lock duration
    /// @return The maximum lock duration in seconds (6 months)
    function MAX_LOCK_DURATION() external view returns (uint256);
}
