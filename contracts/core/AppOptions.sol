// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "../interfaces/IApp.sol";
import "../interfaces/IAppStaking.sol";
import "../interfaces/IPermissionedERC20.sol";
import "../interfaces/IPermissionedERC20Factory.sol";
import "../interfaces/IAppOptions.sol";
import "./AppAccessControlled.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title AppOptions
/// @notice Implementation of the options system that allows users to buy and redeem options
/// @dev This contract handles options positions as NFTs
contract AppOptions is IAppOptions, AppAccessControlled, ERC721Enumerable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeERC20 for IApp;

    /// @inheritdoc IAppOptions
    IApp public rzr;

    /// @inheritdoc IAppOptions
    IPermissionedERC20 public rzrTrackingToken;

    /// @inheritdoc IAppOptions
    uint256 public lastPositionId;

    /// @inheritdoc IAppOptions
    uint256 public lastOfferingId;

    mapping(uint256 => Position) private _positions;
    mapping(uint256 => Offering) private _offerings;

    constructor(address _authority, address _rzr, address _factory) ERC721("RZR Options", "oRZR") ReentrancyGuard() {
        __AppAccessControlled_init(_authority);
        rzr = IApp(_rzr);
        IPermissionedERC20Factory factory = IPermissionedERC20Factory(_factory);
        rzrTrackingToken = factory.createPermissionedERC20("RZR Option", "oRZR", 18);
    }

    modifier onlyOwnerOrAuthorized(uint256 tokenId) {
        _onlyOwnerOrAuthorized(tokenId);
        _;
    }

    /// @inheritdoc IAppOptions
    function createOffering(
        IERC20 quoteToken,
        uint256 dateEnd,
        uint256 dateStart,
        uint256 maxQuoteToken,
        uint256 redemptionPrice,
        uint256 withdrawalDelay
    ) external onlyGovernor returns (uint256 offeringId) {
        offeringId = ++lastOfferingId;

        _offerings[offeringId] = Offering({
            quoteToken: quoteToken,
            enabled: true,
            dateEnd: dateEnd,
            dateStart: dateStart,
            maxQuoteToken: maxQuoteToken,
            filled: 0,
            redemptionPrice: redemptionPrice,
            withdrawalDelay: withdrawalDelay
        });

        // Transfer RZR tokens to the offering
        uint256 expectedRzr = maxQuoteToken * redemptionPrice / 1e18;
        rzr.safeTransferFrom(msg.sender, address(this), expectedRzr);

        emit OfferingCreated(offeringId, quoteToken, dateEnd, dateStart, maxQuoteToken, redemptionPrice);
    }

    /// @inheritdoc IAppOptions
    function cancelOffering(uint256 offeringId) external onlyGuardianOrGovernor {
        _offerings[offeringId].enabled = false;
        emit OfferingCanceled(offeringId);
    }

    /// @inheritdoc IAppOptions
    function buy(uint256 offeringId, uint256 quoteAmount, address receiver) external nonReentrant {
        Offering storage offering = _offerings[offeringId];
        require(offering.enabled, "Offering not enabled");
        require(offering.dateStart <= block.timestamp, "Offering not started");
        require(offering.dateEnd >= block.timestamp, "Offering ended");
        require(offering.maxQuoteToken >= offering.filled + quoteAmount, "Offering sold out");

        offering.quoteToken.safeTransferFrom(msg.sender, address(this), quoteAmount);
        offering.filled += quoteAmount;

        uint256 rzrAmountAllocated = quoteAmount * offering.redemptionPrice / 1e18;

        _positions[++lastPositionId] = Position({
            offeringId: offeringId,
            quoteAmountFilled: quoteAmount,
            quoteAmountRedeemed: 0,
            quoteAmountExercised: 0,
            rzrAmountAllocated: rzrAmountAllocated,
            rzrAmountRedeemed: 0,
            rzrAmountExercised: 0,
            withdrawalTimestamp: 0,
            withdrawalPercentage: 0
        });

        _mint(receiver, lastPositionId);

        emit OptionBought(
            offeringId, lastPositionId, receiver, quoteAmount, rzrAmountAllocated, offering.redemptionPrice
        );
    }

    /// @inheritdoc IAppOptions
    function requestRedemption(uint256 positionId, uint256 percentageE18) external onlyOwnerOrAuthorized(positionId) {
        _checkPercentage(percentageE18);

        Offering memory offering = _offerings[_positions[positionId].offeringId];
        _positions[positionId].withdrawalPercentage = percentageE18;
        _positions[positionId].withdrawalTimestamp = block.timestamp + offering.withdrawalDelay;
        emit RedemptionRequested(positionId, offering.withdrawalDelay, percentageE18);
    }

    /// @inheritdoc IAppOptions
    function cancelRedemption(uint256 positionId) external onlyOwnerOrAuthorized(positionId) {
        _positions[positionId].withdrawalTimestamp = 0;
        _positions[positionId].withdrawalPercentage = 0;
        emit RedemptionCancelled(positionId);
    }

    /// @inheritdoc IAppOptions
    function redeem(uint256 positionId) external nonReentrant onlyOwnerOrAuthorized(positionId) {
        Position storage position = _positions[positionId];
        Offering memory offering = _offerings[position.offeringId];

        require(position.withdrawalTimestamp <= block.timestamp, "Redemption not allowed yet");

        uint256 quoteAmountToRedeem = position.quoteAmountFilled * position.withdrawalPercentage / 1e18;
        uint256 rzrAmountToBurn = position.rzrAmountAllocated * position.withdrawalPercentage / 1e18;

        position.quoteAmountRedeemed += quoteAmountToRedeem;
        position.rzrAmountRedeemed += rzrAmountToBurn;

        _checkPositionInvariants(position, offering);

        // refund and burn the RZR
        offering.quoteToken.safeTransfer(msg.sender, quoteAmountToRedeem);
        rzr.burn(rzrAmountToBurn);

        emit OptionRedeemed(positionId, msg.sender, quoteAmountToRedeem, rzrAmountToBurn);
    }

    /// @inheritdoc IAppOptions
    function excercise(uint256 positionId, uint256 percentageE18)
        external
        nonReentrant
        onlyOwnerOrAuthorized(positionId)
    {
        _checkPercentage(percentageE18);

        Position storage position = _positions[positionId];
        Offering memory offering = _offerings[position.offeringId];

        uint256 quoteAmountToExercise = position.quoteAmountFilled * percentageE18 / 1e18;
        uint256 rzrAmountToExercise = position.rzrAmountAllocated * percentageE18 / 1e18;

        position.rzrAmountExercised += rzrAmountToExercise;
        position.quoteAmountExercised += quoteAmountToExercise;

        _checkPositionInvariants(position, offering);

        // claim the underlying and transfer the RZR
        offering.quoteToken.safeTransfer(_treasury(), quoteAmountToExercise);
        rzr.safeTransfer(msg.sender, rzrAmountToExercise);

        emit OptionExercised(positionId, msg.sender, quoteAmountToExercise, rzrAmountToExercise);
    }

    /// @inheritdoc IAppOptions
    function manage(address asset, uint256 amount, address recipient) external onlyReserveManager {
        IERC20(asset).safeTransfer(recipient, amount);
        emit AssetManaged(asset, amount, recipient);
    }

    /// @inheritdoc IAppOptions
    function getPosition(uint256 positionId) external view returns (Position memory) {
        return _positions[positionId];
    }

    /// @inheritdoc IAppOptions
    function getOffering(uint256 offeringId) external view returns (Offering memory) {
        return _offerings[offeringId];
    }

    /// @dev Check that the position invariants are satisfied
    function _checkPositionInvariants(Position memory p, Offering memory o) internal pure {
        uint256 quoteActioned = p.quoteAmountRedeemed + p.quoteAmountExercised;
        uint256 rzrActioned = p.rzrAmountRedeemed + p.rzrAmountExercised;

        // the total amount of quote tokens actioned must be less than or equal
        // to the total amount of quote tokens filled
        require(quoteActioned <= p.quoteAmountFilled, "invariant violated: I1");

        // the total amount of RZR tokens actioned must be less than or equal
        // to the total amount of RZR tokens allocated
        require(rzrActioned <= p.rzrAmountAllocated, "invariant violated: I2");

        // the total amount of quote tokens actioned must be equal to the total amount of
        // RZR tokens actioned by the redemption price
        require(quoteActioned * o.redemptionPrice / 1e18 == rzrActioned, "invariant violated: I3");
    }

    function _checkPercentage(uint256 percentageE18) internal pure {
        require(percentageE18 > 0 && percentageE18 <= 1e18, "invariant violated: I4");
    }

    function _treasury() internal view returns (address) {
        return address(authority.treasury());
    }

    function _onlyOwnerOrAuthorized(uint256 tokenId) internal view {
        require(
            ownerOf(tokenId) == msg.sender || isApprovedForAll(ownerOf(tokenId), msg.sender), "Not owner or approved"
        );
    }
}
