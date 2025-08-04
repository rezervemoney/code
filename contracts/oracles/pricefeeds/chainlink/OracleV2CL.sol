// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../../../interfaces/IAggregatorV3.sol";
import "../../../interfaces/IAppOracle.sol";
import "../../../interfaces/IOracleV2.sol";

contract OracleV2CL is IAggregatorV3 {
    IAppOracle public appOracle;
    IOracleV2 public rzrSpotOracle;
    address public asset;
    uint256 public amount;

    constructor(IAppOracle _appOracle, IOracleV2 _rzrSpotOracle, address _asset, uint256 _amount) {
        require(address(_appOracle) != address(0), "Invalid oracle address");
        require(address(_asset) != address(0), "Invalid asset address");
        appOracle = _appOracle;
        rzrSpotOracle = _rzrSpotOracle;
        asset = _asset;
        amount = _amount;
    }

    function getPrice() public view returns (int256 usd) {
        (, uint256 usdAmount, uint256 lastUpdatedAt) = appOracle.getPriceForAmount(asset, amount);
        (, uint256 rzrAmountInUsd,) = rzrSpotOracle.getPriceForAmount(amount);
        return int256(rzrAmountInUsd + usdAmount) / 1e10;
    }

    /**
     * @notice Returns the number of decimals used to get its user representation
     */
    function decimals() external pure override returns (uint8) {
        return 8;
    }

    /**
     * @notice Returns the description of the oracle
     */
    function description() external pure override returns (string memory) {
        return "";
    }

    /**
     * @notice Returns the version of the oracle
     */
    function version() external pure override returns (uint256) {
        return 1;
    }

    /**
     * @notice Returns the latest answer (TWAP price)
     */
    function latestAnswer() external view override returns (int256) {
        (, int256 answer,,,) = latestRoundData();
        return answer;
    }

    /**
     * @notice Returns the latest round data
     * @dev Returns the TWAP as the answer with current timestamp
     */
    function latestRoundData()
        public
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (0, getPrice(), block.timestamp, block.timestamp, 0);
    }

    /**
     * @notice Returns round data for a specific round
     * @dev For this implementation, returns the same as latestRoundData
     * @param _roundId The round ID (unused in this implementation)
     */
    function getRoundData(uint80 _roundId)
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return latestRoundData();
    }
}
