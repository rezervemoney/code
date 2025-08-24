// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "../interfaces/IOracleV2.sol";

contract MockOracleV2 is IOracleV2 {
    uint256 private _priceUsd;
    uint256 private _priceRzr;
    uint256 private _lastUpdatedAt;

    IERC20Metadata public immutable asset;

    constructor(uint256 priceRzr, uint256 priceUsd, address _asset) {
        _priceRzr = priceRzr;
        _priceUsd = priceUsd;
        _lastUpdatedAt = block.timestamp;
        asset = IERC20Metadata(_asset);
    }

    function getPriceForAmount(uint256 amount)
        external
        view
        override
        returns (uint256 rzrAssets, uint256 usdAssets, uint256 lastUpdatedAt)
    {
        uint256 decimalOffset = 10 ** (asset.decimals());
        rzrAssets = _priceRzr * amount / decimalOffset;
        usdAssets = _priceUsd * amount / decimalOffset;
        lastUpdatedAt = _lastUpdatedAt;
    }

    function setPrice(uint256 priceRzr_, uint256 priceUsd_) external {
        _priceRzr = priceRzr_;
        _priceUsd = priceUsd_;
        _lastUpdatedAt = block.timestamp;
    }

    function setPriceUsd(uint256 priceUsd_) external {
        _priceUsd = priceUsd_;
        _lastUpdatedAt = block.timestamp;
    }

    function setPriceRzr(uint256 priceRzr_) external {
        _priceRzr = priceRzr_;
        _lastUpdatedAt = block.timestamp;
    }

    function touchTimestamp() external {
        _lastUpdatedAt = block.timestamp;
    }
}
