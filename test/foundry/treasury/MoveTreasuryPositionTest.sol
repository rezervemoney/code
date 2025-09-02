// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {MoveTreasuryPosition} from "../../../contracts/periphery/treasury/MoveTreasuryPosition.sol";
import {IEVC, IEVault} from "../../../contracts/periphery/treasury/EulerBorrowerHelper.sol";
import {IERC20} from "../../../contracts/interfaces/IAppTreasury.sol";
import {IPermit2} from "../../../contracts/interfaces/IPermit2.sol";

/// @title MoveTreasuryPositionTest
/// @notice Verifies that the MoveTreasuryPosition can move the treasury position.
contract MoveTreasuryPositionTest is Test {
    address public treasury = address(0xe22e10f8246dF1f0845eE3E9f2F0318bd60EFC85);
    address public rzr = address(0xb4444468e444f89e1c2CAc2F1D3ee7e336cBD1f5);
    address public usdc = address(0x29219dd400f2Bf60E5a23d13Be72B486D4038894);
    address public safe = address(0x0E43DF9F40Cc6eEd3eC70ea41D6F34329fE75986);
    address public safePosition = address(0x0e43dF9f40cC6EeD3eC70eA41D6F34329FE75987);

    IPermit2 public immutable permit2 = IPermit2(0xB952578f3520EE8Ea45b7914994dcf4702cEe578);

    IEVC public immutable evc = IEVC(0x4860C903f6Ad709c3eDA46D3D502943f184D4315);
    IEVault public immutable borrowVaultUsdc = IEVault(0x9CcF74E64922D8a48b87AA4200b7c27B2B1D860a);
    IEVault public immutable collateralVaultRzr = IEVault(0x8c7a2C0729aFB927DA27D4C9aa172bc5A5FB12Bb);
    IERC20 public immutable usdcDebt = IERC20(0x128aF623F7483B006FDfC7CC66BafCfde9121F9c);

    MoveTreasuryPosition moveTreasuryPosition;
    string SONIC_RPC_URL = vm.envString("SONIC_RPC_URL");

    function setUp() public {
        uint256 mainnetFork = vm.createFork(SONIC_RPC_URL);
        vm.selectFork(mainnetFork);
        vm.rollFork(45518758);

        moveTreasuryPosition = new MoveTreasuryPosition();

        vm.label(address(moveTreasuryPosition), "MoveTreasuryPosition");
        vm.label(address(borrowVaultUsdc), "borrowVaultUsdc");
        vm.label(address(collateralVaultRzr), "collateralVaultRzr");
        vm.label(address(evc), "evc");
        vm.label(address(usdcDebt), "usdcDebt");
        vm.label(address(rzr), "rzr");
        vm.label(address(treasury), "treasury");
        vm.label(address(usdc), "usdc");
        vm.label(address(safe), "safe");
        vm.label(address(0x5362dBb1e601abF3a4c14c22ffEdA64042E5eAA3), "aavePool");
        vm.label(address(safePosition), "safePosition");
    }

    function test_can_move_treasury_position_fork_test() external {
        vm.startPrank(address(safe));
        evc.setAccountOperator(address(safePosition), address(moveTreasuryPosition), true);
        collateralVaultRzr.approve(address(moveTreasuryPosition), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(address(treasury));
        evc.enableCollateral(address(treasury), address(collateralVaultRzr));
        evc.enableController(address(treasury), address(borrowVaultUsdc));
        evc.setAccountOperator(address(treasury), address(moveTreasuryPosition), true);
        vm.stopPrank();

        moveTreasuryPosition.moveTreasuryPosition();

        vm.prank(address(treasury));
        evc.setAccountOperator(address(treasury), address(moveTreasuryPosition), false);
        vm.prank(address(safe));
        evc.setAccountOperator(address(safePosition), address(moveTreasuryPosition), false);
    }
}
