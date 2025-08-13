// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "./IBridge.sol";
import {
    MessagingFee,
    MessagingReceipt
} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

interface IBridgeL2 {
    /// @notice The read channel
    function READ_CHANNEL() external view returns (uint32);

    /// @notice The mainnet eid
    function MAINNET_EID() external view returns (uint32);

    /// @notice The liquid staking
    function LIQUID_STAKING_MAINNET() external view returns (address);

    /// @notice Get the state of the bridge
    /// @dev This function is used to get the state of the bridge
    function data() external view returns (uint32, uint256, uint256);

    /// @notice Sync the rate of the bridge
    /// @param _extraOptions Extra options for the read
    /// @return receipt LayerZero messaging receipt containing transaction details
    function syncRate(bytes calldata _extraOptions) external payable returns (MessagingReceipt memory);

    /// @notice Quote the read fee
    /// @param _extraOptions Extra options for the read
    /// @return fee The fee to pay for the read
    function quoteReadFee(bytes calldata _extraOptions) external view returns (MessagingFee memory fee);
}
