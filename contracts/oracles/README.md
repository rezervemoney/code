# Oracle System

This directory contains the comprehensive oracle infrastructure for the protocol, providing price feeds, cross-chain data synchronization, and reserve tracking across multiple networks. The oracle system is designed to ensure accurate, reliable, and up-to-date information for all protocol operations.

## Overview

The oracle system provides a multi-layered approach to data reliability:

- **Price Feeds**: Real-time pricing for various collateral types and DeFi assets
- **Cross-Chain Data**: Synchronized reserve information across Layer 2 networks
- **Multi-Source Validation**: Combines on-chain and off-chain data sources
- **Standardized Interfaces**: Consistent API for all oracle implementations
- **Security Controls**: Access controls and manipulation resistance mechanisms

## Architecture

### Core Components

The oracle system is organized into two main categories:

1. **[Price Feeds](./pricefeeds/)**: Asset pricing oracles for collateral valuation
2. **[Cross-Chain Oracles](./crosschain/)**: Multi-network data synchronization

### Data Flow

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Price Feeds   │    │  Cross-Chain     │    │   Protocol      │
│   (V2)          │    │  Oracles         │    │   Contracts     │
│                 │    │                  │    │                 │
│ • LP Tokens     │    │ • LayerZero      │    │ • Treasury      │
│ • DeFi Assets   │    │ • Bridge System  │    │ • Staking       │
│ • Yield Tokens  │    │ • Reserve Sync   │    │ • Lending       │
│ • TWAP/Beacon   │    │ • Validation     │    │ • Risk Mgmt     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌────────────────────────┐
                    │   IOracleV2            │
                    │   Interface            │
                    │                        │
                    │ • asset()              │
                    │ • getPriceForAmount()  │
                    └────────────────────────┘
```

## Price Feeds System

### [Price Feeds V2](./pricefeeds/v2/)

The V2 price feeds system provides comprehensive asset pricing through standardized oracle contracts that implement the [`IOracleV2`](../../interfaces/IOracleV2.sol) interface.

**Key Features:**

- **Liquidity Pool Oracles**: Uniswap V2/V3, Balancer, SushiSwap, Curve
- **DeFi Protocol Oracles**: Aave, Euler, ERC4626 vaults
- **Price Manipulation Resistance**: TWAP, capping, and combined mechanisms
- **Flexible Architecture**: Beacon patterns, adapters, and upgradeable implementations

**Supported Asset Types:**

- LP tokens from major DEX protocols
- Yield-bearing tokens and vault shares
- Stable assets and pegged tokens
- Complex DeFi protocol tokens

**Security Considerations:**

- Flash loan attack risks mitigated through access controls
- Only whitelisted addresses can read/update protocol data
- Multi-layered validation and staleness checks

[📖 Read the full Price Feeds V2 documentation →](./pricefeeds/v2/)

## Cross-Chain Oracle System

### [Cross-Chain Oracles](./crosschain/)

The cross-chain oracle system enables real-time synchronization of protocol data across multiple Layer 2 networks using LayerZero infrastructure.

**Key Features:**

- **Multi-Network Support**: Ethereum mainnet and multiple L2 networks
- **LayerZero Integration**: Cross-chain messaging and data transport
- **Dual Data Sources**: On-chain cross-chain data + off-chain oracle updates
- **Deviation Validation**: Ensures data consistency between sources
- **Automatic Synchronization**: Real-time updates via bridge contracts

**Data Synchronization:**

- Reserve tracking across all connected networks
- Staking rate propagation from mainnet to L2s
- Token balance and position monitoring
- Cross-chain liquidity management

**Security Features:**

- Deviation limits (default: 1% tolerance)
- Staleness protection (default: 25 hours)
- Role-based access controls
- Emergency override mechanisms

[📖 Read the full Cross-Chain Oracle documentation →](./crosschain/)

## Core Interfaces

### [IOracleV2](../../interfaces/IOracleV2.sol)

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

**Implementation Requirements:**

- **Asset Identification**: Return the token being priced
- **Dual Pricing**: Provide both RZR and USD denominated values
- **Timestamp Tracking**: Last update time for staleness validation

### Oracle Composition Patterns

The oracle system supports flexible composition patterns:

```solidity
// Chain multiple oracles for complex pricing
BeaconOracle beacon = BeaconOracle(address);
TwapOracleV3 twap = TwapOracleV3(address);
FixedOracle fallback = FixedOracle(address);

// Use beacon for upgradeable pricing
// Fall back to TWAP for manipulation resistance
// Use fixed oracle as last resort
```

### Documentation

- [Price Feeds V2 Documentation](./pricefeeds/v2/)
- [Cross-Chain Oracle Documentation](./crosschain/)
