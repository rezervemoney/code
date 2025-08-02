// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../../../interfaces/IOracleV2.sol";
import "../../../interfaces/IAppOracle.sol";
import "../../../interfaces/IBalancerVault.sol";
import "../../../utils/BalancerMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title BalancerLPOracle
 * @notice An oracle for a Balancer LP token.
 */
contract BalancerLPOracle is BalancerMath, IOracleV2 {
    /// @notice The Balancer vault
    IBalancerVault public vault;

    /// @notice The Balancer pool
    address public pool;

    /// @notice The rzr
    address public rzr;

    /// @notice The app oracle
    IAppOracle public appOracle;

    /// @notice The asset
    IERC20Metadata public immutable asset;

    /// @notice Constructor
    /// @param _vault The Balancer vault
    /// @param _balancerLP The Balancer pool
    /// @param _rzr The rzr
    /// @param _appOracle The app oracle
    constructor(address _vault, address _balancerLP, address _rzr, IAppOracle _appOracle) {
        require(_vault != address(0), "Invalid vault");
        require(_balancerLP != address(0), "Invalid balancer LP");
        require(_rzr != address(0), "Invalid rzr");
        require(address(_appOracle) != address(0), "Invalid app oracle");

        vault = IBalancerVault(_vault);
        pool = _balancerLP;
        rzr = _rzr;
        appOracle = _appOracle;
        asset = IERC20Metadata(_balancerLP);
    }

    /// @inheritdoc IOracleV2
    function getPriceForAmount(uint256 amount)
        public
        view
        returns (uint256 rzrAssets, uint256 usdAssets, uint256 lastUpdatedAt)
    {
        IBalancerVault.BalancerPoolData memory poolData = vault.getPoolData(pool);
        require(poolData.tokens.length == 2, "num tokens must be 2");

        IERC20 tokenA = poolData.tokens[0];
        IERC20 tokenB = poolData.tokens[1];

        uint256 balanceA = poolData.balancesRaw[0];
        uint256 balanceB = poolData.balancesRaw[1];

        uint256 totalSupply = IERC20(pool).totalSupply();
        uint256 amountA = balanceA * amount / totalSupply;
        uint256 amountB = balanceB * amount / totalSupply;

        if (tokenA == IERC20(address(rzr))) {
            uint256 pxB = getPrice(address(tokenB));
            rzrAssets = amountA;
            usdAssets = amountB * pxB / 1e18;
        } else {
            uint256 pxA = getPrice(address(tokenA));
            rzrAssets = amountB * pxA / 1e18;
            usdAssets = amountA;
        }

        lastUpdatedAt = block.timestamp;
    }

    /// @notice Get the price of a token in USD
    /// @param token The token to get the price of
    /// @return px The price of the token in USD
    function getPrice(address token) public view returns (uint256) {
        uint8 decimals = IERC20Metadata(token).decimals();
        (, uint256 usdAmount,) = appOracle.getPrice(token);
        return (usdAmount * 1e18) / (10 ** decimals); // convert to 1e18
    }
}
