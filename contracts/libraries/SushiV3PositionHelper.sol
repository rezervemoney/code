// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "@uniswap/v4-core/src/libraries/TickMath.sol";
import "@uniswap/v4-core/src/libraries/FullMath.sol";
import "@uniswap/v4-core/src/libraries/FixedPoint96.sol";

interface IUniswapV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

interface IUniswapV3Pool {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );
}

interface INonfungiblePositionManager {
    function factory() external view returns (address);
    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );
}

/**
 * @title SushiV3PositionHelper
 * @notice Helper contract for getting current token amounts in Uniswap V3 positions
 */
contract SushiV3PositionHelper {
    /// @notice Get the current amounts of token0 and token1 in a Uniswap V3 position
    /// @param positionManager The address of the Uniswap V3 NonfungiblePositionManager contract
    /// @param tokenId The NFT token ID of the position
    /// @return amount0 The current amount of token0 in the position
    /// @return amount1 The current amount of token1 in the position
    /// @return token0 The address of token0
    /// @return token1 The address of token1
    function getPositionAmounts(address positionManager, address poolAddress, uint256 tokenId)
        internal
        view
        returns (uint256 amount0, uint256 amount1, address token0, address token1)
    {
        INonfungiblePositionManager pm = INonfungiblePositionManager(positionManager);

        // Get the position's data
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        (,, token0, token1,, tickLower, tickUpper, liquidity,,,,) = pm.positions(tokenId);

        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);

        // Get current sqrt price from the pool
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();

        // Calculate amounts manually based on current price and liquidity
        uint160 sqrtPriceLowerX96 = TickMath.getSqrtPriceAtTick(tickLower);
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtPriceAtTick(tickUpper);

        // Safety check: ensure proper price ordering
        require(sqrtPriceLowerX96 < sqrtPriceUpperX96, "Invalid tick range");

        if (sqrtPriceX96 <= sqrtPriceLowerX96) {
            // Current price is below the range, only token0
            amount0 = uint256(liquidity) * uint256(sqrtPriceUpperX96 - sqrtPriceLowerX96) / uint256(sqrtPriceUpperX96);
            amount1 = 0;
        } else if (sqrtPriceX96 >= sqrtPriceUpperX96) {
            // Current price is above the range, only token1
            amount0 = 0;
            amount1 = uint256(liquidity) * uint256(sqrtPriceUpperX96 - sqrtPriceLowerX96) / FixedPoint96.Q96;
        } else {
            // Current price is within the range
            // For in-range positions, use the standard Uniswap V3 formula:
            // amount0 = L * (√P_upper - √P_current) / (√P_current * √P_upper / 2^96)
            // amount1 = L * (√P_current - √P_lower) / 2^96

            // Calculate amount0 with correct formula
            uint256 numerator0 = uint256(liquidity) * uint256(sqrtPriceUpperX96 - sqrtPriceX96);
            uint256 denominator0 = uint256(sqrtPriceX96) * uint256(sqrtPriceUpperX96) / FixedPoint96.Q96;
            amount0 = numerator0 / denominator0;

            // Calculate amount1
            amount1 = uint256(liquidity) * uint256(sqrtPriceX96 - sqrtPriceLowerX96) / FixedPoint96.Q96;
        }
    }
}
