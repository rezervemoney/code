# AppAccessControlled

**File**: [`AppAccessControlled.sol`](./AppAccessControlled.sol)
**Interface**: [`IAppAccessControlled.sol`](../interfaces/IAppAccessControlled.sol)
**License**: AGPL-3.0

## Overview

The `AppAccessControlled` contract is a base contract that provides standardized access control functionality for all protocol contracts. It implements the `IAppAccessControlled` interface and provides a consistent way for contracts to interact with the central authority system.

## Purpose

This contract serves as:

- **Access Control Base**: Foundation for role-based access control across the protocol
- **Authority Integration**: Standardized interface to the central `AppAuthority` contract
- **Pause Functionality**: Built-in pause state checking for emergency situations
- **Role Verification**: Helper functions for checking caller permissions
- **Consistent Interface**: Uniform access control pattern for all protocol contracts

## Architecture

### Inheritance

- [`IAppAccessControlled`](../interfaces/IAppAccessControlled.sol) - Core interface
- `AppAccessControlled` - Base implementation

### Core Components

- **Authority Reference**: Link to the central `AppAuthority` contract
- **Pause State Checking**: Integration with protocol-wide pause functionality
- **Role Verification**: Helper functions for permission checking
- **Modifier Support**: Access control modifiers for function protection

## Key Functions

### Initialization

#### Constructor

```solidity
constructor(address _authority)
```

**Parameters:**

- `_authority`: Address of the central `AppAuthority` contract

**Behavior:**

- Sets the authority address
- Initializes the access control system
- Establishes connection to central governance

### Authority Management

#### Authority Reference

```solidity
IAppAuthority public immutable authority;
```

**Purpose**: Immutable reference to the central authority contract for all access control operations.

#### Authority Getter

```solidity
function getAuthority() external view returns (IAppAuthority)
```

**Returns**: The current authority contract address.

### Pause State Checking

#### Pause State

```solidity
function isPaused() public view returns (bool)
```

**Returns**: `true` if the protocol is currently paused, `false` otherwise.

**Usage**: Contracts can check pause state before executing critical operations.

#### Pause State with Authority Check

```solidity
function isPaused() public view returns (bool)
```

**Implementation**: Delegates to the central authority contract to check global pause state.

## Access Control Modifiers

### Pause Protection

#### When Not Paused

```solidity
modifier whenNotPaused()
```

**Purpose**: Ensures function execution only when protocol is not paused.

**Usage**: Apply to functions that should be blocked during emergency pauses.

#### When Paused

```solidity
modifier whenPaused()
```

**Purpose**: Ensures function execution only when protocol is paused.

**Usage**: Apply to emergency functions that should only work during pauses.

### Role-Based Access Control

#### Governor Only

```solidity
modifier onlyGovernor()
```

**Purpose**: Restricts function access to governor role members only.

**Implementation**: Delegates permission checking to the central authority contract.

#### Guardian or Governor

```solidity
modifier onlyGovernorOrGuardian()
```

**Purpose**: Restricts function access to governor or guardian role members.

**Usage**: Emergency functions that require high-level access but not necessarily governor-only access.

#### Policy Role

```solidity
modifier onlyPolicy()
```

**Purpose**: Restricts function access to policy role members only.

**Usage**: Functions that modify protocol parameters and policies.

#### Reserve Manager

```solidity
modifier onlyReserveManager()
```

**Purpose**: Restricts function access to reserve manager role members only.

**Usage**: Functions that manage treasury reserves and allocations.

#### Executor

```solidity
modifier onlyExecutor()
```

**Purpose**: Restricts function access to executor role members only.

**Usage**: Automated functions and maintenance operations.

#### Reserve Depositor

```solidity
modifier onlyReserveDepositor()
```

**Purpose**: Restricts function access to reserve depositor role members only.

**Usage**: Functions that add new reserves to the treasury.

#### Bond Manager

```solidity
modifier onlyBondManager()
```

**Purpose**: Restricts function access to bond manager role members only.

**Usage**: Functions that manage bond issuance and operations.

## Usage Patterns

### Basic Contract Setup

```solidity
contract MyProtocolContract is AppAccessControlled {
    constructor(address _authority) AppAccessControlled(_authority) {
        // Contract initialization
    }

    function criticalFunction() external whenNotPaused onlyGovernor {
        // Function implementation
    }
}
```

### Pause State Integration

```solidity
contract TreasuryContract is AppAccessControlled {
    function withdraw() external whenNotPaused {
        require(!isPaused(), "Protocol is paused");
        // Withdrawal logic
    }

    function emergencyWithdraw() external whenPaused onlyGuardian {
        // Emergency withdrawal logic
    }
}
```

### Role-Based Function Protection

```solidity
contract StakingContract is AppAccessControlled {
    function setStakingRate(uint256 newRate) external onlyPolicy {
        // Rate setting logic
    }

    function addReserves(uint256 amount) external onlyReserveDepositor {
        // Reserve addition logic
    }

    function executeMaintenance() external onlyExecutor {
        // Maintenance operations
    }
}
```

## Integration Points

### Protocol Contracts

- **All Core Contracts**: Base class for access control functionality
- **Treasury**: [`AppTreasury.sol`](./AppTreasury.sol) - Reserve management
- **Staking**: [`AppStaking.sol`](./AppStaking.sol) - Staking operations
- **Bonds**: [`AppBondDepository.sol`](./AppBondDepository.sol) - Bond management

### Authority System

- **AppAuthority**: [`AppAuthority.sol`](./AppAuthority.sol) - Central authority contract
- **Role Management**: Centralized role assignment and verification
- **Pause Control**: Protocol-wide emergency pause functionality

## Security Features

### Access Control

- **Role Verification**: All role checks delegated to central authority
- **Immutable Authority**: Authority address cannot be changed after deployment
- **Modifier Protection**: Functions protected by role-based access control

### Pause Integration

- **Global Pause State**: All contracts respect protocol-wide pause
- **Emergency Functions**: Support for emergency-only operations
- **State Consistency**: Pause state synchronized across all contracts

### Permission Delegation

- **Centralized Control**: All permissions managed by central authority
- **Consistent Behavior**: Uniform access control across all contracts
- **Audit Trail**: All permission checks logged through authority contract

## Best Practices

### Contract Design

1. **Inherit Early**: Inherit from `AppAccessControlled` in contract definition
2. **Constructor Setup**: Pass authority address in constructor
3. **Modifier Usage**: Apply appropriate modifiers to all functions
4. **Pause Integration**: Check pause state for critical operations

### Access Control

1. **Principle of Least Privilege**: Use most restrictive modifier necessary
2. **Role Separation**: Separate concerns between different roles
3. **Emergency Planning**: Include pause state checks in critical functions
4. **Consistent Patterns**: Follow established access control patterns

### Security Considerations

1. **Authority Validation**: Verify authority address during deployment
2. **Role Verification**: Test all role-based access controls
3. **Pause Testing**: Verify pause state integration
4. **Emergency Procedures**: Test emergency function access

## Testing

### Unit Tests

- Authority address initialization
- Pause state checking functionality
- Modifier behavior validation
- Role verification delegation

### Integration Tests

- Cross-contract permission checking
- Pause state propagation
- Role-based access control
- Emergency function access

### Security Tests

- Unauthorized access attempts
- Role escalation prevention
- Pause state manipulation
- Authority contract integration

## Dependencies

### Core Dependencies

- **IAppAccessControlled**: Core interface definition
- **IAppAuthority**: Authority contract interface
- **AppAuthority**: Central authority contract implementation

### External Dependencies

- **OpenZeppelin**: Access control and modifier patterns
- **Solidity**: Language features and modifier system

## Events

### Authority Events

Events are inherited from the `IAppAccessControlled` interface and typically include:

- Authority initialization events
- Role verification events
- Pause state change events

## Error Handling

### Common Errors

- **Invalid Authority**: Authority address is zero or invalid
- **Unauthorized Access**: Caller lacks required role
- **Protocol Paused**: Function called while protocol is paused
- **Role Verification Failed**: Role check delegation failed

### Error Prevention

- **Constructor Validation**: Verify authority address during deployment
- **Modifier Protection**: Apply appropriate access control modifiers
- **Pause State Checking**: Verify pause state before critical operations
- **Role Verification**: Delegate all permission checks to authority contract

## Deployment Considerations

### Initial Setup

1. **Deploy Authority**: Ensure `AppAuthority` contract is deployed first
2. **Contract Deployment**: Pass authority address to all `AppAccessControlled` contracts
3. **Role Configuration**: Configure roles in authority contract before use
4. **Testing**: Verify all access control functionality

### Configuration

1. **Authority Address**: Verify correct authority contract address
2. **Role Assignment**: Ensure all required roles are properly assigned
3. **Pause State**: Verify pause functionality integration
4. **Access Control**: Test all role-based permissions

## License

AGPL-3.0
