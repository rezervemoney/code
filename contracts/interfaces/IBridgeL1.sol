// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "./IBridge.sol";
import "./IAppStaking.sol";
import "./IStaking4626.sol";
import "./ITotalReservesOracle.sol";
import "./IAppTreasury.sol";
import "./IApp.sol";
import "./ITotalSupplyOracle.sol";

interface IBridgeL1 is IBridge {
    event L2BridgeRegistered(address indexed l2Bridge, uint32 indexed eid);
    event StateSent(uint32 indexed dstEid, bytes message);

    /// @notice Get the staking contract
    function staking() external view returns (IAppStaking);

    /// @notice Get the staking4626 contract
    function staking4626() external view returns (IStaking4626);

    /// @notice Get the treasury contract
    function treasury() external view returns (IAppTreasury);

    /// @notice Get the rzr contract
    function rzr() external view returns (IApp);

    /// @notice Initialize the bridge
    /// @param _delegate The delegate of the bridge
    /// @param _authority The authority of the bridge
    /// @param _staking The staking contract
    /// @param _staking4626 The staking4626 contract
    /// @param _rzr The rzr contract
    /// @param _treasury The treasury contract
    /// @param _totalReservesOracle The total reserves oracle contract
    /// @param _totalSupplyOracle The total supply oracle contract
    /// @dev This function is used to initialize the bridge
    /// @dev This function is only callable by the governor
    function initialize(
        address _lzEndpoint,
        address _delegate,
        address _authority,
        address _staking,
        address _staking4626,
        address _rzr,
        address _treasury,
        address _totalReservesOracle,
        address _totalSupplyOracle
    ) external;

    /// @notice Register an L2 bridge
    /// @param _l2Bridge The address of the L2 bridge
    /// @param _eid The eid of the L2 bridge
    /// @dev This function is used to register an L2 bridge
    /// @dev This function is only callable by the governor
    function registerL2Bridge(address _l2Bridge, uint32 _eid) external;

    /// @notice Send the current protocol state to an L2 bridge
    /// @param _dstEid The eid of the L2 bridge to send the state to
    /// @dev This function is used to send the current protocol state to all L2s
    /// @dev This function is only callable by the executor
    function sentStateToL2(uint32[] calldata _dstEid) external payable;

    /// @notice Sync the mainnet reserves to the total reserves oracle
    /// @dev This function is used to sync the mainnet reserves to the total reserves oracle
    /// @dev This function is only callable by the executor
    function syncMainnetReserves() external;

    /// @notice Purge the given token
    /// @param token The token to purge
    /// @dev This function is used to purge the given token
    /// @dev This function is only callable by the governor
    function purge(address token) external;

    /// @notice Get the total reserves oracle
    /// @return _totalReservesOracle The total reserves oracle
    function totalReservesOracle() external view returns (ITotalReservesOracle);

    /// @notice Get the total supply oracle
    /// @return _totalSupplyOracle The total supply oracle
    function totalSupplyOracle() external view returns (ITotalSupplyOracle);
}
