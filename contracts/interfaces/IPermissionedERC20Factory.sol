// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import {IPermissionedERC20} from "./IPermissionedERC20.sol";

interface IPermissionedERC20Factory {
    function createPermissionedERC20(string memory name, string memory symbol, uint8 decimals)
        external
        returns (IPermissionedERC20);
}
