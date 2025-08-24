// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "../../../interfaces/IOracleV2.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract Adapter4626Oracle is IOracleV2 {
    IERC4626 public immutable VAULT;

    IERC20Metadata public immutable asset;

    constructor(IERC4626 _vault, address _asset) {
        VAULT = _vault;
        asset = IERC20Metadata(_asset);
    }

    /// @inheritdoc IOracleV2
    function getPriceForAmount(uint256 amount)
        external
        view
        override
        returns (uint256 rzrAssets, uint256 usdAssets, uint256 lastUpdatedAt)
    {
        rzrAssets = VAULT.convertToAssets(amount);
        usdAssets = 0;
        lastUpdatedAt = block.timestamp;
    }
}
