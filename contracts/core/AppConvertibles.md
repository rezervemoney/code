# AppConvertibles

**File**: [`AppConvertibles.sol`](./AppConvertibles.sol)

**License**: AGPL-3.0

**Test File**: [`test/foundry/AppConvertiblesTest.t.sol`](../../test/foundry/AppConvertiblesTest.t.sol)

## Overview

The `AppConvertibles` contract manages convertible bond and debt instrument operations for the Rezerve.money protocol. It provides mechanisms for debt-equity conversion, convertible debt management, and flexible financing options through sophisticated conversion and vesting mechanisms.

## Purpose

This contract serves as:

- **Convertible Debt**: Management of convertible debt instruments
- **Debt-Equity Conversion**: Mechanisms for converting debt to equity
- **Flexible Financing**: Alternative funding options for the protocol
- **Investor Relations**: Providing convertible investment opportunities
- **Economic Policy**: Implementing convertible debt strategies

## Architecture

### Inheritance

- `AppAccessControlled` - Protocol access control integration
- `Initializable` - Upgradeable contract pattern

### Core Components

- **Convertible Management**: Convertible debt creation and management
- **Conversion Mechanisms**: Debt to equity conversion logic
- **Vesting Schedules**: Token vesting and distribution management
- **Debt Tracking**: Protocol debt obligation management

## Key Functions

### Staking and Conversion

#### Stake for Convertibles

```solidity
function stake(uint256 amount, uint256 lockDuration, address receiver) external returns (
    uint256 tokenId,
    uint256 conversionPrice,
    uint256 conversionAmount,
    uint256 fixedInterestRate,
    uint256 fixedInterestRateAmount
)
```

**Purpose**: Stake loan tokens to receive convertible debt positions.

**Parameters**:

- `amount`: Amount of loan tokens to stake
- `lockDuration`: Duration to lock staked tokens
- `receiver`: Address to receive the position NFT

**Returns**: Position details including conversion terms and interest rates.

**Process**: Creates NFT position, calculates conversion terms, mints tracking tokens.

#### Convert to Equity

```solidity
function convert(uint256 tokenId) external
```

**Purpose**: Convert convertible debt to RZR equity tokens.

**Parameters**: `tokenId` - NFT token ID of the position.

**Requirements**: Must meet minimum lock duration and price conversion criteria.

**Process**: Burns NFT, transfers loan tokens to treasury, mints RZR tokens.

#### Redeem Position

```solidity
function redeem(uint256 tokenId) external
```

**Purpose**: Redeem staked tokens with accumulated interest.

**Parameters**: `tokenId` - NFT token ID of the position.

**Requirements**: Must meet lock duration requirement.

**Process**: Burns NFT, returns staked tokens plus interest, burns tracking tokens.

### Position Management

#### Split Position

```solidity
function split(uint256 tokenId, uint256 percentageE18) external
```

**Purpose**: Split a position into two separate positions.

**Parameters**:

- `tokenId` - Original position ID
- `percentageE18` - Percentage to split (0-1e18)

**Process**: Creates new NFT with split amounts, updates original position.

#### Claim Interest

```solidity
function claimInterest(uint256 tokenId) external returns (uint256 interestClaimed, uint256 totalInterestClaimed)
```

**Purpose**: Claim accumulated fixed interest on a position.

**Parameters**: `tokenId` - NFT token ID of the position.

**Returns**: Interest claimed and total interest claimed.

**Process**: Calculates claimable interest, transfers loan tokens to owner.

### Configuration

#### Update Oracles

```solidity
function updateOracle(address _oracle, address _twapOracle) external onlyGovernor
```

**Purpose**: Update oracle addresses for price feeds.

**Access Control**: Only governors can update oracles.

#### Set Variables

```solidity
function setVariables(
    uint256 _minConversionPremium,
    uint256 _maxConversionPremium,
    uint256 _minFixedInterestRate,
    uint256 _maxFixedInterestRate,
    uint256 _supplyCap,
    uint256 _debtCap
) external onlyGovernor
```

**Purpose**: Update protocol configuration parameters.

**Access Control**: Only governors can update variables.

**Parameters**: `convertibleId` - ID of the convertible to claim from.

**Requirements**: Must have vested tokens available.

**Process**:

1. Calculate claimable vested tokens
2. Transfer tokens to user
3. Update vesting tracking
4. Emit claim event

### Debt Management

#### Get Total Convertible Debt

```solidity
function getTotalConvertibleDebt() external view returns (uint256)
```

**Purpose**: Get total protocol convertible debt.

**Returns**: Total convertible debt amount across all instruments.

#### Get Convertible Debt

```solidity
function getConvertibleDebt(uint256 convertibleId) external view returns (uint256)
```

**Purpose**: Get debt amount for a specific convertible.

**Parameters**: `convertibleId` - ID of the convertible.

**Returns**: Debt amount for the specified convertible.

## Integration Points

### Protocol Contracts

- **RZR Token**: [`RZR.sol`](./RZR.sol) - Equity token distribution
- **Treasury**: [`AppTreasury.sol`](./AppTreasury.sol) - Funding and debt management
- **Authority**: [`AppAuthority.sol`](./AppAuthority.sol) - Access control
- **Oracle**: Oracle contracts for pricing and conversion calculations

### External Systems

- **Investment Tokens**: Various tokens accepted for convertible purchases
- **Vesting System**: Automated vesting and distribution
- **Debt Analytics**: Debt tracking and reporting systems

## Economic Model

### Convertible Mechanics

- **Conversion Rate**: Fixed rate for debt to equity conversion
- **Vesting Schedule**: Gradual token distribution over time
- **Conversion Flexibility**: Users can convert at any time
- **Equity Participation**: Convertible holders become equity participants

### Debt Structure

- **Principal Amount**: Face value of issued convertibles
- **Conversion Option**: Right to convert debt to equity
- **Vesting Schedule**: Time-based token distribution
- **Debt Service**: Token distribution as debt service

### Investment Returns

- **Debt Interest**: Interest payments through token appreciation
- **Conversion Benefits**: Potential for equity upside
- **Vesting Benefits**: Gradual distribution reduces market impact
- **Protocol Participation**: Convertible holders become stakeholders

## Security Features

### Access Control

- **Role-Based Permissions**: Only authorized roles can manage convertibles
- **Convertible Creation**: Controlled issuance through bond managers
- **Parameter Updates**: Governance-controlled parameter changes
- **Emergency Controls**: Emergency pause and override capabilities

### Economic Security

- **Debt Limits**: Maximum debt limits to prevent over-leverage
- **Vesting Enforcement**: Strict vesting schedule enforcement
- **Conversion Validation**: All conversions validated and tracked
- **Overflow Protection**: Safe math operations for all calculations

### Operational Security

- **Convertible Validation**: All convertible parameters validated
- **State Consistency**: Consistent state across all operations
- **Event Logging**: Complete transparency of all operations
- **Emergency Procedures**: Emergency response capabilities

## Usage Examples

### Convertible Management

#### Create New Convertible

```solidity
// Create a convertible with 5% conversion rate and 12-month vesting
AppConvertibles convertibles = AppConvertibles(convertiblesAddress);

convertibles.createConvertible(
    1000000e18,  // 1M principal
    5e16,         // 5% conversion rate
    365 days,     // 12-month vesting
    1000          // Max 1000 convertibles
);
```

#### Purchase Convertible

```solidity
// Purchase convertible with 1000 USDC
uint256 convertibleId = 1;
uint256 amount = 1000e6; // 1000 USDC

convertibles.purchaseConvertible(convertibleId, amount);
```

### Conversion Operations

#### Convert Debt to Equity

```solidity
// Convert 500 convertible debt to equity
convertibles.convertToEquity(convertibleId, 500e18);
```

#### Check Conversion Eligibility

```solidity
// Get conversion information
(
    uint256 convertibleAmount,
    uint256 equityAmount,
    uint256 conversionRate,
    bool canConvert
) = convertibles.getConversionInfo(convertibleId, msg.sender);

if (canConvert) {
    console.log("Can convert", convertibleAmount, "to", equityAmount, "equity");
}
```

### Vesting and Claims

#### Check Vesting Status

```solidity
// Get vesting information for user's convertible
(
    uint256 totalTokens,
    uint256 vestedTokens,
    uint256 claimableTokens,
    uint256 vestingStartTime
) = convertibles.getVestingInfo(convertibleId, msg.sender);

console.log("Total Tokens:", totalTokens);
console.log("Vested Tokens:", vestedTokens);
console.log("Claimable Tokens:", claimableTokens);
```

#### Claim Vested Tokens

```solidity
// Claim vested tokens
convertibles.claimVestedTokens(convertibleId);
```

### Debt Analytics

#### Get Total Convertible Debt

```solidity
// Check total protocol convertible debt
uint256 totalDebt = convertibles.getTotalConvertibleDebt();
console.log("Total Convertible Debt:", totalDebt);
```

#### Get Convertible-Specific Debt

```solidity
// Check debt for specific convertible
uint256 convertibleDebt = convertibles.getConvertibleDebt(convertibleId);
console.log("Convertible Debt:", convertibleDebt);
```

## Events

### Convertible Events

```solidity
event ConvertibleCreated(uint256 indexed convertibleId, uint256 principal, uint256 conversionRate, uint256 vestingPeriod);
event ConvertiblePurchased(uint256 indexed convertibleId, address indexed buyer, uint256 amount, uint256 tokens);
event ConvertibleConverted(uint256 indexed convertibleId, address indexed user, uint256 debtAmount, uint256 equityAmount);
```

### Vesting Events

```solidity
event TokensVested(uint256 indexed convertibleId, address indexed user, uint256 amount);
event TokensClaimed(uint256 indexed convertibleId, address indexed user, uint256 amount);
```

### Management Events

```solidity
event ConvertibleParametersUpdated(uint256 indexed convertibleId, uint256 conversionRate, uint256 vestingPeriod);
event ConvertibleStatusUpdated(uint256 indexed convertibleId, bool active);
```

## Testing

### Unit Tests

- Convertible creation and management functionality
- Purchase and conversion mechanisms
- Vesting calculation accuracy
- Debt tracking and management

### Integration Tests

- Cross-contract token flows
- Treasury integration testing
- Oracle price feed integration
- Authority system integration

### Security Tests

- Access control validation
- Economic attack vectors
- Vesting manipulation prevention
- Emergency procedure testing

## Deployment Considerations

### Initial Setup

1. **Deploy Contract**: Deploy AppConvertibles contract
2. **Configure Authority**: Set up access control integration
3. **Set Parameters**: Configure convertible parameters and limits
4. **Verify Integration**: Test with RZR token and treasury

### Configuration

1. **Authority Integration**: Connect to protocol authority system
2. **Convertible Parameters**: Set default convertible terms and conditions
3. **Debt Limits**: Configure maximum debt limits
4. **Vesting Schedules**: Set up vesting period options

## Dependencies

### Core Dependencies

- **AppAccessControlled**: Protocol access control integration
- **Initializable**: Upgradeable contract pattern
- **RZR Token**: Equity token distribution

### External Dependencies

- **Treasury System**: Funding and debt management
- **Oracle System**: Pricing and conversion calculations
- **Investment Tokens**: Various tokens for convertible purchases

## Best Practices

### Convertible Management

1. **Parameter Validation**: Validate all convertible parameters before creation
2. **Debt Monitoring**: Monitor total protocol convertible debt levels
3. **Vesting Enforcement**: Strictly enforce vesting schedules
4. **Investor Communication**: Clear communication of convertible terms

### Security Considerations

1. **Access Control**: Verify all convertible operations are properly authorized
2. **Debt Limits**: Implement and enforce maximum debt limits
3. **Vesting Security**: Protect against vesting manipulation
4. **Emergency Procedures**: Test emergency response capabilities

### User Experience

1. **Clear Documentation**: Provide clear convertible investment instructions
2. **Vesting Transparency**: Show clear vesting schedules and progress
3. **Conversion Process**: Simplify debt to equity conversion
4. **Investment Tracking**: Provide tools to track convertible performance

## Testing

### Unit Tests

- Convertible creation
- Purchase operations
- Conversion logic
- Vesting calculations

**Test File**: [`test/foundry/AppConvertiblesTest.t.sol`](../../test/foundry/AppConvertiblesTest.t.sol)

### Integration Tests

- Protocol contract integration
- Treasury interaction testing
- Oracle operations

### Security Tests

- Unauthorized access attempts
- Access control validation
- Conversion manipulation prevention

## License

AGPL-3.0
