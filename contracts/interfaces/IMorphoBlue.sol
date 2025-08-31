// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

interface IMorphoBlue {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    /// @notice Creates the market `marketParams`.
    /// @dev Here is the list of assumptions on the market's dependencies (tokens, IRM and oracle) that guarantees
    /// Morpho behaves as expected:
    /// - The token should be ERC-20 compliant, except that it can omit return values on `transfer` and `transferFrom`.
    /// - The token balance of Morpho should only decrease on `transfer` and `transferFrom`. In particular, tokens with
    /// burn functions are not supported.
    /// - The token should not re-enter Morpho on `transfer` nor `transferFrom`.
    /// - The token balance of the sender (resp. receiver) should decrease (resp. increase) by exactly the given amount
    /// on `transfer` and `transferFrom`. In particular, tokens with fees on transfer are not supported.
    /// - The IRM should not re-enter Morpho.
    /// - The oracle should return a price with the correct scaling.
    /// @dev Here is a list of properties on the market's dependencies that could break Morpho's liveness properties
    /// (funds could get stuck):
    /// - The token can revert on `transfer` and `transferFrom` for a reason other than an approval or balance issue.
    /// - A very high amount of assets (~1e35) supplied or borrowed can make the computation of `toSharesUp` and
    /// `toSharesDown` overflow.
    /// - The IRM can revert on `borrowRate`.
    /// - A very high borrow rate returned by the IRM can make the computation of `interest` in `_accrueInterest`
    /// overflow.
    /// - The oracle can revert on `price`. Note that this can be used to prevent `borrow`, `withdrawCollateral` and
    /// `liquidate` from being used under certain market conditions.
    /// - A very high price returned by the oracle can make the computation of `maxBorrow` in `_isHealthy` overflow, or
    /// the computation of `assetsRepaid` in `liquidate` overflow.
    /// @dev The borrow share price of a market with less than 1e4 assets borrowed can be decreased by manipulations, to
    /// the point where `totalBorrowShares` is very large and borrowing overflows.
    function createMarket(MarketParams memory marketParams) external;
}
