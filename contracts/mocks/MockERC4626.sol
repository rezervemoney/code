// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Mock ERC4626 Vault
/// @notice A mock ERC4626 vault that simulates a lending token that appreciates over time
contract MockERC4626 is ERC20, IERC4626 {
    using Math for uint256;
    using SafeERC20 for ERC20;

    ERC20 private immutable _asset;
    uint256 public totalAssets;
    uint256 public exchangeRate = 1e18; // Initial exchange rate 1:1
    uint256 public lastUpdateTime;
    uint256 public interestRatePerSecond = 1e15; // 0.1% per day

    constructor(string memory name, string memory symbol, ERC20 asset_) ERC20(name, symbol) {
        _asset = asset_;
        lastUpdateTime = block.timestamp;
    }

    /// @notice Update the exchange rate based on time passed and interest accrued
    function updateExchangeRate() public {
        uint256 timePassed = block.timestamp - lastUpdateTime;
        if (timePassed > 0) {
            uint256 interestAccrued = totalAssets * interestRatePerSecond * timePassed / 1e18;
            totalAssets += interestAccrued;
            if (totalSupply() > 0) {
                exchangeRate = totalAssets * 1e18 / totalSupply();
            }
            lastUpdateTime = block.timestamp;
        }
    }

    /// @notice Set the interest rate per second
    function setInterestRatePerSecond(uint256 _rate) external {
        updateExchangeRate();
        interestRatePerSecond = _rate;
    }

    /// @notice Deposit assets and mint shares
    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        updateExchangeRate();
        require(assets > 0, "Zero assets");

        shares = previewDeposit(assets);
        _mint(receiver, shares);
        totalAssets += assets;

        _asset.safeTransferFrom(msg.sender, address(this), assets);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /// @notice Mint shares for assets
    function mint(uint256 shares, address receiver) public override returns (uint256 assets) {
        updateExchangeRate();
        require(shares > 0, "Zero shares");

        assets = previewMint(shares);
        _mint(receiver, shares);
        totalAssets += assets;

        _asset.safeTransferFrom(msg.sender, address(this), assets);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /// @notice Withdraw assets by burning shares
    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256 shares) {
        updateExchangeRate();
        require(assets > 0, "Zero assets");

        shares = previewWithdraw(assets);
        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }
        _burn(owner, shares);
        totalAssets -= assets;

        _asset.safeTransfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    /// @notice Redeem shares for assets
    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256 assets) {
        updateExchangeRate();
        require(shares > 0, "Zero shares");

        assets = previewRedeem(shares);
        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }
        _burn(owner, shares);
        totalAssets -= assets;

        _asset.safeTransfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    /// @notice Preview deposit
    function previewDeposit(uint256 assets) public view override returns (uint256) {
        if (totalSupply() == 0) {
            return assets;
        }
        return assets * totalSupply() / totalAssets;
    }

    /// @notice Preview mint
    function previewMint(uint256 shares) public view override returns (uint256) {
        if (totalSupply() == 0) {
            return shares;
        }
        return shares * totalAssets / totalSupply();
    }

    /// @notice Preview withdraw
    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        if (totalSupply() == 0) {
            return assets;
        }
        return assets * totalSupply() / totalAssets;
    }

    /// @notice Preview redeem
    function previewRedeem(uint256 shares) public view override returns (uint256) {
        if (totalSupply() == 0) {
            return shares;
        }
        return shares * totalAssets / totalSupply();
    }

    /// @notice Convert assets to shares
    function convertToShares(uint256 assets) public view override returns (uint256) {
        return previewDeposit(assets);
    }

    /// @notice Convert shares to assets
    function convertToAssets(uint256 shares) public view override returns (uint256) {
        return previewRedeem(shares);
    }

    /// @notice Maximum deposit
    function maxDeposit(address) public pure override returns (uint256) {
        return type(uint256).max;
    }

    /// @notice Maximum mint
    function maxMint(address) public pure override returns (uint256) {
        return type(uint256).max;
    }

    /// @notice Maximum withdraw
    function maxWithdraw(address owner) public view override returns (uint256) {
        return convertToAssets(balanceOf(owner));
    }

    /// @notice Maximum redeem
    function maxRedeem(address owner) public view override returns (uint256) {
        return balanceOf(owner);
    }

    /// @notice Get the underlying asset address
    function asset() external view override returns (address) {
        return address(_asset);
    }

    /// @notice Decimals of the vault
    function decimals() public view override(ERC20, IERC20Metadata) returns (uint8) {
        return ERC20.decimals();
    }
}
