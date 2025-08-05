// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import {ITotalSupplyOracle} from "./ITotalSupplyOracle.sol";
import {ITotalReservesOracle} from "./ITotalReservesOracle.sol";
import {IAppTreasury} from "./IAppTreasury.sol";
import {
    MessagingFee,
    MessagingReceipt
} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

interface IBridgeL1Reader {
    /// @notice Emitted when cross-chain function data is successfully received
    event StateReceived(uint32 eid, uint256 rzrSupply, uint256 rzrReserves, uint256 usdReserves);

    /// @notice Emitted when a bridge is registered
    event BridgeRegistered(uint32 eid, address bridgeL2Reader);

    /// @notice Error thrown when a bridge is not registered
    error BridgeNotRegistered(uint32 eid);

    /// @notice The read channel
    function READ_CHANNEL() external view returns (uint32);

    /// @notice The mainnet eid
    function MAINNET_EID() external view returns (uint32);

    /// @notice The bridge L2 readers
    function bridgeL2Readers(uint32 eid) external view returns (address);

    /// @notice The total supply oracle
    function totalSupplyOracle() external view returns (ITotalSupplyOracle);

    /// @notice The total reserves oracle
    function totalReservesOracle() external view returns (ITotalReservesOracle);

    /// @notice The treasury
    function treasury() external view returns (IAppTreasury);

    /// @notice Register a bridge on the target chain
    /// @param _eids The LayerZero endpoint IDs of the target chains
    /// @param _bridgeL2Readers The addresses of the bridges on the target chains
    function registerBridges(uint32[] calldata _eids, address[] calldata _bridgeL2Readers) external;

    /// @notice Sync the mainnet reserves to the total reserves oracle
    function syncMainnetReserves() external;

    /// @notice Read data from a single bridge on the target chain
    /// @param eid The LayerZero endpoint ID of the target chain
    /// @return receipt LayerZero messaging receipt containing transaction details
    function syncL2Reserves(uint32 eid, bytes calldata _extraOptions)
        external
        payable
        returns (MessagingReceipt memory);

    /// @notice Get estimated messaging fee for a cross-chain read operation
    /// @param _eid The LayerZero endpoint ID of the target chain
    /// @return fee Estimated LayerZero messaging fee structure
    function quoteReadFee(uint32 _eid, bytes calldata _extraOptions) external view returns (MessagingFee memory fee);
}
