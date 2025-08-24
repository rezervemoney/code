// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "../../../interfaces/IOracleV2.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IShadowLP {
    function current(address tokenIn, uint256 amountIn) external view returns (uint256 amountOut);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

/**
 * @title ShadowLPOracle
 * @notice This contract fetches the price from a shadow LP pair
 * @dev Do not use this by any means use this contract directly in any onchain code. Use it only for frontend
 * @dev Price is returned in 18 decimals
 */
contract ShadowLPOracle is IOracleV2 {
    /// @notice The decimal offset
    uint256 public decimalOffset;

    /// @notice The quote token
    IERC20Metadata public quoteToken;

    /// @notice The base token
    IERC20Metadata public baseToken;

    /// @notice The asset
    IERC20Metadata public immutable asset;

    /// @notice Constructor
    /// @param _amm The shadow LP pair
    /// @param _baseToken The base token
    constructor(IShadowLP _amm, address _baseToken) {
        baseToken = IERC20Metadata(_baseToken);
        quoteToken = IERC20Metadata(
            IShadowLP(address(asset)).token0() == _baseToken
                ? IShadowLP(address(asset)).token1()
                : IShadowLP(address(asset)).token0()
        );

        decimalOffset = 10 ** (18 - quoteToken.decimals());

        asset = IERC20Metadata(address(_amm));
    }

    /// @inheritdoc IOracleV2
    function getPriceForAmount(uint256 amount)
        external
        view
        override
        returns (uint256 rzrAssets, uint256 usdAssets, uint256 lastUpdatedAt)
    {
        rzrAssets = 0;
        usdAssets = IShadowLP(address(asset)).current(address(baseToken), amount) * decimalOffset;
        lastUpdatedAt = block.timestamp;
    }
}
