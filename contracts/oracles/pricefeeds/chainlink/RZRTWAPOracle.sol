// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../../../interfaces/IAggregatorV3.sol";
import "../../../interfaces/IOracle.sol";
import "../../../core/AppAccessControlled.sol";

/**
 * @title RZRTWAPOracle
 * @notice Chainlink-compatible oracle that implements a 1-hour TWAP with 5-minute update intervals
 * @dev Uses a circular buffer to store price observations and calculate TWAP
 * @dev Only executable by authorized executors
 */
contract RZRTWAPOracle is IAggregatorV3, AppAccessControlled {
    struct Observation {
        uint256 timestamp;
        int256 price;
    }

    struct RoundData {
        uint80 roundId;
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
    }

    mapping(uint80 => RoundData) public roundData;

    IOracle public oracle;

    // constants for the TWAP calculation
    uint256 public constant WINDOW_SIZE = 2 hours;
    uint256 public constant UPDATE_INTERVAL = 5 minutes;
    uint256 public constant MAX_OBSERVATIONS = 24; // 2 hours / 5 minutes = 24 observations

    // bounds. this is used to clamp the TWAP to a range.
    uint256 public upperBound;
    uint256 public lowerBound;

    Observation[] public observations;
    uint256 public currentIndex;
    uint256 public lastUpdateTime;

    event ObservationAdded(uint256 timestamp, int256 price);

    /**
     * @notice Constructor
     * @param _oracle The oracle to use for price data
     * @param _authority The authority contract for access control
     */
    constructor(IOracle _oracle, address _authority, uint256 _upperBound, uint256 _lowerBound) {
        require(address(_oracle) != address(0), "Invalid oracle address");
        require(address(_authority) != address(0), "Invalid authority address");

        __AppAccessControlled_init(_authority);

        oracle = _oracle;
        upperBound = _upperBound;
        lowerBound = _lowerBound;

        // Initialize with first observation
        int256 initialPrice = int256(_oracle.getPrice());
        observations.push(Observation({timestamp: block.timestamp, price: initialPrice}));
        lastUpdateTime = block.timestamp;

        emit ObservationAdded(block.timestamp, initialPrice);
    }

    /**
     * @notice Sets the upper and lower bounds for the TWAP
     * @param _upperBound The upper bound
     * @param _lowerBound The lower bound
     */
    function setBounds(uint256 _upperBound, uint256 _lowerBound) external onlyExecutor {
        require(_upperBound > _lowerBound, "Invalid bounds");
        upperBound = _upperBound;
        lowerBound = _lowerBound;
    }

    /**
     * @notice Updates the price observation
     * @dev Can only be called by authorized executors every 30 minutes
     */
    function update() external onlyExecutor {
        require(block.timestamp >= lastUpdateTime + UPDATE_INTERVAL, "Too early to update");

        int256 price = int256(oracle.getPrice());
        require(price > 0, "Invalid price");

        if (observations.length < MAX_OBSERVATIONS) {
            observations.push(Observation({timestamp: block.timestamp, price: price}));
        } else {
            currentIndex = (currentIndex + 1) % MAX_OBSERVATIONS;
            observations[currentIndex] = Observation({timestamp: block.timestamp, price: price});
        }

        lastUpdateTime = block.timestamp;

        // record round data
        int256 twap = getTwap();
        require(twap > int256(lowerBound) && twap < int256(upperBound), "TWAP out of bounds");
        roundData[uint80(block.timestamp)] = RoundData({
            roundId: uint80(block.timestamp),
            answer: twap / 1e10,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: uint80(block.timestamp)
        });

        emit ObservationAdded(block.timestamp, twap);
    }

    /**
     * @notice Returns an observation
     * @param _index The index of the observation
     * @return obs The observation
     */
    function getObservation(uint256 _index) external view returns (Observation memory) {
        require(_index < observations.length, "Index out of bounds");
        return observations[_index];
    }

    /**
     * @notice Calculates the TWAP over the 4-hour window
     * @return twap The time-weighted average price
     */
    function getTwap() public view returns (int256 twap) {
        require(observations.length > 0, "No observations");

        uint256 endTime = block.timestamp;
        uint256 startTime = endTime - WINDOW_SIZE;

        uint256 totalTime = 0;
        int256 weightedSum = 0;

        for (uint256 i = 0; i < observations.length; i++) {
            Observation memory obs = observations[i];

            if (obs.timestamp >= startTime) {
                uint256 timeWeight = obs.timestamp - startTime;
                weightedSum += obs.price * int256(timeWeight);
                totalTime += timeWeight;
            }
        }

        require(totalTime > 0, "No observations in window");
        twap = weightedSum / int256(totalTime);
    }

    // IAggregatorV3 Interface Implementation

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
        return roundData[uint80(lastUpdateTime)].answer;
    }

    /**
     * @notice Returns the latest round data
     * @dev Returns the TWAP as the answer with current timestamp
     */
    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        RoundData memory round = roundData[uint80(lastUpdateTime)];
        return (round.roundId, round.answer, round.startedAt, round.updatedAt, round.answeredInRound);
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
        RoundData memory round = roundData[_roundId];
        return (
            _roundId, // roundId
            round.answer, // answer
            round.startedAt, // startedAt
            round.updatedAt, // updatedAt
            _roundId // answeredInRound
        );
    }
}
