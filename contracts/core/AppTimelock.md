# AppTimelock

**File**: [`AppTimelock.sol`](./AppTimelock.sol)
**License**: AGPL-3.0

## Overview

The `AppTimelock` contract is a time-delay mechanism for governance actions in the Rezerve.money protocol. It provides a security layer by delaying the execution of critical governance decisions, allowing time for review and potential cancellation of proposed actions.

## Purpose

This contract serves as:

- **Governance Security**: Delays execution of critical governance actions
- **Review Period**: Provides time for community review of proposals
- **Cancellation Mechanism**: Allows cancellation of proposed actions
- **Batch Operations**: Supports multiple action execution
- **Emergency Controls**: Emergency override capabilities for urgent situations

## Architecture

### Inheritance

- `AppAccessControlled` - Protocol access control integration
- `Initializable` - Upgradeable contract pattern

### Core Components

- **Delay Management**: Configurable delay periods for different action types
- **Action Queue**: Queue of pending actions awaiting execution
- **Batch Execution**: Support for executing multiple actions together
- **Emergency Controls**: Emergency override mechanisms

## Key Functions

### Action Management

#### Queue Action

```solidity
function queueAction(
    address target,
    uint256 value,
    string calldata signature,
    bytes calldata data,
    uint256 eta
) external onlyGovernor
```

**Purpose**: Queue a governance action for delayed execution.

**Access Control**: Only governors can queue actions.

**Parameters**:

- `target`: Target contract for the action
- `value`: ETH value to send with the action
- `signature`: Function signature
- `data`: Encoded function parameters
- `eta`: Execution timestamp

**Process**:

1. Validate action parameters
2. Calculate execution time based on delay
3. Queue action for execution
4. Emit action queued event

#### Execute Action

```solidity
function executeAction(
    address target,
    uint256 value,
    string calldata signature,
    bytes calldata data,
    uint256 eta
) external onlyGovernor
```

**Purpose**: Execute a queued action after delay period.

**Access Control**: Only governors can execute actions.

**Requirements**: Action must be queued and delay period must have passed.

**Process**:

1. Verify action is queued and ready
2. Execute action on target contract
3. Remove action from queue
4. Emit action executed event

#### Cancel Action

```solidity
function cancelAction(
    address target,
    uint256 value,
    string calldata signature,
    bytes calldata data,
    uint256 eta
) external onlyGovernor
```

**Purpose**: Cancel a queued action before execution.

**Access Control**: Only governors can cancel actions.

**Process**:

1. Verify action exists in queue
2. Remove action from queue
3. Emit action cancelled event

### Batch Operations

#### Queue Batch Actions

```solidity
function queueBatchActions(
    address[] calldata targets,
    uint256[] calldata values,
    string[] calldata signatures,
    bytes[] calldata data,
    uint256 eta
) external onlyGovernor
```

**Purpose**: Queue multiple actions for batch execution.

**Parameters**: Arrays of action parameters for batch processing.

**Process**: Queues all actions with the same execution time.

#### Execute Batch Actions

```solidity
function executeBatchActions(
    address[] calldata targets,
    uint256[] calldata values,
    string[] calldata signatures,
    bytes[] calldata data,
    uint256 eta
) external onlyGovernor
```

**Purpose**: Execute multiple queued actions together.

**Requirements**: All actions must be queued and ready for execution.

**Process**: Executes all actions in sequence.

### Query Functions

#### Get Action Hash

```solidity
function getActionHash(
    address target,
    uint256 value,
    string calldata signature,
    bytes calldata data,
    uint256 eta
) public pure returns (bytes32)
```

**Purpose**: Calculate unique hash for an action.

**Returns**: Keccak256 hash of action parameters.

**Usage**: Used to identify and track specific actions.

#### Is Action Queued

```solidity
function isActionQueued(bytes32 actionHash) public view returns (bool)
```

**Purpose**: Check if an action is currently queued.

**Parameters**: `actionHash` - Hash of the action to check.

**Returns**: `true` if action is queued, `false` otherwise.

#### Get Action ETA

```solidity
function getActionETA(bytes32 actionHash) public view returns (uint256)
```

**Purpose**: Get execution time for a queued action.

**Parameters**: `actionHash` - Hash of the action.

**Returns**: Execution timestamp for the action.

## Integration Points

### Protocol Contracts

- **All Governance Contracts**: Contracts that require timelock protection
- **Authority**: [`AppAuthority.sol`](./AppAuthority.sol) - Access control
- **Proxy Contracts**: [`AppProxy.sol`](./AppProxy.sol) - Upgrade protection

### External Systems

- **Governance**: Governance system for action proposals
- **Monitoring**: Systems for monitoring queued actions
- **Alerting**: Alert systems for pending actions

## Timelock Mechanics

### Delay Periods

- **Configurable Delays**: Different delay periods for different action types
- **Minimum Delays**: Minimum required delays for security
- **Maximum Delays**: Maximum allowed delays for usability
- **Dynamic Adjustment**: Delays can be updated by governance

### Action Lifecycle

1. **Proposal**: Action proposed by governance
2. **Queue**: Action queued with execution timestamp
3. **Review**: Community review period during delay
4. **Execution**: Action executed after delay period
5. **Cancellation**: Action can be cancelled before execution

### Batch Processing

- **Multiple Actions**: Support for executing multiple actions together
- **Same Delay**: All actions in batch have same execution time
- **Atomic Execution**: All actions execute or none execute
- **Efficiency**: Reduces gas costs for multiple actions

## Security Features

### Access Control

- **Governance Only**: Only governors can queue and execute actions
- **Action Validation**: All actions are validated before queuing
- **Delay Enforcement**: Strict enforcement of delay periods
- **Emergency Controls**: Emergency override capabilities

### Timelock Security

- **Minimum Delays**: Prevents immediate execution of critical actions
- **Review Period**: Provides time for community review
- **Cancellation Rights**: Allows cancellation of proposed actions
- **Hash Verification**: Unique action identification and tracking

### Operational Security

- **Action Tracking**: Complete tracking of all queued actions
- **State Validation**: Verification of action readiness
- **Event Logging**: Complete transparency of all operations
- **Emergency Procedures**: Emergency response capabilities

## Usage Examples

### Basic Timelock Operations

#### Queue a Governance Action

```solidity
// Queue an action to upgrade a contract
AppTimelock timelock = AppTimelock(timelockAddress);

timelock.queueAction(
    contractAddress,           // Target contract
    0,                         // No ETH value
    "upgradeTo(address)",      // Function signature
    abi.encode(newImpl),       // Encoded parameters
    block.timestamp + 24 hours // Execute in 24 hours
);
```

#### Execute Queued Action

```solidity
// Execute action after delay period
timelock.executeAction(
    contractAddress,
    0,
    "upgradeTo(address)",
    abi.encode(newImpl),
    eta
);
```

#### Cancel Queued Action

```solidity
// Cancel action before execution
timelock.cancelAction(
    contractAddress,
    0,
    "upgradeTo(address)",
    abi.encode(newImpl),
    eta
);
```

### Batch Operations

#### Queue Multiple Actions

```solidity
// Queue multiple actions for batch execution
address[] memory targets = new address[](2);
uint256[] memory values = new uint256[](2);
string[] memory signatures = new string[](2);
bytes[] memory data = new bytes[](2);

targets[0] = contract1;
targets[1] = contract2;
signatures[0] = "setParameter(uint256)";
signatures[1] = "updateConfig(bytes)";
data[0] = abi.encode(100);
data[1] = abi.encode(configData);

timelock.queueBatchActions(targets, values, signatures, data, eta);
```

#### Execute Batch Actions

```solidity
// Execute all queued actions together
timelock.executeBatchActions(targets, values, signatures, data, eta);
```

### Action Queries

#### Check Action Status

```solidity
// Check if action is queued
bytes32 actionHash = timelock.getActionHash(
    contractAddress,
    0,
    "upgradeTo(address)",
    abi.encode(newImpl),
    eta
);

bool isQueued = timelock.isActionQueued(actionHash);
uint256 executionTime = timelock.getActionETA(actionHash);

if (isQueued) {
    console.log("Action is queued for execution at:", executionTime);
}
```

## Events

### Action Events

```solidity
event ActionQueued(bytes32 indexed actionHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta);
event ActionExecuted(bytes32 indexed actionHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta);
event ActionCancelled(bytes32 indexed actionHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta);
```

### Batch Events

```solidity
event BatchActionsQueued(bytes32[] indexed actionHashes, uint256 eta);
event BatchActionsExecuted(bytes32[] indexed actionHashes);
event BatchActionsCancelled(bytes32[] indexed actionHashes);
```

### Management Events

```solidity
event DelayUpdated(uint256 oldDelay, uint256 newDelay);
event EmergencyExecuted(bytes32 indexed actionHash, address indexed target);
```

## Testing

### Unit Tests

- Action queuing and execution functionality
- Delay period enforcement
- Batch operation handling
- Access control validation

### Integration Tests

- Cross-contract action execution
- Governance integration testing
- Emergency procedure testing
- Authority system integration

### Security Tests

- Access control validation
- Delay manipulation prevention
- Action replay prevention
- Emergency response testing

## Deployment Considerations

### Initial Setup

1. **Deploy Contract**: Deploy AppTimelock contract
2. **Configure Authority**: Set up access control integration
3. **Set Delays**: Configure delay periods for different action types
4. **Verify Functionality**: Test timelock mechanics

### Configuration

1. **Authority Integration**: Connect to governance system
2. **Delay Configuration**: Set appropriate delay periods
3. **Emergency Setup**: Configure emergency override procedures
4. **Monitoring Setup**: Implement action monitoring

## Dependencies

### Core Dependencies

- **AppAccessControlled**: Protocol access control integration
- **Initializable**: Upgradeable contract pattern
- **Governance System**: Access control for timelock operations

### External Dependencies

- **Governance Tools**: Tools for managing timelock actions
- **Monitoring Systems**: Systems for monitoring queued actions
- **Alert Systems**: Alert systems for pending actions

## Best Practices

### Timelock Management

1. **Appropriate Delays**: Set delays appropriate for action criticality
2. **Community Communication**: Communicate all queued actions
3. **Review Periods**: Ensure adequate review time for actions
4. **Cancellation Rights**: Maintain ability to cancel actions

### Security Considerations

1. **Access Control**: Verify timelock permissions are properly restricted
2. **Delay Enforcement**: Ensure delay periods are strictly enforced
3. **Action Validation**: Validate all actions before queuing
4. **Emergency Procedures**: Test emergency response capabilities

### User Experience

1. **Action Transparency**: Provide clear visibility of queued actions
2. **Execution Tracking**: Track action execution status
3. **Cancellation Process**: Clear process for cancelling actions
4. **Monitoring Tools**: Provide tools to monitor timelock status

## License

AGPL-3.0
