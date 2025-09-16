// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "../../../interfaces/ICurveNGPool.sol";
import "../../../interfaces/IOracleV2.sol";
import "../../../interfaces/ISpectraPrincipalToken.sol";
import "../../../libraries/SpectraCurveOracleLib.sol";
import "@pendle/core-v2/contracts/interfaces/IPMarket.sol";

contract SpectraLPOracle is IOracleV2 {
    /// @notice The Chainlink price feed for asset pricing
    IOracleV2 public immutable FEED_ASSET;

    address public pool;
    ISpectraPrincipalToken public pt;

    /// @notice TWAP duration in seconds
    uint32 public immutable TWAP_DURATION;

    /// @notice Constructor for LP oracle with Chainlink interface
    /// @param _pool The address of the Spectra pool
    /// @param _priceFeedAsset The Chainlink feed for underlying asset/USD pricing
    /// @param _twapDuration The duration of the TWAP in seconds (e.g., 1800 for 30 minutes)
    constructor(address _pool, IOracleV2 _priceFeedAsset, uint32 _twapDuration) {
        pool = _pool;
        pt = ISpectraPrincipalToken(ICurveNGPool(pool).coins(1));

        FEED_ASSET = _priceFeedAsset;
        TWAP_DURATION = _twapDuration;

        address _asset = ISpectraPrincipalToken(pt).getIBT();
        require(_asset == address(_priceFeedAsset.asset()), "Invalid asset");
    }

    /// @notice Get the asset of the oracle
    /// @return asset The address of the asset
    function asset() external view override returns (IERC20Metadata) {
        return FEED_ASSET.asset();
    }

    /// @inheritdoc IOracleV2
    function getPriceForAmount(uint256 amount)
        external
        view
        override
        returns (uint256 rzrAssets, uint256 usdAssets, uint256 lastUpdatedAt)
    {
        uint256 assetAmount = getLpToIBTRate() * amount / 1e18;
        (rzrAssets, usdAssets, lastUpdatedAt) = FEED_ASSET.getPriceForAmount(assetAmount);
    }

    function getLpToIBTRate() public view returns (uint256) {
        return SpectraCurveOracleLib.getLPTToIBTRateSNG(pool);
    }
}
