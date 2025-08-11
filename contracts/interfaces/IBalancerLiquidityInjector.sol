// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

interface IBalancerLiquidityInjector {
    function manualDeposit(address gauge, address reward_token, uint256 amount) external;
}
