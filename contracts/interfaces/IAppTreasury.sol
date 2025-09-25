// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "./IAppOracle.sol";
import "./IApp.sol";
import "./IRateProvider.sol";

interface IAppTreasury {
    /**
     * @notice Gets the app
     * @return app_ The app
     */
    function app() external view returns (IApp app_);

    /**
     * @notice allow approved address to deposit an asset for app
     * @param _amount uint256 amount of token to deposit
     * @param _token address of token to deposit
     * @param _profit uint256 amount of profit to mint
     * @return send_ uint256 amount of app minted
     */
    function deposit(uint256 _amount, address _token, uint256 _profit) external returns (uint256 send_);

    /**
     * @notice Returns the value of a token in RZR, 18 decimals
     * @param _token The address of the token
     * @param _amount The amount of the token
     * @return rzrValue_ The value of the token in RZR
     * @return usdValue_ The value of the token in USD
     */
    function tokenValueE18(address _token, uint256 _amount)
        external
        view
        returns (uint256 rzrValue_, uint256 usdValue_);

    /**
     * @notice Returns the value of a token in RZR, 18 decimals
     * @param _token The address of the token
     * @return rzrValue_ The value of the token in RZR
     * @return usdValue_ The value of the token in USD
     */
    function tokenValueE18(address _token) external view returns (uint256 rzrValue_, uint256 usdValue_);

    /**
     * @notice allow approved address to manage the reserves of the treasury
     * @param _token address of the token to manage
     * @param _amount amount of the token to manage
     * @param _recipient address of the recipient
     * @return rzrValue_ amount of app that was managed in RZR terms
     * @return usdValue_ amount of app that was managed in USD terms
     */
    function manage(address _token, uint256 _amount, address _recipient)
        external
        returns (uint256 rzrValue_, uint256 usdValue_);

    /**
     * @notice allow approved address to enable a token as a reserve
     * @param _address address to enable
     */
    function enable(address _address) external;

    /**
     * @notice allow approved address to disable a token as a reserve
     * @param _address address to disable
     */
    function disable(address _address) external;

    /**
     * @notice Returns the total reserves of the treasury in USD terms (including credit and debit)
     * @return totalReserves_ The total reserves of the treasury in USD terms
     * @dev This is the total USD reserves of the treasury, including credit and debit
     */
    function totalReservesUsd() external view returns (uint256);

    /**
     * @notice Returns the total reserves of the treasury in RZR terms (including credit and debit)
     * @return totalReserves_ The total reserves of the treasury in RZR terms
     * @dev This is the total RZR reserves of the treasury, including credit and debit
     */
    function totalReservesRzr() external view returns (uint256);

    /**
     * @notice Sets the reserve fee
     * @param _reserveFee The new reserve fee
     */
    function setReserveFee(uint256 _reserveFee) external;

    /**
     * @notice Syncs the reserves of the treasury
     */
    function syncReserves() external returns (uint256 usdReserves, uint256 rzrReserves);

    /**
     * @notice Calculates the total reserves of the treasury in RZR terms (including credit and debit)
     * @return usdReserves_ The total reserves of the treasury in USD terms
     * @return rzrReserves_ The total reserves of the treasury in RZR terms
     */
    function calculateReserves() external view returns (uint256 usdReserves_, uint256 rzrReserves_);

    /**
     * @notice Gets the reserve fee
     * @return reserveFee_ The reserve fee
     */
    function reserveFee() external view returns (uint256 reserveFee_);

    /**
     * @notice Gets the app oracle
     * @return appOracle_ The app oracle
     */
    function appOracle() external view returns (IAppOracle appOracle_);

    /**
     * @notice Gets the enabled tokens
     * @return enabledTokens_ The enabled tokens
     */
    function enabledTokens(address _token) external view returns (bool enabledTokens_);

    /**
     * @notice Gets the tokens enabled in the treasury
     * @return tokens_ The tokens
     */
    function tokens() external view returns (address[] memory tokens_);

    /**
     * @notice Gets the token at a given index in the enabled tokens array
     * @param _index The index of the token
     * @return token_ The token at the given index
     */
    function tokenAt(uint256 _index) external view returns (address token_);

    /**
     * @notice Gets the number of enabled tokens
     * @return length_ The number of enabled tokens
     */
    function enabledTokensLength() external view returns (uint256 length_);

    /**
     * @notice Registers a rate provider for an asset
     * @param _asset The asset to register the rate provider for
     * @param _rateProvider The rate provider to register
     */
    function registerRateProvider(address _asset, address _rateProvider) external;

    /**
     * @notice Sets the revenue destination
     * @param _revenueDestination The revenue destination
     */
    function setRevenueDestination(address _revenueDestination) external;

    /**
     * @notice Collects the revenue for an asset
     * @param _asset The asset to collect the revenue for
     */
    function collectRevenue(address _asset) external;

    /**
     * @notice Collects the revenue for multiple assets
     * @param _assets The assets to collect the revenue for
     */
    function collectRevenueMultiple(address[] calldata _assets) external;

    /**
     * @notice Gets the revenue destination
     * @return revenueDestination_ The revenue destination
     */
    function revenueDestination() external view returns (address revenueDestination_);

    /**
     * @notice Gets the rate provider for an asset
     * @param _asset The asset to get the rate provider for
     * @return rateProvider_ The rate provider
     */
    function rateProviders(address _asset) external view returns (address rateProvider_);

    /**
     * @notice Gets the rate snapshot for an asset
     * @param _asset The asset to get the rate snapshot for
     * @return rateSnapshot_ The rate snapshot
     */
    function rateSnapshots(address _asset) external view returns (uint256 rateSnapshot_);

    /* ========== EVENTS ========== */

    event Deposit(address indexed token, uint256 amount, uint256 usdValue, uint256 rzrValue);
    event Withdrawal(address indexed token, uint256 amount, uint256 usdValue, uint256 rzrValue);
    event Managed(address indexed token, uint256 amount);
    event ReservesAudited(uint256 indexed totalReserves, uint256 indexed totalReservesWithCredit);
    event Minted(address indexed caller, address indexed recipient, uint256 amount);
    event TokenEnabled(address addr, bool result);
    event ReserveFeeSet(uint256 newFee, uint256 oldFee);
    event RateProviderRegistered(address indexed asset, address indexed rateProvider, uint256 indexed rateSnapshot);
    event RevenueDestinationSet(address indexed revenueDestination);
    event RevenueCollected(
        address indexed asset, uint256 revenue, uint256 revenueToProtocol, uint256 revenueToTreasury
    );
}
