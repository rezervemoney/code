# Treasury Helper Contracts

This directory contains smart contracts that provide helper functions for managing the protocol treasury, particularly for handling loans from Euler Finance and liquidity operations on Balancer.

## Overview

The treasury helper contracts are designed to streamline complex treasury operations by providing abstracted interfaces for:

- Borrowing and repaying loans on Euler Finance
- Managing collateral positions
- Adding liquidity to Balancer pools
- Minting and burning RZR tokens
- Executing batch operations efficiently

## Contract Architecture

### BaseTreasuryHelper.sol

**Abstract base contract providing core treasury functionality**

- **Access Control**: Inherits from `AppAccessControlled` for role-based permissions
- **Treasury Interface**: Provides access to the main treasury contract
- **RZR Token Management**: Handles minting and burning of RZR tokens
- **Safety Features**: Includes kill switch functionality for emergency situations
- **Key Functions**:
  - `_treasury()`: Returns the treasury contract instance
  - `_rzr()`: Returns the RZR app contract
  - `_mint()`: Mints RZR tokens to specified address
  - `_burn()`: Burns RZR tokens
  - `_burnPendingBalance()`: Burns all pending RZR balance
  - `kill()`: Emergency function to disable the contract

### EulerBorrowerHelper.sol

**Abstract contract for Euler Finance borrowing operations**

- **Euler Integration**: Interfaces with Euler Vault Connector (EVC) and EVaults
- **Batch Operations**: Executes multiple operations atomically using EVC batching
- **Collateral Management**: Handles adding/removing collateral
- **Debt Operations**: Manages borrowing and repaying loans
- **Key Functions**:
  - `_addCollateralAndBorrow()`: Adds collateral and borrows debt in one transaction
  - `_repayAndReoveCollateral()`: Repays debt and removes collateral simultaneously
  - `_borrow()`: Creates batch item for borrowing debt
  - `_repay()`: Creates batch item for repaying debt (supports both amount and shares)
  - `_addCollateral()`: Creates batch item for adding collateral
  - `_removeCollateral()`: Creates batch item for removing collateral

### BalancerBorrowAndAdd.sol

**Concrete implementation for Balancer liquidity operations**

- **Balancer Integration**: Interfaces with Balancer V3 router and pools
- **Odos Integration**: Uses Odos for token swaps
- **Liquidity Provision**: Adds proportional liquidity to Balancer pools
- **Complete Workflow**: Combines borrowing, swapping, and liquidity provision
- **Key Functions**:
  - `borrowAndAdd()`: Main function that executes the complete workflow:
    1. Adds collateral and borrows debt from Euler
    2. Swaps borrowed debt for additional collateral via Odos
    3. Mints RZR tokens for pool liquidity
    4. Adds proportional liquidity to Balancer pool
    5. Transfers BPT tokens to treasury
  - `estimateBptOutput()`: Estimates BPT output for given token amounts
  - `initialize()`: Sets up pool and authority references

## Usage Patterns

### Basic Euler Operations

```solidity
// Inherit from EulerBorrowerHelper
contract MyTreasuryHelper is EulerBorrowerHelper {
    // Use inherited functions for Euler operations
    function executeStrategy() external {
        _addCollateralAndBorrow(1000e18, 500e18, address(this));
        // ... additional logic
    }
}
```

### Balancer Liquidity Operations

```solidity
// Use BalancerBorrowAndAdd for complete liquidity workflows
BalancerBorrowAndAdd helper = BalancerBorrowAndAdd(address);
helper.borrowAndAdd(
    collateralAmount,
    debtAmount,
    odosCallData,
    tokenOut,
    minSwapOut,
    rzrToMint,
    minBptAmountOut
);
```

## Security Features

- **Access Control**: All operations require appropriate roles (ReserveManager, Guardian, Governor)
- **Kill Switch**: Emergency shutdown capability for all contracts
- **Batch Validation**: Euler operations use EVC for atomic execution
- **Slippage Protection**: Minimum output requirements for swaps and liquidity operations
- **Balance Checks**: Comprehensive balance validation before and after operations

## Dependencies

- **Euler Finance**: For borrowing and lending operations
- **Balancer V3**: For liquidity pool operations
- **Odos**: For token swaps and routing
- **Permit2**: For token approvals and permissions
- **App Protocol**: Core protocol contracts for treasury and RZR token management

## Deployment

Contracts should be deployed in the following order:

1. `BaseTreasuryHelper` (abstract, not deployed directly)
2. `EulerBorrowerHelper` (abstract, not deployed directly)
3. `BalancerBorrowAndAdd` (concrete implementation)

Ensure proper initialization with correct addresses for:

- Euler Vault Connector (EVC)
- Borrow and collateral vaults
- Balancer V3 router
- Odos contract
- Permit2 contract
- Target Balancer pool
- Protocol authority

## License

AGPL-3.0-or-later
