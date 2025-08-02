// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../../../interfaces/IAppOracle.sol";
import "../../../interfaces/IOracleV2.sol";
import "../../../interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title UniV2LPOracle
 * @notice An oracle for a Uniswap V2 LP token.
 * @dev This oracle is used to get the price of a Uniswap V2 LP token in RZR and USD.
 */
contract UniV2LPOracle is IOracleV2 {
    IUniswapV2Pair public amm;
    address public rzr;
    IAppOracle public appOracle;

    /// @notice The asset
    IERC20Metadata public immutable asset;

    constructor(address _uniV2LP, address _rzr, IAppOracle _appOracle) {
        amm = IUniswapV2Pair(_uniV2LP);
        rzr = _rzr;
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

        (uint256 reserve0, uint256 reserve1,) = amm.getReserves();

        uint256 amount0 = amount * reserve0 / totalSupply;
        uint256 amount1 = amount * reserve1 / totalSupply;

        if (amm.token0() == rzr) {
            rzrAssets = amount0;

            // convert amount1 to usd
            usdAssets = getPrice(amm.token1(), amount1);
        } else {
            rzrAssets = amount1;

            // convert amount0 to usd
            usdAssets = getPrice(amm.token0(), amount0);
        }
    }

    /// @notice Get the price of a token in 1e18
    /// @param token The token to get the price of
    /// @return price The price of the token in 1e18
    function getPrice(address token, uint256 amount) public view returns (uint256) {
        uint8 decimals = IERC20Metadata(token).decimals();
        (, uint256 usdAmount,) = appOracle.getPriceForAmount(token, amount);
        return (usdAmount * 1e18) / (10 ** decimals); // convert to 1e18
    }
}
