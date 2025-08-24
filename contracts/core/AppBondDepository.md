# AppBondDepository

**File**: [`AppBondDepository.sol`](./AppBondDepository.sol)

**License**: AGPL-3.0-or-later

**Test File**: [`test/foundry/AppBondDepositoryTest.t.sol`](../../test/foundry/AppBondDepositoryTest.t.sol)

## Overview

The `AppBondDepository` contract is the bond issuance and management system for the Rezerve.money protocol. It enables the protocol to raise funds through bond sales while providing investors with discounted RZR tokens and managing debt obligations through sophisticated bond mechanics. The system uses NFT-based positions to track individual bond holdings.

## Purpose

This contract serves as:

- **Bond Issuance**: Primary mechanism for protocol funding through bond sales
- **NFT-Based Positions**: Bond positions represented as ERC721 tokens
- **Dynamic Pricing**: Time-based bond pricing with initial and final prices
- **Vesting Management**: Gradual token distribution over vesting periods
- **Staking Integration**: Direct staking of bond positions

## Architecture

### Inheritance

- `IAppBondDepository` - Bond depository interface
- `AppAccessControlled` - Protocol access control integration
- `ERC721EnumerableUpgradeable` - NFT position management
- `ReentrancyGuardUpgradeable` - Reentrancy protection

### Core Components

- **Bond Management**: Bond creation, tracking, and management
- **NFT Positions**: ERC721 tokens representing bond holdings
- **Dynamic Pricing**: Time-based price calculations
- **Vesting System**: Gradual token distribution
- **Staking Integration**: Direct staking of bond positions

## Key Functions

### Bond Management

#### Create Bond

```solidity
function create(
    IERC20 _quoteToken,
    uint256 _capacity,
    uint256 _initialPrice,
    uint256 _finalPrice,
    uint256 _minPrice,
    uint256 _duration,
    uint256 _vestingPeriod,
    uint256 _stakingLockPeriod,
    bool _isLoyaltyBond
) external onlyBondManager returns (uint256 id_)
```

**Purpose**: Create a new bond offering with specified parameters.

**Access Control**: Only bond managers can create bonds.

**Parameters**:

- `_quoteToken` - Token used to purchase bonds (e.g., USDC)
- `_capacity` - Maximum bond capacity
- `_initialPrice` - Starting price for the bond
- `_finalPrice` - Final price at bond end
- `_minPrice` - Minimum allowed price
- `_duration` - Bond duration in seconds
- `_vestingPeriod` - Token vesting period
- `_stakingLockPeriod` - Minimum staking lock period
- `_isLoyaltyBond` - Whether this is a loyalty bond

**Returns**: Bond ID for the created bond.

**Process**: Creates bond with time-based pricing and vesting schedule.

#### Update Bond Price

```solidity
function updateBondPrice(uint256 _id, uint256 _initialPrice, uint256 _finalPrice) external onlyBondManager
```

**Purpose**: Update bond pricing parameters.

**Access Control**: Only bond managers can update prices.

**Parameters**:

- `_id` - Bond ID to update
- `_initialPrice` - New initial price
- `_finalPrice` - New final price

**Requirements**: Both prices must be above minimum price.

#### Update Bond End Date

```solidity
function updateBondEndDate(uint256 _id, uint256 _endTime) external onlyBondManager
```

**Purpose**: Extend or modify bond end date.

**Access Control**: Only bond managers can update end dates.

**Parameters**:

- `_id` - Bond ID to update
- `_endTime` - New end time

**Requirements**: End time must be in the future.

#### Disable Bond

```solidity
function disable(uint256 _id) external onlyBondManager
```

**Purpose**: Disable a bond, preventing further deposits.

**Access Control**: Only bond managers can disable bonds.

**Parameters**: `_id` - Bond ID to disable.

### Bond Operations

#### Deposit (Purchase Bond)

```solidity
function deposit(
    uint256 _id,
    uint256 _amount,
    uint256 _maxPrice,
    uint256 _minPayout,
    address _user
) external nonReentrant returns (uint256 payout_, uint256 tokenId_)
```

**Purpose**: Purchase bonds with specified parameters.

**Parameters**:

- `_id` - Bond ID to purchase
- `_amount` - Amount of quote tokens to spend
- `_maxPrice` - Maximum price willing to pay
- `_minPayout` - Minimum payout required
- `_user` - Address to receive the bond position

**Returns**: Payout amount and bond position token ID.

**Process**: Calculates current price, validates parameters, creates NFT position.

#### Claim Tokens

```solidity
function claim(uint256 _tokenId) external nonReentrant
```

**Purpose**: Claim vested tokens from a bond position.

**Parameters**: `_tokenId` - NFT token ID of the bond position.

**Requirements**: Position must not be blacklisted or staked.

**Process**: Calculates claimable amount and transfers RZR tokens to owner.

#### Stake Position

```solidity
function stake(uint256 _tokenId, uint256 _declaredValue) external nonReentrant
```

**Purpose**: Stake a bond position directly into the staking contract.

**Parameters**:

- `_tokenId` - NFT token ID of the bond position
- `_declaredValue` - Declared value for staking

**Requirements**: Must own the position and not already staked.

**Process**: Stakes unclaimed tokens with minimum lock period.

#### Complete Bond Vesting

```solidity
function completeBondVesting(uint256 _tokenId) external onlyBondManager
```

**Purpose**: Complete vesting for a bond position (emergency function).

**Access Control**: Only bond managers can complete vesting.

**Parameters**: `_tokenId` - NFT token ID of the bond position.

**Requirements**: Vesting must not already be completed.

### View Functions

#### Get Bond Information

```solidity
function getBond(uint256 _id) external view returns (Bond memory)
```

**Purpose**: Get complete bond information.

**Parameters**: `_id` - Bond ID to query.

**Returns**: Complete bond data structure.

#### Get Bond Position

```solidity
function positions(uint256 tokenId) external view returns (BondPosition memory position)
```

**Purpose**: Get bond position information for a token ID.

**Parameters**: `tokenId` - NFT token ID.

**Returns**: Complete bond position data.

#### Check Bond Status

```solidity
function isLive(uint256 _id) external view returns (bool)
```

**Purpose**: Check if a bond is currently active and accepting deposits.

**Parameters**: `_id` - Bond ID to check.

**Returns**: `true` if bond is live, `false` otherwise.

#### Get Current Price

```solidity
function currentPrice(uint256 _id) external view returns (uint256)
```

**Purpose**: Get current bond price based on time elapsed.

**Parameters**: `_id` - Bond ID to query.

**Returns**: Current bond price in quote token terms.

#### Get Claimable Amount

```solidity
function claimableAmount(uint256 _tokenId) external view returns (uint256)
```

**Purpose**: Get amount of tokens that can be claimed from a position.

**Parameters**: `_tokenId` - NFT token ID.

**Returns**: Claimable token amount.

#### Get Bond Length

```solidity
function bondLength() external view returns (uint256)
```

**Purpose**: Get total number of bonds created.

**Returns**: Total bond count.

#### Calculate Payout and Profit

```solidity
function calculatePayoutAndProfit(
    IERC20 _token,
    uint256 _price,
    uint256 _amount
) external view returns (uint256 payout, uint256 profit)
```

**Purpose**: Calculate payout and profit for a given deposit.

**Parameters**:

- `_token` - Quote token
- `_price` - Bond price
- `_amount` - Deposit amount

**Returns**: Payout amount and profit amount.

### Administrative Functions

#### Toggle Blacklist

```solidity
function toggleBlacklist(uint256 _id) external onlyGuardian
```

**Purpose**: Blacklist or unblacklist a bond position.

**Access Control**: Only guardians can toggle blacklist status.

**Parameters**: `_id` - Bond position ID to toggle.

**Process**: Toggles blacklist status and emits event.

## Usage Examples

### Bond Creation

#### Create New Bond

```solidity
// Create a bond with 6-month duration and 12-month vesting
AppBondDepository bondDepository = AppBondDepository(bondAddress);

uint256 bondId = bondDepository.create(
    USDC,           // Quote token
    1000000e18,     // 1M capacity
    1e18,           // $1 initial price
    0.8e18,         // $0.80 final price
    0.7e18,         // $0.70 minimum price
    180 days,       // 6-month duration
    365 days,       // 12-month vesting
    30 days,        // 30-day staking lock
    false           // Not a loyalty bond
);

console.log("Bond created with ID:", bondId);
```

### Bond Purchase

#### Purchase Bond

```solidity
// Purchase bond with 1000 USDC
(uint256 payout, uint256 tokenId) = bondDepository.deposit(
    bondId,         // Bond ID
    1000e6,         // 1000 USDC
    1e18,           // Max $1 price
    800e18,         // Min 800 RZR payout
    msg.sender      // Receive position
);

console.log("Payout:", payout);
console.log("Token ID:", tokenId);
```

### Position Management

#### Check Bond Status

```solidity
// Check if bond is live
bool isLive = bondDepository.isLive(bondId);
console.log("Bond is live:", isLive);

// Get current price
uint256 currentPrice = bondDepository.currentPrice(bondId);
console.log("Current price:", currentPrice);
```

#### Get Position Information

```solidity
// Get bond position details
BondPosition memory position = bondDepository.positions(tokenId);
console.log("Bond ID:", position.bondId);
console.log("Amount:", position.amount);
console.log("Quote Amount:", position.quoteAmount);
console.log("Start Time:", position.startTime);
console.log("Is Staked:", position.isStaked);
```

### Token Claims

#### Check Claimable Amount

```solidity
// Get claimable tokens
uint256 claimable = bondDepository.claimableAmount(tokenId);
console.log("Claimable tokens:", claimable);
```

#### Claim Tokens

```solidity
// Claim vested tokens
bondDepository.claim(tokenId);
```

### Staking Integration

#### Stake Bond Position

```solidity
// Stake bond position directly
bondDepository.stake(tokenId, 1000e18); // Declare $1000 value
```

### Bond Analytics

#### Get Bond Information

```solidity
// Get complete bond details
Bond memory bond = bondDepository.getBond(bondId);
console.log("Capacity:", bond.capacity);
console.log("Sold:", bond.sold);
console.log("Initial Price:", bond.initialPrice);
console.log("Final Price:", bond.finalPrice);
console.log("Vesting Period:", bond.vestingPeriod);
```

#### Calculate Payout

```solidity
// Calculate expected payout for 1000 USDC
(uint256 payout, uint256 profit) = bondDepository.calculatePayoutAndProfit(
    USDC,           // Quote token
    0.9e18,         // Bond price
    1000e6          // 1000 USDC
);

console.log("Payout:", payout);
console.log("Profit:", profit);
```

## Events

### Bond Events

```solidity
event CreateBond(uint256 indexed id, address indexed quoteToken, uint256 initialPrice, uint256 capacity);
event BondCreated(uint256 indexed id, uint256 amount, uint256 price);
event Claimed(uint256 indexed tokenId, uint256 amount);
event Staked(uint256 indexed tokenId, uint256 amount);
```

### Management Events

```solidity
event UpdateBondPrice(uint256 indexed id, uint256 initialPrice, uint256 finalPrice);
event UpdateBondEndDate(uint256 indexed id, uint256 endTime);
event CompleteBondVesting(uint256 indexed tokenId);
event DisableBond(uint256 indexed id);
event Blacklisted(uint256 indexed id, bool blacklisted);
```

## License

AGPL-3.0-or-later
