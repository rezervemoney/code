// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import "../../core/AppAccessControlled.sol";
import "../../interfaces/IBridgeL2.sol";
import "../../interfaces/IStaking4626L2.sol";
import "../oft-proxy/OFTProxy.sol";
import "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import "@layerzerolabs/oft-evm/contracts/OFT.sol";
import "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Staking4626L2 is IStaking4626L2, ERC20Upgradeable, OFTProxy, AppAccessControlled {
    using SafeERC20 for IERC20;

    uint32 public immutable MAINNET_EID = 30101;
    address public immutable MAINNET_STAKING = 0xB33f4B9C6f0624EdeAE8881c97381837760D52CB;

    /// @notice The rate of the staking
    uint256 public rate;

    /// @notice The underlying token
    /// @dev This is the token that is being staked
    IERC20 public underlying;

    /// @inheritdoc IStaking4626L2
    function initialize(address _authority, address _lzEndpoint, address _delegate, address _underlying)
        external
        initializer
    {
        __AppAccessControlled_init(_authority);
        __OFTProxy_init("Liquid Staked Rezerve.money", "lstRZR", _lzEndpoint, _delegate);
        underlying = IERC20(_underlying);
        if (rate == 0) rate = 1e18;

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
    function setRate(uint256 _rate) external onlyBridge {
        uint256 oldRate = rate;
        rate = _rate;
        require(rate >= oldRate, "Rate must be greater than or equal to the old rate");
        emit RateUpdated(rate, oldRate);
    }

    /// @inheritdoc IStaking4626L2
    function flushToL1() external payable onlyExecutor {
        uint256 balance = underlying.balanceOf(address(this));
        IOFT(address(underlying)).send{value: msg.value}(
            SendParam({
                dstEid: MAINNET_EID,
                to: bytes32(uint256(uint160(MAINNET_STAKING))),
                amountLD: balance,
                minAmountLD: balance,
                extraOptions: "",
                composeMsg: "",
                oftCmd: ""
            }),
            MessagingFee({nativeFee: msg.value, lzTokenFee: 0}),
            address(this)
        );
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
        return convertToShares(assets);
    }

    /// @inheritdoc IERC4626
    function previewMint(uint256 shares) external view returns (uint256) {
        return convertToAssets(shares);
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
        shares = convertToShares(assets);
        underlying.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
    }

    /// @inheritdoc IERC4626
    function mint(uint256 shares, address receiver) external returns (uint256 assets) {
        assets = convertToAssets(shares);
        underlying.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
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
