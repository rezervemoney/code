// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;
pragma abicoder v2;

import "./IApp.sol";
import "./IAppOracle.sol";
import "./IOracleV2.sol";
import "./IPermissionedERC20.sol";
import "./IPermissionedERC20Factory.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
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
        IERC4626 asset;
        uint256 amountStaked;
        uint256 amountConvertible;
        uint256 stakingPower;
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
        IPermissionedERC20 trackingToken;
        uint256 minConversionPremium;
        uint256 maxConversionPremium;
        uint256 minFixedInterestRate;
        uint256 maxFixedInterestRate;
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
    /// @param loanToken The loan token that was enabled
    /// @param minConversionPremium New minimum conversion premium
    /// @param maxConversionPremium New maximum conversion premium
    /// @param minFixedInterestRate New minimum fixed interest rate per second
    /// @param maxFixedInterestRate New maximum fixed interest rate per second
    /// @param debtCap New maximum debt of convertible positions
    event VariablesUpdated(
        IERC20 indexed loanToken,
        uint256 minConversionPremium,
        uint256 maxConversionPremium,
        uint256 minFixedInterestRate,
        uint256 maxFixedInterestRate,
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
    /// @param newAmountConvertible newAmountConvertible Amount convertible in the new position
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
    /// @param interestClaimed interestClaimed Amount of interest claimed
    event InterestClaimed(address indexed user, uint256 indexed tokenId, uint256 interestClaimed);

    /// @notice Emitted when a token is enabled
    /// @param token The token that was enabled
    event TokenEnabled(address indexed token);

    /// @notice Get the claimable interest for a convertible position
    /// @param tokenId The NFT token ID that the interest was claimed from
    /// @return interestClaimable interestClaimable Amount of interest claimable
    /// @return totalInterestClaimed Total amount of interest claimed
    function claimableInterest(uint256 tokenId)
        external
        view
        returns (uint256 interestClaimable, uint256 totalInterestClaimed);

    /// @notice Claim interest from a convertible position
    /// @param tokenId The NFT token ID to claim interest from
    /// @param unwrap4626 Whether to unwrap the interest from the 4626 vault
    /// @return interestClaimed interestClaimed Amount of interest claimed
    /// @return totalInterestClaimed Total amount of interest claimed
    function claimInterest(uint256 tokenId, bool unwrap4626)
        external
        returns (uint256 interestClaimed, uint256 totalInterestClaimed);

    /// @notice Maximum lock duration for convertible positions (4 years)
    /// @return value The maximum lock duration in seconds
    function MAX_LOCK_DURATION() external view returns (uint256 value);

    /// @notice Minimum lock duration for convertible positions (30 days)
    /// @return value The minimum lock duration in seconds
    function MIN_LOCK_DURATION() external view returns (uint256 value);

    /// @notice Maximum age of oracle price data before considered stale (1 day)
    /// @return value The maximum oracle staleness period in seconds
    function MAX_ORACLE_STALENESS() external view returns (uint256 value);

    /// @notice Minimum bond duration for convertible positions (7 days)
    /// @return value The minimum bond duration in seconds
    function MIN_BOND_DURATION() external view returns (uint256 value);

    /// @notice The RZR token contract
    /// @return rzr rzr The RZR token contract address
    function rzr() external view returns (IApp rzr);

    /// @notice The tracking token for loan positions
    /// @return stakingPowerToken stakingPowerToken The loan tracking token contract address
    function stakingPowerToken() external view returns (IPermissionedERC20 stakingPowerToken);

    /// @notice The tracking token for RZR convertible positions
    /// @return rzrTrackingToken rzrTrackingToken The RZR tracking token contract address
    function rzrTrackingToken() external view returns (IPermissionedERC20 rzrTrackingToken);

    /// @notice The oracle contract for price feeds
    /// @return oracle   The oracle contract address
    function oracle() external view returns (IAppOracle oracle);

    /// @notice The TWAP oracle contract for conversion price validation
    /// @return twapOracle The TWAP oracle contract address
    function twapOracle() external view returns (IOracleV2 twapOracle);

    /// @notice The spot oracle contract for conversion price validation
    /// @return spotOracle The spot oracle contract address
    function spotOracle() external view returns (IOracleV2 spotOracle);

    /// @notice The last issued token ID
    /// @return lastId The most recent token ID
    function lastId() external view returns (uint256 lastId);

    /// @notice The factory contract for creating permissioned ERC20 tokens
    /// @return factory factory The factory contract address
    function factory() external view returns (IPermissionedERC20Factory factory);

    /// @notice Total amount of loan tokens staked across all positions
    /// @return totalStaked The total staked amount
    function totalStaked(address loanToken) external view returns (uint256 totalStaked);

    /// @notice Total amount of RZR tokens convertible across all positions
    /// @return totalConvertible The total convertible amount
    function totalConvertible() external view returns (uint256 totalConvertible);

    /// @notice Contract variables for conversion premiums and interest rates
    /// @param _loanToken The loan token that was enabled
    /// @return vars The contract variables
    function variables(IERC20 _loanToken) external view returns (Variables memory vars);

    /// @notice Get position details for a specific token ID
    /// @param tokenId The NFT token ID
    /// @return position The position details
    function positions(uint256 tokenId) external view returns (Position memory position);

    /// @notice Initialize the convertibles contract
    /// @param _rzr The RZR token contract address
    /// @param _oracle The oracle contract address for price feeds
    /// @param _spotOracle The spot oracle contract address
    /// @param _twapOracle The TWAP oracle contract address
    /// @param _authority The authority contract address
    function initialize(
        address _rzr,
        address _oracle,
        address _spotOracle,
        address _twapOracle,
        address _authority,
        address _factory
    ) external;

    /// @notice Enable a new loan token for convertible positions
    /// @param loanToken The loan token to enable
    /// @param _minConversionPremium Minimum conversion premium (in basis points)
    /// @param _maxConversionPremium Maximum conversion premium (in basis points)
    /// @param _minFixedInterestRate Minimum fixed interest rate per second
    /// @param _maxFixedInterestRate Maximum fixed interest rate per second
    /// @param _debtCap Maximum debt of convertible positions
    function enableToken(
        IERC20Metadata loanToken,
        uint256 _minConversionPremium,
        uint256 _maxConversionPremium,
        uint256 _minFixedInterestRate,
        uint256 _maxFixedInterestRate,
        uint256 _debtCap
    ) external;

    /// @notice Set contract variables (governance only)
    /// @param _loanToken The loan token that was enabled
    /// @param _minConversionPremium Minimum conversion premium (in basis points)
    /// @param _maxConversionPremium Maximum conversion premium (in basis points)
    /// @param _minFixedInterestRate Minimum fixed interest rate per second
    /// @param _maxFixedInterestRate Maximum fixed interest rate per second
    /// @param _debtCap Maximum debt of convertible positions
    function setVariables(
        IERC20 _loanToken,
        uint256 _minConversionPremium,
        uint256 _maxConversionPremium,
        uint256 _minFixedInterestRate,
        uint256 _maxFixedInterestRate,
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
    /// @return stakingPower Amount of staking power tokens received
    function stake(IERC20 loanToken, uint256 amount, uint256 lockDuration, address receiver)
        external
        returns (
            uint256 tokenId,
            uint256 conversionPrice,
            uint256 conversionAmount,
            uint256 fixedInterestRate,
            uint256 fixedInterestRateAmount,
            uint256 stakingPower
        );

    /// @notice Convert a convertible position to RZR tokens
    /// @param tokenId The NFT token ID to convert
    function convert(uint256 tokenId) external;

    /// @notice Redeem a convertible position for loan tokens + accumulated interest
    /// @param tokenId The NFT token ID to redeem
    /// @param unwrap4626 Whether to unwrap the loan tokens from the 4626 vault
    function redeem(uint256 tokenId, bool unwrap4626) external;

    /// @notice Split a convertible position into two positions
    /// @param tokenId The NFT token ID to split
    /// @param percentageE18 The percentage to split (0-1e18 representing 0-100%)
    function split(uint256 tokenId, uint256 percentageE18) external;

    /// @notice Calculate conversion terms for a given amount and lock duration
    /// @param loanToken The loan token that was enabled
    /// @param amountLoan Amount of loan tokens to stake
    /// @param lockDuration Duration to lock the position
    /// @return conversionPrice Price at which conversion can occur
    /// @return conversionAmount Amount of RZR tokens convertible
    /// @return fixedInterestRate Fixed interest rate per second
    function getOfferings(IERC20 loanToken, uint256 amountLoan, uint256 lockDuration)
        external
        view
        returns (uint256 conversionPrice, uint256 conversionAmount, uint256 fixedInterestRate);

    /// @notice Executes a function on the contract
    /// @param target The target contract
    /// @param data The data to execute
    function execute(address target, bytes memory data) external;
}
