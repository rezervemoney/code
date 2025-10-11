// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract CronWallet is Ownable {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;

    error CronWalletNotBot(address caller);
    error CronWalletExecuteFailed(bytes data);
    error CronWalletRecallFailed();

    event ActionAdded(uint256 actionId, address target, bytes data);
    event ActionRemoved(uint256 actionId);
    event ActionUpdated(uint256 actionId, address target, bytes data);

    struct Action {
        string name;
        address target;
        bytes data;
    }

    address public bot;
    IERC20 public immutable RZR;

    mapping(uint256 => Action) public actions;
    uint256 public actionIdCounter;
    EnumerableSet.UintSet private _actionIds;

    constructor(address _rzr) Ownable(msg.sender) {
        RZR = IERC20(_rzr);
        bot = msg.sender;
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

    function addAction(string calldata _name, address _target, bytes calldata _data) external onlyOwner {
        actionIdCounter++;
        _actionIds.add(actionIdCounter);
        actions[actionIdCounter] = Action(_name, _target, _data);
        emit ActionAdded(actionIdCounter, _target, _data);
    }

    function updateAction(uint256 _actionId, address _target, bytes calldata _data) external onlyOwner {
        actions[_actionId] = Action(actions[_actionId].name, _target, _data);
        emit ActionUpdated(_actionId, _target, _data);
    }

    function removeAction(uint256 _actionId) external onlyOwner {
        _actionIds.remove(_actionId);
        delete actions[_actionId];
        emit ActionRemoved(_actionId);
    }

    function executeAllActions() external onlyBot {
        for (uint256 i = 0; i < _actionIds.length(); i++) {
            _execute(_actionIds.at(i));
        }
    }

    function recall() external onlyOwner {
        RZR.safeTransfer(msg.sender, RZR.balanceOf(address(this)));
        if (address(this).balance > 0) {
            (bool success,) = msg.sender.call{value: address(this).balance}("");
            if (!success) revert CronWalletRecallFailed();
        }
    }

    function _onlyBot() internal view {
        if (msg.sender != bot) revert CronWalletNotBot(msg.sender);
    }

    function _execute(uint256 _actionId) internal {
        Action memory action = actions[_actionId];
        (bool success,) = action.target.call(action.data);
        if (!success) revert CronWalletExecuteFailed(action.data);
    }
}
