# AppAuthority

**File**: [`AppAuthority.sol`](./AppAuthority.sol)

**Interface**: [`IAppAuthority.sol`](../interfaces/IAppAuthority.sol)

**License**: AGPL-3.0

**Test File**: [`test/foundry/AccessControlTest.t.sol`](../../test/foundry/AccessControlTest.t.sol)

## Overview

The `AppAuthority` contract serves as the central access control and governance hub for the entire protocol. It implements a comprehensive role-based access control (RBAC) system that manages permissions for all critical protocol operations, from governance decisions to emergency controls.

## Purpose

This contract provides:

- **Centralized Access Control**: Single source of truth for all protocol permissions
- **Role Management**: Hierarchical role system with specific capabilities
- **Emergency Controls**: Pause/unpause functionality for emergency situations
- **Protocol Configuration**: Management of treasury, bridge, and other core addresses
- **Governance Structure**: Multi-signature and multi-role governance capabilities

## Architecture

### Inheritance

- [`IAppAuthority`](../interfaces/IAppAuthority.sol) - Core interface
- `AccessControlEnumerable` - OpenZeppelin RBAC implementation
- `Pausable` - Emergency pause functionality

### Core Components

- **Role System**: 8 distinct roles with specific permissions
- **Address Management**: Treasury, bridge, and operations treasury addresses
- **Emergency Controls**: Pause/unpause mechanism
- **Role Administration**: Add/remove role members

## Role System

### Role Hierarchy

```
GOVERNOR_ROLE (Admin for all other roles)
├── BOND_MANAGER_ROLE
├── EXECUTOR_ROLE
├── GUARDIAN_ROLE
├── POLICY_ROLE
├── RESERVE_DEPOSITOR_ROLE
└── RESERVE_MANAGER_ROLE
```

### Role Definitions

| Role                     | Purpose                                 | Admin             |
| ------------------------ | --------------------------------------- | ----------------- |
| `GOVERNOR_ROLE`          | Protocol governance and role management | Self-administered |
| `GUARDIAN_ROLE`          | Emergency controls and safety measures  | Governor          |
| `POLICY_ROLE`            | Policy parameter updates                | Governor          |
| `RESERVE_MANAGER_ROLE`   | Treasury reserve management             | Governor          |
| `EXECUTOR_ROLE`          | Automated protocol operations           | Governor          |
| `RESERVE_DEPOSITOR_ROLE` | Treasury deposit operations             | Governor          |
| `BOND_MANAGER_ROLE`      | Bond issuance and management            | Governor          |

## Key Functions

### Role Management

#### Adding Roles

```solidity
function addGovernor(address _newGovernor) external onlyGovernor
function addGuardian(address _newGuardian) external onlyGovernor
function addPolicy(address _newPolicy) external onlyGovernor
function addReserveManager(address _newReserveManager) external onlyGovernor
function addExecutor(address _newExecutor) external onlyGovernor
function addReserveDepositor(address _newReserveDepositor) external onlyGovernor
function addBondManager(address _newBondManager) external onlyGovernor
```

#### Removing Roles

```solidity
function removeGovernor(address _oldGovernor) external onlyGovernor
function removeGuardian(address _oldGuardian) external onlyGovernor
function removePolicy(address _oldPolicy) external onlyGovernor
function removeReserveManager(address _oldReserveManager) external onlyGovernor
function removeExecutor(address _oldExecutor) external onlyGovernor
function removeReserveDepositor(address _oldReserveDepositor) external onlyGovernor
function removeBondManager(address _oldBondManager) external onlyGovernor
```

### Protocol Configuration

#### Treasury Management

```solidity
function setTreasury(address _newTreasury) external onlyGovernor
function setOperationsTreasury(address _newOperationsTreasury) external onlyGovernor
```

#### Bridge Configuration

```solidity
function setBridge(address _newBridge) external onlyGovernor
```

### Emergency Controls

#### Pause/Unpause

```solidity
function emergencyPause() external onlyGovernorOrGuardian
function emergencyUnpause() external onlyGovernor
function underEmergencyPause() external view returns (bool)
```

**Access Control**: Only governors and guardians can pause, only governors can unpause.

## Access Control Modifiers

### Role-Based Modifiers

```solidity
modifier onlyGovernor()
modifier onlyGovernorOrGuardian()
```

### Usage Examples

```solidity
// Only governors can add new roles
function addGuardian(address _newGuardian) external onlyGovernor {
    _grantRole(GUARDIAN_ROLE, _newGuardian);
}

// Governors or guardians can pause in emergencies
function emergencyPause() external onlyGovernorOrGuardian {
    _pause();
}
```

## View Functions

### Role Verification

```solidity
function isGovernor(address account) external view returns (bool)
function isGuardian(address account) external view returns (bool)
function isPolicy(address account) external view returns (bool)
function isReserveManager(address account) external view returns (bool)
function isExecutor(address account) external view returns (bool)
function isReserveDepositor(address account) external view returns (bool)
function isBondManager(address account) external view returns (bool)
function isTreasury(address account) external view returns (bool)
```

### Role Member Enumeration

```solidity
function getAllCandidates(bytes32 role) public view returns (address[] memory)
function getAllGovernorCandidates() external view returns (address[] memory)
function getAllGuardianCandidates() external view returns (address[] memory)
function getAllPolicyCandidates() external view returns (address[] memory)
function getAllReserveManagerCandidates() external view returns (address[] memory)
function getAllExecutorCandidates() external view returns (address[] memory)
function getAllReserveDepositorCandidates() external view returns (address[] memory)
function getAllBondManagerCandidates() external view returns (address[] memory)
```

## Events

### Configuration Updates

```solidity
event OperationsTreasuryUpdated(address indexed newOperationsTreasury, address indexed oldOperationsTreasury)
event TreasuryUpdated(address indexed newTreasury, address indexed oldTreasury)
event BridgeUpdated(address indexed newBridge, address indexed oldBridge)
```

### Role Changes

Role addition/removal events are inherited from OpenZeppelin's `AccessControl`:

- `RoleGranted(bytes32 indexed role, address indexed account, address indexed sender)`
- `RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender)`

### Emergency Controls

Pause/unpause events are inherited from OpenZeppelin's `Pausable`:

- `Paused(address account)`
- `Unpaused(address account)`

## Security Features

### Access Control

- **Role-Based Permissions**: Granular access control for different operations
- **Hierarchical Administration**: Governors control all other roles
- **Modifier Protection**: Functions protected by role-based modifiers

### Emergency Controls

- **Pause Mechanism**: Emergency stop for all protocol operations
- **Guardian Access**: Guardians can pause but not unpause
- **Governor Override**: Governors have full emergency control

### Address Validation

- **Zero Address Checks**: Prevents setting invalid addresses
- **Role Verification**: All operations verify caller permissions
- **Event Logging**: Full transparency of all configuration changes

## Integration Points

### Protocol Contracts

- **Treasury**: [`AppTreasury.sol`](./AppTreasury.sol) - Reserve management
- **Bridge**: Bridge contracts for cross-chain operations
- **Operations Treasury**: Separate treasury for operational expenses

### External Contracts

- **OpenZeppelin**: Access control and pausable functionality
- **Interface Contracts**: [`IAppAuthority.sol`](../interfaces/IAppAuthority.sol)

## Usage Examples

### Adding a New Guardian

```solidity
// Only governors can add guardians
AppAuthority authority = AppAuthority(authorityAddress);
authority.addGuardian(newGuardianAddress);
```

### Emergency Pause

```solidity
// Governors or guardians can pause
if (authority.isGovernor(msg.sender) || authority.isGuardian(msg.sender)) {
    authority.emergencyPause();
}
```

### Checking Permissions

```solidity
// Verify if caller has specific role
if (authority.isReserveManager(msg.sender)) {
    // Execute reserve management function
}
```

## License

AGPL-3.0
