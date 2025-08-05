// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../../../interfaces/IOracleV2.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract Adapter4626OracleModified is IOracleV2 {
    IERC4626 public immutable VAULT;
    uint256 public immutable multiplier;
    IERC20Metadata public immutable asset;

    constructor(IERC4626 _vault, address _asset, uint256 _multiplier) {
        VAULT = _vault;
        asset = IERC20Metadata(_asset);
        multiplier = _multiplier;
    }

    /// @inheritdoc IOracleV2
    function getPriceForAmount(uint256 amount)
        external
        view
        override
        returns (uint256 rzrAssets, uint256 usdAssets, uint256 lastUpdatedAt)
    {
        rzrAssets = VAULT.convertToAssets(amount) * multiplier / 1e18;
        usdAssets = 0;
        lastUpdatedAt = block.timestamp;
    }
}
