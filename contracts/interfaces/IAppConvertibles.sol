// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;
pragma abicoder v2;

import "../interfaces/IApp.sol";
import "../interfaces/IOracleV2.sol";
import "../interfaces/IPermissionedERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

/// @title IAppConvertibles Interface
/// @author RZR Protocol
/// @notice Interface for the RZR Convertibles system
interface IAppConvertibles is IERC721Enumerable {
    /// @notice Position data structure for convertible positions
    /// @param amountStaked Amount of loan tokens staked in this position
    /// @param amountConvertible Amount of RZR tokens convertible in this position
    /// @param fixedInterestRate Fixed interest rate per second for this position
    /// @param fixedInterestClaimed Amount of interest claimed by user
    /// @param lockDuration Lock duration for this position
    /// @param lockStartTime Timestamp when the lock period started
    /// @param priceConversion Price at which conversion can occur
    /// @param priceEntry Price when the position was created
    struct Position {
        uint256 amountStaked;
        uint256 amountConvertible;
        uint256 fixedInterestRate;
        uint256 fixedInterestClaimed;
        uint256 lockDuration;
        uint256 lockStartTime;
        uint256 priceConversion;
        uint256 priceEntry;
    }

    /// @notice Contract configuration variables
    /// @param minConversionPremium Minimum conversion premium (in basis points)
    /// @param maxConversionPremium Maximum conversion premium (in basis points)
    /// @param minFixedInterestRate Minimum fixed interest rate per second
    /// @param maxFixedInterestRate Maximum fixed interest rate per second
    struct Variables {
        uint256 minConversionPremium;
        uint256 maxConversionPremium;
        uint256 minFixedInterestRate;
        uint256 maxFixedInterestRate;
        uint256 supplyCap;
        uint256 debtCap;
    }

    /// @notice Emitted when a user creates a new convertible position
    /// @param user The address of the user who staked
    /// @param tokenId The NFT token ID for the new position
    /// @param amountStaked Amount of loan tokens staked
    /// @param amountConvertible Amount of RZR tokens convertible
    /// @param lockDuration Lock duration for the position
    /// @param priceEntry Price when the position was created
    /// @param priceConversion Price at which conversion can occur
    /// @param fixedInterestPerSecond Fixed interest rate per second
    event Staked(
        address indexed user,
        uint256 indexed tokenId,
        uint256 amountStaked,
        uint256 amountConvertible,
        uint256 lockDuration,
        uint256 priceEntry,
        uint256 priceConversion,
        uint256 fixedInterestPerSecond
    );

    /// @notice Emitted when a user converts their convertible position to RZR tokens
    /// @param user The address of the user who converted
    /// @param tokenId The NFT token ID that was converted
    /// @param amountStaked Amount of loan tokens that were staked
    /// @param amountConvertible Amount of RZR tokens that were convertible
    /// @param twapPrice The TWAP price that triggered the conversion
    event Converted(
        address indexed user,
        uint256 indexed tokenId,
        uint256 amountStaked,
        uint256 amountConvertible,
        uint256 twapPrice
    );

    /// @notice Emitted when a user redeems their convertible position for loan tokens + interest
    /// @param user The address of the user who redeemed
    /// @param tokenId The NFT token ID that was redeemed
    /// @param amountStaked Amount of loan tokens that were staked
    /// @param amountConvertible Amount of RZR tokens that were convertible
    /// @param interestAccumulated Amount of interest accumulated and paid out
    event Redeemed(
        address indexed user,
        uint256 indexed tokenId,
        uint256 amountStaked,
        uint256 amountConvertible,
        uint256 interestAccumulated
    );

    /// @notice Emitted when governance updates the contract variables
    /// @param minConversionPremium New minimum conversion premium
    /// @param maxConversionPremium New maximum conversion premium
    /// @param minFixedInterestRate New minimum fixed interest rate per second
    /// @param maxFixedInterestRate New maximum fixed interest rate per second
    /// @param supplyCap New maximum supply of convertible positions
    /// @param debtCap New maximum debt of convertible positions
    event VariablesUpdated(
        uint256 minConversionPremium,
        uint256 maxConversionPremium,
        uint256 minFixedInterestRate,
        uint256 maxFixedInterestRate,
        uint256 supplyCap,
        uint256 debtCap
    );

    /// @notice Emitted when a convertible NFT is transferred between addresses
    /// @param from The address transferring the position
    /// @param to The address receiving the position
    /// @param tokenId The NFT token ID being transferred
    /// @param amountStaked Amount of loan tokens staked in the position
    /// @param amountConvertible Amount of RZR tokens convertible in the position
    event PositionTransferred(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId,
        uint256 amountStaked,
        uint256 amountConvertible
    );

    /// @notice Emitted when a convertible position is split into two positions
    /// @param user The address of the user who split the position
    /// @param originalTokenId The original NFT token ID
    /// @param newTokenId The new NFT token ID created from the split
    /// @param originalAmountStaked Total amount staked in the original position
    /// @param newAmountStaked Amount staked in the new position
    /// @param originalAmountConvertible Total amount convertible in the original position
    /// @param newAmountConvertible Amount convertible in the new position
    /// @param percentageE18 The percentage used for the split (in basis points)
    event PositionSplit(
        address indexed user,
        uint256 indexed originalTokenId,
        uint256 indexed newTokenId,
        uint256 originalAmountStaked,
        uint256 newAmountStaked,
        uint256 originalAmountConvertible,
        uint256 newAmountConvertible,
        uint256 percentageE18
    );

    /// @notice Emitted when a user claims interest from a convertible position
    /// @param user The address of the user who claimed interest
    /// @param tokenId The NFT token ID that the interest was claimed from
    /// @param interestClaimed Amount of interest claimed
    event InterestClaimed(address indexed user, uint256 indexed tokenId, uint256 interestClaimed);

    /// @notice Claim interest from a convertible position
    /// @param tokenId The NFT token ID to claim interest from
    /// @return interestClaimed Amount of interest claimed
    /// @return totalInterestClaimed Total amount of interest claimed
    function claimInterest(uint256 tokenId) external returns (uint256 interestClaimed, uint256 totalInterestClaimed);

    /// @notice Maximum lock duration for convertible positions (4 years)
    /// @return The maximum lock duration in seconds
    function MAX_LOCK_DURATION() external view returns (uint256);

    /// @notice Minimum lock duration for convertible positions (30 days)
    /// @return The minimum lock duration in seconds
    function MIN_LOCK_DURATION() external view returns (uint256);

    /// @notice Maximum age of oracle price data before considered stale (1 day)
    /// @return The maximum oracle staleness period in seconds
    function MAX_ORACLE_STALENESS() external view returns (uint256);

    /// @notice The loan token (ERC4626 vault) used for staking
    /// @return The loan token contract address
    function loanToken() external view returns (IERC4626);

    /// @notice The RZR token contract
    /// @return The RZR token contract address
    function rzr() external view returns (IApp);

    /// @notice The tracking token for loan positions
    /// @return The loan tracking token contract address
    function loanTrackingToken() external view returns (IPermissionedERC20);

    /// @notice The tracking token for RZR convertible positions
    /// @return The RZR tracking token contract address
    function rzrTrackingToken() external view returns (IPermissionedERC20);

    /// @notice The oracle contract for price feeds
    /// @return The oracle contract address
    function oracle() external view returns (IOracleV2);

    /// @notice The TWAP oracle contract for conversion price validation
    /// @return The TWAP oracle contract address
    function twapOracle() external view returns (IOracleV2);

    /// @notice The last issued token ID
    /// @return The most recent token ID
    function lastId() external view returns (uint256);

    /// @notice Total amount of loan tokens staked across all positions
    /// @return The total staked amount
    function totalStaked() external view returns (uint256);

    /// @notice Total amount of RZR tokens convertible across all positions
    /// @return The total convertible amount
    function totalConvertible() external view returns (uint256);

    /// @notice Decimal scaling factor for loan token (10^(18 - loanToken.decimals()))
    /// @return The decimal scaling factor
    function loanTokenDecimals() external view returns (uint256);

    /// @notice Contract variables for conversion premiums and interest rates
    /// @return vars The contract variables
    function variables() external view returns (Variables memory vars);

    /// @notice Get position details for a specific token ID
    /// @param tokenId The NFT token ID
    /// @return position The position details
    function positions(uint256 tokenId) external view returns (Position memory position);

    /// @notice Initialize the convertibles contract
    /// @param _loanToken The loan token (ERC4626 vault) address
    /// @param _rzr The RZR token contract address
    /// @param _debtTrackingToken The loan tracking token address
    /// @param _conversionTrackingToken The RZR tracking token address
    /// @param _oracle The oracle contract address for price feeds
    /// @param _twapOracle The TWAP oracle contract address
    /// @param _authority The authority contract address
    /// @param _vars The contract variables
    function initialize(
        address _loanToken,
        address _rzr,
        address _debtTrackingToken,
        address _conversionTrackingToken,
        address _oracle,
        address _twapOracle,
        address _authority,
        Variables memory _vars
    ) external;

    /// @notice Set contract variables (governance only)
    /// @param _minConversionPremium Minimum conversion premium (in basis points)
    /// @param _maxConversionPremium Maximum conversion premium (in basis points)
    /// @param _minFixedInterestRate Minimum fixed interest rate per second
    /// @param _maxFixedInterestRate Maximum fixed interest rate per second
    /// @param _supplyCap Maximum supply of convertible positions
    /// @param _debtCap Maximum debt of convertible positions
    function setVariables(
        uint256 _minConversionPremium,
        uint256 _maxConversionPremium,
        uint256 _minFixedInterestRate,
        uint256 _maxFixedInterestRate,
        uint256 _supplyCap,
        uint256 _debtCap
    ) external;

    /// @notice Create a new convertible position by staking loan tokens
    /// @param amount Amount of loan tokens to stake
    /// @param lockDuration Duration to lock the position (must be between MIN and MAX)
    /// @param receiver The address to receive the convertible position
    /// @return tokenId The NFT token ID for the new position
    /// @return conversionPrice Price at which conversion can occur
    /// @return conversionAmount Amount of RZR tokens convertible
    /// @return fixedInterestRate Fixed interest rate per second
    /// @return fixedInterestRateAmount Fixed interest rate amount
    function stake(uint256 amount, uint256 lockDuration, address receiver)
        external
        returns (
            uint256 tokenId,
            uint256 conversionPrice,
            uint256 conversionAmount,
            uint256 fixedInterestRate,
            uint256 fixedInterestRateAmount
        );

    /// @notice Convert a convertible position to RZR tokens
    /// @param tokenId The NFT token ID to convert
    function convert(uint256 tokenId) external;

    /// @notice Redeem a convertible position for loan tokens + accumulated interest
    /// @param tokenId The NFT token ID to redeem
    function redeem(uint256 tokenId) external;

    /// @notice Split a convertible position into two positions
    /// @param tokenId The NFT token ID to split
    /// @param percentageE18 The percentage to split (0-1e18 representing 0-100%)
    function split(uint256 tokenId, uint256 percentageE18) external;

    /// @notice Calculate conversion terms for a given amount and lock duration
    /// @param amountLoan Amount of loan tokens to stake
    /// @param lockDuration Duration to lock the position
    /// @return conversionPrice Price at which conversion can occur
    /// @return conversionAmount Amount of RZR tokens convertible
    /// @return fixedInterestRate Fixed interest rate per second
    function getOfferings(uint256 amountLoan, uint256 lockDuration)
        external
        view
        returns (uint256 conversionPrice, uint256 conversionAmount, uint256 fixedInterestRate);
}
