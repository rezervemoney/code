// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

interface IShadowLiquidityGauge {
    function notifyRewardAmount(address _rewardsToken, uint256 _reward) external;
}
