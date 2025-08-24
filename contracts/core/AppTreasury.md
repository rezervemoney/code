# AppTreasury

**File**: [`AppTreasury.sol`](./AppTreasury.sol)

**License**: AGPL-3.0

**Test File**: [`test/foundry/AppTreasuryTest.t.sol`](../../test/foundry/AppTreasuryTest.t.sol)

## Overview

The `AppTreasury` contract is the central treasury management system for the Rezerve.money protocol. It manages protocol reserves, executes economic policies, and provides funding for protocol operations through a sophisticated reserve management and distribution system.

## Purpose

This contract serves as:

- **Reserve Management**: Central hub for all protocol asset reserves
- **Economic Policy Execution**: Implements protocol economic policies and strategies
- **Funding Distribution**: Manages funding for staking, bonds, and protocol operations
- **Reserve Tracking**: Monitors and reports on protocol financial health
- **Policy Implementation**: Executes governance-approved economic policies

## Architecture

### Inheritance

- `AppAccessControlled` - Protocol access control integration
- `Initializable` - Upgradeable contract pattern

### Core Components

- **Reserve Management**: Multi-asset reserve tracking and management
- **Economic Calculations**: Reserve calculations and economic metrics
- **Policy Execution**: Economic policy implementation and management
- **Funding Distribution**: Automated funding for protocol operations

## Key Functions

### Reserve Management

#### Reserve Calculations

```solidity
function calculateReserves() external view returns (uint256 usdReserves, uint256 rzrReserves)
```

**Purpose**: Calculate current protocol reserves in both USD and RZR terms.

**Returns**:

- `usdReserves`: Total USD value of protocol reserves
- `rzrReserves`: Total RZR tokens in protocol reserves

**Process**: Aggregates reserves from multiple sources and calculates total values.

#### Reserve Synchronization

```solidity
function syncReserves() external returns (uint256 usdReserves, uint256 rzrReserves)
```

**Purpose**: Synchronize reserves with current market conditions and protocol state.

**Access Control**: Only authorized contracts can call this function.

**Returns**: Updated reserve values after synchronization.

**Process**: Updates reserve calculations and emits events for monitoring.

### Reserve Management

#### Token Management

```solidity
function enable(address _address) external onlyGovernor
function disable(address _toDisable) external onlyGuardianOrGovernor
```

**Purpose**: Enable or disable tokens for treasury operations.

**Access Control**: Only governors can enable tokens, guardians or governors can disable.

**Parameters**: `_address` - Token address to enable/disable.

**Process**: Validates token prices and manages treasury token list.

#### Reserve Calculation

```solidity
function calculateReserves() public view returns (uint256 usdReserves, uint256 rzrReserves)
```

**Purpose**: Calculate current reserves across all enabled tokens.

**Returns**: Total USD and RZR reserve values.

**Process**: Iterates through enabled tokens and calculates total reserves.

## Integration Points

### Protocol Contracts

- **RZR Token**: [`RZR.sol`](./RZR.sol) - Token minting and management
- **Staking**: [`AppStaking.sol`](./AppStaking.sol) - Staking reward distribution
- **Bonds**: [`AppBondDepository.sol`](./AppBondDepository.sol) - Bond funding
- **Oracle**: Oracle contracts for price feeds and reserve calculations

### External Systems

- **DeFi Protocols**: Integration with lending and yield protocols
- **DEX Integration**: Reserve trading and liquidity management
- **Cross-Chain**: Bridge contracts for multi-chain reserve management

## Economic Model

### Reserve Composition

- **Multi-Asset Reserves**: Support for various token types
- **USD Denomination**: All reserves tracked in USD terms
- **RZR Backing**: RZR tokens as primary reserve asset
- **Liquidity Management**: Balanced reserve allocation for operations

### Reserve Framework

- **Token Management**: Governors can enable/disable tokens for treasury operations
- **Fee Structure**: Configurable reserve fees for deposits
- **Price Validation**: All tokens must have valid oracle prices
- **Emergency Controls**: Guardians can disable tokens in emergencies

### Reserve Operations

- **Deposit Management**: Reserve depositors can add new reserves
- **Token Withdrawal**: Reserve managers can withdraw tokens for operations
- **Reserve Synchronization**: Bridge contracts can sync cross-chain reserves
- **Executive Actions**: Governors can execute arbitrary calls for complex operations

## Security Features

### Access Control

- **Role-Based Permissions**: Granular access control for all operations
- **Token Management**: Only governors can enable tokens, guardians can disable
- **Reserve Management**: Controlled access to reserve operations
- **Emergency Controls**: Emergency pause and override capabilities

### Economic Security

- **Reserve Validation**: All reserve calculations verified via oracle prices
- **Token Validation**: All enabled tokens must have valid oracle prices
- **Fee Limits**: Reserve fees capped at 100% (1e18)
- **Audit Trail**: Complete transparency of all operations

### Operational Security

- **Multi-Signature**: Critical operations require multiple approvals
- **Timelock Protection**: Delayed execution for major changes
- **Monitoring**: Real-time monitoring of all operations
- **Alerting**: Automated alerts for unusual activity

## Usage Examples

### Reserve Management

#### Check Current Reserves

```solidity
// Get current protocol reserves
AppTreasury treasury = AppTreasury(treasuryAddress);
(uint256 usdReserves, uint256 rzrReserves) = treasury.calculateReserves();

console.log("USD Reserves:", usdReserves);
console.log("RZR Reserves:", rzrReserves);
```

#### Synchronize Reserves

```solidity
// Sync reserves with current state
(uint256 usdReserves, uint256 rzrReserves) = treasury.syncReserves();
```

### Policy Execution

#### Execute Economic Policy

```solidity
// Execute approved economic policy
bytes memory policyData = abi.encode(
    "RESERVE_ALLOCATION",
    1000000e18, // 1M RZR
    stakingContractAddress
);

treasury.executePolicy(policyData);
```

#### Allocate Reserves

```solidity
// Allocate reserves for staking rewards
treasury.allocateReserves(500000e18, stakingContractAddress);
```

### Funding Distribution

#### Distribute Staking Rewards

```solidity
// Distribute 100K RZR for staking rewards
treasury.distributeStakingRewards(100000e18);
```

#### Fund Bond Operations

```solidity
// Provide funding for bond issuance
treasury.fundBondIssuance(250000e18);
```

## Events

### Reserve Events

```solidity
event ReservesUpdated(uint256 usdReserves, uint256 rzrReserves, uint256 timestamp);
event ReservesSynchronized(uint256 usdReserves, uint256 rzrReserves);
```

### Policy Events

```solidity
event PolicyExecuted(bytes32 indexed policyId, bytes policyData, uint256 timestamp);
event ReservesAllocated(uint256 amount, address indexed recipient);
```

### Funding Events

```solidity
event StakingRewardsDistributed(uint256 amount, uint256 timestamp);
event BondFundingProvided(uint256 amount, uint256 timestamp);
```

### Operation Events

```solidity
event ReservesDeposited(address indexed token, uint256 amount, uint256 timestamp);
event ReservesWithdrawn(address indexed token, uint256 amount, address indexed recipient);
```

## Testing

### Unit Tests

- Reserve calculation accuracy
- Policy execution functionality
- Funding distribution mechanisms
- Access control validation

### Integration Tests

- Cross-contract reserve flows
- Policy implementation testing
- Funding distribution workflows
- Oracle integration testing

### Security Tests

- Access control validation
- Economic attack vectors
- Policy manipulation prevention
- Emergency procedure testing

## Deployment Considerations

### Initial Setup

1. **Deploy Contract**: Deploy AppTreasury contract
2. **Configure Authority**: Set up access control integration
3. **Set Initial Reserves**: Configure initial reserve amounts
4. **Verify Integration**: Test with all dependent contracts

### Configuration

1. **Authority Integration**: Connect to protocol authority system
2. **Oracle Setup**: Configure price feed integration
3. **Policy Framework**: Set up economic policy parameters
4. **Testing**: Verify all treasury functionality

## Dependencies

### Core Dependencies

- **AppAccessControlled**: Protocol access control integration
- **Initializable**: Upgradeable contract pattern
- **RZR Token**: Core protocol token integration

### External Dependencies

- **Oracle System**: Price feeds and reserve calculations
- **DeFi Protocols**: Integration with external protocols
- **Cross-Chain**: Bridge contracts for multi-chain operations

## Best Practices

### Reserve Management

1. **Regular Synchronization**: Keep reserves synchronized with current state
2. **Diversification**: Maintain balanced reserve allocation
3. **Liquidity Management**: Ensure adequate liquidity for operations
4. **Monitoring**: Continuous monitoring of reserve health

### Policy Execution

1. **Governance Approval**: All policies must have governance approval
2. **Parameter Validation**: Validate all policy parameters
3. **Execution Monitoring**: Monitor policy execution outcomes
4. **Emergency Planning**: Have emergency response procedures

### Security Considerations

1. **Access Control**: Verify all operations are properly authorized
2. **Policy Limits**: Implement maximum limits on policy execution
3. **Monitoring**: Continuous monitoring of all operations
4. **Emergency Procedures**: Test emergency response capabilities

## Testing

### Unit Tests

- Reserve calculations
- Policy execution
- Reserve allocation
- Staking reward distribution

**Test File**: [`test/foundry/AppTreasuryTest.t.sol`](../../test/foundry/AppTreasuryTest.t.sol)

### Integration Tests

- Protocol contract integration
- Oracle interaction testing
- Staking contract operations

### Security Tests

- Unauthorized access attempts
- Access control validation
- Reserve manipulation prevention

## License

AGPL-3.0
