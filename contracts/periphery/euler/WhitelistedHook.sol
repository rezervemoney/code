// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "./BaseHookTarget.sol";
import "./SelectorAccessControl.sol";
import "../../interfaces/ILoyaltyList.sol";

/// @title HookTargetAccessControlKeyring
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Hook target contract that allows specific functions on the vault to be called only by authorized callers.
contract WhitelistedHook is BaseHookTarget, SelectorAccessControl {
    /// @notice The role for privileged accounts that can bypass the Keyring credential check
    bytes32 public constant PRIVILEGED_ACCOUNT_ROLE = keccak256("PRIVILEGED_ACCOUNT_ROLE");

    /// @notice The loyalty list contract used for credential checking
    ILoyaltyList public immutable loyaltyList;

    /// @notice Initializes the WhitelistedHook contract
    /// @param _evc The address of the EVC.
    /// @param _admin The address to be granted the DEFAULT_ADMIN_ROLE.
    /// @param _eVaultFactory The address of the EVault factory.
    constructor(address _evc, address _admin, address _eVaultFactory, address _loyaltyList)
        BaseHookTarget(_eVaultFactory)
        SelectorAccessControl(_evc, _admin)
    {
        loyaltyList = ILoyaltyList(_loyaltyList);
    }

    /// @notice Fallback function to revert if the address is not whitelisted to call the selector.
    fallback() external {
        _authenticateCaller();
    }

    /// @notice Intercepts EVault deposit operations to authenticate the caller and the receiver
    /// @param receiver The address that will receive shares
    function deposit(uint256, address receiver) external view {
        _authenticateCallerAndAccount(receiver);
    }

    /// @notice Intercepts EVault mint operations to authenticate the caller and the receiver
    /// @param receiver The address that will receive shares
    function mint(uint256, address receiver) external view {
        _authenticateCallerAndAccount(receiver);
    }

    /// @notice Intercepts EVault withdraw operations to authenticate the caller and the owner
    /// @param owner The address whose balance will change
    function withdraw(uint256, address, address owner) external view {
        _authenticateCallerAndAccount(owner);
    }

    /// @notice Intercepts EVault redeem operations to authenticate the caller and the owner
    /// @param owner The address whose balance will change
    function redeem(uint256, address, address owner) external view {
        _authenticateCallerAndAccount(owner);
    }

    /// @notice Intercepts EVault skim operations to authenticate the caller and the receiver
    /// @param receiver The address that will receive shares
    function skim(uint256, address receiver) external view {
        _authenticateCallerAndAccount(receiver);
    }

    /// @notice Intercepts EVault borrow operations to authenticate the caller and the receiver
    /// @param receiver The address that will receive borrowed assets
    function borrow(uint256, address receiver) external view {
        _authenticateCallerAndAccount(receiver);
    }

    /// @notice Intercepts EVault repay operations to authenticate the caller and the receiver
    /// @param receiver The address that will receive the repaid assets
    function repay(uint256, address receiver) external view {
        _authenticateCallerAndAccount(receiver);
    }

    /// @notice Intercepts EVault repayWithShares operations to authenticate the caller and the receiver
    /// @param receiver The address that will receive the repaid assets
    function repayWithShares(uint256, address receiver) external view {
        _authenticateCallerAndAccount(receiver);
    }

    /// @notice Intercepts EVault pullDebt operations to authenticate the caller and the from address
    /// @param from The address from which debt is being pulled
    function pullDebt(uint256, address from) external view {
        _authenticateCallerAndAccount(from);
    }

    /// @notice Checks if the EVC owner of the account has valid Keyring credential
    /// @dev If the EVC owner is not registered yet, the account is assumed to be the owner
    /// @param account The address to check credential for
    /// @return bool True if the EVC owner of the account has valid Keyring credential
    function checkCredential(address account) public view returns (bool) {
        address owner = evc.getAccountOwner(account);
        return loyaltyList.isLoyaltyWallet(owner == address(0) ? account : owner);
    }

    /// @notice Checks if the EVC owner of the account has a valid Keyring credential or the account has the wildcard
    /// role
    /// @dev For the Keyring credential, if the EVC owner is not registered yet, the account is assumed to be the owner
    /// @param account The address to check credential or wildcard role for
    /// @return bool True if the EVC owner of the account has a valid Keyring credential or the account has the wildcard
    /// role
    function checkKeyringCredentialOrWildCard(address account) external view returns (bool) {
        return hasRole(WILD_CARD, account) || checkCredential(account);
    }

    /// @notice Authenticates both the caller and the specified account for access control
    /// @dev This function checks if either the caller or the account owner are authorized to call the function
    /// @param account The account to be authenticated
    function _authenticateCallerAndAccount(address account) internal view {
        address caller = _msgSender();

        // Skip Keyring authentication if caller has wildcard role or specific function selector role
        if (hasRole(WILD_CARD, caller) || hasRole(msg.sig, caller)) return;

        address owner = evc.getAccountOwner(caller);

        // If the EVC owner is not registered yet, assume the caller is the owner
        if (owner == address(0)) owner = caller;

        // If the caller owner has the privileged account role, do not require Keyring authentication. If the caller and
        // the account share the same EVC owner, ensure the authentication is not carried out using the privileged
        // account path
        if (
            !loyaltyList.isLoyaltyWallet(owner)
                && (!hasRole(PRIVILEGED_ACCOUNT_ROLE, owner) || _haveCommonOwner(owner, account))
        ) {
            revert NotAuthorized();
        }

        // If caller and account don't share the same EVC owner, authenticate the account separately
        if (!_haveCommonOwner(owner, account)) {
            owner = evc.getAccountOwner(account);

            // If the EVC owner is not registered yet, assume the account is the owner
            if (owner == address(0)) owner = account;

            // If the account owner has the privileged account role, do not require Keyring authentication
            if (!loyaltyList.isLoyaltyWallet(owner) && !hasRole(PRIVILEGED_ACCOUNT_ROLE, owner)) {
                revert NotAuthorized();
            }
        }
    }

    /// @notice Retrieves the message sender in the context of the EVC or calling vault.
    /// @dev If the caller is a vault deployed by the recognized EVault factory, this function extracts the real
    /// caller address from the calldata. Otherwise, this function returns the account on behalf of which the current
    /// operation is being performed, which is either msg.sender or the account authenticated by the EVC.
    /// @return The address of the message sender.
    function _msgSender() internal view virtual override(BaseHookTarget, SelectorAccessControl) returns (address) {
        address msgSender = BaseHookTarget._msgSender();
        return msg.sender == msgSender ? SelectorAccessControl._msgSender() : msgSender;
    }
}
