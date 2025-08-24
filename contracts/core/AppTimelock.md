# AppTimelock

**File**: [`AppTimelock.sol`](./AppTimelock.sol)

**License**: AGPL-3.0-or-later

## Overview

The `AppTimelock` contract is a time-delay mechanism for governance actions in the Rezerve.money protocol. It extends OpenZeppelin's `TimelockController` to provide a security layer by delaying the execution of critical governance decisions, allowing time for review and potential cancellation of proposed actions.

## Purpose

This contract serves as:

- **Governance Security**: Delays execution of critical governance actions
- **Review Period**: Provides time for community review of proposals
- **Cancellation Mechanism**: Allows cancellation of proposed actions
- **Role Management**: Manages proposer, executor, and admin roles
- **Batch Operations**: Supports multiple action execution through OpenZeppelin's implementation

## Architecture

### Inheritance

- `AccessControlEnumerable` - Role-based access control with enumerable members
- `TimelockController` - OpenZeppelin's timelock implementation

### Core Components

- **Role Management**: Access control for timelock operations
- **Timelock Mechanics**: Delay and execution mechanisms from OpenZeppelin
- **Batch Execution**: Support for executing multiple actions together
- **Role Enumeration**: Query capabilities for role members

## Key Functions

### Role Management

#### Grant Role

```solidity
function _grantRole(bytes32 role, address account) internal virtual override returns (bool)
```

**Purpose**: Grant a role to an account.

**Access Control**: Internal function, can only be called by contract logic.

**Parameters**:

- `role` - Role identifier to grant
- `account` - Address to grant the role to

**Returns**: `true` if role was granted, `false` otherwise.

**Process**: Grants the specified role to the account and emits role granted event.

#### Revoke Role

```solidity
function _revokeRole(bytes32 role, address account) internal override returns (bool)
```

**Purpose**: Revoke a role from an account.

**Access Control**: Internal function, can only be called by contract logic.

**Parameters**:

- `role` - Role identifier to revoke
- `account` - Address to revoke the role from

**Returns**: `true` if role was revoked, `false` otherwise.

**Process**: Revokes the specified role from the account and emits role revoked event.

### Interface Support

#### Supports Interface

```solidity
function supportsInterface(bytes4 interfaceId) public view override returns (bool)
```

**Purpose**: Check if the contract supports a specific interface.

**Parameters**: `interfaceId` - Interface identifier to check.

**Returns**: `true` if interface is supported, `false` otherwise.

**Usage**: Used to verify contract capabilities and compatibility.

### Role Enumeration

#### Get All Candidates

```solidity
function getAllCandidates(bytes32 role) public view returns (address[] memory candidates)
```

**Purpose**: Get all addresses that have a specific role.

**Parameters**: `role` - Role identifier to query.

**Returns**: Array of addresses with the specified role.

**Process**: Enumerates all role members and returns them as an array.

#### Get All Proposers

```solidity
function getAllProposers() public view returns (address[] memory proposers)
```

**Purpose**: Get all addresses with the proposer role.

**Returns**: Array of all proposer addresses.

**Usage**: Convenience function to get all users who can propose timelock actions.

#### Get All Executors

```solidity
function getAllExecutors() public view returns (address[] memory executors)
```

**Purpose**: Get all addresses with the executor role.

**Returns**: Array of all executor addresses.

**Usage**: Convenience function to get all users who can execute timelock actions.

#### Get All Admins

```solidity
function getAllAdmins() public view returns (address[] memory admins)
```

**Purpose**: Get all addresses with the admin role.

**Returns**: Array of all admin addresses.

**Usage**: Convenience function to get all users with administrative privileges.

#### Get All Cancellers

```solidity
function getAllCancellers() public view returns (address[] memory cancelers)
```

**Purpose**: Get all addresses with the canceller role.

**Returns**: Array of all canceller addresses.

**Usage**: Convenience function to get all users who can cancel timelock actions.

## Integration Points

### Protocol Contracts

- **All Governance Contracts**: Contracts that require timelock protection
- **Authority**: [`AppAuthority.sol`](./AppAuthority.sol) - Access control integration
- **Proxy Contracts**: [`AppProxy.sol`](./AppProxy.sol) - Upgrade protection

### External Systems

- **Governance**: Governance system for action proposals
- **Monitoring**: Systems for monitoring queued actions
- **Alerting**: Alert systems for pending actions

## Timelock Mechanics

The contract inherits all timelock functionality from OpenZeppelin's `TimelockController`, including:

### Core Timelock Functions

- **`schedule()`**: Schedule an action for execution after a delay
- **`execute()`**: Execute a scheduled action after the delay period
- **`cancel()`**: Cancel a scheduled action before execution
- **`revoke()`**: Revoke a role from an account

## Usage Examples

### Role Management

#### Check Role Members

```solidity
// Get all proposers
AppTimelock timelock = AppTimelock(timelockAddress);

address[] memory proposers = timelock.getAllProposers();
console.log("Total proposers:", proposers.length);

for (uint256 i = 0; i < proposers.length; i++) {
    console.log("Proposer:", proposers[i]);
}
```

#### Check All Role Types

```solidity
// Get all executors
address[] memory executors = timelock.getAllExecutors();
console.log("Total executors:", executors.length);

// Get all admins
address[] memory admins = timelock.getAllAdmins();
console.log("Total admins:", admins.length);

// Get all cancellers
address[] memory cancellers = timelock.getAllCancellers();
console.log("Total cancellers:", cancellers.length);
```

### Timelock Operations

The contract inherits all timelock operations from OpenZeppelin's `TimelockController`:

#### Schedule an Action

```solidity
// Schedule an action (requires proposer role)
timelock.schedule(
    targetContract,           // Target contract
    value,                    // ETH value to send
    data,                     // Encoded function call
    predecessor,              // Predecessor action (0 for none)
    salt,                     // Unique identifier
    delay                     // Delay before execution
);
```

#### Execute a Scheduled Action

```solidity
// Execute action after delay period (requires executor role)
timelock.execute(
    targetContract,           // Target contract
    value,                    // ETH value to send
    data,                     // Encoded function call
    predecessor,              // Predecessor action
    salt                      // Unique identifier
);
```

#### Cancel a Scheduled Action

```solidity
// Cancel action before execution (requires canceller role)
timelock.cancel(
    targetContract,           // Target contract
    value,                    // ETH value to send
    data,                     // Encoded function call
    predecessor,              // Predecessor action
    salt                      // Unique identifier
);
```

### Role Verification

#### Check Interface Support

```solidity
// Check if contract supports a specific interface
bool supportsAccessControl = timelock.supportsInterface(0x7965db0b);
if (supportsAccessControl) {
    console.log("Contract supports AccessControl interface");
}
```

## Events

The contract inherits all events from OpenZeppelin's `TimelockController` and `AccessControl`:

### Timelock Events

```solidity
event CallScheduled(bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data, bytes32 predecessor, bytes32 salt, uint256 delay);
event CallExecuted(bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data);
event Cancelled(bytes32 indexed id);
event MinDelayChange(uint256 oldDuration, uint256 newDuration);
```

### Access Control Events

```solidity
event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
```

## License

AGPL-3.0-or-later
