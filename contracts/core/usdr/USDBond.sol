// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "../AppAccessControlled.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

/// @title USDBond
/// @notice A token that is locked for a period of time
contract USDBond is ERC4626Upgradeable, AppAccessControlled {
    /// @notice The time at which the token is unlocked
    uint256 public unlockTime;

    /// @notice The max supply of the token
    /// @dev maxSupply is set to 1e18 by default
    uint256 public maxSupply;

    /// @notice Error emitted when the max supply is exceeded
    /// @param totalAssets The total assets
    /// @param maxSupply The max supply
    error MaxSupplyExceeded(uint256 totalAssets, uint256 maxSupply);

    /// @notice Event emitted when the max supply is set
    /// @param maxSupply The new max supply
    event MaxSupplySet(uint256 maxSupply);

    /// @notice Constructor
    /// @param _authority The authority address
    /// @param _name The name of the token
    /// @param _symbol The symbol of the token
    /// @param _underlying The underlying token
    /// @param _unlockTime The time at which the token is unlocked
    function initialize(
        address _authority,
        string memory _name,
        string memory _symbol,
        IERC20 _underlying,
        uint256 _unlockTime,
        uint256 _maxSupply
    ) external initializer {
        __AppAccessControlled_init(_authority);
        __ERC4626_init(_underlying);
        __ERC20_init(_name, _symbol);
        _mint(msg.sender, 1e18);
        _burn(msg.sender, 1e18);
        unlockTime = _unlockTime;
        maxSupply = _maxSupply;
    }

    /// @notice Set the max supply of the token
    /// @param _maxSupply The new max supply
    /// @dev This function is only callable by the guardian or governor
    /// @dev If the max supply is less than the current max supply, the function is only callable by the guardian or governor
    /// @dev If the max supply is greater than the current max supply, the function is only callable by the governor
    function setMaxSupply(uint256 _maxSupply) public {
        uint256 currentSupplyCap = maxSupply;
        if (_maxSupply < currentSupplyCap) _onlyGuardianOrGovernor();
        else _onlyGovernor();
        maxSupply = _maxSupply;
        emit MaxSupplySet(_maxSupply);
    }

    /// @inheritdoc IERC4626
    function maxDeposit(address) public view override returns (uint256) {
        return _convertToAssets(maxMint(address(0)), Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    function maxMint(address) public view override returns (uint256) {
        if (block.timestamp > unlockTime) return 0;
        return totalSupply() >= maxSupply ? 0 : maxSupply - totalSupply();
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256 shares) public view override returns (uint256 assets) {
        if (block.timestamp < unlockTime) return 0;
        return super.previewRedeem(shares);
    }

    /// @inheritdoc IERC4626
    function previewWithdraw(uint256 assets) public view override returns (uint256 shares) {
        if (block.timestamp < unlockTime) return 0;
        return super.previewWithdraw(assets);
    }

    /// @inheritdoc IERC4626
    function maxWithdraw(address owner) public view override returns (uint256) {
        if (block.timestamp < unlockTime) return 0;
        return super.maxWithdraw(owner);
    }

    /// @inheritdoc IERC4626
    function maxRedeem(address owner) public view override returns (uint256) {
        if (block.timestamp < unlockTime) return 0;
        return super.maxRedeem(owner);
    }

    /// @notice Execute a function
    /// @param _to The address of the function to execute
    /// @param _data The data to execute
    /// @dev This function is only callable by the governor
    function execute(address _to, bytes calldata _data) external onlyGovernor {
        (bool success,) = _to.call(_data);
        require(success, "USDBond: execute failed");
    }
}
