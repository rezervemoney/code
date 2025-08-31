# AppConvertibles

**File**: [`AppConvertibles.sol`](./AppConvertibles.sol)

**License**: AGPL-3.0-or-later

**Test File**: [`test/foundry/AppConvertiblesTest.t.sol`](../../test/foundry/AppConvertiblesTest.t.sol)

## Overview

The `AppConvertibles` contract manages convertible debt positions for the Rezerve.money protocol. It provides mechanisms for users to stake loan tokens and receive convertible debt positions that can be converted to RZR equity or redeemed with interest. The system uses NFT-based positions to track individual convertible debt holdings.

## Purpose

This contract serves as:

- **Convertible Debt Management**: Management of convertible debt positions through NFTs
- **Staking System**: Allow users to stake loan tokens for convertible positions
- **Conversion Mechanism**: Convert debt positions to RZR equity tokens
- **Interest Distribution**: Distribute fixed interest on staked positions
- **Position Management**: Split and manage convertible debt positions

## Architecture

### Inheritance

- `IAppConvertibles` - Convertibles system interface
- `AppAccessControlled` - Protocol access control integration
- `ERC721EnumerableUpgradeable` - NFT position management
- `ReentrancyGuardUpgradeable` - Reentrancy protection

### Core Components

- **NFT Positions**: ERC721 tokens representing convertible debt positions
- **Staking Mechanism**: Loan token staking for convertible positions
- **Conversion Logic**: Debt to equity conversion based on price conditions
- **Interest Calculation**: Fixed interest rate calculations and distribution
- **Position Management**: Position splitting and transfer capabilities

## Key Functions

### Position Management

#### Stake for Convertibles

```solidity
function stake(IERC20 loanToken, uint256 amount, uint256 lockDuration, address receiver) external returns (
    uint256 tokenId,
    uint256 conversionPrice,
    uint256 conversionAmount,
    uint256 fixedInterestRate,
    uint256 fixedInterestRateAmount,
    uint256 stakingPower
)
```

**Purpose**: Stake loan tokens to receive convertible debt positions.

**Parameters**:

- `loanToken` - The loan token to stake
- `amount` - Amount of loan tokens to stake
- `lockDuration` - Duration to lock staked tokens (30 days to 4 years)
- `receiver` - Address to receive the position NFT

**Returns**: Position details including conversion terms, interest rates, and staking power.

**Process**: Creates NFT position, calculates conversion terms, mints tracking tokens.

#### Convert to Equity

```solidity
function convert(uint256 tokenId) external nonReentrant onlyOwnerOrAuthorized(tokenId)
```

**Purpose**: Convert convertible debt to RZR equity tokens.

**Parameters**: `tokenId` - NFT token ID of the position.

**Requirements**: Must meet minimum lock duration and price conversion criteria.

**Process**: Burns NFT, transfers loan tokens to treasury, mints RZR tokens.

#### Redeem Position

```solidity
function redeem(uint256 tokenId) external nonReentrant onlyOwnerOrAuthorized(tokenId)
```

**Purpose**: Redeem staked tokens with accumulated interest.

**Parameters**: `tokenId` - NFT token ID of the position.

**Requirements**: Must meet lock duration requirement.

**Process**: Burns NFT, returns staked tokens plus interest, burns tracking tokens.

### Position Operations

#### Split Position

```solidity
function split(uint256 tokenId, uint256 percentageE18) external nonReentrant onlyOwnerOrAuthorized(tokenId)
```

**Purpose**: Split a position into two separate positions.

**Parameters**:

- `tokenId` - Original position ID
- `percentageE18` - Percentage to split (0-1e18)

**Process**: Creates new NFT with split amounts, updates original position.

#### Claim Interest

```solidity
function claimInterest(uint256 tokenId) external nonReentrant returns (
    uint256 interestClaimed,
    uint256 totalInterestClaimed
)
```

**Purpose**: Claim accumulated fixed interest on a position.

**Parameters**: `tokenId` - NFT token ID of the position.

**Returns**: Interest claimed and total interest claimed.

**Process**: Calculates claimable interest, transfers loan tokens to owner.

### Query Functions

#### Get Position Information

```solidity
function positions(uint256 tokenId) public view returns (Position memory position)
```

**Purpose**: Get complete position information for a token ID.

**Parameters**: `tokenId` - NFT token ID.

**Returns**: Complete position data structure.

#### Get Claimable Interest

```solidity
function claimableInterest(uint256 tokenId) public view returns (
    uint256 interestClaimable,
    uint256 totalInterestClaimed
)
```

**Purpose**: Get claimable interest for a position.

**Parameters**: `tokenId` - NFT token ID.

**Returns**: Claimable interest and total interest claimed.

#### Get Offerings

```solidity
function getOfferings(IERC20 loanToken, uint256 amountLoan, uint256 lockDuration) public view returns (
    uint256 conversionPrice,
    uint256 conversionAmount,
    uint256 fixedInterestRate
)
```

**Purpose**: Calculate conversion terms for a given stake amount and duration.

**Parameters**:

- `loanToken` - The loan token to stake
- `amountLoan` - Amount of loan tokens to stake
- `lockDuration` - Lock duration for the position

**Returns**: Conversion price, conversion amount, and fixed interest rate.

#### Get Variables

```solidity
function variables(IERC20 _loanToken) public view returns (Variables memory vars)
```

**Purpose**: Get current protocol configuration variables for a specific loan token.

**Parameters**: `_loanToken` - The loan token to get variables for.

**Returns**: Current protocol variables and parameters for the specified token.

#### Get Total Staked

```solidity
function totalStaked(address loanToken) external view returns (uint256)
```

**Purpose**: Get total amount staked for a specific loan token.

**Parameters**: `loanToken` - The loan token address.

**Returns**: Total amount staked for the token.

### Configuration Management

#### Enable Token

```solidity
function enableToken(
    IERC20Metadata loanToken,
    uint256 _minConversionPremium,
    uint256 _maxConversionPremium,
    uint256 _minFixedInterestRate,
    uint256 _maxFixedInterestRate,
    uint256 _debtCap
) external onlyGovernor
```

**Purpose**: Enable a new loan token for staking and convertibles.

**Access Control**: Only governors can enable new tokens.

**Parameters**:

- `loanToken` - The loan token to enable
- `_minConversionPremium` - Minimum conversion premium
- `_maxConversionPremium` - Maximum conversion premium
- `_minFixedInterestRate` - Minimum fixed interest rate
- `_maxFixedInterestRate` - Maximum fixed interest rate
- `_debtCap` - Maximum debt cap for the token

#### Set Variables

```solidity
function setVariables(
    IERC20 _loanToken,
    uint256 _minConversionPremium,
    uint256 _maxConversionPremium,
    uint256 _minFixedInterestRate,
    uint256 _maxFixedInterestRate,
    uint256 _debtCap
) external onlyGovernor
```

**Purpose**: Update protocol configuration parameters for a specific loan token.

**Access Control**: Only governors can update variables.

**Parameters**: Various protocol configuration values for the specified token.

#### Execute

```solidity
function execute(address target, bytes memory data) external onlyGovernor
```

**Purpose**: Execute arbitrary calls on other contracts (emergency function).

**Access Control**: Only governors can execute arbitrary calls.

**Parameters**:

- `target` - Target contract address
- `data` - Encoded function call data

## Usage Examples

### Position Creation

#### Stake for Convertibles

```solidity
// Stake 1000 USDC for 1 year
AppConvertibles convertibles = AppConvertibles(convertiblesAddress);
IERC20 usdc = IERC20(usdcAddress);

(uint256 tokenId, uint256 conversionPrice, uint256 conversionAmount, uint256 fixedInterestRate, uint256 fixedInterestRateAmount, uint256 stakingPower) = convertibles.stake(
    usdc,           // USDC token
    1000e6,        // 1000 USDC
    365 days,      // 1 year lock
    msg.sender     // Receive position
);

console.log("Position ID:", tokenId);
console.log("Conversion Price:", conversionPrice);
console.log("Convertible Amount:", conversionAmount);
console.log("Fixed Interest Rate:", fixedInterestRate);
console.log("Staking Power:", stakingPower);
```

### Position Management

#### Check Position Details

```solidity
// Get position information
Position memory position = convertibles.positions(tokenId);
console.log("Amount Staked:", position.amountStaked);
console.log("Convertible Amount:", position.amountConvertible);
console.log("Lock Duration:", position.lockDuration);
console.log("Lock Start Time:", position.lockStartTime);
console.log("Conversion Price:", position.priceConversion);
console.log("Entry Price:", position.priceEntry);
```

#### Split Position

```solidity
// Split position 50/50
convertibles.split(tokenId, 0.5e18); // 50%
```

### Conversion and Redemption

#### Convert to Equity

```solidity
// Convert position to RZR equity
convertibles.convert(tokenId);
```

#### Redeem with Interest

```solidity
// Redeem position and claim interest
convertibles.redeem(tokenId);
```

### Interest Management

#### Check Claimable Interest

```solidity
// Get claimable interest
(uint256 interestClaimable, uint256 totalInterestClaimed) = convertibles.claimableInterest(tokenId);
console.log("Interest Claimable:", interestClaimable);
console.log("Total Interest Claimed:", totalInterestClaimed);
```

#### Claim Interest

```solidity
// Claim accumulated interest
(uint256 interestClaimed, uint256 totalInterestClaimed) = convertibles.claimInterest(tokenId);
console.log("Interest Claimed:", interestClaimed);
```

### Market Information

#### Get Conversion Offerings

```solidity
// Calculate conversion terms for 1000 USDC, 6 months
(uint256 conversionPrice, uint256 conversionAmount, uint256 fixedInterestRate) = convertibles.getOfferings(
    usdc,           // USDC token
    1000e6,        // 1000 USDC
    180 days       // 6 months
);

console.log("Conversion Price:", conversionPrice);
console.log("Convertible Amount:", conversionAmount);
console.log("Fixed Interest Rate:", fixedInterestRate);
```

#### Check Protocol Variables

```solidity
// Get current protocol configuration for USDC
Variables memory vars = convertibles.variables(usdc);
console.log("Min Conversion Premium:", vars.minConversionPremium);
console.log("Max Conversion Premium:", vars.maxConversionPremium);
console.log("Min Fixed Interest Rate:", vars.minFixedInterestRate);
console.log("Max Fixed Interest Rate:", vars.maxFixedInterestRate);
console.log("Debt Cap:", vars.debtCap);
```

#### Check Total Staked

```solidity
// Get total USDC staked
uint256 totalUsdcStaked = convertibles.totalStaked(address(usdc));
console.log("Total USDC Staked:", totalUsdcStaked);
```

## Events

### Position Events

```solidity
event Staked(address indexed receiver, uint256 indexed tokenId, uint256 amount, uint256 conversionAmount, uint256 lockDuration, uint256 price, uint256 conversionPrice, uint256 fixedInterestRate);
event Converted(address indexed user, uint256 indexed tokenId, uint256 amountStaked, uint256 conversionAmount, uint256 twapPrice);
event Redeemed(address indexed user, uint256 indexed tokenId, uint256 amountStaked, uint256 conversionAmount, uint256 interestAccumulated);
```

### Management Events

```solidity
event PositionSplit(address indexed user, uint256 indexed originalTokenId, uint256 indexed newTokenId, uint256 originalAmountStaked, uint256 splitAmountStaked, uint256 originalConvertibleAmount, uint256 splitConvertibleAmount, uint256 percentageE18);
event PositionTransferred(address indexed from, address indexed to, uint256 indexed tokenId, uint256 stakingPower, uint256 amountConvertible);
event InterestClaimed(address indexed user, uint256 indexed tokenId, uint256 interestClaimed);
```

### Configuration Events

```solidity
event TokenEnabled(address indexed loanToken);
event VariablesUpdated(IERC20 indexed loanToken, uint256 minConversionPremium, uint256 maxConversionPremium, uint256 minFixedInterestRate, uint256 maxFixedInterestRate, uint256 debtCap);
```

## Constants

### Duration Limits

- `MAX_LOCK_DURATION`: 4 years (4 \* 365 days)
- `MIN_LOCK_DURATION`: 30 days
- `MIN_BOND_DURATION`: 7 days (minimum time before conversion)

### Oracle Settings

- `MAX_ORACLE_STALENESS`: 1 day (maximum oracle data age)

## Internal Functions

### Interest Calculation

```solidity
function _interestAccumulated(
    uint256 amount,
    uint256 interestRatePerYear,
    uint256 currentTime,
    uint256 lockStartTime,
    uint256 lockDuration
) internal pure returns (uint256 interest)
```

**Purpose**: Calculate accumulated interest based on time elapsed and interest rate.

**Logic**: Uses linear interest calculation with per-second precision.

### Price Retrieval

```solidity
function _getPrice(IERC20 loanToken) internal view returns (uint256 price)
function _getTwapPrice() internal view returns (uint256 price)
```

**Purpose**: Get current price from oracle or TWAP oracle.

**Validation**: Ensures prices are valid and not stale.

### Scaling Functions

```solidity
function _scale(uint256 max, uint256 min, uint256 lockDuration) internal pure returns (uint256 value)
function _scaleAmount(IERC20 loanToken, uint256 amount) internal view returns (uint256 amountScaled)
function _getStakingPower(IERC20 loanToken, uint256 amount, uint256 duration) internal view returns (uint256 stakingPower)
```

**Purpose**: Scale values based on lock duration and token decimals.

## License

AGPL-3.0-or-later
