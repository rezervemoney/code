// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "../interfaces/IApp.sol";
import "../interfaces/IAppConvertibles.sol";
import "../interfaces/IAppOracle.sol";
import "../interfaces/IPermissionedERC20.sol";
import "../interfaces/IPermissionedERC20Factory.sol";
import "./AppAccessControlled.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
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
    using SafeERC20 for IERC4626;

    /// @inheritdoc IAppConvertibles
    uint256 public immutable MAX_LOCK_DURATION = 4 * 365 days;

    /// @inheritdoc IAppConvertibles
    uint256 public immutable MIN_LOCK_DURATION = 30 days;

    /// @inheritdoc IAppConvertibles
    uint256 public immutable MAX_ORACLE_STALENESS = 1 days;

    /// @inheritdoc IAppConvertibles
    uint256 public immutable MIN_BOND_DURATION = 7 days;

    /// @inheritdoc IAppConvertibles
    IApp public rzr;

    /// @inheritdoc IAppConvertibles
    IPermissionedERC20 public stakingPowerToken;

    /// @inheritdoc IAppConvertibles
    IPermissionedERC20 public rzrTrackingToken;

    /// @inheritdoc IAppConvertibles
    IAppOracle public oracle;

    /// @inheritdoc IAppConvertibles
    IOracleV2 public spotOracle;

    /// @inheritdoc IAppConvertibles
    IOracleV2 public twapOracle;

    /// @inheritdoc IAppConvertibles
    uint256 public lastId;

    /// @inheritdoc IAppConvertibles
    uint256 public totalConvertible;

    /// @dev Mapping of tokenId to position
    mapping(uint256 tokenId => Position) private _positions;

    /// @dev Mapping of loan token to variables
    mapping(IERC20 loanToken => Variables variables) private _variables;

    /// @inheritdoc IAppConvertibles
    IPermissionedERC20Factory public factory;

    /// @inheritdoc IAppConvertibles
    function initialize(
        address _rzr,
        address _oracle,
        address _spotOracle,
        address _twapOracle,
        address _authority,
        address _factory
    ) external initializer {
        __ERC721_init("RZR Convertibles", "cRZR-POS");
        __ReentrancyGuard_init();
        __AppAccessControlled_init(_authority);
        rzr = IApp(_rzr);
        oracle = IAppOracle(_oracle);
        spotOracle = IOracleV2(_spotOracle);
        twapOracle = IOracleV2(_twapOracle);
        factory = IPermissionedERC20Factory(_factory);

        if (address(stakingPowerToken) == address(0)) {
            stakingPowerToken = factory.createPermissionedERC20("Staking Power", "RZRsp", 18);
        }
        if (address(rzrTrackingToken) == address(0)) {
            rzrTrackingToken = factory.createPermissionedERC20("RZR Convertible", "cRZR", 18);
        }
    }

    modifier onlyOwnerOrAuthorized(uint256 tokenId) {
        _onlyOwnerOrAuthorized(tokenId);
        _;
    }

    /// @inheritdoc IAppConvertibles
    function enableToken(
        IERC20Metadata loanToken,
        uint256 _minConversionPremium,
        uint256 _maxConversionPremium,
        uint256 _minFixedInterestRate,
        uint256 _maxFixedInterestRate,
        uint256 _debtCap
    ) external onlyGovernor {
        require(_variables[loanToken].minConversionPremium == 0, "Token already enabled");
        require(loanToken.decimals() <= 18, "Invalid decimals");

        string memory name = string.concat("Staked ", IERC20Metadata(address(loanToken)).name());
        string memory symbol = string.concat("stk", IERC20Metadata(address(loanToken)).symbol());
        uint8 decimals = IERC20Metadata(address(loanToken)).decimals();

        Variables memory _vars = Variables({
            trackingToken: factory.createPermissionedERC20(name, symbol, decimals),
            minConversionPremium: _minConversionPremium,
            maxConversionPremium: _maxConversionPremium,
            minFixedInterestRate: _minFixedInterestRate,
            maxFixedInterestRate: _maxFixedInterestRate,
            debtCap: _debtCap
        });
        _variables[loanToken] = _vars;
        emit TokenEnabled(address(loanToken));
    }

    /// @inheritdoc IAppConvertibles
    function positions(uint256 tokenId) public view returns (Position memory position) {
        position = _positions[tokenId];
    }

    /// @inheritdoc IAppConvertibles
    function variables(IERC20 _loanToken) public view returns (Variables memory vars) {
        vars = _variables[_loanToken];
    }

    /// @inheritdoc IAppConvertibles
    function setVariables(
        IERC20 _loanToken,
        uint256 _minConversionPremium,
        uint256 _maxConversionPremium,
        uint256 _minFixedInterestRate,
        uint256 _maxFixedInterestRate,
        uint256 _debtCap
    ) external onlyGovernor {
        Variables memory vars = Variables({
            trackingToken: _variables[_loanToken].trackingToken,
            minConversionPremium: _minConversionPremium,
            maxConversionPremium: _maxConversionPremium,
            minFixedInterestRate: _minFixedInterestRate,
            maxFixedInterestRate: _maxFixedInterestRate,
            debtCap: _debtCap
        });
        _variables[_loanToken] = vars;
        emit VariablesUpdated(
            _loanToken,
            vars.minConversionPremium,
            vars.maxConversionPremium,
            vars.minFixedInterestRate,
            vars.maxFixedInterestRate,
            vars.debtCap
        );
    }

    /// @inheritdoc IAppConvertibles
    function stake(IERC20 loanToken, uint256 amount, uint256 lockDuration, address receiver)
        external
        nonReentrant
        returns (
            uint256 tokenId,
            uint256 conversionPrice,
            uint256 conversionAmount,
            uint256 fixedInterestRate,
            uint256 fixedInterestRateAmount,
            uint256 stakingPower
        )
    {
        uint256 priceRzrToUsd = _getSpotPrice();
        Variables memory _vars = _variables[loanToken];

        require(amount > 0, "Invalid amount");
        require(lockDuration >= MIN_LOCK_DURATION && lockDuration <= MAX_LOCK_DURATION, "Invalid lock duration");

        (conversionPrice, conversionAmount, fixedInterestRate) = getOfferings(loanToken, amount, lockDuration);

        fixedInterestRateAmount = 0;
        stakingPower = _getStakingPower(loanToken, amount, lockDuration);

        loanToken.safeTransferFrom(msg.sender, address(this), amount);
        _positions[++lastId] = Position({
            asset: IERC4626(address(loanToken)),
            stakingPower: stakingPower,
            amountStaked: amount,
            amountConvertible: conversionAmount,
            fixedInterestRate: fixedInterestRate,
            fixedInterestClaimed: 0,
            lockDuration: lockDuration,
            lockStartTime: block.timestamp,
            priceConversion: conversionPrice,
            priceEntry: priceRzrToUsd
        });

        _mint(receiver, lastId);

        totalConvertible += conversionAmount;
        _vars.trackingToken.mint(receiver, amount);
        stakingPowerToken.mint(receiver, stakingPower);
        rzrTrackingToken.mint(receiver, conversionAmount);

        uint256 _totalStaked = _vars.trackingToken.totalSupply();
        require(_totalStaked <= _vars.debtCap || _vars.debtCap == 0, "Debt cap reached");

        emit Staked(
            receiver, lastId, amount, conversionAmount, lockDuration, priceRzrToUsd, conversionPrice, fixedInterestRate
        );

        return (lastId, conversionPrice, conversionAmount, fixedInterestRate, fixedInterestRateAmount, stakingPower);
    }

    /// @inheritdoc IAppConvertibles
    function convert(uint256 tokenId) external nonReentrant onlyOwnerOrAuthorized(tokenId) {
        Position storage position = _positions[tokenId];
        uint256 twapPrice = _getTwapPrice();

        require(position.amountStaked > 0, "Position does not exist");
        require(block.timestamp - position.lockStartTime >= MIN_BOND_DURATION, "Not enough time passed");
        require(twapPrice > position.priceConversion, "Invalid conversion price");

        uint256 stakingPower = position.stakingPower;
        uint256 amountConvertible = position.amountConvertible;
        uint256 amountStaked = position.amountStaked;
        IERC20 asset = position.asset;
        address owner = ownerOf(tokenId);

        _burn(tokenId);
        delete _positions[tokenId];

        totalConvertible -= amountConvertible;

        // transfer the loan tokens to the treasury so that we can clear out our debt
        asset.safeTransfer(address(authority.treasury()), amountStaked);

        // burn the loan tracking tokens
        stakingPowerToken.burn(owner, stakingPower);
        _variables[asset].trackingToken.burn(owner, amountStaked);

        // convert the debt to rzr
        rzr.mint(owner, amountConvertible);
        rzrTrackingToken.burn(owner, amountConvertible);
        emit Converted(owner, tokenId, amountStaked, amountConvertible, twapPrice);
    }

    /// @inheritdoc IAppConvertibles
    function redeem(uint256 tokenId, bool unwrap4626) external nonReentrant onlyOwnerOrAuthorized(tokenId) {
        Position storage position = _positions[tokenId];

        require(block.timestamp - position.lockStartTime >= position.lockDuration, "Not enough time passed");
        require(position.amountStaked > 0, "Position does not exist");

        uint256 amountStaked = position.amountStaked;
        uint256 amountConvertible = position.amountConvertible;
        uint256 stakingPower = position.stakingPower;
        IERC4626 asset = position.asset;
        address owner = ownerOf(tokenId);

        // we assume that the contract always has enough shares to cover the interest
        uint256 interestAccumulated = _interestAccumulated(
            amountStaked, position.fixedInterestRate, block.timestamp, position.lockStartTime, position.lockDuration
        );

        _burn(tokenId);
        delete _positions[tokenId];

        totalConvertible -= amountConvertible;

        // clear out the debt and send it back to the user along with the fixed interest
        if (unwrap4626) asset.withdraw(amountStaked + interestAccumulated, owner, address(this));
        else asset.safeTransfer(owner, amountStaked + interestAccumulated);

        stakingPowerToken.burn(owner, stakingPower);
        _variables[asset].trackingToken.burn(owner, amountStaked);

        rzrTrackingToken.burn(owner, amountConvertible);
        emit Redeemed(owner, tokenId, amountStaked, amountConvertible, interestAccumulated);
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
        uint256 stakingPower = position.stakingPower * percentageE18 / 1e18;

        // Ensure minimum amounts for both positions
        require(splitAmountStaked > 0, "Split amount too small");
        require(position.amountStaked - splitAmountStaked > 0, "Remaining amount too small");

        // Update original position
        position.amountStaked -= splitAmountStaked;
        position.amountConvertible -= splitAmountConvertible;
        position.fixedInterestClaimed -= fixedInterestClaimed;
        position.stakingPower -= stakingPower;

        // Create new position
        uint256 newTokenId = ++lastId;
        _positions[newTokenId] = Position({
            asset: position.asset,
            stakingPower: stakingPower,
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
    function claimInterest(uint256 tokenId, bool unwrap4626)
        external
        nonReentrant
        returns (uint256 interestClaimed, uint256 totalInterestClaimed)
    {
        Position storage position = _positions[tokenId];
        (interestClaimed, totalInterestClaimed) = _claimableInterest(tokenId);
        require(interestClaimed > 0, "No interest to claim");
        position.fixedInterestClaimed = totalInterestClaimed;

        if (unwrap4626) position.asset.withdraw(interestClaimed, ownerOf(tokenId), address(this));
        else position.asset.transfer(ownerOf(tokenId), interestClaimed);

        emit InterestClaimed(msg.sender, tokenId, interestClaimed);
    }

    /// @inheritdoc IAppConvertibles
    function totalStaked(address loanToken) external view returns (uint256) {
        return _variables[IERC20(loanToken)].trackingToken.totalSupply();
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
    function getOfferings(IERC20 loanToken, uint256 amountLoan, uint256 lockDuration)
        public
        view
        returns (uint256 conversionPrice, uint256 conversionAmount, uint256 fixedInterestRate)
    {
        uint256 priceLoanToUsd = _getPrice(loanToken);
        uint256 priceUsdToRzr = _getSpotPrice();

        // get the USD value of the loan token amount
        uint256 amountLoanScaled = _scaleAmount(loanToken, amountLoan);
        uint256 amountLoanScaledToUsd = amountLoanScaled * priceLoanToUsd / 1e18;
        Variables memory _vars = _variables[loanToken];

        // calculate the conversion premium; longer duration means lower premium
        uint256 premium =
            _scale(_vars.maxConversionPremium, _vars.minConversionPremium, MAX_LOCK_DURATION - lockDuration);

        // calculate the conversion price in RZR/USD terms
        conversionPrice = priceUsdToRzr * (1e18 + premium) / 1e18;

        // based on the dollar value of the loan token amount, calculate the conversion amount in RZR terms
        conversionAmount = amountLoanScaledToUsd * 1e18 / conversionPrice;

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
    /// @return interest The interest accumulated in loan tokens
    function _interestAccumulated(
        uint256 amount,
        uint256 interestRatePerYear,
        uint256 currentTime,
        uint256 lockStartTime,
        uint256 lockDuration
    ) internal pure returns (uint256 interest) {
        uint256 interestEarnedPerSecond = amount * interestRatePerYear / 1e18 / 365 days;
        uint256 timeElapsed = Math.min(currentTime - lockStartTime, lockDuration);
        interest = interestEarnedPerSecond * timeElapsed;
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
            uint256 stakingPower = _positions[tokenId].stakingPower;
            uint256 amtConvertible = _positions[tokenId].amountConvertible;
            uint256 amountStaked = _positions[tokenId].amountStaked;
            IERC20 asset = _positions[tokenId].asset;
            if (stakingPower > 0) stakingPowerToken.transferPermissioned(from, to, stakingPower);
            if (amtConvertible > 0) rzrTrackingToken.transferPermissioned(from, to, amtConvertible);
            if (amountStaked > 0) _variables[asset].trackingToken.transferPermissioned(from, to, amountStaked);
            emit PositionTransferred(from, to, tokenId, stakingPower, amtConvertible);
        }
    }

    function _getPrice(IERC20 asset) internal view returns (uint256 price) {
        uint256 decimals = IERC20Metadata(address(asset)).decimals();
        (uint256 rzrAssets, uint256 usdAssets, uint256 lastUpdatedAt) =
            oracle.getPriceForAmount(address(asset), 10 ** (decimals));
        require(rzrAssets == 0 && usdAssets > 0, "Invalid price");
        require(lastUpdatedAt > block.timestamp - MAX_ORACLE_STALENESS, "Stale price");
        price = usdAssets;
    }

    function _getSpotPrice() internal view returns (uint256 price) {
        (uint256 rzrAssets, uint256 usdAssets, uint256 lastUpdatedAt) = spotOracle.getPriceForAmount(1e18);
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

    function _scaleAmount(IERC20 loanToken, uint256 amount) internal view returns (uint256 amountScaled) {
        amountScaled = amount * 10 ** (18 - IERC20Metadata(address(loanToken)).decimals());
    }

    function _getStakingPower(IERC20 loanToken, uint256 amount, uint256 duration)
        internal
        view
        returns (uint256 stakingPower)
    {
        uint256 amountScaled = _scaleAmount(loanToken, amount);
        stakingPower = amountScaled * duration / MAX_LOCK_DURATION;
    }

    function _onlyOwnerOrAuthorized(uint256 tokenId) internal view {
        require(
            ownerOf(tokenId) == msg.sender || isApprovedForAll(ownerOf(tokenId), msg.sender), "Not owner or approved"
        );
    }
}
