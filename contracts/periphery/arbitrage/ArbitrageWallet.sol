// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ArbitrageWallet is Ownable {
    using SafeERC20 for IERC20;

    error ArbitrageWalletNotBot(address caller);
    error ArbitrageWalletExecuteFailed(bytes data);
    error ArbitrageWalletRecallFailed();

    address public bot;
    address public immutable SWAPPER;
    IERC20 public immutable TOKEN0;
    IERC20 public immutable TOKEN1;

    constructor(address _swapper, address _token0, address _token1) Ownable(msg.sender) {
        SWAPPER = _swapper;
        bot = msg.sender;
        TOKEN0 = IERC20(_token0);
        TOKEN1 = IERC20(_token1);
        TOKEN0.approve(SWAPPER, type(uint256).max);
        TOKEN1.approve(SWAPPER, type(uint256).max);
    }

    // do nothing
    receive() external payable {}

    modifier onlyBot() {
        _onlyBot();
        _;
    }

    function setBot(address _bot) external onlyOwner {
        bot = _bot;
    }

    function execute(uint256 _value, bytes calldata _data) external payable onlyBot {
        (bool success,) = SWAPPER.call{value: _value}(_data);
        if (!success) revert ArbitrageWalletExecuteFailed(_data);
    }

    function bridge(address _token, uint256 _amount) external onlyBot {
        // todo; write the code to send USDC/RZR to stargate
    }

    function _onlyBot() internal view {
        if (msg.sender != bot) {
            revert ArbitrageWalletNotBot(msg.sender);
        }
    }

    function recall() external onlyOwner {
        TOKEN0.safeTransfer(msg.sender, TOKEN0.balanceOf(address(this)));
        TOKEN1.safeTransfer(msg.sender, TOKEN1.balanceOf(address(this)));
        if (address(this).balance > 0) {
            (bool success,) = msg.sender.call{value: address(this).balance}("");
            if (!success) revert ArbitrageWalletRecallFailed();
        }
    }
}
