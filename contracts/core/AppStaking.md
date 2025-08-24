# AppStaking

**File**: [`AppStaking.sol`](./AppStaking.sol)

**License**: AGPL-3.0

**Test File**: [`test/foundry/AppStakingTest.t.sol`](../../test/foundry/AppStakingTest.t.sol)

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

#### Create Position

```solidity
function createPosition(address to, uint256 amount, uint256 declaredValue, uint256 minLockDuration) external returns (uint256 tokenId, uint256 taxPaid)
```

**Purpose**: Create a new staking position as an NFT.

**Parameters**:

- `to` - Address to receive the position NFT
- `amount` - Amount of RZR tokens to stake
- `declaredValue` - Declared value for tax calculation
- `minLockDuration` - Minimum lock duration for the position

**Returns**: `tokenId` - NFT token ID, `taxPaid` - Deposit fee paid

**Process**: Transfers RZR tokens, mints NFT, calculates streaming tax rate

#### Start Unstaking

```solidity
function startUnstaking(uint256 tokenId) external
```

**Purpose**: Begin the unstaking process for a position.

**Parameters**: `tokenId` - NFT token ID of the position.

**Requirements**: Must be position owner, not already in cooldown.

**Process**: Starts withdrawal cooldown period.

#### Complete Unstaking

```solidity
function completeUnstaking(uint256 tokenId) external
```

**Purpose**: Complete unstaking after cooldown period.

**Parameters**: `tokenId` - NFT token ID of the position.

**Requirements**: Cooldown period must have expired.

**Process**: Transfers RZR tokens back to user and burns NFT.

### Position Management

#### Buy Position

```solidity
function buyPosition(uint256 tokenId) external
```

**Purpose**: Buy an existing staking position from another user.

**Parameters**: `tokenId` - NFT token ID to purchase.

**Requirements**: Cannot buy own position, position not in buy cooldown.

**Process**: Transfers RZR tokens, pays resell fee, transfers NFT.

#### Split Position

```solidity
function splitPosition(uint256 tokenId, uint256 splitRatio, address to) external returns (uint256 newTokenId)
```

**Purpose**: Split a position into two separate positions.

**Parameters**:

- `tokenId` - Original position ID
- `splitRatio` - Ratio to split (0-1e18)
- `to` - Recipient of new position

**Returns**: `newTokenId` - ID of the new split position.

#### Merge Positions

```solidity
function mergePositions(uint256 tokenId1, uint256 tokenId2) external returns (uint256 mergedTokenId)
```

**Purpose**: Merge two positions owned by the same user.

**Parameters**: `tokenId1`, `tokenId2` - Position IDs to merge.

**Returns**: `mergedTokenId` - ID of the merged position.

**Requirements**: Must own both positions, neither in cooldown.

### Reward Management

#### Claim Rewards

```solidity
function claimRewards(uint256 tokenId) external returns (uint256 reward)
```

**Purpose**: Claim accumulated rewards for a specific position.

**Parameters**: `tokenId` - NFT token ID of the position.

**Returns**: `reward` - Amount of rewards claimed.

**Process**: Calculates and transfers accumulated rewards to position owner.

#### Calculate Rewards

```solidity
function earned(uint256 tokenId) public view returns (uint256)
```

**Purpose**: Calculate current unclaimed rewards for a position.

**Parameters**: `tokenId` - NFT token ID of the position.

**Returns**: Amount of accumulated rewards.

**Process**: Calculates rewards based on staking amount and time.

#### Notify Reward Amount

```solidity
function notifyRewardAmount(uint256 reward) external onlyPolicy
```

**Purpose**: Add new rewards to the staking pool.

**Parameters**: `reward` - Amount of RZR tokens to add as rewards.

**Access Control**: Only policy role members can add rewards.

**Process**: Updates reward rate and distribution period.

### Tax Management

#### Collect Streaming Tax

```solidity
function collectStreamingTax(uint256 id) external returns (uint256 tax, uint256 credit)
```

**Purpose**: Collect streaming tax from a position.

**Parameters**: `id` - NFT token ID of the position.

**Returns**: `tax` - Tax amount collected, `credit` - Credit used.

**Process**: Calculates and collects harberger tax, burns taxed tokens.

#### Calculate Streaming Tax

```solidity
function calculateStreamingTax(uint256 id) external view returns (uint256 tax)
```

**Purpose**: Calculate streaming tax owed for a position.

**Parameters**: `id` - NFT token ID of the position.

**Returns**: Amount of tax owed.

**Process**: Calculates tax based on declared value and time elapsed.

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

### Harberger Tax System

- **Streaming Tax**: Continuous tax based on declared position value
- **Tax Rate**: Configurable harberger tax rate (default: 5%)
- **Declared Value**: Users declare their position value for tax calculation
- **Tax Collection**: Automatic tax collection with configurable intervals

### Position Trading

- **Buy/Sell Positions**: Users can buy and sell existing staking positions
- **Resell Fees**: 1% fee on position sales to prevent gaming
- **Cooldown Periods**: Buy and withdrawal cooldowns to prevent manipulation
- **Position Splitting**: Users can split positions into smaller ones

### Staking Mechanics

- **NFT-Based**: Each staking position is a unique NFT
- **Lock Periods**: Configurable minimum lock durations
- **Cooldown System**: Withdrawal cooldown periods for stability
- **Tracking Tokens**: Separate tracking tokens for position management

## Security Features

### Access Control

- **Role-Based Permissions**: Only authorized roles can perform operations
- **Staking Controls**: Controlled staking and unstaking operations
- **Reward Management**: Controlled reward distribution
- **Emergency Controls**: Emergency pause functionality

### Economic Security

- **Tax Enforcement**: Automatic harberger tax calculation and collection
- **Reward Validation**: All reward calculations verified
- **Cooldown Enforcement**: Cooldown periods strictly enforced
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

## Testing

### Unit Tests

- Staking functionality
- Unstaking operations
- Reward calculations
- Penalty system

**Test File**: [`test/foundry/AppStakingTest.t.sol`](../../test/foundry/AppStakingTest.t.sol)

### Integration Tests

- Protocol contract integration
- Treasury interaction testing
- Oracle operations

### Security Tests

- Unauthorized access attempts
- Access control validation
- Reward manipulation prevention

## License

AGPL-3.0
