// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import "../../interfaces/IBridgeL2.sol";
import "../../interfaces/IStaking4626L2.sol";
import "../../interfaces/IAppTreasury.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BridgeL2Reader is IBridgeL2 {
    uint32 public immutable eid;
    IStaking4626L2 public liquidStaking;
    IAppTreasury public treasury;
    IERC20 public rzr;

    /// @notice Initialize the contract
    /// @param _treasury The address of the treasury
    /// @param _liquidStaking The address of the liquid staking
    constructor(uint32 _eid, address _treasury, address _liquidStaking, address _rzr) {
        eid = _eid;
        liquidStaking = IStaking4626L2(_liquidStaking);
        treasury = IAppTreasury(_treasury);
        rzr = IERC20(_rzr);
    }

    /// @inheritdoc IBridgeL2
    function data() public view returns (uint32, uint256, uint256, uint256) {
        State memory state = getCurrentState();
        return (eid, state.rzrSupply, state.rzrReserves, state.usdReserves);
    }

    /// @inheritdoc IBridge
    function getCurrentState() public view returns (State memory) {
        (uint256 rzrReserves, uint256 usdReserves, uint256 staking4626Rate, uint256 lstRzrSupply) = (0, 0, 0, 0);
        if (address(treasury) != address(0)) {
            (rzrReserves, usdReserves) = treasury.calculateReserves();
        }

        if (address(liquidStaking) != address(0)) {
            staking4626Rate = liquidStaking.convertToAssets(1e18);
            lstRzrSupply = liquidStaking.totalSupply();
        }

        return State({
            staking4626Rate: staking4626Rate,
            rzrReserves: rzrReserves,
            usdReserves: usdReserves,
            rzrSupply: rzr.totalSupply(),
            lstRzrSupply: lstRzrSupply,
            updatedAt: block.timestamp
        });
    }
}
