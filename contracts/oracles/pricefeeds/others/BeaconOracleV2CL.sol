// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "../../../interfaces/IOracleV2.sol";
import "../../../interfaces/IAggregatorV3.sol";
import "../../../core/AppAccessControlled.sol";

/**
 * @title BeaconOracle
 * @notice This contract is a wrapper around an IOracleV2 that allows for the beacon to be updated.
 */
contract BeaconOracleV2CL is IAggregatorV3, AppAccessControlled {
    /// @notice The beacon to use
    IOracleV2 public beacon;

    /// @notice Event emitted when the beacon is updated
    event BeaconUpdated(IOracleV2 indexed newBeacon);

    /// @notice Constructor
    /// @param _beacon The initial beacon
    constructor(IOracleV2 _beacon, address _authority) {
        __AppAccessControlled_init(_authority);
        _setBeacon(_beacon);
    }

    /// @notice Sets the beacon
    /// @param _beacon The new beacon
    function setBeacon(IOracleV2 _beacon) external onlyGovernor {
        _setBeacon(_beacon);
    }

    /// @notice Sets the beacon
    /// @param _beacon The new beacon
    function _setBeacon(IOracleV2 _beacon) internal {
        require(address(_beacon) != address(0), "Invalid beacon address");
        beacon = _beacon;
        emit BeaconUpdated(_beacon);
    }

    function getPrice() public view returns (int256 usd, uint256 lastUpdatedAt) {
        uint256 rzrAmountInUsd;
        (, rzrAmountInUsd, lastUpdatedAt) = beacon.getPriceForAmount(1e18);
        // forge-lint: disable-next-line(unsafe-typecast)
        usd = int256(rzrAmountInUsd) / 1e10;
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
        (int256 answerUsd, uint256 lastUpdatedAt) = getPrice();
        return (0, answerUsd, lastUpdatedAt, lastUpdatedAt, 0);
    }

    /**
     * @notice Returns round data for a specific round
     * @dev For this implementation, returns the same as latestRoundData
     */
    function getRoundData(uint80)
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return latestRoundData();
    }
}
