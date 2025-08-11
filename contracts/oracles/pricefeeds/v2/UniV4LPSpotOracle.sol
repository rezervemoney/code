// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../../../interfaces/IAppOracle.sol";
import "../../../interfaces/IOracleV2.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@uniswap/v4-core/src/types/PoolKey.sol";
import "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import "@uniswap/v4-core/src/libraries/FixedPoint96.sol";
import "@uniswap/v4-core/src/libraries/FullMath.sol";
import "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import "@uniswap/v4-core/src/types/Currency.sol";

using CurrencyLibrary for Currency;

/**
 * @title UniV4LPSpotOracle
 * @notice This contract fetches the spot price from a Uniswap V4 pool using slot0
 * @dev Do not use this contract directly in any onchain code. Use it only for frontend
 * @dev Price is returned in 18 decimals
 */
contract UniV4LPSpotOracle is IOracleV2 {
    /// @notice The quote token
    IERC20Metadata public quoteToken;

    /// @notice The base token
    IERC20Metadata public baseToken;

    /// @notice The asset (pool address)
    IERC20Metadata public immutable asset;

    /// @notice The pool manager
    IPoolManager public poolManager;

    /// @notice The pool key
    PoolKey public poolKey;

    /// @notice The app oracle for USD conversion
    IAppOracle public appOracle;

    address public immutable weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// @notice Constructor
    /// @param _poolManager The Uniswap V4 pool manager
    /// @param _poolKey The pool key containing token addresses and fee info
    /// @param _baseToken The base token (token we want to price)
    /// @param _appOracle The app oracle for USD conversion
    constructor(IPoolManager _poolManager, PoolKey memory _poolKey, address _baseToken, IAppOracle _appOracle) {
        poolManager = _poolManager;
        poolKey = _poolKey;
        baseToken = IERC20Metadata(_baseToken);
        appOracle = _appOracle;

        // Determine quote token (the other token in the pair)
        address token0 = Currency.unwrap(_poolKey.currency0);
        address token1 = Currency.unwrap(_poolKey.currency1);

        if (_baseToken == token0) {
            quoteToken = IERC20Metadata(token1);
            asset = IERC20Metadata(token0);
        } else if (_baseToken == token1) {
            quoteToken = IERC20Metadata(token0);
            asset = IERC20Metadata(token1);
        } else {
            revert("Base token not in pool");
        }

        if (address(quoteToken) == address(0)) quoteToken = IERC20Metadata(weth);
    }

    /// @inheritdoc IOracleV2
    function getPriceForAmount(uint256 amount)
        external
        view
        override
        returns (uint256 rzrAssets, uint256 usdAssets, uint256 lastUpdatedAt)
    {
        // Get current sqrt price from the pool
        (uint160 sqrtPriceX96,,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());

        // Calculate the spot price: (sqrtPriceX96 / 2^96)^2
        // This gives us the price of token1 in terms of token0
        uint256 priceX96 = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96);

        // Convert to 18 decimals
        uint256 price = FullMath.mulDiv(priceX96, 1e18, FixedPoint96.Q96);

        // Determine if we need to invert the price based on token ordering
        address token0 = Currency.unwrap(poolKey.currency0);

        if (address(baseToken) == token0) {
            // Base token is token0, so price is already correct (token1/token0)
            // Convert amount of base token to quote token value
            uint256 quoteTokenAmount = FullMath.mulDiv(amount, price, 1e18);
            usdAssets = quoteTokenAmount;
        } else {
            // Base token is token1, so we need to invert the price (token0/token1)
            uint256 invertedPrice = FullMath.mulDiv(1e18, 1e18, price);
            uint256 quoteTokenAmount = FullMath.mulDiv(amount, invertedPrice, 1e18);
            usdAssets = quoteTokenAmount;
        }

        // Convert quote token amount to USD using appOracle
        if (usdAssets > 0) {
            (uint256 rzrQuote, uint256 usdQuote, uint256 lastUpdatedQuote) =
                appOracle.getPriceForAmount(address(quoteToken), usdAssets);
            rzrAssets = rzrQuote;
            usdAssets = usdQuote;
            lastUpdatedAt = lastUpdatedQuote;
        } else {
            rzrAssets = 0;
            lastUpdatedAt = block.timestamp;
        }
    }
}
