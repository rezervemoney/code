// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../../../interfaces/IOracleV2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CappedOracle
 * @notice This contract takes an oracle and reverts if the price is outside of a certain range
 * @dev Uses a percentage-based deviation check to ensure oracle reliability
 */
contract CappedOracle is IOracleV2 {
    /// @notice The oracle to cap
    IOracleV2 public oracle;

    /// @notice Maximum allowed upper bound for USD
    uint256 public maxUpperBoundUsd;

    /// @notice Maximum allowed lower bound for USD
    uint256 public maxLowerBoundUsd;

    /// @notice Maximum allowed upper bound for RZR
    uint256 public maxUpperBoundRzr;

    /// @notice Maximum allowed lower bound for RZR
    uint256 public maxLowerBoundRzr;

    /// @notice The asset
    IERC20Metadata public immutable asset;

    /**
     * @notice Constructor
     * @param _oracle Oracle
     * @param _maxUpperBoundUsd Maximum allowed upper bound for USD
     * @param _maxLowerBoundUsd Maximum allowed lower bound for USD
     * @param _maxUpperBoundRzr Maximum allowed upper bound for RZR
     * @param _maxLowerBoundRzr Maximum allowed lower bound for RZR
     */
    constructor(
        IOracleV2 _oracle,
        uint256 _maxUpperBoundUsd,
        uint256 _maxLowerBoundUsd,
        uint256 _maxUpperBoundRzr,
        uint256 _maxLowerBoundRzr,
        address _asset
    ) {
        require(address(_oracle) != address(0), "Invalid oracle address");
        oracle = _oracle;
        maxUpperBoundUsd = _maxUpperBoundUsd;
        maxLowerBoundUsd = _maxLowerBoundUsd;
        maxUpperBoundRzr = _maxUpperBoundRzr;
        maxLowerBoundRzr = _maxLowerBoundRzr;
        asset = IERC20Metadata(_asset);

        require(_maxUpperBoundUsd > _maxLowerBoundUsd, "Invalid USD bounds");
        require(_maxUpperBoundRzr > _maxLowerBoundRzr, "Invalid RZR bounds");
        require(_oracle.asset() == asset, "Oracle asset mismatch");
    }

    /// @inheritdoc IOracleV2
    function getPriceForAmount(uint256 amount)
        external
        view
        override
        returns (uint256 rzrAssets, uint256 usdAssets, uint256 lastUpdatedAt)
    {
        (rzrAssets, usdAssets, lastUpdatedAt) = oracle.getPriceForAmount(amount);

        // Calculate deviation as a percentage
        require(usdAssets <= maxUpperBoundUsd, "Price exceeds upper bound");
        require(usdAssets >= maxLowerBoundUsd, "Price exceeds lower bound");
        require(rzrAssets <= maxUpperBoundRzr, "Price exceeds upper bound");
        require(rzrAssets >= maxLowerBoundRzr, "Price exceeds lower bound");

        return (rzrAssets, usdAssets, lastUpdatedAt);
    }
}
