# AppReferrals

**File**: [`AppReferrals.sol`](./AppReferrals.sol)

**License**: AGPL-3.0

**Test File**: [`test/foundry/AppReferrals.t.sol`](../../test/foundry/AppReferrals.t.sol)

## Overview

The `AppReferrals` contract is a referral system for the Rezerve.money protocol that tracks user referrals through referral codes and provides referral-based staking and bonding functionality. It integrates with the protocol's staking and bonding systems to enable referral-based activities.

## Purpose

This contract serves as:

- **Referral Code Management**: Generate and manage unique referral codes for users
- **Referral Tracking**: Track referral relationships through referral codes
- **Referral-Based Staking**: Enable staking with referral codes
- **Referral-Based Bonding**: Enable bonding with referral codes
- **Reward Distribution**: Distribute rewards through merkle proofs

## Architecture

### Inheritance

- `AppAccessControlled` - Protocol access control integration
- `ReentrancyGuardUpgradeable` - Reentrancy protection
- `IAppReferrals` - Referral system interface

### Core Components

- **Referral Code System**: Unique referral codes for users
- **Referral Tracking**: Track referral relationships
- **Staking Integration**: Referral-based staking operations
- **Bonding Integration**: Referral-based bonding operations
- **Merkle Reward System**: Off-chain calculated rewards with merkle proofs

## Key Functions

### Referral Code Management

#### Register Referral Code

```solidity
function registerReferralCode(bytes8 _code) external
```

**Purpose**: Register a referral code for the caller.

**Parameters**: `_code` - The referral code to register.

**Process**:

1. Validate referral code uniqueness
2. Check whitelist requirements if enabled
3. Register code for the caller
4. Emit referral code registered event

#### Register Referral Code For

```solidity
function registerReferralCodeFor(bytes8 _code, address _referrer) external onlyExecutor
```

**Purpose**: Register a referral code for a specific referrer (executor only).

**Access Control**: Only executors can register codes for others.

**Parameters**:

- `_code` - The referral code to register
- `_referrer` - The address to register the code for

### Referral-Based Staking

#### Stake With Referral

```solidity
function stakeWithReferral(
    uint256 amount,
    uint256 declaredValue,
    bytes8 _referralCode,
    address _to
) external nonReentrant returns (uint256 tokenId, uint256 taxPaid)
```

**Purpose**: Stake RZR tokens with a referral code.

**Parameters**:

- `amount` - Amount of RZR to stake
- `declaredValue` - Declared value for staking
- `_referralCode` - Referral code to use
- `_to` - Address to stake for

**Returns**: Token ID and tax paid from staking.

**Process**:

1. Transfer RZR from caller to contract
2. Register referral if code is valid
3. Create staking position for the target address
4. Emit referral staked event

#### Stake Into LST With Referral

```solidity
function stakeIntoLSTWithReferral(
    uint256 amount,
    bytes8 _referralCode,
    address _to
) external nonReentrant returns (uint256 minted)
```

**Purpose**: Stake RZR tokens into liquid staking with a referral code.

**Parameters**:

- `amount` - Amount of RZR to stake
- `_referralCode` - Referral code to use
- `_to` - Address to stake for

**Returns**: Amount of LST tokens minted.

**Process**:

1. Transfer RZR from caller to contract
2. Register referral if code is valid
3. Deposit into liquid staking for target address
4. Emit referral staked into LST event

### Referral-Based Bonding

#### Bond With Referral

```solidity
function bondWithReferral(
    uint256 _id,
    uint256 _amount,
    uint256 _maxPrice,
    uint256 _minPayout,
    bytes8 _referralCode,
    address _to
) external nonReentrant returns (uint256 payout_, uint256 tokenId_)
```

**Purpose**: Buy bonds with a referral code.

**Parameters**:

- `_id` - Bond ID to purchase
- `_amount` - Amount of quote tokens to spend
- `_maxPrice` - Maximum price willing to pay
- `_minPayout` - Minimum payout required
- `_referralCode` - Referral code to use
- `_to` - Address to buy bonds for

**Returns**: Payout amount and bond token ID.

**Process**:

1. Transfer quote tokens from caller to contract
2. Register referral if code is valid
3. Purchase bond for target address
4. Emit referral bond bought event

### Reward Management

#### Claim Rewards

```solidity
function claimRewards(ClaimRewardsInput[] calldata inputs) external
```

**Purpose**: Claim rewards using merkle proofs.

**Parameters**: `inputs` - Array of reward claim inputs with merkle proofs.

**Process**:

1. Verify merkle proof for each input
2. Check if rewards already claimed
3. Transfer unclaimed rewards to user
4. Update claimed amounts tracking

### Referral Tracking

#### Get Referrals

```solidity
function getReferrals(address _referrer) external view returns (address[] memory referrals)
```

**Purpose**: Get all addresses referred by a specific referrer.

**Parameters**: `_referrer` - Address of the referrer.

**Returns**: Array of referred addresses.

#### Total Referrals Made

```solidity
function totalReferralsMade(address _referrer) external view returns (uint256)
```

**Purpose**: Get total number of referrals made by a referrer.

**Parameters**: `_referrer` - Address of the referrer.

**Returns**: Total number of referrals.

### Configuration Management

#### Set Merkle Server

```solidity
function setMerkleServer(address _merkleServer) external onlyGovernor
```

**Purpose**: Set the merkle server address for reward verification.

**Access Control**: Only governors can set merkle server.

#### Set Enable Whitelisting

```solidity
function setEnableWhitelisting(bool _enableWhitelisting) external onlyGovernor
```

**Purpose**: Enable or disable whitelist requirement for referral codes.

**Access Control**: Only governors can toggle whitelisting.

#### Set Merkle Root

```solidity
function setMerkleRoot(bytes32 _merkleRoot) external
```

**Purpose**: Set merkle root for reward verification.

**Access Control**: Only merkle server can set root.

#### Whitelist User

```solidity
function whitelist(address _user) external onlyExecutor
```

**Purpose**: Add user to whitelist for referral code registration.

**Access Control**: Only executors can whitelist users.

## Usage Examples

### Referral Code Management

#### Register Your Referral Code

```solidity
// Register a referral code for yourself
AppReferrals referrals = AppReferrals(referralsAddress);

referrals.registerReferralCode(0x12345678); // Your unique code
```

#### Check Referral Code

```solidity
// Check if a referral code exists
address referrer = referrals.referralCodes(0x12345678);
if (referrer != address(0)) {
    console.log("Code belongs to:", referrer);
}
```

### Referral-Based Staking

#### Stake With Referral Code

```solidity
// Stake RZR with a referral code
(uint256 tokenId, uint256 taxPaid) = referrals.stakeWithReferral(
    1000e18,        // 1000 RZR
    1000e18,        // Declared value
    0x12345678,     // Referral code
    msg.sender      // Stake for yourself
);

console.log("Staked, Token ID:", tokenId);
console.log("Tax Paid:", taxPaid);
```

#### Stake Into Liquid Staking With Referral

```solidity
// Stake into LST with referral code
uint256 minted = referrals.stakeIntoLSTWithReferral(
    1000e18,        // 1000 RZR
    0x12345678,     // Referral code
    msg.sender      // Stake for yourself
);

console.log("LST Minted:", minted);
```

### Referral-Based Bonding

#### Buy Bonds With Referral

```solidity
// Buy bonds with referral code
(uint256 payout, uint256 tokenId) = referrals.bondWithReferral(
    1,              // Bond ID
    1000e6,         // 1000 USDC
    100e18,         // Max price
    50e18,          // Min payout
    0x12345678,     // Referral code
    msg.sender      // Buy for yourself
);

console.log("Bond Payout:", payout);
console.log("Bond Token ID:", tokenId);
```

### Referral Tracking

#### Check Your Referrals

```solidity
// Get all users you've referred
address[] memory yourReferrals = referrals.getReferrals(msg.sender);
console.log("You have referred", yourReferrals.length, "users");

for (uint256 i = 0; i < yourReferrals.length; i++) {
    console.log("Referred:", yourReferrals[i]);
}
```

#### Check Total Referrals

```solidity
// Get total referrals made
uint256 totalRefs = referrals.totalReferralsMade(msg.sender);
console.log("Total referrals made:", totalRefs);
```

### Reward Claims

#### Claim Rewards

```solidity
// Claim rewards using merkle proof
ClaimRewardsInput[] memory inputs = new ClaimRewardsInput[](1);
inputs[0] = ClaimRewardsInput({
    user: msg.sender,
    amount: 100e18,
    proofs: merkleProof
});

referrals.claimRewards(inputs);
```

## Events

### Referral Events

```solidity
event ReferralCodeRegistered(address indexed referrer, bytes8 indexed code);
event ReferralRegistered(address indexed user, address indexed referrer, bytes8 indexed code);
event ReferralStaked(address indexed user, uint256 amount, uint256 declaredValue, bytes8 indexed code);
event ReferralStakedIntoLST(address indexed user, uint256 amount, bytes8 indexed code);
event ReferralBondBought(address indexed user, uint256 payout, bytes8 indexed code);
```

### Management Events

```solidity
event MerkleServerSet(address indexed merkleServer);
event EnableWhitelistingSet(bool enableWhitelisting);
event MerkleRootSet(bytes32 indexed merkleRoot);
event Whitelisted(address indexed user);
```

### Reward Events

```solidity
event RewardsClaimed(address indexed user, uint256 amount, bytes32 indexed merkleRoot);
```

## License

AGPL-3.0
