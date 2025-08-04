// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import "../../interfaces/IBridgeL2.sol";
import "../../interfaces/IStaking4626L2.sol";
import "../../interfaces/ITotalReservesOracle.sol";
import "../../interfaces/ITotalSupplyOracle.sol";
import "../../interfaces/IAppTreasury.sol";
import "../../libraries/OAppControlledProxy.sol";
import "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BridgeL2 is OAppControlledProxy, IBridgeL2 {
    uint256 public immutable MAINNET_EID = 30101;

    address public l1Bridge;
    IStaking4626L2 public liquidStaking;
    ITotalReservesOracle public totalReservesOracle;
    ITotalSupplyOracle public totalSupplyOracle;
    IAppTreasury public treasury;
    IERC20 public rzr;

    receive() external payable {
        // do nothing
    }

    /// @notice Initialize the contract
    /// @param _delegate The address of the delegate
    /// @param _authority The address of the authority
    function initialize(
        address _l1Bridge,
        address _lzEndpoint,
        address _delegate,
        address _authority,
        address _treasury,
        address _liquidStaking,
        address _totalReservesOracle,
        address _totalSupplyOracle
    ) external initializer {
        __OAppControlledProxy_init(_lzEndpoint, _delegate, _authority);
        l1Bridge = _l1Bridge;
        liquidStaking = IStaking4626L2(_liquidStaking);
        treasury = IAppTreasury(_treasury);
        totalReservesOracle = ITotalReservesOracle(_totalReservesOracle);
        totalSupplyOracle = ITotalSupplyOracle(_totalSupplyOracle);
        rzr = IERC20(liquidStaking.asset());
    }

    /// @inheritdoc IBridgeL2
    function syncRzrToL1LiquidStaking() external view override {
        _ensureUnpaused();
        require(msg.sender == address(liquidStaking), "Invalid sender");

        uint256 rzrBalance = rzr.balanceOf(address(this));
        require(rzrBalance > 0, "No rzr to flush");

        // todo send rzr to L1 and deposit to liquid staking using LayerZero
    }

    /// @inheritdoc IBridgeL2
    function syncStateToL1() external payable onlyExecutor whenNotPaused {
        State memory state = getCurrentState();
        _lzSend(MAINNET_EID, abi.encode(state), "", MessagingFee({nativeFee: msg.value, lzTokenFee: 0}), address(this));
    }

    /// @inheritdoc IBridge
    function getCurrentState() public view returns (State memory) {
        uint256 staking4626Rate = liquidStaking.convertToAssets(1e18);
        return State({
            staking4626Rate: staking4626Rate,
            rzrReserves: treasury.totalReservesRzr(),
            usdReserves: treasury.totalReservesUsd(),
            rzrSupply: rzr.totalSupply(),
            lstRzrSupply: liquidStaking.totalSupply(),
            updatedAt: block.timestamp
        });
    }

    function _lzReceive(Origin calldata _origin, bytes32, bytes calldata _message, address, bytes calldata)
        internal
        override
        whenNotPaused
    {
        require(_origin.srcEid == MAINNET_EID, "Invalid origin");
        require(_origin.sender == l1Bridge, "Invalid origin");

        State memory state = abi.decode(_message, (State));
        uint256 newRate = state.staking4626Rate;
        liquidStaking.setRate(newRate);
    }
}
