# RZR Token

**File**: [`RZR.sol`](./RZR.sol)

**License**: AGPL-3.0

## Overview

The `RZR` contract is the core ERC20 token contract for the Rezerve.money protocol. It implements the standard ERC20 functionality with additional features for protocol governance, staking, and economic mechanisms.

## Purpose

This contract serves as:

- **Protocol Token**: Native token for the Rezerve.money ecosystem
- **Governance Token**: Used for protocol governance and decision-making
- **Staking Token**: Base token for staking and yield generation
- **Economic Unit**: Primary unit of account for protocol operations
- **Reward Distribution**: Token used for incentives and rewards

## Architecture

### Inheritance

- `ERC20` - OpenZeppelin ERC20 implementation
- `ERC20Burnable` - Burnable token functionality
- `ERC20Permit` - Permit functionality for gasless approvals

### Core Components

- **Token Standard**: Full ERC20 compliance
- **Minting Control**: Controlled minting for protocol operations
- **Burning Capability**: Token burning for deflationary mechanics
- **Permit Support**: EIP-2612 permit for gasless transactions

## Key Functions

### Token Information

#### Basic Token Details

```solidity
string public constant name = "Rezerve.money";
string public constant symbol = "RZR";
uint8 public constant decimals = 18;
```

**Purpose**: Standard ERC20 token metadata for identification and display.

### Minting Control

#### Mint Function

```solidity
function mint(address to, uint256 amount) external
```

**Access Control**: Only authorized contracts can mint new tokens.

**Parameters:**

- `to`: Address to receive the minted tokens
- `amount`: Amount of tokens to mint

**Usage**: Used by protocol contracts to create new tokens for:

- Staking rewards
- Bond payouts
- Protocol incentives
- Treasury operations

### Burning Functionality

#### Burn Function

```solidity
function burn(uint256 amount) external
```

**Purpose**: Allows token holders to burn their own tokens.

**Parameters:**

- `amount`: Amount of tokens to burn

**Usage**: Token holders can burn tokens for:

- Deflationary pressure
- Protocol participation
- Economic incentives

#### Burn From Function

```solidity
function burnFrom(address account, uint256 amount) external
```

**Purpose**: Allows burning tokens from another account with allowance.

**Parameters:**

- `account`: Account to burn tokens from
- `amount`: Amount of tokens to burn

**Usage**: Used by protocol contracts to burn tokens from users with proper authorization.

### Permit Functionality

#### Permit Function

```solidity
function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
) external
```

**Purpose**: EIP-2612 permit for gasless token approvals.

**Parameters:**

- `owner`: Token owner
- `spender`: Address to approve
- `value`: Amount to approve
- `deadline`: Expiration timestamp
- `v, r, s`: ECDSA signature components

**Usage**: Enables gasless token approvals for better user experience.

## Integration Points

### Protocol Contracts

- **Treasury**: [`AppTreasury.sol`](./AppTreasury.sol) - Token minting and management
- **Staking**: [`AppStaking.sol`](./AppStaking.sol) - Staking rewards and distribution
- **Bonds**: [`AppBondDepository.sol`](./AppBondDepository.sol) - Bond payouts
- **Oracle**: Oracle contracts for price feeds

### External Systems

- **DEX Integration**: Uniswap, Balancer, and other DEXs
- **Wallet Support**: MetaMask and other wallet applications
- **DeFi Protocols**: Integration with lending and yield protocols

## Economic Model

### Token Supply

- **Initial Supply**: Set during deployment
- **Minting**: Controlled by protocol contracts
- **Burning**: User-initiated and protocol-controlled
- **Maximum Supply**: No hard cap (inflationary/deflationary based on protocol activity)

### Distribution Mechanisms

- **Staking Rewards**: Tokens distributed to stakers
- **Bond Payouts**: Tokens distributed for bond purchases
- **Protocol Incentives**: Tokens for protocol participation
- **Treasury Operations**: Tokens for protocol development

### Deflationary Pressures

- **User Burning**: Voluntary token burning
- **Protocol Burning**: Automatic burning through mechanisms
- **Staking Lock**: Tokens locked in staking positions

## Security Features

### Access Control

- **Minting Control**: Only authorized contracts can mint
- **Role-Based Access**: Integration with protocol authority system
- **Emergency Controls**: Pause functionality through authority contract

### Token Safety

- **Standard Compliance**: Full ERC20 standard implementation
- **OpenZeppelin Audited**: Uses audited OpenZeppelin contracts
- **No Backdoors**: No hidden minting or burning functions

### Economic Safety

- **Controlled Inflation**: Minting controlled by protocol logic
- **Transparent Operations**: All operations visible on-chain
- **Governance Control**: Protocol parameters controlled by governance

## Usage Examples

### Basic Token Operations

#### Transfer Tokens

```solidity
// Transfer tokens to another address
RZR rzr = RZR(rzrAddress);
rzr.transfer(recipientAddress, amount);
```

#### Approve Spending

```solidity
// Approve another contract to spend tokens
rzr.approve(spenderAddress, amount);
```

#### Permit Approval (Gasless)

```solidity
// Gasless approval using permit
rzr.permit(owner, spender, value, deadline, v, r, s);
```

### Protocol Integration

#### Minting Tokens

```solidity
// Only authorized contracts can mint
function distributeRewards(address user, uint256 amount) external {
    require(authority.isReserveManager(msg.sender), "Not authorized");
    rzr.mint(user, amount);
}
```

#### Burning Tokens

```solidity
// Burn tokens for deflationary pressure
function burnTokens(uint256 amount) external {
    rzr.burn(amount);
    emit TokensBurned(msg.sender, amount);
}
```

## Events

### Standard ERC20 Events

```solidity
event Transfer(address indexed from, address indexed to, uint256 value);
event Approval(address indexed owner, address indexed spender, uint256 value);
```

### Permit Events

```solidity
event Permit(address indexed owner, address indexed spender, uint256 value, uint256 deadline);
```

## Testing

### Unit Tests

- Token minting functionality
- Burning operations
- Transfer and approval mechanisms
- Permit functionality
- Access control validation

### Integration Tests

- Protocol contract integration
- DEX interaction testing
- Wallet compatibility
- Cross-contract token flows

### Security Tests

- Unauthorized minting attempts
- Access control validation
- Economic attack vectors
- Integration security

## Deployment Considerations

### Initial Setup

1. **Deploy Contract**: Deploy RZR token contract
2. **Configure Authority**: Set up minting permissions
3. **Initial Distribution**: Mint initial token supply
4. **Verify Integration**: Test with protocol contracts

### Configuration

1. **Minting Permissions**: Grant minting rights to authorized contracts
2. **Authority Integration**: Connect to protocol authority system
3. **Initial Supply**: Determine initial token distribution
4. **Economic Parameters**: Set up economic model parameters

## Dependencies

### Core Dependencies

- **OpenZeppelin**: ERC20, ERC20Burnable, ERC20Permit
- **Protocol Authority**: Integration with access control system

### External Dependencies

- **EIP-2612**: Permit standard for gasless approvals
- **ERC20 Standard**: Ethereum token standard compliance

## Best Practices

### Token Management

1. **Controlled Minting**: Limit minting to authorized contracts only
2. **Transparent Operations**: All operations should be visible on-chain
3. **Economic Balance**: Balance inflationary and deflationary pressures
4. **Governance Integration**: Integrate with protocol governance system

### Security Considerations

1. **Access Control**: Implement proper access controls for minting
2. **Audit Compliance**: Use audited OpenZeppelin contracts
3. **Emergency Procedures**: Include emergency pause functionality
4. **Monitoring**: Monitor token supply and distribution

### User Experience

1. **Gas Optimization**: Implement permit for gasless approvals
2. **Standard Compliance**: Full ERC20 standard implementation
3. **Wallet Support**: Ensure compatibility with major wallets
4. **Documentation**: Provide clear usage instructions

## Testing

### Unit Tests

- Token minting functionality
- Burning operations
- Permit functionality
- Access control validation

**Test File**: [`test/foundry/Staking4626.t.sol`](../../test/foundry/Staking4626.t.sol)

### Integration Tests

- Protocol contract integration
- DEX interaction testing
- Treasury operations

### Security Tests

- Unauthorized minting attempts
- Access control validation
- Permit signature verification

## License

AGPL-3.0
