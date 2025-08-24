# Foundry Tests

This directory contains comprehensive test suites for the Rezerve.money protocol contracts using the Foundry testing framework.

## Setup

### Install Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Install Dependencies

```bash
forge install
```

## Running Tests

### Run All Tests

```bash
forge test
```

### Run Specific Test File

```bash
forge test --match-path test/foundry/AppStakingTest.t.sol
```

### Run Tests with Verbose Output

```bash
forge test -vv
```

### Run Tests with Gas Reporting

```bash
forge test --gas-report
```

### Run Fuzz Tests

```bash
forge test --match-path test/foundry/Staking4626Fuzz.t.sol
```

## Test Structure

- **BaseTest.sol**: Common test setup and utilities
- **Contract Tests**: Individual test files for each protocol contract
- **Invariants**: Property-based testing for critical functions
- **Fuzz Tests**: Randomized testing for edge cases

## Coverage

Generate test coverage report:

```bash
forge coverage
```

## Gas Optimization

Analyze gas usage:

```bash
forge test --gas-report --match-contract AppStaking
```
