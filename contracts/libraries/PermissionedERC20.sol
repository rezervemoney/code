// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IPermissionedERC20.sol";

contract PermissionedERC20 is ERC20, IPermissionedERC20 {
    uint8 private immutable __decimals;

    /// @notice Event emitted when the permissioned contract is updated
    /// @param permissionedContract The new permissioned contract
    event PermissionedContractUpdated(address permissionedContract);

    /// @notice Modifier to check if the caller is the staking contract
    /// @dev This modifier is only callable by the staking contract
    modifier onlyPermissionedContract() {
        require(msg.sender == permissionedContract, "PermissionedContract:  call is not permissioned contract");
        _;
    }

    /// @notice The staking contract
    address public permissionedContract;

    /// @notice Constructor
    /// @dev This function is only callable once
    /// @param _name The name of the token
    /// @param _symbol The symbol of the token
    constructor(string memory _name, string memory _symbol, uint8 _decimals, address _permissionedContract)
        ERC20(_name, _symbol)
    {
        _mint(msg.sender, 1e18);
        _burn(msg.sender, 1e18);
        __decimals = _decimals;
        permissionedContract = _permissionedContract;
    }

    /// @notice Get the decimals of the token
    /// @return The decimals of the token
    function decimals() public view override returns (uint8) {
        return __decimals;
    }

    /// @notice Mint function is only callable by the staking contract
    /// @dev This function is only callable by the staking contract
    /// @param to The address of the recipient
    /// @param amount The amount of tokens to mint
    function mint(address to, uint256 amount) external onlyPermissionedContract {
        _mint(to, amount);
    }

    /// @notice Burn function is not allowed
    /// @dev This function is not allowed
    /// @param from The address of the sender
    /// @param amount The amount of tokens to burn
    function burn(address from, uint256 amount) external onlyPermissionedContract {
        _burn(from, amount);
    }

    /// @notice Transfer function is only callable by the staking contract
    /// @dev This function is only callable by the staking contract
    /// @param from The address of the sender
    /// @param to The address of the recipient
    /// @param amount The amount of tokens to transfer
    function transferPermissioned(address from, address to, uint256 amount) external onlyPermissionedContract {
        _transfer(from, to, amount);
    }

    /// @notice Transfer function is not allowed
    /// @dev This function is not allowed
    /// @param to The address of the recipient
    /// @param value The amount of tokens to transfer
    /// @return bool True if the transfer is successful, false otherwise
    function transfer(address to, uint256 value) public override(ERC20, IERC20) returns (bool) {
        require(false, "transfer not allowed");
        return super.transfer(to, value);
    }

    /// @notice Transfer function is not allowed
    /// @dev This function is not allowed
    /// @param from The address of the sender
    /// @param to The address of the recipient
    /// @param value The amount of tokens to transfer
    /// @return bool True if the transfer is successful, false otherwise
    function transferFrom(address from, address to, uint256 value) public override(ERC20, IERC20) returns (bool) {
        require(false, "transferFrom not allowed");
        return super.transferFrom(from, to, value);
    }
}
