// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

interface ITotalSupplyOracle {
    /// @notice Emitted when the max deviation is updated
    /// @param maxDeviation The max deviation
    event MaxDeviationUpdated(uint256 indexed maxDeviation);

    /// @notice Emitted when the offchain total supply is updated
    /// @param offchainTotalSupply The offchain total supply
    /// @param lastUpdatedOffchainAt The last time the offchain total supply was updated
    event TotalSupplyOffchainUpdated(uint256 indexed offchainTotalSupply, uint256 indexed lastUpdatedOffchainAt);

    /// @notice Emitted when the offchain updater is updated
    /// @param offchainUpdater The address of the offchain updater
    event OffchainUpdaterUpdated(address indexed offchainUpdater);

    /// @notice Emitted when the crosschain total supply is updated
    /// @param eid The eid of the chain
    /// @param crosschainTotalSupply The crosschain total supply
    /// @param lastUpdatedAt The last time the crosschain total supply was updated
    event CrosschainTotalSupplyUpdated(
        uint256 indexed eid, uint256 indexed crosschainTotalSupply, uint256 indexed lastUpdatedAt
    );

    /// @notice Emitted when the onchain total supply is updated
    /// @param onchainTotalSupply The onchain total supply
    event TotalSupplyOnchainUpdated(uint256 indexed onchainTotalSupply);

    /// @notice Emitted when the total supply credit is updated
    /// @param totalSupplyCredit The total supply credit
    event TotalSupplyCreditUpdated(uint256 indexed totalSupplyCredit);

    /// @notice Emitted when the total supply unbacked is updated
    /// @param totalSupplyUnbacked The total supply unbacked
    event TotalSupplyUnbackedUpdated(uint256 indexed totalSupplyUnbacked);

    /// @notice Emitted when the enabled status for a chain is toggled
    /// @param eid The eid of the chain
    /// @param enabled The enabled status
    event EidToggled(uint256 indexed eid, bool indexed enabled);

    /// @notice Initialize the total supply oracle
    /// @param _authority The authority address
    /// @param _offchainUpdater The address of the offchain updater
    /// @param _rzr The address of the RZR token
    function initialize(address _authority, address _offchainUpdater, address _rzr) external;

    /// @notice Get the onchain total supply
    /// @return _onchainTotalSupply The onchain total supply
    function getOnchainTotalSupply() external view returns (uint256 _onchainTotalSupply);

    /// @notice Get the offchain total supply
    /// @return _offchainTotalSupply The offchain total supply
    function getOffchainTotalSupply() external view returns (uint256 _offchainTotalSupply);

    /// @notice Get the total supply
    /// @return _totalSupply The total supply
    function getTotalSupply() external view returns (uint256 _totalSupply);

    /// @notice Get the total supply unbacked
    /// @return _totalSupplyUnbacked The total supply unbacked
    function totalSupplyUnbacked() external view returns (uint256 _totalSupplyUnbacked);

    /// @notice Toggle the enabled status for a chain
    /// @param eid The eid of the chain
    function toggleEid(uint256 eid) external;

    /// @notice Update the offchain total supply
    /// @param _offchainTotalSupply The offchain total supply
    function updateTotalSupplyOffchain(uint256 _offchainTotalSupply) external;

    /// @notice Set the offchain updater
    /// @param _offchainUpdater The address of the offchain updater
    function setOffchainUpdater(address _offchainUpdater) external;

    /// @notice Overwrite the crosschain total supply
    /// @param eid The eid of the chain
    /// @param _crosschainTotalSupply The crosschain total supply
    function overwriteCrosschainTotalSupply(uint256 eid, uint256 _crosschainTotalSupply) external;

    /// @notice Overwrite the onchain total supply
    /// @param _onchainTotalSupply The onchain total supply
    function overwriteOnchainTotalSupply(uint256 _onchainTotalSupply) external;

    /// @notice Set the crosschain total supply
    /// @param eid The eid of the chain
    /// @param _crosschainTotalSupply The crosschain total supply
    function setCrosschainTotalSupply(uint256 eid, uint256 _crosschainTotalSupply) external;

    /// @notice Set the total supply credit
    /// @param _totalSupplyCredit The total supply credit
    function setTotalSupplyCredit(uint256 _totalSupplyCredit) external;

    /// @notice Set the total supply unbacked
    /// @param _totalSupplyUnbacked The total supply unbacked
    function setTotalSupplyUnbacked(uint256 _totalSupplyUnbacked) external;

    /// @notice Set the max deviation
    /// @param _maxDeviation The max deviation
    function setMaxDeviation(uint256 _maxDeviation) external;
}
