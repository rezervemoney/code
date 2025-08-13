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

    /// @notice Initialize the contract
    /// @param _treasury The address of the treasury
    /// @param _liquidStaking The address of the liquid staking
    constructor(uint32 _eid, address _treasury, address _liquidStaking) {
        eid = _eid;
        liquidStaking = IStaking4626L2(_liquidStaking);
        treasury = IAppTreasury(_treasury);
    }

    /// @inheritdoc IBridgeL2
    function data() public view returns (uint32 _eid, uint256 _rzrReserves, uint256 _usdReserves) {
        _eid = eid;
        if (address(treasury) != address(0)) {
            (_usdReserves, _rzrReserves) = treasury.calculateReserves();
        }
    }
}
