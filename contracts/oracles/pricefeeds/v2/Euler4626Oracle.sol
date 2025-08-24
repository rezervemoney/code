// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "../../../interfaces/IOracleV2.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract Euler4626Oracle is IOracleV2 {
    IERC4626 public immutable VAULT;
    IOracleV2 public immutable UNDERLYING_ORACLE;

    IERC20Metadata public immutable asset;

    constructor(IERC4626 _vault, address _underlyingOracle) {
        VAULT = _vault;
        UNDERLYING_ORACLE = IOracleV2(_underlyingOracle);
        asset = IERC20Metadata(address(VAULT));
        require(address(UNDERLYING_ORACLE.asset()) == address(VAULT.asset()), "Asset mismatch");

        (uint256 rzrAssets, uint256 usdAssets,) = getPriceForAmount(1e18);
        require(rzrAssets > 0 || usdAssets > 0, "Invalid price");
    }

    /// @inheritdoc IOracleV2
    function getPriceForAmount(uint256 shares)
        public
        view
        override
        returns (uint256 rzrAssets, uint256 usdAssets, uint256 lastUpdatedAt)
    {
        uint256 underlyingAmount = VAULT.convertToAssets(shares);
        (rzrAssets, usdAssets, lastUpdatedAt) = UNDERLYING_ORACLE.getPriceForAmount(underlyingAmount);
    }
}
