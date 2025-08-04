// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import "../core/AppAccessControlled.sol";
import "../periphery/oft-proxy/OAppProxy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract OAppControlledProxy is OAppProxy, AppAccessControlled {
    function __OAppControlledProxy_init(address _lzEndpoint, address _delegate, address _authority)
        internal
        onlyInitializing
    {
        __AppAccessControlled_init(_authority);
        __OAppProxy_init(_lzEndpoint, _delegate);
    }

    function _checkOwner() internal view virtual override {
        if (!authority.isGovernor(_msgSender())) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }
}
