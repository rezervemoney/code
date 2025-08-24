// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import {BaseTreasuryHelper, IERC20} from "./BaseTreasuryHelper.sol";
import {IEVC} from "evc/interfaces/IEthereumVaultConnector.sol";
import {IEVault} from "evk/EVault/IEVault.sol";

abstract contract EulerBorrowerHelper is BaseTreasuryHelper {
    IEVC public immutable evc;
    IEVault public immutable borrowVault;
    IEVault public immutable collateralVault;

    constructor(address _evc, address _borrowVault, address _collateralVault) {
        evc = IEVC(_evc);
        borrowVault = IEVault(_borrowVault);
        collateralVault = IEVault(_collateralVault);
    }

    function _collateral() internal view returns (IERC20) {
        return IERC20(collateralVault.asset());
    }

    function _debt() internal view returns (IERC20) {
        return IERC20(borrowVault.asset());
    }

    /// @notice Repay debt and remove collateral from Euler
    /// @param repayAmountOrShares The amount of debt to repay or the amount of shares to use to repay the debt
    /// @param removeCollateralAmount The amount of collateral to remove
    /// @param useShares Whether to use shares to repay the debt
    function _repayAndReoveCollateral(uint256 repayAmountOrShares, uint256 removeCollateralAmount, bool useShares)
        internal
        whenNotKilled
    {
        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](2);
        items[0] = _repay(repayAmountOrShares, useShares);
        items[1] = _removeCollateral(removeCollateralAmount);
        evc.batch(items);
    }

    /// @notice Add collateral and borrow from Euler
    /// @param addCollateralAmount The amount of collateral to add
    /// @param borrowAmount The amount of debt to borrow
    /// @param receiver The address to receive the borrowed tokens
    function _addCollateralAndBorrow(uint256 addCollateralAmount, uint256 borrowAmount, address receiver)
        internal
        whenNotKilled
    {
        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](2);
        items[0] = _addCollateral(addCollateralAmount);
        items[1] = _borrow(borrowAmount, receiver);
        evc.batch(items);
    }

    /// @notice Borrow from Euler
    /// @param amount The amount of debt to borrow
    /// @param receiver The address to receive the borrowed tokens
    function _borrow(uint256 amount, address receiver)
        internal
        view
        whenNotKilled
        returns (IEVC.BatchItem memory item)
    {
        item = IEVC.BatchItem({
            targetContract: address(borrowVault),
            onBehalfOfAccount: address(_treasury()),
            value: 0,
            data: abi.encodeWithSelector(borrowVault.borrow.selector, amount, receiver)
        });
    }

    /// @notice Repay debt
    /// @param sharesOrAmount The amount of debt to repay or the amount of shares to use to repay the debt
    /// @param useShares Whether to use shares to repay the debt
    function _repay(uint256 sharesOrAmount, bool useShares)
        internal
        view
        whenNotKilled
        returns (IEVC.BatchItem memory item)
    {
        if (useShares) {
            item = IEVC.BatchItem({
                targetContract: address(borrowVault),
                onBehalfOfAccount: address(_treasury()),
                value: 0,
                data: abi.encodeWithSelector(borrowVault.repayWithShares.selector, sharesOrAmount, address(_treasury()))
            });
        } else {
            item = IEVC.BatchItem({
                targetContract: address(borrowVault),
                onBehalfOfAccount: address(_treasury()),
                value: 0,
                data: abi.encodeWithSelector(borrowVault.repay.selector, sharesOrAmount, address(_treasury()))
            });
        }
    }

    /// @notice Add collateral
    /// @param amount The amount of collateral to add
    function _addCollateral(uint256 amount) internal view whenNotKilled returns (IEVC.BatchItem memory item) {
        item = IEVC.BatchItem({
            targetContract: address(collateralVault),
            onBehalfOfAccount: address(_treasury()),
            value: 0,
            data: abi.encodeWithSelector(collateralVault.deposit.selector, amount, address(_treasury()))
        });
    }

    /// @notice Remove collateral
    /// @param amount The amount of collateral to remove
    function _removeCollateral(uint256 amount) internal view whenNotKilled returns (IEVC.BatchItem memory item) {
        item = IEVC.BatchItem({
            targetContract: address(collateralVault),
            onBehalfOfAccount: address(_treasury()),
            value: 0,
            data: abi.encodeWithSelector(collateralVault.withdraw.selector, amount, address(_treasury()))
        });
    }
}
