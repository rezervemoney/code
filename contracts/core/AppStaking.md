# AppStaking

**File**: [`AppStaking.sol`](./AppStaking.sol)
**License**: AGPL-3.0

## Overview

The `AppStaking` contract is the main staking contract for the Rezerve.money protocol. It manages RZR token staking operations, reward distribution, and staking position management through a sophisticated time-based staking system with reward multipliers and penalty mechanisms.

## Purpose

This contract serves as:

- **Core Staking**: Primary staking functionality for RZR tokens
- **Reward Distribution**: Automated reward calculation and distribution
- **Position Management**: Staking position tracking and management
- **Time-Based Rewards**: Staking duration-based reward multipliers
- **Penalty System**: Early withdrawal penalties and lock-up mechanisms

## Architecture

### Inheritance

- `AppAccessControlled` - Protocol access control integration
- `Initializable` - Upgradeable contract pattern

### Core Components

- **Staking Positions**: User staking position tracking and management
- **Reward System**: Automated reward calculation and distribution
- **Time Mechanics**: Staking duration and lock-up period management
- **Penalty Logic**: Early withdrawal penalty calculations and enforcement

## Key Functions

### Staking Operations

#### Stake Tokens

```solidity
function stake(uint256 amount, uint256 lockDuration) external
```

**Purpose**: Stake RZR tokens for a specified lock duration.

**Parameters**:

- `amount`: Amount of RZR tokens to stake
- `lockDuration`: Duration to lock staked tokens (in seconds)

**Process**:

1. Transfer RZR tokens from user to staking contract
2. Create staking position with lock duration
3. Calculate reward multiplier based on lock duration
4. Update user staking balance and total staked

#### Unstake Tokens

```solidity
function unstake(uint256 amount) external
```

**Purpose**: Unstake RZR tokens after lock period expires.

**Parameters**: `amount` - Amount of RZR tokens to unstake.

**Requirements**: Lock period must have expired.

**Process**:

1. Verify lock period has expired
2. Calculate rewards for the position
3. Transfer RZR tokens and rewards to user
4. Update staking position and total staked

#### Emergency Unstake

```solidity
function emergencyUnstake(uint256 amount) external
```

**Purpose**: Unstake tokens before lock period with penalty.

**Parameters**: `amount` - Amount of RZR tokens to emergency unstake.

**Penalty**: Early withdrawal penalty applied to rewards.

**Process**:

1. Calculate early withdrawal penalty
2. Transfer RZR tokens and reduced rewards
3. Apply penalty to protocol treasury
4. Update staking position

### Reward Management

#### Claim Rewards

```solidity
function claimRewards() external
```

**Purpose**: Claim accumulated staking rewards.

**Process**:

1. Calculate user's accumulated rewards
2. Transfer RZR rewards to user
3. Update reward tracking for user's position
4. Reset accumulated rewards

#### Calculate Rewards

```solidity
function calculateRewards(address user) public view returns (uint256)
```

**Purpose**: Calculate current rewards for a specific user.

**Parameters**: `user` - Address of the user to calculate rewards for.

**Returns**: Amount of accumulated rewards.

**Process**: Calculates rewards based on staking amount, duration, and time.

### Position Management

#### Get Staking Position

```solidity
function getStakingPosition(address user) external view returns (
    uint256 stakedAmount,
    uint256 lockStartTime,
    uint256 lockDuration,
    uint256 rewardMultiplier,
    uint256 accumulatedRewards
)
```

**Purpose**: Get detailed information about a user's staking position.

**Parameters**: `user` - Address of the user.

**Returns**: Complete staking position information.

#### Get Total Staked

```solidity
function getTotalStaked() external view returns (uint256)
```

**Purpose**: Get total amount of RZR tokens currently staked.

**Returns**: Total staked amount across all users.

## Integration Points

### Protocol Contracts

- **RZR Token**: [`RZR.sol`](./RZR.sol) - Core staking token
- **Treasury**: [`AppTreasury.sol`](./AppTreasury.sol) - Reward funding and penalty collection
- **sRZR Token**: [`sRZR.sol`](./sRZR.sol) - Liquid staking derivative
- **Authority**: [`AppAuthority.sol`](./AppAuthority.sol) - Access control

### External Systems

- **Reward Distribution**: Automated reward distribution system
- **Penalty Collection**: Penalty funds sent to treasury
- **Staking Analytics**: Staking metrics and reporting

## Economic Model

### Reward Multipliers

- **Time-Based Multipliers**: Longer lock periods = higher rewards
- **Multiplier Calculation**: Based on lock duration and base rate
- **Maximum Multiplier**: Cap on maximum reward multiplier
- **Dynamic Adjustment**: Multipliers can be updated by governance

### Penalty System

- **Early Withdrawal Penalty**: Penalty for unstaking before lock expires
- **Penalty Calculation**: Based on remaining lock time and staked amount
- **Penalty Distribution**: Penalties sent to protocol treasury
- **Penalty Rates**: Configurable penalty rates by governance

### Staking Mechanics

- **Lock Periods**: Configurable staking lock durations
- **Minimum Stakes**: Minimum staking amounts
- **Maximum Stakes**: Maximum staking limits per user
- **Compound Rewards**: Rewards can be restaked for compounding

## Security Features

### Access Control

- **Role-Based Permissions**: Only authorized roles can perform operations
- **Staking Controls**: Controlled staking and unstaking operations
- **Reward Management**: Controlled reward distribution
- **Emergency Controls**: Emergency pause functionality

### Economic Security

- **Penalty Enforcement**: Automatic penalty calculation and collection
- **Reward Validation**: All reward calculations verified
- **Lock Enforcement**: Lock periods strictly enforced
- **Overflow Protection**: Safe math operations for all calculations

### Operational Security

- **Position Validation**: All staking positions validated
- **State Consistency**: Consistent state across all operations
- **Event Logging**: Complete transparency of all operations
- **Emergency Procedures**: Emergency response capabilities

## Usage Examples

### Basic Staking Operations

#### Stake RZR Tokens

```solidity
// Stake 1000 RZR for 30 days
AppStaking staking = AppStaking(stakingAddress);
RZR rzr = RZR(rzrAddress);

// Approve staking contract to spend RZR
rzr.approve(address(staking), 1000e18);

// Stake tokens for 30 days (30 * 24 * 60 * 60 seconds)
uint256 lockDuration = 30 days;
staking.stake(1000e18, lockDuration);
```

#### Check Staking Position

```solidity
// Get user's staking position
(
    uint256 stakedAmount,
    uint256 lockStartTime,
    uint256 lockDuration,
    uint256 rewardMultiplier,
    uint256 accumulatedRewards
) = staking.getStakingPosition(msg.sender);

console.log("Staked Amount:", stakedAmount);
console.log("Lock Duration:", lockDuration);
console.log("Reward Multiplier:", rewardMultiplier);
console.log("Accumulated Rewards:", accumulatedRewards);
```

#### Unstake After Lock Period

```solidity
// Unstake tokens after lock period expires
staking.unstake(1000e18);
```

#### Emergency Unstake

```solidity
// Emergency unstake with penalty
staking.emergencyUnstake(500e18);
```

### Reward Management

#### Check Rewards

```solidity
// Calculate current rewards
uint256 rewards = staking.calculateRewards(msg.sender);
console.log("Current Rewards:", rewards);
```

#### Claim Rewards

```solidity
// Claim accumulated rewards
staking.claimRewards();
```

### Staking Analytics

#### Get Total Staked

```solidity
// Get total protocol staking
uint256 totalStaked = staking.getTotalStaked();
console.log("Total Protocol Staking:", totalStaked);
```

## Events

### Staking Events

```solidity
event TokensStaked(address indexed user, uint256 amount, uint256 lockDuration, uint256 rewardMultiplier);
event TokensUnstaked(address indexed user, uint256 amount, uint256 rewards);
event EmergencyUnstake(address indexed user, uint256 amount, uint256 rewards, uint256 penalty);
```

### Reward Events

```solidity
event RewardsClaimed(address indexed user, uint256 amount);
event RewardsDistributed(uint256 totalAmount, uint256 timestamp);
```

### Management Events

```solidity
event StakingParametersUpdated(uint256 baseRewardRate, uint256 maxMultiplier, uint256 penaltyRate);
event LockDurationUpdated(uint256 oldDuration, uint256 newDuration);
```

## Testing

### Unit Tests

- Staking and unstaking functionality
- Reward calculation accuracy
- Penalty calculation and enforcement
- Lock period validation

### Integration Tests

- Cross-contract token flows
- Treasury integration testing
- Reward distribution workflows
- Authority system integration

### Security Tests

- Access control validation
- Economic attack vectors
- Penalty manipulation prevention
- Emergency procedure testing

## Deployment Considerations

### Initial Setup

1. **Deploy Contract**: Deploy AppStaking contract
2. **Configure Authority**: Set up access control integration
3. **Set Parameters**: Configure staking parameters and rates
4. **Verify Integration**: Test with RZR token and treasury

### Configuration

1. **Authority Integration**: Connect to protocol authority system
2. **Staking Parameters**: Set base reward rates and multipliers
3. **Lock Durations**: Configure available lock duration options
4. **Penalty Rates**: Set early withdrawal penalty rates

## Dependencies

### Core Dependencies

- **AppAccessControlled**: Protocol access control integration
- **Initializable**: Upgradeable contract pattern
- **RZR Token**: Core staking token integration

### External Dependencies

- **Treasury System**: Reward funding and penalty collection
- **Oracle System**: Price feeds for reward calculations
- **Governance**: Parameter updates and policy changes

## Best Practices

### Staking Operations

1. **Lock Duration Selection**: Choose appropriate lock duration for goals
2. **Reward Optimization**: Maximize rewards through strategic staking
3. **Penalty Avoidance**: Avoid early withdrawal penalties
4. **Compound Rewards**: Restake rewards for compounding growth

### Security Considerations

1. **Access Control**: Verify all staking operations are properly authorized
2. **Reward Validation**: Ensure reward calculations are accurate
3. **Penalty Enforcement**: Verify penalty calculations and collection
4. **Emergency Procedures**: Test emergency response capabilities

### User Experience

1. **Clear Documentation**: Provide clear staking instructions
2. **Reward Transparency**: Show clear reward calculations
3. **Penalty Awareness**: Clearly communicate penalty implications
4. **Monitoring Tools**: Offer tools to track staking performance

## License

AGPL-3.0
