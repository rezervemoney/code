// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../../../interfaces/IOracleV2.sol";
import "../../../core/AppAccessControlled.sol";

/**
 * @title TwapOracleV2
 * @notice This contract implements a Time-Weighted Average Price (TWAP) oracle
 * @dev Uses a circular buffer to store price _observations and calculate TWAP
 */
contract TwapOracleV2 is IOracleV2, AppAccessControlled {
    struct Observation {
        uint256 timestamp;
        uint256 priceUsd;
        uint256 priceRzr;
    }

    uint256 public immutable MAX_OBSERVATIONS = 10;
    uint256 public immutable MAX_STALENESS = 86400;

    IOracleV2 public oracle;
    uint256 public windowSize;
    uint256 public minUpdateInterval;

    Observation[] public _observations;
    uint256 public currentIndex;
    uint256 public lastUpdateTime;

    event ObservationAdded(uint256 timestamp, uint256 priceUsd, uint256 priceRzr);

    /**
     * @notice Constructor
     * @param _oracle The oracle to use
     * @param _minUpdateInterval The minimum update interval
     * @param _windowSize The window size
     * @param _authority The authority
     */
    constructor(IOracleV2 _oracle, uint256 _minUpdateInterval, uint256 _windowSize, address _authority) {
        require(address(_oracle) != address(0), "Invalid oracle address");
        require(_windowSize > 0, "Window size must be > 0");

        __AppAccessControlled_init(_authority);

        oracle = _oracle;
        windowSize = _windowSize;
        minUpdateInterval = _minUpdateInterval;

        (uint256 priceUsd, uint256 priceRzr, uint256 lastUpdated) = _oracle.getPriceForAmount(1e18);
        require(priceUsd > 0 || priceRzr > 0, "Invalid price");
        require(lastUpdated <= block.timestamp - MAX_STALENESS, "Price is stale");

        _observations.push(Observation({timestamp: block.timestamp, priceUsd: priceUsd, priceRzr: priceRzr}));
        emit ObservationAdded(block.timestamp, priceUsd, priceRzr);
    }

    /**
     * @notice Updates the price observation
     * @dev Can be called by anyone to update the price
     */
    function update() public onlyExecutor {
        require(block.timestamp >= lastUpdateTime + minUpdateInterval, "Too early to update");

        (uint256 priceUsd, uint256 priceRzr, uint256 lastUpdated) = oracle.getPriceForAmount(1e18);
        require(priceUsd > 0 || priceRzr > 0, "Invalid price");
        require(lastUpdated <= block.timestamp - MAX_STALENESS, "Price is stale");

        if (_observations.length < MAX_OBSERVATIONS) {
            _observations.push(Observation({timestamp: block.timestamp, priceUsd: priceUsd, priceRzr: priceRzr}));
        } else {
            currentIndex = (currentIndex + 1) % MAX_OBSERVATIONS;
            _observations[currentIndex] =
                Observation({timestamp: block.timestamp, priceUsd: priceUsd, priceRzr: priceRzr});
        }

        lastUpdateTime = block.timestamp;
        emit ObservationAdded(block.timestamp, priceUsd, priceRzr);
    }

    /**
     * @notice Returns an observation
     * @param _index The index of the observation
     * @return obs The observation
     */
    function observations(uint256 _index) public view returns (Observation memory) {
        return _observations[_index];
    }

    /**
     * @notice Calculates the TWAP over the window size
     * @return twapRzr The time-weighted average price of RZR
     * @return twapUsd The time-weighted average price of USD
     */
    function getTwap() public view returns (uint256 twapRzr, uint256 twapUsd) {
        require(_observations.length > 0, "No _observations");

        uint256 endTime = block.timestamp;
        uint256 startTime = endTime - windowSize;

        uint256 totalTime = 0;
        uint256 weightedSumRzr = 0;
        uint256 weightedSumUsd = 0;

        for (uint256 i = 0; i < _observations.length; i++) {
            Observation memory obs = _observations[i];

            if (obs.timestamp >= startTime) {
                uint256 timeWeight = obs.timestamp - startTime;
                weightedSumRzr += obs.priceRzr * timeWeight;
                weightedSumUsd += obs.priceUsd * timeWeight;
                totalTime += timeWeight;
            }
        }

        require(totalTime > 0, "No _observations in window");
        twapRzr = weightedSumRzr / totalTime;
        twapUsd = weightedSumUsd / totalTime;
    }

    function getPriceForAmount(uint256)
        external
        view
        override
        returns (uint256 priceUsd, uint256 priceRzr, uint256 lastUpdated)
    {
        (priceUsd, priceRzr) = getTwap();
        lastUpdated = lastUpdateTime;
    }

    function asset() external view returns (IERC20Metadata) {
        return oracle.asset();
    }
}
