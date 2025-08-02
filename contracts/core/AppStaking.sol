// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import "../interfaces/IAppStaking.sol";
import "../interfaces/IPermissionedERC20.sol";
import "./AppAccessControlled.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "forge-std/console.sol";

/// @title AppStaking
/// @notice Implementation of the staking system that allows users to stake RZR tokens and earn rewards
/// @dev This contract handles staking positions as NFTs, with harberger tax and reward distribution
contract AppStaking is IAppStaking, AppAccessControlled, ERC721EnumerableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    uint256 public immutable EPOCH_DURATION = 24 hours;

    IERC20 public override appToken;
    IPermissionedERC20 public trackingToken;

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
    address public override burner;

    // State _variables
    mapping(uint256 => Position) private _positions;
    Variables private _variables;

    /// @inheritdoc IAppStaking
    function initialize(address _appToken, address _trackingToken, address _authority, address _burner)
        public
        reinitializer(1)
    {
        if (lastId == 0) lastId = 1;

        __ERC721_init("RZR Staking Position", "RZR-POS");
        __ReentrancyGuard_init();
        __AppAccessControlled_init(_authority);

        require(_appToken != address(0), "Invalid RZR token address");
        require(_trackingToken != address(0), "Invalid tracking token address");

        appToken = IERC20(_appToken);
        trackingToken = IPermissionedERC20(_trackingToken);
        burner = _burner;

        _setVariables(
            Variables({
                harbergerTaxRate: 0.05 ether, // 5%
                resellFeeRate: 0.01 ether, // 1%
                withdrawCooldownPeriod: 3 days, // 3 days
                buyCooldownPeriod: 1 days, // 1 day
                lowDemandThreshold: 0.8e18, // 80%
                highDemandThreshold: 0.95e18, // 95%
                maxDepositFee: 1.5e18 // 150%
            })
        );
    }

    /// @inheritdoc IAppStaking
    function variables() external view override returns (Variables memory) {
        return _variables;
    }

    /// @inheritdoc IAppStaking
    function positions(uint256 tokenId) external view override returns (Position memory) {
        return _positions[tokenId];
    }

    /// @inheritdoc IAppStaking
    function setVariables(Variables memory variables_) external onlyGovernor {
        _setVariables(variables_);
    }

    /// @notice Returns the current demand ratio as basis points (0…BASIS_POINTS)
    function getStakingRatio() public view returns (uint256) {
        uint256 supply = appToken.totalSupply();
        if (supply == 0 || totalStaked == 0) return 0;
        return (totalStaked * 1e18) / supply;
    }

    /// @notice Returns the current deposit fee in basis points (0…maxDepositFee)
    function getDepositFee() public view returns (uint256) {
        uint256 ratio = getStakingRatio();
        if (ratio <= _variables.lowDemandThreshold) return 0;
        if (ratio >= _variables.highDemandThreshold) return _variables.maxDepositFee;

        uint256 span = _variables.highDemandThreshold - _variables.lowDemandThreshold;
        uint256 above = ratio - _variables.lowDemandThreshold;
        return (above * _variables.maxDepositFee) / span;
    }

    /// @notice Gets the buy cooldown end timestamp for a position
    /// @param tokenId The position ID
    /// @return The timestamp when buy cooldown ends, or 0 if not in cooldown
    function getBuyCooldownEnd(uint256 tokenId) external view returns (uint256) {
        return _positions[tokenId].buyCooldownEnd;
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
        uint256 taxRate = _calculateStreamingTaxRate(declaredValue);

        // Charge deposit fee
        taxPaid = _chargeDepositFee(amount);
        amount -= taxPaid;

        // Create new position
        tokenId = lastId++;
        _mint(to, tokenId);

        _positions[tokenId] = Position({
            amount: amount,
            declaredValue: declaredValue,
            rewardPerTokenPaid: rewardPerTokenStored,
            rewards: 0,
            withdrawCooldownEnd: 0,
            withdrawCooldownStart: block.timestamp + minLockDuration,
            buyCooldownEnd: 0,
            taxRate: taxRate,
            taxCredit: 0,
            lastTaxCollectionTime: block.timestamp
        });

        totalStaked += amount;

        // Mint tracking tokens for the staked amount
        trackingToken.mint(to, amount);

        emit PositionCreated(tokenId, to, amount, declaredValue);
    }

    /// @inheritdoc IAppStaking
    function startUnstaking(uint256 tokenId) external override nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(_positions[tokenId].withdrawCooldownEnd == 0, "Already in cooldown");
        require(_positions[tokenId].withdrawCooldownStart <= block.timestamp, "Currently in withdraw cooldown");

        Position storage position = _positions[tokenId];
        _updateReward(tokenId);
        position.withdrawCooldownEnd = block.timestamp + _variables.withdrawCooldownPeriod;

        emit CooldownStarted(tokenId, msg.sender);
    }

    /// @inheritdoc IAppStaking
    function completeUnstaking(uint256 tokenId) external override nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "Not owner");

        Position storage position = _positions[tokenId];
        require(position.withdrawCooldownEnd > 0, "Not in cooldown");
        require(block.timestamp >= position.withdrawCooldownEnd, "Cooldown not finished");

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

        emit PositionUnstaked(tokenId, msg.sender, amount);
    }

    function updateWithdrawCooldown(uint256 tokenId, uint256 newCooldownEnd) external onlyGovernor {
        _positions[tokenId].withdrawCooldownStart = newCooldownEnd;
    }

    function getUpfrontTaxCredit(uint256 tokenId) external view returns (uint256) {
        return _positions[tokenId].taxCredit;
    }

    /// @inheritdoc IAppStaking
    function buyPosition(uint256 tokenId) external override nonReentrant {
        address seller = ownerOf(tokenId);
        require(seller != address(0), "Position does not exist");
        require(seller != msg.sender, "Cannot buy your own position");

        Position storage position = _positions[tokenId];

        // Check if position is in buy cooldown
        require(position.buyCooldownEnd == 0 || block.timestamp >= position.buyCooldownEnd, "Position in buy cooldown");
        uint256 price = position.declaredValue;

        // Calculate resell fee
        uint256 resellFee = (price * _variables.resellFeeRate) / 1e18;
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
        _positions[tokenId].buyCooldownEnd = block.timestamp + _variables.buyCooldownPeriod;

        emit PositionSold(tokenId, seller, msg.sender, price);
    }

    /// @inheritdoc IAppStaking
    function claimRewards(uint256 tokenId) external override nonReentrant returns (uint256 reward) {
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
        returns (uint256 depositFee)
    {
        require(ownerOf(tokenId) != address(0), "Position does not exist");
        require(_positions[tokenId].withdrawCooldownEnd == 0, "Position is in cooldown");
        require(addtionalDeclaredValue > 0 || additionalAmount > 0, "Declared value or amount must be greater than 0");

        _updateReward(tokenId);

        Position storage position = _positions[tokenId];
        address owner = ownerOf(tokenId);

        // Transfer RZR tokens from user
        if (additionalAmount > 0) {
            appToken.safeTransferFrom(msg.sender, address(this), additionalAmount);
            depositFee = _chargeDepositFee(additionalAmount);
            additionalAmount -= depositFee;
        }

        // Update streaming tax rate for the additional declared value
        if (addtionalDeclaredValue > 0) {
            uint256 newStreamingTaxRate = _calculateStreamingTaxRate(position.declaredValue + addtionalDeclaredValue);
            uint256 oldRate = position.taxRate;
            position.taxRate = newStreamingTaxRate;
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
        require(position.withdrawCooldownEnd > 0, "Not in cooldown");

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

        Position storage position = _positions[tokenId];
        require(position.withdrawCooldownEnd == 0, "Position is in cooldown");

        // Update rewards for the original position
        _updateReward(tokenId);

        // Create new position
        newTokenId = lastId++;
        _mint(to, newTokenId);

        uint256 splitAmount = position.amount * splitRatio / 1e18;
        uint256 splitDeclaredValue = position.declaredValue * splitRatio / 1e18;
        uint256 splitTaxRate = position.taxRate * splitRatio / 1e18;
        uint256 splitTaxCredit = position.taxCredit * splitRatio / 1e18;

        // Create new position with split values
        _positions[newTokenId] = Position({
            amount: splitAmount,
            declaredValue: splitDeclaredValue,
            rewardPerTokenPaid: rewardPerTokenStored,
            rewards: 0,
            withdrawCooldownEnd: position.withdrawCooldownEnd,
            withdrawCooldownStart: position.withdrawCooldownStart,
            buyCooldownEnd: position.buyCooldownEnd,
            taxRate: splitTaxRate,
            taxCredit: splitTaxCredit,
            lastTaxCollectionTime: block.timestamp
        });

        // Update original position
        position.amount -= splitAmount;
        position.declaredValue -= splitDeclaredValue;
        position.taxCredit -= splitTaxCredit;
        position.taxRate -= splitTaxRate;

        // Update tracking tokens for the new position
        trackingToken.burn(msg.sender, splitAmount);
        trackingToken.mint(to, splitAmount);

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

        // Ensure neither position is in cooldown
        Position storage position1 = _positions[tokenId1];
        Position storage position2 = _positions[tokenId2];
        require(position1.withdrawCooldownEnd == 0 && position2.withdrawCooldownEnd == 0, "Position in cooldown");

        // Update rewards for both positions so that their rewards are up to date before merging
        _updateReward(tokenId1);
        _updateReward(tokenId2);

        // Aggregate values
        position1.amount += position2.amount;
        position1.buyCooldownEnd = Math.max(position1.buyCooldownEnd, position2.buyCooldownEnd);
        position1.declaredValue += position2.declaredValue;
        position1.lastTaxCollectionTime = Math.min(position1.lastTaxCollectionTime, position2.lastTaxCollectionTime);
        position1.rewards += position2.rewards;
        position1.taxCredit += position2.taxCredit;
        position1.withdrawCooldownStart = Math.max(position1.withdrawCooldownStart, position2.withdrawCooldownStart);

        position1.taxRate = _calculateStreamingTaxRate(position1.declaredValue);

        // Burn the second token and delete its storage
        _burn(tokenId2);
        delete _positions[tokenId2];

        // Refresh accounting for the merged position
        _updateReward(tokenId1);

        emit PositionMerged(tokenId1, tokenId2, msg.sender, position1.amount, position1.declaredValue);

        return tokenId1;
    }

    /// @inheritdoc IAppStaking
    function collectStreamingTax(uint256 tokenId) external override nonReentrant returns (uint256 taxAmount) {
        require(ownerOf(tokenId) != address(0), "Position does not exist");
        return _collectStreamingTaxInternal(tokenId);
    }

    /// @inheritdoc IAppStaking
    function calculateStreamingTax(uint256 tokenId) external view override returns (uint256 taxAmount) {
        Position storage position = _positions[tokenId];
        return _calculateStreamingTax(position);
    }

    /// @inheritdoc IAppStaking
    function setUpfrontTaxCredit(uint256 tokenId, uint256 creditAmount) external override onlyGovernor {
        _setUpfrontTaxCreditInternal(tokenId, creditAmount);
    }

    /// @notice Cancels the unstaking process and resets cooldown _variables
    /// @param tokenId The position ID
    function _cancelUnstaking(uint256 tokenId) internal {
        Position storage position = _positions[tokenId];

        if (position.withdrawCooldownEnd > 0) {
            _updateReward(tokenId);
            position.withdrawCooldownEnd = 0;
            emit UnstakingCancelled(tokenId, msg.sender);
        }

        _updateReward(tokenId);
    }

    /// @notice Claims rewards for a position
    /// @param tokenId The position ID
    /// @return reward The amount of rewards claimed
    function _claimRewards(uint256 tokenId) internal returns (uint256 reward) {
        Position storage position = _positions[tokenId];
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

    /// @notice Distributes the deposit fee to the operations treasury and protocol treasury
    /// @param amount The amount of RZR to distribute
    /// @return depositFee The total amount of deposit fee paid
    function _chargeDepositFee(uint256 amount) internal returns (uint256 depositFee) {
        depositFee = (amount * getDepositFee()) / 1e18;
        if (depositFee > 0) appToken.safeTransfer(burner, depositFee);
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
            _collectStreamingTaxInternal(tokenId);
        }
    }

    /// @notice Returns the base URI for the NFT metadata
    /// @return baseURI The base URI string
    function _baseURI() internal view virtual override returns (string memory baseURI) {
        return "https://uri.rezerve.money/api/staking/";
    }

    /// @notice Calculates the streaming tax rate based on the declared value.
    /// @param declaredValue The declared value of the position.
    /// @return taxRate The streaming tax rate per second.
    function _calculateStreamingTaxRate(uint256 declaredValue) internal view returns (uint256 taxRate) {
        taxRate = (declaredValue * _variables.harbergerTaxRate) / (1e18 * 365 days);
    }

    /// @notice Calculates the streaming tax owed for a position
    /// @param position The position to calculate tax for
    /// @return taxAmount The amount of tax owed
    function _calculateStreamingTax(Position storage position) internal view returns (uint256 taxAmount) {
        if (position.amount == 0) return 0;
        uint256 timeElapsed = block.timestamp - position.lastTaxCollectionTime;
        taxAmount = position.taxRate * timeElapsed;

        // Cap tax at position amount to prevent over-taxation
        if (taxAmount > position.amount) taxAmount = position.amount;
    }

    /// @notice Internal function to collect streaming tax from a position
    /// @param tokenId The position ID
    /// @return taxAmount The amount of tax collected
    function _collectStreamingTaxInternal(uint256 tokenId) internal returns (uint256 taxAmount) {
        Position storage position = _positions[tokenId];
        taxAmount = _calculateStreamingTax(position);
        if (taxAmount == 0) return 0;

        uint256 actualTaxToCollect = taxAmount;
        uint256 creditUsed = 0;

        // Check if position has upfront tax credit to use
        if (position.taxCredit > 0) {
            creditUsed = Math.min(taxAmount, position.taxCredit);
            position.taxCredit -= creditUsed;
            actualTaxToCollect -= creditUsed;

            // Emit credit consumption event
            emit UpfrontTaxCreditConsumed(tokenId, creditUsed, position.taxCredit);
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
        position.lastTaxCollectionTime = block.timestamp;

        uint256 timeElapsed = block.timestamp - position.lastTaxCollectionTime;
        emit StreamingTaxCollected(tokenId, taxAmount, timeElapsed);

        // Return the total tax amount (including credit used)
        return taxAmount;
    }

    /// @notice Internal function to set upfront tax credit for a position
    /// @param tokenId The position ID
    /// @param creditAmount The amount of upfront tax credit to set
    function _setUpfrontTaxCreditInternal(uint256 tokenId, uint256 creditAmount) internal {
        require(ownerOf(tokenId) != address(0), "Position does not exist");
        require(_positions[tokenId].taxCredit == 0, "Credit already set");
        require(creditAmount > 0, "Credit amount must be greater than 0");

        Position storage position = _positions[tokenId];
        position.taxCredit = creditAmount;

        emit UpfrontTaxCreditSet(tokenId, creditAmount);
    }

    /// @notice Calculates the upfront tax credit based on position amount, declared value, and tax rate
    /// @param amount The position amount
    /// @param declaredValue The declared value
    /// @param taxRate The tax rate to use for calculation (in basis points)
    /// @return creditAmount The calculated upfront tax credit
    function _calculateUpfrontTaxCredit(uint256 amount, uint256 declaredValue, uint256 taxRate)
        internal
        pure
        returns (uint256 creditAmount)
    {
        // Calculate the upfront tax that would have been paid
        // This is based on the provided tax rate applied to the declared value
        creditAmount = (declaredValue * taxRate) / 1e18;

        // Cap the credit at the position amount to prevent over-crediting
        if (creditAmount > amount) creditAmount = amount;
    }

    function _setVariables(Variables memory variables_) internal {
        _variables = variables_;
        require(_variables.buyCooldownPeriod > 0, "Invalid buy cooldown period");
        emit VariablesUpdated(variables_);
    }

    /// @notice Calculates the upfront tax credit using the current harberger tax rate
    /// @param amount The position amount
    /// @param declaredValue The declared value
    /// @return creditAmount The calculated upfront tax credit
    function _calculateUpfrontTaxCredit(uint256 amount, uint256 declaredValue)
        internal
        view
        returns (uint256 creditAmount)
    {
        return _calculateUpfrontTaxCredit(amount, declaredValue, _variables.harbergerTaxRate);
    }
}
