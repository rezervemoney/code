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
    function getProtocolInfo(address user, address[] memory tokens, address allowanceTarget)
        external
        view
        returns (
            ProtocolInfo memory protocolInfo,
            bytes8 referralCode,
            TokenInfo[] memory tokenInfos,
            StakingPositionInfo[] memory stakingPositions,
            ConvertiblePositionInfo[] memory convertiblePositions,
            ConvertibleProtocolInfo memory convertibleProtocolInfo,
            ProjectedEpochRate memory projectedEpochRate
        )
    {
        // Get protocol-wide stats
        convertiblePositions = getConvertiblePositions(user);
        projectedEpochRate = getProjectedEpochRate();
        protocolInfo = getProtocolInfo();
        referralCode = referrals.referrerCodes(user);
        stakingPositions = getStakingPositions(user);
        tokenInfos = getTokenInfos(user, tokens, allowanceTarget);
        convertibleProtocolInfo = getConvertibleProtocolInfo();
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

    function getTokenInfos(address user, address[] memory bondTokens, address allowanceTarget)
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
            allowance: appToken.allowance(user, allowanceTarget),
            treasuryBalance: appToken.balanceOf(address(treasury)),
            totalSupply: appToken.totalSupply(),
            decimals: 18,
            oraclePriceUsd: getSpotPrice()
        });

        // Add staking token info
        tokenInfos[1] = TokenInfo({
            token: address(stakingToken),
            name: "Staked RZR",
            symbol: "sRZR",
            balance: stakingToken.balanceOf(user),
            allowance: stakingToken.allowance(user, allowanceTarget),
            totalSupply: stakingToken.totalSupply(),
            treasuryBalance: 0,
            decimals: 18,
            oraclePriceUsd: getSpotPrice()
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
            decimals: 18,
            oraclePriceUsd: getLstPrice()
        });

        // Add bond token info
        for (uint256 i = 0; i < bondTokens.length; i++) {
            IERC20Metadata token = IERC20Metadata(bondTokens[i]);
            tokenInfos[i + 3] = TokenInfo({
                balance: token.balanceOf(user),
                allowance: token.allowance(user, allowanceTarget),
                decimals: token.decimals(),
                totalSupply: token.totalSupply(),
                name: token.name(),
                symbol: token.symbol(),
                treasuryBalance: token.balanceOf(address(treasury)),
                token: address(token),
                oraclePriceUsd: getTokenPrice(token)
            });
        }
    }

    function getTokenPrice(IERC20Metadata token) internal view returns (uint256) {
        uint256 decimals = token.decimals();
        uint256 oneUnit = 10 ** decimals;
        uint256 rzrPrice = getSpotPrice();

        if (address(appOracle) != address(0)) {
            (uint256 rzrAmount, uint256 usdAmount,) = appOracle.getPriceForAmount(address(token), oneUnit);
            return usdAmount + (rzrPrice * rzrAmount / 1e18);
        }

        return 0;
    }

    function getLstPrice() internal view returns (uint256) {
        uint256 rzrPrice = getSpotPrice();
        uint256 lstPrice = staking4626.rate();
        return rzrPrice * lstPrice / 1e18;
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

    function getConvertiblePositions(address user)
        internal
        view
        returns (ConvertiblePositionInfo[] memory convertiblePositions)
    {
        if (address(convertibles) == address(0)) return convertiblePositions;

        uint256 convertibleBalance = convertibles.balanceOf(user);
        convertiblePositions = new ConvertiblePositionInfo[](convertibleBalance);

        for (uint256 i = 0; i < convertibleBalance; i++) {
            uint256 tokenId = convertibles.tokenOfOwnerByIndex(user, i);
            convertiblePositions[i] = getConvertiblePositions(tokenId);
        }
    }

    function getConvertiblePositions(uint256 tokenId)
        public
        view
        returns (ConvertiblePositionInfo memory convertiblePosition)
    {
        if (address(convertibles) == address(0)) return convertiblePosition;
        uint256 twapPrice = getTwapPrice();

        IAppConvertibles.Position memory position = convertibles.positions(tokenId);
        (uint256 interestClaimable, uint256 totalInterestClaimed) = convertibles.claimableInterest(tokenId);

        convertiblePosition = ConvertiblePositionInfo({
            owner: convertibles.ownerOf(tokenId),
            id: tokenId,
            amountStaked: position.amountStaked,
            amountConvertible: position.amountConvertible,
            fixedInterestRate: position.fixedInterestRate,
            lockDuration: position.lockDuration,
            lockStartTime: position.lockStartTime,
            priceConversion: position.priceConversion,
            priceEntry: position.priceEntry,
            canConvert: position.priceConversion >= twapPrice,
            interestClaimable: interestClaimable,
            totalInterestClaimed: totalInterestClaimed
        });

        return convertiblePosition;
    }

    function getConvertiblePositionsByIndex(uint256 startIndex, uint256 endIndex)
        external
        view
        returns (ConvertiblePositionInfo[] memory convertiblePositions)
    {
        if (address(convertibles) == address(0)) return convertiblePositions;

        endIndex = endIndex > convertibles.totalSupply() ? convertibles.totalSupply() : endIndex;
        convertiblePositions = new ConvertiblePositionInfo[](endIndex - startIndex);

        for (uint256 i = startIndex; i < endIndex; i++) {
            convertiblePositions[i - startIndex] = getConvertiblePositions(i);
        }
    }

    function getTwapPrice() public view returns (uint256 price) {
        if (address(convertibles) == address(0)) return 0;
        IOracleV2 twapOracle = convertibles.twapOracle();
        (, uint256 usdAssets,) = twapOracle.getPriceForAmount(1e18);
        price = usdAssets;
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

    function getConvertibleProtocolInfo()
        public
        view
        returns (ConvertibleProtocolInfo memory convertibleProtocolInfo)
    {
        if (address(convertibles) == address(0)) return convertibleProtocolInfo;
        IAppConvertibles.Variables memory vars = convertibles.variables();
        uint256 totalStaked = convertibles.totalStaked();
        convertibleProtocolInfo = ConvertibleProtocolInfo({
            totalStaked: totalStaked,
            minConversionPremium: vars.minConversionPremium,
            maxConversionPremium: vars.maxConversionPremium,
            minFixedInterestRate: vars.minFixedInterestRate,
            maxFixedInterestRate: vars.maxFixedInterestRate,
            supplyCap: vars.supplyCap,
            debtCap: vars.debtCap
        });
    }
}
