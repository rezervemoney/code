// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "../../../interfaces/IOracleV2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BeaconOracle
 * @notice This contract is a wrapper around an IOracleV2 that allows for the beacon to be updated.
 */
contract BeaconOracle is IOracleV2, Ownable {
    /// @notice The beacon to use
    IOracleV2 public beacon;

    /// @notice Event emitted when the beacon is updated
    event BeaconUpdated(IOracleV2 indexed newBeacon);

    /// @notice The asset
    IERC20Metadata public immutable asset;

    /// @notice Constructor
    /// @param _beacon The initial beacon
    constructor(IOracleV2 _beacon, address _asset) Ownable(msg.sender) {
        asset = IERC20Metadata(_asset);
        _setBeacon(_beacon);
    }

    /// @notice Sets the beacon
    /// @param _beacon The new beacon
    function setBeacon(IOracleV2 _beacon) external onlyOwner {
        _setBeacon(_beacon);
    }

    /// @inheritdoc IOracleV2
    function getPriceForAmount(uint256 amount)
        external
        view
        override
        returns (uint256 rzrAssets, uint256 usdAssets, uint256 lastUpdatedAt)
    {
        (rzrAssets, usdAssets, lastUpdatedAt) = beacon.getPriceForAmount(amount);
    }

    /// @notice Sets the beacon
    /// @param _beacon The new beacon
    function _setBeacon(IOracleV2 _beacon) internal {
        require(address(_beacon) != address(0), "Invalid beacon address");
        require(_beacon.asset() == asset, "Beacon asset mismatch");
        beacon = _beacon;
        emit BeaconUpdated(_beacon);
    }
}
