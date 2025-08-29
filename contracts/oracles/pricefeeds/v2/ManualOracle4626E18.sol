// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "../../../interfaces/IOracleV2.sol";
import "../../../interfaces/IRateProvider.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ManualOracle
 * @notice An oracle that allows the operator to set the price.
 * @dev This oracle is used to set the price of a token.
 * @dev The operator is the address that can set the price.
 * @dev The price is set in 1e18.
 */
contract ManualOracle4626E18 is IOracleV2, Ownable {
    /// @notice The price in USD
    uint256 public priceUsd;

    /// @notice The price in RZR
    uint256 public priceRzr;

    IRateProvider public immutable rateProvider;

    /// @notice Event emitted when the price is set
    event PriceSet(uint256 priceUsd, uint256 priceRzr);

    /// @notice The asset
    IERC20Metadata public immutable asset;

    /// @notice Constructor
    /// @param _priceUsd The initial price in USD
    /// @param _priceRzr The initial price in RZR
    /// @param _asset The asset
    /// @param _rateProvider The rate provider
    constructor(uint256 _priceRzr, uint256 _priceUsd, address _asset, address _rateProvider) Ownable(msg.sender) {
        priceRzr = _priceRzr;
        priceUsd = _priceUsd;
        asset = IERC20Metadata(_asset);
        rateProvider = IRateProvider(_rateProvider);
    }

    /// @notice Sets the price
    /// @param _priceUsd The price in USD
    /// @param _priceRzr The price in RZR
    function setPrice(uint256 _priceUsd, uint256 _priceRzr) external onlyOwner {
        require(_priceUsd > 0, "Invalid price");
        require(_priceRzr > 0, "Invalid price");
        priceUsd = _priceUsd;
        priceRzr = _priceRzr;
        emit PriceSet(priceUsd, priceRzr);
    }

    /// @inheritdoc IOracleV2
    function getPriceForAmount(uint256 amount)
        external
        view
        override
        returns (uint256 rzrAssets, uint256 usdAssets, uint256 lastUpdatedAt)
    {
        uint256 rate = rateProvider.getRate();
        rzrAssets = (priceRzr * amount * rate) / 1e36;
        usdAssets = (priceUsd * amount * rate) / 1e36;
        lastUpdatedAt = block.timestamp;
    }
}
