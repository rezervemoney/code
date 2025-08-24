# AppOracle

**File**: [`AppOracle.sol`](./AppOracle.sol)
**License**: AGPL-3.0

## Overview

The `AppOracle` contract is the core oracle contract for the Rezerve.money protocol. It provides price data management, oracle aggregation, and data validation for various assets, serving as the central hub for all pricing and economic calculations within the protocol.

## Purpose

This contract serves as:

- **Price Data Hub**: Central source for asset pricing information
- **Oracle Aggregation**: Aggregates data from multiple oracle sources
- **Data Validation**: Validates and filters oracle data for accuracy
- **Economic Calculations**: Provides pricing data for protocol operations
- **Oracle Management**: Manages oracle sources and configurations

## Architecture

### Inheritance

- `AppAccessControlled` - Protocol access control integration
- `Initializable` - Upgradeable contract pattern

### Core Components

- **Oracle Registry**: Management of oracle sources and configurations
- **Data Aggregation**: Aggregation of data from multiple sources
- **Validation Logic**: Data validation and staleness checks
- **Price Feeds**: Price feed management and distribution

## Key Functions

### Oracle Management

#### Register Oracle

```solidity
function registerOracle(
    address oracle,
    uint256 weight,
    bool active
) external onlyGovernor
```

**Purpose**: Register a new oracle source with specified weight.

**Access Control**: Only governors can register oracles.

**Parameters**:

- `oracle`: Address of the oracle contract
- `weight`: Weight for this oracle in aggregation
- `active`: Whether the oracle is active

**Process**:

1. Validate oracle address
2. Set oracle weight and status
3. Add to oracle registry
4. Emit oracle registered event

#### Update Oracle Weight

```solidity
function updateOracleWeight(address oracle, uint256 newWeight) external onlyGovernor
```

**Purpose**: Update the weight of a registered oracle.

**Access Control**: Only governors can update oracle weights.

**Parameters**:

- `oracle`: Address of the oracle to update
- `newWeight`: New weight for the oracle

**Process**: Updates oracle weight and emits event.

### Price Data Management

#### Get Asset Price

```solidity
function getAssetPrice(address asset) external view returns (uint256 price, uint256 timestamp)
```

**Purpose**: Get current price for a specific asset.

**Parameters**: `asset` - Address of the asset token.

**Returns**:

- `price`: Current asset price
- `timestamp`: Timestamp of price data

**Process**: Aggregates prices from all active oracles.

#### Get Asset Price with Validation

```solidity
function getValidatedAssetPrice(address asset) external view returns (uint256 price, uint256 timestamp)
```

**Purpose**: Get validated price data with staleness and deviation checks.

**Parameters**: `asset` - Address of the asset token.

**Returns**: Validated price data meeting quality criteria.

**Process**: Applies validation filters to price data.

### Data Validation

#### Check Data Staleness

```solidity
function isDataStale(uint256 timestamp) public view returns (bool)
```

**Purpose**: Check if data is stale based on configured staleness threshold.

**Parameters**: `timestamp` - Timestamp of the data.

**Returns**: `true` if data is stale, `false` otherwise.

**Process**: Compares timestamp with current time and threshold.

#### Validate Price Deviation

```solidity
function validatePriceDeviation(
    uint256 price1,
    uint256 price2,
    uint256 maxDeviation
) public pure returns (bool)
```

**Purpose**: Validate that price deviation is within acceptable limits.

**Parameters**:

- `price1`: First price for comparison
- `price2`: Second price for comparison
- `maxDeviation`: Maximum allowed deviation

**Returns**: `true` if deviation is acceptable, `false` otherwise.

**Process**: Calculates percentage deviation and compares to threshold.

### Oracle Configuration

#### Get Oracle Info

```solidity
function getOracleInfo(address oracle) external view returns (
    uint256 weight,
    bool active,
    uint256 lastUpdate
)
```

**Purpose**: Get information about a registered oracle.

**Parameters**: `oracle` - Address of the oracle.

**Returns**: Oracle weight, active status, and last update time.

#### Get Active Oracles

```solidity
function getActiveOracles() external view returns (address[] memory)
```

**Purpose**: Get list of all active oracle addresses.

**Returns**: Array of active oracle addresses.

## Integration Points

### Protocol Contracts

- **Treasury**: [`AppTreasury.sol`](./AppTreasury.sol) - Reserve calculations
- **Staking**: [`AppStaking.sol`](./AppStaking.sol) - Reward calculations
- **Bonds**: [`AppBondDepository.sol`](./AppBondDepository.sol) - Bond pricing
- **Authority**: [`AppAuthority.sol`](./AppAuthority.sol) - Access control

### External Systems

- **Price Feeds**: Chainlink, Pyth, and other oracle providers
- **DEX Oracles**: Uniswap, Balancer, and other DEX price feeds
- **Custom Oracles**: Protocol-specific oracle implementations
- **Data Aggregators**: External data aggregation services

## Oracle System Architecture

### Multi-Source Aggregation

- **Weighted Averages**: Oracle prices weighted by configured weights
- **Source Diversity**: Multiple oracle sources for redundancy
- **Quality Filtering**: Filter out low-quality or stale data
- **Fallback Mechanisms**: Fallback to reliable sources if needed

### Data Quality Controls

- **Staleness Checks**: Ensure data is recent enough
- **Deviation Limits**: Prevent extreme price movements
- **Source Validation**: Validate oracle source reliability
- **Consistency Checks**: Ensure data consistency across sources

### Configuration Management

- **Dynamic Weights**: Adjustable oracle weights
- **Source Activation**: Enable/disable oracle sources
- **Parameter Updates**: Configurable validation parameters
- **Emergency Controls**: Emergency oracle management

## Security Features

### Access Control

- **Governance Only**: Only governors can manage oracle configuration
- **Oracle Validation**: Validate all oracle addresses and parameters
- **Parameter Limits**: Maximum limits on configuration parameters
- **Emergency Controls**: Emergency pause and override capabilities

### Data Security

- **Source Validation**: Validate all oracle sources
- **Data Filtering**: Filter out invalid or manipulated data
- **Staleness Protection**: Protect against stale data usage
- **Deviation Limits**: Prevent extreme price movements

### Operational Security

- **Oracle Monitoring**: Monitor oracle performance and reliability
- **Data Validation**: Continuous validation of oracle data
- **Event Logging**: Complete transparency of all operations
- **Emergency Procedures**: Emergency response capabilities

## Usage Examples

### Oracle Management

#### Register New Oracle

```solidity
// Register a new Chainlink oracle
AppOracle oracle = AppOracle(oracleAddress);

oracle.registerOracle(
    chainlinkOracleAddress,  // Oracle address
    50,                      // 50% weight
    true                     // Active
);
```

#### Update Oracle Weight

```solidity
// Update oracle weight
oracle.updateOracleWeight(chainlinkOracleAddress, 60);
```

### Price Data Retrieval

#### Get Asset Price

```solidity
// Get current price for USDC
(address asset, uint256 price, uint256 timestamp) = oracle.getAssetPrice(usdcAddress);

console.log("USDC Price:", price);
console.log("Timestamp:", timestamp);
```

#### Get Validated Price

```solidity
// Get validated price data
(uint256 price, uint256 timestamp) = oracle.getValidatedAssetPrice(assetAddress);

if (price > 0) {
    console.log("Valid Price:", price);
} else {
    console.log("No valid price available");
}
```

### Oracle Information

#### Check Oracle Status

```solidity
// Get oracle information
(
    uint256 weight,
    bool active,
    uint256 lastUpdate
) = oracle.getOracleInfo(chainlinkOracleAddress);

console.log("Oracle Weight:", weight);
console.log("Oracle Active:", active);
console.log("Last Update:", lastUpdate);
```

#### Get Active Oracles

```solidity
// Get all active oracles
address[] memory activeOracles = oracle.getActiveOracles();
console.log("Active Oracle Count:", activeOracles.length);

for (uint i = 0; i < activeOracles.length; i++) {
    console.log("Oracle", i, ":", activeOracles[i]);
}
```

### Data Validation

#### Check Data Staleness

```solidity
// Check if data is stale
bool isStale = oracle.isDataStale(timestamp);
if (isStale) {
    console.log("Data is stale, consider refreshing");
}
```

#### Validate Price Deviation

```solidity
// Validate price deviation
bool isValid = oracle.validatePriceDeviation(
    oldPrice,
    newPrice,
    maxDeviation
);

if (!isValid) {
    console.log("Price deviation too high");
}
```

## Events

### Oracle Management Events

```solidity
event OracleRegistered(address indexed oracle, uint256 weight, bool active);
event OracleWeightUpdated(address indexed oracle, uint256 oldWeight, uint256 newWeight);
event OracleStatusUpdated(address indexed oracle, bool active);
```

### Data Events

```solidity
event PriceUpdated(address indexed asset, uint256 price, uint256 timestamp);
event DataValidationFailed(address indexed asset, string reason);
```

### Configuration Events

```solidity
event StalenessThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
event MaxDeviationUpdated(uint256 oldDeviation, uint256 newDeviation);
```

## Testing

### Unit Tests

- Oracle registration and management functionality
- Price aggregation and validation
- Data quality control mechanisms
- Access control validation

### Integration Tests

- Cross-contract price data flows
- Oracle source integration testing
- Treasury and staking integration
- Authority system integration

### Security Tests

- Access control validation
- Data manipulation prevention
- Oracle source validation
- Emergency procedure testing

## Deployment Considerations

### Initial Setup

1. **Deploy Contract**: Deploy AppOracle contract
2. **Configure Authority**: Set up access control integration
3. **Register Oracles**: Register initial oracle sources
4. **Verify Functionality**: Test oracle data retrieval

### Configuration

1. **Authority Integration**: Connect to governance system
2. **Oracle Sources**: Set up reliable oracle sources
3. **Validation Parameters**: Configure validation thresholds
4. **Monitoring Setup**: Implement oracle monitoring

## Dependencies

### Core Dependencies

- **AppAccessControlled**: Protocol access control integration
- **Initializable**: Upgradeable contract pattern
- **Oracle Sources**: External oracle contracts and services

### External Dependencies

- **Price Feed Protocols**: Chainlink, Pyth, and other oracles
- **DEX Integration**: Uniswap, Balancer price feeds
- **Data Aggregation**: External data aggregation services

## Best Practices

### Oracle Management

1. **Source Diversity**: Use multiple oracle sources for redundancy
2. **Quality Monitoring**: Monitor oracle performance and reliability
3. **Weight Optimization**: Optimize oracle weights for accuracy
4. **Regular Updates**: Keep oracle configurations current

### Security Considerations

1. **Access Control**: Verify oracle management permissions
2. **Source Validation**: Validate all oracle sources
3. **Data Quality**: Implement robust data validation
4. **Emergency Procedures**: Test emergency response capabilities

### User Experience

1. **Price Transparency**: Provide clear price data access
2. **Data Quality**: Ensure high-quality price data
3. **Update Frequency**: Maintain frequent price updates
4. **Monitoring Tools**: Provide tools to monitor oracle health

## License

AGPL-3.0
