// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {BalancerBorrowAndAdd} from "../../../contracts/periphery/treasury/BalancerBorrowAndAdd.sol";
import {IEVC, IEVault} from "../../../contracts/periphery/treasury/EulerBorrowerHelper.sol";
import {IBalancerPool, IBalancerV3Router} from "../../../contracts/interfaces/IBalancerVault.sol";
import {IAppAuthority} from "../../../contracts/interfaces/IAppAuthority.sol";
import {IAppTreasury, IERC20} from "../../../contracts/interfaces/IAppTreasury.sol";
import {IPermit2} from "../../../contracts/interfaces/IPermit2.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BalancerMockOdos is Test {
    using SafeERC20 for IERC20;

    function swap(uint256 amountIn, uint256 amountOut, address tokenIn, address tokenOut) external {
        // todo
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        deal(tokenOut, msg.sender, amountOut);
    }
}

/// @title BalancerBorrowAndAddTest
/// @notice Verifies that the BalancerBorrowAndAdd can borrow and add to balancer.
contract BalancerBorrowAndAddTest is Test {
    IEVC public immutable evc = IEVC(0x0C9a3dd6b8F28529d72d7f9cE918D493519EE383);
    IEVault public immutable borrowVault = IEVault(0xC42d337861878baa4dC820D9E6B6C667C2b57e8A);
    IEVault public immutable collateralVault = IEVault(0x1ab9e92CFdE84f38868753d30fFc43F812B803C5);
    IERC20 public immutable rzr = IERC20(0xb4444468e444f89e1c2CAc2F1D3ee7e336cBD1f5);
    IERC20 public immutable usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 public immutable weeth = IERC20(0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee);

    IPermit2 public immutable permit2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    IBalancerV3Router public immutable balancerV3Router = IBalancerV3Router(0xAE563E3f8219521950555F5962419C8919758Ea2);
    IBalancerPool public immutable pool = IBalancerPool(0x3F89f8C0E0FfdfaE0b97959303831fa893f1CFE0);
    BalancerMockOdos public odos;

    IAppTreasury public immutable treasury = IAppTreasury(0x0000030d7a7C4888851F35705B0852CF20Ac1bA6);
    IAppAuthority public immutable authority = IAppAuthority(0x43A38A7Ba3417D675b7a78BF026A9cf6fA45417D);

    address public executor = address(0x5f5a6E0F769BBb9232d2F6EDA84790296b288974);

    address public immutable eulerGovernor = address(0x1f4817b5F2B2e71658251d905634C62FAb8e2033);
    address public immutable appGovernor = address(0x0E43DF9F40Cc6eEd3eC70ea41D6F34329fE75986);

    BalancerBorrowAndAdd balancerBorrowAndAdd;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() public {
        uint256 mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        vm.rollFork(23203617);

        odos = new BalancerMockOdos();

        balancerBorrowAndAdd = new BalancerBorrowAndAdd(
            address(evc),
            address(borrowVault),
            address(collateralVault),
            address(balancerV3Router),
            address(odos),
            address(permit2)
        );

        balancerBorrowAndAdd.initialize(address(pool), address(authority));

        vm.startPrank(address(treasury));
        evc.enableCollateral(address(treasury), address(collateralVault));
        evc.enableController(address(treasury), address(borrowVault));
        evc.setAccountOperator(address(treasury), address(balancerBorrowAndAdd), true);
        vm.stopPrank();

        vm.prank(appGovernor);
        authority.addPolicy(address(balancerBorrowAndAdd));

        vm.label(address(balancerBorrowAndAdd), "balancerBorrowAndAdd");
        vm.label(address(balancerV3Router), "balancerV3Router");
        vm.label(address(borrowVault), "borrowVault");
        vm.label(address(collateralVault), "collateralVault");
        vm.label(address(evc), "evc");
        vm.label(address(odos), "odos");
        vm.label(address(pool), "pool");
        vm.label(address(rzr), "rzr");
        vm.label(address(treasury), "treasury");
        vm.label(address(usdc), "usdc");
        vm.label(address(weeth), "weeth");
    }

    function test_can_borrow_add_liquidity_fork_test() external {
        uint256 collateralToAdd = 1e18;
        uint256 debtToBorrow = 20000e6;

        uint256 rzrToMint = 10000e18;
        uint256 minWeETHtoReceive = 1000e18;
        uint256 minBptAmountOut = _estimateBptOutput(rzrToMint, minWeETHtoReceive);

        bytes memory odosCallData = _getDummyOdosCallData(debtToBorrow, minWeETHtoReceive);

        uint256[] memory balancesRawBefore = _printPoolBalances();
        uint256 poolBalanceBefore = pool.balanceOf(address(treasury));

        vm.prank(appGovernor);
        (uint256[] memory amountsIn, uint256 swapOut, uint256 bptAmountOut) = balancerBorrowAndAdd.borrowAndAdd(
            collateralToAdd, debtToBorrow, odosCallData, weeth, minWeETHtoReceive, rzrToMint, minBptAmountOut
        );

        uint256[] memory balancesRawAfter = _printPoolBalances();
        uint256 poolBalanceAfter = pool.balanceOf(address(treasury));

        console.log("poolBalanceBefore", poolBalanceBefore);
        console.log("poolBalanceAfter", poolBalanceAfter);
        console.log("bpt minted", bptAmountOut);
        console.log("weth swapped", swapOut);
        console.log("amountsIn[0] - added to pool", amountsIn[0]);
        console.log("amountsIn[1] - added to pool", amountsIn[1]);

        assertGt(bptAmountOut, 0, "!bptAmountOut");
        assertGt(swapOut, 0, "!swapOut");
        assertGt(amountsIn[0], 0, "!amountsIn[0]");
        assertGt(amountsIn[1], 0, "!amountsIn[1]");

        assertGt(poolBalanceAfter, poolBalanceBefore, "!poolBalanceAfter");
        assertGt(balancesRawAfter[0], balancesRawBefore[0], "!balancesRawAfter[0]");
        assertGt(balancesRawAfter[1], balancesRawBefore[1], "!balancesRawAfter[1]");
    }

    function execute() internal {}

    function _getDummyOdosCallData(uint256 amountIn, uint256 amountOut) internal view returns (bytes memory) {
        return
            abi.encodeWithSelector(BalancerMockOdos.swap.selector, amountIn, amountOut, address(usdc), address(weeth));
    }

    function _printPoolBalances() internal view returns (uint256[] memory balancesRaw) {
        (,, balancesRaw,) = pool.getTokenInfo();

        console.log("poolData.balancesRaw[0]", balancesRaw[0]);
        console.log("poolData.balancesRaw[1]", balancesRaw[1]);
    }

    function _estimateBptOutput(uint256 rzrToMint, uint256 minWeETHtoReceive) internal view returns (uint256) {
        uint256[] memory amountsIn = new uint256[](2);
        amountsIn[0] = rzrToMint;
        amountsIn[1] = minWeETHtoReceive;
        return balancerBorrowAndAdd.estimateBptOutput(amountsIn) * 99 / 100;
    }
}
