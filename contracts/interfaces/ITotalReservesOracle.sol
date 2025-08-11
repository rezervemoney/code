// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

interface ITotalReservesOracle {
    /// @notice Emitted when the offchain reserves are updated
    /// @param rzrReserves The RZR reserves
    /// @param usdReserves The USD reserves
    /// @param lastUpdatedAt The last time the offchain reserves were updated
    event ReservesOffchainUpdated(
        uint256 indexed rzrReserves, uint256 indexed usdReserves, uint256 indexed lastUpdatedAt
    );

    /// @notice Emitted when the offchain updater is updated
    /// @param offchainUpdater The address of the offchain updater
    event OffchainUpdaterUpdated(address indexed offchainUpdater);

    /// @notice Emitted when the crosschain reserves are updated
    /// @param eid The eid of the chain
    /// @param rzrReserves The RZR reserves for the chain
    /// @param usdReserves The USD reserves for the chain
    /// @param lastUpdatedAt The last time the crosschain reserves were updated
    event CrosschainReservesUpdated(
        uint256 indexed eid, uint256 indexed rzrReserves, uint256 indexed usdReserves, uint256 lastUpdatedAt
    );

    /// @notice Emitted when the onchain reserves are updated
    /// @param rzrReserves The total RZR reserves across all chains
    /// @param usdReserves The total USD reserves across all chains
    event ReservesOnchainUpdated(uint256 indexed rzrReserves, uint256 indexed usdReserves);

    /// @notice Emitted when the reserves credit for USD is updated
    /// @param reservesCreditUsd The reserves credit for USD
    event ReservesCreditUsdUpdated(uint256 indexed reservesCreditUsd);

    /// @notice Emitted when the reserves credit for RZR is updated
    /// @param reservesCreditRzr The reserves credit for RZR
    event ReservesCreditRzrUpdated(uint256 indexed reservesCreditRzr);

    /// @notice Initialize the total reserves oracle
    /// @param _authority The authority address
    /// @param _offchainUpdater The address of the offchain updater
    function initialize(address _authority, address _offchainUpdater) external;

    /// @notice Get the onchain total reserves
    /// @return _rzrReserves The total RZR reserves across all chains
    /// @return _usdReserves The total USD reserves across all chains
    function getOnchainReserves() external view returns (uint256 _rzrReserves, uint256 _usdReserves);

    /// @notice Get the offchain total reserves
    /// @return _rzrReserves The offchain RZR reserves
    /// @return _usdReserves The offchain USD reserves
    function getOffchainReserves() external view returns (uint256 _rzrReserves, uint256 _usdReserves);

    /// @notice Get the total reserves
    /// @return _rzrReserves The total RZR reserves
    /// @return _usdReserves The total USD reserves
    function getTotalReserves() external view returns (uint256 _rzrReserves, uint256 _usdReserves);

    /// @notice Update the offchain reserves
    /// @param _rzrReserves The offchain RZR reserves
    /// @param _usdReserves The offchain USD reserves
    function updateReservesOffchain(uint256 _rzrReserves, uint256 _usdReserves) external;

    /// @notice Set the offchain updater
    /// @param _offchainUpdater The address of the offchain updater
    function setOffchainUpdater(address _offchainUpdater) external;

    /// @notice Overwrite the crosschain reserves for a specific chain
    /// @param eid The eid of the chain
    /// @param _rzrReserves The RZR reserves for the chain
    /// @param _usdReserves The USD reserves for the chain
    function overwriteCrosschainReserves(uint256 eid, uint256 _rzrReserves, uint256 _usdReserves) external;

    /// @notice Set the crosschain reserves for a specific chain (bridge permission)
    /// @param eid The eid of the chain
    /// @param _rzrReserves The RZR reserves for the chain
    /// @param _usdReserves The USD reserves for the chain
    function setCrosschainReserves(uint256 eid, uint256 _rzrReserves, uint256 _usdReserves) external;

    /// @notice Get the crosschain reserves for a specific chain
    /// @param eid The eid of the chain
    /// @return _rzrReserves The RZR reserves for the chain
    /// @return _usdReserves The USD reserves for the chain
    function getCrosschainReserves(uint256 eid) external view returns (uint256 _rzrReserves, uint256 _usdReserves);

    /// @notice Set the reserves credit for USD
    /// @param _reservesCreditUsd The reserves credit for USD
    function setReservesCreditUsd(uint256 _reservesCreditUsd) external;

    /// @notice Set the reserves credit for RZR
    /// @param _reservesCreditRzr The reserves credit for RZR
    function setReservesCreditRzr(uint256 _reservesCreditRzr) external;
}
