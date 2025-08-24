# sRZR Token

**File**: [`sRZR.sol`](./sRZR.sol)
**License**: AGPL-3.0

## Overview

The `sRZR` contract is the staking derivative token for the Rezerve.money protocol. It represents staked RZR positions and provides liquid staking functionality, allowing users to earn staking rewards while maintaining liquidity of their staked assets.

## Purpose

This contract serves as:

- **Liquid Staking Token**: Represents staked RZR positions with full liquidity
- **Yield Generation**: Automatic yield distribution to token holders
- **Staking Derivative**: ERC20 token backed by staked RZR
- **DeFi Integration**: Compatible with DeFi protocols and DEX trading
- **Reward Distribution**: Efficient distribution of staking rewards

## Architecture

### Inheritance

- `ERC20` - OpenZeppelin ERC20 implementation
- `ERC20Burnable` - Burnable token functionality
- `AppAccessControlled` - Protocol access control integration

### Core Components

- **Staking Vault**: Integration with staking contract for RZR staking
- **Yield Distribution**: Automatic reward distribution to sRZR holders
- **Liquidity Management**: Full liquidity for staked positions
- **Access Control**: Role-based permissions for staking operations

## Key Functions

### Token Information

#### Basic Token Details

```solidity
string public constant name = "Staked Rezerve.money";
string public constant symbol = "sRZR";
uint8 public constant decimals = 18;
```

**Purpose**: Standard ERC20 token metadata for identification and display.

### Staking Operations

#### Stake Function

```solidity
function stake(uint256 amount) external
```

**Purpose**: Stake RZR tokens and receive sRZR in return.

**Parameters:**

- `amount`: Amount of RZR tokens to stake

**Process:**

1. Transfer RZR from user to staking contract
2. Calculate sRZR shares based on current exchange rate
3. Mint sRZR tokens to user
4. Update staking position and rewards

#### Unstake Function

```solidity
function unstake(uint256 sRzrAmount) external
```

**Purpose**: Convert sRZR back to RZR tokens.

**Parameters:**

- `sRzrAmount`: Amount of sRZR tokens to unstake

**Process:**

1. Burn sRZR tokens from user
2. Calculate RZR amount based on current exchange rate
3. Transfer RZR tokens back to user
4. Update staking position

### Yield Distribution

#### Claim Rewards

```solidity
function claimRewards() external
```

**Purpose**: Claim accumulated staking rewards.

**Process:**

1. Calculate user's share of accumulated rewards
2. Transfer RZR rewards to user
3. Update reward tracking for user's position

#### Automatic Yield Distribution

```solidity
function distributeRewards(uint256 amount) external onlyStakingContract
```

**Purpose**: Distribute new staking rewards to all sRZR holders.

**Access Control**: Only the staking contract can call this function.

**Process:**

1. Receive RZR rewards from staking contract
2. Update global reward per share
3. Update user reward tracking

## Integration Points

### Protocol Contracts

- **Staking Contract**: [`AppStaking.sol`](./AppStaking.sol) - Core staking operations
- **RZR Token**: [`RZR.sol`](./RZR.sol) - Underlying staking token
- **Treasury**: [`AppTreasury.sol`](./AppTreasury.sol) - Reserve management
- **Authority**: [`AppAuthority.sol`](./AppAuthority.sol) - Access control

### External Systems

- **DEX Integration**: Uniswap, Balancer, and other DEXs for sRZR trading
- **DeFi Protocols**: Lending, yield farming, and other DeFi integrations
- **Wallet Support**: MetaMask and other wallet applications

## Economic Model

### Exchange Rate Mechanism

- **Dynamic Rate**: Exchange rate between RZR and sRZR changes based on rewards
- **Reward Accumulation**: Rewards increase the value of sRZR over time
- **Compounding Effect**: Reinvested rewards compound for existing holders

### Yield Distribution

- **Proportional Distribution**: Rewards distributed based on sRZR holdings
- **Automatic Compounding**: Rewards automatically increase sRZR value
- **Claim Flexibility**: Users can claim rewards or let them compound

### Liquidity Benefits

- **Immediate Liquidity**: sRZR can be traded immediately
- **No Lock-up Period**: No minimum staking duration
- **DEX Trading**: Full integration with decentralized exchanges

## Security Features

### Access Control

- **Role-Based Permissions**: Only authorized contracts can perform staking operations
- **Staking Contract Integration**: Direct integration with main staking contract
- **Emergency Controls**: Pause functionality through authority contract

### Economic Security

- **Backing Verification**: sRZR always backed by actual staked RZR
- **Reward Validation**: All rewards verified through staking contract
- **Exchange Rate Safety**: Protected against manipulation through staking mechanics

### Token Safety

- **Standard Compliance**: Full ERC20 standard implementation
- **OpenZeppelin Audited**: Uses audited OpenZeppelin contracts
- **No Backdoors**: All operations transparent and verifiable

## Usage Examples

### Basic Staking Operations

#### Stake RZR Tokens

```solidity
// Stake 1000 RZR tokens
RZR rzr = RZR(rzrAddress);
sRZR srzr = sRZR(srzrAddress);

// Approve sRZR contract to spend RZR
rzr.approve(address(srzr), 1000e18);

// Stake tokens
srzr.stake(1000e18);
```

#### Unstake sRZR Tokens

```solidity
// Unstake 500 sRZR tokens
srzr.unstake(500e18);
```

#### Claim Rewards

```solidity
// Claim accumulated staking rewards
srzr.claimRewards();
```

### DeFi Integration

#### DEX Trading

```solidity
// Trade sRZR on Uniswap
IUniswapV2Router router = IUniswapV2Router(routerAddress);
srzr.approve(address(router), amount);

router.swapExactTokensForTokens(
    amount,
    minAmountOut,
    path,
    recipient,
    block.timestamp
);
```

#### Yield Farming

```solidity
// Deposit sRZR in yield farming protocol
IYieldFarming farming = IYieldFarming(farmingAddress);
srzr.approve(address(farming), amount);

farming.deposit(amount);
```

## Events

### Staking Events

```solidity
event Staked(address indexed user, uint256 rzrAmount, uint256 sRzrAmount);
event Unstaked(address indexed user, uint256 sRzrAmount, uint256 rzrAmount);
event RewardsClaimed(address indexed user, uint256 amount);
event RewardsDistributed(uint256 totalAmount);
```

### Standard ERC20 Events

```solidity
event Transfer(address indexed from, address indexed to, uint256 value);
event Approval(address indexed owner, address indexed spender, uint256 value);
```

## Testing

### Unit Tests

- Staking and unstaking functionality
- Reward distribution mechanisms
- Exchange rate calculations
- Access control validation

### Integration Tests

- Staking contract integration
- Treasury operations
- Cross-contract token flows
- DeFi protocol integration

### Security Tests

- Access control validation
- Economic attack vectors
- Reward manipulation prevention
- Integration security

## Deployment Considerations

### Initial Setup

1. **Deploy Contract**: Deploy sRZR token contract
2. **Configure Staking**: Set up staking contract integration
3. **Set Permissions**: Configure access control and permissions
4. **Verify Integration**: Test with staking and treasury contracts

### Configuration

1. **Staking Integration**: Connect to main staking contract
2. **Access Control**: Set up role-based permissions
3. **Initial Parameters**: Configure exchange rate and reward mechanisms
4. **Testing**: Verify all staking and reward functionality

## Dependencies

### Core Dependencies

- **OpenZeppelin**: ERC20, ERC20Burnable
- **AppAccessControlled**: Protocol access control integration
- **AppStaking**: Core staking contract integration

### External Dependencies

- **ERC20 Standard**: Ethereum token standard compliance
- **DeFi Standards**: Integration with DeFi protocols and DEXs

## Best Practices

### Staking Operations

1. **Reward Optimization**: Consider timing of reward claims vs. compounding
2. **Liquidity Management**: Balance staking rewards with trading needs
3. **Gas Optimization**: Batch operations when possible
4. **Monitoring**: Track exchange rates and reward accumulation

### Security Considerations

1. **Access Control**: Verify all staking operations are properly authorized
2. **Reward Validation**: Ensure rewards are properly distributed
3. **Exchange Rate Safety**: Monitor for manipulation attempts
4. **Integration Security**: Verify all external contract integrations

### User Experience

1. **Clear Documentation**: Provide clear staking and reward instructions
2. **Gas Optimization**: Optimize gas costs for common operations
3. **Error Handling**: Provide clear error messages for failed operations
4. **Monitoring Tools**: Offer tools to track staking performance

## Testing

### Unit Tests

- Staking functionality
- Unstaking operations
- Reward distribution
- Penalty calculations

**Test File**: [`test/foundry/Staking4626.t.sol`](../../test/foundry/Staking4626.t.sol)

### Integration Tests

- Protocol contract integration
- Treasury interaction testing
- Staking vault operations

### Security Tests

- Unauthorized staking attempts
- Access control validation
- Reward manipulation prevention

## License

AGPL-3.0
