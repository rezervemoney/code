# AppBurner

**File**: [`AppBurner.sol`](./AppBurner.sol)
**License**: AGPL-3.0

## Overview

The `AppBurner` contract is a token burning mechanism for the Rezerve.money protocol that provides controlled token burning for deflationary pressure and supply management. It implements various burning strategies and mechanisms to manage the RZR token supply effectively.

## Purpose

This contract serves as:

- **Supply Management**: Controlled reduction of RZR token supply
- **Deflationary Pressure**: Create deflationary pressure for token appreciation
- **Economic Balance**: Balance inflationary and deflationary forces
- **Protocol Integration**: Integration with other protocol mechanisms
- **Burning Strategies**: Multiple burning strategies and mechanisms

## Architecture

### Inheritance

- `AppAccessControlled` - Protocol access control integration
- `Initializable` - Upgradeable contract pattern

### Core Components

- **Burning Mechanisms**: Various token burning strategies
- **Supply Tracking**: Token supply monitoring and management
- **Strategy Management**: Configurable burning strategies
- **Integration Points**: Connection with other protocol contracts

## Key Functions

### Burning Operations

#### Burn Tokens

```solidity
function burn(uint256 amount) external onlyReserveManager
```

**Purpose**: Burn a specified amount of RZR tokens.

**Access Control**: Only reserve managers can burn tokens.

**Parameters**: `amount` - Amount of RZR tokens to burn.

**Process**:

1. Validate burn amount
2. Transfer tokens from treasury to burner
3. Burn tokens permanently
4. Update supply tracking
5. Emit burn event

#### Burn From Treasury

```solidity
function burnFromTreasury(uint256 amount) external onlyReserveManager
```

**Purpose**: Burn tokens directly from treasury reserves.

**Access Control**: Only reserve managers can burn from treasury.

**Parameters**: `amount` - Amount of tokens to burn from treasury.

**Process**:

1. Calculate available treasury balance
2. Burn tokens from treasury
3. Update supply and treasury tracking
4. Emit burn event

### Strategy Management

#### Set Burning Strategy

```solidity
function setBurningStrategy(
    uint256 strategyId,
    uint256 burnRate,
    bool active
) external onlyGovernor
```

**Purpose**: Configure burning strategies and parameters.

**Access Control**: Only governors can set burning strategies.

**Parameters**:

- `strategyId`: ID of the burning strategy
- `burnRate`: Rate of burning for this strategy
- `active`: Whether the strategy is active

**Process**:

1. Validate strategy parameters
2. Update strategy configuration
3. Emit strategy updated event

#### Execute Burning Strategy

```solidity
function executeBurningStrategy(uint256 strategyId) external onlyExecutor
```

**Purpose**: Execute a configured burning strategy.

**Access Control**: Only executors can execute strategies.

**Parameters**: `strategyId` - ID of the strategy to execute.

**Process**:

1. Validate strategy is active
2. Calculate burn amount based on strategy
3. Execute burning operation
4. Update strategy execution tracking

### Supply Management

#### Get Total Burned

```solidity
function getTotalBurned() external view returns (uint256)
```

**Purpose**: Get total amount of RZR tokens burned.

**Returns**: Total amount of tokens burned since inception.

#### Get Burned This Period

```solidity
function getBurnedThisPeriod() external view returns (uint256)
```

**Purpose**: Get amount of tokens burned in current period.

**Returns**: Amount of tokens burned in current period.

#### Get Burning Statistics

```solidity
function getBurningStats() external view returns (
    uint256 totalBurned,
    uint256 burnedThisPeriod,
    uint256 lastBurnTime,
    uint256 activeStrategies
)
```

**Purpose**: Get comprehensive burning statistics.

**Returns**: Complete burning statistics and information.

## Integration Points

### Protocol Contracts

- **RZR Token**: [`RZR.sol`](./RZR.sol) - Token burning operations
- **Treasury**: [`AppTreasury.sol`](./AppTreasury.sol) - Treasury integration
- **Authority**: [`AppAuthority.sol`](./AppAuthority.sol) - Access control
- **Staking**: [`AppStaking.sol`](./AppStaking.sol) - Staking integration

### External Systems

- **Supply Analytics**: Token supply tracking and reporting
- **Economic Models**: Economic analysis and modeling
- **Burning Strategies**: External strategy management systems

## Usage Examples

### Basic Burning Operations

#### Burn Tokens

```solidity
// Burn 1000 RZR tokens
AppBurner burner = AppBurner(burnerAddress);

burner.burn(1000e18);
```

#### Burn From Treasury

```solidity
// Burn 500 RZR tokens from treasury
burner.burnFromTreasury(500e18);
```

### Strategy Management

#### Set Burning Strategy

```solidity
// Set up automatic burning strategy
burner.setBurningStrategy(
    1,              // Strategy ID
    5e16,           // 5% burn rate
    true            // Active
);
```

#### Execute Strategy

```solidity
// Execute burning strategy
burner.executeBurningStrategy(1);
```

### Supply Analytics

#### Check Burning Statistics

```solidity
// Get comprehensive burning stats
(
    uint256 totalBurned,
    uint256 burnedThisPeriod,
    uint256 lastBurnTime,
    uint256 activeStrategies
) = burner.getBurningStats();

console.log("Total Burned:", totalBurned);
console.log("Burned This Period:", burnedThisPeriod);
console.log("Active Strategies:", activeStrategies);
```

#### Get Total Burned

```solidity
// Check total tokens burned
uint256 totalBurned = burner.getTotalBurned();
console.log("Total Tokens Burned:", totalBurned);
```

#### Get Period Burned

```solidity
// Check current period burning
uint256 periodBurned = burner.getBurnedThisPeriod();
console.log("Tokens Burned This Period:", periodBurned);
```

## Events

### Burning Events

```solidity
event TokensBurned(uint256 amount, uint256 timestamp);
event TreasuryBurned(uint256 amount, uint256 timestamp);
event StrategyExecuted(uint256 indexed strategyId, uint256 amount);
```

### Strategy Events

```solidity
event BurningStrategySet(uint256 indexed strategyId, uint256 burnRate, bool active);
event BurningStrategyUpdated(uint256 indexed strategyId, uint256 oldRate, uint256 newRate);
```

### Management Events

```solidity
event BurnerParametersUpdated(uint256 maxBurnRate, uint256 maxBurnAmount);
event EmergencyBurnExecuted(uint256 amount, string reason);
```

## Testing

### Unit Tests

- Token burning functionality
- Strategy management mechanisms
- Supply tracking accuracy
- Access control validation

### Integration Tests

- Cross-contract burning flows
- Treasury integration testing
- Staking integration testing
- Authority system integration

### Security Tests

- Access control validation
- Economic attack vectors
- Supply manipulation prevention
- Emergency procedure testing

## Deployment Considerations

### Initial Setup

1. **Deploy Contract**: Deploy AppBurner contract
2. **Configure Authority**: Set up access control integration
3. **Set Strategies**: Configure initial burning strategies
4. **Verify Integration**: Test with RZR token and treasury

### Configuration

1. **Authority Integration**: Connect to protocol authority system
2. **Burning Strategies**: Set up effective burning strategies
3. **Supply Limits**: Configure maximum burning limits
4. **Monitoring Setup**: Implement burning monitoring

## Dependencies

### Core Dependencies

- **AppAccessControlled**: Protocol access control integration
- **Initializable**: Upgradeable contract pattern
- **RZR Token**: Token burning operations

### External Dependencies

- **Treasury System**: Treasury integration for burning
- **Economic Models**: Economic analysis and modeling
- **Supply Analytics**: Supply tracking and reporting

## Best Practices

### Burning Management

1. **Strategy Optimization**: Optimize burning strategies for goals
2. **Supply Monitoring**: Monitor token supply and burning impact
3. **Market Impact**: Minimize market disruption from burning
4. **Economic Balance**: Maintain balanced economic model

### Security Considerations

1. **Access Control**: Verify burning permissions are properly restricted
2. **Supply Limits**: Implement and enforce maximum burning limits
3. **Strategy Validation**: Validate all burning strategies
4. **Emergency Procedures**: Test emergency response capabilities

### User Experience

1. **Transparency**: Provide clear visibility of burning operations
2. **Impact Communication**: Communicate burning impact to users
3. **Strategy Visibility**: Show active burning strategies
4. **Monitoring Tools**: Provide tools to monitor burning operations

## License

AGPL-3.0
