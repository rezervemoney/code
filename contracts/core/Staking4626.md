# Staking4626

**File**: [`Staking4626.sol`](./Staking4626.sol)

**License**: AGPL-3.0

**Test File**: [`test/foundry/Staking4626.t.sol`](../../test/foundry/Staking4626.t.sol)

## Overview

The `Staking4626` contract is an ERC4626-compliant staking vault that provides standardized staking functionality for RZR tokens. It implements the ERC4626 vault standard, enabling seamless integration with DeFi protocols while maintaining the protocol's staking mechanics and reward distribution.

## Purpose

This contract serves as:

- **ERC4626 Vault**: Standardized staking interface following ERC4626 standard
- **Staking Vault**: Secure vault for RZR token staking operations
- **Yield Distribution**: Automated yield distribution to stakers
- **DeFi Integration**: Compatible with all ERC4626-supporting protocols
- **Standard Compliance**: Full adherence to ERC4626 vault standard

## Architecture

### Inheritance

- `ERC4626` - OpenZeppelin ERC4626 vault implementation
- `AppAccessControlled` - Protocol access control integration
- `Initializable` - Upgradeable contract pattern

### Core Components

- **Vault Standard**: Full ERC4626 compliance for DeFi integration
- **Staking Logic**: Protocol-specific staking mechanics
- **Yield Management**: Automated yield calculation and distribution
- **Access Control**: Role-based permissions for vault operations

## Key Functions

### ERC4626 Standard Functions

#### Deposit

```solidity
function deposit(uint256 assets, address receiver) external returns (uint256 shares)
```

**Purpose**: Deposit RZR tokens and receive vault shares.

**Parameters:**

- `assets`: Amount of RZR tokens to deposit
- `receiver`: Address to receive the vault shares

**Returns**: Number of vault shares minted.

**Process:**

1. Transfer RZR tokens from user to vault
2. Calculate shares based on current exchange rate
3. Mint shares to receiver
4. Update vault state and user position

#### Mint

```solidity
function mint(uint256 shares, address receiver) external returns (uint256 assets)
```

**Purpose**: Mint vault shares by depositing RZR tokens.

**Parameters:**

- `shares`: Number of vault shares to mint
- `receiver`: Address to receive the vault shares

**Returns**: Amount of RZR tokens required.

**Process:**

1. Calculate required RZR amount for shares
2. Transfer RZR tokens from user to vault
3. Mint shares to receiver
4. Update vault state

#### Withdraw

```solidity
function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares)
```

**Purpose**: Withdraw RZR tokens by burning vault shares.

**Parameters:**

- `assets`: Amount of RZR tokens to withdraw
- `receiver`: Address to receive the RZR tokens
- `owner`: Address that owns the shares

**Returns**: Number of shares burned.

**Process:**

1. Calculate shares to burn for requested assets
2. Burn shares from owner
3. Transfer RZR tokens to receiver
4. Update vault state

#### Redeem

```solidity
function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets)
```

**Purpose**: Redeem vault shares for RZR tokens.

**Parameters:**

- `shares`: Number of vault shares to redeem
- `receiver`: Address to receive the RZR tokens
- `owner`: Address that owns the shares

**Returns**: Amount of RZR tokens received.

**Process:**

1. Calculate RZR amount for shares
2. Burn shares from owner
3. Transfer RZR tokens to receiver
4. Update vault state

### Vault Management Functions

#### Total Assets

```solidity
function totalAssets() public view returns (uint256)
```

**Purpose**: Get total RZR tokens in the vault.

**Returns**: Total amount of RZR tokens deposited.

#### Preview Functions

```solidity
function previewDeposit(uint256 assets) public view returns (uint256)
function previewMint(uint256 shares) public view returns (uint256)
function previewWithdraw(uint256 assets) public view returns (uint256)
function previewRedeem(uint256 shares) public view returns (uint256)
```

**Purpose**: Preview the outcome of vault operations without executing them.

**Usage**: Calculate expected shares/assets before performing operations.

#### Max Functions

```solidity
function maxDeposit(address) public view returns (uint256)
function maxMint(address) public view returns (uint256)
function maxWithdraw(address owner) public view returns (uint256)
function maxRedeem(address owner) public view returns (uint256)
```

**Purpose**: Get maximum amounts for vault operations.

**Usage**: Determine limits for user operations.

## Integration Points

### Protocol Contracts

- **RZR Token**: [`RZR.sol`](./RZR.sol) - Underlying staking token
- **sRZR Token**: [`sRZR.sol`](./sRZR.sol) - Staking derivative token
- **Treasury**: [`AppTreasury.sol`](./AppTreasury.sol) - Reserve management
- **Authority**: [`AppAuthority.sol`](./AppAuthority.sol) - Access control

### External Systems

- **DeFi Protocols**: All ERC4626-supporting protocols
- **DEX Integration**: Uniswap, Balancer, and other DEXs
- **Lending Protocols**: Aave, Compound, and other lending platforms
- **Yield Farming**: Integration with yield farming protocols

## ERC4626 Standard Compliance

### Vault Interface

- **Full ERC4626 Implementation**: Complete standard compliance
- **Standard Functions**: Deposit, mint, withdraw, redeem
- **Preview Functions**: All preview functions implemented
- **Max Functions**: All max functions implemented

### DeFi Integration

- **Protocol Compatibility**: Works with all ERC4626 protocols
- **Standard Events**: Emits standard ERC4626 events
- **Error Handling**: Standard error codes and messages
- **Gas Optimization**: Optimized for DeFi protocol usage

## Economic Model

### Share Calculation

- **Dynamic Shares**: Share calculation based on current vault state
- **Exchange Rate**: Shares to assets conversion rate
- **Yield Accrual**: Shares automatically accrue yield over time
- **Compounding Effect**: Reinvested yield compounds for holders

### Yield Distribution

- **Automatic Accrual**: Yield automatically increases share value
- **Proportional Distribution**: Yield distributed based on share holdings
- **No Claim Required**: Yield automatically compounds
- **Transparent Calculation**: All yield calculations visible on-chain

### Fee Structure

- **No Entry Fees**: No fees for depositing or minting
- **No Exit Fees**: No fees for withdrawing or redeeming
- **Yield Sharing**: Protocol shares in yield generation
- **Transparent Costs**: All costs visible and calculable

## Security Features

### Access Control

- **Role-Based Permissions**: Only authorized contracts can perform operations
- **Vault Management**: Controlled vault operations through authority system
- **Emergency Controls**: Pause functionality through authority contract

### Economic Security

- **Asset Backing**: All shares backed by actual RZR tokens
- **Yield Validation**: All yield calculations verified and transparent
- **Manipulation Protection**: Protected against common attack vectors

### Vault Safety

- **Standard Compliance**: Full ERC4626 standard implementation
- **OpenZeppelin Audited**: Uses audited OpenZeppelin contracts
- **No Backdoors**: All operations transparent and verifiable

## Usage Examples

### Basic Vault Operations

#### Deposit RZR Tokens

```solidity
// Deposit 1000 RZR tokens
Staking4626 vault = Staking4626(vaultAddress);
RZR rzr = RZR(rzrAddress);

// Approve vault to spend RZR
rzr.approve(address(vault), 1000e18);

// Deposit tokens
uint256 shares = vault.deposit(1000e18, msg.sender);
```

#### Mint Vault Shares

```solidity
// Mint 500 vault shares
uint256 assets = vault.previewMint(500e18);
rzr.approve(address(vault), assets);

uint256 actualAssets = vault.mint(500e18, msg.sender);
```

#### Withdraw RZR Tokens

```solidity
// Withdraw 500 RZR tokens
uint256 shares = vault.previewWithdraw(500e18);
uint256 actualShares = vault.withdraw(500e18, msg.sender, msg.sender);
```

#### Redeem Vault Shares

```solidity
// Redeem 300 vault shares
uint256 assets = vault.previewRedeem(300e18);
uint256 actualAssets = vault.redeem(300e18, msg.sender, msg.sender);
```

### DeFi Protocol Integration

#### Lending Protocol

```solidity
// Deposit vault shares in lending protocol
ILendingProtocol lending = ILendingProtocol(lendingAddress);
vault.approve(address(lending), shares);

lending.deposit(address(vault), shares, msg.sender, 0);
```

#### Yield Farming

```solidity
// Stake vault shares in yield farming
IYieldFarming farming = IYieldFarming(farmingAddress);
vault.approve(address(farming), shares);

farming.stake(shares);
```

#### DEX Trading

```solidity
// Trade vault shares on DEX
IUniswapV2Router router = IUniswapV2Router(routerAddress);
vault.approve(address(router), shares);

router.swapExactTokensForTokens(
    shares,
    minAmountOut,
    path,
    recipient,
    block.timestamp
);
```

## Events

### ERC4626 Standard Events

```solidity
event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);
```

### Vault-Specific Events

```solidity
event VaultStateUpdated(uint256 totalAssets, uint256 totalShares, uint256 exchangeRate);
event YieldDistributed(uint256 totalYield, uint256 timestamp);
```

## Testing

### Unit Tests

- ERC4626 standard function compliance
- Share calculation accuracy
- Yield distribution mechanisms
- Access control validation

### Integration Tests

- DeFi protocol integration
- Cross-contract token flows
- Treasury operations
- Authority system integration

### Security Tests

- Access control validation
- Economic attack vectors
- Manipulation prevention
- Integration security

## Deployment Considerations

### Initial Setup

1. **Deploy Contract**: Deploy Staking4626 vault contract
2. **Configure Authority**: Set up access control integration
3. **Set Permissions**: Configure role-based permissions
4. **Verify Integration**: Test with RZR token and treasury

### Configuration

1. **Authority Integration**: Connect to protocol authority system
2. **Token Integration**: Set up RZR token integration
3. **Initial Parameters**: Configure vault parameters
4. **Testing**: Verify all ERC4626 functionality

## Dependencies

### Core Dependencies

- **OpenZeppelin**: ERC4626, Initializable
- **AppAccessControlled**: Protocol access control integration
- **RZR Token**: Underlying staking token

### External Dependencies

- **ERC4626 Standard**: Vault standard compliance
- **DeFi Standards**: Integration with DeFi protocols

## Best Practices

### Vault Operations

1. **Gas Optimization**: Use preview functions before operations
2. **Batch Operations**: Combine multiple operations when possible
3. **Yield Monitoring**: Track yield accumulation and compounding
4. **DeFi Integration**: Leverage full ERC4626 compatibility

### Security Considerations

1. **Access Control**: Verify all vault operations are properly authorized
2. **Yield Validation**: Ensure yield calculations are accurate
3. **Integration Security**: Verify all external protocol integrations
4. **Monitoring**: Monitor vault state and operations

### User Experience

1. **Clear Documentation**: Provide clear vault operation instructions
2. **Gas Optimization**: Optimize gas costs for common operations
3. **Error Handling**: Provide clear error messages for failed operations
4. **Monitoring Tools**: Offer tools to track vault performance

## Testing

### Unit Tests

- ERC4626 compliance
- Deposit and withdrawal operations
- Share calculations
- Preview functions

**Test File**: [`test/foundry/Staking4626.t.sol`](../../test/foundry/Staking4626.t.sol)

### Integration Tests

- Protocol contract integration
- Treasury interaction testing
- Staking vault operations

### Security Tests

- Unauthorized access attempts
- Access control validation
- Reentrancy protection

## License

AGPL-3.0
