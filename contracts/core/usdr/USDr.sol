// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "../AppAccessControlled.sol";
import "../../interfaces/IApp.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @title USDR
/// @notice USDR is a stablecoin that is used to lock debt for the Rezerve.money protocol
contract USDR is ERC20Permit, AppAccessControlled, IApp {
    /// @notice Constructor
    /// @param _authority The address of the authority
    /// @dev This function is only callable once
    constructor(address _authority) ERC20("Rezerve.money USD", "USDR") ERC20Permit("Rezerve.money USD") {
        __AppAccessControlled_init(_authority);
        _mint(msg.sender, 1e18);
        _burn(msg.sender, 1e18);
    }

    /// @notice Mint function is only callable by the policy
    /// @dev This function is only callable by the policy
    /// @param account_ The address of the recipient
    /// @param amount_ The amount of tokens to mint
    function mint(address account_, uint256 amount_) external override onlyPolicy whenNotPaused {
        _mint(account_, amount_);
    }

    /// @notice Burn function is only callable by the policy
    /// @dev This function is only callable by the policy
    /// @param amount The amount of tokens to burn
    function burn(uint256 amount) external override onlyPolicy whenNotPaused {
        _burn(msg.sender, amount);
    }

    /// @inheritdoc ERC20
    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);
        _ensureUnpaused();
    }
}
