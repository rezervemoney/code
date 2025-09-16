// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../../contracts/core/usdr/USDBond.sol";
import "../../../contracts/core/AppAuthority.sol";
import "../../../contracts/mocks/MockERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract USDBondTest is Test {
    USDBond public bond;
    AppAuthority public authority;
    MockERC20 public underlying;

    address public governor = address(0x1);
    address public guardian = address(0x2);
    address public user = address(0x3);
    address public nonGovernor = address(0x4);

    uint256 public constant INITIAL_SUPPLY = 1000000e18;
    uint256 public constant MAX_SUPPLY = 10000000e18;
    uint256 public constant UNLOCK_TIME = 1000;

    event MaxSupplySet(uint256 maxSupply);

    function setUp() public {
        // Deploy authority
        authority = new AppAuthority();

        // Deploy mock underlying token
        underlying = new MockERC20("Mock Token", "MOCK");
        underlying.mint(address(this), INITIAL_SUPPLY);

        // Deploy bond
        bond = new USDBond();

        // Initialize bond
        bond.initialize(address(authority), "USDR Bond", "USDRB", underlying, block.timestamp + UNLOCK_TIME, MAX_SUPPLY);

        // Set up roles
        authority.grantRole(authority.GOVERNOR_ROLE(), governor);
        authority.grantRole(authority.GUARDIAN_ROLE(), guardian);

        // Transfer some underlying tokens to users
        underlying.transfer(user, 100000e18);
        underlying.transfer(nonGovernor, 100000e18);
    }

    function test_Initialize() public view {
        assertEq(bond.name(), "USDR Bond");
        assertEq(bond.symbol(), "USDRB");
        assertEq(address(bond.asset()), address(underlying));
        assertEq(bond.unlockTime(), block.timestamp + UNLOCK_TIME);
        assertEq(bond.maxSupply(), MAX_SUPPLY);
        assertEq(bond.totalSupply(), 0); // Initial mint and burn should result in 0
    }

    function test_SetMaxSupply_Governor() public {
        uint256 newMaxSupply = 20000000e18;

        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit MaxSupplySet(newMaxSupply);
        bond.setMaxSupply(newMaxSupply);

        assertEq(bond.maxSupply(), newMaxSupply);
    }

    function test_SetMaxSupply_Guardian() public {
        uint256 newMaxSupply = 5000000e18; // Less than current max supply

        vm.prank(guardian);
        vm.expectEmit(true, true, true, true);
        emit MaxSupplySet(newMaxSupply);
        bond.setMaxSupply(newMaxSupply);

        assertEq(bond.maxSupply(), newMaxSupply);
    }

    function test_SetMaxSupply_NonGovernor() public {
        uint256 newMaxSupply = 20000000e18;

        vm.prank(nonGovernor);
        vm.expectRevert();
        bond.setMaxSupply(newMaxSupply);
    }

    function test_SetMaxSupply_GuardianIncreaseFails() public {
        uint256 newMaxSupply = 20000000e18; // Greater than current max supply

        vm.prank(guardian);
        vm.expectRevert();
        bond.setMaxSupply(newMaxSupply);
    }

    function test_MaxMint_BeforeUnlock() public {
        uint256 maxMintAmount = bond.maxMint(user);
        assertEq(maxMintAmount, MAX_SUPPLY);
    }

    function test_MaxMint_AfterUnlock() public {
        vm.warp(block.timestamp + UNLOCK_TIME + 1);
        uint256 maxMintAmount = bond.maxMint(user);
        assertEq(maxMintAmount, 0);
    }

    function test_MaxMint_AtMaxSupply() public {
        // Mint up to max supply
        underlying.mint(address(this), MAX_SUPPLY); // Ensure we have enough balance
        underlying.approve(address(bond), MAX_SUPPLY);
        bond.deposit(MAX_SUPPLY, address(this));

        uint256 maxMintAmount = bond.maxMint(user);
        assertEq(maxMintAmount, 0);
    }

    function test_MaxMint_PartialSupply() public {
        uint256 depositAmount = 1000000e18;
        underlying.mint(address(this), depositAmount); // Ensure we have enough balance
        underlying.approve(address(bond), depositAmount);
        bond.deposit(depositAmount, address(this));

        uint256 maxMintAmount = bond.maxMint(user);
        assertEq(maxMintAmount, MAX_SUPPLY - depositAmount);
    }

    function test_MaxDeposit_BeforeUnlock() public {
        uint256 maxDepositAmount = bond.maxDeposit(user);
        assertEq(maxDepositAmount, MAX_SUPPLY);
    }

    function test_MaxDeposit_AfterUnlock() public {
        vm.warp(block.timestamp + UNLOCK_TIME + 1);
        uint256 maxDepositAmount = bond.maxDeposit(user);
        assertEq(maxDepositAmount, 0);
    }

    function test_PreviewRedeem_BeforeUnlock() public {
        uint256 shares = 1000e18;
        uint256 assets = bond.previewRedeem(shares);
        assertEq(assets, 0);
    }

    function test_PreviewRedeem_AfterUnlock() public {
        vm.warp(block.timestamp + UNLOCK_TIME + 1);
        uint256 shares = 1000e18;
        uint256 assets = bond.previewRedeem(shares);
        assertEq(assets, shares); // 1:1 ratio
    }

    function test_PreviewWithdraw_BeforeUnlock() public {
        uint256 assets = 1000e18;
        uint256 shares = bond.previewWithdraw(assets);
        assertEq(shares, 0);
    }

    function test_PreviewWithdraw_AfterUnlock() public {
        vm.warp(block.timestamp + UNLOCK_TIME + 1);
        uint256 assets = 1000e18;
        uint256 shares = bond.previewWithdraw(assets);
        assertEq(shares, assets); // 1:1 ratio
    }

    function test_MaxWithdraw_BeforeUnlock() public {
        uint256 maxWithdrawAmount = bond.maxWithdraw(user);
        assertEq(maxWithdrawAmount, 0);
    }

    function test_MaxWithdraw_AfterUnlock() public {
        // First deposit some assets before unlock
        vm.startPrank(user);
        underlying.approve(address(bond), 1000e18);
        bond.deposit(1000e18, user);
        vm.stopPrank();

        // Now warp to after unlock
        vm.warp(block.timestamp + UNLOCK_TIME + 1);

        uint256 maxWithdrawAmount = bond.maxWithdraw(user);
        assertEq(maxWithdrawAmount, 1000e18);
    }

    function test_MaxRedeem_BeforeUnlock() public {
        uint256 maxRedeemAmount = bond.maxRedeem(user);
        assertEq(maxRedeemAmount, 0);
    }

    function test_MaxRedeem_AfterUnlock() public {
        // First deposit some assets before unlock
        vm.startPrank(user);
        underlying.approve(address(bond), 1000e18);
        bond.deposit(1000e18, user);
        vm.stopPrank();

        // Now warp to after unlock
        vm.warp(block.timestamp + UNLOCK_TIME + 1);

        uint256 maxRedeemAmount = bond.maxRedeem(user);
        assertEq(maxRedeemAmount, 1000e18);
    }

    function test_Deposit_BeforeUnlock() public {
        uint256 depositAmount = 1000e18;

        vm.startPrank(user);
        underlying.approve(address(bond), depositAmount);
        bond.deposit(depositAmount, user);
        vm.stopPrank();

        assertEq(bond.balanceOf(user), depositAmount);
        assertEq(bond.totalSupply(), depositAmount);
    }

    function test_Deposit_AfterUnlock() public {
        vm.warp(block.timestamp + UNLOCK_TIME + 1);

        uint256 depositAmount = 1000e18;

        vm.startPrank(user);
        underlying.approve(address(bond), depositAmount);
        vm.expectRevert();
        bond.deposit(depositAmount, user);
        vm.stopPrank();
    }

    function test_Deposit_ExceedsMaxSupply() public {
        uint256 depositAmount = MAX_SUPPLY + 1;

        vm.startPrank(user);
        underlying.approve(address(bond), depositAmount);
        vm.expectRevert();
        bond.deposit(depositAmount, user);
        vm.stopPrank();
    }

    function test_Withdraw_BeforeUnlock() public {
        // First deposit
        vm.startPrank(user);
        underlying.approve(address(bond), 1000e18);
        bond.deposit(1000e18, user);
        vm.stopPrank();

        // Try to withdraw before unlock
        vm.startPrank(user);
        vm.expectRevert();
        bond.withdraw(1000e18, user, user);
        vm.stopPrank();
    }

    function test_Withdraw_AfterUnlock() public {
        // First deposit
        vm.startPrank(user);
        underlying.approve(address(bond), 1000e18);
        bond.deposit(1000e18, user);
        vm.stopPrank();

        // Warp to after unlock
        vm.warp(block.timestamp + UNLOCK_TIME + 1);

        // Withdraw
        vm.startPrank(user);
        uint256 balanceBefore = underlying.balanceOf(user);
        bond.withdraw(1000e18, user, user);
        uint256 balanceAfter = underlying.balanceOf(user);
        vm.stopPrank();

        assertEq(balanceAfter - balanceBefore, 1000e18);
        assertEq(bond.balanceOf(user), 0);
    }

    function test_Redeem_BeforeUnlock() public {
        // First deposit
        vm.startPrank(user);
        underlying.approve(address(bond), 1000e18);
        bond.deposit(1000e18, user);
        vm.stopPrank();

        // Try to redeem before unlock
        vm.startPrank(user);
        vm.expectRevert();
        bond.redeem(1000e18, user, user);
        vm.stopPrank();
    }

    function test_Redeem_AfterUnlock() public {
        // First deposit
        vm.startPrank(user);
        underlying.approve(address(bond), 1000e18);
        bond.deposit(1000e18, user);
        vm.stopPrank();

        // Warp to after unlock
        vm.warp(block.timestamp + UNLOCK_TIME + 1);

        // Redeem
        vm.startPrank(user);
        uint256 balanceBefore = underlying.balanceOf(user);
        bond.redeem(1000e18, user, user);
        uint256 balanceAfter = underlying.balanceOf(user);
        vm.stopPrank();

        assertEq(balanceAfter - balanceBefore, 1000e18);
        assertEq(bond.balanceOf(user), 0);
    }

    function test_Execute_Success() public {
        // Create a simple call data to transfer from bond contract to user
        // First give the bond contract some tokens
        underlying.mint(address(bond), 1000e18);

        bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", user, 1000e18);

        vm.prank(governor);
        bond.execute(address(underlying), data);

        assertEq(underlying.balanceOf(user), 100000e18 + 1000e18);
    }

    function test_Execute_NonGovernor() public {
        bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", user, 1000e18);

        vm.prank(nonGovernor);
        vm.expectRevert();
        bond.execute(address(underlying), data);
    }

    function test_Execute_FailedCall() public {
        // Create invalid call data
        bytes memory data = abi.encodeWithSignature("nonExistentFunction()");

        vm.prank(governor);
        vm.expectRevert("USDBond: execute failed");
        bond.execute(address(underlying), data);
    }

    function test_ConvertToAssets() public {
        uint256 shares = 1000e18;
        uint256 assets = bond.convertToAssets(shares);
        assertEq(assets, shares); // 1:1 ratio
    }

    function test_ConvertToShares() public {
        uint256 assets = 1000e18;
        uint256 shares = bond.convertToShares(assets);
        assertEq(shares, assets); // 1:1 ratio
    }

    function test_TotalAssets() public {
        // Deposit some assets
        underlying.approve(address(bond), 1000e18);
        bond.deposit(1000e18, address(this));

        assertEq(bond.totalAssets(), 1000e18);
    }

    function test_Asset() public {
        assertEq(address(bond.asset()), address(underlying));
    }

    function test_Decimals() public {
        assertEq(bond.decimals(), underlying.decimals());
    }

    // ============ ERC4626 COMPATIBILITY TESTS ============

    function test_ERC4626_Asset() public {
        assertEq(address(bond.asset()), address(underlying));
    }

    function test_ERC4626_TotalAssets() public {
        // Initially no assets
        assertEq(bond.totalAssets(), 0);

        // After deposit
        underlying.approve(address(bond), 1000e18);
        bond.deposit(1000e18, address(this));
        assertEq(bond.totalAssets(), 1000e18);
    }

    function test_ERC4626_ConvertToShares() public {
        // 1:1 conversion before any deposits
        assertEq(bond.convertToShares(1000e18), 1000e18);

        // After deposit, should still be 1:1
        underlying.approve(address(bond), 1000e18);
        bond.deposit(1000e18, address(this));
        assertEq(bond.convertToShares(1000e18), 1000e18);
    }

    function test_ERC4626_ConvertToAssets() public {
        // 1:1 conversion before any deposits
        assertEq(bond.convertToAssets(1000e18), 1000e18);

        // After deposit, should still be 1:1
        underlying.approve(address(bond), 1000e18);
        bond.deposit(1000e18, address(this));
        assertEq(bond.convertToAssets(1000e18), 1000e18);
    }

    function test_ERC4626_PreviewDeposit() public {
        uint256 assets = 1000e18;
        uint256 shares = bond.previewDeposit(assets);
        assertEq(shares, assets); // 1:1 ratio
    }

    function test_ERC4626_PreviewMint() public {
        uint256 shares = 1000e18;
        uint256 assets = bond.previewMint(shares);
        assertEq(assets, shares); // 1:1 ratio
    }

    function test_ERC4626_PreviewWithdraw_BeforeUnlock() public {
        uint256 assets = 1000e18;
        uint256 shares = bond.previewWithdraw(assets);
        assertEq(shares, 0); // Should return 0 before unlock
    }

    function test_ERC4626_PreviewWithdraw_AfterUnlock() public {
        vm.warp(block.timestamp + UNLOCK_TIME + 1);
        uint256 assets = 1000e18;
        uint256 shares = bond.previewWithdraw(assets);
        assertEq(shares, assets); // 1:1 ratio after unlock
    }

    function test_ERC4626_PreviewRedeem_BeforeUnlock() public {
        uint256 shares = 1000e18;
        uint256 assets = bond.previewRedeem(shares);
        assertEq(assets, 0); // Should return 0 before unlock
    }

    function test_ERC4626_PreviewRedeem_AfterUnlock() public {
        vm.warp(block.timestamp + UNLOCK_TIME + 1);
        uint256 shares = 1000e18;
        uint256 assets = bond.previewRedeem(shares);
        assertEq(assets, shares); // 1:1 ratio after unlock
    }

    function test_ERC4626_MaxDeposit_BeforeUnlock() public {
        uint256 maxDeposit = bond.maxDeposit(user);
        assertEq(maxDeposit, MAX_SUPPLY);
    }

    function test_ERC4626_MaxDeposit_AfterUnlock() public {
        vm.warp(block.timestamp + UNLOCK_TIME + 1);
        uint256 maxDeposit = bond.maxDeposit(user);
        assertEq(maxDeposit, 0); // No deposits allowed after unlock
    }

    function test_ERC4626_MaxMint_BeforeUnlock() public {
        uint256 maxMint = bond.maxMint(user);
        assertEq(maxMint, MAX_SUPPLY);
    }

    function test_ERC4626_MaxMint_AfterUnlock() public {
        vm.warp(block.timestamp + UNLOCK_TIME + 1);
        uint256 maxMint = bond.maxMint(user);
        assertEq(maxMint, 0); // No minting allowed after unlock
    }

    function test_ERC4626_MaxWithdraw_BeforeUnlock() public {
        uint256 maxWithdraw = bond.maxWithdraw(user);
        assertEq(maxWithdraw, 0); // No withdrawals before unlock
    }

    function test_ERC4626_MaxWithdraw_AfterUnlock() public {
        // First deposit some assets
        vm.startPrank(user);
        underlying.approve(address(bond), 1000e18);
        bond.deposit(1000e18, user);
        vm.stopPrank();

        vm.warp(block.timestamp + UNLOCK_TIME + 1);
        uint256 maxWithdraw = bond.maxWithdraw(user);
        assertEq(maxWithdraw, 1000e18);
    }

    function test_ERC4626_MaxRedeem_BeforeUnlock() public {
        uint256 maxRedeem = bond.maxRedeem(user);
        assertEq(maxRedeem, 0); // No redemptions before unlock
    }

    function test_ERC4626_MaxRedeem_AfterUnlock() public {
        // First deposit some assets
        vm.startPrank(user);
        underlying.approve(address(bond), 1000e18);
        bond.deposit(1000e18, user);
        vm.stopPrank();

        vm.warp(block.timestamp + UNLOCK_TIME + 1);
        uint256 maxRedeem = bond.maxRedeem(user);
        assertEq(maxRedeem, 1000e18);
    }

    function test_ERC4626_Deposit_Events() public {
        uint256 assets = 1000e18;

        underlying.approve(address(bond), assets);
        bond.deposit(assets, address(this));

        // Verify the deposit worked
        assertEq(bond.balanceOf(address(this)), assets);
        assertEq(bond.totalSupply(), assets);
    }

    function test_ERC4626_Mint_Events() public {
        uint256 shares = 1000e18;

        underlying.approve(address(bond), shares);
        bond.mint(shares, address(this));

        // Verify the mint worked
        assertEq(bond.balanceOf(address(this)), shares);
        assertEq(bond.totalSupply(), shares);
    }

    function test_ERC4626_Withdraw_Events() public {
        // First deposit
        underlying.approve(address(bond), 1000e18);
        bond.deposit(1000e18, address(this));

        vm.warp(block.timestamp + UNLOCK_TIME + 1);

        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(this), address(0), 1000e18);

        bond.withdraw(1000e18, address(this), address(this));
    }

    function test_ERC4626_Redeem_Events() public {
        // First deposit
        underlying.approve(address(bond), 1000e18);
        bond.deposit(1000e18, address(this));

        vm.warp(block.timestamp + UNLOCK_TIME + 1);

        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(this), address(0), 1000e18);

        bond.redeem(1000e18, address(this), address(this));
    }

    function test_ERC4626_Withdraw_ExceedsBalance() public {
        // First deposit
        underlying.approve(address(bond), 1000e18);
        bond.deposit(1000e18, address(this));

        vm.warp(block.timestamp + UNLOCK_TIME + 1);

        // Try to withdraw more than balance
        vm.expectRevert();
        bond.withdraw(2000e18, address(this), address(this));
    }

    function test_ERC4626_Redeem_ExceedsBalance() public {
        // First deposit
        underlying.approve(address(bond), 1000e18);
        bond.deposit(1000e18, address(this));

        vm.warp(block.timestamp + UNLOCK_TIME + 1);

        // Try to redeem more than balance
        vm.expectRevert();
        bond.redeem(2000e18, address(this), address(this));
    }

    function test_ERC4626_Deposit_ExceedsMaxSupply() public {
        // Try to deposit more than max supply
        underlying.mint(address(this), MAX_SUPPLY + 1);
        underlying.approve(address(bond), MAX_SUPPLY + 1);

        vm.expectRevert();
        bond.deposit(MAX_SUPPLY + 1, address(this));
    }

    function test_ERC4626_Mint_ExceedsMaxSupply() public {
        // Try to mint more than max supply
        underlying.mint(address(this), MAX_SUPPLY + 1);
        underlying.approve(address(bond), MAX_SUPPLY + 1);

        vm.expectRevert();
        bond.mint(MAX_SUPPLY + 1, address(this));
    }

    function test_ERC4626_Withdraw_ZeroAmount() public {
        vm.warp(block.timestamp + UNLOCK_TIME + 1);

        // Withdraw zero amount should work
        bond.withdraw(0, address(this), address(this));
    }

    function test_ERC4626_Redeem_ZeroAmount() public {
        vm.warp(block.timestamp + UNLOCK_TIME + 1);

        // Redeem zero amount should work
        bond.redeem(0, address(this), address(this));
    }

    function test_ERC4626_Deposit_ZeroAmount() public {
        // Deposit zero amount should work
        bond.deposit(0, address(this));
        assertEq(bond.balanceOf(address(this)), 0);
    }

    function test_ERC4626_Mint_ZeroAmount() public {
        // Mint zero amount should work
        bond.mint(0, address(this));
        assertEq(bond.balanceOf(address(this)), 0);
    }

    function test_ERC4626_ConversionConsistency() public {
        uint256 assets = 1000e18;

        // Convert assets to shares and back
        uint256 shares = bond.convertToShares(assets);
        uint256 backToAssets = bond.convertToAssets(shares);
        assertEq(backToAssets, assets);

        // Convert shares to assets and back
        uint256 assetsFromShares = bond.convertToAssets(shares);
        uint256 backToShares = bond.convertToShares(assetsFromShares);
        assertEq(backToShares, shares);
    }

    function test_ERC4626_PreviewConsistency() public {
        uint256 assets = 1000e18;
        uint256 shares = 1000e18;

        // previewDeposit and convertToShares should be consistent
        assertEq(bond.previewDeposit(assets), bond.convertToShares(assets));

        // previewMint and convertToAssets should be consistent
        assertEq(bond.previewMint(shares), bond.convertToAssets(shares));
    }

    function testFuzz_SetMaxSupply(uint256 newMaxSupply) public {
        vm.assume(newMaxSupply > 0);

        vm.prank(governor);
        bond.setMaxSupply(newMaxSupply);

        assertEq(bond.maxSupply(), newMaxSupply);
    }

    function testFuzz_Deposit(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount <= MAX_SUPPLY);
        vm.assume(amount <= 1000000e18); // Reasonable upper bound

        // Ensure we have enough balance
        underlying.mint(address(this), amount);

        underlying.approve(address(bond), amount);
        bond.deposit(amount, address(this));

        assertEq(bond.balanceOf(address(this)), amount);
        assertEq(bond.totalSupply(), amount);
    }

    function testFuzz_MaxMint(uint256 currentSupply) public {
        vm.assume(currentSupply <= MAX_SUPPLY);
        vm.assume(currentSupply <= 1000000e18); // Reasonable upper bound

        if (currentSupply > 0) {
            underlying.mint(address(this), currentSupply);
            underlying.approve(address(bond), currentSupply);
            bond.deposit(currentSupply, address(this));
        }

        uint256 maxMint = bond.maxMint(user);
        assertEq(maxMint, MAX_SUPPLY - currentSupply);
    }
}
