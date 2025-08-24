// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import "../../interfaces/ITotalReservesOracle.sol";
import "../../core/AppAccessControlled.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title TotalReservesOracle
 * @notice Oracle for the total RZR and USD reserves across multiple chains
 * @dev The total reserves oracle tracks RZR and USD reserves across multiple chains. It uses layerzero to get the reserves
 * from other chains and uses a server-side oracle to get the reserves off-chain. The main reason for having two sources
 * is to avoid the need for a single point of failure. The max deviation is set to 1% to avoid any issues with the oracle.
 * This oracle captures reserves data in the style of IOracleV2 which provides both RZR and USD asset amounts.
 */
contract TotalReservesOracle is AppAccessControlled, ITotalReservesOracle {
    using EnumerableSet for EnumerableSet.UintSet;

    /// @notice The maximum deviation from the onchain reserves (1% = 0.01e18)
    uint256 public maxDeviation;

    /// @notice The staleness of the offchain reserves
    uint256 public staleness;

    /// @notice The offchain RZR reserves
    uint256 public offchainRzrReserves;

    /// @notice The offchain USD reserves
    uint256 public offchainUsdReserves;

    /// @notice The last time the offchain reserves were updated
    uint256 public lastUpdatedOffchainAt;

    /// @notice The address of the offchain updater
    address public offchainUpdater;

    /// @notice The reserves credit for the current epoch
    uint256 public reservesCreditUsd;

    /// @notice The reserves credit for the current epoch
    uint256 public reservesCreditRzr;

    /// @notice The crosschain reserves for each chain
    /// @dev Mapping from chain eid to a struct containing RZR and USD reserves
    mapping(uint256 eid => ChainReserves) public crosschainReserves;

    /// @notice The eids of the chains that are supported
    EnumerableSet.UintSet internal _eids;

    /// @notice Struct to store reserves for a specific chain
    struct ChainReserves {
        uint256 rzrReserves;
        uint256 usdReserves;
        uint256 lastUpdatedAt;
    }

    /// @inheritdoc ITotalReservesOracle
    function initialize(address _authority, address _offchainUpdater) external reinitializer(4) {
        __AppAccessControlled_init(_authority);
        offchainUpdater = _offchainUpdater;
        maxDeviation = 1e16; // 1% max deviation (100 basis points)
        staleness = 25 hours; // 1 day staleness
    }

    /// @inheritdoc ITotalReservesOracle
    function getOnchainReserves() public view returns (uint256 _rzrReserves, uint256 _usdReserves) {
        uint256 length = _eids.length();
        for (uint256 i = 0; i < length; i++) {
            uint256 eid = _eids.at(i);
            ChainReserves storage chainReserves = crosschainReserves[eid];
            _rzrReserves += chainReserves.rzrReserves;
            _usdReserves += chainReserves.usdReserves;
            require(chainReserves.lastUpdatedAt > block.timestamp - staleness, "Crosschain reserves are stale");
        }
    }

    function getEids() external view returns (uint256[] memory) {
        return _eids.values();
    }

    function toggleEid(uint256 eid) external onlyGovernor {
        if (_eids.contains(eid)) _eids.remove(eid);
        else _eids.add(eid);
    }

    /// @inheritdoc ITotalReservesOracle
    function getOffchainReserves() public view returns (uint256 _rzrReserves, uint256 _usdReserves) {
        require(lastUpdatedOffchainAt > block.timestamp - staleness, "Offchain reserves are stale");
        _rzrReserves = offchainRzrReserves;
        _usdReserves = offchainUsdReserves;
    }

    /// @inheritdoc ITotalReservesOracle
    function getTotalReserves() external view returns (uint256 _rzrReserves, uint256 _usdReserves) {
        (uint256 _onchainRzrReserves, uint256 _onchainUsdReserves) = getOnchainReserves();
        (uint256 _offchainRzrReserves, uint256 _offchainUsdReserves) = getOffchainReserves();

        // Check deviation for RZR reserves
        require(
            _offchainRzrReserves >= _onchainRzrReserves * (1e18 - maxDeviation) / 1e18,
            "RZR reserves deviation too high"
        );
        require(
            _offchainRzrReserves <= _onchainRzrReserves * (1e18 + maxDeviation) / 1e18, "RZR reserves deviation too low"
        );

        // Check deviation for USD reserves
        require(
            _offchainUsdReserves >= _onchainUsdReserves * (1e18 - maxDeviation) / 1e18,
            "USD reserves deviation too high"
        );
        require(
            _offchainUsdReserves <= _onchainUsdReserves * (1e18 + maxDeviation) / 1e18,
            "USD reserves deviation too high"
        );

        _rzrReserves = _onchainRzrReserves + reservesCreditRzr;
        _usdReserves = _onchainUsdReserves + reservesCreditUsd;
    }

    /// @inheritdoc ITotalReservesOracle
    function updateReservesOffchain(uint256 _rzrReserves, uint256 _usdReserves) external {
        require(msg.sender == offchainUpdater || authority.isExecutor(msg.sender), "Only updater");
        offchainRzrReserves = _rzrReserves;
        offchainUsdReserves = _usdReserves;
        lastUpdatedOffchainAt = block.timestamp;
        emit ReservesOffchainUpdated(offchainRzrReserves, offchainUsdReserves, lastUpdatedOffchainAt);
    }

    /// @inheritdoc ITotalReservesOracle
    function setOffchainUpdater(address _offchainUpdater) external onlyGovernor {
        offchainUpdater = _offchainUpdater;
        emit OffchainUpdaterUpdated(offchainUpdater);
    }

    /// @inheritdoc ITotalReservesOracle
    function overwriteCrosschainReserves(uint256 eid, uint256 _rzrReserves, uint256 _usdReserves)
        external
        onlyGovernor
    {
        ChainReserves storage chainReserves = crosschainReserves[eid];
        chainReserves.rzrReserves = _rzrReserves;
        chainReserves.usdReserves = _usdReserves;
        chainReserves.lastUpdatedAt = block.timestamp;
        emit CrosschainReservesUpdated(eid, _rzrReserves, _usdReserves, block.timestamp);
    }

    /// @inheritdoc ITotalReservesOracle
    function setReservesCreditUsd(uint256 _reservesCreditUsd) external onlyGovernor {
        reservesCreditUsd = _reservesCreditUsd;
        emit ReservesCreditUsdUpdated(reservesCreditUsd);
    }

    /// @inheritdoc ITotalReservesOracle
    function setReservesCreditRzr(uint256 _reservesCreditRzr) external onlyGovernor {
        reservesCreditRzr = _reservesCreditRzr;
        emit ReservesCreditRzrUpdated(reservesCreditRzr);
    }

    /// @inheritdoc ITotalReservesOracle
    function setCrosschainReserves(uint256 eid, uint256 _rzrReserves, uint256 _usdReserves) external onlyBridge {
        ChainReserves storage chainReserves = crosschainReserves[eid];
        chainReserves.rzrReserves = _rzrReserves;
        chainReserves.usdReserves = _usdReserves;
        chainReserves.lastUpdatedAt = block.timestamp;
        emit CrosschainReservesUpdated(eid, _rzrReserves, _usdReserves, block.timestamp);
    }

    /// @inheritdoc ITotalReservesOracle
    function getCrosschainReserves(uint256 eid) external view returns (uint256 _rzrReserves, uint256 _usdReserves) {
        ChainReserves storage chainReserves = crosschainReserves[eid];
        _rzrReserves = chainReserves.rzrReserves;
        _usdReserves = chainReserves.usdReserves;
    }

    /// @notice Set the maximum deviation allowed between onchain and offchain reserves
    /// @param _maxDeviation The maximum deviation (in basis points, e.g., 0.01e18 = 1%)
    function setMaxDeviation(uint256 _maxDeviation) external onlyGovernor {
        maxDeviation = _maxDeviation;
    }

    /// @notice Set the staleness period for offchain reserves
    /// @param _staleness The staleness period in seconds
    function setStaleness(uint256 _staleness) external onlyGovernor {
        staleness = _staleness;
    }
}
