# AppOracle

**File**: [`AppOracle.sol`](./AppOracle.sol)

**License**: AGPL-3.0

**Test File**: [`test/foundry/AppOracleTest.t.sol`](../../test/foundry/AppOracleTest.t.sol)

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

- **Oracle Registry**: Mapping of tokens to their oracle contracts
- **Staleness Management**: Configurable staleness thresholds per token
- **Price Validation**: Automatic staleness checking for all price queries
- **Floor Price System**: RZR token floor price management
- **Dual Pricing**: Support for both RZR and USD denominated prices

## Key Functions

### Oracle Management

#### Update Oracle

```solidity
function updateOracle(address _token, address _oracle, uint256 _maxStaleness) external onlyGovernor
```

**Purpose**: Update or register an oracle for a specific token.

**Access Control**: Only governors can update oracles.

**Parameters**:

- `_token`: Address of the token
- `_oracle`: Address of the oracle contract
- `_maxStaleness`: Maximum staleness threshold for the oracle

**Process**:

1. Validate token and oracle addresses
2. Set oracle for the token
3. Configure staleness threshold
4. Validate oracle price data
5. Emit oracle updated event

### Price Data Management

#### Get Price

```solidity
function getPrice(address token) public view returns (uint256 rzrAmount, uint256 usdAmount, uint256 lastUpdatedAt)
```

**Purpose**: Get current price for a specific token (1e18 amount).

**Parameters**: `token` - Address of the token.

**Returns**:

- `rzrAmount`: Price in RZR terms
- `usdAmount`: Price in USD terms
- `lastUpdatedAt`: Timestamp of price data

**Process**: Retrieves price from registered oracle for 1e18 token amount.

#### Get Price for Amount

```solidity
function getPriceForAmount(address token, uint256 amount) public view returns (uint256 rzrAmount, uint256 usdAmount, uint256 lastUpdatedAt)
```

**Purpose**: Get price for a specific token amount.

**Parameters**:

- `token` - Address of the token
- `amount` - Amount of tokens to price

**Returns**: Price data for the specified amount.

**Process**: Retrieves price from registered oracle and validates staleness.

#### Get Price in USD

```solidity
function getPriceUsd(address token) external view returns (uint256 usdAmount)
```

**Purpose**: Get USD price for a token.

**Parameters**: `token` - Address of the token.

**Returns**: USD price of the token.

#### Get Price in RZR

```solidity
function getPriceRzr(address token) external view returns (uint256 rzrAmount)
```

**Purpose**: Get RZR price for a token.

**Parameters**: `token` - Address of the token.

**Returns**: RZR price of the token.

### Floor Price Management

#### Get Token Price

```solidity
function getTokenPrice() external view returns (uint256)
```

**Purpose**: Get the current floor price for RZR tokens.

**Returns**: Floor price in USD with 18 decimals.

#### Set Token Price

```solidity
function setTokenPrice(uint256 newFloorPrice) external onlyPolicy
```

**Purpose**: Update the floor price for RZR tokens.

**Access Control**: Only policy role members can update floor price.

**Parameters**: `newFloorPrice` - New floor price (must be >= current price).

**Process**: Updates floor price and emits event.

### Floor-Adjusted Pricing

#### Get Price for Amount in Floor

```solidity
function getPriceForAmountInFloor(address token, uint256 amount) external view returns (uint256 rzrAmount, uint256 usdAmount, uint256 lastUpdatedAt)
```

**Purpose**: Get price data adjusted by the floor price.

**Parameters**:

- `token` - Address of the token
- `amount` - Amount of tokens to price

**Returns**: Floor-adjusted price data.

**Process**: Gets base price and adjusts USD amount by floor price ratio.

## Integration Points

### Protocol Contracts

- **Treasury**: [`AppTreasury.sol`](./AppTreasury.sol) - Reserve calculations
- **Staking**: [`AppStaking.sol`](./AppStaking.sol) - Reward calculations
- **Bonds**: [`AppBondDepository.sol`](./AppBondDepository.sol) - Bond pricing
- **Authority**: [`AppAuthority.sol`](./AppAuthority.sol) - Access control

### External Systems

- **Oracle Contracts**: IOracleV2 compliant oracle implementations
- **Token Contracts**: IERC20Metadata compliant tokens
- **Price Feeds**: Chainlink, Pyth, and other oracle providers
- **DEX Oracles**: Uniswap, Balancer, and other DEX price feeds

### Oracle Management

#### Update Oracle for Token

```solidity
// Update oracle for USDC token
AppOracle oracle = AppOracle(oracleAddress);

oracle.updateOracle(
    usdcAddress,           // Token address
    chainlinkOracleAddress, // Oracle address
    1 hours                // Max staleness threshold
);
```

### Price Data Retrieval

#### Get Token Price

```solidity
// Get current price for USDC (1e18 amount)
(uint256 rzrAmount, uint256 usdAmount, uint256 timestamp) = oracle.getPrice(usdcAddress);

console.log("USDC RZR Price:", rzrAmount);
console.log("USDC USD Price:", usdAmount);
console.log("Timestamp:", timestamp);
```

#### Get Price for Specific Amount

```solidity
// Get price for 1000 USDC tokens
(uint256 rzrAmount, uint256 usdAmount, uint256 timestamp) = oracle.getPriceForAmount(usdcAddress, 1000e6);

console.log("1000 USDC RZR Value:", rzrAmount);
console.log("1000 USDC USD Value:", usdAmount);
```

#### Get USD Price Only

```solidity
// Get USD price for USDC
uint256 usdPrice = oracle.getPriceUsd(usdcAddress);
console.log("USDC USD Price:", usdPrice);
```

#### Get RZR Price Only

```solidity
// Get RZR price for USDC
uint256 rzrPrice = oracle.getPriceRzr(usdcAddress);
console.log("USDC RZR Price:", rzrPrice);
```

### Floor Price Management

#### Get Current Floor Price

```solidity
// Get current RZR floor price
uint256 floorPrice = oracle.getTokenPrice();
console.log("RZR Floor Price:", floorPrice);
```

#### Update Floor Price

```solidity
// Update floor price (only policy role)
oracle.setTokenPrice(newFloorPrice);
```

### Floor-Adjusted Pricing

#### Get Floor-Adjusted Price

```solidity
// Get floor-adjusted price data
(uint256 rzrAmount, uint256 usdAmount, uint256 timestamp) = oracle.getPriceForAmountInFloor(usdcAddress, 1000e6);

console.log("Floor-Adjusted USD Value:", usdAmount);
```

## License

AGPL-3.0
