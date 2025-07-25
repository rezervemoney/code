// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;
pragma abicoder v2;

import "./AppUIHelperBase.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IAppBondDepositoryOld {
    struct BondPositionOld {
        uint256 bondId;
        uint256 amount; // amount of RZR tokens
        uint256 quoteAmount; // amount of quote tokens paid
        uint256 startTime; // when the bond was purchased
        uint256 lastClaimTime; // last time tokens were claimed
        uint256 claimedAmount; // amount of tokens already claimed
        bool isStaked; // whether the position is staked
    }

    struct BondOld {
        bool enabled;
        uint256 capacity; // capacity remaining
        IERC20 quoteToken; // token to accept as payment
        uint256 totalDebt; // total debt from bond
        uint256 maxPayout; // max tokens in/out
        uint256 sold; // RZR tokens out
        uint256 purchased; // quote tokens in
        uint256 startTime; // when the bond starts
        uint256 endTime; // when the bond ends
        uint256 initialPrice; // starting price in quote token
        uint256 finalPrice; // ending price in quote token
    }

    function positions(uint256 tokenId) external view returns (BondPositionOld memory);

    function bonds(uint256 bondId) external view returns (BondOld memory);
}

/// @title RZR UI Helper
/// @author RZR Protocol
contract AppUIHelperRead is AppUIHelperBase {
    constructor(
        address _staking,
        address _bondDepository,
        address _treasury,
        address _appToken,
        address _stakingToken,
        address _rebaseController,
        address _appOracle,
        address _shadowLP,
        address _odos,
        address _staking4626,
        address _referrals
    )
        AppUIHelperBase(
            _staking,
            _bondDepository,
            _treasury,
            _appToken,
            _stakingToken,
            _rebaseController,
            _appOracle,
            _shadowLP,
            _odos,
            _staking4626,
            _referrals
        )
    {}

    /// @notice Get all protocol information for a user
    /// @param user The address of the user
    function getProtocolInfo(address user, address[] memory bondTokens)
        external
        view
        returns (
            uint256 tvl,
            uint256 totalSupply,
            uint256 totalStaked,
            uint256 totalRewards,
            uint256 currentAPR,
            uint256 currentSpotPrice,
            uint256 unbackedSupply,
            bytes8 referralCode,
            TokenInfo[] memory tokenInfos,
            StakingPositionInfo[] memory stakingPositions,
            BondPositionInfo[] memory bondPositions,
            ProjectedEpochRate memory projectedEpochRate
        )
    {
        // Get protocol-wide stats
        tvl = treasury.calculateReserves();
        totalSupply = appToken.totalSupply();
        totalStaked = staking.totalStaked();
        totalRewards = staking.rewardPerToken();
        currentAPR = calculateAPRRaw(totalStaked);
        currentSpotPrice = shadowLP.getPrice();
        projectedEpochRate = getProjectedEpochRate();
        tokenInfos = getTokenInfos(user, bondTokens);
        stakingPositions = getStakingPositions(user);
        bondPositions = getBondPositions(user);
        unbackedSupply = treasury.unbackedSupply();
        referralCode = referrals.referrerCodes(user);
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
            oraclePrice: appOracle.getTokenPrice(),
            oraclePriceInApp: 1e18
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
            oraclePrice: appOracle.getTokenPrice(),
            oraclePriceInApp: 1e18
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
            oraclePrice: appOracle.getPrice(address(staking4626)),
            oraclePriceInApp: appOracle.getPriceInToken(address(staking4626))
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
                treasuryValueApp: treasury.tokenValueE18(address(token), token.balanceOf(address(treasury))),
                token: address(token),
                oraclePriceInApp: appOracle.getPriceInToken(address(token)),
                oraclePrice: appOracle.getPrice(address(token))
            });
        }
    }

    function getStakingPositions(address user) internal view returns (StakingPositionInfo[] memory stakingPositions) {
        uint256 stakingBalance = staking.balanceOf(user);
        stakingPositions = new StakingPositionInfo[](stakingBalance);

        for (uint256 i = 0; i < stakingBalance; i++) {
            uint256 tokenId = staking.tokenOfOwnerByIndex(user, i);
            if (tokenId == 0) continue;
            IAppStaking.Position memory position = staking.positions(tokenId);

            (bool inWithdrawCooldown, uint256 withdrawCooldownStart) = staking.isInWithdrawCooldown(tokenId);

            stakingPositions[i] = StakingPositionInfo({
                owner: user,
                id: tokenId,
                amount: position.amount,
                declaredValue: position.declaredValue,
                rewards: staking.earned(tokenId),
                cooldownEnd: position.cooldownEnd,
                rewardsUnlockAt: position.rewardsUnlockAt,
                isActive: position.cooldownEnd == 0,
                inCooldown: staking.isInBuyCooldown(tokenId),
                inWithdrawCooldown: inWithdrawCooldown,
                withdrawCooldownStart: withdrawCooldownStart,
                isFrom4626: staking4626.unstakingTokenId(tokenId)
            });
        }
    }

    function getBondPositions(address user) internal view returns (BondPositionInfo[] memory bondPositions) {
        uint256 bondBalance = bondDepository.balanceOf(user);
        bondPositions = new BondPositionInfo[](bondBalance);

        for (uint256 i = 0; i < bondBalance; i++) {
            uint256 tokenId = bondDepository.tokenOfOwnerByIndex(user, i);
            IAppBondDepositoryOld.BondPositionOld memory position =
                IAppBondDepositoryOld(address(bondDepository)).positions(tokenId);

            bondPositions[i] = BondPositionInfo({
                owner: user,
                id: tokenId,
                bondId: position.bondId,
                amount: position.amount,
                quoteAmount: position.quoteAmount,
                startTime: position.startTime,
                lastClaimTime: position.lastClaimTime,
                claimedAmount: position.claimedAmount,
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
        endIndex = endIndex > bondDepository.totalSupply() ? bondDepository.totalSupply() : endIndex;
        bondPositions = new BondPositionInfo[](endIndex - startIndex);

        for (uint256 i = startIndex; i < endIndex; i++) {
            // if (bondDepository.ownerOf(i) == address(0)) continue;
            IAppBondDepositoryOld.BondPositionOld memory position =
                IAppBondDepositoryOld(address(bondDepository)).positions(i);
            bondPositions[i - startIndex] = BondPositionInfo({
                owner: bondDepository.ownerOf(i),
                id: i,
                bondId: position.bondId,
                amount: position.amount,
                quoteAmount: position.quoteAmount,
                startTime: position.startTime,
                lastClaimTime: position.lastClaimTime,
                claimedAmount: position.claimedAmount,
                claimableAmount: bondDepository.claimableAmount(i),
                isStaked: position.isStaked
            });
        }
    }

    function getProjectedEpochRate() internal view returns (ProjectedEpochRate memory projectedEpochRate) {
        (uint256 apr, uint256 epochRate, uint256 toStakers, uint256 toOps, uint256 toBurner) =
            rebaseController.projectedEpochRate();
        projectedEpochRate =
            ProjectedEpochRate({apr: apr, epochRate: epochRate, toStakers: toStakers, toOps: toOps, toBurner: toBurner});
    }

    /// @notice Calculate the current APR
    /// @return The current APR as a percentage (e.g., 1000 = 10%)
    function calculateAPR() public view returns (uint256) {
        return calculateAPRRaw(staking.totalStaked());
    }

    function calculateAPRRaw(uint256 totalStaked) public view returns (uint256) {
        (,, uint256 toStakers,,) = rebaseController.projectedEpochRate();
        return toStakers * 1e18 * 365 * 4 / totalStaked;
    }

    function getAllStakingPositions(uint256 startingIndex, uint256 endingIndex)
        external
        view
        returns (StakingPositionInfo[] memory)
    {
        StakingPositionInfo[] memory positions = new StakingPositionInfo[](endingIndex - startingIndex);

        for (uint256 i = startingIndex; i < endingIndex; i++) {
            IAppStaking.Position memory position = staking.positions(i);

            if (position.amount == 0) continue;

            (bool inWithdrawCooldown, uint256 withdrawCooldownStart) = staking.isInWithdrawCooldown(i);

            positions[i - startingIndex] = StakingPositionInfo({
                id: i,
                owner: staking.ownerOf(i),
                amount: position.amount,
                declaredValue: position.declaredValue,
                rewards: staking.earned(i),
                cooldownEnd: position.cooldownEnd,
                rewardsUnlockAt: position.rewardsUnlockAt,
                isActive: position.cooldownEnd == 0,
                inCooldown: staking.isInBuyCooldown(i),
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
        returns (IAppBondDepositoryOld.BondOld[] memory bonds, uint256[] memory currentPrices)
    {
        bonds = new IAppBondDepositoryOld.BondOld[](bondIds.length);
        currentPrices = new uint256[](bondIds.length);

        for (uint256 i = 0; i < bondIds.length; i++) {
            IAppBondDepositoryOld.BondOld memory bond = IAppBondDepositoryOld(address(bondDepository)).bonds(bondIds[i]);
            bonds[i] = bond;
            currentPrices[i] = bondDepository.currentPrice(bondIds[i]);
        }
    }
}
