// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

// import "./IAccounting.sol";

interface IBridge {
    struct State {
        uint256 staking4626Rate;
        uint256 rzrSupply;
        uint256 lstRzrSupply;
        uint256 rzrReserves;
        uint256 usdReserves;
        uint256 updatedAt;
    }

    /// @notice Get the current protocol state
    /// @dev This function is used to get the current protocol state
    function getCurrentState() external view returns (State memory);
}
