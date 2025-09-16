// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IAppOracle.sol";

contract MockAppOracle is IAppOracle {
    mapping(address => uint256) public rzrAmounts;
    mapping(address => uint256) public usdAmounts;
    uint256 public tokenPrice = 1e18;

    function setPrice(address asset, uint256 rzrAmount, uint256 usdAmount) external {
        rzrAmounts[asset] = rzrAmount;
        usdAmounts[asset] = usdAmount;
    }

    function getPriceForAmount(address asset, uint256 amount)
        external
        view
        returns (uint256 rzrAmount, uint256 usdAmount, uint256 timestamp)
    {
        rzrAmount = rzrAmounts[asset];
        // The oracle should return the price for the given amount
        // For 6-decimal tokens: if amount is 1e6, return the price for 1e6 tokens (which is 1e18)
        // For 18-decimal tokens: if amount is 1e18, return the price for 1e18 tokens (which is 1e18)
        usdAmount = usdAmounts[asset];
        timestamp = block.timestamp;
    }

    function initialize(address _authority, address _app) external override {
        // Mock implementation
    }

    function updateOracle(address token, address oracle, uint256 maxStaleness) external override {
        // Mock implementation
    }

    function getPrice(address token)
        external
        view
        override
        returns (uint256 rzrAmount, uint256 usdAmount, uint256 lastUpdatedAt)
    {
        rzrAmount = rzrAmounts[token];
        usdAmount = usdAmounts[token];
        lastUpdatedAt = block.timestamp;
    }

    function getPriceForAmountInFloor(address token, uint256 amount)
        external
        view
        override
        returns (uint256 rzrAmount, uint256 usdAmount, uint256 lastUpdatedAt)
    {
        rzrAmount = rzrAmounts[token] * amount / 1e18;
        usdAmount = usdAmounts[token] * amount / 1e18;
        lastUpdatedAt = block.timestamp;
    }

    function getTokenPrice() external view override returns (uint256) {
        return tokenPrice;
    }

    function setTokenPrice(uint256 newFloorPrice) external override {
        tokenPrice = newFloorPrice;
    }
}
