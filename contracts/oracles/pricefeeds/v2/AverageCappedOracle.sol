// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../../../interfaces/IOracleV2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title AverageCappedOracle
 * @notice This contract takes the average of two oracle prices and reverts if they deviate too much
 * @dev Uses a percentage-based deviation check to ensure oracle reliability
 */
contract AverageCappedOracle is IOracleV2 {
    /// @notice The first oracle
    IOracleV2 public immutable oracle0;

    /// @notice The second oracle
    IOracleV2 public immutable oracle1;

    /// @notice The maximum allowed deviation
    uint256 public immutable maxDeviationPercent;

    /// @inheritdoc IOracleV2
    IERC20Metadata public immutable asset;

    /// @notice Emitted when the deviation is too high
    /// @param usdAmount0 The USD amount from oracle0
    /// @param usdAmount1 The USD amount from oracle1
    /// @param deviationUsd The deviation in USD
    /// @param rzrAmount0 The RZR amount from oracle0
    /// @param rzrAmount1 The RZR amount from oracle1
    /// @param deviationRzr The deviation in RZR
    error ExcessiveDeviation(
        uint256 usdAmount0,
        uint256 usdAmount1,
        uint256 deviationUsd,
        uint256 rzrAmount0,
        uint256 rzrAmount1,
        uint256 deviationRzr
    );

    /**
     * @notice Constructor
     * @param _oracle0 First oracle
     * @param _oracle1 Second oracle
     * @param _maxDeviationPercent Maximum allowed deviation
     */
    constructor(IOracleV2 _oracle0, IOracleV2 _oracle1, uint256 _maxDeviationPercent, address _asset) {
        require(address(_oracle0) != address(0), "Invalid oracle0 address");
        require(address(_oracle1) != address(0), "Invalid oracle1 address");
        require(_maxDeviationPercent > 0 && _maxDeviationPercent <= 1e18, "Invalid max deviation"); // Max 10%

        oracle0 = _oracle0;
        oracle1 = _oracle1;
        maxDeviationPercent = _maxDeviationPercent;
        asset = IERC20Metadata(_asset);
    }

    /// @inheritdoc IOracleV2
    function getPriceForAmount(uint256 amount)
        external
        view
        override
        returns (uint256 rzrAmount, uint256 usdAmount, uint256 lastUpdatedAt)
    {
        (uint256 rzrAmount0, uint256 usdAmount0, uint256 lastUpdatedAt0) = oracle0.getPriceForAmount(amount);
        (uint256 rzrAmount1, uint256 usdAmount1, uint256 lastUpdatedAt1) = oracle1.getPriceForAmount(amount);

        // Calculate deviation as a percentage
        uint256 deviationUsd = _maxDeviation(usdAmount0, usdAmount1);
        uint256 deviationRzr = _maxDeviation(rzrAmount0, rzrAmount1);

        // Check if deviation exceeds maximum allowed
        if (deviationUsd > maxDeviationPercent || deviationRzr > maxDeviationPercent) {
            revert ExcessiveDeviation(usdAmount0, usdAmount1, deviationUsd, rzrAmount0, rzrAmount1, deviationRzr);
        }

        // Return average price
        usdAmount = (usdAmount0 + usdAmount1) / 2;
        rzrAmount = (rzrAmount0 + rzrAmount1) / 2;
        lastUpdatedAt = Math.min(lastUpdatedAt0, lastUpdatedAt1);
    }

    /// @notice Calculate the maximum deviation between two prices
    /// @param price0 The first price
    /// @param price1 The second price
    /// @return deviation The maximum deviation
    function _maxDeviation(uint256 price0, uint256 price1) internal pure returns (uint256 deviation) {
        if (price0 > price1) deviation = ((price0 - price1) * 1e18) / price1;
        else deviation = ((price1 - price0) * 1e18) / price0;
    }
}
