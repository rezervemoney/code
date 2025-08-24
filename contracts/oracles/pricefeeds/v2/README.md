# Price Feeds V2 Oracle Contracts

This directory contains a comprehensive collection of oracle contracts that provide price data for various collateral types in the protocol. These oracles implement the [`IOracleV2`](../../../interfaces/IOracleV2.sol) interface to standardize how collateral values are calculated and reported.

## Overview

The V2 oracle system provides standardized price feeds for:

- **Liquidity Pool Tokens**: Uniswap V2/V3, Balancer, SushiSwap, and Curve LP tokens
- **DeFi Protocol Tokens**: Aave, Euler, and other lending protocol tokens
- **Stable Assets**: Fixed-price oracles for stablecoins and pegged assets
- **Time-Weighted Prices**: TWAP oracles for price manipulation resistance
- **Adapter Patterns**: Flexible oracle routing and beacon implementations

## Core Interface

### [IOracleV2](../../../interfaces/IOracleV2.sol)

**Standard interface for all V2 oracle contracts**

```solidity
interface IOracleV2 {
    function asset() external view returns (IERC20Metadata);
    function getPriceForAmount(uint256 amount) external view returns (
        uint256 rzrAssets,
        uint256 usdAssets,
        uint256 lastUpdatedAt
    );
}
```

All oracles must implement this interface to provide:

- **Asset Identification**: The token being priced
- **Dual Pricing**: Both RZR and USD denominated values
- **Timestamp Tracking**: Last update time for staleness checks

## Oracle Categories

### 1. Liquidity Pool Oracles

#### [UniV2LPOracle.sol](./UniV2LPOracle.sol)

**Uniswap V2 LP token pricing**

- Calculates proportional token amounts in LP position
- Aggregates RZR and USD values from underlying tokens
- Uses app oracle for individual token pricing

#### [UniV4LPPosOracle.sol](./UniV4LPPosOracle.sol)

**Uniswap V4 concentrated liquidity position pricing**

- Handles concentrated liquidity ranges
- Calculates position value based on current price
- Aggregates underlying token values

#### [BalancerLPOracle.sol](./BalancerLPOracle.sol)

**Balancer weighted pool LP token pricing**

- Supports variable weight pools
- Calculates proportional token allocations
- Aggregates multi-token values

#### [SushiV3LPPosOracle.sol](./SushiV3LPPosOracle.sol)

**SushiSwap V3 concentrated liquidity pricing**

- Similar to Uniswap V4 but for SushiSwap
- Handles range-based liquidity positions
- Aggregates underlying token values

#### [CurveTriCryptoOracle.sol](./CurveTriCryptoOracle.sol)

**Curve TriCrypto pool LP token pricing**

- Supports 3-token pools (e.g., USDT, WBTC, ETH)
- Calculates proportional token amounts
- Aggregates values from all pool tokens

### 2. DeFi Protocol Oracles

#### [AaveAdapterOracle.sol](./AaveAdapterOracle.sol)

**Aave lending protocol token pricing**

- Prices aToken, vToken, and sToken variants
- Calculates underlying asset value plus accrued interest
- Handles Aave's interest-bearing token mechanics

#### [Euler4626Oracle.sol](./Euler4626Oracle.sol)

**Euler Finance ERC4626 vault pricing**

- Prices Euler's yield-bearing vault tokens
- Calculates underlying asset value plus yield
- Supports Euler's risk-adjusted lending model

#### [Adapter4626Oracle.sol](./Adapter4626Oracle.sol)

**Generic ERC4626 vault adapter**

- Universal adapter for ERC4626 compliant vaults
- Calculates share-to-asset conversion ratios
- Supports any ERC4626 yield-bearing token

### 3. Price Manipulation Resistance

#### [TwapOracleV3.sol](./TwapOracleV3.sol)

**Time-Weighted Average Price oracle**

- Uses circular buffer for price observations
- Calculates TWAP over configurable time window
- Resistant to short-term price manipulation
- Configurable update frequency and observation count

#### [CappedOracle.sol](./CappedOracle.sol)

**Price movement capping oracle**

- Limits maximum price change between updates
- Prevents extreme price swings
- Configurable cap thresholds

#### [AverageCappedOracle.sol](./AverageCappedOracle.sol)

**Combined TWAP and capping oracle**

- Combines time-weighted averaging with price caps
- Maximum protection against manipulation
- Configurable parameters for both mechanisms

### 4. Utility and Adapter Oracles

#### [BeaconOracle.sol](./BeaconOracle.sol)

**Upgradeable oracle beacon pattern**

- Allows oracle implementation updates
- Maintains consistent interface address
- Governance-controlled oracle upgrades

#### [FixedOracle.sol](./FixedOracle.sol)

**Static price oracle**

- Fixed RZR and USD prices
- Useful for stable assets and pegged tokens
- Manual price updates by governance

#### [ManualOracleE18.sol](./ManualOracleE18.sol)

**Manually updated price oracle**

- Governance-controlled price updates
- E18 precision for accurate pricing
- Emergency price override capability

#### [ShadowLPOracle.sol](./ShadowLP.sol)

**Shadow LP token pricing**

- Handles special LP token types
- Calculates shadow pool values
- Supports complex LP mechanics

## Price Calculation Patterns

### LP Token Pricing

```solidity
// Calculate proportional token amounts
uint256 amountA = balanceA * amount / totalSupply;
uint256 amountB = balanceB * amount / totalSupply;

// Get individual token prices via [AppOracle](../../../core/AppOracle.sol)
(uint256 rzrA, uint256 usdA,) = appOracle.getPriceForAmount(tokenA, amountA);
(uint256 rzrB, uint256 usdB,) = appOracle.getPriceForAmount(tokenB, amountB);

// Aggregate total values
rzrAssets = rzrA + rzrB;
usdAssets = usdA + usdB;
```

### Yield Token Pricing

```solidity
// Calculate underlying asset value via [AppOracle](../../../core/AppOracle.sol)
uint256 underlyingAmount = convertToAssets(shares);
(uint256 rzrValue, uint256 usdValue,) = appOracle.getPriceForAmount(underlying, underlyingAmount);

// Add accrued yield if applicable
rzrAssets = rzrValue + yieldRzr;
usdAssets = usdValue + yieldUsd;
```

### TWAP Calculation

```solidity
// Circular buffer implementation
uint256 idToReplace = (_lastEpochId + 1) % _maxObservations;
twapPriceUsd = twapPriceUsd - _observations[idToReplace].priceUsd + priceUsd;
twapPriceRzr = twapPriceRzr - _observations[idToReplace].priceRzr + priceRzr;
```

## Security Considerations

### Flash Loan Attack Resistance

**Important**: These oracles are **not resistant to flash loan attacks** by design. However, the risk is mitigated because:

- **Whitelisted Access**: Only authorized addresses can read/update protocol data
- **Access Control**: Protocol functions require specific roles and permissions
- **Rate Limiting**: Update frequency controls prevent rapid manipulation
- **Multi-Source Validation**: Cross-referencing with other data sources

### Security Features

- **Staleness Checks**: Reject outdated price data
- **Price Validation**: Ensure prices are within reasonable bounds
- **Access Controls**: Role-based permissions for updates
- **Event Logging**: Full transparency of price changes

## Integration Patterns

### Oracle Composition

```solidity
// Chain multiple oracles for complex pricing
BeaconOracle beacon = BeaconOracle(address);
TwapOracleV3 twap = TwapOracleV3(address);
FixedOracle fallback = FixedOracle(address);

// Use beacon for upgradeable pricing
// Fall back to TWAP for manipulation resistance
// Use fixed oracle as last resort
```

### App Oracle Integration

```solidity
// Most LP oracles use the app oracle for underlying token pricing
[IAppOracle](../../../interfaces/IAppOracle.sol) public immutable appOracle;

// Get individual token prices
(uint256 rzrAmount, uint256 usdAmount,) = appOracle.getPriceForAmount(token, amount);
```

## Usage Examples

### Querying LP Token Value

```solidity
// Get value of 1000 LP tokens
(uint256 rzrValue, uint256 usdValue, uint256 lastUpdate) =
    uniV2Oracle.getPriceForAmount(1000e18);
```

### Updating TWAP Oracle

```solidity
// Update TWAP observations (executor only)
twapOracle.update();
```

### Changing Oracle Beacon

```solidity
// Update beacon implementation (owner only)
beaconOracle.setBeacon(newOracle);
```

## Deployment Considerations

### Oracle Dependencies

- **App Oracle**: Required for underlying token pricing
- **Protocol Contracts**: LP pools, vaults, and other DeFi protocols
- **Access Control**: Authority contracts for role management

### Configuration Parameters

- **Update Frequencies**: TWAP observation intervals
- **Price Caps**: Maximum allowed price movements
- **Staleness Thresholds**: Data freshness requirements
- **Observation Counts**: TWAP calculation windows

## Monitoring and Events

### Key Events

- `BeaconUpdated`: Oracle implementation changes
- `ObservationAdded`: TWAP price observations
- `TwapUpdated`: TWAP price recalculations
- `PriceUpdated`: Manual price changes

### Health Monitoring

- **Price Staleness**: Monitor last update timestamps
- **Price Deviations**: Track price changes between updates
- **Oracle Availability**: Ensure oracles are responding
- **Update Frequency**: Monitor TWAP observation rates

## Dependencies

- **[IOracleV2](../../../interfaces/IOracleV2.sol)**: Core oracle interface
- **[IAppOracle](../../../interfaces/IAppOracle.sol)**: App-level oracle interface
- **DeFi Protocols**: Uniswap, Balancer, Curve, Aave, Euler
- **OpenZeppelin**: Access control and utility libraries

## License

MIT (most contracts)
