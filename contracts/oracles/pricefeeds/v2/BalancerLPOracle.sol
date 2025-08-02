// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../../../interfaces/IOracleV2.sol";
import "../../../interfaces/IAppOracle.sol";
import "../../../interfaces/IBalancerVault.sol";
import "../../../utils/BalancerMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title BalancerLPOracle
 * @notice An oracle for a Balancer LP token.
 */
contract BalancerLPOracle is BalancerMath, IOracleV2 {
    /// @notice The Balancer vault
    IBalancerVault public immutable vault;

    /// @notice The app oracle
    IAppOracle public immutable appOracle;

    /// @inheritdoc IOracleV2
    IERC20Metadata public immutable asset;

    /// @notice Constructor
    /// @param _vault The Balancer vault
    /// @param _balancerLP The Balancer pool
    /// @param _appOracle The app oracle
    constructor(address _vault, address _balancerLP, IAppOracle _appOracle) {
        require(_vault != address(0), "Invalid vault address");
        require(_balancerLP != address(0), "Invalid balancer LP address");
        require(address(_appOracle) != address(0), "Invalid app oracle");

        vault = IBalancerVault(_vault);
        appOracle = _appOracle;
        asset = IERC20Metadata(_balancerLP);

        IBalancerVault.BalancerPoolData memory poolData = vault.getPoolData(address(asset));
        require(poolData.tokens.length == 2, "num tokens must be 2");

        _checkOracle(poolData.tokens[0]);
        _checkOracle(poolData.tokens[1]);
    }

    /// @inheritdoc IOracleV2
    function getPriceForAmount(uint256 amount)
        public
        view
        returns (uint256 rzrAssets, uint256 usdAssets, uint256 lastUpdatedAt)
    {
        IBalancerVault.BalancerPoolData memory poolData = vault.getPoolData(address(asset));
        uint256 totalSupply = asset.totalSupply();

        {
            uint256 balanceA = poolData.balancesRaw[0];
            uint256 amountA = balanceA * amount / totalSupply;
            (uint256 rzrAmountA, uint256 usdAmountA, uint256 lastUpdatedAtA) =
                appOracle.getPriceForAmount(address(poolData.tokens[0]), amountA);
            rzrAssets = rzrAmountA;
            usdAssets = usdAmountA;
            lastUpdatedAt = lastUpdatedAtA;
        }
        {
            uint256 balanceB = poolData.balancesRaw[1];
            uint256 amountB = balanceB * amount / totalSupply;
            (uint256 rzrAmountB, uint256 usdAmountB, uint256 lastUpdatedAtB) =
                appOracle.getPriceForAmount(address(poolData.tokens[1]), amountB);
            rzrAssets += rzrAmountB;
            usdAssets += usdAmountB;
            lastUpdatedAt = Math.min(lastUpdatedAt, lastUpdatedAtB);
        }
    }

    function _checkOracle(IERC20 token) internal view {
        require(address(token) != address(asset), "Token is the same as the asset");
        (uint256 rzrAmount, uint256 usdAmount, uint256 lastUpdatedAt) =
            appOracle.getPriceForAmount(address(token), 1e18);
        require(rzrAmount > 0 || usdAmount > 0, "Invalid price");
        require(lastUpdatedAt > 0, "Invalid last updated at");
    }
}
