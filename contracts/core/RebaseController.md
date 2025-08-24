# RebaseController

**File**: [`RebaseController.sol`](./RebaseController.sol)

**License**: AGPL-3.0

**Test File**: [`test/foundry/RebaseControllerTest.t.sol`](../../test/foundry/RebaseControllerTest.t.sol)

## Overview

The `RebaseController` contract is a rebase mechanism for the Rezerve.money protocol that provides supply adjustment, economic rebalancing, and market stabilization through sophisticated rebase calculations and supply management. It implements elastic supply mechanics to maintain economic equilibrium.

## Purpose

This contract serves as:

- **Supply Adjustment**: Dynamic adjustment of RZR token supply
- **Economic Rebalancing**: Maintain economic equilibrium and stability
- **Market Stabilization**: Stabilize token price and market conditions
- **Elastic Supply**: Implement elastic supply mechanics
- **Economic Policy**: Execute rebase-based economic strategies

## Architecture

### Inheritance

- `AppAccessControlled` - Protocol access control integration
- `Initializable` - Upgradeable contract pattern

### Core Components

- **Rebase Calculation**: Rebase amount and frequency calculations
- **Supply Management**: Token supply adjustment mechanisms
- **Economic Metrics**: Economic indicators and calculations
- **Rebase Execution**: Automated and manual rebase execution

## Key Functions

### Rebase Management

#### Calculate Rebase

```solidity
function calculateRebase() external view returns (uint256 rebaseAmount, bool shouldRebase)
```

**Purpose**: Calculate rebase amount and determine if rebase should occur.

**Returns**:

- `rebaseAmount`: Amount to adjust supply by
- `shouldRebase`: Whether rebase should be executed

**Process**: Analyzes economic conditions and calculates optimal rebase.

#### Execute Rebase

```solidity
function executeRebase() external onlyRebaseManager
```

**Purpose**: Execute a rebase operation to adjust token supply.

**Access Control**: Only rebase managers can execute rebases.

**Process**:

1. Calculate rebase amount
2. Adjust token supply
3. Update rebase tracking
4. Emit rebase executed event

#### Emergency Rebase

```solidity
function emergencyRebase(uint256 amount) external onlyGovernor
```

**Purpose**: Execute emergency rebase for urgent economic adjustments.

**Access Control**: Only governors can execute emergency rebases.

**Parameters**: `amount` - Emergency rebase amount.

**Process**: Executes immediate rebase with specified amount.

### Rebase Configuration

#### Set Rebase Parameters

```solidity
function setRebaseParameters(
    uint256 minRebaseInterval,
    uint256 maxRebaseAmount,
    uint256 targetPrice
) external onlyGovernor
```

**Purpose**: Update rebase configuration parameters.

**Access Control**: Only governors can update parameters.

**Parameters**:

- `minRebaseInterval`: Minimum time between rebases
- `maxRebaseAmount`: Maximum rebase amount per operation
- `targetPrice`: Target price for economic equilibrium

**Process**: Updates parameters and emits event.

#### Get Rebase Parameters

```solidity
function getRebaseParameters() external view returns (
    uint256 minRebaseInterval,
    uint256 maxRebaseAmount,
    uint256 targetPrice,
    uint256 lastRebaseTime
)
```

**Purpose**: Get current rebase configuration.

**Returns**: Current rebase parameters and timing.

### Supply Management

#### Get Supply Info

```solidity
function getSupplyInfo() external view returns (
    uint256 currentSupply,
    uint256 targetSupply,
    uint256 lastRebaseAmount,
    uint256 totalRebases
)
```

**Purpose**: Get comprehensive supply information.

**Returns**: Current supply, target supply, and rebase history.

#### Get Rebase History

```solidity
function getRebaseHistory(uint256 index) external view returns (
    uint256 amount,
    uint256 timestamp,
    uint256 supplyBefore,
    uint256 supplyAfter
)
```

**Purpose**: Get historical rebase information.

**Parameters**: `index` - Index of rebase in history.

**Returns**: Detailed rebase information.

## Integration Points

### Protocol Contracts

- **RZR Token**: [`RZR.sol`](./RZR.sol) - Supply adjustment operations
- **Treasury**: [`AppTreasury.sol`](./AppTreasury.sol) - Economic calculations
- **Authority**: [`AppAuthority.sol`](./AppAuthority.sol) - Access control
- **Oracle**: Oracle contracts for price feeds and economic data

### External Systems

- **Economic Models**: Economic analysis and modeling systems
- **Price Feeds**: Market price and economic indicator feeds
- **Supply Analytics**: Supply tracking and reporting systems
- **Market Data**: Market condition and volatility data

## Rebase Mechanics

### Rebase Triggers

- **Price Deviation**: Rebase when price deviates from target
- **Time-Based**: Periodic rebases at regular intervals
- **Economic Conditions**: Rebase based on economic indicators
- **Market Volatility**: Rebase during high volatility periods

### Rebase Calculations

- **Supply Elasticity**: Calculate optimal supply adjustment
- **Price Targeting**: Adjust supply to target price
- **Market Impact**: Consider market impact of rebase
- **Economic Equilibrium**: Maintain economic balance

### Supply Adjustment

- **Positive Rebase**: Increase supply (expansion)
- **Negative Rebase**: Decrease supply (contraction)
- **Proportional Adjustment**: Adjust all holder balances proportionally
- **Rebase Distribution**: Distribute rebase across all holders

## Economic Model

### Supply Elasticity

- **Elastic Supply**: Supply adjusts to maintain price stability
- **Economic Equilibrium**: Balance supply and demand
- **Price Targeting**: Target price maintenance
- **Market Stabilization**: Reduce price volatility

### Rebase Impact

- **Holder Balances**: All holder balances adjusted proportionally
- **Price Stability**: Reduced price volatility
- **Economic Balance**: Maintained economic equilibrium
- **Market Efficiency**: Improved market efficiency

### Economic Indicators

- **Price Deviation**: Deviation from target price
- **Market Volatility**: Market volatility measures
- **Supply Demand**: Supply and demand dynamics
- **Economic Health**: Overall economic health indicators

## Security Features

### Access Control

- **Role-Based Permissions**: Only authorized roles can manage rebases
- **Rebase Validation**: Validate all rebase operations
- **Parameter Limits**: Maximum limits on rebase parameters
- **Emergency Controls**: Emergency pause and override capabilities

### Economic Security

- **Rebase Limits**: Maximum rebase amounts to prevent manipulation
- **Timing Controls**: Minimum intervals between rebases
- **Supply Validation**: Validate supply adjustments
- **Overflow Protection**: Safe math operations for all calculations

### Operational Security

- **Rebase Validation**: All rebases validated before execution
- **State Consistency**: Consistent state across all operations
- **Event Logging**: Complete transparency of all operations
- **Emergency Procedures**: Emergency response capabilities

## Usage Examples

### Rebase Operations

#### Calculate Rebase

```solidity
// Calculate if rebase should occur
RebaseController rebaseController = RebaseController(rebaseAddress);

(uint256 rebaseAmount, bool shouldRebase) = rebaseController.calculateRebase();

if (shouldRebase) {
    console.log("Rebase needed, amount:", rebaseAmount);
} else {
    console.log("No rebase needed");
}
```

#### Execute Rebase

```solidity
// Execute rebase operation
rebaseController.executeRebase();
```

#### Emergency Rebase

```solidity
// Execute emergency rebase
rebaseController.emergencyRebase(1000000e18); // 1M RZR
```

### Configuration Management

#### Update Rebase Parameters

```solidity
// Update rebase configuration
rebaseController.setRebaseParameters(
    24 hours,        // Min 24 hours between rebases
    10000000e18,     // Max 10M RZR per rebase
    1e18             // Target $1 price
);
```

#### Check Current Parameters

```solidity
// Get current rebase parameters
(
    uint256 minRebaseInterval,
    uint256 maxRebaseAmount,
    uint256 targetPrice,
    uint256 lastRebaseTime
) = rebaseController.getRebaseParameters();

console.log("Min Interval:", minRebaseInterval);
console.log("Max Amount:", maxRebaseAmount);
console.log("Target Price:", targetPrice);
```

### Supply Analytics

#### Get Supply Information

```solidity
// Get comprehensive supply info
(
    uint256 currentSupply,
    uint256 targetSupply,
    uint256 lastRebaseAmount,
    uint256 totalRebases
) = rebaseController.getSupplyInfo();

console.log("Current Supply:", currentSupply);
console.log("Target Supply:", targetSupply);
console.log("Last Rebase:", lastRebaseAmount);
console.log("Total Rebases:", totalRebases);
```

#### Check Rebase History

```solidity
// Get specific rebase history
(
    uint256 amount,
    uint256 timestamp,
    uint256 supplyBefore,
    uint256 supplyAfter
) = rebaseController.getRebaseHistory(0);

console.log("Rebase Amount:", amount);
console.log("Timestamp:", timestamp);
console.log("Supply Before:", supplyBefore);
console.log("Supply After:", supplyAfter);
```

## Events

### Rebase Events

```solidity
event RebaseExecuted(uint256 amount, uint256 supplyBefore, uint256 supplyAfter, uint256 timestamp);
event EmergencyRebaseExecuted(uint256 amount, string reason, uint256 timestamp);
event RebaseCalculated(uint256 calculatedAmount, bool shouldRebase);
```

### Configuration Events

```solidity
event RebaseParametersUpdated(uint256 minRebaseInterval, uint256 maxRebaseAmount, uint256 targetPrice);
event RebasePaused(bool paused);
event RebaseManagerUpdated(address indexed oldManager, address indexed newManager);
```

### Supply Events

```solidity
event SupplyAdjusted(uint256 oldSupply, uint256 newSupply, uint256 adjustment);
event TargetSupplyUpdated(uint256 oldTarget, uint256 newTarget);
```

## Testing

### Unit Tests

- Rebase calculation accuracy
- Supply adjustment mechanisms
- Parameter management functionality
- Access control validation

### Integration Tests

- Cross-contract rebase flows
- Treasury integration testing
- Oracle price feed integration
- Authority system integration

### Security Tests

- Access control validation
- Economic attack vectors
- Supply manipulation prevention
- Emergency procedure testing

## Deployment Considerations

### Initial Setup

1. **Deploy Contract**: Deploy RebaseController contract
2. **Configure Authority**: Set up access control integration
3. **Set Parameters**: Configure rebase parameters and limits
4. **Verify Integration**: Test with RZR token and treasury

### Configuration

1. **Authority Integration**: Connect to protocol authority system
2. **Rebase Parameters**: Set appropriate rebase intervals and amounts
3. **Economic Targets**: Configure target price and economic indicators
4. **Monitoring Setup**: Implement rebase monitoring

## Dependencies

### Core Dependencies

- **AppAccessControlled**: Protocol access control integration
- **Initializable**: Upgradeable contract pattern
- **RZR Token**: Supply adjustment operations

### External Dependencies

- **Treasury System**: Economic calculations and data
- **Oracle System**: Price feeds and economic indicators
- **Economic Models**: Economic analysis and modeling

## Best Practices

### Rebase Management

1. **Parameter Optimization**: Optimize rebase parameters for stability
2. **Market Impact**: Minimize market disruption from rebases
3. **Economic Balance**: Maintain balanced economic model
4. **Monitoring**: Continuous monitoring of rebase effectiveness

### Security Considerations

1. **Access Control**: Verify rebase permissions are properly restricted
2. **Parameter Limits**: Implement and enforce rebase limits
3. **Supply Validation**: Validate all supply adjustments
4. **Emergency Procedures**: Test emergency response capabilities

### User Experience

1. **Transparency**: Provide clear visibility of rebase operations
2. **Impact Communication**: Communicate rebase impact to users
3. **Balance Updates**: Ensure accurate balance updates
4. **Monitoring Tools**: Provide tools to monitor rebase operations

## Testing

### Unit Tests

- Rebase calculations
- Execution logic
- Parameter management
- History tracking

**Test File**: [`test/foundry/RebaseControllerTest.t.sol`](../../test/foundry/RebaseControllerTest.t.sol)

### Integration Tests

- Protocol contract integration
- Treasury interaction testing
- Supply management validation

### Security Tests

- Unauthorized access attempts
- Access control validation
- Rebase manipulation prevention

## License

AGPL-3.0
