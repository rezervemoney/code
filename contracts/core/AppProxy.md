# AppProxy

**File**: [`AppProxy.sol`](./AppProxy.sol)

**License**: AGPL-3.0

## Overview

The `AppProxy` contract is an upgradeable proxy contract that enables the Rezerve.money protocol to upgrade core contract implementations while preserving user data and state. It implements the proxy pattern to separate storage from logic, allowing for seamless contract upgrades.

## Purpose

This contract serves as:

- **Upgradeable Infrastructure**: Enables contract upgrades without data migration
- **Storage Separation**: Separates contract logic from storage
- **State Preservation**: Maintains user data across contract upgrades
- **Governance Control**: Controlled upgrades through governance system
- **Backward Compatibility**: Ensures protocol continuity during upgrades

## Key Functions

### Proxy Operations

#### Fallback Function

```solidity
fallback() external payable
```

**Purpose**: Routes all function calls to the current implementation contract.

**Process**:

1. Receives function call data
2. Delegates call to current implementation
3. Returns result from implementation
4. Handles any revert conditions

#### Receive Function

```solidity
receive() external payable
```

**Purpose**: Handles direct ETH transfers to the proxy contract.

**Process**: Accepts ETH and forwards to implementation if needed.

### Implementation Management

#### Get Implementation

```solidity
function implementation() external view returns (address)
```

**Purpose**: Get the current implementation contract address.

**Returns**: Address of the current implementation contract.

**Usage**: Used to verify which implementation is currently active.

#### Upgrade Implementation

```solidity
function upgradeTo(address newImplementation) external onlyGovernor
```

**Purpose**: Upgrade to a new implementation contract.

**Access Control**: Only governors can upgrade implementations.

**Parameters**: `newImplementation` - Address of the new implementation contract.

**Process**:

1. Validate new implementation address
2. Update implementation reference
3. Emit upgrade event
4. Verify new implementation compatibility

## Usage Examples

### Basic Proxy Operations

#### Check Current Implementation

```solidity
// Get current implementation address
AppProxy proxy = AppProxy(proxyAddress);
address currentImpl = proxy.implementation();
console.log("Current Implementation:", currentImpl);
```

#### Upgrade Implementation

```solidity
// Upgrade to new implementation
address newImplementation = 0x...;
proxy.upgradeTo(newImplementation);
```

### Contract Interaction

#### Interact Through Proxy

```solidity
// All function calls go through proxy
// Example: calling a function on the proxied contract
IProxiedContract contract = IProxiedContract(proxyAddress);
contract.someFunction(parameters);
```

#### Check Proxy Status

```solidity
// Verify proxy is working correctly
try proxy.implementation() returns (address impl) {
    console.log("Proxy is working, implementation:", impl);
} catch {
    console.log("Proxy has issues");
}
```

## License

AGPL-3.0
