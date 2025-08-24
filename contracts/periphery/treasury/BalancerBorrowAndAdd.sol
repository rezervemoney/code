// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import {EulerBorrowerHelper} from "./EulerBorrowerHelper.sol";
import {IBalancerPool, IERC20, IBalancerV3Router} from "../../interfaces/IBalancerVault.sol";
import {IPermit2} from "../../interfaces/IPermit2.sol";

contract BalancerBorrowAndAdd is EulerBorrowerHelper {
    IBalancerV3Router public immutable router;
    address public immutable odos;
    IPermit2 public immutable permit2;
    IBalancerPool public pool;

    constructor(
        address _evc,
        address _borrowVault,
        address _collateralVault,
        address _balancerV3Router,
        address _odos,
        address _permit2
    ) EulerBorrowerHelper(_evc, _borrowVault, _collateralVault) {
        router = IBalancerV3Router(_balancerV3Router);
        odos = _odos;
        permit2 = IPermit2(_permit2);
    }

    function initialize(address _pool, address _authority) external initializer {
        pool = IBalancerPool(_pool);
        __BaseTreasuryHelper_init(_authority);

        IERC20[] memory tokens = pool.getTokens();
        for (uint256 i = 0; i < tokens.length; i++) {
            tokens[i].approve(address(permit2), type(uint256).max);
        }
    }

    function borrowAndAdd(
        uint256 collateralToAdd,
        uint256 debtToBorrow,
        bytes calldata odosCallData,
        IERC20 tokenOut,
        uint256 minSwapOut,
        uint256 rzrToMint,
        uint256 minBptAmountOut
    )
        external
        onlyReserveManager
        whenNotKilled
        returns (uint256[] memory amountsIn, uint256 swapOut, uint256 bptAmountOut)
    {
        // Add collateral and borrow debt
        _addCollateralAndBorrow(collateralToAdd, debtToBorrow, address(this));

        // Approve debt to be used by odos
        _debt().approve(odos, debtToBorrow);

        // Call odos to swap debt for collateral
        (bool success, bytes memory data) = odos.call(odosCallData);
        require(success, "BalancerBorrowAndAdd: odos call failed");
        swapOut = tokenOut.balanceOf(address(this));
        require(swapOut >= minSwapOut, "BalancerBorrowAndAdd: swapOut < minSwapOut");

        // Mint rzr to add into the balancer pool
        _mint(address(this), rzrToMint);

        _approve(address(_collateral()));
        _approve(address(tokenOut));

        // Add liquidity to balancer pool
        uint256[] memory maxAmountsIn = _getTokenBalances();
        amountsIn = router.addLiquidityProportional(address(pool), maxAmountsIn, minBptAmountOut, false, data);

        // Transfer BPT to treasury
        bptAmountOut = pool.balanceOf(address(this));
        require(bptAmountOut > 0, "BalancerBorrowAndAdd: bptAmountOut == 0");

        // Burn pending balance
        _burnPendingBalance();
        _purge(address(pool));
        _purge(address(tokenOut));
        _purge(address(_debt()));
    }

    function _getTokenBalances() internal view returns (uint256[] memory amountsIn) {
        IERC20[] memory tokens = pool.getTokens();
        amountsIn = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            amountsIn[i] = tokens[i].balanceOf(address(this));
        }
    }

    function _approve(address token) internal {
        permit2.approve(token, address(router), type(uint160).max, uint48(block.timestamp + 1));
    }

    function estimateBptOutput(uint256[] memory amountsIn) external view returns (uint256 bptEstimate) {
        uint256 totalSupply = pool.totalSupply();
        (,, uint256[] memory balancesRaw,) = pool.getTokenInfo();

        uint256 minRatio = type(uint256).max;
        for (uint256 i = 0; i < amountsIn.length; i++) {
            if (balancesRaw[i] > 0) {
                uint256 ratio = (totalSupply * amountsIn[i]) / balancesRaw[i];
                if (ratio < minRatio) minRatio = ratio;
            }
        }

        return minRatio;
    }

    function _purge(address token) internal {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) IERC20(token).transfer(address(_treasury()), balance);
    }
}
