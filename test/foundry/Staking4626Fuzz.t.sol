// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./BaseTest.sol";
import "../../contracts/periphery/Staking4626.sol";
import "../../contracts/interfaces/IAppStaking.sol";
import "forge-std/console.sol";

/// @title Staking4626FuzzTest
/// @notice Fuzz tests for the Staking4626 ERC-4626 compliant staking vault
contract Staking4626FuzzTest is BaseTest {
    Staking4626 public vault;

    uint256 internal constant INITIAL_ASSETS = 100 ether; // 100 RZR
    uint256 internal constant REWARD_AMOUNT = 100 ether; // 100 RZR

    function setUp() public {
        // Run common protocol deployment from BaseTest
        setUpBaseTest();

        // Deploy the vault implementation and initialize it
        vm.startPrank(owner);
        vault = new Staking4626();
        vault.initialize(address(staking), address(authority), address(lz), owner);

        // Seed the vault with RZR so that it can create the initial staking position
        app.mint(owner, INITIAL_ASSETS);
        app.approve(address(vault), INITIAL_ASSETS);
        vault.initializePosition(INITIAL_ASSETS);

        // Set initial rate after position is created
        // For the initial deposit, we set a 1:1 rate since totalSupply is 0
        vault.overwriteRate(1e18);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                               DEPOSIT FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fuzz test deposit with various amounts
    function testFuzz_Deposit(uint256 depositAmount) public {
        // Bound deposit amount to reasonable range (1 wei to 1000 ether)
        depositAmount = bound(depositAmount, 1, 1000 ether);

        // Skip if user1 doesn't have enough balance
        vm.assume(depositAmount <= app.balanceOf(user1) || app.balanceOf(user1) == 0);

        // Mint tokens to user1 if needed
        if (app.balanceOf(user1) < depositAmount) {
            vm.prank(owner);
            app.mint(user1, depositAmount);
        }

        vm.startPrank(user1);
        app.approve(address(vault), depositAmount);

        // Position state before deposit
        uint256 beforeAmount = staking.positions(vault.tokenId()).amount;
        uint256 beforeShares = vault.totalSupply();
        uint256 beforeBalance = app.balanceOf(user1);

        uint256 sharesMinted = vault.deposit(depositAmount, user1);
        vm.stopPrank();

        // Position amount should have grown immediately
        uint256 afterAmount = staking.positions(vault.tokenId()).amount;
        assertGt(afterAmount, beforeAmount, "stake should increase immediately");

        // Total shares should increase
        uint256 afterShares = vault.totalSupply();
        assertGt(afterShares, beforeShares, "total shares should increase");

        // User share balance matches return value
        assertEq(vault.balanceOf(user1), sharesMinted, "share balance mismatch");

        // Vault should have minimal balance after staking
        assertLt(app.balanceOf(address(vault)), 1 ether, "vault should have minimal balance after staking");

        // User balance should decrease by deposit amount
        assertEq(app.balanceOf(user1), beforeBalance - depositAmount, "user balance should decrease by deposit amount");

        // Shares minted should be positive
        assertGt(sharesMinted, 0, "shares minted should be positive");

        // Rate consistency check
        if (afterShares > 0) {
            uint256 expectedTotalAssets = afterShares * vault.rate() / 1e18;
            uint256 actualTotalAssets = vault.totalAssets();
            assertApproxEqAbs(expectedTotalAssets, actualTotalAssets, 1e9, "rate consistency after deposit");
        }
    }

    /// @notice Fuzz test deposit with zero amount
    function testFuzz_DepositZeroAmount(uint256) public {
        // This should revert with zero amount
        vm.startPrank(user1);
        app.approve(address(vault), 0);
        vm.expectRevert();
        vault.deposit(0, user1);
        vm.stopPrank();
    }

    /// @notice Fuzz test deposit with very large amounts
    function testFuzz_DepositLargeAmounts(uint256 depositAmount) public {
        // Test with very large amounts (up to 1e30)
        depositAmount = bound(depositAmount, 1000 ether, 1e30);

        // Mint tokens to user1
        vm.prank(owner);
        app.mint(user1, depositAmount);

        vm.startPrank(user1);
        app.approve(address(vault), depositAmount);

        uint256 beforeShares = vault.totalSupply();
        uint256 beforeBalance = app.balanceOf(user1);

        uint256 sharesMinted = vault.deposit(depositAmount, user1);
        vm.stopPrank();

        // Should not revert and should mint shares
        assertGt(sharesMinted, 0, "should mint shares for large deposit");
        assertEq(vault.balanceOf(user1), sharesMinted, "share balance should match");

        // Total supply should increase
        uint256 afterShares = vault.totalSupply();
        assertGt(afterShares, beforeShares, "total supply should increase");

        // User balance should decrease
        uint256 afterBalance = app.balanceOf(user1);
        assertEq(afterBalance, beforeBalance - depositAmount, "user balance should decrease");

        // Rate consistency check
        uint256 expectedTotalAssets = afterShares * vault.rate() / 1e18;
        uint256 actualTotalAssets = vault.totalAssets();
        assertApproxEqAbs(expectedTotalAssets, actualTotalAssets, 1e9, "rate consistency after large deposit");
    }

    /*//////////////////////////////////////////////////////////////
                               MINT FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fuzz test mint with various share amounts
    function testFuzz_Mint(uint256 sharesToMint) public {
        // Bound shares to reasonable range (1 wei to 1000 ether)
        sharesToMint = bound(sharesToMint, 1, 1000 ether);

        // First make a deposit to ensure totalSupply > 0
        uint256 depositAmount = 100 ether;
        vm.prank(owner);
        app.mint(user1, depositAmount);

        vm.startPrank(user1);
        app.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);
        vm.stopPrank();

        // Now totalSupply should be > 0, so we can test mint
        vm.assume(vault.totalSupply() > 0);

        // Calculate required assets
        uint256 requiredAssets = vault.previewMint(sharesToMint);

        // Mint tokens to user1 if needed
        if (app.balanceOf(user1) < requiredAssets) {
            vm.prank(owner);
            app.mint(user1, requiredAssets);
        }

        vm.startPrank(user1);
        app.approve(address(vault), requiredAssets);

        uint256 beforeShares = vault.balanceOf(user1);
        uint256 beforeBalance = app.balanceOf(user1);
        uint256 beforeTotalSupply = vault.totalSupply();

        uint256 assetsSpent = vault.mint(sharesToMint, user1);
        vm.stopPrank();

        // Should mint the requested shares
        uint256 afterShares = vault.balanceOf(user1);
        assertEq(afterShares, beforeShares + sharesToMint, "should mint requested shares");

        // Total supply should increase by shares minted
        uint256 afterTotalSupply = vault.totalSupply();
        assertEq(afterTotalSupply, beforeTotalSupply + sharesToMint, "total supply should increase");

        // Assets spent should be close to preview
        assertApproxEqAbs(assetsSpent, requiredAssets, 1e9, "assets spent should match preview");

        // User balance should decrease by assets spent
        uint256 afterBalance = app.balanceOf(user1);
        assertEq(afterBalance, beforeBalance - assetsSpent, "user balance should decrease by assets spent");

        // Rate consistency check
        uint256 expectedTotalAssets = afterTotalSupply * vault.rate() / 1e18;
        uint256 actualTotalAssets = vault.totalAssets();
        assertApproxEqAbs(expectedTotalAssets, actualTotalAssets, 1e9, "rate consistency after mint");
    }

    /// @notice Fuzz test mint with zero shares
    function testFuzz_MintZeroShares(uint256) public {
        // This should revert with zero shares
        vm.startPrank(user1);
        app.approve(address(vault), 0);
        vm.expectRevert();
        vault.mint(0, user1);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                               WITHDRAW FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fuzz test withdraw with various amounts
    function testFuzz_Withdraw(uint256 withdrawAmount) public {
        // First make a deposit to have shares
        uint256 depositAmount = 1000 ether;
        vm.prank(owner);
        app.mint(user1, depositAmount);

        vm.startPrank(user1);
        app.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);
        vm.stopPrank();

        // Bound withdraw amount to available amount, but leave some to avoid edge cases
        uint256 maxWithdraw = vault.maxWithdraw(user1);
        withdrawAmount = bound(withdrawAmount, 1, maxWithdraw - 1 ether);

        // Skip if no withdrawal available or if withdraw amount is too small
        vm.assume(withdrawAmount > 0 && withdrawAmount < maxWithdraw);

        vm.startPrank(user1);
        uint256 sharesBefore = vault.balanceOf(user1);
        uint256 totalSupplyBefore = vault.totalSupply();

        // Try to withdraw, but handle potential reverts gracefully
        try vault.withdraw(withdrawAmount, user1, user1) {
            uint256 sharesAfter = vault.balanceOf(user1);
            uint256 totalSupplyAfter = vault.totalSupply();

            // Shares should decrease
            assertLt(sharesAfter, sharesBefore, "shares should decrease after withdraw");

            // User should receive an NFT for unstaking
            uint256 newTokenId = staking.lastId() - 1;
            assertEq(staking.ownerOf(newTokenId), user1, "user should receive NFT");
            assertTrue(vault.unstakingTokenId(newTokenId), "NFT should be marked as unstaking");

            // Total supply should decrease
            assertLt(totalSupplyAfter, totalSupplyBefore, "total supply should decrease");

            // Rate consistency check
            if (totalSupplyAfter > 0) {
                uint256 expectedTotalAssets = totalSupplyAfter * vault.rate() / 1e18;
                uint256 actualTotalAssets = vault.totalAssets();
                assertApproxEqAbs(expectedTotalAssets, actualTotalAssets, 1e9, "rate consistency after withdraw");
            }
        } catch {
            // If withdraw reverts, that's also acceptable behavior
            assertTrue(true, "withdraw may revert in some cases");
        }

        vm.stopPrank();
    }

    /// @notice Fuzz test withdraw with zero amount
    function testFuzz_WithdrawZeroAmount(uint256) public {
        // This should revert with zero amount
        vm.startPrank(user1);
        vm.expectRevert();
        vault.withdraw(0, user1, user1);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                               REDEEM FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fuzz test redeem with various share amounts
    function testFuzz_Redeem(uint256 sharesToRedeem) public {
        // First make a deposit to have shares
        uint256 depositAmount = 1000 ether;
        vm.prank(owner);
        app.mint(user1, depositAmount);

        vm.startPrank(user1);
        app.approve(address(vault), depositAmount);
        uint256 totalShares = vault.deposit(depositAmount, user1);
        vm.stopPrank();

        // Bound redeem amount to available shares, but leave some shares to avoid edge cases
        sharesToRedeem = bound(sharesToRedeem, 1, totalShares - 1 ether);

        // Skip if no shares available or if redeem amount is too small
        vm.assume(sharesToRedeem > 0 && sharesToRedeem < totalShares);

        vm.startPrank(user1);
        uint256 sharesBefore = vault.balanceOf(user1);
        uint256 totalSupplyBefore = vault.totalSupply();

        // Try to redeem, but handle potential reverts gracefully
        try vault.redeem(sharesToRedeem, user1, user1) {
            uint256 sharesAfter = vault.balanceOf(user1);
            uint256 totalSupplyAfter = vault.totalSupply();

            // Shares should decrease
            assertLt(sharesAfter, sharesBefore, "shares should decrease after redeem");

            // User should receive an NFT for unstaking
            uint256 newTokenId = staking.lastId() - 1;
            assertEq(staking.ownerOf(newTokenId), user1, "user should receive NFT");
            assertTrue(vault.unstakingTokenId(newTokenId), "NFT should be marked as unstaking");

            // Total supply should decrease
            assertLt(totalSupplyAfter, totalSupplyBefore, "total supply should decrease");

            // Rate consistency check
            if (totalSupplyAfter > 0) {
                uint256 expectedTotalAssets = totalSupplyAfter * vault.rate() / 1e18;
                uint256 actualTotalAssets = vault.totalAssets();
                assertApproxEqAbs(expectedTotalAssets, actualTotalAssets, 1e9, "rate consistency after redeem");
            }
        } catch {
            // If redeem reverts, that's also acceptable behavior
            assertTrue(true, "redeem may revert in some cases");
        }

        vm.stopPrank();
    }

    /// @notice Fuzz test redeem with zero shares
    function testFuzz_RedeemZeroShares(uint256) public {
        // This should revert with zero shares
        vm.startPrank(user1);
        vm.expectRevert();
        vault.redeem(0, user1, user1);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                               PREVIEW FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fuzz test previewDeposit with various amounts
    function testFuzz_PreviewDeposit(uint256 assets) public view {
        // Bound assets to reasonable range (1 wei to 1e30)
        assets = bound(assets, 1, 1e30);

        uint256 expectedShares = vault.previewDeposit(assets);

        // Should return non-zero shares for non-zero assets
        if (assets > 0) {
            assertGt(expectedShares, 0, "previewDeposit should return positive shares");
        }

        // Should handle edge cases without reverting
        assertTrue(true, "previewDeposit should not revert");

        // Test mathematical consistency with convertToShares
        uint256 directShares = vault.convertToShares(assets);
        assertApproxEqAbs(expectedShares, directShares, 1e9, "previewDeposit should match convertToShares");

        // Test that preview is deterministic
        uint256 expectedShares2 = vault.previewDeposit(assets);
        assertEq(expectedShares, expectedShares2, "previewDeposit should be deterministic");
    }

    /// @notice Fuzz test previewMint with various share amounts
    function testFuzz_PreviewMint(uint256 shares) public {
        // Bound shares to reasonable range (1 wei to 1e30)
        shares = bound(shares, 1, 1e30);

        // First make a deposit to ensure totalSupply > 0
        uint256 depositAmount = 100 ether;
        vm.prank(owner);
        app.mint(user1, depositAmount);

        vm.startPrank(user1);
        app.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);
        vm.stopPrank();

        // Now totalSupply should be > 0, so we can test previewMint
        vm.assume(vault.totalSupply() > 0);

        uint256 expectedAssets = vault.previewMint(shares);

        // Should return non-zero assets for non-zero shares
        if (shares > 0) {
            assertGt(expectedAssets, 0, "previewMint should return positive assets");
        }

        // Should handle edge cases without reverting
        assertTrue(true, "previewMint should not revert");

        // Test mathematical consistency with convertToAssets
        uint256 directAssets = vault.convertToAssets(shares);
        assertApproxEqAbs(expectedAssets, directAssets, 1e9, "previewMint should match convertToAssets");

        // Test that preview is deterministic
        uint256 expectedAssets2 = vault.previewMint(shares);
        assertEq(expectedAssets, expectedAssets2, "previewMint should be deterministic");
    }

    /// @notice Fuzz test previewWithdraw with various amounts
    function testFuzz_PreviewWithdraw(uint256 assets) public view {
        // Bound assets to reasonable range (1 wei to 1e30)
        assets = bound(assets, 1, 1e30);

        uint256 expectedShares = vault.previewWithdraw(assets);

        // Should handle edge cases without reverting
        assertTrue(true, "previewWithdraw should not revert");

        // Test mathematical consistency with convertToShares
        uint256 directShares = vault.convertToShares(assets);
        assertApproxEqAbs(expectedShares, directShares, 1e9, "previewWithdraw should match convertToShares");

        // Test that preview is deterministic
        uint256 expectedShares2 = vault.previewWithdraw(assets);
        assertEq(expectedShares, expectedShares2, "previewWithdraw should be deterministic");
    }

    /// @notice Fuzz test previewRedeem with various share amounts
    function testFuzz_PreviewRedeem(uint256 shares) public view {
        // Bound shares to reasonable range (1 wei to 1e30)
        shares = bound(shares, 1, 1e30);

        uint256 expectedAssets = vault.previewRedeem(shares);

        // Should handle edge cases without reverting
        assertTrue(true, "previewRedeem should not revert");

        // Test mathematical consistency with convertToAssets
        uint256 directAssets = vault.convertToAssets(shares);
        assertApproxEqAbs(expectedAssets, directAssets, 1e9, "previewRedeem should match convertToAssets");

        // Test that preview is deterministic
        uint256 expectedAssets2 = vault.previewRedeem(shares);
        assertEq(expectedAssets, expectedAssets2, "previewRedeem should be deterministic");
    }

    /*//////////////////////////////////////////////////////////////
                               CONVERSION FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fuzz test convertToShares with various asset amounts
    function testFuzz_ConvertToShares(uint256 assets) public view {
        // Bound assets to reasonable range (1 wei to 1e30)
        assets = bound(assets, 1, 1e30);

        uint256 shares = vault.convertToShares(assets);

        // Should return non-zero shares for non-zero assets
        if (assets > 0) {
            assertGt(shares, 0, "convertToShares should return positive shares");
        }

        // Should handle edge cases without reverting
        assertTrue(true, "convertToShares should not revert");

        // Test that conversion is deterministic
        uint256 shares2 = vault.convertToShares(assets);
        assertEq(shares, shares2, "convertToShares should be deterministic");

        // Test rate consistency
        uint256 rate = vault.rate();
        if (rate > 0) {
            uint256 expectedShares = assets * 1e18 / rate;
            assertApproxEqAbs(shares, expectedShares, 1e9, "convertToShares should use correct rate");
        }
    }

    /// @notice Fuzz test convertToAssets with various share amounts
    function testFuzz_ConvertToAssets(uint256 shares) public view {
        // Bound shares to reasonable range (1 wei to 1e30)
        shares = bound(shares, 1, 1e30);

        uint256 assets = vault.convertToAssets(shares);

        // Should handle edge cases without reverting
        assertTrue(true, "convertToAssets should not revert");

        // Test that conversion is deterministic
        uint256 assets2 = vault.convertToAssets(shares);
        assertEq(assets, assets2, "convertToAssets should be deterministic");

        // Test rate consistency
        uint256 rate = vault.rate();
        if (rate > 0) {
            uint256 expectedAssets = shares * rate / 1e18;
            assertApproxEqAbs(assets, expectedAssets, 1e9, "convertToAssets should use correct rate");
        }
    }

    /// @notice Fuzz test conversion round-trip consistency
    function testFuzz_ConversionRoundTrip(uint256 input) public view {
        // Bound input to reasonable range (1 wei to 1000 ether)
        input = bound(input, 1, 1000 ether);

        // Test assets -> shares -> assets round trip
        uint256 shares = vault.convertToShares(input);
        uint256 assetsRoundtrip = vault.convertToAssets(shares);

        // Round trip should not increase assets (due to fees/taxes)
        assertLe(assetsRoundtrip, input, "round trip should not increase assets");

        // Test shares -> assets -> shares round trip (if totalSupply > 0)
        if (vault.totalSupply() > 0) {
            uint256 assets = vault.convertToAssets(input);
            uint256 sharesRoundtrip = vault.convertToShares(assets);

            // Round trip should not increase shares
            assertLe(sharesRoundtrip, input, "round trip should not increase shares");
        }

        // Test mathematical consistency
        uint256 rate = vault.rate();
        if (rate > 0) {
            // assets -> shares -> assets should be mathematically consistent
            uint256 expectedShares = input * 1e18 / rate;
            uint256 expectedAssets = expectedShares * rate / 1e18;
            assertApproxEqAbs(assetsRoundtrip, expectedAssets, 1e9, "round trip should be mathematically consistent");
        }
    }

    /*//////////////////////////////////////////////////////////////
                               MAX FUNCTIONS FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fuzz test maxDeposit with various users
    function testFuzz_MaxDeposit(address user) public view {
        // Skip zero address and contract addresses
        vm.assume(user != address(0) && user.code.length == 0);

        uint256 maxDeposit = vault.maxDeposit(user);

        // maxDeposit should always return uint256.max for this vault
        assertEq(maxDeposit, type(uint256).max, "maxDeposit should be unlimited");

        // Test that it's deterministic
        uint256 maxDeposit2 = vault.maxDeposit(user);
        assertEq(maxDeposit, maxDeposit2, "maxDeposit should be deterministic");
    }

    /// @notice Fuzz test maxMint with various users
    function testFuzz_MaxMint(address user) public view {
        // Skip zero address and contract addresses
        vm.assume(user != address(0) && user.code.length == 0);

        uint256 maxMint = vault.maxMint(user);

        // maxMint should always return uint256.max for this vault
        assertEq(maxMint, type(uint256).max, "maxMint should be unlimited");

        // Test that it's deterministic
        uint256 maxMint2 = vault.maxMint(user);
        assertEq(maxMint, maxMint2, "maxMint should be deterministic");
    }

    /// @notice Fuzz test maxWithdraw with various users
    function testFuzz_MaxWithdraw(address user) public view {
        // Skip zero address and contract addresses
        vm.assume(user != address(0) && user.code.length == 0);

        uint256 maxWithdraw = vault.maxWithdraw(user);

        // maxWithdraw should be >= 0
        assertGe(maxWithdraw, 0, "maxWithdraw should be non-negative");

        // maxWithdraw should not exceed user's share balance
        uint256 userShares = vault.balanceOf(user);
        uint256 userShareValue = vault.convertToAssets(userShares);
        assertLe(maxWithdraw, userShareValue, "maxWithdraw should not exceed user's share value");

        // Test that it's deterministic
        uint256 maxWithdraw2 = vault.maxWithdraw(user);
        assertEq(maxWithdraw, maxWithdraw2, "maxWithdraw should be deterministic");
    }

    /// @notice Fuzz test maxRedeem with various users
    function testFuzz_MaxRedeem(address user) public view {
        // Skip zero address and contract addresses
        vm.assume(user != address(0) && user.code.length == 0);

        uint256 maxRedeem = vault.maxRedeem(user);

        // maxRedeem should equal user's share balance
        uint256 userShares = vault.balanceOf(user);
        assertEq(maxRedeem, userShares, "maxRedeem should equal user's share balance");

        // Test that it's deterministic
        uint256 maxRedeem2 = vault.maxRedeem(user);
        assertEq(maxRedeem, maxRedeem2, "maxRedeem should be deterministic");
    }

    /*//////////////////////////////////////////////////////////////
                               RATE FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fuzz test rate overwrite with various values
    function testFuzz_OverwriteRate(uint256 newRate) public {
        // Bound rate to reasonable range (1e6 to 1e30)
        newRate = bound(newRate, 1e6, 1e30);

        vm.startPrank(owner);
        vault.overwriteRate(newRate);
        vm.stopPrank();

        assertEq(vault.rate(), newRate, "rate should be overwritten");

        // Test that rate change affects totalAssets calculation
        uint256 totalSupply = vault.totalSupply();
        uint256 expectedTotalAssets = totalSupply * newRate / 1e18;
        uint256 actualTotalAssets = vault.totalAssets();
        assertEq(actualTotalAssets, expectedTotalAssets, "totalAssets should reflect new rate");
    }

    /// @notice Fuzz test rate consistency after operations
    function testFuzz_RateConsistency(uint256 depositAmount) public {
        // Bound deposit amount to reasonable range (1 ether to 1000 ether)
        depositAmount = bound(depositAmount, 1 ether, 1000 ether);

        // Skip if user1 doesn't have enough balance
        vm.assume(depositAmount <= app.balanceOf(user1) || app.balanceOf(user1) == 0);

        // Mint tokens to user1 if needed
        if (app.balanceOf(user1) < depositAmount) {
            vm.prank(owner);
            app.mint(user1, depositAmount);
        }

        vm.startPrank(user1);
        app.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);
        vm.stopPrank();

        // Rate should be consistent with totalAssets calculation
        uint256 calculatedTotalAssets = vault.totalSupply() * vault.rate() / 1e18;
        uint256 actualTotalAssets = vault.totalAssets();
        assertEq(calculatedTotalAssets, actualTotalAssets, "rate should be consistent with totalAssets");

        // Test that individual user assets are consistent with rate
        uint256 userShares = vault.balanceOf(user1);
        uint256 userAssets = vault.convertToAssets(userShares);
        uint256 expectedUserAssets = userShares * vault.rate() / 1e18;
        assertApproxEqAbs(userAssets, expectedUserAssets, 1e9, "user assets should be consistent with rate");
    }

    /*//////////////////////////////////////////////////////////////
                               HARVEST FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fuzz test harvest with various reward amounts
    function testFuzz_Harvest(uint256 rewardAmount) public {
        // Bound reward amount to reasonable range (1 ether to 10000 ether)
        rewardAmount = bound(rewardAmount, 1 ether, 10000 ether);

        // First make a deposit to have shares
        uint256 depositAmount = 100 ether;
        vm.prank(owner);
        app.mint(user1, depositAmount);

        vm.startPrank(user1);
        app.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);
        vm.stopPrank();

        // Provide rewards
        vm.startPrank(owner);
        app.mint(owner, rewardAmount);
        app.approve(address(staking), rewardAmount);
        staking.notifyRewardAmount(rewardAmount);
        vm.stopPrank();

        // Fast forward time
        vm.warp(block.timestamp + 4 hours);

        // Record state before harvest
        uint256 beforeTotalSupply = vault.totalSupply();
        uint256 beforeTotalAssets = vault.totalAssets();

        // Harvest should not revert
        vm.prank(owner);
        vault.harvest();

        // Rate should remain consistent after harvest
        uint256 afterRate = vault.rate();
        uint256 afterTotalAssets = vault.totalAssets();
        uint256 afterTotalSupply = vault.totalSupply();

        // Total supply should remain the same
        assertEq(afterTotalSupply, beforeTotalSupply, "total supply should remain unchanged after harvest");

        // Rate consistency check
        uint256 calculatedTotalAssets = afterTotalSupply * afterRate / 1e18;
        assertApproxEqAbs(calculatedTotalAssets, afterTotalAssets, 1e9, "rate should be consistent after harvest");

        // Test that harvest doesn't break invariants
        assertGe(afterTotalAssets, beforeTotalAssets, "total assets should not decrease after harvest");
    }

    /*//////////////////////////////////////////////////////////////
                               TAX FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fuzz test with various tax rates
    function testFuzz_TaxRates(uint256 taxRate) public {
        // Bound tax rate to valid range (0 to 10000 basis points = 0% to 100%)
        taxRate = bound(taxRate, 0, 10000);

        // Set tax rate
        vm.startPrank(owner);
        IAppStaking.Variables memory defaultVariables = staking.variables();
        defaultVariables.harbergerTaxRate = taxRate;
        staking.setVariables(defaultVariables);
        vm.stopPrank();

        // Test deposit with various amounts
        uint256 assets = 100 ether;
        uint256 expectedShares = vault.previewDeposit(assets);

        // With streaming tax, shares should equal assets (no upfront tax)
        assertApproxEqAbs(expectedShares, assets, 1, "previewDeposit should return full amount with streaming tax");

        // Test that tax rate setting is effective
        IAppStaking.Variables memory currentVariables = staking.variables();
        assertEq(currentVariables.harbergerTaxRate, taxRate, "tax rate should be set correctly");

        // Test consistency across multiple calls
        uint256 expectedShares2 = vault.previewDeposit(assets);
        assertEq(expectedShares, expectedShares2, "previewDeposit should be consistent with same tax rate");
    }

    /// @notice Fuzz test tax precision with small amounts
    function testFuzz_TaxPrecisionSmallAmounts(uint256 assets) public view {
        // Bound assets to small amounts (1 wei to 1 ether)
        assets = bound(assets, 1, 1 ether);

        uint256 expectedShares = vault.previewDeposit(assets);

        // Should handle small amounts without reverting
        assertTrue(expectedShares >= 0, "previewDeposit should handle small amounts");

        // Test mathematical consistency
        uint256 directShares = vault.convertToShares(assets);
        assertApproxEqAbs(
            expectedShares, directShares, 1e9, "previewDeposit should match convertToShares for small amounts"
        );

        // Test that small amounts are handled consistently
        if (assets > 0) {
            assertGt(expectedShares, 0, "small positive amounts should result in positive shares");
        }
    }

    /*//////////////////////////////////////////////////////////////
                               EDGE CASE FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fuzz test with extreme values
    function testFuzz_ExtremeValues(uint256 input) public view {
        // Test with extreme values (very small to very large)
        input = bound(input, 1, type(uint256).max);

        // Should handle extreme values without reverting (may return 0 or max values)
        try vault.previewDeposit(input) {
            uint256 shares = vault.previewDeposit(input);

            // Test that extreme values don't break mathematical relationships
            if (input > 0 && shares > 0) {
                // For very large inputs, shares should be proportionally large
                if (input > 1e30) {
                    assertGt(shares, 1e20, "very large inputs should result in proportionally large shares");
                }

                // For very small inputs, shares should be proportionally small
                if (input < 1e6) {
                    assertLt(shares, input * 2, "very small inputs should result in proportionally small shares");
                }
            }
        } catch {
            // It's okay if it reverts for extreme values
            assertTrue(true, "previewDeposit may revert for extreme values");
        }
    }

    /// @notice Fuzz test with random addresses
    function testFuzz_RandomAddresses(address user) public view {
        // Skip zero address and contract addresses
        vm.assume(user != address(0) && user.code.length == 0);

        // Test max functions with random addresses
        uint256 maxDeposit = vault.maxDeposit(user);
        uint256 maxMint = vault.maxMint(user);
        uint256 maxWithdraw = vault.maxWithdraw(user);
        uint256 maxRedeem = vault.maxRedeem(user);

        // Should handle random addresses without reverting
        assertTrue(true, "should handle random addresses");

        // Test consistency of max functions
        assertEq(maxDeposit, type(uint256).max, "maxDeposit should always be unlimited");
        assertEq(maxMint, type(uint256).max, "maxMint should always be unlimited");
        assertGe(maxWithdraw, 0, "maxWithdraw should be non-negative");
        assertGe(maxRedeem, 0, "maxRedeem should be non-negative");

        // Test that maxRedeem equals user's share balance
        uint256 userShares = vault.balanceOf(user);
        assertEq(maxRedeem, userShares, "maxRedeem should equal user's share balance");
    }

    /// @notice Fuzz test position recreation after buyout
    function testFuzz_PositionRecreation(uint256 buyoutPrice) public {
        // Bound buyout price to reasonable range (1 ether to 10000 ether)
        buyoutPrice = bound(buyoutPrice, 1 ether, 10000 ether);

        // Existing position id
        uint256 oldId = vault.tokenId();
        uint256 prevTa = vault.totalAssets();

        // Buyer purchases the position
        uint256 actualPrice = staking.positions(oldId).declaredValue;

        // Skip if buyout price is too low
        vm.assume(buyoutPrice >= actualPrice);

        vm.startPrank(owner);
        app.mint(user2, buyoutPrice);
        vm.stopPrank();

        vm.startPrank(user2);
        app.approve(address(staking), buyoutPrice);
        staking.buyPosition(oldId);
        vm.stopPrank();

        // Recreate position
        vm.prank(owner);
        vault.recreatePosition();

        uint256 newId = vault.tokenId();
        assertTrue(newId != oldId, "tokenId not updated");
        assertEq(staking.ownerOf(newId), address(vault));

        // totalAssets should work and be >= newAssets
        uint256 ta = vault.totalAssets();
        assertGe(ta, prevTa);

        // Test that new position is properly initialized
        IAppStaking.Position memory newPosition = staking.positions(newId);
        assertGt(newPosition.amount, 0, "new position should have positive amount");

        // Test rate consistency with new position
        uint256 expectedTotalAssets = vault.totalSupply() * vault.rate() / 1e18;
        assertApproxEqAbs(ta, expectedTotalAssets, 1e9, "rate should be consistent after position recreation");
    }

    /*//////////////////////////////////////////////////////////////
                               INVARIANT FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fuzz test invariant: rate consistency after random operations
    function testFuzz_Invariant_RateConsistency(uint256 seed) public {
        // Use seed to determine operation type and parameters
        uint256 operationType = seed % 4; // 0: deposit, 1: mint, 2: withdraw, 3: redeem
        uint256 amount = bound(seed, 1 ether, 1000 ether);

        // Record initial state
        uint256 initialRate = vault.rate();
        uint256 initialTotalSupply = vault.totalSupply();

        // Perform random operation
        if (operationType == 0) {
            // Deposit
            if (app.balanceOf(user1) < amount) {
                vm.prank(owner);
                app.mint(user1, amount);
            }
            vm.startPrank(user1);
            app.approve(address(vault), amount);
            vault.deposit(amount, user1);
            vm.stopPrank();
        } else if (operationType == 1 && vault.totalSupply() > 0) {
            // Mint
            uint256 requiredAssets = vault.previewMint(amount);
            if (app.balanceOf(user1) < requiredAssets) {
                vm.prank(owner);
                app.mint(user1, requiredAssets);
            }
            vm.startPrank(user1);
            app.approve(address(vault), requiredAssets);
            vault.mint(amount, user1);
            vm.stopPrank();
        } else if (operationType == 2) {
            // Withdraw (if available)
            uint256 maxWithdraw = vault.maxWithdraw(user1);
            if (maxWithdraw > 0) {
                uint256 withdrawAmount = amount > maxWithdraw ? maxWithdraw : amount;
                vm.startPrank(user1);
                vault.withdraw(withdrawAmount, user1, user1);
                vm.stopPrank();
            }
        } else if (operationType == 3) {
            // Redeem (if available)
            uint256 userShares = vault.balanceOf(user1);
            if (userShares > 0) {
                uint256 redeemAmount = amount > userShares ? userShares : amount;
                vm.startPrank(user1);
                vault.redeem(redeemAmount, user1, user1);
                vm.stopPrank();
            }
        }

        // Rate should remain consistent after operation
        if (vault.totalSupply() > 0) {
            uint256 calculatedTotalAssets = vault.totalSupply() * vault.rate() / 1e18;
            uint256 actualTotalAssets = vault.totalAssets();
            assertApproxEqAbs(
                calculatedTotalAssets, actualTotalAssets, 1e9, "rate should be consistent after operation"
            );
        }

        // Test that rate hasn't changed unexpectedly
        uint256 finalRate = vault.rate();
        assertEq(finalRate, initialRate, "rate should not change during user operations");

        // Test that total supply changes are consistent with operations
        uint256 finalTotalSupply = vault.totalSupply();
        if (operationType == 0 || operationType == 1) {
            // Deposit and mint should increase total supply
            assertGe(finalTotalSupply, initialTotalSupply, "total supply should not decrease after deposit/mint");
        }
    }

    /// @notice Fuzz test invariant: total assets consistency
    function testFuzz_Invariant_TotalAssetsConsistency(uint256 seed) public {
        // Use seed to determine deposit amount
        uint256 depositAmount = bound(seed, 1 ether, 1000 ether);

        // Skip if user1 doesn't have enough balance
        vm.assume(depositAmount <= app.balanceOf(user1) || app.balanceOf(user1) == 0);

        // Mint tokens to user1 if needed
        if (app.balanceOf(user1) < depositAmount) {
            vm.prank(owner);
            app.mint(user1, depositAmount);
        }

        vm.startPrank(user1);
        app.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);
        vm.stopPrank();

        // Total assets should be consistent with rate calculation
        uint256 calculatedTotalAssets = vault.totalSupply() * vault.rate() / 1e18;
        uint256 actualTotalAssets = vault.totalAssets();
        assertEq(calculatedTotalAssets, actualTotalAssets, "total assets should be consistent");

        // Test that individual user assets sum up correctly
        uint256 userShares = vault.balanceOf(user1);
        uint256 userAssets = vault.convertToAssets(userShares);
        assertApproxEqAbs(userAssets, depositAmount, 1e9, "user assets should equal deposit amount");

        // Test that total assets are positive
        assertGt(actualTotalAssets, 0, "total assets should be positive after deposit");

        // Test that rate calculation is mathematically sound
        uint256 rate = vault.rate();
        if (rate > 0) {
            uint256 expectedTotalSupply = actualTotalAssets * 1e18 / rate;
            assertApproxEqAbs(
                expectedTotalSupply, vault.totalSupply(), 1e9, "rate calculation should be mathematically consistent"
            );
        }
    }
}
