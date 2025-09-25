// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IRateProvider.sol";

contract MockRateProvider is IRateProvider {
    uint256 private _rate;
    address public owner;

    event RateUpdated(uint256 oldRate, uint256 newRate);

    constructor(uint256 _initialRate) {
        _rate = _initialRate;
        owner = msg.sender;
    }

    function getRate() external view override returns (uint256) {
        return _rate;
    }

    function setRate(uint256 _newRate) external {
        require(msg.sender == owner, "Only owner can set rate");
        uint256 oldRate = _rate;
        _rate = _newRate;
        emit RateUpdated(oldRate, _newRate);
    }

    function increaseRate(uint256 _increase) external {
        require(msg.sender == owner, "Only owner can increase rate");
        uint256 oldRate = _rate;
        _rate += _increase;
        emit RateUpdated(oldRate, _rate);
    }

    function decreaseRate(uint256 _decrease) external {
        require(msg.sender == owner, "Only owner can decrease rate");
        require(_rate >= _decrease, "Rate cannot be negative");
        uint256 oldRate = _rate;
        _rate -= _decrease;
        emit RateUpdated(oldRate, _rate);
    }
}
