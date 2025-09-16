// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;
pragma abicoder v2;

import "./AppUIHelperBase.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";

/// @title RZR UI Helper
/// @author RZR Protocol
contract AppUIHelperWrite is AppUIHelperBase {
    using SafeERC20 for IERC20;

    struct OdosParams {
        address tokenIn;
        uint256 tokenAmountIn;
        address odosTokenIn;
        uint256 odosTokenAmountIn;
        bytes odosData;
    }

    struct ConvertibleParams {
        uint256 amount;
        uint256 lockDuration;
        bool stakeInto4626;
    }

    struct StakeParams {
        uint256 amountDeclared;
        uint256 amountDeclaredAsPercentage;
        bytes8 referralCode;
    }

    constructor(InitParams memory params) AppUIHelperBase(params) {}

    /// @notice Claim all rewards for a staking position
    /// @return amount The amount of rewards claimed
    function claimAllRewards(address user) external returns (uint256 amount) {
        uint256 balance = staking.balanceOf(user);
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = staking.tokenOfOwnerByIndex(user, i);
            if (tokenId == 0) continue;
            // IAppStaking.Position memory position = staking.positions(tokenId);
            // if (position.withdrawCooldownEnd > block.timestamp) continue;
            amount += staking.claimRewards(tokenId);
        }
    }

    /// @notice Claim all rewards for a convertible position
    /// @param user The user to claim rewards for
    /// @param merkleProofs The merkle proofs for the rewards
    /// @return amount The amount of rewards claimed
    function claimAllInterestAndMerklRewards(address user, bool unwrap4626, bytes memory merkleProofs)
        external
        returns (uint256 amount)
    {
        uint256 balance = convertibles.balanceOf(user);
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = convertibles.tokenOfOwnerByIndex(user, i);
            if (tokenId == 0) continue;
            (uint256 interestClaimable,) = convertibles.claimInterest(tokenId, unwrap4626);
            amount += interestClaimable;
        }

        // todo claim merkl rewards
    }

    /// @notice Zaps and buys a bond
    /// @param odosParams The parameters for the zap
    /// @param convertibleParams The parameters for the convertible
    /// @return tokenId The ID of the created convertible position NFT
    /// @return conversionPrice The price of the convertible
    /// @return conversionAmount The amount of RZR tokens convertible
    /// @return fixedInterestRate The fixed interest rate per second
    /// @return fixedInterestRateAmount The fixed interest rate amount
    function zapAndBuyConvertible(OdosParams memory odosParams, ConvertibleParams memory convertibleParams)
        external
        payable
        returns (
            uint256 tokenId,
            uint256 conversionPrice,
            uint256 conversionAmount,
            uint256 fixedInterestRate,
            uint256 fixedInterestRateAmount,
            uint256 stakingPower
        )
    {
        _performZap(odosParams);

        if (convertibleParams.stakeInto4626) {
            loanTokenUnderlying.approve(address(loanToken), type(uint256).max);
            loanToken.deposit(loanTokenUnderlying.balanceOf(address(this)), address(this));
        }

        (tokenId, conversionPrice, conversionAmount, fixedInterestRate, fixedInterestRateAmount, stakingPower) =
        convertibles.stake(
            loanTokenUnderlying,
            loanTokenUnderlying.balanceOf(address(this)),
            convertibleParams.lockDuration,
            msg.sender
        );

        _purgeAll(odosParams);
    }

    /// @notice Zaps and deposits into a bond
    /// @param odosParams The parameters for the zap
    /// @param zapAsset The asset to zap into the bond
    /// @param bond The bond to deposit into
    /// @return payout The amount of payout tokens received
    function zapIntoBond(OdosParams memory odosParams, IERC20 zapAsset, IERC4626 bond, uint256 minPayout)
        external
        payable
        returns (uint256 payout)
    {
        _performZap(odosParams);

        zapAsset.approve(address(usdtreasury), type(uint256).max);
        usdtreasury.mint(zapAsset, address(this), zapAsset.balanceOf(address(this)));

        IERC20 underlying = IERC20(bond.asset());
        underlying.approve(address(bond), type(uint256).max);
        payout = bond.deposit(underlying.balanceOf(address(this)), msg.sender);

        require(payout >= minPayout, "Insufficient payout");

        _purgeAll(odosParams);
    }

    /// @notice Zaps and deposits into the LST
    /// @param odosParams The parameters for the zap
    /// @param referralCode The referral code to use
    /// @param destination The destination address
    /// @param minMinted The minimum amount of tokens minted
    /// @return minted The amount of tokens minted
    function zapIntoLST(OdosParams memory odosParams, bytes8 referralCode, address destination, uint256 minMinted)
        external
        payable
        returns (uint256 minted)
    {
        _performZap(odosParams);
        appToken.approve(address(referrals), type(uint256).max);
        minted = referrals.stakeIntoLSTWithReferral(appToken.balanceOf(address(this)), referralCode, destination);
        require(minted >= minMinted, "Insufficient minted");
        _purgeAll(odosParams);
    }

    /// @notice Zaps and stakes the given token amount
    /// @param odosParams The parameters for the zap
    /// @param stakeParams The parameters for the stake
    /// @return tokenId The ID of the created stake position NFT
    /// @return taxPaid The amount of tax paid
    /// @return amountStaked The amount of app tokens staked
    /// @return amountDeclared The amount of app tokens declared
    function zapAndStake(OdosParams memory odosParams, StakeParams memory stakeParams, uint256 minStaked)
        external
        payable
        returns (uint256 tokenId, uint256 taxPaid, uint256 amountStaked, uint256 amountDeclared)
    {
        _performZap(odosParams);

        amountStaked = appToken.balanceOf(address(this));
        appToken.approve(address(referrals), type(uint256).max);
        amountDeclared = stakeParams.amountDeclared;
        (tokenId, taxPaid) =
            referrals.stakeWithReferral(amountStaked, amountDeclared, stakeParams.referralCode, msg.sender);

        require(amountStaked >= minStaked, "Insufficient staked");
        _purgeAll(odosParams);
    }

    /// @notice Zaps and stakes the given token amount as a percentage of the app token balance
    /// @param odosParams The parameters for the zap
    /// @param stakeParams The parameters for the stake
    /// @param minStaked The minimum amount of app tokens staked
    /// @return tokenId The ID of the created stake position NFT
    /// @return taxPaid The amount of tax paid
    /// @return amountStaked The amount of app tokens staked
    /// @return amountDeclared The amount of app tokens declared
    function zapAndStakeAsPercentage(OdosParams memory odosParams, StakeParams memory stakeParams, uint256 minStaked)
        external
        payable
        returns (uint256 tokenId, uint256 taxPaid, uint256 amountStaked, uint256 amountDeclared)
    {
        _performZap(odosParams);

        amountStaked = appToken.balanceOf(address(this));
        amountDeclared = (amountStaked * stakeParams.amountDeclaredAsPercentage) / 1e18;
        appToken.approve(address(referrals), amountStaked);
        (tokenId, taxPaid) =
            referrals.stakeWithReferral(amountStaked, amountDeclared, stakeParams.referralCode, msg.sender);

        require(amountStaked >= minStaked, "Insufficient staked");

        _purgeAll(odosParams);
    }

    /// @notice Estimates the output of a zap
    /// @dev This function does not perform the zap, it only estimates the output. Use as a static call.
    /// @param odosParams The parameters for the zap
    /// @param tokenOut The token to estimate the output for
    /// @return output_ The estimated output
    function estimateZapOutput(OdosParams memory odosParams, address tokenOut)
        external
        payable
        returns (uint256 output_)
    {
        _performZap(odosParams);
        output_ = IERC20(tokenOut).balanceOf(address(this));
    }

    /// @notice Estimates the output of a bond
    /// @dev This function does not perform the bond, it only estimates the output. Use as a static call.
    /// @param tokenIn The token to estimate the output for
    /// @param amountIn The amount of token to estimate the output for
    /// @param bondId The ID of the bond to estimate the output for
    /// @return output_ The estimated output
    function estimateBondOutput(address tokenIn, uint256 amountIn, uint256 bondId)
        external
        view
        returns (uint256 output_)
    {
        // uint256 price = convertibles.currentPrice(bondId);
        // (uint256 payout,) = convertibles.calculatePayoutAndProfit(IERC20(tokenIn), price, amountIn);
        // output_ = payout;
    }

    /// @notice Purges all tokens from the contract
    /// @param odosParams The parameters for the zap
    function _purgeAll(OdosParams memory odosParams) internal {
        _purge(odosParams.tokenIn);
        _purge(odosParams.odosTokenIn);
        _purge(address(appToken));
    }

    /// @notice Purges the given token
    /// @param token The token to purge
    function _purge(address token) internal {
        if (token == address(0)) {
            if (address(this).balance > 0) {
                (bool success,) = msg.sender.call{value: address(this).balance}("");
                require(success, "Failed to send ETH");
            }
        } else {
            uint256 balance = IERC20(token).balanceOf(address(this));
            if (balance > 0) IERC20(token).safeTransfer(msg.sender, balance);
        }
    }

    /// @notice Prepares the zap for the given token and odos data
    /// @param odosParams The parameters for the zap
    function _performZap(OdosParams memory odosParams) internal {
        if (odosParams.tokenIn == address(0)) {
            require(msg.value == odosParams.tokenAmountIn, "Invalid ETH amount");
        } else {
            IERC20(odosParams.tokenIn).safeTransferFrom(msg.sender, address(this), odosParams.tokenAmountIn);
        }

        if (odosParams.tokenIn != address(0)) {
            IERC20(odosParams.tokenIn).approve(odos, type(uint256).max);
        }

        if (odosParams.odosData.length > 0) {
            (bool success,) = odos.call{value: msg.value}(odosParams.odosData);
            require(success, "Odos call failed");
        }
    }

    receive() external payable {}
}
