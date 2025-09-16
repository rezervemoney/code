// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.28;

import {OAppSenderProxy} from "./OAppSenderProxy.sol";
import {OAppReceiverProxy} from "./OAppReceiverProxy.sol";

/**
 * @title OApp
 * @dev Abstract contract serving as the base for OApp implementation, combining OAppSender and OAppReceiver functionality.
 */
abstract contract OAppProxy is OAppSenderProxy, OAppReceiverProxy {
    /**
     * @dev Constructor to initialize the OApp with the provided endpoint and owner.
     * @param _endpoint The address of the LOCAL LayerZero endpoint.
     * @param _delegate The delegate capable of making OApp configurations inside of the endpoint.
     */
    function __OAppProxy_init(address _endpoint, address _delegate) internal onlyInitializing {
        __OAppCoreProxy_init(_endpoint, _delegate);
    }

    /**
     * @notice Retrieves the OApp version information.
     * @return senderVersion The version of the OAppSender.sol implementation.
     * @return receiverVersion The version of the OAppReceiver.sol implementation.
     */
    function oAppVersion()
        public
        pure
        virtual
        override(OAppSenderProxy, OAppReceiverProxy)
        returns (uint64 senderVersion, uint64 receiverVersion)
    {
        return (SENDER_VERSION, RECEIVER_VERSION);
    }
}
