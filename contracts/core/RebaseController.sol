// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../interfaces/IApp.sol";
import "../interfaces/IAppStaking.sol";
import "../interfaces/IRebaseController.sol";
import "../libraries/StakingDistributionLogic.sol";
import "../libraries/YieldLogic.sol";
import "./AppAccessControlled.sol";
import "../interfaces/ITotalReservesOracle.sol";

/**
 * @title BondController
 * @dev Minimal reference implementation of RZR's bonding-curve logic.
 *      ─ Calculates backing ratio β = PCV / supply
 *      ─ Determines epochic rebase rate r_t using piece-wise curve
 *      ─ Mints RZR supply for stakers each epoch once called by a keeper
 *      ─ Exposes view helpers for front-end gauges
 */
contract RebaseController is AppAccessControlled, IRebaseController {
    uint256 public immutable EPOCH = 23 hours;

    IApp public app; // RZR token (decimals = 18)
    IAppOracle public appOracle;
    ITotalReservesOracle public totalReservesOracle;
    IAppStaking public staking; // staking contract or escrow
    address public burner; // burner contract

    // --- Epoch params --------------------------------------------------------
    uint256 public lastEpochTime;

    uint256 public targetOpsPct; // ideally 10%
    uint256 public minFloorPct; // minimum to the floor price ideally 15%
    uint256 public maxFloorPct; // maximum to the floor price ideally 50%
    uint256 public floorSlope; // ideally 50%

    // --- Constants -----------------------------------------------------------
    uint16 public floorApr;
    uint16 public ceilApr; // 2000% APR
    uint16 public k1; // rises 0->1000% over β 1-1.5
    uint16 public k2; // rises 1000->2000% over β 1.5-2.5

    // --- Constructor ---------------------------------------------------------
    /// @inheritdoc IRebaseController
    function initialize(
        address _rzr,
        address _appOracle,
        address _staking,
        address _authority,
        address _burner,
        address _totalReservesOracle
    ) public reinitializer(5) {
        app = IApp(_rzr);
        appOracle = IAppOracle(_appOracle);
        staking = IAppStaking(_staking);
        burner = _burner;
        totalReservesOracle = ITotalReservesOracle(_totalReservesOracle);

        __AppAccessControlled_init(_authority);

        floorApr = 500; // 500% APR
        ceilApr = 2000; // 2000% APR
        k1 = 10; // rises 0->500% over β 1-1.5
        k2 = 1500; // rises 500->2000% over β 1.5-2.5

        targetOpsPct = 0.1e18; // 10%
        minFloorPct = 0.15e18; // 15%
        maxFloorPct = 0.5e18; // 50%
        floorSlope = 0.45e18; // 45%

        lastEpochTime = 0;

        app.approve(address(staking), type(uint256).max);
    }

    /// @inheritdoc IRebaseController
    function setTargetPcts(uint256 _targetOpsPct, uint256 _minFloorPct, uint256 _maxFloorPct, uint256 _floorSlope)
        external
        onlyGovernor
    {
        targetOpsPct = _targetOpsPct;
        minFloorPct = _minFloorPct;
        maxFloorPct = _maxFloorPct;
        floorSlope = _floorSlope;
        emit TargetPctsSet(targetOpsPct, minFloorPct, maxFloorPct, floorSlope);
    }

    /// @inheritdoc IRebaseController
    function setAprVariables(uint16 _floorApr, uint16 _ceilApr, uint16 _k1, uint16 _k2) external onlyGovernor {
        floorApr = _floorApr;
        ceilApr = _ceilApr;
        k1 = _k1;
        k2 = _k2;
        emit AprVariablesSet(floorApr, ceilApr, k1, k2);
    }

    // --- Public keeper function ----------------------------------------------

    /// @inheritdoc IRebaseController
    function executeEpoch() external onlyExecutor {
        require(block.timestamp >= lastEpochTime + EPOCH, "epoch not ready");

        // Get current state
        (, uint256 epochMint, uint256 toStakers, uint256 toOps, uint256 toBurner) = projectedEpochRate();

        // Verify we have enough reserves
        require(epochMint <= excessReserves(), "Insufficient reserves");

        if (epochMint > 0) {
            // Mint tokens
            app.mint(address(this), epochMint);

            // Distribute to stakers
            staking.notifyRewardAmount(toStakers);

            // Send to ops treasury
            app.transfer(address(authority.operationsTreasury()), toOps);

            // Send to burner
            app.transfer(burner, toBurner);
        }

        lastEpochTime = block.timestamp;
        emit Rebased(epochMint, toStakers, toOps, toBurner);
    }

    // --- View helpers --------------------------------------------------------
    /// @inheritdoc IRebaseController
    function currentBackingRatio() external view returns (uint256) {
        (uint256 rzrReserves, uint256 usdReserves) = totalReservesOracle.getTotalReserves();
        uint256 pcv = usdReserves;
        uint256 supply = app.totalSupply() - rzrReserves;
        return (supply == 0) ? 0 : (pcv * 1e18) / supply; // 1e18 == β=1
    }

    /// @inheritdoc IRebaseController
    function excessReserves() public view returns (uint256) {
        (uint256 rzrReserves, uint256 usdReserves) = totalReservesOracle.getTotalReserves();
        uint256 floorPrice = appOracle.getTokenPrice();
        uint256 rzrSupplyInFloor = (app.totalSupply() - rzrReserves) * floorPrice / 1e18;
        return usdReserves - rzrSupplyInFloor;
    }

    /// @inheritdoc IRebaseController
    function projectedEpochRate()
        public
        view
        returns (uint256 apr, uint256 epochRate, uint256 toStakers, uint256 toOps, uint256 toBurner)
    {
        (uint256 rzrReserves, uint256 usdReserves) = totalReservesOracle.getTotalReserves();
        uint256 pcv = usdReserves;

        // this is important. we need to subtract the RZR reserves from the total supply because the
        // reserves oracle splits what we hold in assets (in USD terms) and what we hold in RZR (in RZR terms).
        // otherwise the supply would get inflated.
        uint256 supply = app.totalSupply() - rzrReserves;
        return projectedEpochRateRaw(pcv, supply, staking.totalStaked());
    }

    function projectedEpochRateRaw(uint256 pcv, uint256 supply, uint256 stakedSupply)
        public
        view
        returns (uint256 apr, uint256 epochMint, uint256 toStakers, uint256 toOps, uint256 toBurner)
    {
        require(targetOpsPct + minFloorPct + maxFloorPct > 0, "Invalid percentages");

        // Calculate APR and epoch rate
        (apr, epochMint) = YieldLogic.calcEpoch(floorApr, ceilApr, k1, k2, pcv, supply, 365 days / EPOCH);

        // Calculate token distribution
        (toStakers, toOps, toBurner) = StakingDistributionLogic.allocate(
            epochMint, supply, stakedSupply, targetOpsPct, minFloorPct, maxFloorPct, floorSlope
        );
    }
}
