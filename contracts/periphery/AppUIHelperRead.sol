// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;
pragma abicoder v2;

import "./AppUIHelperBase.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title RZR UI Helper
/// @author RZR Protocol
contract AppUIHelperRead is AppUIHelperBase {
    constructor(InitParams memory params) AppUIHelperBase(params) {}

    /// @notice Get all protocol information for a user
    /// @param user The address of the user
    function getProtocolInfo(address user, address[] memory bondTokens)
        external
        view
        returns (
            ProtocolInfo memory protocolInfo,
            bytes8 referralCode,
            TokenInfo[] memory tokenInfos,
            StakingPositionInfo[] memory stakingPositions,
            BondPositionInfo[] memory bondPositions,
            ProjectedEpochRate memory projectedEpochRate
        )
    {
        // Get protocol-wide stats
        bondPositions = getBondPositions(user);
        projectedEpochRate = getProjectedEpochRate();
        protocolInfo = getProtocolInfo();
        referralCode = referrals.referrerCodes(user);
        stakingPositions = getStakingPositions(user);
        tokenInfos = getTokenInfos(user, bondTokens);
    }

    function getProtocolInfo() internal view returns (ProtocolInfo memory protocolInfo) {
        if (address(totalReservesOracle) != address(0)) {
            (uint256 rzrReserves, uint256 usdReserves) = totalReservesOracle.getTotalReserves();
            protocolInfo.tvlRzr = rzrReserves;
            protocolInfo.tvlUsd = usdReserves;
        }

        if (address(staking) != address(0)) {
            protocolInfo.totalStaked = staking.totalStaked();
            protocolInfo.totalRewards = staking.rewardPerToken();
        }

        protocolInfo.totalSupply = appToken.totalSupply();
        protocolInfo.currentAPR = calculateAPR();
        protocolInfo.currentSpotPrice = getSpotPrice();
        protocolInfo.currentEthPrice = getEthPrice();
    }

    function getSpotPrice() internal view returns (uint256) {
        if (address(spotOracle) != address(0)) {
            (, uint256 spotPrice,) = spotOracle.getPriceForAmount(1e18);
            return spotPrice;
        }
        return 0;
    }

    function getEthPrice() internal view returns (uint256) {
        if (address(ethOracle) != address(0)) {
            (, uint256 ethPrice,) = ethOracle.getPriceForAmount(1e18);
            return ethPrice;
        }
        return 0;
    }

    function getTokenInfos(address user, address[] memory bondTokens)
        internal
        view
        returns (TokenInfo[] memory tokenInfos)
    {
        tokenInfos = new TokenInfo[](bondTokens.length + 3); // +1 for RZR token, +1 for staking token, +1 for lstRZR token

        // Add RZR token info
        tokenInfos[0] = TokenInfo({
            token: address(appToken),
            name: "RZR",
            symbol: "RZR",
            balance: appToken.balanceOf(user),
            allowance: appToken.allowance(user, address(staking)),
            treasuryBalance: appToken.balanceOf(address(treasury)),
            treasuryValueApp: appToken.balanceOf(address(treasury)),
            totalSupply: appToken.totalSupply(),
            decimals: 18,
            oraclePrice: 0, // appOracle.getTokenPrice(),
            oraclePriceInApp: 0 // 1e18
        });

        // Add staking token info
        tokenInfos[1] = TokenInfo({
            token: address(stakingToken),
            name: "Staked RZR",
            symbol: "sRZR",
            balance: stakingToken.balanceOf(user),
            allowance: stakingToken.allowance(user, address(staking)),
            totalSupply: stakingToken.totalSupply(),
            treasuryBalance: 0,
            treasuryValueApp: 0,
            decimals: 18,
            oraclePrice: 0, // appOracle.getTokenPrice(),
            oraclePriceInApp: 0 // 1e18
        });

        // Add lstRZR token info
        tokenInfos[2] = TokenInfo({
            token: address(staking4626),
            name: "Liquid Staked RZR",
            symbol: "lstRZR",
            balance: staking4626.balanceOf(user),
            allowance: 0,
            totalSupply: staking4626.totalSupply(),
            treasuryBalance: staking4626.balanceOf(address(treasury)),
            treasuryValueApp: staking4626.balanceOf(address(treasury)),
            decimals: 18,
            oraclePrice: 0, // appOracle.getPrice(address(staking4626), 1e18),
            oraclePriceInApp: 0 // appOracle.getPriceInToken(address(staking4626), 1e18)
        });

        // Add bond token info
        for (uint256 i = 0; i < bondTokens.length; i++) {
            IERC20Metadata token = IERC20Metadata(bondTokens[i]);
            tokenInfos[i + 3] = TokenInfo({
                balance: token.balanceOf(user),
                allowance: token.allowance(user, address(bondDepository)),
                decimals: token.decimals(),
                totalSupply: token.totalSupply(),
                name: token.name(),
                symbol: token.symbol(),
                treasuryBalance: token.balanceOf(address(treasury)),
                treasuryValueApp: 0, // treasury.tokenValueE18(address(token), token.balanceOf(address(treasury)))[1],
                token: address(token),
                oraclePriceInApp: 0, // appOracle.getPriceInToken(address(token), token.balanceOf(address(treasury))),
                oraclePrice: 0 // appOracle.getPrice(address(token), token.balanceOf(address(treasury)))
            });
        }
    }

    function getStakingPositions(address user) internal view returns (StakingPositionInfo[] memory stakingPositions) {
        if (address(staking) == address(0)) return stakingPositions;

        uint256 stakingBalance = staking.balanceOf(user);
        stakingPositions = new StakingPositionInfo[](stakingBalance);

        for (uint256 i = 0; i < stakingBalance; i++) {
            uint256 tokenId = staking.tokenOfOwnerByIndex(user, i);
            if (tokenId == 0) continue;
            IAppStaking.Position memory position = staking.positions(tokenId);

            bool inBuyCooldown = position.buyCooldownEnd > 0 && block.timestamp < position.buyCooldownEnd;
            bool inWithdrawCooldown =
                position.withdrawCooldownStart > 0 && block.timestamp < position.withdrawCooldownStart;
            uint256 withdrawCooldownStart = position.withdrawCooldownStart;

            stakingPositions[i] = StakingPositionInfo({
                owner: user,
                id: tokenId,
                amount: position.amount,
                declaredValue: position.declaredValue,
                rewards: staking.earned(tokenId),
                withdrawCooldownEnd: position.withdrawCooldownEnd,
                isActive: position.withdrawCooldownEnd == 0,
                inCooldown: inBuyCooldown,
                inWithdrawCooldown: inWithdrawCooldown,
                withdrawCooldownStart: withdrawCooldownStart,
                isFrom4626: staking4626.unstakingTokenId(tokenId)
            });
        }
    }

    function getBondPositions(address user) internal view returns (BondPositionInfo[] memory bondPositions) {
        if (address(bondDepository) == address(0)) return bondPositions;

        uint256 bondBalance = bondDepository.balanceOf(user);
        bondPositions = new BondPositionInfo[](bondBalance);

        for (uint256 i = 0; i < bondBalance; i++) {
            uint256 tokenId = bondDepository.tokenOfOwnerByIndex(user, i);
            IAppBondDepository.BondPosition memory position = bondDepository.positions(tokenId);

            bondPositions[i] = BondPositionInfo({
                owner: user,
                id: tokenId,
                bondId: position.bondId,
                amount: position.amount,
                quoteAmount: position.quoteAmount,
                startTime: position.startTime,
                lastClaimTime: position.lastClaimTime,
                claimedAmount: position.claimedAmount,
                vestingPeriod: position.vestingPeriod,
                claimableAmount: bondDepository.claimableAmount(tokenId),
                isStaked: position.isStaked
            });
        }
    }

    function getBondPositionsByIndex(uint256 startIndex, uint256 endIndex)
        external
        view
        returns (BondPositionInfo[] memory bondPositions)
    {
        if (address(bondDepository) == address(0)) return bondPositions;

        endIndex = endIndex > bondDepository.totalSupply() ? bondDepository.totalSupply() : endIndex;
        bondPositions = new BondPositionInfo[](endIndex - startIndex);

        for (uint256 i = startIndex; i < endIndex; i++) {
            // if (bondDepository.ownerOf(i) == address(0)) continue;
            IAppBondDepository.BondPosition memory position = bondDepository.positions(i);
            bondPositions[i - startIndex] = BondPositionInfo({
                owner: bondDepository.ownerOf(i),
                id: i,
                bondId: position.bondId,
                amount: position.amount,
                quoteAmount: position.quoteAmount,
                startTime: position.startTime,
                lastClaimTime: position.lastClaimTime,
                claimedAmount: position.claimedAmount,
                vestingPeriod: position.vestingPeriod,
                claimableAmount: bondDepository.claimableAmount(i),
                isStaked: position.isStaked
            });
        }
    }

    function getProjectedEpochRate() internal view returns (ProjectedEpochRate memory projectedEpochRate) {
        if (address(rebaseController) == address(0)) return projectedEpochRate;
        (uint256 apr, uint256 epochRate, uint256 toStakers, uint256 toOps, uint256 toBurner) =
            rebaseController.projectedEpochRate();
        projectedEpochRate =
            ProjectedEpochRate({apr: apr, epochRate: epochRate, toStakers: toStakers, toOps: toOps, toBurner: toBurner});
    }

    /// @notice Calculate the current APR
    /// @return The current APR as a percentage (e.g., 1000 = 10%)
    function calculateAPR() public view returns (uint256) {
        if (address(staking) == address(0)) return 0;
        return calculateAPRRaw(staking.totalStaked());
    }

    function calculateAPRRaw(uint256 totalStaked) public view returns (uint256) {
        if (address(rebaseController) == address(0)) return 0;
        (,, uint256 toStakers,,) = rebaseController.projectedEpochRate();
        return toStakers * 1e18 * 365 * 4 / totalStaked;
    }

    function getAllStakingPositions(uint256 startingIndex, uint256 endingIndex)
        external
        view
        returns (StakingPositionInfo[] memory)
    {
        StakingPositionInfo[] memory positions = new StakingPositionInfo[](endingIndex - startingIndex);
        if (address(staking) == address(0)) return positions;

        for (uint256 i = startingIndex; i < endingIndex; i++) {
            IAppStaking.Position memory position = staking.positions(i);

            if (position.amount == 0) continue;

            bool inWithdrawCooldown =
                position.withdrawCooldownStart > 0 && block.timestamp < position.withdrawCooldownStart;
            uint256 withdrawCooldownStart = position.withdrawCooldownStart;
            bool inBuyCooldown = position.buyCooldownEnd > 0 && block.timestamp < position.buyCooldownEnd;

            positions[i - startingIndex] = StakingPositionInfo({
                id: i,
                owner: staking.ownerOf(i),
                amount: position.amount,
                declaredValue: position.declaredValue,
                rewards: staking.earned(i),
                withdrawCooldownEnd: position.withdrawCooldownEnd,
                isActive: position.withdrawCooldownEnd == 0,
                inCooldown: inBuyCooldown,
                inWithdrawCooldown: inWithdrawCooldown,
                withdrawCooldownStart: withdrawCooldownStart,
                isFrom4626: staking4626.unstakingTokenId(i)
            });
        }

        return positions;
    }

    function getBondVariables(uint256[] memory bondIds)
        external
        view
        returns (IAppBondDepository.Bond[] memory bonds, uint256[] memory currentPrices)
    {
        if (address(bondDepository) == address(0)) return (bonds, currentPrices);
        bonds = new IAppBondDepository.Bond[](bondIds.length);
        currentPrices = new uint256[](bondIds.length);

        for (uint256 i = 0; i < bondIds.length; i++) {
            IAppBondDepository.Bond memory bond = bondDepository.bonds(bondIds[i]);
            bonds[i] = bond;
            currentPrices[i] = bondDepository.currentPrice(bondIds[i]);
        }
    }
}
