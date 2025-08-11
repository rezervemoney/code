// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import "./AppAccessControlled.sol";
import "../interfaces/IAppOracle.sol";
import "../interfaces/IApp.sol";
import "../interfaces/IAppTreasury.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract AppTreasury is AppAccessControlled, IAppTreasury, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;
    using SafeERC20 for IApp;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 private _totalReservesUsd;
    uint256 private _totalReservesRzr;

    EnumerableSet.AddressSet private _tokens;

    /// @inheritdoc IAppTreasury
    IApp public override app;

    /// @inheritdoc IAppTreasury
    IAppOracle public appOracle;

    /// @inheritdoc IAppTreasury
    uint256 public reserveFee;

    function initialize(address _app, address _appOracle, address _authority) public reinitializer(12) {
        require(_app != address(0), "Zero address: app");
        require(_appOracle != address(0), "Zero address: appOracle");
        app = IApp(_app);
        appOracle = IAppOracle(_appOracle);
        __AppAccessControlled_init(_authority);
        __ReentrancyGuard_init();
    }

    /// @inheritdoc IAppTreasury
    function setReserveFee(uint256 _reserveFee) external onlyGovernor {
        require(_reserveFee <= 1e18, "Invalid reserve fee");
        emit ReserveFeeSet(_reserveFee, reserveFee);
        reserveFee = _reserveFee;
    }

    /// @inheritdoc IAppTreasury
    function deposit(uint256 _amount, address _token, uint256 _profit)
        external
        override
        nonReentrant
        whenNotPaused
        onlyReserveDepositor
        returns (uint256 send_)
    {
        require(_tokens.contains(_token), "Treasury: invalid token");

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        // send 10% to the treasury
        uint256 fee = _amount * reserveFee / 1e18;
        IERC20(_token).safeTransfer(authority.operationsTreasury(), fee);
        _amount -= fee;

        (uint256 rzrValue, uint256 usdValue) = tokenValueE18(_token, _amount);
        require(rzrValue == 0, "avoid rzr value");
        require(usdValue > 0, "invalid usd value");

        // mint app needed and store amount of rewards for distribution
        send_ = usdValue - _profit;
        app.mint(msg.sender, send_);

        _totalReservesUsd += usdValue;
        _totalReservesRzr += rzrValue;

        // todo add invariant checks

        emit Deposit(_token, _amount, usdValue, rzrValue);
    }

    /// @inheritdoc IAppTreasury
    function manage(address _token, uint256 _amount, address _recipient)
        external
        override
        nonReentrant
        whenNotPaused
        onlyReserveManager
        returns (uint256 rzrValue, uint256 usdValue)
    {
        if (_tokens.contains(_token)) {
            (rzrValue, usdValue) = tokenValueE18(_token, _amount);
            _totalReservesUsd = _totalReservesUsd - usdValue;
            _totalReservesRzr = _totalReservesRzr - rzrValue;
        }

        IERC20(_token).safeTransfer(_recipient, _amount);
        emit Managed(_token, _amount);

        _updateReserves();
    }

    /// @inheritdoc IAppTreasury
    function syncReserves() external onlyBridge returns (uint256 usdReserves, uint256 rzrReserves) {
        _updateReserves();
        return (_totalReservesUsd, _totalReservesRzr);
    }

    /// @inheritdoc IAppTreasury
    function enable(address _address) external onlyGovernor {
        require(_address != address(0), "Zero address");

        // add token into tokens array if not already added
        if (!_tokens.contains(_address)) _tokens.add(_address);

        // ensure the token has a valid price in appOracle contract
        (uint256 rzrAmount, uint256 usdAmount,) = appOracle.getPrice(_address);
        require(rzrAmount > 0 || usdAmount > 0, "Invalid price");
        emit TokenEnabled(_address, true);
    }

    /// @inheritdoc IAppTreasury
    function disable(address _toDisable) external onlyGuardianOrGovernor {
        _tokens.remove(_toDisable);
        emit TokenEnabled(_toDisable, false);
    }

    /// @inheritdoc IAppTreasury
    function tokenValueE18(address _token, uint256 _amount)
        public
        view
        override
        returns (uint256 rzrValue, uint256 usdValue)
    {
        (rzrValue, usdValue,) = appOracle.getPriceForAmountInFloor(_token, _amount);
    }

    /// @inheritdoc IAppTreasury
    function totalReservesUsd() public view override returns (uint256) {
        return _totalReservesUsd;
    }

    /// @inheritdoc IAppTreasury
    function totalReservesRzr() public view override returns (uint256) {
        return _totalReservesRzr;
    }

    /// @inheritdoc IAppTreasury
    function calculateReserves() public view override returns (uint256 usdReserves, uint256 rzrReserves) {
        for (uint256 i = 0; i < _tokens.length(); i++) {
            address token = _tokens.at(i);
            uint256 balance = IERC20(token).balanceOf(address(this));
            (uint256 rzrValue, uint256 usdValue) = tokenValueE18(token, balance);
            usdReserves += usdValue;
            rzrReserves += rzrValue;
        }
    }

    /// @inheritdoc IAppTreasury
    function tokens() public view returns (address[] memory) {
        return _tokens.values();
    }

    /// @inheritdoc IAppTreasury
    function tokenAt(uint256 _index) public view returns (address) {
        return _tokens.at(_index);
    }

    /// @inheritdoc IAppTreasury
    function enabledTokensLength() public view returns (uint256) {
        return _tokens.length();
    }

    /// @inheritdoc IAppTreasury
    function enabledTokens(address _token) public view override returns (bool) {
        return _tokens.contains(_token);
    }

    function _updateReserves() internal {
        (uint256 usdReserves, uint256 rzrReserves) = calculateReserves();
        _totalReservesUsd = usdReserves;
        _totalReservesRzr = rzrReserves;
        emit ReservesAudited(usdReserves, rzrReserves);
    }

    function execute(address _to, uint256 _value, bytes calldata _data) external onlyGovernor {
        (bool success,) = _to.call{value: _value}(_data);
        require(success, "Treasury: execute failed");
    }
}
