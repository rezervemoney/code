// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IOracleV2 {
    /// @notice Get the asset of the oracle
    /// @return asset The address of the asset
    function asset() external view returns (IERC20Metadata);

    /// @notice Get the price of an asset for a given amount
    /// @dev If the asset is an LP token, the RZR and USD amounts are the amounts of RZR and USD in the LP
    /// @param amount The amount of the asset to get the price of
    /// @return rzrAssets The amount of RZR assets
    /// @return usdAssets The amount of USD assets
    /// @return lastUpdatedAt The timestamp of the last update
    function getPriceForAmount(uint256 amount)
        external
        view
        returns (uint256 rzrAssets, uint256 usdAssets, uint256 lastUpdatedAt);
}
