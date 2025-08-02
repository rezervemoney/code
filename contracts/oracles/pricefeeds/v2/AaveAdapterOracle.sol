// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../../../interfaces/IOracleV2.sol";
import "../../../interfaces/IAggregatorV3.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AaveAdapterOracle is IOracleV2 {
    IAggregatorV3 public immutable AGGREGATOR;
    uint256 private decimalsToAdjust;

    IERC20Metadata public immutable asset;

    constructor(IAggregatorV3 _aggregator, address _asset) {
        AGGREGATOR = _aggregator;
        uint8 decimals = AGGREGATOR.decimals();
        decimalsToAdjust = 10 ** (18 - decimals);
        asset = IERC20Metadata(_asset);
    }

    /// @inheritdoc IOracleV2
    function getPriceForAmount(uint256 amount)
        external
        view
        override
        returns (uint256 rzrAssets, uint256 usdAssets, uint256 lastUpdatedAt)
    {
        (, int256 answer,, uint256 updatedAt,) = AGGREGATOR.latestRoundData();
        rzrAssets = 0;
        usdAssets = amount * uint256(answer) * decimalsToAdjust;
        lastUpdatedAt = updatedAt;
    }
}
