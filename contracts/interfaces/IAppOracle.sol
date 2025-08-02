// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IAppOracle {
    event OracleUpdated(address indexed token, address indexed oracle, uint256 maxStaleness);
    event FloorPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event PriceFetched(
        address indexed token, uint256 amount, uint256 rzrAmount, uint256 usdAmount, uint256 lastUpdatedAt
    );

    // Errors
    error OracleNotFound(address token);
    error OracleAlreadyExists(address token);
    error OracleInactive(address token);
    error InvalidOracleAddress();
    error InvalidTokenAddress();

    /// @notice Initializes the AppOracle contract
    /// @dev This function is only callable once
    /// @param _authority The address of the authority contract
    /// @param _app The address of the app contract
    function initialize(address _authority, address _app) external;

    /**
     * @notice Update the oracle for a token
     * @param token The token address
     * @param oracle The oracle contract
     */
    function updateOracle(address token, address oracle, uint256 maxStaleness) external;

    /**
     * @notice Get the price for a token
     * @param token The token address
     * @return rzrAmount The token price in RZR
     * @return usdAmount The token price in USD
     * @return lastUpdatedAt The timestamp of the last update
     */
    function getPrice(address token)
        external
        view
        returns (uint256 rzrAmount, uint256 usdAmount, uint256 lastUpdatedAt);

    /**
     * @notice Get the price for a token in RZR for an amount
     * @param token The token address
     * @param amount The amount of the token
     * @return rzrAmount The token price in RZR for the amount
     * @return usdAmount The token price in USD for the amount
     * @return lastUpdatedAt The timestamp of the last update
     */
    function getPriceForAmount(address token, uint256 amount)
        external
        view
        returns (uint256 rzrAmount, uint256 usdAmount, uint256 lastUpdatedAt);

    /**
     * @notice Get the price for a token in RZR for an amount in the floor price
     * @param token The token address
     * @param amount The amount of the token
     * @return rzrAmount The token price in RZR for the amount
     * @return usdAmount The token price in USD for the amount
     * @return lastUpdatedAt The timestamp of the last update
     */
    function getPriceForAmountInFloor(address token, uint256 amount)
        external
        view
        returns (uint256 rzrAmount, uint256 usdAmount, uint256 lastUpdatedAt);

    /**
     * @notice Get the floor price for RZR
     * @return price The RZR floor price
     */
    function getTokenPrice() external view returns (uint256);

    /**
     * @notice Set the floor price for RZR
     * @param newFloorPrice The new RZR price
     */
    function setTokenPrice(uint256 newFloorPrice) external;
}
