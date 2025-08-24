# AppBurner

**File**: [`AppBurner.sol`](./AppBurner.sol)

**License**: AGPL-3.0

**Test File**: [`test/foundry/AppBurnerTest.t.sol`](../../test/foundry/AppBurnerTest.t.sol)

## Overview

The `AppBurner` contract is a token burning mechanism for the Rezerve.money protocol that provides controlled token burning for deflationary pressure and supply management. It implements various burning strategies and mechanisms to manage the RZR token supply effectively.

## Purpose

This contract serves as:

- **Supply Management**: Controlled reduction of RZR token supply
- **Deflationary Pressure**: Create deflationary pressure for token appreciation
- **Economic Balance**: Balance inflationary and deflationary forces
- **Protocol Integration**: Integration with other protocol mechanisms
- **Burning Strategies**: Multiple burning strategies and mechanisms

## Architecture

### Inheritance

- `AppAccessControlled` - Protocol access control integration
- `Initializable` - Upgradeable contract pattern

### Core Components

- **Balance Burning**: Burns entire RZR balance of the contract
- **Floor Price Updates**: Automatically updates RZR floor price after burning
- **Price Calculation**: Exponential formula for floor price updates
- **Token Recovery**: ERC20 token recovery functionality
- **Contract Execution**: Arbitrary function execution capability

## Key Functions

### Burning Operations

#### Burn Contract Balance

```solidity
function burn() external onlyExecutor
```

**Purpose**: Burn the entire balance of RZR tokens held by the burner contract.

**Access Control**: Only executors can burn tokens.

**Process**:

1. Get current RZR balance of the contract
2. Calculate new floor price based on burn amount
3. Validate floor price increase constraints
4. Burn all tokens and update floor price
5. Emit burn event with amount and new floor price

### Floor Price Management

#### Calculate Floor Update

```solidity
function calculateFloorUpdate(uint256 amountToBurn, uint256 totalSupply, uint256 floorPrice) public pure returns (uint256 newFloorPrice)
```

**Purpose**: Calculate new floor price based on burn amount and total supply.

**Parameters**:

- `amountToBurn`: Amount of tokens to burn
- `totalSupply`: Total supply of RZR tokens
- `floorPrice`: Current floor price

**Returns**: New calculated floor price.

**Process**: Uses exponential formula to calculate price multiplier based on burn percentage.

### Contract Management

#### Recover ERC20 Tokens

```solidity
function recoverERC20(address token, uint256 amount) external onlyGovernor
```

**Purpose**: Recover ERC20 tokens from the contract.

**Access Control**: Only governors can recover tokens.

**Parameters**:

- `token`: Address of the token to recover
- `amount`: Amount of tokens to recover

**Process**: Transfers tokens to operations treasury.

#### Execute Function

```solidity
function execute(address _to, uint256 _value, bytes calldata _data) external onlyGovernor
```

**Purpose**: Execute arbitrary function calls on other contracts.

**Access Control**: Only governors can execute functions.

**Parameters**:

- `_to`: Target contract address
- `_value`: ETH value to send
- `_data`: Function call data

## Integration Points

### Protocol Contracts

- **RZR Token**: [`RZR.sol`](./RZR.sol) - Token burning operations
- **AppOracle**: [`AppOracle.sol`](./AppOracle.sol) - Floor price management
- **Authority**: [`AppAuthority.sol`](./AppAuthority.sol) - Access control
- **App Contract**: Main protocol contract for token operations

### External Systems

- **Supply Analytics**: Token supply tracking and reporting
- **Economic Models**: Economic analysis and modeling
- **Burning Strategies**: External strategy management systems

## Usage Examples

### Basic Burning Operations

#### Burn Contract Balance

```solidity
// Burn all RZR tokens in the burner contract
AppBurner burner = AppBurner(burnerAddress);

burner.burn();
```

### Floor Price Calculations

#### Calculate New Floor Price

```solidity
// Calculate new floor price for burning 1000 tokens
uint256 newFloorPrice = burner.calculateFloorUpdate(
    1000e18,        // Amount to burn
    1000000e18,     // Total supply
    1e18            // Current floor price
);

console.log("New Floor Price:", newFloorPrice);
```

### Contract Management

#### Recover ERC20 Tokens

```solidity
// Recover USDC tokens from the contract
burner.recoverERC20(usdcAddress, 1000e6);
```

#### Execute Function Call

```solidity
// Execute a function on another contract
bytes memory data = abi.encodeWithSignature("someFunction(uint256)", 123);
burner.execute(targetContract, 0, data);
```

## License

AGPL-3.0
