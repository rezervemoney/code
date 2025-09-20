// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "../../core/AppAccessControlled.sol";
import "../../interfaces/IBridgeL2.sol";
import "../../interfaces/IStaking4626L2.sol";
import "../oft/OFTProxy.sol";
import "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import "@layerzerolabs/oft-evm/contracts/OFT.sol";
import "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Staking4626L2 is IStaking4626L2, OFTProxy, AppAccessControlled {
    using SafeERC20 for IERC20;

    /// @notice The rate of the staking
    uint256 public rate;

    /// @notice The deposit fee
    uint256 public depositFee;

    /// @notice The underlying token
    /// @dev This is the token that is being staked
    IERC20 public underlying;

    /// @notice Total fees collected from deposits
    uint256 public totalFeesCollected;

    /// @notice The last time the rate was updated
    uint256 public lastRateUpdated;

    /// @inheritdoc IStaking4626L2
    function initialize(address _authority, address _lzEndpoint, address _delegate, address _underlying)
        external
        reinitializer(10)
    {
        __AppAccessControlled_init(_authority);
        __OFTProxy_init("Liquid Staked Rezerve.money", "lstRZR", _lzEndpoint, _delegate);
        underlying = IERC20(_underlying);
        if (rate == 0) rate = 1e18;

        depositFee = 0.01e18; // 1%

        _mint(address(this), 1e18);
        _burn(address(this), 1e18);
    }

    receive() external payable {}

    function _checkOwner() internal view virtual override {
        if (!authority.isGovernor(_msgSender())) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /// @inheritdoc IStaking4626L2
    function setRate(uint256 _rate) external onlyBridgeOrGovernor {
        uint256 oldRate = rate;
        rate = _rate;
        require(rate >= oldRate, "Rate must be greater than or equal to the old rate");
        emit RateUpdated(rate, oldRate);
        lastRateUpdated = block.timestamp;
    }

    /// @inheritdoc IStaking4626L2
    function setDepositFee(uint256 _depositFee) external onlyGovernor {
        require(_depositFee <= 0.1e18, "Deposit fee cannot exceed 10%");
        depositFee = _depositFee;
        emit DepositFeeUpdated(depositFee);
    }

    /// @inheritdoc IERC4626
    function convertToAssets(uint256 shares) public view returns (uint256) {
        return shares * rate / 1e18;
    }

    /// @inheritdoc IERC4626
    function convertToShares(uint256 assets) public view returns (uint256) {
        return assets * 1e18 / rate;
    }

    /// @inheritdoc IERC4626
    function maxDeposit(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    /// @inheritdoc IERC4626
    function maxMint(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    /// @inheritdoc IERC4626
    function maxWithdraw(address) external pure returns (uint256) {
        return 0;
    }

    /// @inheritdoc IERC4626
    function maxRedeem(address) external pure returns (uint256) {
        return 0;
    }

    /// @inheritdoc IERC4626
    function asset() external view returns (address) {
        return address(underlying);
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 assets) external view returns (uint256) {
        uint256 feeAmount = (assets * depositFee) / 1e18;
        uint256 netAssets = assets - feeAmount;
        return convertToShares(netAssets);
    }

    /// @inheritdoc IERC4626
    function previewMint(uint256 shares) external view returns (uint256) {
        uint256 grossAssets = convertToAssets(shares);
        uint256 feeAmount = (grossAssets * depositFee) / (1e18 - depositFee);
        return grossAssets + feeAmount;
    }

    /// @inheritdoc IERC4626
    function previewWithdraw(uint256 assets) external view returns (uint256) {
        return convertToShares(assets);
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256 shares) external view returns (uint256) {
        return convertToAssets(shares);
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        require(assets > 0, "ZERO_ASSETS");

        // Calculate fee and net assets
        uint256 feeAmount = (assets * depositFee) / 1e18;
        uint256 netAssets = assets - feeAmount;

        // Calculate shares based on net assets
        shares = convertToShares(netAssets);
        require(shares > 0, "ZERO_SHARES");

        // Process the deposit
        _processDeposit(msg.sender, receiver, assets, shares, feeAmount);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /// @inheritdoc IERC4626
    function mint(uint256 shares, address receiver) external returns (uint256 assets) {
        require(shares > 0, "ZERO_SHARES");

        // Calculate gross assets needed (including fee)
        uint256 grossAssets = convertToAssets(shares);
        uint256 feeAmount = (grossAssets * depositFee) / (1e18 - depositFee);
        assets = grossAssets + feeAmount;

        require(assets > 0, "ZERO_ASSETS");

        // Process the mint
        _processDeposit(msg.sender, receiver, assets, shares, feeAmount);

        // Note: IERC4626 doesn't have a Mint event, so we only emit DepositFeeCollected if there are fees
    }

    /// @dev Internal function to process deposits and mints
    /// @param caller The address calling the function
    /// @param receiver The address to receive the shares
    /// @param assets The amount of assets transferred
    /// @param shares The amount of shares to mint
    /// @param feeAmount The fee amount collected
    function _processDeposit(address caller, address receiver, uint256 assets, uint256 shares, uint256 feeAmount)
        internal
    {
        require(block.timestamp - lastRateUpdated >= 1 days, "Rate update cooldown");

        // Transfer the full amount from user to the bridge
        underlying.safeTransferFrom(caller, authority.bridge(), assets);

        // Mint shares to receiver
        _mint(receiver, shares);

        // Track fees if any
        if (feeAmount > 0) {
            totalFeesCollected += feeAmount;
            emit DepositFeeCollected(caller, feeAmount);
        }
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256, address, address) external pure returns (uint256) {
        require(false, "Only on L1");
        return 0;
    }

    /// @inheritdoc IERC4626
    function redeem(uint256, address, address) external pure returns (uint256) {
        require(false, "Only on L1");
        return 0;
    }

    /// @inheritdoc IERC4626
    function totalAssets() external view returns (uint256) {
        return totalSupply() * rate / 1e18;
    }

    function _debit(address _from, uint256 _amountLD, uint256 _minAmountLD, uint32 _dstEid)
        internal
        virtual
        override
        returns (uint256 amountSentLD, uint256 amountReceivedLD)
    {
        (amountSentLD, amountReceivedLD) = _debitView(_amountLD, _minAmountLD, _dstEid);
        _burn(_from, amountSentLD);
    }

    function _credit(address _to, uint256 _amountLD, uint32 /*_srcEid*/ )
        internal
        virtual
        override
        returns (uint256 amountReceivedLD)
    {
        if (_to == address(0x0)) _to = address(0xdead);
        _mint(_to, _amountLD);
        return _amountLD;
    }
}
