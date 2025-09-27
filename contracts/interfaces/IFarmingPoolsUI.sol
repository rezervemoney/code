// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.28;


interface IFarmingPoolsUI {
    /**
     * @dev Thrown when a zero address is provided where it's not allowed
     */
    error ZeroAddress();

    /**
     * @dev Thrown when an invalid pool address is provided
     */
    error InvalidPoolAddress();

    /**
     * @dev Emitted when a pool configuration is set
     * @param pool The address of the pool
     * @param poolType The type of the pool
     * @param gauge The gauge address
     * @param oracle The oracle address
     */
    event PoolConfigSet(address indexed pool, PoolType poolType, address gauge, address oracle);

    /**
     * @dev Emitted when the RZR oracle is updated
     * @param oldOracle The previous oracle address
     * @param newOracle The new oracle address
     */
    event RzrOracleUpdated(address indexed oldOracle, address indexed newOracle);

    /**
     * @dev Pool data structure containing all relevant information about a user's position in a pool
     * @param poolAddress The address of the farming pool
     * @param poolType The type of pool (PENDLE, SPECTRA, BEETS, etc.)
     * @param lpBalance The user's LP token balance in the pool
     * @param stakedBalance The user's staked balance in the gauge (if applicable)
     * @param usdValue The USD value of the user's position
     */
    struct PoolData {
        address poolAddress;
        PoolType poolType;
        uint256 lpBalance;
        uint256 stakedBalance;
        uint256 usdValue;
    }

    /**
     * @dev Pool configuration structure for setting up pool parameters
     * @param poolAddress The address of the farming pool
     * @param poolType The type of pool (PENDLE, SPECTRA, BEETS, etc.)
     * @param gauge The address of the gauge contract for staking (if applicable)
     * @param oracle The address of the oracle contract for price feeds
     */
    struct PoolConfig {
        address poolAddress;
        PoolType poolType;
        address gauge;
        address oracle;
    }

    /**
     * @dev Enumeration of supported farming pool types
     * @notice Each pool type represents a different DeFi protocol or farming mechanism
     */
    enum PoolType {
        PENDLE, // Pendle protocol pools
        SPECTRA, // Spectra protocol pools
        BEETS, // Beethoven X (Beets) pools
        SHADOW, // Shadow protocol pools
        EQUALIZER, // Equalizer protocol pools
        EULER, // Euler protocol pools
        REZERVE, // Rezerve protocol pools
        BALANCER, // Balancer protocol pools
        CURVE, // Curve protocol pools
        UNISWAP // Uniswap protocol pools
    }

    /**
     * @dev Get data for a single pool - main entry point
     * @param user User address to get data for
     * @param pool Pool address
     * @return PoolData struct with all relevant information
     */
    function getPoolData(address user, address pool) external view returns (PoolData memory);

    /**
     * @dev Get data for multiple pools in a single call - most efficient
     * @param user User address to get data for
     * @param pools Array of pool addresses
     * @return Array of PoolData structs
     */
    function getAllPoolsData(address user, address[] calldata pools) external view returns (PoolData[] memory);

    /**
     * @dev Set RZR oracle address
     * @param _rzrOracle RZR oracle address
     * @notice Only callable by admin role
     */
    function setRzrOracle(address _rzrOracle) external;

    /**
     * @dev Set complete pool configuration in one call
     * @param poolConfig Pool configuration to set
     * @notice Only callable by admin role
     */
    function setPoolConfig(PoolConfig calldata poolConfig) external;

    /**
     * @dev Batch set multiple pool configurations
     * @param poolsConfigs Array of pool configurations to set
     * @notice Only callable by admin role
     */
    function batchSetPoolConfigs(PoolConfig[] calldata poolsConfigs) external;

    /**
     * @dev Get pool configuration
     * @param pool Pool address to get configuration for
     * @return PoolConfig struct with pool configuration
     */
    function getPoolConfig(address pool) external view returns (PoolConfig memory);

    /**
     * @dev Check if pool is configured
     * @param pool Pool address to check
     * @return True if pool is configured, false otherwise
     */
    function isPoolConfigured(address pool) external view returns (bool);

    /**
     * @dev Get the RZR oracle address
     * @return The address of the RZR oracle contract
     */
    function rzrOracle() external view returns (address);

    /**
     * @dev Get pool configuration by address
     * @param pool Pool address to get configuration for
     * @return PoolConfig struct with pool configuration
     */
    function poolConfigs(address pool) external view returns (PoolConfig memory);

    /**
     * @dev Get the total number of configured pools
     * @return The length of the markets array
     */
    function length() external view returns (uint256);

    /**
     * @dev Get paginated pool data for all configured pools for a specific user
     * @param user User address to get data for
     * @param startingIndex Starting index
     * @param endingIndex Ending index
     * @return Array of PoolData structs for the requested page
     * @notice Similar to getAllStakingPositions in AppUIHelperRead with pagination
     */
    function getAllPoolsDataPaginated(
        address user,
        uint256 startingIndex,
        uint256 endingIndex
    ) external view returns (PoolData[] memory);
}
