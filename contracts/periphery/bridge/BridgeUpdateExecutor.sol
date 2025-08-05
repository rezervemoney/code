// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import "../../interfaces/IBridgeL1Reader.sol";
import "../../core/AppAccessControlled.sol";

contract BridgeUpdateExecutor is AppAccessControlled {
    IBridgeL1Reader public immutable bridgeL1Reader;

    constructor(address _authority, address _bridgeL1Reader) {
        __AppAccessControlled_init(_authority);
        bridgeL1Reader = IBridgeL1Reader(_bridgeL1Reader);
    }

    receive() external payable {}

    function updateReserves(uint32[] calldata _eids, uint256[] calldata _fees) external payable onlyExecutor {
        for (uint256 i = 0; i < _eids.length; i++) {
            uint256 fee = _fees[i];
            uint32 eid = _eids[i];
            bridgeL1Reader.syncL2Reserves{value: fee}(eid, "0x");
        }
    }
}
