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
    IOracleV2 public oracle0;
    IOracleV2 public oracle1;
    uint256 public maxDeviationPercent; // In basis points (1% = 100)

    IERC20Metadata public immutable asset;

    event MaxDeviationUpdated(uint256 newMaxDeviation);

    error ExcessiveDeviation(uint256 price0, uint256 price1, uint256 deviation);

    /**
     * @notice Constructor
     * @param _oracle0 First oracle
     * @param _oracle1 Second oracle
     * @param _maxDeviationPercent Maximum allowed deviation in basis points (1% = 100)
     */
    constructor(IOracleV2 _oracle0, IOracleV2 _oracle1, uint256 _maxDeviationPercent, address _asset) {
        require(address(_oracle0) != address(0), "Invalid oracle0 address");
        require(address(_oracle1) != address(0), "Invalid oracle1 address");
        require(_maxDeviationPercent > 0 && _maxDeviationPercent <= 1000, "Invalid max deviation"); // Max 10%

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
        (, uint256 price0, uint256 lastUpdatedAt0) = oracle0.getPriceForAmount(amount);
        (, uint256 price1, uint256 lastUpdatedAt1) = oracle1.getPriceForAmount(amount);

        // Calculate deviation as a percentage
        uint256 deviation;
        if (price0 > price1) {
            deviation = ((price0 - price1) * 10000) / price1; // Convert to basis points
        } else {
            deviation = ((price1 - price0) * 10000) / price0; // Convert to basis points
        }

        // Check if deviation exceeds maximum allowed
        if (deviation > maxDeviationPercent) {
            revert ExcessiveDeviation(price0, price1, deviation);
        }

        // Return average price
        usdAmount = (price0 + price1) / 2;
        lastUpdatedAt = Math.min(lastUpdatedAt0, lastUpdatedAt1);
    }
}
