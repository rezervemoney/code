// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import "../interfaces/IAppConvertibles.sol";

contract BoostedBalanceChecker {
    IAppConvertibles public immutable convertible;

    constructor(address _convertible) {
        convertible = IAppConvertibles(_convertible);
    }

    function balanceOf(address user) external view returns (uint256 boostedBalance) {
        uint256 balance = convertible.balanceOf(user);

        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = convertible.tokenOfOwnerByIndex(user, i);
            IAppConvertibles.Position memory position = convertible.positions(tokenId);
            boostedBalance += (position.amountStaked * position.lockDuration) / convertible.MAX_LOCK_DURATION();
        }
    }
}
