// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;
pragma abicoder v2;

import "../interfaces/IAppStaking.sol";
import "../core/AppAccessControlled.sol";

interface IAppStakingMigrator {
    function mint(address to, IAppStaking.Position memory position) external;
}

contract AppStakingMigrator is AppAccessControlled {
    IAppStakingMigrator public immutable staking;
    mapping(uint256 => bool) public migrated;

    struct Migration {
        address to;
        uint256 tokenId;
        IAppStaking.Position position;
    }

    constructor(address _staking, address _authority) {
        staking = IAppStakingMigrator(_staking);
        __AppAccessControlled_init(_authority);
    }

    function migratePositions(Migration[] memory migrations) external onlyExecutor {
        for (uint256 i = 0; i < migrations.length; i++) {
            _migratePosition(migrations[i].to, migrations[i].tokenId, migrations[i].position);
        }
    }

    function _migratePosition(address to, uint256 tokenId, IAppStaking.Position memory position) internal {
        if (migrated[tokenId]) return;
        staking.mint(to, position);
        migrated[tokenId] = true;
    }
}
