// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "../interfaces/IApp.sol";
import "../interfaces/IOracleV2.sol";
import "../interfaces/IPermissionedERC20.sol";
import "../interfaces/IAppConvertibles.sol";
import "./AppAccessControlled.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/// @title RZR Convertibles
/// @author RZR Protocol
/// @notice Implementation of the convertibles system that allows users to purchase convertibles with quote tokens
/// @dev This contract handles convertibles creation, management, and NFT-based convertibles positions
contract AppConvertibles is
    IAppConvertibles,
    AppAccessControlled,
    ERC721EnumerableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    /// @inheritdoc IAppConvertibles
    uint256 public immutable MAX_LOCK_DURATION = 4 * 365 days;

    /// @inheritdoc IAppConvertibles
    uint256 public immutable MIN_LOCK_DURATION = 30 days;

    /// @inheritdoc IAppConvertibles
    uint256 public immutable MAX_ORACLE_STALENESS = 1 days;

    /// @inheritdoc IAppConvertibles
    IERC4626 public loanToken;

    /// @inheritdoc IAppConvertibles
    IApp public rzr;

    /// @inheritdoc IAppConvertibles
    IPermissionedERC20 public loanTrackingToken;

    /// @inheritdoc IAppConvertibles
    IPermissionedERC20 public rzrTrackingToken;

    /// @inheritdoc IAppConvertibles
    IOracleV2 public oracle;

    /// @inheritdoc IAppConvertibles
    IOracleV2 public twapOracle;

    /// @inheritdoc IAppConvertibles
    uint256 public lastId;

    /// @inheritdoc IAppConvertibles
    uint256 public totalStaked;

    /// @inheritdoc IAppConvertibles
    uint256 public totalConvertible;

    /// @inheritdoc IAppConvertibles
    uint256 public loanTokenDecimals;

    mapping(uint256 tokenId => Position) private _positions;

    Variables private _vars;

    /// @inheritdoc IAppConvertibles
    function initialize(
        address _loanToken,
        address _rzr,
        address _debtTrackingToken,
        address _conversionTrackingToken,
        address _oracle,
        address _twapOracle,
        address _authority,
        Variables memory __vars
    ) external reinitializer(2) {
        __ERC721_init("RZR Convertibles", "cRZR-POS");
        __ReentrancyGuard_init();
        __AppAccessControlled_init(_authority);
        loanToken = IERC4626(_loanToken);
        rzr = IApp(_rzr);
        loanTrackingToken = IPermissionedERC20(_debtTrackingToken);
        rzrTrackingToken = IPermissionedERC20(_conversionTrackingToken);
        oracle = IOracleV2(_oracle);
        twapOracle = IOracleV2(_twapOracle);

        loanTokenDecimals = 10 ** (18 - loanToken.decimals());

        _vars = __vars;

        // check if the price is valid
        require(_getPrice(1e18) > 0, "Invalid price");
    }

    modifier onlyOwnerOrAuthorized(uint256 tokenId) {
        require(
            ownerOf(tokenId) == msg.sender || isApprovedForAll(ownerOf(tokenId), msg.sender), "Not owner or approved"
        );
        _;
    }

    /// @inheritdoc IAppConvertibles
    function updateOracle(address _oracle, address _twapOracle) external onlyGovernor {
        oracle = IOracleV2(_oracle);
        twapOracle = IOracleV2(_twapOracle);
    }

    /// @inheritdoc IAppConvertibles
    function positions(uint256 tokenId) public view returns (Position memory position) {
        position = _positions[tokenId];
    }

    /// @inheritdoc IAppConvertibles
    function variables() public view returns (Variables memory vars) {
        vars = _vars;
    }

    /// @inheritdoc IAppConvertibles
    function setVariables(
        uint256 _minConversionPremium,
        uint256 _maxConversionPremium,
        uint256 _minFixedInterestRate,
        uint256 _maxFixedInterestRate,
        uint256 _supplyCap,
        uint256 _debtCap
    ) external onlyGovernor {
        _vars.minConversionPremium = _minConversionPremium;
        _vars.maxConversionPremium = _maxConversionPremium;
        _vars.minFixedInterestRate = _minFixedInterestRate;
        _vars.maxFixedInterestRate = _maxFixedInterestRate;
        _vars.supplyCap = _supplyCap;
        _vars.debtCap = _debtCap;
        emit VariablesUpdated(
            _minConversionPremium,
            _maxConversionPremium,
            _minFixedInterestRate,
            _maxFixedInterestRate,
            _supplyCap,
            _debtCap
        );
    }

    /// @inheritdoc IAppConvertibles
    function stake(uint256 amount, uint256 lockDuration, address receiver)
        external
        nonReentrant
        returns (
            uint256 tokenId,
            uint256 conversionPrice,
            uint256 conversionAmount,
            uint256 fixedInterestRate,
            uint256 fixedInterestRateAmount
        )
    {
        uint256 price = _getPrice(amount);

        require(amount > 0, "Invalid amount");
        require(lockDuration >= MIN_LOCK_DURATION && lockDuration <= MAX_LOCK_DURATION, "Invalid lock duration");

        (conversionPrice, conversionAmount, fixedInterestRate) = getOfferings(amount, lockDuration);

        fixedInterestRateAmount = 0;

        loanToken.transferFrom(msg.sender, address(this), amount);
        _positions[++lastId] = Position({
            amountStaked: amount,
            amountConvertible: conversionAmount,
            fixedInterestRate: fixedInterestRate,
            fixedInterestClaimed: 0,
            lockDuration: lockDuration,
            lockStartTime: block.timestamp,
            priceConversion: conversionPrice,
            priceEntry: price
        });

        _mint(receiver, lastId);

        totalStaked += amount;
        totalConvertible += conversionAmount;

        require(totalStaked <= _vars.debtCap || _vars.debtCap == 0, "Debt cap reached");
        require(totalConvertible <= _vars.supplyCap || _vars.supplyCap == 0, "Supply cap reached");

        loanTrackingToken.mint(receiver, amount);
        rzrTrackingToken.mint(receiver, conversionAmount);

        emit Staked(receiver, lastId, amount, conversionAmount, lockDuration, price, conversionPrice, fixedInterestRate);

        return (lastId, conversionPrice, conversionAmount, fixedInterestRate, fixedInterestRateAmount);
    }

    /// @inheritdoc IAppConvertibles
    function convert(uint256 tokenId) external nonReentrant onlyOwnerOrAuthorized(tokenId) {
        Position storage position = _positions[tokenId];
        uint256 twapPrice = _getTwapPrice();

        require(position.amountStaked > 0, "Position does not exist");
        require(block.timestamp - position.lockStartTime >= 7 days, "Not enough time passed");
        require(twapPrice > position.priceConversion, "Invalid conversion price");

        uint256 amountStaked = position.amountStaked;
        uint256 amountConvertible = position.amountConvertible;

        _burn(tokenId);
        delete _positions[tokenId];

        totalStaked -= amountStaked;
        totalConvertible -= amountConvertible;

        // transfer the loan tokens to the treasury so that we can clear out our debt
        loanToken.transfer(address(authority.treasury()), amountStaked);

        // burn the loan tracking tokens
        loanTrackingToken.burn(msg.sender, amountStaked);

        // convert the debt to rzr
        rzr.mint(msg.sender, amountConvertible);
        rzrTrackingToken.burn(msg.sender, amountConvertible);
        emit Converted(msg.sender, tokenId, amountStaked, amountConvertible, twapPrice);
    }

    /// @inheritdoc IAppConvertibles
    function redeem(uint256 tokenId) external nonReentrant onlyOwnerOrAuthorized(tokenId) {
        Position storage position = _positions[tokenId];

        require(block.timestamp - position.lockStartTime >= position.lockDuration, "Not enough time passed");
        require(position.amountStaked > 0, "Position does not exist");

        uint256 amountStaked = position.amountStaked;
        uint256 amountConvertible = position.amountConvertible;

        // we assume that the contract always has enough shares to cover the interest
        uint256 interestAccumulated = _interestAccumulated(
            amountStaked, position.fixedInterestRate, block.timestamp, position.lockStartTime, position.lockDuration
        );

        _burn(tokenId);
        delete _positions[tokenId];

        totalStaked -= amountStaked;
        totalConvertible -= amountConvertible;

        // clear out the debt and send it back to the user along with the fixed interest
        loanToken.transfer(msg.sender, amountStaked + interestAccumulated);
        loanTrackingToken.burn(msg.sender, amountStaked);

        rzrTrackingToken.burn(msg.sender, amountConvertible);
        emit Redeemed(msg.sender, tokenId, amountStaked, amountConvertible, interestAccumulated);
    }

    /// @inheritdoc IAppConvertibles
    function split(uint256 tokenId, uint256 percentageE18) external nonReentrant onlyOwnerOrAuthorized(tokenId) {
        require(percentageE18 > 0 && percentageE18 < 1e18, "Invalid percentage");

        Position storage position = _positions[tokenId];
        require(position.amountStaked > 0, "Position does not exist");

        // Calculate split amounts
        uint256 splitAmountStaked = position.amountStaked * percentageE18 / 1e18;
        uint256 splitAmountConvertible = position.amountConvertible * percentageE18 / 1e18;
        uint256 fixedInterestClaimed = position.fixedInterestClaimed * percentageE18 / 1e18;

        // Ensure minimum amounts for both positions
        require(splitAmountStaked > 0, "Split amount too small");
        require(position.amountStaked - splitAmountStaked > 0, "Remaining amount too small");

        // Update original position
        position.amountStaked -= splitAmountStaked;
        position.amountConvertible -= splitAmountConvertible;
        position.fixedInterestClaimed -= fixedInterestClaimed;

        // Create new position
        uint256 newTokenId = ++lastId;
        _positions[newTokenId] = Position({
            amountStaked: splitAmountStaked,
            amountConvertible: splitAmountConvertible,
            fixedInterestRate: position.fixedInterestRate,
            fixedInterestClaimed: fixedInterestClaimed,
            lockDuration: position.lockDuration,
            lockStartTime: position.lockStartTime,
            priceConversion: position.priceConversion,
            priceEntry: position.priceEntry
        });

        // Mint new NFT
        _mint(msg.sender, newTokenId);

        emit PositionSplit(
            msg.sender,
            tokenId,
            newTokenId,
            position.amountStaked + splitAmountStaked,
            splitAmountStaked,
            position.amountConvertible + splitAmountConvertible,
            splitAmountConvertible,
            percentageE18
        );
    }

    /// @inheritdoc IAppConvertibles
    function claimInterest(uint256 tokenId)
        external
        nonReentrant
        returns (uint256 interestClaimed, uint256 totalInterestClaimed)
    {
        Position storage position = _positions[tokenId];
        (interestClaimed, totalInterestClaimed) = _claimableInterest(tokenId);
        require(interestClaimed > 0, "No interest to claim");
        position.fixedInterestClaimed = totalInterestClaimed;

        loanToken.transfer(ownerOf(tokenId), interestClaimed);
        emit InterestClaimed(msg.sender, tokenId, interestClaimed);
    }

    /// @inheritdoc IAppConvertibles
    function claimableInterest(uint256 tokenId)
        public
        view
        returns (uint256 interestClaimable, uint256 totalInterestClaimed)
    {
        (interestClaimable, totalInterestClaimed) = _claimableInterest(tokenId);
    }

    /// @inheritdoc IAppConvertibles
    function getOfferings(uint256 amountLoan, uint256 lockDuration)
        public
        view
        returns (uint256 conversionPrice, uint256 conversionAmount, uint256 fixedInterestRate)
    {
        uint256 amountLoanScaled = amountLoan * loanTokenDecimals;
        uint256 price = _getPrice(1e18);

        // calculate the conversion premium; longer duration means lower premium
        uint256 premium =
            _scale(_vars.maxConversionPremium, _vars.minConversionPremium, MAX_LOCK_DURATION - lockDuration);
        conversionPrice = price * (1e18 + premium) / 1e18;
        conversionAmount = amountLoanScaled * 1e18 / conversionPrice;

        // calculate the fixed interest rate; longer duration means higher fixed interest rate
        fixedInterestRate = _scale(_vars.maxFixedInterestRate, _vars.minFixedInterestRate, lockDuration);
    }

    /// @inheritdoc IAppConvertibles
    function execute(address target, bytes memory data) external onlyGovernor {
        (bool success,) = target.call(data);
        require(success, "Execute failed");
    }

    function _claimableInterest(uint256 tokenId)
        internal
        view
        returns (uint256 interestClaimable, uint256 totalInterestClaimed)
    {
        Position storage position = _positions[tokenId];
        require(position.amountStaked > 0, "Position does not exist");

        totalInterestClaimed = _interestAccumulated(
            position.amountStaked,
            position.fixedInterestRate,
            block.timestamp,
            position.lockStartTime,
            position.lockDuration
        );

        interestClaimable = totalInterestClaimed - position.fixedInterestClaimed;
    }

    /// @notice Calculates the interest accumulated on a position
    /// @param amount The amount of loan tokens staked
    /// @param interestRatePerYear The interest rate per year
    /// @param lockStartTime The timestamp when the lock period started
    /// @return interestInShares The interest accumulated in loan tokens
    function _interestAccumulated(
        uint256 amount,
        uint256 interestRatePerYear,
        uint256 currentTime,
        uint256 lockStartTime,
        uint256 lockDuration
    ) internal view returns (uint256 interestInShares) {
        uint256 interestEarnedPerSecond = amount * interestRatePerYear / 1e18 / 365 days;
        uint256 timeElapsed = Math.min(currentTime - lockStartTime, lockDuration);
        uint256 interest = interestEarnedPerSecond * timeElapsed;
        interestInShares = loanToken.convertToShares(interest);
    }

    /// @notice Returns the base URI for the NFT metadata
    /// @return baseURI The base URI string
    function _baseURI() internal view virtual override returns (string memory baseURI) {
        return "https://uri.rezerve.money/api/convertibles/";
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address from) {
        // Call parent which performs the actual state update and returns the previous owner (or zero address on mint).
        from = super._update(to, tokenId, auth);

        // Skip for mint (from == 0) and burn (to == 0). Only handle transfers between non-zero addresses.
        if (from != address(0) && to != address(0)) {
            // Burn tracking tokens from the sender and mint to the receiver.
            uint256 amtStaked = _positions[tokenId].amountStaked;
            uint256 amtConvertible = _positions[tokenId].amountConvertible;
            if (amtStaked > 0) loanTrackingToken.transferPermissioned(from, to, amtStaked);
            if (amtConvertible > 0) rzrTrackingToken.transferPermissioned(from, to, amtConvertible);
            emit PositionTransferred(from, to, tokenId, amtStaked, amtConvertible);
        }
    }

    function _getPrice(uint256 amount) internal view returns (uint256 price) {
        (uint256 rzrAssets, uint256 usdAssets, uint256 lastUpdatedAt) = oracle.getPriceForAmount(amount);
        require(rzrAssets == 0 && usdAssets > 0, "Invalid price");
        require(lastUpdatedAt > block.timestamp - MAX_ORACLE_STALENESS, "Stale price");
        price = usdAssets;
    }

    function _getTwapPrice() internal view returns (uint256 price) {
        (uint256 rzrAssets, uint256 usdAssets, uint256 lastUpdatedAt) = twapOracle.getPriceForAmount(1e18);
        require(rzrAssets == 0 && usdAssets > 0, "Invalid price");
        require(lastUpdatedAt > block.timestamp - MAX_ORACLE_STALENESS, "Stale price");
        price = usdAssets;
    }

    /// @notice Scales a value between a minimum and maximum value based on a lock duration
    /// @param max The maximum value
    /// @param min The minimum value
    /// @param lockDuration The lock duration
    /// @return value The scaled value
    function _scale(uint256 max, uint256 min, uint256 lockDuration) internal pure returns (uint256 value) {
        value = min + (max - min) * lockDuration / MAX_LOCK_DURATION;
    }
}
