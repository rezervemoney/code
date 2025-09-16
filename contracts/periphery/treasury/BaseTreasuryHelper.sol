// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import {AppAccessControlled} from "../../core/AppAccessControlled.sol";
import {IAppTreasury} from "../../interfaces/IAppTreasury.sol";
import {IApp} from "../../interfaces/IApp.sol";

abstract contract BaseTreasuryHelper is AppAccessControlled {
    bool public killed;

    modifier whenNotKilled() {
        _whenNotKilled();
        _;
    }

    /// @notice Initializes the contract
    function __BaseTreasuryHelper_init(address _authority) internal {
        __AppAccessControlled_init(_authority);
    }

    /// @notice Returns the treasury
    /// @dev This will return the treasury
    function _treasury() internal view returns (IAppTreasury) {
        return IAppTreasury(authority.treasury());
    }

    /// @notice Returns the rzr app
    /// @dev This will return the rzr app
    function _rzr() internal view returns (IApp) {
        return _treasury().app();
    }

    /// @notice Mints rzr
    /// @dev This will mint rzr
    function _mint(address to, uint256 amount) internal {
        _rzr().mint(to, amount);
    }

    /// @notice Burns rzr
    /// @dev This will burn rzr
    function _burn(uint256 amount) internal {
        _rzr().burn(amount);
    }

    /// @notice Burns the pending balance of rzr
    /// @dev This will burn the pending balance of rzr
    function _burnPendingBalance() internal {
        uint256 pendingBalance = _rzr().balanceOf(address(this));
        _burn(pendingBalance);
    }

    /// @notice Kills the contract
    /// @dev This will prevent the contract from being used
    function kill() public onlyGuardianOrGovernor {
        killed = true;
    }

    function _whenNotKilled() internal view {
        require(!killed, "BaseTreasuryHelper: killed");
    }
}
