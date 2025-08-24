# AppBondDepository

**File**: [`AppBondDepository.sol`](./AppBondDepository.sol)
**License**: AGPL-3.0

## Overview

The `AppBondDepository` contract is the bond issuance and management system for the Rezerve.money protocol. It enables the protocol to raise funds through bond sales while providing investors with discounted RZR tokens and managing debt obligations through sophisticated bond mechanics.

## Purpose

This contract serves as:

- **Bond Issuance**: Primary mechanism for protocol funding through bond sales
- **Debt Management**: Tracking and management of protocol debt obligations
- **Investor Relations**: Providing investment opportunities with discounted tokens
- **Protocol Funding**: Raising capital for development and operations
- **Economic Policy**: Implementing debt-based economic strategies

## Architecture

### Inheritance

- `AppAccessControlled` - Protocol access control integration
- `Initializable` - Upgradeable contract pattern

### Core Components

- **Bond Management**: Bond creation, tracking, and redemption
- **Debt Tracking**: Protocol debt obligation management
- **Vesting Schedules**: Bond token vesting and distribution
- **Pricing Mechanisms**: Dynamic bond pricing and discount calculations

## Key Functions

### Bond Issuance

#### Create Bond

```solidity
function createBond(
    uint256 principal,
    uint256 discount,
    uint256 vestingPeriod,
    uint256 maxBonds
) external onlyBondManager
```

**Purpose**: Create a new bond offering with specified parameters.

**Access Control**: Only bond managers can create bonds.

**Parameters**:

- `principal`: Principal amount of the bond
- `discount`: Discount percentage for bond purchasers
- `vestingPeriod`: Duration of token vesting period
- `maxBonds`: Maximum number of bonds that can be sold

**Process**:

1. Validate bond parameters
2. Create bond offering
3. Set bond terms and conditions
4. Emit bond creation event

#### Purchase Bond

```solidity
function purchaseBond(uint256 bondId, uint256 amount) external
```

**Purpose**: Purchase bonds with specified amount.

**Parameters**:

- `bondId`: ID of the bond to purchase
- `amount`: Amount to invest in the bond

**Process**:

1. Validate bond availability and terms
2. Transfer investment tokens from user
3. Calculate discounted RZR tokens
4. Create bond position for user

### Bond Management

#### Get Bond Information

```solidity
function getBond(uint256 bondId) external view returns (
    uint256 principal,
    uint256 discount,
    uint256 vestingPeriod,
    uint256 maxBonds,
    uint256 soldBonds,
    uint256 startTime,
    bool active
)
```

**Purpose**: Get detailed information about a specific bond.

**Parameters**: `bondId` - ID of the bond to query.

**Returns**: Complete bond information including terms and status.

#### Get User Bonds

```solidity
function getUserBonds(address user) external view returns (uint256[] memory)
```

**Purpose**: Get all bond IDs owned by a specific user.

**Parameters**: `user` - Address of the user.

**Returns**: Array of bond IDs owned by the user.

### Vesting and Redemption

#### Check Vesting Status

```solidity
function getVestingInfo(uint256 bondId, address user) external view returns (
    uint256 totalTokens,
    uint256 vestedTokens,
    uint256 claimableTokens,
    uint256 vestingStartTime
)
```

**Purpose**: Get vesting information for a user's bond position.

**Parameters**:

- `bondId`: ID of the bond
- `user`: Address of the bond holder

**Returns**: Detailed vesting information and status.

#### Claim Vested Tokens

```solidity
function claimVestedTokens(uint256 bondId) external
```

**Purpose**: Claim vested RZR tokens from a bond position.

**Parameters**: `bondId` - ID of the bond to claim from.

**Requirements**: Must have vested tokens available.

**Process**:

1. Calculate claimable vested tokens
2. Transfer RZR tokens to user
3. Update vesting tracking
4. Emit claim event

### Debt Management

#### Get Total Debt

```solidity
function getTotalDebt() external view returns (uint256)
```

**Purpose**: Get total protocol debt from all active bonds.

**Returns**: Total debt amount across all bonds.

#### Get Bond Debt

```solidity
function getBondDebt(uint256 bondId) external view returns (uint256)
```

**Purpose**: Get debt amount for a specific bond.

**Parameters**: `bondId` - ID of the bond.

**Returns**: Debt amount for the specified bond.

## Integration Points

### Protocol Contracts

- **RZR Token**: [`RZR.sol`](./RZR.sol) - Bond token distribution
- **Treasury**: [`AppTreasury.sol`](./AppTreasury.sol) - Bond funding and debt management
- **Authority**: [`AppAuthority.sol`](./AppAuthority.sol) - Access control
- **Oracle**: Oracle contracts for pricing and economic calculations

### External Systems

- **Investment Tokens**: Various tokens accepted for bond purchases
- **Vesting System**: Automated vesting and distribution
- **Debt Analytics**: Debt tracking and reporting systems

## Economic Model

### Bond Pricing

- **Discount Mechanism**: Bonds sold at discount to face value
- **Dynamic Pricing**: Pricing based on market conditions and demand
- **Vesting Schedule**: Gradual token distribution over time
- **Yield Calculation**: Effective yield based on discount and vesting

### Debt Structure

- **Principal Amount**: Face value of issued bonds
- **Interest Obligation**: Implicit interest through token appreciation
- **Maturity Schedule**: Vesting-based maturity structure
- **Debt Service**: Token distribution as debt service

### Investment Returns

- **Discount Capture**: Investors benefit from discounted token prices
- **Vesting Benefits**: Gradual distribution reduces market impact
- **Token Appreciation**: Potential for token value increase
- **Protocol Participation**: Bond holders become protocol stakeholders

## Security Features

### Access Control

- **Role-Based Permissions**: Only authorized roles can manage bonds
- **Bond Creation**: Controlled bond issuance through bond managers
- **Parameter Updates**: Governance-controlled parameter changes
- **Emergency Controls**: Emergency pause and override capabilities

### Economic Security

- **Debt Limits**: Maximum debt limits to prevent over-leverage
- **Vesting Enforcement**: Strict vesting schedule enforcement
- **Token Validation**: All token transfers validated
- **Overflow Protection**: Safe math operations for all calculations

### Operational Security

- **Bond Validation**: All bond parameters validated
- **State Consistency**: Consistent state across all operations
- **Event Logging**: Complete transparency of all operations
- **Emergency Procedures**: Emergency response capabilities

## Usage Examples

### Bond Management

#### Create New Bond

```solidity
// Create a bond with 10% discount and 12-month vesting
AppBondDepository bondDepository = AppBondDepository(bondAddress);

bondDepository.createBond(
    1000000e18,  // 1M principal
    10e16,        // 10% discount
    365 days,     // 12-month vesting
    1000          // Max 1000 bonds
);
```

#### Purchase Bond

```solidity
// Purchase bond with 1000 USDC
uint256 bondId = 1;
uint256 amount = 1000e6; // 1000 USDC

bondDepository.purchaseBond(bondId, amount);
```

### Bond Information

#### Get Bond Details

```solidity
// Get bond information
(
    uint256 principal,
    uint256 discount,
    uint256 vestingPeriod,
    uint256 maxBonds,
    uint256 soldBonds,
    uint256 startTime,
    bool active
) = bondDepository.getBond(bondId);

console.log("Principal:", principal);
console.log("Discount:", discount);
console.log("Vesting Period:", vestingPeriod);
```

#### Check User Bonds

```solidity
// Get user's bond positions
uint256[] memory userBonds = bondDepository.getUserBonds(msg.sender);
console.log("User has", userBonds.length, "bonds");
```

### Vesting and Claims

#### Check Vesting Status

```solidity
// Get vesting information for user's bond
(
    uint256 totalTokens,
    uint256 vestedTokens,
    uint256 claimableTokens,
    uint256 vestingStartTime
) = bondDepository.getVestingInfo(bondId, msg.sender);

console.log("Total Tokens:", totalTokens);
console.log("Vested Tokens:", vestedTokens);
console.log("Claimable Tokens:", claimableTokens);
```

#### Claim Vested Tokens

```solidity
// Claim vested tokens
bondDepository.claimVestedTokens(bondId);
```

### Debt Analytics

#### Get Total Protocol Debt

```solidity
// Check total protocol debt
uint256 totalDebt = bondDepository.getTotalDebt();
console.log("Total Protocol Debt:", totalDebt);
```

#### Get Bond-Specific Debt

```solidity
// Check debt for specific bond
uint256 bondDebt = bondDepository.getBondDebt(bondId);
console.log("Bond Debt:", bondDebt);
```

## Events

### Bond Events

```solidity
event BondCreated(uint256 indexed bondId, uint256 principal, uint256 discount, uint256 vestingPeriod);
event BondPurchased(uint256 indexed bondId, address indexed buyer, uint256 amount, uint256 tokens);
event BondRedeemed(uint256 indexed bondId, address indexed user, uint256 amount);
```

### Vesting Events

```solidity
event TokensVested(uint256 indexed bondId, address indexed user, uint256 amount);
event TokensClaimed(uint256 indexed bondId, address indexed user, uint256 amount);
```

### Management Events

```solidity
event BondParametersUpdated(uint256 indexed bondId, uint256 discount, uint256 vestingPeriod);
event BondStatusUpdated(uint256 indexed bondId, bool active);
```

## Testing

### Unit Tests

- Bond creation and management functionality
- Purchase and redemption mechanisms
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

1. **Deploy Contract**: Deploy AppBondDepository contract
2. **Configure Authority**: Set up access control integration
3. **Set Parameters**: Configure bond parameters and limits
4. **Verify Integration**: Test with RZR token and treasury

### Configuration

1. **Authority Integration**: Connect to protocol authority system
2. **Bond Parameters**: Set default bond terms and conditions
3. **Debt Limits**: Configure maximum debt limits
4. **Vesting Schedules**: Set up vesting period options

## Dependencies

### Core Dependencies

- **AppAccessControlled**: Protocol access control integration
- **Initializable**: Upgradeable contract pattern
- **RZR Token**: Bond token distribution

### External Dependencies

- **Treasury System**: Bond funding and debt management
- **Oracle System**: Pricing and economic calculations
- **Investment Tokens**: Various tokens for bond purchases

## Best Practices

### Bond Management

1. **Parameter Validation**: Validate all bond parameters before creation
2. **Debt Monitoring**: Monitor total protocol debt levels
3. **Vesting Enforcement**: Strictly enforce vesting schedules
4. **Investor Communication**: Clear communication of bond terms

### Security Considerations

1. **Access Control**: Verify all bond operations are properly authorized
2. **Debt Limits**: Implement and enforce maximum debt limits
3. **Vesting Security**: Protect against vesting manipulation
4. **Emergency Procedures**: Test emergency response capabilities

### User Experience

1. **Clear Documentation**: Provide clear bond investment instructions
2. **Vesting Transparency**: Show clear vesting schedules and progress
3. **Claim Automation**: Automate token claiming where possible
4. **Investment Tracking**: Provide tools to track bond performance

## License

AGPL-3.0
