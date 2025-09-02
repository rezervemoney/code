// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "./PermissionedERC20.sol";
import "../interfaces/IPermissionedERC20Factory.sol";

contract PermissionedERC20Factory is IPermissionedERC20Factory {
    function createPermissionedERC20(string memory name, string memory symbol, uint8 decimals)
        external
        override
        returns (IPermissionedERC20)
    {
        return new PermissionedERC20(name, symbol, decimals, msg.sender);
    }
}
