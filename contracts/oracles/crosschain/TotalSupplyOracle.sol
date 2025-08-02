// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import "../../interfaces/ITotalSupplyOracle.sol";
import "../../interfaces/IApp.sol";
import "../../core/AppAccessControlled.sol";

/**
 * @title TotalSupplyOracle
 * @notice Oracle for the total supply of the token across multiple chains
 * @dev The total supply is an oracle that gets the total supply across multiple chains. It uses layerzero to get the total supply of all RZR on-chain
 * and uses a server-side oracle to get the total supply of all RZR off-chain. The main reason for having two sources is to avoid
 * the need for a single point of failure. The max deviation is set to 1% to avoid any issues with the oracle.
 */
contract TotalSupplyOracle is AppAccessControlled, ITotalSupplyOracle {
    /// @notice The maximum deviation from the onchain total supply
    uint256 public maxDeviation;

    /// @notice The staleness of the offchain total supply
    uint256 public staleness;

    /// @notice The offchain total supply
    uint256 public offchainTotalSupply;

    /// @notice The last time the offchain total supply was updated
    uint256 public lastUpdatedOffchainAt;

    /// @notice The onchain total supply across all other chains
    uint256 public l2chainTotalSupply;

    /// @notice The address of the offchain updater
    address public offchainUpdater;

    /// @notice The crosschain total supply for each chain
    mapping(uint256 eid => uint256 totalSupply) public crosschainTotalSupply;

    /// @notice The RZR token
    IApp public rzr;

    /// @inheritdoc ITotalSupplyOracle
    function initialize(address _authority, address _offchainUpdater, address _rzr) external initializer {
        __AppAccessControlled_init(_authority);
        rzr = IApp(_rzr);
        offchainUpdater = _offchainUpdater;
        maxDeviation = 0.01e18; // 1% max deviation
        staleness = 1 days; // 1 day staleness
    }

    /// @inheritdoc ITotalSupplyOracle
    function getOnchainTotalSupply() public view returns (uint256 _onchainTotalSupply) {
        _onchainTotalSupply = l2chainTotalSupply + rzr.totalSupply();
    }

    /// @inheritdoc ITotalSupplyOracle
    function getOffchainTotalSupply() public view returns (uint256 _offchainTotalSupply) {
        require(lastUpdatedOffchainAt > block.timestamp - staleness, "Offchain total supply is stale");
        _offchainTotalSupply = offchainTotalSupply;
    }

    /// @inheritdoc ITotalSupplyOracle
    function getTotalSupply() external view returns (uint256 _totalSupply) {
        uint256 _onchainTotalSupply = getOnchainTotalSupply();
        uint256 _offchainTotalSupply = getOffchainTotalSupply();
        require(
            _offchainTotalSupply > _onchainTotalSupply * (10000 - maxDeviation) / 10000
                && _offchainTotalSupply < _onchainTotalSupply * (10000 + maxDeviation) / 10000,
            "Total supply deviation too high"
        );
        _totalSupply = _onchainTotalSupply;
    }

    /// @inheritdoc ITotalSupplyOracle
    function updateTotalSupplyOffchain(uint256 _offchainTotalSupply) external {
        require(msg.sender == offchainUpdater, "Only offchainUpdater");
        offchainTotalSupply = _offchainTotalSupply;
        emit TotalSupplyOffchainUpdated(offchainTotalSupply, block.timestamp);
    }

    /// @inheritdoc ITotalSupplyOracle
    function setOffchainUpdater(address _offchainUpdater) external onlyGovernor {
        offchainUpdater = _offchainUpdater;
        emit OffchainUpdaterUpdated(offchainUpdater);
    }

    /// @inheritdoc ITotalSupplyOracle
    function overwriteCrosschainTotalSupply(uint256 eid, uint256 _crosschainTotalSupply) external onlyGovernor {
        uint256 oldCrosschainTotalSupply = crosschainTotalSupply[eid];
        crosschainTotalSupply[eid] = _crosschainTotalSupply;
        emit CrosschainTotalSupplyUpdated(eid, oldCrosschainTotalSupply, _crosschainTotalSupply);
    }

    /// @inheritdoc ITotalSupplyOracle
    function overwriteOnchainTotalSupply(uint256 _onchainTotalSupply) external onlyGovernor {
        l2chainTotalSupply = _onchainTotalSupply;
        emit TotalSupplyOnchainUpdated(l2chainTotalSupply);
    }

    /// @inheritdoc ITotalSupplyOracle
    function setCrosschainTotalSupply(uint256 eid, uint256 _crosschainTotalSupply) external onlyBridge {
        uint256 oldCrosschainTotalSupply = crosschainTotalSupply[eid];
        crosschainTotalSupply[eid] = _crosschainTotalSupply;
        emit CrosschainTotalSupplyUpdated(eid, oldCrosschainTotalSupply, _crosschainTotalSupply);

        l2chainTotalSupply = l2chainTotalSupply - oldCrosschainTotalSupply + _crosschainTotalSupply;
        emit TotalSupplyOnchainUpdated(l2chainTotalSupply);
    }
}
