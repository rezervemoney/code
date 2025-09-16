// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "../AppAccessControlled.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract USDDistributor is AppAccessControlled {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _assets;
    mapping(address asset => uint256 shares) private _shares;

    struct Distribution {
        address asset;
        uint256 shares;
    }

    IERC20 public immutable usdr;

    event Distributed(address asset, uint256 shares);
    event DistributionSet(Distribution[] distributions);

    constructor(address _authority, IERC20 _usdr) {
        __AppAccessControlled_init(_authority);
        usdr = _usdr;
    }

    /// @notice Set the distribution
    /// @param _distributions The distributions
    /// @dev This function is only callable by the governor
    function setDistribution(Distribution[] memory _distributions) external onlyGovernor {
        _assets.clear();
        uint256 totalShares = 0;
        for (uint256 i = 0; i < _distributions.length; i++) {
            _assets.add(address(_distributions[i].asset));
            _shares[address(_distributions[i].asset)] = _distributions[i].shares;
            totalShares += _distributions[i].shares;
        }

        require(totalShares == 1e18, "Total shares must be 1e18");
        emit DistributionSet(_distributions);
    }

    /// @notice Distribute the USDR to the assets
    /// @dev This function is only callable by the executor
    function distribute() external onlyExecutor {
        uint256 balance = usdr.balanceOf(address(this));
        uint256 length = _assets.length();
        for (uint256 i = 0; i < length; i++) {
            address asset = _assets.at(i);
            uint256 shares = _shares[asset] * balance / 1e18;
            usdr.safeTransfer(asset, shares);
            emit Distributed(asset, shares);
        }
    }

    /// @notice Get the assets
    /// @return totalAssets The assets
    function assets() external view returns (address[] memory totalAssets) {
        totalAssets = _assets.values();
    }

    /// @notice Get the shares for an asset
    /// @param asset The asset
    /// @return share The shares
    function shares(address asset) external view returns (uint256 share) {
        share = _shares[asset];
    }
}
