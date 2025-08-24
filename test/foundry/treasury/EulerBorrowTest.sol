// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {EulerBorrowerHelper, IEVC, IEVault} from "../../../contracts/periphery/treasury/EulerBorrowerHelper.sol";
import {IAppAuthority} from "../../../contracts/interfaces/IAppAuthority.sol";
import {IAppTreasury, IERC20} from "../../../contracts/interfaces/IAppTreasury.sol";

contract EulerBorrowerHelperMock is EulerBorrowerHelper {
    constructor(address _evc, address _borrowVault, address _collateralVault, address _authority)
        EulerBorrowerHelper(_evc, _borrowVault, _collateralVault)
    {
        __BaseTreasuryHelper_init(_authority);
    }

    function addCollateralAndBorrow(uint256 addCollateralAmount, uint256 borrowAmount) public {
        _addCollateralAndBorrow(addCollateralAmount, borrowAmount, address(_treasury()));
    }
}

/// @title EulerBorrowTest
/// @notice Verifies that the EulerBorrowerHelper can borrow and repay from Euler.
contract EulerBorrowTest is Test {
    IEVC public immutable evc = IEVC(0x0C9a3dd6b8F28529d72d7f9cE918D493519EE383);
    IEVault public immutable borrowVault = IEVault(0xC42d337861878baa4dC820D9E6B6C667C2b57e8A);
    IEVault public immutable collateralVault = IEVault(0x1ab9e92CFdE84f38868753d30fFc43F812B803C5);
    IERC20 public immutable rzr = IERC20(0xb4444468e444f89e1c2CAc2F1D3ee7e336cBD1f5);
    IERC20 public immutable usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    IAppTreasury public immutable treasury = IAppTreasury(0x0000030d7a7C4888851F35705B0852CF20Ac1bA6);
    IAppAuthority public immutable authority = IAppAuthority(0x43A38A7Ba3417D675b7a78BF026A9cf6fA45417D);

    address public executor = address(0x5f5a6E0F769BBb9232d2F6EDA84790296b288974);

    address public immutable eulerGovernor = address(0x1f4817b5F2B2e71658251d905634C62FAb8e2033);
    address public immutable appGovernor = address(0x0E43DF9F40Cc6eEd3eC70ea41D6F34329fE75986);

    EulerBorrowerHelperMock eulerBorrowerHelper;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() public {
        uint256 mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        vm.rollFork(23203617);

        eulerBorrowerHelper = new EulerBorrowerHelperMock(
            address(evc), address(borrowVault), address(collateralVault), address(authority)
        );

        vm.startPrank(address(treasury));
        evc.enableCollateral(address(treasury), address(collateralVault));
        evc.enableController(address(treasury), address(borrowVault));
        evc.setAccountOperator(address(treasury), address(eulerBorrowerHelper), true);
        vm.stopPrank();
    }

    function test_canBorrow_normal() external {
        uint256 balanceBefore = usdc.balanceOf(address(treasury));
        vm.prank(address(treasury));
        borrowVault.borrow(1e6, address(treasury));
        uint256 balanceAfter = usdc.balanceOf(address(treasury));
        assertEq(balanceAfter, balanceBefore + 1e6, "balanceAfter != balanceBefore + 1e6");
    }

    function test_canBorrow_via_eulerBorrowerHelper() external {
        uint256 balanceBeforeUSDC = usdc.balanceOf(address(treasury));
        uint256 balanceBeforeRZR = rzr.balanceOf(address(treasury));

        vm.prank(appGovernor);
        eulerBorrowerHelper.addCollateralAndBorrow(1e18, 1e6);

        uint256 balanceAfterUSDC = usdc.balanceOf(address(treasury));
        uint256 balanceAfterRZR = rzr.balanceOf(address(treasury));

        assertEq(balanceAfterUSDC, balanceBeforeUSDC + 1e6, "balanceAfterUSDC != balanceBeforeUSDC + 1e6");
        assertEq(balanceAfterRZR, balanceBeforeRZR - 1e18, "balanceAfterRZR != balanceBeforeRZR - 1e18");
    }
}
