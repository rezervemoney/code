// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/IAppStaking.sol";
import "../interfaces/IPermissionedERC20.sol";
import "./AppAccessControlled.sol";

/// @title AppStaking
/// @notice Implementation of the staking system that allows users to stake RZR tokens and earn rewards
/// @dev This contract handles staking positions as NFTs, with harberger tax and reward distribution
contract AppStaking is
    IAppStaking,
    AppAccessControlled,
    ERC721EnumerableUpgradeable,
    ReentrancyGuardUpgradeable,
    MulticallUpgradeable
{
    using SafeERC20 for IERC20;

    uint256 public immutable BASIS_POINTS = 10000;
    uint256 public immutable EPOCH_DURATION = 8 hours;

    // Configurable parameters
    uint256 public harbergerTaxRate;
    uint256 public resellFeeRate;
    uint256 public withdrawCooldownPeriod;
    uint256 public rewardCooldownPeriod;

    // State variables
    IERC20 public override appToken;
    IPermissionedERC20 public trackingToken;

    // Mapping from token ID to Position
    mapping(uint256 => Position) private _positions;

    uint256 public lastId;

    /// @inheritdoc IAppStaking
    uint256 public periodFinish;

    /// @inheritdoc IAppStaking
    uint256 public rewardRate;

    /// @inheritdoc IAppStaking
    uint256 public lastUpdateTime;

    /// @inheritdoc IAppStaking
    uint256 public rewardPerTokenStored;

    /// @inheritdoc IAppStaking
    uint256 public override totalStaked;

    /// @inheritdoc IAppStaking
    address public burner;

    // Mapping from token ID to buy cooldown end timestamp
    mapping(uint256 => uint256) private _buyCooldownEnd;

    /// @inheritdoc IAppStaking
    uint256 public buyCooldownPeriod;

    // Mapping from token ID to withdraw cooldown end timestamp
    mapping(uint256 => uint256) private _withdrawCooldownStart;

    // Streaming tax constants
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant STREAMING_TAX_PRECISION = 1e18;

    // Mapping from token ID to StreamingTaxData
    mapping(uint256 => StreamingTaxData) private _streamingTaxData;

    /// @inheritdoc IAppStaking
    function initialize(address _appToken, address _trackingToken, address _authority, address _burner)
        public
        reinitializer(9)
    {
        if (lastId == 0) lastId = 1;

        __ERC721_init("RZR Staking Position", "RZR-POS");
        __ReentrancyGuard_init();
        __AppAccessControlled_init(_authority);
        __Multicall_init();

        uint256 _harbergerTaxRate = 500;
        uint256 _resellFeeRate = 100;
        uint256 _withdrawCooldownPeriod = 3 days;
        uint256 _rewardCooldownPeriod = 1 days;
        uint256 _buyCooldownPeriod = 1 days;

        require(_appToken != address(0), "Invalid RZR token address");
        require(_trackingToken != address(0), "Invalid tracking token address");
        require(_harbergerTaxRate <= BASIS_POINTS, "Invalid harberger tax rate");
        require(_resellFeeRate <= BASIS_POINTS, "Invalid resell fee rate");
        require(_withdrawCooldownPeriod > 0, "Invalid withdraw cooldown period");
        require(_rewardCooldownPeriod > 0, "Invalid reward cooldown period");
        require(_buyCooldownPeriod > 0, "Invalid buy cooldown period");

        appToken = IERC20(_appToken);
        trackingToken = IPermissionedERC20(_trackingToken);
        burner = _burner;

        harbergerTaxRate = _harbergerTaxRate;
        resellFeeRate = _resellFeeRate;
        withdrawCooldownPeriod = _withdrawCooldownPeriod;
        rewardCooldownPeriod = _rewardCooldownPeriod;
        buyCooldownPeriod = _buyCooldownPeriod;
    }

    /// @notice Sets the harberger tax rate
    /// @param _harbergerTaxRate The new harberger tax rate
    function setHarbergerTaxRate(uint256 _harbergerTaxRate) external onlyGovernor {
        require(_harbergerTaxRate <= BASIS_POINTS, "Invalid harberger tax rate");
        uint256 oldValue = harbergerTaxRate;
        harbergerTaxRate = _harbergerTaxRate;
        emit HarbergerTaxRateUpdated(oldValue, _harbergerTaxRate);
    }

    /// @notice Sets the withdraw cooldown period
    /// @param _withdrawCooldownPeriod The new withdraw cooldown period
    function setWithdrawCooldownPeriod(uint256 _withdrawCooldownPeriod) external onlyGovernor {
        require(_withdrawCooldownPeriod > 0, "Invalid withdraw cooldown period");
        uint256 oldValue = withdrawCooldownPeriod;
        withdrawCooldownPeriod = _withdrawCooldownPeriod;
        emit WithdrawCooldownPeriodUpdated(oldValue, _withdrawCooldownPeriod);
    }

    /// @notice Sets the reward cooldown period
    /// @param _rewardCooldownPeriod The new reward cooldown period
    function setRewardCooldownPeriod(uint256 _rewardCooldownPeriod) external onlyPolicy {
        require(_rewardCooldownPeriod > 0, "Invalid reward cooldown period");
        uint256 oldValue = rewardCooldownPeriod;
        rewardCooldownPeriod = _rewardCooldownPeriod;
        emit RewardCooldownPeriodUpdated(oldValue, _rewardCooldownPeriod);
    }

    /// @inheritdoc IAppStaking
    function positions(uint256 tokenId) external view override returns (Position memory) {
        return _positions[tokenId];
    }

    /// @inheritdoc IAppStaking
    function streamingTaxData(uint256 tokenId) external view override returns (StreamingTaxData memory) {
        return _streamingTaxData[tokenId];
    }

    /// @notice Sets the buy cooldown period
    /// @param _buyCooldownPeriod The new buy cooldown period
    function setBuyCooldownPeriod(uint256 _buyCooldownPeriod) external onlyGovernor {
        require(_buyCooldownPeriod > 0, "Invalid buy cooldown period");
        uint256 oldValue = buyCooldownPeriod;
        buyCooldownPeriod = _buyCooldownPeriod;
        emit BuyCooldownPeriodUpdated(oldValue, _buyCooldownPeriod);
    }

    /// @notice Gets the buy cooldown end timestamp for a position
    /// @param tokenId The position ID
    /// @return The timestamp when buy cooldown ends, or 0 if not in cooldown
    function getBuyCooldownEnd(uint256 tokenId) external view returns (uint256) {
        return _buyCooldownEnd[tokenId];
    }

    /// @inheritdoc IAppStaking
    function lastTimeRewardApplicable() public view override returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    /// @inheritdoc IAppStaking
    function rewardPerToken() public view override returns (uint256) {
        if (totalStaked == 0) return rewardPerTokenStored;
        // Round down at each step to prevent over-distribution
        uint256 timeElapsed = lastTimeRewardApplicable() - lastUpdateTime;
        uint256 rewardPerTokenDelta = (timeElapsed * rewardRate * 1e18) / totalStaked;
        return rewardPerTokenStored + rewardPerTokenDelta;
    }

    /// @inheritdoc IAppStaking
    function notifyRewardAmount(uint256 reward) external override onlyPolicy {
        require(reward > 0, "No reward");
        require(totalStaked > 0, "No stakers");

        // Update rewards
        _updateReward(0);
        appToken.safeTransferFrom(msg.sender, address(this), reward);

        if (block.timestamp >= periodFinish) {
            // If no reward is currently being distributed, the new rate is just `reward / duration`
            rewardRate = reward / EPOCH_DURATION;
        } else {
            // Otherwise, cancel the future reward and add the amount left to distribute to reward
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / EPOCH_DURATION;
        }

        // Ensures the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of `rewardRate` in the earned and `rewardsPerToken` functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = appToken.balanceOf(address(this));
        require(rewardRate <= balance / EPOCH_DURATION, "Reward rate too high");

        // Update period finish
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + EPOCH_DURATION;

        emit RewardAdded(reward);
    }

    /// @inheritdoc IAppStaking
    function createPosition(address to, uint256 amount, uint256 declaredValue, uint256 minLockDuration)
        external
        override
        nonReentrant
        returns (uint256 tokenId, uint256 taxPaid)
    {
        require(amount > 0, "Amount must be greater than 0");
        require(declaredValue > 0, "Declared value must be greater than 0");
        _updateReward(0);

        // Transfer RZR tokens from user
        appToken.safeTransferFrom(msg.sender, address(this), amount);

        // Calculate streaming tax rate based on declared value
        uint256 streamingTaxRate = _calculateStreamingTaxRate(declaredValue);

        // Create new position
        tokenId = lastId++;
        _mint(to, tokenId);

        _positions[tokenId] = Position({
            amount: amount,
            declaredValue: declaredValue,
            rewardPerTokenPaid: rewardPerTokenStored,
            rewards: 0,
            cooldownEnd: 0,
            rewardsUnlockAt: block.timestamp + rewardCooldownPeriod
        });

        _streamingTaxData[tokenId] = StreamingTaxData({
            lastTaxCollectionTime: block.timestamp,
            streamingTaxRate: streamingTaxRate,
            lastAppliedTaxRate: 0,
            hasPaidUpfrontTax: false,
            upfrontTaxCredit: 0
        });

        _withdrawCooldownStart[tokenId] = block.timestamp + minLockDuration;

        totalStaked += amount;

        // Mint tracking tokens for the staked amount
        trackingToken.mint(to, amount);

        emit PositionCreated(tokenId, to, amount, declaredValue);
    }

    /// @inheritdoc IAppStaking
    function startUnstaking(uint256 tokenId) external override nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(_positions[tokenId].cooldownEnd == 0, "Already in cooldown");
        require(_withdrawCooldownStart[tokenId] <= block.timestamp, "Currently in withdraw cooldown");

        // Collect any pending streaming taxes
        _collectStreamingTaxInternal(tokenId);

        Position storage position = _positions[tokenId];
        _updateReward(tokenId);
        position.cooldownEnd = block.timestamp + withdrawCooldownPeriod;

        emit CooldownStarted(tokenId, msg.sender);
    }

    /// @inheritdoc IAppStaking
    function completeUnstaking(uint256 tokenId) external override nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "Not owner");

        Position storage position = _positions[tokenId];
        require(position.cooldownEnd > 0, "Not in cooldown");
        require(block.timestamp >= position.cooldownEnd, "Cooldown not finished");

        // Collect any pending streaming taxes
        _collectStreamingTaxInternal(tokenId);

        _updateReward(tokenId);

        uint256 amount = position.amount;
        totalStaked -= amount;

        // Burn tracking tokens for the unstaked amount
        trackingToken.burn(msg.sender, amount);

        // Transfer RZR tokens back to user
        appToken.safeTransfer(msg.sender, amount);

        // Burn the NFT
        _burn(tokenId);
        delete _positions[tokenId];
        delete _streamingTaxData[tokenId];
        delete _buyCooldownEnd[tokenId];
        delete _withdrawCooldownStart[tokenId];

        emit PositionUnstaked(tokenId, msg.sender, amount);
    }

    function updateWithdrawCooldown(uint256 tokenId, uint256 newCooldownEnd) external onlyGovernor {
        _withdrawCooldownStart[tokenId] = newCooldownEnd;
    }

    /// @inheritdoc IAppStaking
    function buyPosition(uint256 tokenId) external override nonReentrant {
        address seller = ownerOf(tokenId);
        require(seller != address(0), "Position does not exist");
        require(seller != msg.sender, "Cannot buy your own position");

        // Check if position is in buy cooldown
        require(
            _buyCooldownEnd[tokenId] == 0 || block.timestamp >= _buyCooldownEnd[tokenId], "Position in buy cooldown"
        );

        // Collect any pending streaming taxes from the seller
        _collectStreamingTaxInternal(tokenId);

        Position storage position = _positions[tokenId];
        uint256 price = position.declaredValue;

        // Calculate resell fee
        uint256 resellFee = (price * resellFeeRate) / BASIS_POINTS;
        uint256 sellerAmount = price - resellFee;

        // Transfer RZR tokens from buyer
        appToken.safeTransferFrom(msg.sender, address(this), price);

        // Distribute payment
        appToken.safeTransfer(seller, sellerAmount);
        appToken.safeTransfer(burner, resellFee);

        // Transfer NFT to buyer (tracking tokens are transferred in _update)
        _transfer(seller, msg.sender, tokenId);

        // Cancel unstaking and claim any pending rewards to avoid getting sniped
        _cancelUnstaking(tokenId);
        _claimRewards(tokenId);

        // Set buy cooldown end timestamp
        _buyCooldownEnd[tokenId] = block.timestamp + buyCooldownPeriod;

        emit PositionSold(tokenId, seller, msg.sender, price);
    }

    /// @inheritdoc IAppStaking
    function claimRewards(uint256 tokenId) external override nonReentrant returns (uint256 reward) {
        // Collect any pending streaming taxes
        _collectStreamingTaxInternal(tokenId);
        
        reward = _claimRewards(tokenId);
    }

    /// @inheritdoc IAppStaking
    function earned(uint256 tokenId) public view override returns (uint256) {
        Position storage position = _positions[tokenId];
        if (position.amount == 0) return 0;

        uint256 currentRewardPerToken = rewardPerToken();
        // Round down at each step to prevent over-distribution
        uint256 rewardDelta = (position.amount * (currentRewardPerToken - position.rewardPerTokenPaid)) / 1e18;
        return rewardDelta + position.rewards;
    }

    /// @inheritdoc IAppStaking
    function increaseAmount(uint256 tokenId, uint256 additionalAmount, uint256 addtionalDeclaredValue)
        external
        override
        nonReentrant
        returns (uint256 taxPaid)
    {
        require(ownerOf(tokenId) != address(0), "Position does not exist");
        require(additionalAmount > 0, "Amount must be greater than 0");
        require(_positions[tokenId].cooldownEnd == 0, "Position is in cooldown");
        require(addtionalDeclaredValue > 0 || additionalAmount > 0, "Declared value or amount must be greater than 0");

        // Collect any pending streaming taxes
        _collectStreamingTaxInternal(tokenId);

        _updateReward(tokenId);

        Position storage position = _positions[tokenId];
        address owner = ownerOf(tokenId);

        // Transfer RZR tokens from user
        if (additionalAmount > 0) {
            appToken.safeTransferFrom(msg.sender, address(this), additionalAmount);
        }

        // Update streaming tax rate for the additional declared value
        if (addtionalDeclaredValue > 0) {
            uint256 newStreamingTaxRate = _calculateStreamingTaxRate(
                position.declaredValue + addtionalDeclaredValue
            );
            StreamingTaxData storage taxData = _streamingTaxData[tokenId];
            uint256 oldRate = taxData.streamingTaxRate;
            taxData.streamingTaxRate = newStreamingTaxRate;
            emit StreamingTaxRateUpdated(tokenId, oldRate, newStreamingTaxRate);
        }

        // Update position
        position.amount += additionalAmount;
        position.declaredValue += addtionalDeclaredValue;
        totalStaked += additionalAmount;

        require(position.amount > 0, "Position amount must be greater than 0");

        // Update rewards
        _updateReward(tokenId);

        // Mint tracking tokens for the additional amount
        trackingToken.mint(owner, additionalAmount);

        emit PositionUpdated(tokenId, owner, position.amount, position.declaredValue);
    }

    /// @inheritdoc IAppStaking
    function cancelUnstaking(uint256 tokenId) external override nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "Not owner");

        Position storage position = _positions[tokenId];
        require(position.cooldownEnd > 0, "Not in cooldown");

        // Update rewards to resume accrual
        _cancelUnstaking(tokenId);
    }

    /// @inheritdoc IAppStaking
    function splitPosition(uint256 tokenId, uint256 splitRatio, address to)
        external
        override
        nonReentrant
        returns (uint256 newTokenId)
    {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(to != address(0), "Invalid recipient address");
        require(splitRatio > 0, "Split ratio must be greater than 0");
        require(splitRatio <= 1e18, "Split ratio must be less than or equal to 100%");

        // Collect any pending streaming taxes
        _collectStreamingTaxInternal(tokenId);

        Position storage position = _positions[tokenId];
        require(position.cooldownEnd == 0, "Position is in cooldown");

        // Update rewards for the original position
        _updateReward(tokenId);

        // Create new position
        newTokenId = lastId++;
        _mint(to, newTokenId);

        uint256 splitAmount = position.amount * splitRatio / 1e18;
        uint256 splitDeclaredValue = position.declaredValue * splitRatio / 1e18;

        // Create new position with split values
        _positions[newTokenId] = Position({
            amount: splitAmount,
            declaredValue: splitDeclaredValue,
            rewardPerTokenPaid: rewardPerTokenStored,
            rewards: 0,
            cooldownEnd: 0,
            rewardsUnlockAt: position.rewardsUnlockAt
        });

        // Create streaming tax data for new position
        StreamingTaxData storage originalTaxData = _streamingTaxData[tokenId];
        uint256 newCredit = (originalTaxData.upfrontTaxCredit * splitAmount) / position.amount;
        _streamingTaxData[newTokenId] = StreamingTaxData({
            lastTaxCollectionTime: originalTaxData.lastTaxCollectionTime,
            streamingTaxRate: _calculateStreamingTaxRate(splitDeclaredValue),
            lastAppliedTaxRate: originalTaxData.lastAppliedTaxRate,
            hasPaidUpfrontTax: originalTaxData.hasPaidUpfrontTax,
            upfrontTaxCredit: newCredit
        });
        
        // Update original position's credit
        originalTaxData.upfrontTaxCredit -= newCredit;

        // Inherit buy cooldown from original position
        _buyCooldownEnd[newTokenId] = _buyCooldownEnd[tokenId];

        // Inherit withdraw cooldown from original position
        _withdrawCooldownStart[newTokenId] = _withdrawCooldownStart[tokenId];

        // Update original position
        position.amount -= splitAmount;
        position.declaredValue -= splitDeclaredValue;

        // Update tracking tokens for the new position
        trackingToken.mint(to, splitAmount);
        trackingToken.burn(msg.sender, splitAmount);

        _updateReward(tokenId);
        _updateReward(newTokenId);

        emit PositionSplit(tokenId, newTokenId, msg.sender, to, splitAmount, splitDeclaredValue);
    }

    /// @inheritdoc IAppStaking
    function mergePositions(uint256 tokenId1, uint256 tokenId2)
        external
        override
        nonReentrant
        returns (uint256 mergedTokenId)
    {
        require(tokenId1 != tokenId2, "Token IDs must differ");
        require(ownerOf(tokenId1) == msg.sender && ownerOf(tokenId2) == msg.sender, "Not owner of both tokens");

        // Collect any pending streaming taxes from both positions
        _collectStreamingTaxInternal(tokenId1);
        _collectStreamingTaxInternal(tokenId2);

        // Ensure neither position is in cooldown
        Position storage position1 = _positions[tokenId1];
        Position storage position2 = _positions[tokenId2];
        require(position1.cooldownEnd == 0 && position2.cooldownEnd == 0, "Position in cooldown");

        // Update rewards for both positions so that their rewards are up to date before merging
        _updateReward(tokenId1);
        _updateReward(tokenId2);

        // Aggregate values
        position1.amount += position2.amount;
        position1.declaredValue += position2.declaredValue;
        position1.rewards += position2.rewards;
        // Keep the strictest rewards unlock schedule (the furthest date)
        position1.rewardsUnlockAt = Math.max(position1.rewardsUnlockAt, position2.rewardsUnlockAt);
        
        // Merge streaming tax data
        StreamingTaxData storage taxData1 = _streamingTaxData[tokenId1];
        StreamingTaxData storage taxData2 = _streamingTaxData[tokenId2];
        
        // Keep the earliest tax collection time to ensure no tax is lost
        taxData1.lastTaxCollectionTime = Math.min(taxData1.lastTaxCollectionTime, taxData2.lastTaxCollectionTime);
        // Recalculate streaming tax rate for the merged position
        taxData1.streamingTaxRate = _calculateStreamingTaxRate(position1.declaredValue);
        
        // Merge upfront tax credits
        taxData1.upfrontTaxCredit += taxData2.upfrontTaxCredit;
        // If either position had upfront tax, the merged position should have it
        taxData1.hasPaidUpfrontTax = taxData1.hasPaidUpfrontTax || taxData2.hasPaidUpfrontTax;

        // Inherit cooldowns from the original position
        _buyCooldownEnd[tokenId1] = Math.max(_buyCooldownEnd[tokenId1], _buyCooldownEnd[tokenId2]);
        _withdrawCooldownStart[tokenId1] = Math.max(_withdrawCooldownStart[tokenId1], _withdrawCooldownStart[tokenId2]);

        // Burn the second token and delete its storage
        _burn(tokenId2);
        delete _positions[tokenId2];
        delete _streamingTaxData[tokenId2];
        delete _buyCooldownEnd[tokenId2];
        delete _withdrawCooldownStart[tokenId2];

        // No change in totalStaked or tracking tokens is required since the overall amount stays the same

        // Refresh accounting for the merged position
        _updateReward(tokenId1);

        emit PositionMerged(tokenId1, tokenId2, msg.sender, position1.amount, position1.declaredValue);

        return tokenId1;
    }

    function increaseDeclaredValue(uint256 tokenId, uint256 additionalDeclaredValue)
        external
        nonReentrant
        returns (uint256 taxPaid)
    {
        require(ownerOf(tokenId) != address(0), "Position does not exist");
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(_positions[tokenId].cooldownEnd == 0, "Position is in cooldown");
        require(additionalDeclaredValue > 0, "Additional value must be greater than 0");

        // Collect any pending streaming taxes
        _collectStreamingTaxInternal(tokenId);

        // Update rewards before mutation to keep accounting correct
        _updateReward(tokenId);

        // Increase the declared value for the position
        Position storage position = _positions[tokenId];
        position.declaredValue += additionalDeclaredValue;
        
        // Update streaming tax rate for the new declared value
        uint256 newStreamingTaxRate = _calculateStreamingTaxRate(position.declaredValue);
        StreamingTaxData storage taxData = _streamingTaxData[tokenId];
        uint256 oldRate = taxData.streamingTaxRate;
        taxData.streamingTaxRate = newStreamingTaxRate;
        emit StreamingTaxRateUpdated(tokenId, oldRate, newStreamingTaxRate);

        _updateReward(tokenId);

        emit PositionUpdated(tokenId, ownerOf(tokenId), position.amount, position.declaredValue);
    }

    /// @inheritdoc IAppStaking
    function isInBuyCooldown(uint256 tokenId) external view override returns (bool) {
        return _buyCooldownEnd[tokenId] > 0 && block.timestamp < _buyCooldownEnd[tokenId];
    }

    /// @inheritdoc IAppStaking
    function isInWithdrawCooldown(uint256 tokenId) external view override returns (bool, uint256) {
        return (
            _withdrawCooldownStart[tokenId] > 0 && block.timestamp < _withdrawCooldownStart[tokenId],
            _withdrawCooldownStart[tokenId]
        );
    }

    /// @inheritdoc IAppStaking
    function collectStreamingTax(uint256 tokenId) external override nonReentrant returns (uint256 taxAmount) {
        require(ownerOf(tokenId) != address(0), "Position does not exist");
        
        return _collectStreamingTaxInternal(tokenId);
    }

    /// @inheritdoc IAppStaking
    function calculateStreamingTax(uint256 tokenId) external view override returns (uint256 taxAmount, uint256 timeElapsed) {
        return _calculateStreamingTax(tokenId);
    }

    /// @inheritdoc IAppStaking
    function updateStreamingTaxRate(uint256 tokenId, uint256 newStreamingTaxRate) external override {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(ownerOf(tokenId) != address(0), "Position does not exist");
        
        StreamingTaxData storage taxData = _streamingTaxData[tokenId];
        uint256 oldRate = taxData.streamingTaxRate;
        taxData.streamingTaxRate = newStreamingTaxRate;
        
        emit StreamingTaxRateUpdated(tokenId, oldRate, newStreamingTaxRate);
    }

    /// @inheritdoc IAppStaking
    function collectAllStreamingTaxes(address user) external override nonReentrant returns (uint256 totalTaxCollected) {
        uint256 balance = balanceOf(user);
        
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(user, i);
            uint256 taxAmount = _collectStreamingTaxInternal(tokenId);
            totalTaxCollected += taxAmount;
        }
    }

    /// @inheritdoc IAppStaking
    function setUpfrontTaxCredit(uint256 tokenId, uint256 creditAmount) external override onlyGovernor {
        _setUpfrontTaxCreditInternal(tokenId, creditAmount);
    }

    /// @inheritdoc IAppStaking
    function setUpfrontTaxCreditWithRate(uint256 tokenId, uint256 taxRate) external override onlyGovernor {
        require(ownerOf(tokenId) != address(0), "Position does not exist");
        require(_streamingTaxData[tokenId].upfrontTaxCredit == 0, "Credit already set");
        require(taxRate <= BASIS_POINTS, "Invalid tax rate");
        
        Position storage position = _positions[tokenId];
        uint256 creditAmount = _calculateUpfrontTaxCredit(position.amount, position.declaredValue, taxRate);
        
        _setUpfrontTaxCreditInternal(tokenId, creditAmount);
    }

    /// @inheritdoc IAppStaking
    function setUpfrontTaxCreditsBatch(uint256[] calldata tokenIds, uint256[] calldata creditAmounts) external override onlyGovernor {
        require(tokenIds.length == creditAmounts.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _setUpfrontTaxCreditInternal(tokenIds[i], creditAmounts[i]);
        }
    }

    /// @inheritdoc IAppStaking
    function getUpfrontTaxCredit(uint256 tokenId) external view override returns (uint256) {
        return _streamingTaxData[tokenId].upfrontTaxCredit;
    }

    /// @notice Cancels the unstaking process and resets cooldown variables
    /// @param tokenId The position ID
    function _cancelUnstaking(uint256 tokenId) internal {
        Position storage position = _positions[tokenId];

        if (position.cooldownEnd > 0) {
            _updateReward(tokenId);
            position.cooldownEnd = 0;
            position.rewardsUnlockAt = 0;
            emit UnstakingCancelled(tokenId, msg.sender);
        }

        _updateReward(tokenId);
    }

    /// @notice Claims rewards for a position
    /// @param tokenId The position ID
    /// @return reward The amount of rewards claimed
    function _claimRewards(uint256 tokenId) internal returns (uint256 reward) {
        Position storage position = _positions[tokenId];
        // todo
        // require(block.timestamp >= position.rewardsUnlockAt, "Rewards in cooldown");

        _updateReward(tokenId);

        reward = position.rewards;
        if (reward > 0) {
            address owner = ownerOf(tokenId);
            position.rewards = 0;
            appToken.safeTransfer(owner, reward);
            emit RewardsClaimed(tokenId, owner, reward);
        }
    }

    /// @notice Hooks into ERC721 transfers/mints/burns to keep trackingToken in sync.
    /// @dev When a position NFT moves between addresses, burn tracking tokens from the sender and mint to the receiver
    ///      equivalent to the position.amount. Mints and burns keep their existing behaviour.
    function _update(address to, uint256 tokenId, address auth) internal override returns (address from) {
        // Call parent which performs the actual state update and returns the previous owner (or zero address on mint).
        from = super._update(to, tokenId, auth);

        // Skip for mint (from == 0) and burn (to == 0). Only handle transfers between non-zero addresses.
        if (from != address(0) && to != address(0)) {
            uint256 amt = _positions[tokenId].amount;
            if (amt > 0) {
                // Burn tracking tokens from the sender and mint to the receiver.
                trackingToken.burn(from, amt);
                trackingToken.mint(to, amt);
            }
        }
    }

    /// @notice Distributes the tax to the operations treasury and protocol treasury
    /// @param amount The amount of RZR to distribute
    /// @return taxPaid The total amount of tax paid
    function _distributeTax(uint256 amount) internal returns (uint256 taxPaid) {
        taxPaid = (amount * harbergerTaxRate) / BASIS_POINTS;
        appToken.safeTransfer(burner, taxPaid); // burn the tax so that the floor price increases
    }

    /// @notice Updates the reward for a position
    /// @param tokenId The position ID
    function _updateReward(uint256 tokenId) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();

        if (tokenId > 0) {
            Position storage position = _positions[tokenId];
            position.rewards = earned(tokenId);
            position.rewardPerTokenPaid = rewardPerTokenStored;
        }
    }

    /// @notice Returns the base URI for the NFT metadata
    /// @return The base URI string
    function _baseURI() internal view virtual override returns (string memory) {
        return "https://uri.rezerve.money/api/staking/";
    }

    /// @notice Calculates the streaming tax rate based on the declared value.
    /// @param declaredValue The declared value of the position.
    /// @return streamingTaxRate The streaming tax rate per second.
    function _calculateStreamingTaxRate(uint256 declaredValue) internal view returns (uint256 streamingTaxRate) {
        // Convert annual harberger tax rate to per-second rate
        // harbergerTaxRate is in basis points (e.g., 500 = 5%)
        streamingTaxRate = (declaredValue * harbergerTaxRate) / (BASIS_POINTS * SECONDS_PER_YEAR);
    }

    /// @notice Calculates the streaming tax owed for a position
    /// @param tokenId The position ID
    /// @return taxAmount The amount of tax owed
    /// @return timeElapsed The time elapsed since last collection
    function _calculateStreamingTax(uint256 tokenId) internal view returns (uint256 taxAmount, uint256 timeElapsed) {
        Position storage position = _positions[tokenId];
        StreamingTaxData storage taxData = _streamingTaxData[tokenId];
        
        if (position.amount == 0) {
            return (0, 0);
        }
        
        timeElapsed = block.timestamp - taxData.lastTaxCollectionTime;
        taxAmount = taxData.streamingTaxRate * timeElapsed;
        
        // Cap tax at position amount to prevent over-taxation
        if (taxAmount > position.amount) {
            taxAmount = position.amount;
        }
    }

    /// @notice Internal function to collect streaming tax from a position
    /// @param tokenId The position ID
    /// @return taxAmount The amount of tax collected
    function _collectStreamingTaxInternal(uint256 tokenId) internal returns (uint256 taxAmount) {
        Position storage position = _positions[tokenId];
        StreamingTaxData storage taxData = _streamingTaxData[tokenId];
        (taxAmount, ) = _calculateStreamingTax(tokenId);
        
        if (taxAmount > 0) {
            uint256 actualTaxToCollect = taxAmount;
            uint256 creditUsed = 0;
            
            // Check if position has upfront tax credit to use
            if (taxData.hasPaidUpfrontTax && taxData.upfrontTaxCredit > 0) {
                creditUsed = Math.min(taxAmount, taxData.upfrontTaxCredit);
                taxData.upfrontTaxCredit -= creditUsed;
                actualTaxToCollect = taxAmount - creditUsed;
                
                // Emit credit consumption event
                emit UpfrontTaxCreditConsumed(tokenId, creditUsed, taxData.upfrontTaxCredit);
            }
            
            // Only deduct from position and burn tokens for the actual tax collected
            if (actualTaxToCollect > 0) {
                // Deduct tax from position amount
                position.amount -= actualTaxToCollect;
                totalStaked -= actualTaxToCollect;
                
                // Burn tracking tokens for the taxed amount
                trackingToken.burn(ownerOf(tokenId), actualTaxToCollect);
                
                // Transfer tax to burner
                appToken.safeTransfer(burner, actualTaxToCollect);
            }
            
            // Update last collection time and applied tax rate
            taxData.lastTaxCollectionTime = block.timestamp;
            taxData.lastAppliedTaxRate = taxData.streamingTaxRate;
            
            uint256 timeElapsed = block.timestamp - taxData.lastTaxCollectionTime;
            emit StreamingTaxCollected(tokenId, ownerOf(tokenId), actualTaxToCollect, timeElapsed);
            
            // Return the total tax amount (including credit used)
            return taxAmount;
        }
        
        return 0;
    }

    /// @notice Internal function to set upfront tax credit for a position
    /// @param tokenId The position ID
    /// @param creditAmount The amount of upfront tax credit to set
    function _setUpfrontTaxCreditInternal(uint256 tokenId, uint256 creditAmount) internal {
        require(ownerOf(tokenId) != address(0), "Position does not exist");
        require(_streamingTaxData[tokenId].upfrontTaxCredit == 0, "Credit already set");
        require(creditAmount > 0, "Credit amount must be greater than 0");
        
        StreamingTaxData storage taxData = _streamingTaxData[tokenId];
        taxData.hasPaidUpfrontTax = true;
        taxData.upfrontTaxCredit = creditAmount;
        
        emit UpfrontTaxCreditSet(tokenId, creditAmount);
    }

    /// @notice Calculates the upfront tax credit based on position amount, declared value, and tax rate
    /// @param amount The position amount
    /// @param declaredValue The declared value
    /// @param taxRate The tax rate to use for calculation (in basis points)
    /// @return creditAmount The calculated upfront tax credit
    function _calculateUpfrontTaxCredit(uint256 amount, uint256 declaredValue, uint256 taxRate) internal view returns (uint256 creditAmount) {
        // Calculate the upfront tax that would have been paid
        // This is based on the provided tax rate applied to the declared value
        creditAmount = (declaredValue * taxRate) / BASIS_POINTS;
        
        // Cap the credit at the position amount to prevent over-crediting
        if (creditAmount > amount) {
            creditAmount = amount;
        }
    }

    /// @notice Calculates the upfront tax credit using the current harberger tax rate
    /// @param amount The position amount
    /// @param declaredValue The declared value
    /// @return creditAmount The calculated upfront tax credit
    function _calculateUpfrontTaxCredit(uint256 amount, uint256 declaredValue) internal view returns (uint256 creditAmount) {
        return _calculateUpfrontTaxCredit(amount, declaredValue, harbergerTaxRate);
    }
}
