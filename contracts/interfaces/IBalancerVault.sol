// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBalancerVault {
    enum BalancerTokenType {
        STANDARD,
        WITH_RATE
    }

    struct BalancerTokenInfo {
        BalancerTokenType tokenType;
        address rateProvider;
        bool paysYieldFees;
    }

    struct BalancerPoolData {
        bytes32 poolConfigBits;
        IERC20[] tokens;
        BalancerTokenInfo[] tokenInfo;
        uint256[] balancesRaw;
        uint256[] balancesLiveScaled18;
        uint256[] tokenRates;
        uint256[] decimalScalingFactors;
    }

    function getPoolData(address pool) external view returns (BalancerPoolData memory);

    function addLiquidityProportional(
        address pool,
        uint256[] memory maxAmountsIn,
        uint256 exactBptAmountOut,
        bool wethIsEth,
        bytes memory userData
    ) external payable returns (uint256[] memory amountsIn);
}

interface IBalancerPool is IERC20 {
    struct BalancerTokenInfo {
        uint256 balancesRaw;
        address tokens;
        bool what;
    }

    function getNormalizedWeights() external view returns (uint256[] memory);

    function getTokens() external view returns (IERC20[] memory);

    function getTokenInfo()
        external
        view
        returns (
            IERC20[] memory tokens,
            BalancerTokenInfo[] memory tokenInfo,
            uint256[] memory balancesRaw,
            uint256[] memory lastBalancesLiveScaled18
        );
}

interface IBalancerV3Router {
    function addLiquidityProportional(
        address pool,
        uint256[] memory maxAmountsIn,
        uint256 exactBptAmountOut,
        bool wethIsEth,
        bytes memory userData
    ) external payable returns (uint256[] memory amountsIn);
}
