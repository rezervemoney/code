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

## License

AGPL-3.0
