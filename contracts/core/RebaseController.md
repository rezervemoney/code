# RebaseController

**File**: [`RebaseController.sol`](./RebaseController.sol)

**License**: AGPL-3.0-only

**Test File**: [`test/foundry/RebaseControllerTest.t.sol`](../../test/foundry/RebaseControllerTest.t.sol)

## Overview

The `RebaseController` contract is a bonding-curve based rebase mechanism for the Rezerve.money protocol that provides epochic supply adjustments based on backing ratio calculations. It implements a sophisticated yield distribution system that mints RZR tokens for stakers, operations treasury, and burner contracts based on protocol performance metrics.

## Purpose

This contract serves as:

- **Epochic Rebase System**: Executes rebases at regular 23-hour epochs
- **Bonding Curve Logic**: Calculates rebase rates using piece-wise curves
- **Yield Distribution**: Distributes minted tokens to stakers, operations, and burner
- **Backing Ratio Management**: Maintains protocol backing ratio through supply adjustments
- **Performance Metrics**: Provides view functions for front-end gauges and analytics

## Architecture

### Inheritance

- `AppAccessControlled` - Protocol access control integration
- `IRebaseController` - Rebase controller interface
- `Initializable` - Upgradeable contract pattern

### Core Components

- **Epoch Management**: 23-hour epoch system for rebase execution
- **Bonding Curve**: Piece-wise curve calculations for yield rates
- **Reserve Management**: Integration with total reserves oracle
- **Distribution Logic**: Token allocation to stakers, operations, and burner
- **Price Oracle Integration**: Floor price calculations for reserve management

## Key Functions

### Epoch Execution

#### Execute Epoch

```solidity
function executeEpoch() external onlyExecutor
```

**Purpose**: Execute a rebase epoch, minting and distributing RZR tokens.

**Access Control**: Only executors can execute epochs.

**Requirements**: Must wait for full epoch duration (23 hours) since last execution.

**Process**:

1. Verify epoch is ready for execution
2. Calculate projected epoch rate and distribution
3. Verify sufficient reserves for minting
4. Mint RZR tokens and distribute to:
   - Stakers (via staking contract)
   - Operations treasury
   - Burner contract
5. Update last epoch time
6. Emit rebase event

### Configuration Management

#### Set Target Percentages

```solidity
function setTargetPcts(
    uint256 _targetOpsPct,
    uint256 _minFloorPct,
    uint256 _maxFloorPct,
    uint256 _floorSlope
) external onlyGovernor
```

**Purpose**: Update target percentage parameters for token distribution.

**Access Control**: Only governors can update target percentages.

**Parameters**:

- `_targetOpsPct` - Target percentage for operations treasury
- `_minFloorPct` - Minimum floor percentage
- `_maxFloorPct` - Maximum floor percentage
- `_floorSlope` - Floor slope parameter

**Process**: Updates parameters and emits event.

#### Set APR Variables

```solidity
function setAprVariables(uint16 _floorApr, uint16 _ceilApr, uint16 _k1, uint16 _k2) external onlyGovernor
```

**Purpose**: Update APR calculation parameters for the bonding curve.

**Access Control**: Only governors can update APR variables.

**Parameters**:

- `_floorApr` - Floor APR percentage (e.g., 500 for 500%)
- `_ceilApr` - Ceiling APR percentage (e.g., 2000 for 2000%)
- `_k1` - Curve parameter for β 1-1.5 range
- `_k2` - Curve parameter for β 1.5-2.5 range

**Process**: Updates APR parameters and emits event.

### View Functions

#### Current Backing Ratio

```solidity
function currentBackingRatio() external view returns (uint256)
```

**Purpose**: Get the current protocol backing ratio (β).

**Returns**: Backing ratio in 1e18 format (1e18 = β=1).

**Calculation**: β = PCV / supply, where PCV is protocol controlled value in USD.

#### Excess Reserves

```solidity
function excessReserves() public view returns (uint256)
```

**Purpose**: Calculate excess reserves available for minting.

**Returns**: Amount of excess reserves in USD terms.

**Calculation**: Excess = USD reserves - (RZR supply × floor price).

#### Projected Epoch Rate

```solidity
function projectedEpochRate() public view returns (
    uint256 apr,
    uint256 epochRate,
    uint256 toStakers,
    uint256 toOps,
    uint256 toBurner
)
```

**Purpose**: Get projected APR and token distribution for the next epoch.

**Returns**: APR, epoch mint rate, and distribution amounts.

**Process**: Calculates rates based on current backing ratio and staked supply.

#### Projected Epoch Rate Raw

```solidity
function projectedEpochRateRaw(
    uint256 pcv,
    uint256 supply,
    uint256 stakedSupply
) public view returns (
    uint256 apr,
    uint256 epochMint,
    uint256 toStakers,
    uint256 toOps,
    uint256 toBurner
)
```

**Purpose**: Calculate epoch rates with custom PCV and supply parameters.

**Parameters**:

- `pcv` - Protocol controlled value in USD
- `supply` - RZR token supply
- `stakedSupply` - Total staked RZR amount

**Returns**: APR, epoch mint rate, and distribution amounts.

**Usage**: Used for testing and external calculations with custom parameters.

## Usage Examples

### Epoch Execution

#### Execute Epoch

```solidity
// Execute a rebase epoch (executor only)
RebaseController rebaseController = RebaseController(rebaseAddress);

rebaseController.executeEpoch();
```

### Configuration Management

#### Update Target Percentages

```solidity
// Update distribution percentages (governor only)
rebaseController.setTargetPcts(
    0.1e18,    // 10% to operations
    0.15e18,   // 15% minimum floor
    0.5e18,    // 50% maximum floor
    0.45e18    // 45% floor slope
);
```

#### Update APR Variables

```solidity
// Update APR calculation parameters (governor only)
rebaseController.setAprVariables(
    500,    // 500% floor APR
    2000,   // 2000% ceiling APR
    10,     // k1 parameter
    1500    // k2 parameter
);
```

### Market Analytics

#### Check Current Backing Ratio

```solidity
// Get current protocol backing ratio
uint256 backingRatio = rebaseController.currentBackingRatio();
console.log("Current Backing Ratio:", backingRatio);
console.log("Backing Ratio %:", backingRatio * 100 / 1e18);
```

#### Check Excess Reserves

```solidity
// Get available excess reserves
uint256 excess = rebaseController.excessReserves();
console.log("Excess Reserves:", excess);
```

#### Get Projected Epoch Rates

```solidity
// Get projected rates for next epoch
(
    uint256 apr,
    uint256 epochRate,
    uint256 toStakers,
    uint256 toOps,
    uint256 toBurner
) = rebaseController.projectedEpochRate();

console.log("Projected APR:", apr);
console.log("Epoch Mint Rate:", epochRate);
console.log("To Stakers:", toStakers);
console.log("To Operations:", toOps);
console.log("To Burner:", toBurner);
```

#### Custom Rate Calculations

```solidity
// Calculate rates with custom parameters
(
    uint256 apr,
    uint256 epochMint,
    uint256 toStakers,
    uint256 toOps,
    uint256 toBurner
) = rebaseController.projectedEpochRateRaw(
    1000000e18,  // 1M USD PCV
    500000e18,   // 500K RZR supply
    300000e18    // 300K staked
);

console.log("Custom APR:", apr);
console.log("Custom Epoch Mint:", epochMint);
```

## Events

### Configuration Events

```solidity
event TargetPctsSet(uint256 targetOpsPct, uint256 minFloorPct, uint256 maxFloorPct, uint256 floorSlope);
event AprVariablesSet(uint16 floorApr, uint16 ceilApr, uint16 k1, uint16 k2);
```

### Execution Events

```solidity
event Rebased(uint256 epochMint, uint256 toStakers, uint256 toOps, uint256 toBurner);
```

## License

AGPL-3.0-only
