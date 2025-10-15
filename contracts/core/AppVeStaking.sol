// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "../interfaces/IAppVeStaking.sol";
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
contract AppVeStaking is IAppVeStaking, AppAccessControlled, ERC721EnumerableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    /// @inheritdoc IAppVeStaking
    uint256 public immutable MAX_LOCK_DURATION = 6 * 30 days; // 6 months

    /// @inheritdoc IAppVeStaking
    IERC20 public rzr;

    /// @inheritdoc IAppVeStaking
    IPermissionedERC20 public votingPowerToken;

    /// @inheritdoc IAppVeStaking
    uint256 public lastId;

    /// @inheritdoc IAppVeStaking
    uint256 public totalLocked;

    /// @inheritdoc IAppVeStaking
    mapping(uint256 tokenId => bool blacklisted) public blacklisted;

    mapping(uint256 tokenId => Lock lock) private _locks;

    modifier onlyOwnerOrAuthorized(uint256 tokenId) {
        _onlyOwnerOrAuthorized(tokenId);
        _;
    }

    /// @inheritdoc IAppVeStaking
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

    /// @inheritdoc IAppVeStaking
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
            lockStartDate: block.timestamp
        });

        totalLocked += amount;
        votingPowerToken.mint(receiver, lock.votingPower);
        _locks[lastId] = lock;
        emit Locked(msg.sender, receiver, amount, duration);
    }

    /// @inheritdoc IAppVeStaking
    function unlock(uint256 tokenId) external nonReentrant onlyOwnerOrAuthorized(tokenId) {
        _onlyNotBlacklisted(tokenId);
        require(_locks[tokenId].lockStartDate + _locks[tokenId].duration <= block.timestamp, "Lock not ended");
        require(_locks[tokenId].amount > 0, "Lock not started");

        address owner = ownerOf(tokenId);
        uint256 votingPower = _locks[tokenId].votingPower;
        uint256 amount = _locks[tokenId].amount;
        totalLocked -= amount;
        delete _locks[tokenId];

        votingPowerToken.burn(owner, votingPower);
        rzr.safeTransfer(owner, amount);
        emit Unlocked(owner, tokenId, amount);

        _burn(tokenId);
    }

    /// @inheritdoc IAppVeStaking
    function increaseLockDuration(uint256 tokenId, uint256 duration)
        external
        nonReentrant
        onlyOwnerOrAuthorized(tokenId)
    {
        _validAndActiveLock(tokenId);

        address owner = ownerOf(tokenId);
        Lock storage lock = _locks[tokenId];

        uint256 currentVotingPower = lock.votingPower;

        lock.duration += duration;
        lock.votingPower = votingPower(lock.amount, lock.duration);
        require(lock.duration <= MAX_LOCK_DURATION, "Max lock duration exceeded");

        votingPowerToken.mint(owner, lock.votingPower - currentVotingPower);
        emit LockDurationIncreased(owner, tokenId, lock.duration);
    }

    /// @inheritdoc IAppVeStaking
    function increaseLockAmount(uint256 tokenId, uint256 amount) external nonReentrant {
        _validAndActiveLock(tokenId);
        Lock memory lock = _locks[tokenId];

        rzr.safeTransferFrom(msg.sender, address(this), amount);

        address owner = ownerOf(tokenId);
        uint256 currentVotingPower = lock.votingPower;
        lock.amount += amount;
        lock.votingPower = votingPowerOfLock(lock);
        totalLocked += amount;

        _locks[tokenId] = lock;
        votingPowerToken.mint(owner, lock.votingPower - currentVotingPower);

        emit LockAmountIncreased(owner, tokenId, amount);
    }

    /// @inheritdoc IAppVeStaking
    function split(uint256 tokenId, uint256 percentageE18, address to)
        external
        nonReentrant
        onlyOwnerOrAuthorized(tokenId)
    {
        _checkPercentage(percentageE18);
        _validAndActiveLock(tokenId);

        Lock storage lock = _locks[tokenId];

        address owner = ownerOf(tokenId);
        uint256 splitAmount = lock.amount * percentageE18 / 1e18;
        uint256 splitVotingPower = lock.votingPower * percentageE18 / 1e18;

        lock.amount -= splitAmount;
        lock.votingPower -= splitVotingPower;

        _mint(to, ++lastId);
        _locks[lastId] = Lock({
            amount: splitAmount,
            duration: lock.duration,
            votingPower: splitVotingPower,
            lockStartDate: lock.lockStartDate
        });

        votingPowerToken.transferPermissioned(owner, to, splitVotingPower);

        emit Split(tokenId, lastId, owner, to, splitAmount, splitVotingPower);
    }

    /// @inheritdoc IAppVeStaking
    function merge(uint256 tokenId1, uint256 tokenId2) external nonReentrant {
        _validAndActiveLock(tokenId1);
        _validAndActiveLock(tokenId2);
        _onlyOwnerOrAuthorized(tokenId1);
        _onlyOwnerOrAuthorized(tokenId2);

        Lock storage lock1 = _locks[tokenId1];
        Lock storage lock2 = _locks[tokenId2];

        votingPowerToken.burn(ownerOf(tokenId1), lock1.votingPower);
        votingPowerToken.burn(ownerOf(tokenId2), lock2.votingPower);

        lock1.duration = Math.max(lock1.duration, lock2.duration);
        lock1.lockStartDate = Math.max(lock1.lockStartDate, lock2.lockStartDate);
        lock1.amount += lock2.amount;
        lock1.votingPower = votingPower(lock1.amount, lock1.duration);

        votingPowerToken.mint(ownerOf(tokenId1), lock1.votingPower);

        _burn(tokenId2);
        delete _locks[tokenId2];

        emit Merged(tokenId1, tokenId2, lock1.amount, lock1.votingPower);
    }

    /// @inheritdoc IAppVeStaking
    function blacklist(uint256 tokenId) external onlyGuardianOrGovernor {
        blacklisted[tokenId] = true;
        emit PositionBlacklisted(tokenId);
    }

    /// @inheritdoc IAppVeStaking
    function votingPower(uint256 amount, uint256 duration) public view returns (uint256) {
        return amount * duration / MAX_LOCK_DURATION;
    }

    /// @inheritdoc IAppVeStaking
    function votingPowerOfLock(Lock memory lock) public view returns (uint256) {
        return votingPower(lock.amount, lock.duration);
    }

    /// @inheritdoc IAppVeStaking
    function locks(uint256 tokenId) external view returns (Lock memory) {
        return _locks[tokenId];
    }

    function _onlyOwnerOrAuthorized(uint256 tokenId) internal view {
        require(
            ownerOf(tokenId) == msg.sender || isApprovedForAll(ownerOf(tokenId), msg.sender), "Not owner or approved"
        );
    }

    function _onlyNotBlacklisted(uint256 tokenId) internal view {
        require(!blacklisted[tokenId], "Blacklisted");
    }

    function _checkPercentage(uint256 percentageE18) internal pure {
        require(percentageE18 > 0 && percentageE18 <= 1e18, "Invalid percentage");
    }

    function _validAndActiveLock(uint256 tokenId) internal view {
        _onlyNotBlacklisted(tokenId);
        require(_locks[tokenId].amount > 0, "Invalid lock amount");
        require(_locks[tokenId].lockStartDate + _locks[tokenId].duration >= block.timestamp, "Lock ended");
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address from) {
        _onlyNotBlacklisted(tokenId);

        // Call parent which performs the actual state update and returns the previous owner (or zero address on mint).
        from = super._update(to, tokenId, auth);

        // Skip for mint (from == 0) and burn (to == 0). Only handle transfers between non-zero addresses.
        if (from != address(0) && to != address(0)) {
            // Burn tracking tokens from the sender and mint to the receiver.
            uint256 stakingPower = _locks[tokenId].votingPower;
            if (stakingPower > 0) votingPowerToken.transferPermissioned(from, to, stakingPower);
            emit PositionTransferred(from, to, tokenId, stakingPower);
        }
    }
}
