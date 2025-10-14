// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "../interfaces/IAppStaking.sol";
import "../interfaces/IPermissionedERC20.sol";
import "../interfaces/IPermissionedERC20Factory.sol";
import "./AppAccessControlled.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/// @title AppVeStaking
/// @notice Implementation of the ve staking system that allows users to stake RZR tokens and earn rewards
/// @dev This contract handles ve staking positions as NFTs, with reward distribution
contract AppVeStaking is AppAccessControlled, ERC721EnumerableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    uint256 public immutable EPOCH_DURATION = 23.5 hours;
    uint256 public immutable MAX_LOCK_DURATION = 6 * 30 days; // 6 months

    IERC20 public rzr;

    IPermissionedERC20 public votingPowerToken;

    uint256 public lastId;

    uint256 public totalLocked;

    struct Lock {
        uint256 amount;
        uint256 duration;
        uint256 votingPower;
        uint256 lockStartDate;
        uint256 lockEndDate;
    }

    mapping(uint256 tokenId => Lock lock) public locks;
    mapping(uint256 tokenId => bool blacklisted) public blacklisted;

    event Locked(address indexed user, address indexed receiver, uint256 amount, uint256 duration);
    event Unlocked(address indexed user, uint256 tokenId, uint256 amount);
    event LockDurationIncreased(address indexed user, uint256 tokenId, uint256 duration);
    event LockAmountIncreased(address indexed user, uint256 tokenId, uint256 amount);
    event PositionTransferred(address indexed from, address indexed to, uint256 tokenId, uint256 amount);
    event PositionBlacklisted(uint256 tokenId);

    function initialize(address _rzr, address _tokenFactory, address _authority) public reinitializer(1) {
        if (lastId == 0) lastId = 1;

        __ERC721_init("RZR Staking Position", "RZR-POS");
        __ReentrancyGuard_init();
        __AppAccessControlled_init(_authority);

        require(_rzr != address(0), "Invalid RZR token address");
        require(_tokenFactory != address(0), "Invalid token factory address");

        rzr = IERC20(_rzr);
        if (address(votingPowerToken) == address(0)) {
            IPermissionedERC20Factory factory = IPermissionedERC20Factory(_tokenFactory);
            votingPowerToken = factory.createPermissionedERC20("RZR Voting Power", "vRZRp", 18);
        }
    }

    modifier onlyOwnerOrAuthorized(uint256 tokenId) {
        _onlyOwnerOrAuthorized(tokenId);
        _;
    }

    function lock(uint256 amount, uint256 duration, address receiver) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(duration > 0, "Duration must be greater than 0");
        require(duration <= MAX_LOCK_DURATION, "Max lock duration exceeded");
        require(receiver != address(0), "Invalid receiver address");

        rzr.transferFrom(msg.sender, address(this), amount);
        _mint(receiver, ++lastId);

        Lock memory lock = Lock({
            amount: amount,
            duration: duration,
            votingPower: votingPower(amount, duration),
            lockStartDate: block.timestamp,
            lockEndDate: block.timestamp + duration
        });

        totalLocked += amount;
        votingPowerToken.mint(receiver, lock.votingPower);
        locks[lastId] = lock;
        emit Locked(msg.sender, receiver, amount, duration);
    }

    function unlock(uint256 tokenId) external nonReentrant onlyOwnerOrAuthorized(tokenId) {
        _onlyNotBlacklisted(tokenId);
        require(locks[tokenId].lockEndDate <= block.timestamp, "Lock not ended");
        require(locks[tokenId].amount > 0, "Lock not started");

        address owner = ownerOf(tokenId);
        uint256 votingPower = locks[tokenId].votingPower;
        uint256 amount = locks[tokenId].amount;
        totalLocked -= amount;
        delete locks[tokenId];

        votingPowerToken.burn(owner, votingPower);
        rzr.safeTransfer(owner, amount);
        emit Unlocked(owner, tokenId, amount);

        _burn(tokenId);
    }

    function increaseLockDuration(uint256 tokenId, uint256 duration)
        external
        nonReentrant
        onlyOwnerOrAuthorized(tokenId)
    {
        _onlyNotBlacklisted(tokenId);
        require(locks[tokenId].duration + duration <= MAX_LOCK_DURATION, "Max lock duration exceeded");
        require(locks[tokenId].lockEndDate >= block.timestamp, "Lock ended");
        require(locks[tokenId].amount > 0, "Invalid lock amount");

        uint256 currentVotingPower = locks[tokenId].votingPower;

        Lock memory lock = locks[tokenId];
        address owner = ownerOf(tokenId);
        lock.duration += duration;
        lock.lockEndDate += duration;
        lock.votingPower = votingPowerOfLock(lock);

        locks[tokenId] = lock;
        votingPowerToken.mint(owner, lock.votingPower - currentVotingPower);

        emit LockDurationIncreased(owner, tokenId, lock.duration);
    }

    function increaseLockAmount(uint256 tokenId, uint256 amount) external nonReentrant {
        Lock memory lock = locks[tokenId];

        rzr.safeTransferFrom(msg.sender, address(this), amount);

        address owner = ownerOf(tokenId);
        uint256 currentVotingPower = lock.votingPower;
        lock.amount += amount;
        lock.votingPower = votingPowerOfLock(lock);
        totalLocked += amount;

        locks[tokenId] = lock;
        votingPowerToken.mint(owner, lock.votingPower - currentVotingPower);

        emit LockAmountIncreased(owner, tokenId, amount);
    }

    function blacklist(uint256 tokenId) external onlyGuardianOrGovernor {
        blacklisted[tokenId] = true;
        emit PositionBlacklisted(tokenId);
    }

    function votingPower(uint256 amount, uint256 duration) public pure returns (uint256) {
        return amount * duration / MAX_LOCK_DURATION;
    }

    function votingPowerOfLock(Lock memory lock) public pure returns (uint256) {
        return lock.amount * lock.duration / MAX_LOCK_DURATION;
    }

    function _onlyOwnerOrAuthorized(uint256 tokenId) internal view {
        require(
            ownerOf(tokenId) == msg.sender || isApprovedForAll(ownerOf(tokenId), msg.sender), "Not owner or approved"
        );
    }

    function _onlyNotBlacklisted(uint256 tokenId) internal view {
        require(!blacklisted[tokenId], "Blacklisted");
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address from) {
        _onlyNotBlacklisted(tokenId);

        // Call parent which performs the actual state update and returns the previous owner (or zero address on mint).
        from = super._update(to, tokenId, auth);

        // Skip for mint (from == 0) and burn (to == 0). Only handle transfers between non-zero addresses.
        if (from != address(0) && to != address(0)) {
            // Burn tracking tokens from the sender and mint to the receiver.
            uint256 stakingPower = locks[tokenId].votingPower;
            if (stakingPower > 0) votingPowerToken.transferPermissioned(from, to, stakingPower);
            emit PositionTransferred(from, to, tokenId, stakingPower);
        }
    }
}
