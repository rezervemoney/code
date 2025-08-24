// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../../core/AppAccessControlled.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BlankTreasury is AppAccessControlled {
    using SafeERC20 for IERC20;

    constructor() {
        _disableInitializers();
    }

    receive() external payable {
        // do nothing
    }

    /// @notice Initializes the contract
    /// @param _authority The address of the authority contract
    function initialize(address _authority) external initializer {
        __AppAccessControlled_init(_authority);
    }

    /// @notice Refunds the ETH to the given address
    /// @param to The address to refund the ETH to
    function refundEth(address to) external onlyGovernor {
        _purge(address(0), to);
    }

    /// @notice Refunds the token to the given address
    /// @param token The token to refund
    /// @param to The address to refund the token to
    function refundToken(address token, address to) external onlyGovernor {
        _purge(token, to);
    }

    /// @notice Executes a call to the given address
    /// @param to The address to execute the call to
    /// @param data The data to execute the call with
    function execute(address to, bytes calldata data) external payable onlyGovernor {
        (bool success,) = to.call{value: msg.value}(data);
        require(success, "Failed to execute");
    }

    /// @notice Purges the given token
    /// @param token The token to purge
    function _purge(address token, address to) internal {
        if (token == address(0)) {
            (bool success,) = to.call{value: address(this).balance}("");
            require(success, "Failed to send ETH");
        } else {
            uint256 balance = IERC20(token).balanceOf(address(this));
            if (balance > 0) IERC20(token).safeTransfer(to, balance);
        }
    }
}
