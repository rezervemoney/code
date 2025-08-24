// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import "@uniswap/v4-core/src/types/PoolKey.sol";
import "@uniswap/v4-periphery/src/libraries/PositionInfoLibrary.sol";
import "@uniswap/v4-core/src/libraries/TickMath.sol";
import "@uniswap/v4-core/src/libraries/FixedPoint96.sol";
import "@uniswap/v4-core/src/libraries/FullMath.sol";
import "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import "@uniswap/v4-core/src/types/Currency.sol";

using CurrencyLibrary for Currency;

/**
 * @title UniV4PositionHelper
 * @notice Helper contract for getting current token amounts in Uniswap V4 positions
 */
contract UniV4PositionHelper {
    /// @notice Get the current amounts of token0 and token1 in a Uniswap V4 position
    /// @param positionManager The address of the Uniswap V4 PositionManager contract
    /// @param poolManager The address of the Uniswap V4 PoolManager contract
    /// @param tokenId The NFT token ID of the position
    /// @return amount0 The current amount of token0 in the position
    /// @return amount1 The current amount of token1 in the position
    function getPositionAmounts(address positionManager, address poolManager, uint256 tokenId)
        internal
        view
        returns (uint256 amount0, uint256 amount1, address token0, address token1)
    {
        IPositionManager pm = IPositionManager(positionManager);
        IPoolManager pool = IPoolManager(poolManager);

        // Get the position's liquidity and pool information
        uint128 liquidity = pm.getPositionLiquidity(tokenId);
        (PoolKey memory poolKey, PositionInfo positionInfo) = pm.getPoolAndPositionInfo(tokenId);

        // Extract tick range from position info
        int24 tickLower = positionInfo.tickLower();
        int24 tickUpper = positionInfo.tickUpper();

        token0 = Currency.unwrap(poolKey.currency0);
        token1 = Currency.unwrap(poolKey.currency1);

        // Get current sqrt price from the pool
        (uint160 sqrtPriceX96,,,) = StateLibrary.getSlot0(pool, poolKey.toId());

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
            // For in-range positions, use the standard Uniswap V3/V4 formula:
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
