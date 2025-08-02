// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.28;

import "../interfaces/IAppOracle.sol";
import "../interfaces/IOracleV2.sol";
import "../interfaces/IApp.sol";
import "./AppAccessControlled.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title OracleRepository
 * @notice Central repository for managing token oracles
 * @dev Allows adding, updating, and removing oracles for different tokens
 */
contract AppOracle is IAppOracle, AppAccessControlled {
    mapping(IERC20Metadata => IOracleV2) public oracles;
    mapping(IERC20Metadata => uint256) public maxStaleness;
    uint256 private _floorPrice; // in USD with 18 decimals

    IApp public app;

    /// @inheritdoc IAppOracle
    function initialize(address _authority, address _app) external initializer {
        __AppAccessControlled_init(_authority);
        app = IApp(_app);
        if (_floorPrice == 0) _floorPrice = 1e18; // Start at 1 USD
    }

    /// @inheritdoc IAppOracle
    function updateOracle(address _token, address _oracle, uint256 _maxStaleness) external onlyGovernor {
        if (address(_token) == address(0)) revert InvalidTokenAddress();
        if (address(_oracle) == address(0)) revert InvalidOracleAddress();

        oracles[IERC20Metadata(_token)] = IOracleV2(_oracle);
        maxStaleness[IERC20Metadata(_token)] = _maxStaleness;

        (uint256 rzrAmount, uint256 usdAmount, uint256 lastUpdatedAt) = IOracleV2(_oracle).getPriceForAmount(1e18);
        require(rzrAmount > 0 || usdAmount > 0, "Invalid price");
        _checkStaleness(_maxStaleness, lastUpdatedAt);

        emit OracleUpdated(_token, _oracle, _maxStaleness);
    }

    /// @inheritdoc IAppOracle
    function getPrice(address token)
        public
        view
        returns (uint256 rzrAmount, uint256 usdAmount, uint256 lastUpdatedAt)
    {
        return getPriceForAmount(token, 1e18);
    }

    /// @notice Get the price of a token in USD
    /// @param token The address of the token
    /// @return usdAmount The price of the token in USD
    function getPriceUsd(address token) external view returns (uint256 usdAmount) {
        (, usdAmount,) = getPriceForAmount(token, 1e18);
    }

    /// @notice Get the price of a token in RZR
    /// @param token The address of the token
    /// @return rzrAmount The price of the token in RZR
    function getPriceRzr(address token) external view returns (uint256 rzrAmount) {
        (rzrAmount,,) = getPriceForAmount(token, 1e18);
    }

    /// @inheritdoc IAppOracle
    function getPriceForAmount(address token, uint256 amount)
        public
        view
        returns (uint256 rzrAmount, uint256 usdAmount, uint256 lastUpdatedAt)
    {
        IOracleV2 oracle = oracles[IERC20Metadata(token)];
        if (address(oracle) == address(0)) revert OracleNotFound(token);

        (rzrAmount, usdAmount, lastUpdatedAt) = oracle.getPriceForAmount(amount);

        _checkStaleness(maxStaleness[IERC20Metadata(token)], lastUpdatedAt);
    }

    /// @inheritdoc IAppOracle
    function getPriceForAmountInFloor(address token, uint256 amount)
        external
        view
        returns (uint256 rzrAmount, uint256 usdAmount, uint256 lastUpdatedAt)
    {
        (rzrAmount, usdAmount, lastUpdatedAt) = getPriceForAmount(token, amount);
        usdAmount = usdAmount * 1e18 / _floorPrice;
    }

    /// @inheritdoc IAppOracle
    function getTokenPrice() external view returns (uint256) {
        return _floorPrice;
    }

    /// @inheritdoc IAppOracle
    function setTokenPrice(uint256 newFloorPrice) external onlyPolicy {
        require(newFloorPrice >= _floorPrice, "floor price can only increase");

        uint256 oldPrice = _floorPrice;
        _floorPrice = newFloorPrice;

        emit FloorPriceUpdated(oldPrice, newFloorPrice);

        // ensure that the treasury has enough RZR to cover the new floor price
        // IAccounting accounting = IAccounting(authority.accounting());
        // uint256 totalSupply = accounting.totalSupply();

        // uint256 currentRZR = accounting.calculateReserves();
        // require(currentRZR >= totalSupply, "treasury backing would fail");
    }

    function _checkStaleness(uint256 staleness, uint256 lastUpdatedAt) internal view {
        require(block.timestamp - lastUpdatedAt < staleness, "Oracle is stale");
    }
}
