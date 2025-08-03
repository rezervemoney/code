// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import "../core/AppAccessControlled.sol";
import "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract OAppControlledProxy is OApp, AppAccessControlled {
    constructor(address _lzEndpoint, address _delegate, address owner) OApp(_lzEndpoint, _delegate) Ownable(owner) {}

    function __OAppControlledProxy_init(address _delegate, address _authority) internal onlyInitializing {
        __AppAccessControlled_init(_authority);
        endpoint.setDelegate(_delegate);
    }

    function _checkOwner() internal view virtual override {
        if (!authority.isGovernor(_msgSender())) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }
}
