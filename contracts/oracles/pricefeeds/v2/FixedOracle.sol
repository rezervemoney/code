// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../../../interfaces/IOracleV2.sol";

contract FixedOracle is IOracleV2 {
    /// @notice The price in USD
    uint256 public priceUsd;

    /// @notice The price in RZR
    uint256 public priceRzr;

    /// @notice The asset
    IERC20Metadata public immutable asset;

    /// @notice Constructor
    /// @param _priceRzr The initial price in RZR
    /// @param _priceUsd The initial price in USD
    constructor(uint256 _priceRzr, uint256 _priceUsd, address _asset) {
        priceUsd = _priceUsd;
        priceRzr = _priceRzr;
        asset = IERC20Metadata(_asset);
    }

    /// @inheritdoc IOracleV2
    function getPriceForAmount(uint256 amount)
        external
        view
        override
        returns (uint256 rzrAssets, uint256 usdAssets, uint256 lastUpdatedAt)
    {
        rzrAssets = priceRzr * amount / 1e18;
        usdAssets = priceUsd * amount / 1e18;
        lastUpdatedAt = block.timestamp;
    }
}
