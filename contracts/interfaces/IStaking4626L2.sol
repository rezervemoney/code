// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "@openzeppelin/contracts/interfaces/IERC4626.sol";

interface IStaking4626L2 is IERC4626 {
    /// @notice Emitted when the rate is updated
    /// @param rate The new rate
    /// @param oldRate The old rate
    event RateUpdated(uint256 rate, uint256 oldRate);

    /// @notice Emitted when the deposit fee is updated
    /// @param depositFee The new deposit fee
    event DepositFeeUpdated(uint256 depositFee);

    /// @notice Emitted when a deposit fee is collected
    /// @param user The user who paid the fee
    /// @param feeAmount The amount of fee collected
    event DepositFeeCollected(address indexed user, uint256 feeAmount);

    /// @notice The rate of the staking
    function rate() external view returns (uint256);

    /// @notice The deposit fee
    function depositFee() external view returns (uint256);

    /// @notice Set the deposit fee
    /// @param _depositFee The new deposit fee
    function setDepositFee(uint256 _depositFee) external;

    /// @notice Initialize the staking contract
    /// @param _authority The address of the authority contract
    /// @param _lzEndpoint The address of the LayerZero endpoint
    /// @param _delegate The address of the delegate contract
    /// @param _underlying The underlying token of the staking
    function initialize(address _authority, address _lzEndpoint, address _delegate, address _underlying) external;

    /// @notice Set the rate of the staking
    /// @param _rate The new rate of the staking
    function setRate(uint256 _rate) external;
}
