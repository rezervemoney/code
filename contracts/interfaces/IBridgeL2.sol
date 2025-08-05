// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "./IBridge.sol";

interface IBridgeL2 is IBridge {
    /// @notice Get the state of the bridge
    /// @dev This function is used to get the state of the bridge
    function data() external view returns (uint32, uint256, uint256, uint256);
}
