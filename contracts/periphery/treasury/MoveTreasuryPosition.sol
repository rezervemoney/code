// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IEVC} from "evc/interfaces/IEthereumVaultConnector.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {IApp} from "../../../contracts/interfaces/IApp.sol";
import {IPermit2} from "../../../contracts/interfaces/IPermit2.sol";

import "forge-std/console.sol";

interface IAavePool {
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

/// @title RZR UI Helper
/// @author RZR Protocol
contract MoveTreasuryPosition {
    address public treasury = address(0xe22e10f8246dF1f0845eE3E9f2F0318bd60EFC85);
    IERC20 public rzr = IERC20(0xb4444468e444f89e1c2CAc2F1D3ee7e336cBD1f5);
    IERC20 public usdc = IERC20(0x29219dd400f2Bf60E5a23d13Be72B486D4038894);
    address public safe = address(0x0E43DF9F40Cc6eEd3eC70ea41D6F34329fE75986);
    address public safePosition = address(0x0e43dF9f40cC6EeD3eC70eA41D6F34329FE75987);

    IAavePool public immutable POOL = IAavePool(address(0x5362dBb1e601abF3a4c14c22ffEdA64042E5eAA3));

    IEVC public immutable evc = IEVC(0x4860C903f6Ad709c3eDA46D3D502943f184D4315);
    IEVault public immutable borrowVaultUsdc = IEVault(0x9CcF74E64922D8a48b87AA4200b7c27B2B1D860a);
    IEVault public immutable collateralVaultRzr = IEVault(0x8c7a2C0729aFB927DA27D4C9aa172bc5A5FB12Bb);

    IPermit2 public immutable permit2 = IPermit2(0xB952578f3520EE8Ea45b7914994dcf4702cEe578);

    IERC20 public immutable usdcDebt = IERC20(0x128aF623F7483B006FDfC7CC66BafCfde9121F9c);

    address public who;

    constructor() {
        who = msg.sender;
    }

    function executeOperation(address asset, uint256 amount, uint256 premium, address initiator, bytes calldata)
        external
        returns (bool)
    {
        require(msg.sender == address(POOL), "not authorized");
        require(address(this) == initiator, "not owner");

        usdc.approve(address(permit2), type(uint256).max);
        permit2.approve(address(usdc), address(borrowVaultUsdc), type(uint160).max, uint48(block.timestamp + 1));

        // we have the usdc to repay the debt
        uint256 debt = usdcDebt.balanceOf(safePosition);
        usdc.approve(address(borrowVaultUsdc), type(uint256).max);
        borrowVaultUsdc.repay(type(uint256).max, safePosition);

        uint256 rzrBalance = collateralVaultRzr.balanceOf(safePosition);
        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](2);
        items[0] = IEVC.BatchItem({
            targetContract: address(collateralVaultRzr),
            onBehalfOfAccount: address(safePosition),
            value: 0,
            data: abi.encodeWithSelector(collateralVaultRzr.transfer.selector, address(treasury), rzrBalance)
        });
        items[1] = IEVC.BatchItem({
            targetContract: address(borrowVaultUsdc),
            onBehalfOfAccount: address(treasury),
            value: 0,
            data: abi.encodeWithSelector(collateralVaultRzr.borrow.selector, debt + premium, address(this))
        });

        evc.batch(items);

        // Approve the Pool contract allowance to *pull* the owed amount
        uint256 amountOwed = amount + premium;
        IERC20(asset).approve(address(POOL), amountOwed);

        return true;
    }

    function moveTreasuryPosition() public {
        require(msg.sender == who || msg.sender == address(safe), "not authorized");
        POOL.flashLoanSimple(address(this), address(usdc), 123019893411, "", 0);
    }

    receive() external payable {}
}
