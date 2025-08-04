// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../../../interfaces/IOracleV2.sol";
import "../../../interfaces/IAppOracle.sol";
import "../../../interfaces/IBalancerVault.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

interface ICurveTriCrypto {
    function coins(uint256 i) external view returns (address);

    function balances(uint256 i) external view returns (uint256);

    function totalSupply() external view returns (uint256);
}

/**
 * @title BalancerLPOracle
 * @notice An oracle for a Balancer LP token.
 */
contract CurveTriCryptoOracle is IOracleV2 {
    /// @notice The app oracle
    IAppOracle public immutable appOracle;

    /// @inheritdoc IOracleV2
    IERC20Metadata public immutable asset;

    /// @notice The Curve TriCrypto pool
    ICurveTriCrypto public immutable pool;

    /// @notice Constructor
    /// @param _curveTriCrypto The Curve TriCrypto pool
    /// @param _appOracle The app oracle
    constructor(address _curveTriCrypto, IAppOracle _appOracle) {
        require(_curveTriCrypto != address(0), "Invalid curve tri crypto address");
        require(address(_appOracle) != address(0), "Invalid app oracle");

        appOracle = _appOracle;
        asset = IERC20Metadata(_curveTriCrypto);
        pool = ICurveTriCrypto(address(asset));

        _checkOracle(pool.coins(0));
        _checkOracle(pool.coins(1));
        _checkOracle(pool.coins(2));
    }

    /// @inheritdoc IOracleV2
    function getPriceForAmount(uint256 amount)
        public
        view
        returns (uint256 rzrAssets, uint256 usdAssets, uint256 lastUpdatedAt)
    {
        uint256 totalSupply = pool.totalSupply();

        {
            address tokenA = pool.coins(0);
            uint256 balanceA = pool.balances(0);
            uint256 amountA = balanceA * amount / totalSupply;
            (uint256 rzrAmountA, uint256 usdAmountA, uint256 lastUpdatedAtA) =
                appOracle.getPriceForAmount(tokenA, amountA);
            rzrAssets = rzrAmountA;
            usdAssets = usdAmountA;
            lastUpdatedAt = lastUpdatedAtA;
        }
        {
            address tokenB = pool.coins(1);
            uint256 balanceB = pool.balances(1);
            uint256 amountB = balanceB * amount / totalSupply;
            (uint256 rzrAmountB, uint256 usdAmountB, uint256 lastUpdatedAtB) =
                appOracle.getPriceForAmount(tokenB, amountB);
            rzrAssets += rzrAmountB;
            usdAssets += usdAmountB;
            lastUpdatedAt = Math.min(lastUpdatedAt, lastUpdatedAtB);
        }
        {
            address tokenC = pool.coins(2);
            uint256 balanceC = pool.balances(2);
            uint256 amountC = balanceC * amount / totalSupply;
            (uint256 rzrAmountC, uint256 usdAmountC, uint256 lastUpdatedAtC) =
                appOracle.getPriceForAmount(tokenC, amountC);
            rzrAssets += rzrAmountC;
            usdAssets += usdAmountC;
            lastUpdatedAt = Math.min(lastUpdatedAt, lastUpdatedAtC);
        }
    }

    function _checkOracle(address token) internal view {
        require(token != address(asset), "Token is the same as the asset");
        (uint256 rzrAmount, uint256 usdAmount, uint256 lastUpdatedAt) = appOracle.getPriceForAmount(token, 1e18);
        require(rzrAmount > 0 || usdAmount > 0, "Invalid price");
        require(lastUpdatedAt > 0, "Invalid last updated at");
    }
}
