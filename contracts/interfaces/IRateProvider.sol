// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

interface IRateProvider {
    function getRate() external view returns (uint256 _rate);
}
