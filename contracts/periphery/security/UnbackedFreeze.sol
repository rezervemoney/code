pragma solidity 0.8.28;

// SPDX-License-Identifier: AGPL-3.0

import "../../core/AppAccessControlled.sol";
import "../../interfaces/IAppTreasury.sol";

/**
 * @title UnbackedFreeze
 * @notice Contract that can be invoked by executors to evaluate the protocol's backing invariant and, if violated,
 *         attempt to pause critical protocol contracts (Treasury, Staking and Bond Depository).
 *
 * Bad debt is defined as:  actual RZR supply (including unbacked supply) minus total reserves (actual reserves + credit).
 * If the bad debt exceeds the configured `BAD_DEBT_THRESHOLD`, this contract will:
 *   1. Pause the Treasury (must implement `pause()` & be guardian-gated).
 *   2. Attempt to pause the Staking and Bond Depository contracts. These calls are executed using a low-level `call`
 *      and are therefore tolerant to targets that do not expose a `pause()` selector – the failure is simply emitted.
 */
contract UnbackedFreeze is AppAccessControlled {
// todo
}
