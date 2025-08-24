// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "../../../interfaces/IOracleV2.sol";
import "../../../interfaces/IAggregatorV3.sol";

contract AaveAdapterOracle is IOracleV2 {
    IAggregatorV3 public immutable AGGREGATOR;
    uint256 private oracleDecimals;
    uint256 private assetDecimals;

    IERC20Metadata public immutable asset;

    constructor(IAggregatorV3 _aggregator, address _asset) {
        AGGREGATOR = _aggregator;
        oracleDecimals = AGGREGATOR.decimals();
        assetDecimals = IERC20Metadata(_asset).decimals();
        asset = IERC20Metadata(_asset);
    }

    /// @inheritdoc IOracleV2
    function getPriceForAmount(uint256 amount)
        external
        view
        override
        returns (uint256 rzrAssets, uint256 usdAssets, uint256 lastUpdatedAt)
    {
        int256 answer = AGGREGATOR.latestAnswer();

        uint256 oracleAnswerE18 = uint256(answer) * 10 ** (18 - oracleDecimals);
        uint256 amountE18 = amount * 10 ** (18 - assetDecimals);

        rzrAssets = 0;
        usdAssets = amountE18 * oracleAnswerE18 / 1e18;
        lastUpdatedAt = block.timestamp;
    }
}
