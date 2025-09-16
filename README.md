# Rezerve Money Protocol

Welcome to the Rezerve Money Protocol. Here you'll find everything you need to know about RZR, our dynamic currency, and its governance and insurance token.

## Protocol Overview

Rezerve Money is a DeFi protocol that combines dynamic rebasing, staking, bonding, and liquid staking mechanisms.

### Core Components

- **RZR**: The base rebasing token with dynamic supply adjustments
- **sRZR**: Non-transferable staking receipt token
- **Staking4626**: ERC4626-compliant staking vaults
- **Bond System**: NFT-based bond issuance with dynamic pricing
- **Convertibles**: NFT-based convertible debt positions
- **Rebase Controller**: Epochic supply management via bonding curves
- **Treasury**: Protocol reserve management and fee collection
- **Referrals**: NFT-based referral system with Merkle rewards

## Documentation Structure

### Core Contracts

- [Core Contracts Overview](./contracts/core/README.md) - Detailed documentation of all core protocol contracts
- [RZR](./contracts/core/RZR.md) - Base rebasing token
- [sRZR](./contracts/core/sRZR.md) - Staking receipt token
- [Staking4626](./contracts/core/Staking4626.md) - ERC4626 staking vaults
- [AppBondDepository](./contracts/core/AppBondDepository.md) - Bond issuance system
- [AppConvertibles](./contracts/core/AppConvertibles.md) - Convertible debt management
- [RebaseController](./contracts/core/RebaseController.md) - Supply rebasing mechanism
- [AppTimelock](./contracts/core/AppTimelock.md) - Governance timelock
- [AppReferrals](./contracts/core/AppReferrals.md) - Referral and rewards system
- [AppTreasury](./contracts/core/AppTreasury.md) - Treasury management
- [AppOracle](./contracts/core/AppOracle.md) - Price feed oracles

### Testing

- [Foundry Tests](./test/foundry/README.md) - Comprehensive test suite using Foundry
- [Test Invariants](./test/invariants.md) - Property-based testing specifications

### External Resources

- Documentation: [https://rezerve.gitbook.io/protocol](https://rezerve.gitbook.io/protocol)
- Discord: [https://discord.rezerve.money](https://discord.rezerve.money)
- Website: [https://rezerve.money](https://rezerve.money)

## Quick Start

```
# Install Dependencies
yarn install
forge install https://github.com/foundry-rs/forge-std
forge install https://github.com/a16z/halmos-cheatcodes
forge install https://github.com/euler-xyz/euler-vault-kit
forge install https://github.com/euler-xyz/ethereum-vault-connector

# Compile contracts
forge build

# Run tests
yarn tests
```

## License

This project is licensed under AGPL-3.0-or-later. See [LICENSE](./LICENSE) for details.
