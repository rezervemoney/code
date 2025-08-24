# Cross-Chain Oracle Contracts

This directory contains smart contracts that provide cross-chain data aggregation and validation for the protocol. The primary contract, `TotalReservesOracle`, serves as a decentralized oracle that captures reserve information from multiple Layer 2 networks and off-chain sources, ensuring data consistency and reliability across the entire ecosystem.

## Overview

The cross-chain oracle system provides a robust mechanism for:

- **Multi-Source Data Aggregation**: Combining on-chain and off-chain reserve data
- **Cross-Chain Synchronization**: Real-time updates from Layer 2 networks via LayerZero
- **Deviation Validation**: Ensuring data consistency between different sources
- **Fallback Mechanisms**: Redundant data sources to prevent single points of failure
- **Governance Controls**: Configurable parameters for oracle behavior and security

## Contract Architecture

### TotalReservesOracle.sol

**Central oracle contract that aggregates and validates reserve data from multiple sources**

- **Dual Data Sources**: Combines on-chain cross-chain data with off-chain oracle updates
- **Deviation Checking**: Validates that off-chain data stays within acceptable bounds
- **Chain Management**: Tracks reserves across multiple Layer 2 networks
- **Staleness Protection**: Ensures data freshness with configurable timeouts
- **Credit System**: Supports additional reserve credits for protocol operations

## Data Sources

### 1. Cross-Chain Reserves (LayerZero)

```
L2 Chain → BridgeL2 → LayerZero → BridgeL1 → TotalReservesOracle
```

- **Source**: Bridge contracts on various Layer 2 networks
- **Transport**: LayerZero cross-chain messaging infrastructure
- **Update Mechanism**: Automatic updates when bridge contracts sync reserves
- **Data Format**: RZR and USD reserve amounts with timestamp
- **Access Control**: Only registered bridge contracts can update

### 2. Off-Chain Oracle

```
Off-Chain Oracle → TotalReservesOracle
```

- **Source**: External oracle service or server-side aggregation
- **Update Mechanism**: Manual updates by authorized updater or executor
- **Data Format**: RZR and USD reserve amounts with timestamp
- **Fallback**: Provides redundancy and additional data validation

## Key Components

### Chain Reserves Tracking

```solidity
struct ChainReserves {
    uint256 rzrReserves;      // RZR token reserves on the chain
    uint256 usdReserves;      // USD value of reserves on the chain
    uint256 lastUpdatedAt;    // Timestamp of last update
}

mapping(uint256 eid => ChainReserves) public crosschainReserves;
```

- **EID Mapping**: Maps LayerZero endpoint IDs to chain-specific reserve data
- **Dynamic Chain Support**: Chains can be added/removed by governance
- **Timestamp Validation**: Ensures data freshness across all chains

### Deviation Validation

```solidity
uint256 public maxDeviation; // 1% = 0.01e18 (100 basis points)
```

The oracle implements strict deviation checking to prevent data manipulation:

- **RZR Reserves**: Off-chain data must be within ±1% of on-chain total
- **USD Reserves**: Off-chain data must be within ±1% of on-chain total
- **Configurable**: Deviation threshold can be adjusted by governance
- **Fail-Safe**: Transactions revert if deviation exceeds threshold

### Staleness Protection

```solidity
uint256 public staleness; // 25 hours default
```

- **Data Freshness**: All data sources must be updated within staleness period
- **Automatic Rejection**: Stale data causes transaction failures
- **Configurable Timeout**: Staleness period adjustable by governance
- **Cross-Chain Consistency**: Applies to both individual chains and off-chain data

## Data Flow and Synchronization

### Cross-Chain Reserve Updates

1. **BridgeL1** receives reserve data from L2 chains via LayerZero
2. **BridgeL1** calls `setCrosschainReserves()` on TotalReservesOracle
3. **Oracle** updates the specific chain's reserve data and timestamp
4. **Event** emitted for monitoring and indexing

### Off-Chain Oracle Updates

1. **Authorized Updater** calls `updateReservesOffchain()`
2. **Oracle** validates caller permissions (updater or executor)
3. **Data** updated with current timestamp
4. **Event** emitted for transparency

### Reserve Aggregation

1. **On-Chain Aggregation**: Sums reserves across all registered L2 chains
2. **Deviation Check**: Validates off-chain data against on-chain total
3. **Credit Addition**: Adds protocol reserve credits
4. **Final Total**: Returns validated total reserves

## Access Control and Security

### Role-Based Permissions

- **Governor**: Chain management, parameter configuration, emergency overrides
- **Bridge**: Cross-chain reserve updates (automated via LayerZero)
- **Off-Chain Updater**: Manual reserve updates (server-side oracle)
- **Executor**: Emergency off-chain updates (fallback mechanism)

### Security Features

- **Deviation Limits**: Prevents significant data manipulation
- **Staleness Checks**: Ensures data freshness and reliability
- **Access Controls**: Restricted update permissions
- **Event Logging**: Full transparency of all data changes
- **Emergency Overrides**: Governance can force updates if needed

## Configuration Parameters

### Oracle Behavior

```solidity
function setMaxDeviation(uint256 _maxDeviation) external onlyGovernor
function setStaleness(uint256 _staleness) external onlyGovernor
```

- **Max Deviation**: Acceptable difference between data sources (default: 1%)
- **Staleness Period**: Maximum age of data before rejection (default: 25 hours)

### Chain Management

```solidity
function toggleEid(uint256 eid) external onlyGovernor
function overwriteCrosschainReserves(uint256 eid, uint256 _rzrReserves, uint256 _usdReserves) external onlyGovernor
```

- **Chain Toggle**: Enable/disable specific Layer 2 networks
- **Manual Override**: Force update reserves for specific chain (emergency use)

### Reserve Credits

```solidity
function setReservesCreditUsd(uint256 _reservesCreditUsd) external onlyGovernor
function setReservesCreditRzr(uint256 _reservesCreditRzr) external onlyGovernor
```

- **Protocol Credits**: Additional reserves not captured by cross-chain data
- **Flexibility**: Supports various protocol operations and accounting needs

## Integration with Bridge System

### Automatic Updates

The oracle automatically receives updates from the bridge system:

- **BridgeL1** calls `setCrosschainReserves()` after LayerZero message receipt
- **Real-time Sync**: Reserve data stays current across all networks
- **Event Emission**: All updates logged for monitoring and transparency

### Data Validation

```solidity
function getTotalReserves() external view returns (uint256 _rzrReserves, uint256 _usdReserves)
```

This function provides the validated total reserves:

1. Aggregates on-chain reserves from all L2 networks
2. Validates off-chain data against on-chain total
3. Applies deviation checks to ensure data integrity
4. Adds protocol reserve credits
5. Returns final validated totals

## Monitoring and Events

### Key Events

- `CrosschainReservesUpdated`: Cross-chain reserve updates
- `ReservesOffchainUpdated`: Off-chain oracle updates
- `OffchainUpdaterUpdated`: Updater address changes
- `ReservesCreditUsdUpdated`: USD credit adjustments
- `ReservesCreditRzrUpdated`: RZR credit adjustments

### Health Monitoring

- **Data Freshness**: Monitor timestamp of last updates
- **Deviation Tracking**: Track differences between data sources
- **Chain Coverage**: Ensure all expected chains are reporting
- **Update Frequency**: Monitor cross-chain sync performance

## Usage Examples

### Querying Total Reserves

```solidity
// Get validated total reserves across all sources
(uint256 rzrTotal, uint256 usdTotal) = oracle.getTotalReserves();
```

### Checking Specific Chain Reserves

```solidity
// Get reserves for specific Layer 2 network
(uint256 rzrReserves, uint256 usdReserves) = oracle.getCrosschainReserves(chainEid);
```

### Monitoring Cross-Chain Coverage

```solidity
// Get list of all supported chain EIDs
uint256[] memory supportedChains = oracle.getEids();
```

## Deployment and Configuration

### Initial Setup

1. Deploy `TotalReservesOracle` contract
2. Initialize with authority and off-chain updater addresses
3. Configure initial deviation and staleness parameters
4. Register supported Layer 2 networks

### Bridge Integration

1. Ensure bridge contracts have `BRIDGE` role
2. Configure LayerZero endpoint IDs for each chain
3. Test cross-chain message delivery
4. Monitor automatic reserve synchronization

### Off-Chain Oracle Setup

1. Configure authorized updater address
2. Set up automated update mechanism
3. Implement deviation monitoring
4. Establish fallback update procedures

## Dependencies

- **LayerZero**: Cross-chain messaging infrastructure
- **Bridge Contracts**: Source of cross-chain reserve data
- **App Protocol**: Core access control and governance
- **OpenZeppelin**: Utility libraries and data structures
