# sRZR Token

**File**: [`sRZR.sol`](./sRZR.sol)

**License**: AGPL-3.0

## Overview

The `sRZR` contract is the staking derivative token for the Rezerve.money protocol. It represents staked RZR positions and provides a non-transferable staking token that can only be minted and burned by the authorized staking contract.

## Purpose

This contract serves as:

- **Staking Token**: Represents staked RZR positions
- **Non-Transferable**: Prevents trading of staking positions
- **Controlled Minting**: Only staking contract can mint/burn tokens
- **Staking Integration**: Integrates with the protocol's staking system
- **Position Tracking**: Tracks staked positions through token balances

## Architecture

### Inheritance

- `ERC20Permit` - OpenZeppelin ERC20 with permit functionality
- `AppAccessControlled` - Protocol access control integration

### Core Components

- **Staking Contract Integration**: Controlled minting and burning by staking contract
- **Non-Transferable**: Transfer functions are disabled
- **Access Control**: Role-based permissions for staking operations
- **Position Tracking**: Token balances represent staked positions

## Key Functions

### Token Information

#### Basic Token Details

```solidity
string public constant name = "Staked Rezerve.money";
string public constant symbol = "sRZR";
uint8 public constant decimals = 18;
```

**Purpose**: Standard ERC20 token metadata for identification and display.

### Staking Contract Management

#### Set Staking Contract

```solidity
function setStakingContract(address _stakingContract) external onlyGovernor
```

**Purpose**: Set the address of the staking contract that can mint and burn tokens.

**Access Control**: Only governors can set the staking contract.

**Parameters**: `_stakingContract` - Address of the staking contract.

**Process**: Updates the staking contract address and emits event.

### Token Operations

#### Mint Tokens

```solidity
function mint(address to, uint256 amount) external onlyStakingContract
```

**Purpose**: Mint sRZR tokens to represent staked positions.

**Access Control**: Only the staking contract can mint tokens.

**Parameters**:

- `to` - Address to receive the minted tokens
- `amount` - Amount of tokens to mint

**Process**: Mints tokens to the specified address.

#### Burn Tokens

```solidity
function burn(address from, uint256 amount) external onlyStakingContract
```

**Purpose**: Burn sRZR tokens when positions are unstaked.

**Access Control**: Only the staking contract can burn tokens.

**Parameters**:

- `from` - Address to burn tokens from
- `amount` - Amount of tokens to burn

**Process**: Burns tokens from the specified address.

### Disabled Functions

#### Transfer (Disabled)

```solidity
function transfer(address to, uint256 value) public override returns (bool)
```

**Purpose**: This function is disabled and will always revert.

**Returns**: Always reverts with "transfer not allowed" message.

**Note**: sRZR tokens cannot be transferred between addresses.

#### Transfer From (Disabled)

```solidity
function transferFrom(address from, address to, uint256 value) public override returns (bool)
```

**Purpose**: This function is disabled and will always revert.

**Returns**: Always reverts with "transfer not allowed" message.

**Note**: sRZR tokens cannot be transferred between addresses.

## License

AGPL-3.0
