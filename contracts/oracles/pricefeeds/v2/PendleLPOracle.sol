// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "../../../interfaces/IOracleV2.sol";
import "@pendle/core-v2/contracts/interfaces/IPMarket.sol";
import "@pendle/core-v2/contracts/oracles/PtYtLpOracle/PendleLpOracleLib.sol";

contract PendleLPOracle is IOracleV2 {
    /// @notice The Chainlink price feed for asset pricing
    IOracleV2 public immutable FEED_ASSET;

    /// @notice The Pendle market interface
    IPMarket public immutable PENDLE_MARKET;

    /// @notice TWAP duration in seconds
    uint32 public immutable TWAP_DURATION;

    /// @notice Constructor for LP oracle with Chainlink interface
    /// @param _pendleMarketAddress The address of the Pendle LP market
    /// @param _priceFeedAsset The Chainlink feed for underlying asset/USD pricing
    /// @param _twapDuration The duration of the TWAP in seconds (e.g., 1800 for 30 minutes)
    constructor(address _pendleMarketAddress, IOracleV2 _priceFeedAsset, uint32 _twapDuration) {
        PENDLE_MARKET = IPMarket(_pendleMarketAddress);
        FEED_ASSET = _priceFeedAsset;
        TWAP_DURATION = _twapDuration;

        PENDLE_MARKET.readTokens();
        (IStandardizedYield sy,,) = PENDLE_MARKET.readTokens();
        require(sy.yieldToken() == address(_priceFeedAsset.asset()), "Invalid asset");
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
        uint256 assetAmount = getLpToSyRate() * amount / 1e18;
        (rzrAssets, usdAssets, lastUpdatedAt) = FEED_ASSET.getPriceForAmount(assetAmount);
    }

    /// @notice Get the LP to asset rate using Pendle's LP oracle library
    /// @dev This function simulates hypothetical AMM trades using PT oracle TWAP data
    /// @dev The LP oracle inherently uses PT oracle through PendleLpOracleLib internal calls
    /// @dev Includes built-in insolvency protection for both LP and underlying assets
    /// @return LP to asset rate in 18 decimals
    function getLpToAssetRate() public view returns (uint256) {
        return PendleLpOracleLib.getLpToAssetRate(PENDLE_MARKET, TWAP_DURATION);
    }

    /// @notice Get the LP to SY rate instead of LP to asset rate
    /// @dev Alternative pricing method for different use cases
    /// @dev SY (Standardized Yield) is the interest-bearing token wrapper
    /// @return LP to SY rate in 18 decimals
    function getLpToSyRate() public view returns (uint256) {
        return PendleLpOracleLib.getLpToSyRate(PENDLE_MARKET, TWAP_DURATION);
    }
}
