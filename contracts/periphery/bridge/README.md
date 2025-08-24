# Bridge Contracts

This directory contains smart contracts that enable cross-chain data synchronization between Ethereum mainnet and various Layer 2 networks using LayerZero's cross-chain messaging infrastructure. These contracts facilitate the exchange of critical protocol information such as reserves, staking rates, and token balances.

## Overview

The bridge contracts establish a decentralized cross-chain communication network that allows:

- **Data Synchronization**: Real-time syncing of protocol metrics across chains
- **Rate Propagation**: Distribution of staking rates from mainnet to L2s
- **Reserve Tracking**: Monitoring of treasury reserves across all connected networks
- **Token Bridging**: Cross-chain transfer of RZR and lstRZR tokens

## Contract Architecture

### BridgeL1.sol

**Mainnet bridge contract that coordinates cross-chain data synchronization**

- **LayerZero Integration**: Inherits from `OAppRead` for cross-chain read operations
- **Bridge Registry**: Maintains mapping of L2 chain IDs to their bridge contracts
- **Reserve Synchronization**: Syncs mainnet reserves and distributes them to L2s
- **Cross-Chain Reads**: Initiates read requests to L2 chains for reserve data
- **Key Functions**:
  - `registerBridges()`: Registers L2 bridge contracts for specific chain IDs
  - `syncMainnetReserves()`: Updates mainnet reserves in the oracle
  - `syncL2Reserves()`: Requests reserve data from specific L2 chains
  - `flushRZR()`: Converts RZR to lstRZR and bridges to L2s
  - `_lzReceive()`: Processes incoming data from L2 chains

### BridgeL2.sol

**Layer 2 bridge contract that responds to mainnet read requests**

- **Bidirectional Communication**: Receives read requests and sends rate updates
- **Rate Synchronization**: Syncs staking rates from mainnet liquid staking contract
- **Data Exposure**: Provides local chain data (reserves, chain ID) to mainnet
- **Token Bridging**: Enables RZR tokens to be sent back to mainnet
- **Key Functions**:
  - `syncRate()`: Requests current staking rate from mainnet
  - `flushToL1()`: Bridges RZR tokens back to mainnet
  - `data()`: Returns local chain reserves and chain ID
  - `_lzReceive()`: Processes rate updates from mainnet

### Staking4626L2.sol

**ERC4626-compliant liquid staking vault for Layer 2 networks**

- **Cross-Chain Staking**: Allows users to stake RZR tokens on L2s
- **Rate Synchronization**: Receives and applies staking rates from mainnet
- **Fee Collection**: Implements deposit fees to incentivize the bridge
- **OFT Integration**: Inherits from `OFTProxy` for cross-chain token transfers
- **Key Functions**:
  - `setRate()`: Updates staking rate (only callable by bridge or governor)
  - `deposit()`: Accepts RZR deposits and mints lstRZR shares
  - `convertToAssets()`: Converts shares to underlying assets using current rate
  - `convertToShares()`: Converts assets to shares using current rate

## Cross-Chain Data Flow

### Reserve Synchronization

```
L2 Chain → BridgeL2 → LayerZero → BridgeL1 → TotalReservesOracle
```

1. **BridgeL1** initiates a read request to **BridgeL2** on target L2
2. **BridgeL2** calls `data()` function to get local reserves
3. **LayerZero** transports the data back to mainnet
4. **BridgeL1** receives data and updates the oracle

### Rate Synchronization

```
Mainnet Liquid Staking → BridgeL2 → LayerZero → BridgeL1 → Staking4626L2
```

1. **BridgeL2** requests current staking rate from mainnet
2. **LayerZero** transports the rate data to L2
3. **BridgeL2** receives rate and updates **Staking4626L2**

### Token Bridging

```
L2 Staking4626L2 → BridgeL2 → LayerZero → BridgeL1 → Mainnet lstRZR
```

1. Users deposit RZR in **Staking4626L2** on L2
2. **BridgeL2** bridges accumulated RZR back to mainnet
3. **BridgeL1** converts RZR to lstRZR and distributes

## LayerZero Integration

### Read Channels

- **READ_CHANNEL**: Dedicated channel for cross-chain read operations
- **READ_TYPE**: Message type identifier for read requests
- **EVMCallRequestV1**: Standardized structure for cross-chain function calls

### Message Flow

```solidity
// Building read commands
EVMCallRequestV1[] memory readRequests = new EVMCallRequestV1[](1);
readRequests[0] = EVMCallRequestV1({
    appRequestLabel: 1,
    targetEid: _eid,
    isBlockNum: false,
    blockNumOrTimestamp: uint64(block.timestamp),
    confirmations: 5,
    to: _targetContractAddress,
    callData: callData
});
```

## Security Features

- **Access Control**: Role-based permissions for all critical functions
- **Bridge Registration**: Only registered L2 bridges can communicate
- **Rate Validation**: Staking rates can only increase (no rate manipulation)
- **Fee Limits**: Deposit fees capped at 10% maximum
- **Ownership Controls**: Governor-only access to bridge registration and configuration

## Usage Patterns

### Registering New L2 Bridge

```solidity
// Only callable by governor
bridgeL1.registerBridges(
    [chainId1, chainId2],
    [bridgeAddress1, bridgeAddress2]
);
```

### Syncing L2 Reserves

```solidity
// Executor can sync reserves from specific L2
uint256 fee = bridgeL1.quoteReadFee(chainId, "");
bridgeL1.syncL2Reserves{value: fee}(chainId, "");
```

### Updating Staking Rate on L2

```solidity
// Bridge automatically syncs rate from mainnet
bridgeL2.syncRate{value: fee}("");
```

## Dependencies

- **LayerZero**: Cross-chain messaging infrastructure
- **OFT Protocol**: Cross-chain token transfer standard
- **ERC4626**: Standard for tokenized vaults
- **App Protocol**: Core protocol contracts and access control

## Deployment Considerations

### Contract Deployment Order

1. Deploy **Staking4626L2** on each L2 network
2. Deploy **BridgeL2** on each L2 network
3. Deploy **BridgeL1** on mainnet
4. Register L2 bridges in **BridgeL1**
5. Configure read channels and peers

### Required Addresses

- LayerZero endpoint addresses for each chain
- Treasury contracts on each network
- Liquid staking contracts (mainnet and L2)
- RZR token addresses (OFT-compliant)
- Protocol authority contracts

### Network Configuration

- **Mainnet EID**: 30101 (Ethereum)
- **L2 EIDs**: Varies by network (Arbitrum, Base, etc.)
- **Read Channels**: Unique channel IDs for each bridge pair
- **Confirmation Blocks**: 5 blocks for data finality

## Monitoring and Events

### Key Events

- `BridgeRegistered`: New L2 bridge registration
- `StateReceived`: Cross-chain data reception
- `RateUpdated`: Staking rate changes on L2
- `DepositFeeCollected`: Fee collection from deposits

### Health Checks

- Monitor cross-chain message delivery
- Track reserve synchronization frequency
- Verify rate propagation accuracy
- Check bridge contract balances
