// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

interface IBalancerLiquidityGauge {
    function deposit_reward_token(address _reward_token, uint256 _amount) external;
}
