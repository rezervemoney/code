// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IPermissionedERC20.sol";

/// @title Mock Permissioned ERC20
/// @notice A mock permissioned ERC20 token for testing
contract MockPermissionedERC20 is ERC20, IPermissionedERC20 {
    mapping(address => bool) public authorizedMinters;
    mapping(address => bool) public authorizedBurners;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    /// @notice Add an authorized minter
    function addMinter(address minter) external {
        authorizedMinters[minter] = true;
    }

    /// @notice Add an authorized burner
    function addBurner(address burner) external {
        authorizedBurners[burner] = true;
    }

    /// @notice Remove an authorized minter
    function removeMinter(address minter) external {
        authorizedMinters[minter] = false;
    }

    /// @notice Remove an authorized burner
    function removeBurner(address burner) external {
        authorizedBurners[burner] = false;
    }

    /// @notice Mint tokens (only authorized minters)
    function mint(address to, uint256 amount) external override {
        require(authorizedMinters[msg.sender], "Not authorized to mint");
        _mint(to, amount);
    }

    /// @notice Burn tokens (only authorized burners)
    function burn(address from, uint256 amount) external override {
        require(authorizedBurners[msg.sender], "Not authorized to burn");
        _burn(from, amount);
    }

    /// @notice Transfer tokens with permission (only authorized contracts)
    function transferPermissioned(address from, address to, uint256 amount) external override {
        require(authorizedMinters[msg.sender] || authorizedBurners[msg.sender], "Not authorized");
        _transfer(from, to, amount);
    }
}
