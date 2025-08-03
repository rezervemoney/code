// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "./IBridge.sol";

interface IBridgeL2 is IBridge {
    /// @notice Flush the rzr to the L1 liquid staking
    /// @dev This function is used to flush the rzr to the L1 liquid staking
    /// @dev This function is only callable by the liquid staking
    function syncRzrToL1LiquidStaking() external;

    /// @notice Sync the state to L1
    /// @dev This function is used to sync the state to L1
    /// @dev This function is only callable by the operator
    function syncStateToL1() external payable;
}
