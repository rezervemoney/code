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
**Interface**: [`IRZR.sol`](../interfaces/IRZR.sol)
**Tests**: [`test/foundry/Staking4626.t.sol`](../../test/foundry/Staking4626.t.sol)

#### [sRZR](./sRZR.md)

**Staking derivative token representing staked RZR positions**

- **Purpose**: Liquid staking token for RZR stakers
- **Key Features**: ERC4626 vault standard, yield generation, liquid staking
- **Mechanics**: Share-based staking, automatic yield distribution
- **Benefits**: Maintains liquidity while earning staking rewards

**File**: [`sRZR.sol`](./sRZR.sol)
**Interface**: [`IsRZR.sol`](../interfaces/IsRZR.sol)
**Tests**: [`test/foundry/Staking4626.t.sol`](../../test/foundry/Staking4626.t.sol)

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

**Bond issuance and management system for protocol funding**

- **Purpose**: Bond issuance, debt management, funding operations
- **Key Features**: Bond creation, vesting schedules, debt tracking
- **Integration**: Treasury system, RZR token, governance
- **Mechanics**: Bond pricing, vesting, redemption

**File**: [`AppBondDepository.sol`](./AppBondDepository.sol)
**Interface**: [`IAppBondDepository.sol`](../interfaces/IAppBondDepository.sol)
**Tests**: [`test/foundry/AppBondDepositoryTest.t.sol`](../../test/foundry/AppBondDepositoryTest.t.sol)

#### [AppConvertibles](./AppConvertibles.md)

**Convertible bond and debt instrument management**

- **Purpose**: Convertible debt instruments, debt-equity conversion
- **Key Features**: Conversion mechanisms, debt management, equity distribution
- **Integration**: Bond system, treasury, governance
- **Mechanics**: Conversion ratios, vesting schedules, debt tracking

**File**: [`AppConvertibles.sol`](./AppConvertibles.sol)
**Interface**: [`IAppConvertibles.sol`](../interfaces/IAppConvertibles.sol)
**Tests**: [`test/foundry/AppConvertiblesTest.t.sol`](../../test/foundry/AppConvertiblesTest.t.sol)

#### [RebaseController](./RebaseController.md)

**Rebase mechanism for token supply adjustments**

- **Purpose**: Supply adjustment, economic rebalancing, market stabilization
- **Key Features**: Rebase calculations, supply adjustments, market mechanics
- **Integration**: RZR token, treasury, economic policy
- **Effects**: Supply elasticity, price stabilization

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
**Interface**: [`IAppProxy.sol`](../interfaces/IAppProxy.sol)
**Tests**: [`test/foundry/AccessControlTest.t.sol`](../../test/foundry/AccessControlTest.t.sol)

#### [AppTimelock](./AppTimelock.md)

**Time-delay mechanism for governance actions**

- **Purpose**: Delayed execution of governance decisions
- **Key Features**: Configurable delays, batch operations, emergency controls
- **Security**: Prevents immediate execution of critical changes
- **Governance**: Integration with authority system

**File**: [`AppTimelock.sol`](./AppTimelock.sol)
**Interface**: [`IAppTimelock.sol`](../interfaces/IAppTimelock.sol)
**Tests**: [`test/foundry/AccessControlTest.t.sol`](../../test/foundry/AccessControlTest.t.sol)

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

**Referral system for protocol user acquisition**

- **Purpose**: User referral tracking, reward distribution, growth incentives
- **Key Features**: Referral tracking, reward calculation, user management
- **Integration**: Staking system, treasury, user onboarding
- **Benefits**: Growth incentives, user acquisition, community building

**File**: [`AppReferrals.sol`](./AppReferrals.sol)
**Interface**: [`IAppReferrals.sol`](../interfaces/IAppReferrals.sol)
**Tests**: [`test/foundry/AppReferrals.t.sol`](../../test/foundry/AppReferrals.t.sol)

## Testing & Development

### Test Coverage

All core contracts include comprehensive test suites covering:

- **Unit Tests**: Individual contract functionality and edge cases
- **Integration Tests**: Cross-contract interactions and workflows
- **Security Tests**: Access control, economic attacks, and emergency procedures

### Test Files

- **RZR**: [`test/foundry/Staking4626.t.sol`](../../test/foundry/Staking4626.t.sol)
- **sRZR**: [`test/foundry/Staking4626.t.sol`](../../test/foundry/Staking4626.t.sol)
- **Staking4626**: [`test/foundry/Staking4626.t.sol`](../../test/foundry/Staking4626.t.sol)
- **AppTreasury**: [`test/foundry/AppTreasuryTest.t.sol`](../../test/foundry/AppTreasuryTest.t.sol)
- **AppStaking**: [`test/foundry/AppStakingTest.t.sol`](../../test/foundry/AppStakingTest.t.sol)
- **AppBondDepository**: [`test/foundry/AppBondDepositoryTest.t.sol`](../../test/foundry/AppBondDepositoryTest.t.sol)
- **AppConvertibles**: [`test/foundry/AppConvertiblesTest.t.sol`](../../test/foundry/AppConvertiblesTest.t.sol)
- **RebaseController**: [`test/foundry/RebaseControllerTest.t.sol`](../../test/foundry/RebaseControllerTest.t.sol)
- **AppProxy**: [`test/foundry/AccessControlTest.t.sol`](../../test/foundry/AccessControlTest.t.sol)
- **AppTimelock**: [`test/foundry/AccessControlTest.t.sol`](../../test/foundry/AccessControlTest.t.sol)
- **AppOracle**: [`test/foundry/AppOracleTest.t.sol`](../../test/foundry/AppOracleTest.t.sol)
- **AppBurner**: [`test/foundry/AppBurnerTest.t.sol`](../../test/foundry/AppBurnerTest.t.sol)
- **AppReferrals**: [`test/foundry/AppReferrals.t.sol`](../../test/foundry/AppReferrals.t.sol)

### Interface Definitions

All contracts implement standardized interfaces:

- **Core Interfaces**: [`../interfaces/`](../interfaces/) - Protocol interface definitions
- **ERC Standards**: OpenZeppelin ERC20, ERC4626, and other standard interfaces
- **Custom Interfaces**: Protocol-specific interface implementations

## License

All core contracts are licensed under **AGPL-3.0** to ensure open source compliance and community contribution.
