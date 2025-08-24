# AppReferrals

**File**: [`AppReferrals.sol`](./AppReferrals.sol)
**License**: AGPL-3.0

## Overview

The `AppReferrals` contract is a referral system for the Rezerve.money protocol that tracks user referrals, calculates rewards, and manages the referral program. It provides incentives for user acquisition and community building through a sophisticated referral tracking and reward distribution system.

## Purpose

This contract serves as:

- **User Acquisition**: Incentivize new user onboarding
- **Referral Tracking**: Track referral relationships and performance
- **Reward Distribution**: Distribute rewards for successful referrals
- **Community Building**: Foster community growth and engagement
- **Growth Analytics**: Provide referral program analytics and insights

## Architecture

### Inheritance

- `AppAccessControlled` - Protocol access control integration
- `Initializable` - Upgradeable contract pattern

### Core Components

- **Referral Tracking**: User referral relationship management
- **Reward Calculation**: Referral reward calculation and distribution
- **Performance Analytics**: Referral performance tracking
- **Program Management**: Referral program configuration and management

## Key Functions

### Referral Management

#### Register Referral

```solidity
function registerReferral(address referrer, address referee) external
```

**Purpose**: Register a new referral relationship.

**Parameters**:

- `referrer`: Address of the user making the referral
- `referee`: Address of the user being referred

**Process**:

1. Validate referral parameters
2. Check referral eligibility
3. Create referral relationship
4. Update referral tracking
5. Emit referral registered event

#### Get Referrer

```solidity
function getReferrer(address user) external view returns (address)
```

**Purpose**: Get the referrer for a specific user.

**Parameters**: `user` - Address of the user to check.

**Returns**: Address of the user's referrer, or zero if none.

#### Get Referrals

```solidity
function getReferrals(address user) external view returns (address[] memory)
```

**Purpose**: Get all users referred by a specific user.

**Parameters**: `user` - Address of the referrer.

**Returns**: Array of addresses referred by the user.

### Reward Management

#### Calculate Referral Reward

```solidity
function calculateReferralReward(
    address referrer,
    address referee,
    uint256 activityAmount
) external view returns (uint256)
```

**Purpose**: Calculate referral reward for a specific activity.

**Parameters**:

- `referrer`: Address of the referrer
- `referee`: Address of the referee
- `activityAmount`: Amount of the activity for reward calculation

**Returns**: Calculated referral reward amount.

#### Distribute Referral Reward

```solidity
function distributeReferralReward(
    address referrer,
    address referee,
    uint256 activityAmount
) external onlyReserveManager
```

**Purpose**: Distribute referral reward for completed activity.

**Access Control**: Only reserve managers can distribute rewards.

**Parameters**:

- `referrer`: Address of the referrer
- `referee`: Address of the referee
- `activityAmount`: Amount of the activity

**Process**:

1. Calculate reward amount
2. Transfer reward to referrer
3. Update reward tracking
4. Emit reward distributed event

### Program Management

#### Set Referral Parameters

```solidity
function setReferralParameters(
    uint256 rewardRate,
    uint256 maxReferrals,
    uint256 minActivityAmount
) external onlyGovernor
```

**Purpose**: Update referral program parameters.

**Access Control**: Only governors can update parameters.

**Parameters**:

- `rewardRate`: Rate for referral rewards
- `maxReferrals`: Maximum referrals per user
- `minActivityAmount`: Minimum activity amount for rewards

**Process**: Updates parameters and emits event.

#### Get Referral Parameters

```solidity
function getReferralParameters() external view returns (
    uint256 rewardRate,
    uint256 maxReferrals,
    uint256 minActivityAmount
)
```

**Purpose**: Get current referral program parameters.

**Returns**: Current referral program configuration.

### Analytics and Reporting

#### Get Referral Statistics

```solidity
function getReferralStats(address user) external view returns (
    uint256 totalReferrals,
    uint256 activeReferrals,
    uint256 totalRewards,
    uint256 lastReferralTime
)
```

**Purpose**: Get comprehensive referral statistics for a user.

**Parameters**: `user` - Address of the user.

**Returns**: Complete referral statistics and information.

#### Get Program Statistics

```solidity
function getProgramStats() external view returns (
    uint256 totalReferrals,
    uint256 totalRewards,
    uint256 activeUsers,
    uint256 totalReferrers
)
```

**Purpose**: Get overall referral program statistics.

**Returns**: Program-wide statistics and metrics.

## Integration Points

### Protocol Contracts

- **RZR Token**: [`RZR.sol`](./RZR.sol) - Referral reward distribution
- **Treasury**: [`AppTreasury.sol`](./AppTreasury.sol) - Reward funding
- **Authority**: [`AppAuthority.sol`](./AppAuthority.sol) - Access control
- **Staking**: [`AppStaking.sol`](./AppStaking.sol) - Referral activity tracking

### External Systems

- **User Onboarding**: New user registration systems
- **Activity Tracking**: Protocol activity monitoring
- **Reward Distribution**: Automated reward distribution
- **Analytics**: Referral program analytics and reporting

## Referral Program Mechanics

### Referral Eligibility

- **New Users**: Only new users can be referred
- **Referrer Limits**: Maximum referrals per referrer
- **Activity Requirements**: Minimum activity for reward eligibility
- **Time Restrictions**: Referral time limits and restrictions

### Reward Structure

- **Activity-Based**: Rewards based on referee activity
- **Percentage-Based**: Reward percentage of activity amount
- **Tiered Rewards**: Different reward rates for different activities
- **Cumulative Rewards**: Rewards accumulate over time

### Performance Tracking

- **Referral Count**: Number of successful referrals
- **Activity Volume**: Total activity from referrals
- **Reward Earnings**: Total rewards earned
- **Success Rate**: Referral success metrics

## Security Features

### Access Control

- **Role-Based Permissions**: Only authorized roles can manage referrals
- **Referral Validation**: Validate all referral relationships
- **Reward Controls**: Controlled reward distribution
- **Emergency Controls**: Emergency pause and override capabilities

### Referral Security

- **Self-Referral Prevention**: Prevent users from referring themselves
- **Duplicate Prevention**: Prevent duplicate referral relationships
- **Eligibility Validation**: Validate referral eligibility
- **Fraud Prevention**: Anti-fraud mechanisms and monitoring

### Operational Security

- **Referral Validation**: All referrals validated before registration
- **State Consistency**: Consistent state across all operations
- **Event Logging**: Complete transparency of all operations
- **Emergency Procedures**: Emergency response capabilities

## Usage Examples

### Referral Management

#### Register New Referral

```solidity
// Register a new referral
AppReferrals referrals = AppReferrals(referralsAddress);

referrals.registerReferral(
    referrerAddress,  // User making referral
    refereeAddress    // User being referred
);
```

#### Check Referral Status

```solidity
// Check if user has a referrer
address referrer = referrals.getReferrer(userAddress);

if (referrer != address(0)) {
    console.log("User referred by:", referrer);
} else {
    console.log("User has no referrer");
}
```

#### Get User Referrals

```solidity
// Get all users referred by a specific user
address[] memory userReferrals = referrals.getReferrals(referrerAddress);
console.log("User has referred", userReferrals.length, "users");
```

### Reward Operations

#### Calculate Referral Reward

```solidity
// Calculate reward for staking activity
uint256 reward = referrals.calculateReferralReward(
    referrerAddress,
    refereeAddress,
    1000e18  // 1000 RZR staked
);

console.log("Referral reward:", reward);
```

#### Distribute Referral Reward

```solidity
// Distribute reward for completed activity
referrals.distributeReferralReward(
    referrerAddress,
    refereeAddress,
    1000e18  // Activity amount
);
```

### Program Management

#### Update Referral Parameters

```solidity
// Update referral program parameters
referrals.setReferralParameters(
    5e16,     // 5% reward rate
    10,       // Max 10 referrals per user
    100e18    // Minimum 100 RZR activity
);
```

#### Check Program Parameters

```solidity
// Get current program parameters
(
    uint256 rewardRate,
    uint256 maxReferrals,
    uint256 minActivityAmount
) = referrals.getReferralParameters();

console.log("Reward Rate:", rewardRate);
console.log("Max Referrals:", maxReferrals);
console.log("Min Activity:", minActivityAmount);
```

### Analytics and Reporting

#### Get User Referral Stats

```solidity
// Get comprehensive referral statistics
(
    uint256 totalReferrals,
    uint256 activeReferrals,
    uint256 totalRewards,
    uint256 lastReferralTime
) = referrals.getReferralStats(userAddress);

console.log("Total Referrals:", totalReferrals);
console.log("Active Referrals:", activeReferrals);
console.log("Total Rewards:", totalRewards);
```

#### Get Program Statistics

```solidity
// Get overall program statistics
(
    uint256 totalReferrals,
    uint256 totalRewards,
    uint256 activeUsers,
    uint256 totalReferrers
) = referrals.getProgramStats();

console.log("Program Total Referrals:", totalReferrals);
console.log("Program Total Rewards:", totalRewards);
console.log("Active Users:", activeUsers);
```

## Events

### Referral Events

```solidity
event ReferralRegistered(address indexed referrer, address indexed referee, uint256 timestamp);
event ReferralRewardDistributed(address indexed referrer, address indexed referee, uint256 amount);
event ReferralCompleted(address indexed referrer, address indexed referee, uint256 activityAmount);
```

### Management Events

```solidity
event ReferralParametersUpdated(uint256 rewardRate, uint256 maxReferrals, uint256 minActivityAmount);
event ReferralProgramPaused(bool paused);
event ReferralRewardRateUpdated(uint256 oldRate, uint256 newRate);
```

### Analytics Events

```solidity
event ReferralStatsUpdated(address indexed user, uint256 totalReferrals, uint256 totalRewards);
event ProgramStatsUpdated(uint256 totalReferrals, uint256 totalRewards, uint256 activeUsers);
```

## Testing

### Unit Tests

- Referral registration and management functionality
- Reward calculation accuracy
- Parameter management mechanisms
- Access control validation

### Integration Tests

- Cross-contract referral flows
- Treasury integration testing
- Staking integration testing
- Authority system integration

### Security Tests

- Access control validation
- Referral manipulation prevention
- Fraud prevention mechanisms
- Emergency procedure testing

## Deployment Considerations

### Initial Setup

1. **Deploy Contract**: Deploy AppReferrals contract
2. **Configure Authority**: Set up access control integration
3. **Set Parameters**: Configure referral program parameters
4. **Verify Integration**: Test with RZR token and treasury

### Configuration

1. **Authority Integration**: Connect to protocol authority system
2. **Referral Parameters**: Set appropriate reward rates and limits
3. **Integration Setup**: Connect with activity tracking systems
4. **Monitoring Setup**: Implement referral monitoring

## Dependencies

### Core Dependencies

- **AppAccessControlled**: Protocol access control integration
- **Initializable**: Upgradeable contract pattern
- **RZR Token**: Referral reward distribution

### External Dependencies

- **Treasury System**: Reward funding and distribution
- **Activity Tracking**: Protocol activity monitoring systems
- **User Management**: User registration and management systems

## Best Practices

### Referral Management

1. **Eligibility Validation**: Validate all referral eligibility criteria
2. **Fraud Prevention**: Implement anti-fraud mechanisms
3. **Performance Monitoring**: Monitor referral program performance
4. **User Experience**: Ensure smooth referral process

### Security Considerations

1. **Access Control**: Verify referral management permissions
2. **Referral Validation**: Validate all referral relationships
3. **Reward Security**: Secure reward distribution mechanisms
4. **Emergency Procedures**: Test emergency response capabilities

### User Experience

1. **Clear Process**: Provide clear referral instructions
2. **Reward Transparency**: Show clear reward calculations
3. **Progress Tracking**: Track referral progress and rewards
4. **Support Tools**: Provide tools for referral management

## License

AGPL-3.0
