// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IAppOracle.sol";
import "../../interfaces/IOracleV2.sol";

/// @title UserRoleChecker
/// @notice A UI helper contract that provides read functions
/// to check various user roles and conditions with detailed metrics
contract UserRoleChecker {
    /// @notice The app oracle
    IAppOracle public immutable appOracle;

    /// @notice The spot oracle
    IOracleV2 public immutable spotOracle;

    struct CheckIfHoldingParams {
        IERC20 token;
        IERC20[] forwarders;
    }

    struct CheckIfHoldingMultipleParams {
        CheckIfHoldingParams[] params;
    }

    /**
     * @notice Constructor
     * @param _appOracle The address of the app oracle
     * @param _spotOracle The address of the spot oracle
     */
     constructor(address _appOracle, address _spotOracle) {
        appOracle = IAppOracle(_appOracle);
        spotOracle = IOracleV2(_spotOracle);
     }

    /**
     * @notice Check if a user is holding a specific set of tokens
     * @param user The address of the user to check
     * @param token The token to check
     * @param forwarders The addresses of the forwarders to check
     * @return isHolding Whether the user is holding the tokens
     * @return totalUsdValue The total USD value of the tokens
     * @return rzrValue The total RZR value of the tokens
     */
    function checkIfHolding(address user, IERC20 token, IERC20[] memory forwarders) public view returns (bool isHolding, uint256 totalUsdValue, uint256 rzrValue) {
        uint256 spotPrice = spotPrice();
        uint256 balance = token.balanceOf(user);

        for (uint256 j = 0; j < forwarders.length; j++) {
            balance += forwarders[j].balanceOf(user);
        }

        (uint256 rzrAmount, uint256 usdAmount,) = appOracle.getPriceForAmount(address(token), balance);
        totalUsdValue += usdAmount + (rzrAmount * spotPrice / 1e18);
        rzrValue += rzrAmount;


        isHolding = totalUsdValue > 0;
    }

    /**
     * @notice Check if a user is holding a specific set of tokens
     * @param user The address of the user to check
     * @param tokens The addresses of the tokens to check
     * @param forwarders The addresses of the forwarders to check
     * @return isHolding Whether the user is holding the tokens
     * @return totalUsdValue The total USD value of the tokens
     * @return rzrValue The total RZR value of the tokens
     */
    function checkIfHoldingMultiple(address user, IERC20[] memory tokens, IERC20[][] memory forwarders) public view returns (bool isHolding, uint256 totalUsdValue, uint256 rzrValue) {
        for (uint256 i = 0; i < tokens.length; i++) {
            (bool _isHolding, uint256 _usdAmount, uint256 _rzrAmount) = checkIfHolding(user, tokens[i], forwarders[i]);
            isHolding = isHolding || _isHolding;
            totalUsdValue += _usdAmount;
            rzrValue += _rzrAmount;
        }
    }

    /**
     * @notice Check if a user is holding a specific set of tokens
     * @param user The address of the user to check
     * @param data The data to decode
     * @return isHolding Whether the user is holding the tokens
     * @return totalUsdValue The total USD value of the tokens
     * @return rzrValue The total RZR value of the tokens
     */
    function checkIfHoldingWithData(address user, bytes memory data) public view returns (bool isHolding, uint256 totalUsdValue, uint256 rzrValue) {
        CheckIfHoldingMultipleParams memory params = abi.decode(data, (CheckIfHoldingMultipleParams));
        for (uint256 i = 0; i < params.params.length; i++) {
            (bool _isHolding, uint256 _usdAmount, uint256 _rzrAmount) = checkIfHolding(user, params.params[i].token, params.params[i].forwarders);
            isHolding = isHolding || _isHolding;
            totalUsdValue += _usdAmount;
            rzrValue += _rzrAmount;
        }
    }

    /**
     * @notice Get the USD value of a user's holdings
     * @param user The address of the user to check
     * @param data The data to decode
     * @return totalUsdValue The total USD value of the user's holdings
     */
    function getUsdValue(address user, bytes memory data) public view returns (uint256 totalUsdValue) {
        CheckIfHoldingMultipleParams memory params = abi.decode(data, (CheckIfHoldingMultipleParams));
        for (uint256 i = 0; i < params.params.length; i++) {
            (, uint256 _usdAmount, ) = checkIfHolding(user, params.params[i].token, params.params[i].forwarders);
            totalUsdValue += _usdAmount;
        }
    }

    /**
     * @notice Get the spot price
     * @return spotPrice The spot price
     */
    function spotPrice() public view returns (uint256) {
        (,uint256 spotPrice,) = spotOracle.getPriceForAmount(1e18);
        return spotPrice;
    }
}
