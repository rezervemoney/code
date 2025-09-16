// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "../../interfaces/IApp.sol";
import "../../interfaces/IAppOracle.sol";
import "../../interfaces/IUSDTreasury.sol";
import "../AppAccessControlled.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @title USDR
/// @notice USDR is a stablecoin that is used to lock debt for the protocol
/// @dev This contract is used to manage the USDR token and the assets that are backed by it
contract USDTreasury is AppAccessControlled, ReentrancyGuardUpgradeable, IUSDTreasury {
    using SafeERC20 for IERC20;
    using SafeERC20 for IApp;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice The maximum deviation allowed for the price of an asset
    uint256 public immutable MAX_DEVIATION = 0.001e18; // 0.1%

    uint256 public constant BURN_CANCEL_TIME = 1 days;

    /// @inheritdoc IUSDTreasury
    IApp public override usdr;

    /// @inheritdoc IUSDTreasury
    IAppOracle public override appOracle;

    mapping(IERC20 asset => AssetInfo assetInfo) private _assetInfos;
    EnumerableSet.AddressSet private _assets;

    mapping(address who => PendingBurn pendingBurn) private _pendingBurns;

    /// @notice Initialize the contract
    /// @param _authority The authority address
    /// @param _usdr The address of the USDR token
    /// @param _appOracle The address of the app oracle
    function initialize(address _authority, address _usdr, address _appOracle) external reinitializer(3) {
        __AppAccessControlled_init(_authority);
        __ReentrancyGuard_init();
        usdr = IApp(_usdr);
        appOracle = IAppOracle(_appOracle);
    }

    /// @inheritdoc IUSDTreasury
    function assetInfos(IERC20 asset) external view override returns (AssetInfo memory) {
        return _assetInfos[asset];
    }

    function pendingBurn(address who) external view override returns (PendingBurn memory) {
        return _pendingBurns[who];
    }

    /// @inheritdoc IUSDTreasury
    function mint(IERC20 asset, address account_, uint256 amount_)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 mintAmount)
    {
        _checkValidAsset(asset);
        uint256 mintPrice = _getMintPriceAndCheckDeviation(asset);
        mintAmount = amount_ * mintPrice / _getOneUnitOfAsset(asset);

        _assetInfos[asset].supplied += amount_;
        require(_assetInfos[asset].supplied <= _assetInfos[asset].supplyCap, "supply cap exceeded");

        asset.safeTransferFrom(msg.sender, address(this), amount_);
        usdr.mint(account_, mintAmount);

        emit Minted(asset, account_, amount_);
    }

    /// @inheritdoc IUSDTreasury
    function borrow(IERC20 asset, address destination, uint256 amount_) external onlyReserveManager whenNotPaused {
        _checkValidAsset(asset);
        asset.safeTransfer(destination, amount_);
        _assetInfos[asset].borrowed += amount_;
        emit Borrowed(asset, destination, amount_);
    }

    /// @inheritdoc IUSDTreasury
    function repay(IERC20 asset, uint256 amount_) external onlyReserveManager whenNotPaused {
        _checkValidAsset(asset);
        asset.safeTransferFrom(msg.sender, address(this), amount_);
        _assetInfos[asset].borrowed -= amount_;
        emit Repaid(asset, msg.sender, amount_);
    }

    /// @inheritdoc IUSDTreasury
    function burn(uint256 amountToBurn, IERC20 asset)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 redeemAmount)
    {
        require(_pendingBurns[msg.sender].asset == IERC20(address(0)), "Pending burn");

        _checkValidAsset(asset);
        (, uint256 redeemPriceWithFee) = _getRedeemPriceAndCheckDeviation(asset);
        redeemAmount = amountToBurn * _getOneUnitOfAsset(asset) * redeemPriceWithFee / 1e36;

        _assetInfos[asset].supplied -= redeemAmount;
        usdr.safeTransferFrom(msg.sender, address(this), amountToBurn);

        _pendingBurns[msg.sender] = PendingBurn({
            asset: asset,
            assetRedeemed: redeemAmount,
            amountBurned: amountToBurn,
            submittedAt: block.timestamp
        });

        emit BurnSubmitted(msg.sender, asset, amountToBurn);
    }

    function completeBurn() external override nonReentrant {
        PendingBurn memory _pendingBurn = _pendingBurns[msg.sender];

        require(_pendingBurn.asset != IERC20(address(0)), "No pending burn");
        require(_pendingBurn.submittedAt + BURN_CANCEL_TIME < block.timestamp, "Burn cancel time not passed");
        _pendingBurn.asset.safeTransfer(msg.sender, _pendingBurn.assetRedeemed);
        usdr.burn(_pendingBurn.amountBurned);

        delete _pendingBurns[msg.sender];
        emit BurnCompleted(msg.sender);
    }

    function cancelBurn() external override nonReentrant {
        PendingBurn memory _pendingBurn = _pendingBurns[msg.sender];

        require(_pendingBurn.asset != IERC20(address(0)), "No pending burn");
        usdr.safeTransfer(msg.sender, _pendingBurn.amountBurned);

        delete _pendingBurns[msg.sender];
        emit BurnCanceled(msg.sender);
    }

    /// @inheritdoc IUSDTreasury
    function setAsset(IERC20 asset, uint256 price, uint256 redeemFee, uint256 supplyCap) external onlyGovernor {
        _assetInfos[asset].price = price;
        _assetInfos[asset].redeemFee = redeemFee;
        _assetInfos[asset].supplyCap = supplyCap;
        emit AssetSet(asset, price, redeemFee, supplyCap);
    }

    /// @inheritdoc IUSDTreasury
    function setAssetSupplyCap(IERC20 asset, uint256 supplyCap) external {
        uint256 currentSupplyCap = _assetInfos[asset].supplyCap;
        if (supplyCap < currentSupplyCap) _onlyGuardianOrGovernor();
        else _onlyGovernor();
        _assetInfos[asset].supplyCap = supplyCap;
        emit AssetSupplyCapSet(asset, supplyCap);
    }

    /// @inheritdoc IUSDTreasury
    function disableAsset(IERC20 asset) external onlyGuardianOrGovernor {
        _assets.remove(address(asset));
        emit AssetPaused(asset);
    }

    /// @inheritdoc IUSDTreasury
    function enableAsset(IERC20 asset) external onlyGovernor {
        _assets.add(address(asset));
        emit AssetUnpaused(asset);
    }

    /// @inheritdoc IUSDTreasury
    function assets() external view returns (address[] memory) {
        return _assets.values();
    }

    /// @dev This function is used to check the deviation of the current price and the oracle price
    /// @param currentPrice The current price
    /// @param oraclePrice The oracle price
    function _checkDeviation(uint256 currentPrice, uint256 oraclePrice) internal pure {
        require(oraclePrice <= currentPrice * (1e18 + MAX_DEVIATION) / 1e18, "deviation too high");
        require(oraclePrice >= currentPrice * (1e18 - MAX_DEVIATION) / 1e18, "deviation too high");
    }

    /// @dev This function is used to get the mint price and check the deviation
    /// @param asset The asset
    /// @return mintPrice The mint price
    function _getMintPriceAndCheckDeviation(IERC20 asset) internal view returns (uint256 mintPrice) {
        uint256 spotPrice = _getAssetPrice(asset);
        mintPrice = _assetInfos[asset].price;
        _checkDeviation(mintPrice, spotPrice);
    }

    /// @dev This function is used to get the redeem price and check the deviation
    /// @param asset The asset
    /// @return redeemPrice The redeem price
    /// @return redeemPriceWithFee The redeem price with fee
    function _getRedeemPriceAndCheckDeviation(IERC20 asset)
        internal
        view
        returns (uint256 redeemPrice, uint256 redeemPriceWithFee)
    {
        uint256 spotPrice = _getAssetPrice(asset);
        redeemPrice = _assetInfos[asset].price;
        redeemPriceWithFee = redeemPrice * (1e18 - _assetInfos[asset].redeemFee) / 1e18;
        _checkDeviation(redeemPrice, spotPrice);
    }

    /// @dev This function is used to check if the asset is valid
    /// @param asset The asset
    function _checkValidAsset(IERC20 asset) internal view {
        require(_assetInfos[asset].price > 0, "Invalid asset");
        require(_assets.contains(address(asset)), "Asset is disabled");
    }

    /// @dev This function is used to get the one unit of the asset
    /// @param asset The asset
    /// @return amount The one unit of the asset
    function _getOneUnitOfAsset(IERC20 asset) internal view returns (uint256 amount) {
        amount = 10 ** (IERC20Metadata(address(asset)).decimals());
    }

    /// @dev This function is used to get the price of the asset
    /// @param asset The asset
    /// @return price The price of the asset
    function _getAssetPrice(IERC20 asset) internal view returns (uint256 price) {
        (uint256 rzrAmount, uint256 usdAmount,) = appOracle.getPriceForAmount(address(asset), _getOneUnitOfAsset(asset));
        require(rzrAmount == 0, "Invalid price");
        require(usdAmount > 0, "Invalid price");
        price = usdAmount;
    }
}
