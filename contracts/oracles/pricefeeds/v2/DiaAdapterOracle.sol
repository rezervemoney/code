// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../../../interfaces/IOracleV2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../../../interfaces/IAggregatorV3.sol";

interface IDiaOracle {
    function getValue(string memory _key) external view returns (uint128 value, uint128 timestamp);
}

contract DiaAdapterOracle is IOracleV2, IAggregatorV3 {
    IDiaOracle public immutable DIAL_ORACLE;
    IERC20Metadata public immutable asset;
    string public key;

    constructor(IDiaOracle _diaOracle, string memory _key, address _asset) {
        DIAL_ORACLE = _diaOracle;
        key = _key;
        asset = IERC20Metadata(_asset);
    }

    function description() external pure returns (string memory) {
        return "IAggregatorV3 implementation for a Dia price feed";
    }

    /// @inheritdoc IAggregatorV3
    function version() external pure returns (uint256) {
        return 1;
    }

    /// @inheritdoc IOracleV2
    function getPriceForAmount(uint256 amount)
        external
        view
        override
        returns (uint256 rzrAssets, uint256 usdAssets, uint256 lastUpdatedAt)
    {
        (uint128 value, uint128 timestamp) = DIAL_ORACLE.getValue(key);
        rzrAssets = 0;
        usdAssets = value * 1e10;
        lastUpdatedAt = timestamp;
    }

    /// @inheritdoc IAggregatorV3
    function latestAnswer() external view returns (int256) {
        (uint128 value, uint128 timestamp) = DIAL_ORACLE.getValue(key);
        return int256(int128(value));
    }

    /// @inheritdoc IAggregatorV3
    function decimals() external pure returns (uint8) {
        return 8;
    }

    /// @inheritdoc IAggregatorV3
    function latestRoundData()
        public
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (uint128 value, uint128 timestamp) = DIAL_ORACLE.getValue(key);
        return (0, int256(int128(value)), 0, timestamp, 0);
    }

    /// @inheritdoc IAggregatorV3
    function getRoundData(uint80 _roundId)
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return latestRoundData();
    }
}
