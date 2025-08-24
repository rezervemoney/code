// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "../../../interfaces/IAppOracle.sol";
import "../../../interfaces/IOracleV2.sol";
import "../../../libraries/UniV4PositionHelper.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title UniV4LPPosOracle
 * @notice An oracle for a Uniswap V4 LP token.
 * @dev This oracle is used to get the price of a Uniswap V4 LP token in RZR and USD.
 */
contract UniV4LPPosOracle is IOracleV2, IERC20Metadata, UniV4PositionHelper {
    IAppOracle public appOracle;

    /// @notice The asset
    IERC20Metadata public immutable asset;

    string public name;
    string public symbol;
    IERC721 public positionManager;
    address public poolManager;
    uint256 public tokenId;

    address public immutable weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    constructor(
        string memory _name,
        string memory _symbol,
        address _positionManager,
        address _poolManager,
        uint256 _tokenId,
        IAppOracle _appOracle
    ) {
        name = _name;
        symbol = _symbol;
        positionManager = IERC721(_positionManager);
        poolManager = _poolManager;
        tokenId = _tokenId;
        appOracle = _appOracle;
        asset = IERC20Metadata(address(this));
        (uint256 rzrAmount, uint256 usdAmount,) = getPriceForAmount(1e18);
        require(rzrAmount > 0 || usdAmount > 0, "Invalid price");
    }

    function decimals() external pure override returns (uint8) {
        return 18;
    }

    function totalSupply() external pure override returns (uint256) {
        return 1e18;
    }

    function balanceOf(address who) external view override returns (uint256) {
        return positionManager.ownerOf(tokenId) == who ? 1e18 : 0;
    }

    function allowance(address, address) external pure override returns (uint256) {
        return 0;
    }

    function transfer(address, uint256) external pure override returns (bool) {
        revert("Not implemented");
    }

    function transferFrom(address, address, uint256) external pure override returns (bool) {
        revert("Not implemented");
    }

    function approve(address, uint256) external pure override returns (bool) {
        revert("Not implemented");
    }

    /// @inheritdoc IOracleV2
    function getPriceForAmount(uint256)
        public
        view
        override
        returns (uint256 rzrAssets, uint256 usdAssets, uint256 lastUpdatedAt)
    {
        (uint256 amountA, uint256 amountB, address token0, address token1) =
            getPositionAmounts(address(positionManager), poolManager, tokenId);

        if (token0 == address(0)) token0 = weth;
        if (token1 == address(0)) token1 = weth;

        {
            (uint256 rzrA, uint256 usdA, uint256 lastUpdatedAtA) = appOracle.getPriceForAmount(token0, amountA);
            rzrAssets = rzrA;
            usdAssets = usdA;
            lastUpdatedAt = lastUpdatedAtA;
        }
        {
            (uint256 rzrB, uint256 usdB, uint256 lastUpdatedAtB) = appOracle.getPriceForAmount(token1, amountB);
            rzrAssets += rzrB;
            usdAssets += usdB;
            lastUpdatedAt = lastUpdatedAt > lastUpdatedAtB ? lastUpdatedAt : lastUpdatedAtB;
        }
    }
}
