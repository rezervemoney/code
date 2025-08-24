# Core Contracts

This directory contains the foundational smart contracts that form the backbone of the Rezerve.money protocol. These contracts provide the essential infrastructure for governance, access control, token management, staking, treasury operations, and more.

## Overview

The core contracts implement the fundamental architecture and business logic of the protocol, including:

- **Governance & Access Control**: Role-based permissions and emergency controls
- **Token System**: Core RZR token and staking derivatives
- **Treasury Management**: Reserve management and economic operations
- **Staking Infrastructure**: Liquid staking and yield generation
- **Bond System**: Bond issuance and management
- **Utility Contracts**: Proxies, timelocks, and operational tools

## Contract Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Core Protocol Layer                      │
├─────────────────────────────────────────────────────────────┤
│  Governance & Access Control                                │
│  ┌─────────────────┐  ┌───────────────────┐                 │
│  │  AppAuthority   │  │AppAccessControlled│                 │
│  │  (Central RBAC) │  │  (Base Access)    │                 │
│  └─────────────────┘  └───────────────────┘                 │
├─────────────────────────────────────────────────────────────┤
│  Token & Staking System                                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐  │
│  │      RZR        │  │     sRZR        │  │Staking4626  │  │
│  │  (Core Token)   │  │ (Staking Token) │  │(L2 Staking) │  │
│  └─────────────────┘  └─────────────────┘  └─────────────┘  │
├─────────────────────────────────────────────────────────────┤
│  Core Protocol Contracts                                    │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐  │
│  │  AppTreasury    │  │   AppStaking    │  │AppConverti  │  │
│  │  (Reserves)     │  │  (Staking)      │  │(Convertibl) │  │
│  └─────────────────┘  └─────────────────┘  └─────────────┘  │
├─────────────────────────────────────────────────────────────┤
│  Utility & Infrastructure                                   │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐  │
│  │   AppProxy      │  │  AppTimelock    │  │AppOracle    │  │
│  │  (Upgrades)     │  │  (Delays)       │  │(Pricing)    │  │
│  └─────────────────┘  └─────────────────┘  └─────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Contract Documentation

### Governance & Access Control

#### [AppAuthority](./AppAuthority.md)

**Central authority contract managing roles, permissions, and emergency controls**

- **Purpose**: Centralized role-based access control (RBAC) system
- **Key Features**: 8 distinct roles, emergency pause functionality, governance controls
- **Roles**: Governor, Guardian, Policy, Reserve Manager, Executor, Reserve Depositor, Bond Manager
- **Security**: Multi-layer access controls, emergency procedures, role hierarchy

**File**: [`AppAuthority.sol`](./AppAuthority.sol)
**Interface**: [`IAppAuthority.sol`](../interfaces/IAppAuthority.sol)

#### [AppAccessControlled](./AppAccessControlled.md)

**Base contract providing standardized access control for all protocol contracts**

- **Purpose**: Foundation for role-based access control across the protocol
- **Key Features**: Authority integration, pause state checking, role verification
- **Modifiers**: `onlyGovernor`, `onlyGuardian`, `onlyPolicy`, `whenNotPaused`
- **Integration**: Inherited by all core protocol contracts

**File**: [`AppAccessControlled.sol`](./AppAccessControlled.sol)

### Token & Staking System

#### [RZR](./RZR.md)

**Core ERC20 token contract for the Rezerve.money protocol**

- **Purpose**: Native protocol token with governance, staking, and economic functions
- **Key Features**: ERC20 standard, controlled minting, burning, EIP-2612 permit
- **Economic Model**: Inflationary/deflationary based on protocol activity
- **Integration**: Treasury, staking, bonds, and oracle systems

**File**: [`RZR.sol`](./RZR.sol)
**Interface**: No interface file exists

#### [sRZR](./sRZR.md)

**Non-transferable staking token representing staked RZR positions**

- **Purpose**: Staking derivative token that tracks staked positions
- **Key Features**: ERC20Permit standard, controlled minting/burning, non-transferable
- **Mechanics**: Only staking contract can mint/burn, prevents position trading
- **Benefits**: Secure position tracking, integration with staking system

**File**: [`sRZR.sol`](./sRZR.sol)
**Interface**: No interface file exists

#### [Staking4626](./Staking4626.md)

**ERC4626-compliant staking vault for RZR tokens**

- **Purpose**: Standardized staking interface following ERC4626 standard
- **Key Features**: Share-based staking, yield distribution, withdrawal controls
- **Integration**: Works with sRZR token and treasury operations
- **Standards**: Full ERC4626 compliance for DeFi integration

**File**: [`Staking4626.sol`](./Staking4626.sol)
**Interface**: [`IStaking4626.sol`](../interfaces/IStaking4626.sol)
**Tests**: [`test/foundry/Staking4626.t.sol`](../../test/foundry/Staking4626.t.sol)

### Core Protocol Contracts

#### [AppTreasury](./AppTreasury.md)

**Central treasury contract managing protocol reserves and economic operations**

- **Purpose**: Reserve management, economic policy execution, protocol funding
- **Key Features**: Multi-asset reserves, economic calculations, reserve distribution
- **Operations**: Reserve tracking, economic metrics, treasury management
- **Integration**: Oracle system, staking contracts, bond system

**File**: [`AppTreasury.sol`](./AppTreasury.sol)
**Interface**: [`IAppTreasury.sol`](../interfaces/IAppTreasury.sol)
**Tests**: [`test/foundry/AppTreasuryTest.t.sol`](../../test/foundry/AppTreasuryTest.t.sol)

#### [AppStaking](./AppStaking.md)

**Main staking contract managing RZR staking operations and rewards**

- **Purpose**: Core staking functionality, reward distribution, staking management
- **Key Features**: Staking positions, reward calculation, withdrawal management
- **Mechanics**: Time-based staking, reward multipliers, penalty systems
- **Integration**: RZR token, treasury, oracle system

**File**: [`AppStaking.sol`](./AppStaking.sol)
**Interface**: [`IAppStaking.sol`](../interfaces/IAppStaking.sol)
**Tests**: [`test/foundry/AppStakingTest.t.sol`](../../test/foundry/AppStakingTest.t.sol)

#### [AppBondDepository](./AppBondDepository.md)

**NFT-based bond issuance and management system for protocol funding**

- **Purpose**: Bond issuance, position management, funding operations
- **Key Features**: NFT-based positions, dynamic pricing, direct staking integration
- **Integration**: Treasury system, RZR token, staking contract, loyalty system
- **Mechanics**: Time-based pricing, vesting schedules, position staking

**File**: [`AppBondDepository.sol`](./AppBondDepository.sol)
**Interface**: [`IAppBondDepository.sol`](../interfaces/IAppBondDepository.sol)
**Tests**: [`test/foundry/AppBondDepositoryTest.t.sol`](../../test/foundry/AppBondDepositoryTest.t.sol)

#### [AppConvertibles](./AppConvertibles.md)

**NFT-based convertible debt position management system**

- **Purpose**: Convertible debt positions, debt-equity conversion, interest distribution
- **Key Features**: NFT positions, conversion mechanics, fixed interest rates
- **Integration**: Bond system, treasury, staking integration, oracle pricing
- **Mechanics**: Price-based conversion, vesting schedules, position splitting

**File**: [`AppConvertibles.sol`](./AppConvertibles.sol)
**Interface**: [`IAppConvertibles.sol`](../interfaces/IAppConvertibles.sol)
**Tests**: [`test/foundry/AppConvertiblesTest.t.sol`](../../test/foundry/AppConvertiblesTest.t.sol)

#### [RebaseController](./RebaseController.md)

**Bonding-curve based epochic rebase mechanism for supply adjustments**

- **Purpose**: Epochic supply adjustments, yield distribution, backing ratio management
- **Key Features**: 23-hour epochs, bonding curve calculations, token distribution
- **Integration**: RZR token, treasury, staking contract, reserves oracle
- **Effects**: Automated yield distribution, economic equilibrium maintenance

**File**: [`RebaseController.sol`](./RebaseController.sol)
**Interface**: [`IRebaseController.sol`](../interfaces/IRebaseController.sol)
**Tests**: [`test/foundry/RebaseControllerTest.t.sol`](../../test/foundry/RebaseControllerTest.t.sol)

### Utility & Infrastructure

#### [AppProxy](./AppProxy.md)

**Upgradeable proxy contract for core protocol contracts**

- **Purpose**: Contract upgradeability, implementation management
- **Key Features**: Proxy pattern, upgrade management, storage separation
- **Benefits**: Upgradeable contracts without data migration
- **Security**: Controlled upgrades through governance

**File**: [`AppProxy.sol`](./AppProxy.sol)

#### [AppTimelock](./AppTimelock.md)

**OpenZeppelin-based timelock controller with role management**

- **Purpose**: Delayed execution of governance decisions with role-based access
- **Key Features**: Inherits OpenZeppelin TimelockController, role enumeration
- **Security**: Prevents immediate execution of critical changes
- **Governance**: Integration with authority system and role management

**File**: [`AppTimelock.sol`](./AppTimelock.sol)

#### [AppOracle](./AppOracle.md)

**Core oracle contract for price feeds and data aggregation**

- **Purpose**: Price data management, oracle aggregation, data validation
- **Key Features**: Multi-source pricing, data validation, staleness checks
- **Integration**: Price feed system, treasury operations, economic calculations
- **Standards**: Oracle interface compliance

**File**: [`AppOracle.sol`](./AppOracle.sol)
**Interface**: [`IAppOracle.sol`](../interfaces/IAppOracle.sol)
**Tests**: [`test/foundry/AppOracleTest.t.sol`](../../test/foundry/AppOracleTest.t.sol)

#### [AppBurner](./AppBurner.md)

**Token burning mechanism for deflationary pressure**

- **Purpose**: Controlled token burning, supply management
- **Key Features**: Burn mechanisms, supply control, economic balance
- **Integration**: RZR token, treasury, economic policy
- **Effects**: Deflationary pressure, value appreciation

**File**: [`AppBurner.sol`](./AppBurner.sol)
**Interface**: [`IAppBurner.sol`](../interfaces/IAppBurner.sol)
**Tests**: [`test/foundry/AppBurnerTest.t.sol`](../../test/foundry/AppBurnerTest.t.sol)

#### [AppReferrals](./AppReferrals.md)

**Referral code system for protocol user acquisition and activity tracking**

- **Purpose**: Referral code management, activity tracking, referral-based operations
- **Key Features**: Unique referral codes, referral-based staking/bonding, merkle rewards
- **Integration**: Staking system, bonding system, liquid staking, treasury
- **Benefits**: User acquisition, activity attribution, community growth

**File**: [`AppReferrals.sol`](./AppReferrals.sol)
**Interface**: [`IAppReferrals.sol`](../interfaces/IAppReferrals.sol)
**Tests**: [`test/foundry/AppReferrals.t.sol`](../../test/foundry/AppReferrals.t.sol) (Note: This is a test file, not a test suite)

## Testing & Development

### Test Coverage

All core contracts include comprehensive test suites covering:

- **Unit Tests**: Individual contract functionality and edge cases
- **Integration Tests**: Cross-contract interactions and workflows
- **Security Tests**: Access control, economic attacks, and emergency procedures

### Test Files

- **Staking4626**: [`test/foundry/Staking4626.t.sol`](../../test/foundry/Staking4626.t.sol)
- **AppTreasury**: [`test/foundry/AppTreasuryTest.t.sol`](../../test/foundry/AppTreasuryTest.t.sol)
- **AppStaking**: [`test/foundry/AppStakingTest.t.sol`](../../test/foundry/AppStakingTest.t.sol)
- **AppBondDepository**: [`test/foundry/AppBondDepositoryTest.t.sol`](../../test/foundry/AppBondDepositoryTest.t.sol)
- **AppConvertibles**: [`test/foundry/AppConvertiblesTest.t.sol`](../../test/foundry/AppConvertiblesTest.t.sol)
- **RebaseController**: [`test/foundry/RebaseControllerTest.t.sol`](../../test/foundry/RebaseControllerTest.t.sol)
- **AppOracle**: [`test/foundry/AppOracleTest.t.sol`](../../test/foundry/AppOracleTest.t.sol)
- **AppBurner**: [`test/foundry/AppBurnerTest.t.sol`](../../test/foundry/AppBurnerTest.t.sol)
- **AppReferrals**: [`test/foundry/AppReferrals.t.sol`](../../test/foundry/AppReferrals.t.sol) (Note: This is a test file, not a test suite)

### Interface Definitions

All contracts implement standardized interfaces:

- **Core Interfaces**: [`../interfaces/`](../interfaces/) - Protocol interface definitions
- **ERC Standards**: OpenZeppelin ERC20, ERC4626, and other standard interfaces
- **Custom Interfaces**: Protocol-specific interface implementations

## License

All core contracts are licensed under **AGPL-3.0-or-later** to ensure open source compliance and community contribution.
