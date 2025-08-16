// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;
pragma abicoder v2;

import "../core/AppOracle.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract HoldersAnalysis {
    IAppOracle public immutable appOracle;

    struct HolderBalance {
        address token;
        uint256 rzrValue;
        uint256 usdValue;
    }

    struct HolderResponse {
        address user;
        HolderBalance[] balances;
    }

    constructor(address _appOracle) {
        appOracle = IAppOracle(_appOracle);
    }

    /// @notice Get all protocol information for a user
    /// @param users The addresses of the users
    /// @param tokens The addresses of the tokens
    function getInfoAboutHolders(address[] memory users, address[] memory tokens)
        external
        view
        returns (HolderResponse[] memory response)
    {
        response = new HolderResponse[](users.length);

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            HolderBalance[] memory balances = new HolderBalance[](tokens.length);

            for (uint256 j = 0; j < tokens.length; j++) {
                balances[j] = getHolderBalance(user, tokens[j]);
            }

            response[i] = HolderResponse({user: user, balances: balances});
        }
    }

    function getHolderBalance(address user, address token) public view returns (HolderBalance memory balance) {
        uint256 tokenBalance = IERC20(token).balanceOf(user);
        (uint256 rzrValue, uint256 usdValue,) = appOracle.getPriceForAmount(token, tokenBalance);
        balance = HolderBalance({token: token, rzrValue: rzrValue, usdValue: usdValue});
    }
}
