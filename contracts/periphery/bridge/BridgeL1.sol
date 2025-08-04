// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import "../../interfaces/IBridgeL1.sol";
import "../../interfaces/ITotalReservesOracle.sol";
import "../../interfaces/ITotalSupplyOracle.sol";
import "../../interfaces/IAppTreasury.sol";
import "../../interfaces/IAppStaking.sol";
import "../../interfaces/IStaking4626.sol";
import "../../interfaces/IApp.sol";
import "../../libraries/OAppControlledProxy.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title BridgeL1
 * @notice This contract is used to send the current protocol state to an L2 bridge
 * @dev The contract sends the account state of the L1 to the L2 bridge
 * @dev This contract is a proxy
 */
contract BridgeL1 is OAppControlledProxy, IBridgeL1 {
    using SafeERC20 for IERC20;

    uint256 public immutable MAINNET_EID = 30101;

    mapping(uint32 eid => address l2Bridge) public l2Bridges;

    /// @inheritdoc IBridgeL1
    IApp public rzr;

    /// @inheritdoc IBridgeL1
    IAppTreasury public treasury;

    /// @inheritdoc IBridgeL1
    IAppStaking public staking;

    /// @inheritdoc IBridgeL1
    IStaking4626 public staking4626;

    /// @inheritdoc IBridgeL1
    ITotalReservesOracle public totalReservesOracle;

    /// @inheritdoc IBridgeL1
    ITotalSupplyOracle public totalSupplyOracle;

    receive() external payable {
        // do nothing
    }

    /// @inheritdoc IBridgeL1
    function initialize(
        address _lzEndpoint,
        address _delegate,
        address _authority,
        address _staking,
        address _staking4626,
        address _rzr,
        address _treasury,
        address _totalReservesOracle,
        address _totalSupplyOracle
    ) external initializer {
        __OAppControlledProxy_init(_lzEndpoint, _delegate, _authority);
        staking = IAppStaking(_staking);
        staking4626 = IStaking4626(_staking4626);
        rzr = IApp(_rzr);
        treasury = IAppTreasury(_treasury);
        totalReservesOracle = ITotalReservesOracle(_totalReservesOracle);
        totalSupplyOracle = ITotalSupplyOracle(_totalSupplyOracle);
    }

    /// @inheritdoc IBridgeL1
    function sentStateToL2(uint32[] calldata _dstEid) external payable onlyExecutor whenNotPaused {
        treasury.syncReserves();
        bytes memory _message = abi.encode(getCurrentState());
        for (uint256 i = 0; i < _dstEid.length; i++) {
            _lzSend(_dstEid[i], _message, "", MessagingFee({nativeFee: msg.value, lzTokenFee: 0}), address(this));
            emit StateSent(_dstEid[i], _message);
        }
    }

    /// @inheritdoc IBridgeL1
    function registerL2Bridge(address _l2Bridge, uint32 _eid) external onlyGovernor whenNotPaused {
        l2Bridges[_eid] = _l2Bridge;
        emit L2BridgeRegistered(_l2Bridge, _eid);
    }

    /// @inheritdoc IBridgeL1
    function syncMainnetReserves() external onlyExecutor {
        (uint256 usdReserves, uint256 rzrReserves) = treasury.syncReserves();
        totalReservesOracle.setCrosschainReserves(MAINNET_EID, rzrReserves, usdReserves);
    }

    /// @inheritdoc IBridge
    function getCurrentState() public view returns (State memory) {
        uint256 staking4626Rate = staking4626.convertToAssets(1e18);

        return State({
            staking4626Rate: staking4626Rate,
            rzrReserves: treasury.totalReservesRzr(),
            usdReserves: treasury.totalReservesUsd(),
            rzrSupply: rzr.totalSupply(),
            lstRzrSupply: staking4626.totalSupply(),
            updatedAt: block.timestamp
        });
    }

    /// @inheritdoc IBridgeL1
    function purge(address token) external onlyGovernor {
        if (token == address(0)) {
            (bool success,) = msg.sender.call{value: address(this).balance}("");
            require(success, "Failed to send ETH");
        } else {
            uint256 balance = IERC20(token).balanceOf(address(this));
            if (balance > 0) {
                IERC20(token).safeTransfer(msg.sender, balance);
            }
        }
    }

    function _lzReceive(Origin calldata _origin, bytes32, bytes calldata _message, address, bytes calldata)
        internal
        override
        whenNotPaused
    {
        // todo check if the executor is the same as the one that sent the message
        uint256 eid = _origin.srcEid;
        State memory state = abi.decode(_message, (State));

        require(state.updatedAt < block.timestamp, "Invalid updatedAt");

        totalReservesOracle.setCrosschainReserves(eid, state.rzrReserves, state.usdReserves);
        totalSupplyOracle.setCrosschainTotalSupply(eid, state.rzrSupply);
    }
}
