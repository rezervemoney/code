// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;
pragma abicoder v2;

import "../interfaces/IAppStaking.sol";
import "../interfaces/IAppBondDepository.sol";
import "../interfaces/IRebaseController.sol";
import "../interfaces/IAppTreasury.sol";
import "../interfaces/IAppOracle.sol";
import "../interfaces/IOracleV2.sol";
import "../interfaces/IStaking4626.sol";
import "../interfaces/IAppReferrals.sol";
import "../interfaces/ITotalReservesOracle.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title RZR UI Helper
/// @author RZR Protocol
abstract contract AppUIHelperBase {
    struct ProtocolInfo {
        uint256 tvlRzr;
        uint256 tvlUsd;
        uint256 totalSupply;
        uint256 totalStaked;
        uint256 totalRewards;
        uint256 currentAPR;
        uint256 currentSpotPrice;
        uint256 currentEthPrice;
        uint256 unbackedSupply;
    }

    struct TokenInfo {
        address token;
        string name;
        string symbol;
        uint256 balance;
        uint256 allowance;
        uint256 treasuryBalance;
        uint256 treasuryValueApp;
        uint256 totalSupply;
        uint8 decimals;
        uint256 oraclePrice;
        uint256 oraclePriceInApp;
    }

    struct StakingPositionInfo {
        address owner;
        uint256 id;
        uint256 amount;
        uint256 declaredValue;
        uint256 rewards;
        uint256 withdrawCooldownEnd;
        uint256 withdrawCooldownStart;
        bool isActive;
        bool inCooldown; // whether the position is in cooldown
        bool inWithdrawCooldown; // whether the position is in withdraw cooldown
        bool isFrom4626; // whether the position is from the 4626 staking contract
    }

    struct BondPositionInfo {
        address owner;
        uint256 id;
        uint256 bondId;
        uint256 amount; // amount of RZR tokens
        uint256 quoteAmount; // amount of quote tokens paid
        uint256 startTime; // when the bond was purchased
        uint256 lastClaimTime; // last time tokens were claimed
        uint256 vestingPeriod; // vesting period of the bond
        uint256 claimedAmount; // amount of tokens already claimed
        uint256 claimableAmount; // amount of tokens that can be claimed
        bool isStaked; // whether the position is staked
    }

    struct BondVariables {
        uint256 capacity; // capacity remaining in quote tokens
        IERC20 quoteToken; // token to accept as payment
        uint256 totalDebt; // total debt from bond
        uint256 maxPayout; // max tokens in/out
        uint256 sold; // RZR tokens out
        uint256 purchased; // quote tokens in
        uint256 startTime; // when the bond starts
        uint256 endTime; // when the bond ends
        uint256 initialPrice; // starting price in quote token
        uint256 finalPrice; // ending price in quote token
        uint256 currentPrice; // current price in quote token
    }

    struct ProjectedEpochRate {
        uint256 apr;
        uint256 epochRate;
        uint256 toStakers;
        uint256 toOps;
        uint256 toBurner;
    }

    // State variables
    address public odos;
    IAppBondDepository public bondDepository;
    IAppOracle public appOracle;
    IAppStaking public staking;
    IAppTreasury public treasury;
    IERC20 public appToken;
    IERC20 public stakingToken;
    IOracleV2 public spotOracle;
    IOracleV2 public ethOracle;
    IRebaseController public rebaseController;
    IStaking4626 public staking4626;
    IAppReferrals public referrals;
    ITotalReservesOracle public totalReservesOracle;

    // Events
    event RewardsClaimed(uint256 indexed positionId, uint256 amount);

    struct InitParams {
        address staking;
        address bondDepository;
        address treasury;
        address appToken;
        address stakingToken;
        address rebaseController;
        address appOracle;
        address spotOracle;
        address ethOracle;
        address odos;
        address staking4626;
        address referrals;
        address totalReservesOracle;
    }

    constructor(InitParams memory params) {
        staking = IAppStaking(params.staking);
        bondDepository = IAppBondDepository(params.bondDepository);
        treasury = IAppTreasury(params.treasury);
        appToken = IERC20(params.appToken);
        stakingToken = IERC20(params.stakingToken);
        appOracle = IAppOracle(params.appOracle);
        spotOracle = IOracleV2(params.spotOracle);
        ethOracle = IOracleV2(params.ethOracle);
        rebaseController = IRebaseController(params.rebaseController);
        odos = params.odos;
        staking4626 = IStaking4626(params.staking4626);
        referrals = IAppReferrals(params.referrals);
        totalReservesOracle = ITotalReservesOracle(params.totalReservesOracle);

        if (address(staking) != address(0)) {
            appToken.approve(address(staking), type(uint256).max);
        }

        if (address(bondDepository) != address(0)) {
            appToken.approve(address(bondDepository), type(uint256).max);
        }
    }
}
