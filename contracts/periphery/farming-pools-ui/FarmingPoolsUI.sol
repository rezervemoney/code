// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.28;

import {IOracleV2} from "contracts/interfaces/IOracleV2.sol";
import {IFarmingPoolsUI} from "contracts/interfaces/IFarmingPoolsUI.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title FarmingPoolsUI
 * @dev Unified contract to fetch user data from various farming pools with optimized structure
 * @notice This contract provides both unified and individual pool data access methods
 */
contract FarmingPoolsUI is AccessControl, IFarmingPoolsUI {
    mapping(address => PoolConfig) private _poolConfigs;
    address public rzrOracle;
    
    constructor(address _rzrOracle) {
        rzrOracle = _rzrOracle;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /// @inheritdoc IFarmingPoolsUI
    function getPoolData(address user, address pool) external view returns (PoolData memory) {
        return _getPoolData(user, pool);
    }

    /// @inheritdoc IFarmingPoolsUI
    function getAllPoolsData(address user, address[] calldata pools) external view returns (PoolData[] memory) {
        PoolData[] memory results = new PoolData[](pools.length);

        for (uint256 i = 0; i < pools.length; i++) {
            results[i] = _getPoolData(user, pools[i]);
        }

        return results;
    }
    
    /// @inheritdoc IFarmingPoolsUI
    function setRzrOracle(address _rzrOracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_rzrOracle == address(0)) revert ZeroAddress();
        
        address oldOracle = rzrOracle;
        rzrOracle = _rzrOracle;
        
        emit RzrOracleUpdated(oldOracle, _rzrOracle);
    }

    /// @inheritdoc IFarmingPoolsUI
    function setPoolConfig(PoolConfig calldata poolConfig) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (poolConfig.poolAddress == address(0)) revert InvalidPoolAddress();
        
        _poolConfigs[poolConfig.poolAddress] = poolConfig;
        
        emit PoolConfigSet(
            poolConfig.poolAddress,
            poolConfig.poolType,
            poolConfig.gauge,
            poolConfig.oracle
        );
    }

    /// @inheritdoc IFarmingPoolsUI
    function batchSetPoolConfigs(PoolConfig[] calldata poolsConfigs) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < poolsConfigs.length; i++) {
            _poolConfigs[poolsConfigs[i].poolAddress] = poolsConfigs[i];
            
            emit PoolConfigSet(
                poolsConfigs[i].poolAddress,
                poolsConfigs[i].poolType,
                poolsConfigs[i].gauge,
                poolsConfigs[i].oracle
            );
        }
    }

    /// @inheritdoc IFarmingPoolsUI
    function getPoolConfig(address pool) external view returns (PoolConfig memory) {
        return _poolConfigs[pool];
    }

    /// @inheritdoc IFarmingPoolsUI
    function isPoolConfigured(address pool) external view returns (bool) {
        return _poolConfigs[pool].poolAddress != address(0);
    }

    /// @inheritdoc IFarmingPoolsUI
    function poolConfigs(address pool) external view returns (PoolConfig memory) {
        return _poolConfigs[pool];
    }

    /// @dev Core function to get protocol data
    function _getPoolData(address user, address pool) internal view returns (PoolData memory poolData) {
        PoolConfig memory config = _poolConfigs[pool];

        if (config.poolAddress == address(0)) {
            return poolData;
        }

        // Get LP token balance
        uint256 lpBalance = ERC20(pool).balanceOf(user);

        // Get staked balance
        uint256 stakedBalance = config.gauge != address(0) ? ERC20(config.gauge).balanceOf(user) : 0;

        // Get USD value
        uint256 usdValue = 0;
        if (config.oracle != address(0)) {
            (uint256 rzrAssets, uint256 price, ) = IOracleV2(config.oracle).getPriceForAmount(10 ** 18);
            usdValue = price;
            if (usdValue == 0) {
                (, uint256 usdPrice, ) = IOracleV2(rzrOracle).getPriceForAmount(rzrAssets);
                usdValue = usdPrice;
            }
        }

        poolData = PoolData({
            poolAddress: pool,
            poolType: config.poolType,
            lpBalance: lpBalance,
            stakedBalance: stakedBalance,
            usdValue: usdValue
        });
    }
}
