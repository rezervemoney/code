// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import "./IApp.sol";
import "./IAppTreasury.sol";
import "./IAppStaking.sol";
import "./IAppOracle.sol";
import "./ITotalReservesOracle.sol";

interface IRebaseController {
    // --- State Variables -----------------------------------------------------
    function app() external view returns (IApp);
    function appOracle() external view returns (IAppOracle);
    function totalReservesOracle() external view returns (ITotalReservesOracle);
    function staking() external view returns (IAppStaking);
    function EPOCH() external view returns (uint256);
    function lastEpochTime() external view returns (uint256);

    // --- Events --------------------------------------------------------------
    event Rebased(uint256 backingRatio, uint256 epochRate, uint256 tokensMinted, uint256 newFloorPrice);
    event TargetPctsSet(uint256 targetOpsPct, uint256 minFloorPct, uint256 maxFloorPct, uint256 floorSlope);
    event AprVariablesSet(uint16 floorApr, uint16 ceilApr, uint16 k1, uint16 k2);

    // --- Functions ----------------------------------------------------------
    /// @notice Initialize the rebase controller
    /// @param _rzr The address of the RZR
    /// @param _appOracle The address of the app oracle contract
    /// @param _staking The address of the staking contract
    /// @param _authority The address of the authority contract
    /// @param _burner The address of the burner contract
    /// @param _totalReservesOracle The address of the total reserves oracle contract
    function initialize(
        address _rzr,
        address _appOracle,
        address _staking,
        address _authority,
        address _burner,
        address _totalReservesOracle
    ) external;

    /// @notice Set the target percentages
    /// @param _targetOpsPct The target operations percentage
    /// @param _minFloorPct The minimum floor percentage
    /// @param _maxFloorPct The maximum floor percentage
    /// @param _floorSlope The floor slope
    function setTargetPcts(uint256 _targetOpsPct, uint256 _minFloorPct, uint256 _maxFloorPct, uint256 _floorSlope)
        external;

    /// @notice Set the APR variables
    /// @param _floorApr The floor APR
    /// @param _ceilApr The ceiling APR
    /// @param _k1 The k1 parameter
    /// @param _k2 The k2 parameter
    function setAprVariables(uint16 _floorApr, uint16 _ceilApr, uint16 _k1, uint16 _k2) external;

    /// @notice Execute the epoch
    function executeEpoch() external;

    /// @notice Get the excess reserves
    /// @return excessReserves The excess reserves
    function excessReserves() external view returns (uint256 excessReserves);

    /// @notice Get the current backing ratio
    /// @return backingRatio The current backing ratio
    function currentBackingRatio() external view returns (uint256 backingRatio);

    /// @notice Get the projected epoch rate
    /// @return apr The APR
    /// @return epochRate The epoch rate
    /// @return toStakers The amount to mint to stakers
    /// @return toOps The amount to mint to operations
    /// @return toBurner The amount to mint to the burner
    function projectedEpochRate()
        external
        view
        returns (uint256 apr, uint256 epochRate, uint256 toStakers, uint256 toOps, uint256 toBurner);

    /// @notice Get the projected epoch rate
    /// @param pcv The PCV
    /// @param supply The supply
    /// @param stakedSupply The staked supply
    /// @return apr The APR
    /// @return epochRate The epoch rate
    /// @return toStakers The amount to mint to stakers
    /// @return toOps The amount to mint to operations
    /// @return toBurner The amount to mint to the burner
    function projectedEpochRateRaw(uint256 pcv, uint256 supply, uint256 stakedSupply)
        external
        view
        returns (uint256 apr, uint256 epochRate, uint256 toStakers, uint256 toOps, uint256 toBurner);
}
