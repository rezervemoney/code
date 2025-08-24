// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../../../interfaces/IOracleV2.sol";
import "../../../core/AppAccessControlled.sol";

/**
 * @title TwapOracleV3
 * @notice This contract implements a Time-Weighted Average Price (TWAP) oracle
 * @dev Uses a circular buffer to store price _observations and calculate TWAP
 */
contract TwapOracleV3 is IOracleV2, AppAccessControlled {
    uint256 public immutable MAX_STALENESS = 25 hours;
    uint256 public immutable EPOCH_DURATION = 23 hours;

    struct Observation {
        uint256 timestamp;
        uint256 priceUsd;
        uint256 priceRzr;
    }

    IOracleV2 public oracle;
    Observation[] private _observations;
    uint256 private _lastEpochId;
    uint256 private _maxObservations;

    uint256 public twapPriceUsd;
    uint256 public twapPriceRzr;
    uint256 public lastUpdateTime;

    event ObservationAdded(uint256 timestamp, uint256 priceUsd, uint256 priceRzr);
    event TwapUpdated(uint256 twapPriceUsd, uint256 twapPriceRzr);

    /**
     * @notice Constructor
     * @param oracle_ The oracle to use
     * @param maxObservations_ The maximum number of observations
     * @param authority_ The authority
     */
    constructor(IOracleV2 oracle_, uint256 maxObservations_, address authority_) {
        require(address(oracle_) != address(0), "Invalid oracle address");
        require(maxObservations_ > 0, "Max observations must be > 0");

        __AppAccessControlled_init(authority_);

        oracle = oracle_;
        _maxObservations = maxObservations_;

        (uint256 priceRzr, uint256 priceUsd, uint256 lastUpdated) = oracle.getPriceForAmount(1e18);
        require(priceRzr > 0 || priceUsd > 0, "Invalid price");
        require(lastUpdated >= block.timestamp - MAX_STALENESS, "Price is stale");

        for (uint256 i = 0; i < _maxObservations; i++) {
            _observations.push(Observation({timestamp: block.timestamp, priceUsd: priceUsd, priceRzr: priceRzr}));
        }

        _lastEpochId = _maxObservations - 1;
        twapPriceUsd = priceUsd * _maxObservations;
        twapPriceRzr = priceRzr * _maxObservations;
        lastUpdateTime = block.timestamp;

        emit ObservationAdded(block.timestamp, priceUsd, priceRzr);
        emit TwapUpdated(twapPriceUsd / _maxObservations, twapPriceRzr / _maxObservations);
    }

    /**
     * @notice Updates the price observation
     * @dev Can be called by anyone to update the price
     */
    function update() public onlyExecutor {
        require(block.timestamp >= lastUpdateTime + EPOCH_DURATION, "Too early to update");
        lastUpdateTime = block.timestamp;

        (uint256 priceRzr, uint256 priceUsd, uint256 lastUpdated) = oracle.getPriceForAmount(1e18);
        require(priceRzr > 0 || priceUsd > 0, "Invalid price");
        require(lastUpdated >= block.timestamp - MAX_STALENESS, "Price is stale");

        Observation memory obs = Observation({timestamp: block.timestamp, priceUsd: priceUsd, priceRzr: priceRzr});

        // Replace the oldest observation with the newest one
        uint256 idToReplace = (_lastEpochId + 1) % _maxObservations;
        twapPriceUsd = twapPriceUsd - _observations[idToReplace].priceUsd + priceUsd;
        twapPriceRzr = twapPriceRzr - _observations[idToReplace].priceRzr + priceRzr;

        _observations[idToReplace] = obs;
        _lastEpochId = idToReplace;

        emit ObservationAdded(block.timestamp, priceUsd, priceRzr);
        emit TwapUpdated(twapPriceUsd / _maxObservations, twapPriceRzr / _maxObservations);
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
        twapRzr = twapPriceRzr / _maxObservations;
        twapUsd = twapPriceUsd / _maxObservations;
    }

    function getPriceForAmount(uint256 amount)
        external
        view
        override
        returns (uint256 priceRzr, uint256 priceUsd, uint256 lastUpdated)
    {
        (uint256 twapRzr, uint256 twapUsd) = getTwap();
        priceRzr = twapRzr * amount / 1e18;
        priceUsd = twapUsd * amount / 1e18;
        lastUpdated = lastUpdateTime;
    }

    function asset() external view returns (IERC20Metadata) {
        return oracle.asset();
    }
}
