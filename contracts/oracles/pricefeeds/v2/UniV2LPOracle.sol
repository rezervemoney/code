// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../../../interfaces/IAppOracle.sol";
import "../../../interfaces/IOracleV2.sol";
import "../../../interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title UniV2LPOracle
 * @notice An oracle for a Uniswap V2 LP token.
 * @dev This oracle is used to get the price of a Uniswap V2 LP token in RZR and USD.
 */
contract UniV2LPOracle is IOracleV2 {
    IUniswapV2Pair public amm;
    IAppOracle public appOracle;

    /// @notice The asset
    IERC20Metadata public immutable asset;

    constructor(address _uniV2LP, IAppOracle _appOracle) {
        amm = IUniswapV2Pair(_uniV2LP);
        appOracle = _appOracle;
        asset = IERC20Metadata(_uniV2LP);
        (uint256 rzrAmount, uint256 usdAmount,) = getPriceForAmount(1e18);
        require(rzrAmount > 0 || usdAmount > 0, "Invalid price");
    }

    /// @inheritdoc IOracleV2
    function getPriceForAmount(uint256 amount)
        public
        view
        override
        returns (uint256 rzrAssets, uint256 usdAssets, uint256 lastUpdatedAt)
    {
        uint256 totalSupply = amm.totalSupply();

        (uint256 balanceA, uint256 balanceB,) = amm.getReserves();

        {
            uint256 amountA = balanceA * amount / totalSupply;
            (uint256 rzrA, uint256 usdA, uint256 lastUpdatedAtA) = appOracle.getPriceForAmount(amm.token0(), amountA);
            rzrAssets = rzrA;
            usdAssets = usdA;
            lastUpdatedAt = lastUpdatedAtA;
        }
        {
            uint256 amountB = balanceB * amount / totalSupply;
            (uint256 rzrB, uint256 usdB, uint256 lastUpdatedAtB) = appOracle.getPriceForAmount(amm.token1(), amountB);
            rzrAssets += rzrB;
            usdAssets += usdB;
            lastUpdatedAt = Math.min(lastUpdatedAt, lastUpdatedAtB);
        }
    }
}
