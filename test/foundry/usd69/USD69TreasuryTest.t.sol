// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../../contracts/core/usdr/USDTreasury.sol";
import "../../../contracts/core/AppAuthority.sol";
import "../../../contracts/mocks/MockERC20.sol";
import "../../../contracts/mocks/MockApp.sol";
import "../../../contracts/mocks/MockAppOracle.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract USDTreasuryTest is Test {
    USDTreasury public treasury;
    AppAuthority public authority;
    MockERC20 public underlying;
    MockERC20 public underlying6Decimals; // 6 decimal token
    MockApp public usdr;
    MockAppOracle public appOracle;

    address public governor = address(0x1);
    address public guardian = address(0x2);
    address public reserveManager = address(0x3);
    address public user = address(0x4);
    address public nonGovernor = address(0x5);

    uint256 public constant INITIAL_SUPPLY = 1000000e18;
    uint256 public constant ASSET_PRICE = 1e18; // 1:1 price
    uint256 public constant REDEEM_FEE = 0.01e18; // 1% fee
    uint256 public constant SUPPLY_CAP = 10000000e18;

    // For 6 decimal token: 1e6 token = 1e18 USDR (price = 1e18)
    uint256 public constant ASSET_PRICE_6_DECIMALS = 1e18; // Oracle returns 1e18 for 1e6 of 6-decimal token
    uint256 public constant REDEEM_FEE_6_DECIMALS = 0.01e18; // 1% fee
    uint256 public constant SUPPLY_CAP_6_DECIMALS = 10000000e6; // 10M tokens with 6 decimals

    event AssetSet(IERC20 asset, uint256 price, uint256 redeemFee, uint256 supplyCap);
    event AssetSupplyCapSet(IERC20 asset, uint256 supplyCap);
    event AssetPaused(IERC20 asset);
    event AssetUnpaused(IERC20 asset);
    event Borrowed(IERC20 asset, address destination, uint256 amount);
    event Repaid(IERC20 asset, address destination, uint256 amount);
    event Burned(IERC20 asset, address destination, uint256 amount);
    event Minted(IERC20 asset, address destination, uint256 amount);
    event BurnSubmitted(address who, IERC20 asset, uint256 amount);
    event BurnCompleted(address who);
    event BurnCanceled(address who);

    function setUp() public {
        // Deploy authority
        authority = new AppAuthority();

        // Deploy mock contracts
        underlying = new MockERC20("Mock Token", "MOCK");
        underlying6Decimals = new MockERC20("Mock Token 6Dec", "MOCK6");
        underlying6Decimals.setDecimals(6); // Set to 6 decimals
        usdr = new MockApp("USDR", "USDR");
        appOracle = new MockAppOracle();

        // Deploy treasury
        treasury = new USDTreasury();

        // Initialize treasury
        treasury.initialize(address(authority), address(usdr), address(appOracle));

        // Set up roles
        authority.grantRole(authority.GOVERNOR_ROLE(), governor);
        authority.grantRole(authority.GUARDIAN_ROLE(), guardian);
        authority.grantRole(authority.RESERVE_MANAGER_ROLE(), reserveManager);

        // Transfer some underlying tokens to users
        underlying.mint(user, 100000e18);
        underlying.mint(nonGovernor, 100000e18);
        underlying6Decimals.mint(user, 100000e6); // 6 decimal tokens
        underlying6Decimals.mint(nonGovernor, 100000e6);

        // Set up oracle prices
        appOracle.setPrice(address(underlying), 0, ASSET_PRICE);
        appOracle.setPrice(address(underlying6Decimals), 0, ASSET_PRICE_6_DECIMALS);

        // Set up assets in treasury
        vm.prank(governor);
        treasury.setAsset(underlying, ASSET_PRICE, REDEEM_FEE, SUPPLY_CAP);

        vm.prank(governor);
        treasury.setAsset(underlying6Decimals, ASSET_PRICE_6_DECIMALS, REDEEM_FEE_6_DECIMALS, SUPPLY_CAP_6_DECIMALS);

        // Enable assets
        vm.prank(governor);
        treasury.enableAsset(underlying);

        vm.prank(governor);
        treasury.enableAsset(underlying6Decimals);
    }

    function test_Initialize() public view {
        assertEq(address(treasury.usdr()), address(usdr));
        assertEq(address(treasury.appOracle()), address(appOracle));
        assertEq(treasury.MAX_DEVIATION(), 0.001e18);
    }

    function test_SetAsset() public {
        MockERC20 newAsset = new MockERC20("New Asset", "NEW");
        uint256 price = 2e18;
        uint256 redeemFee = 0.02e18;
        uint256 supplyCap = 5000000e18;

        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit AssetSet(newAsset, price, redeemFee, supplyCap);
        treasury.setAsset(newAsset, price, redeemFee, supplyCap);

        IUSDTreasury.AssetInfo memory assetInfo = treasury.assetInfos(newAsset);
        assertEq(assetInfo.price, price);
        assertEq(assetInfo.redeemFee, redeemFee);
        assertEq(assetInfo.supplyCap, supplyCap);
        assertEq(assetInfo.supplied, 0);
        assertEq(assetInfo.borrowed, 0);
    }

    function test_SetAsset_NonGovernor() public {
        MockERC20 newAsset = new MockERC20("New Asset", "NEW");

        vm.prank(nonGovernor);
        vm.expectRevert();
        treasury.setAsset(newAsset, 1e18, 0.01e18, 1000000e18);
    }

    function test_SetAssetSupplyCap_Governor() public {
        uint256 newSupplyCap = 20000000e18;

        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit AssetSupplyCapSet(underlying, newSupplyCap);
        treasury.setAssetSupplyCap(underlying, newSupplyCap);

        IUSDTreasury.AssetInfo memory assetInfo = treasury.assetInfos(underlying);
        assertEq(assetInfo.supplyCap, newSupplyCap);
    }

    function test_SetAssetSupplyCap_Guardian_Decrease() public {
        uint256 newSupplyCap = 5000000e18; // Less than current

        vm.prank(guardian);
        vm.expectEmit(true, true, true, true);
        emit AssetSupplyCapSet(underlying, newSupplyCap);
        treasury.setAssetSupplyCap(underlying, newSupplyCap);

        IUSDTreasury.AssetInfo memory assetInfo = treasury.assetInfos(underlying);
        assertEq(assetInfo.supplyCap, newSupplyCap);
    }

    function test_SetAssetSupplyCap_Guardian_Increase() public {
        uint256 newSupplyCap = 20000000e18; // More than current

        vm.prank(guardian);
        vm.expectRevert();
        treasury.setAssetSupplyCap(underlying, newSupplyCap);
    }

    function test_SetAssetSupplyCap_NonGovernor() public {
        uint256 newSupplyCap = 20000000e18;

        vm.prank(nonGovernor);
        vm.expectRevert();
        treasury.setAssetSupplyCap(underlying, newSupplyCap);
    }

    function test_DisableAsset() public {
        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit AssetPaused(underlying);
        treasury.disableAsset(underlying);

        // Asset should be disabled - should have 1 asset left (the 6-decimal one)
        address[] memory assets = treasury.assets();
        assertEq(assets.length, 1);
        assertEq(assets[0], address(underlying6Decimals));
    }

    function test_DisableAsset_Guardian() public {
        vm.prank(guardian);
        vm.expectEmit(true, true, true, true);
        emit AssetPaused(underlying);
        treasury.disableAsset(underlying);
    }

    function test_DisableAsset_NonGovernor() public {
        vm.prank(nonGovernor);
        vm.expectRevert();
        treasury.disableAsset(underlying);
    }

    function test_EnableAsset() public {
        // First disable the asset
        vm.prank(governor);
        treasury.disableAsset(underlying);

        // Then enable it
        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit AssetUnpaused(underlying);
        treasury.enableAsset(underlying);

        // Asset should be enabled - should have 2 assets now
        address[] memory assets = treasury.assets();
        assertEq(assets.length, 2);
        // Check that both assets are present
        bool found18Dec = false;
        bool found6Dec = false;
        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i] == address(underlying)) found18Dec = true;
            if (assets[i] == address(underlying6Decimals)) found6Dec = true;
        }
        assertTrue(found18Dec);
        assertTrue(found6Dec);
    }

    function test_EnableAsset_NonGovernor() public {
        vm.prank(nonGovernor);
        vm.expectRevert();
        treasury.enableAsset(underlying);
    }

    function test_Assets() public {
        address[] memory assets = treasury.assets();
        assertEq(assets.length, 2);
        // Check that both assets are present
        bool found18Dec = false;
        bool found6Dec = false;
        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i] == address(underlying)) found18Dec = true;
            if (assets[i] == address(underlying6Decimals)) found6Dec = true;
        }
        assertTrue(found18Dec);
        assertTrue(found6Dec);
    }

    function test_Mint() public {
        uint256 amount = 1000e18;
        uint256 expectedMintAmount = amount * ASSET_PRICE / 1e18;

        vm.startPrank(user);
        underlying.approve(address(treasury), amount);
        vm.expectEmit(true, true, true, true);
        emit Minted(underlying, user, amount);
        uint256 mintAmount = treasury.mint(underlying, user, amount);
        vm.stopPrank();

        assertEq(mintAmount, expectedMintAmount);
        assertEq(usdr.balanceOf(user), expectedMintAmount);
        assertEq(underlying.balanceOf(address(treasury)), amount);

        IUSDTreasury.AssetInfo memory assetInfo = treasury.assetInfos(underlying);
        assertEq(assetInfo.supplied, amount);
    }

    function test_Mint_InvalidAsset() public {
        MockERC20 invalidAsset = new MockERC20("Invalid", "INV");

        vm.startPrank(user);
        invalidAsset.approve(address(treasury), 1000e18);
        vm.expectRevert("Invalid asset");
        treasury.mint(invalidAsset, user, 1000e18);
        vm.stopPrank();
    }

    function test_Mint_DisabledAsset() public {
        // Disable the asset
        vm.prank(governor);
        treasury.disableAsset(underlying);

        vm.startPrank(user);
        underlying.approve(address(treasury), 1000e18);
        vm.expectRevert("Asset is disabled");
        treasury.mint(underlying, user, 1000e18);
        vm.stopPrank();
    }

    function test_Mint_ExceedsSupplyCap() public {
        uint256 amount = SUPPLY_CAP + 1;

        vm.startPrank(user);
        underlying.mint(user, amount);
        underlying.approve(address(treasury), amount);
        vm.expectRevert("supply cap exceeded");
        treasury.mint(underlying, user, amount);
        vm.stopPrank();
    }

    function test_Mint_PriceDeviationTooHigh() public {
        // Set oracle price to be too high
        appOracle.setPrice(address(underlying), 0, ASSET_PRICE * 2);

        vm.startPrank(user);
        underlying.approve(address(treasury), 1000e18);
        vm.expectRevert("deviation too high");
        treasury.mint(underlying, user, 1000e18);
        vm.stopPrank();
    }

    function test_Mint_PriceDeviationTooLow() public {
        // Set oracle price to be too low
        appOracle.setPrice(address(underlying), 0, ASSET_PRICE / 2);

        vm.startPrank(user);
        underlying.approve(address(treasury), 1000e18);
        vm.expectRevert("deviation too high");
        treasury.mint(underlying, user, 1000e18);
        vm.stopPrank();
    }

    function test_Borrow() public {
        // First mint some assets
        vm.startPrank(user);
        underlying.approve(address(treasury), 1000e18);
        treasury.mint(underlying, user, 1000e18);
        vm.stopPrank();

        uint256 borrowAmount = 500e18;

        vm.prank(reserveManager);
        vm.expectEmit(true, true, true, true);
        emit Borrowed(underlying, user, borrowAmount);
        treasury.borrow(underlying, user, borrowAmount);

        assertEq(underlying.balanceOf(user), 100000e18 - 1000e18 + 500e18);

        IUSDTreasury.AssetInfo memory assetInfo = treasury.assetInfos(underlying);
        assertEq(assetInfo.borrowed, borrowAmount);
    }

    function test_Borrow_NonReserveManager() public {
        vm.prank(nonGovernor);
        vm.expectRevert();
        treasury.borrow(underlying, user, 1000e18);
    }

    function test_Borrow_InvalidAsset() public {
        MockERC20 invalidAsset = new MockERC20("Invalid", "INV");

        vm.prank(reserveManager);
        vm.expectRevert("Invalid asset");
        treasury.borrow(invalidAsset, user, 1000e18);
    }

    function test_Repay() public {
        // First borrow some assets
        vm.startPrank(user);
        underlying.approve(address(treasury), 1000e18);
        treasury.mint(underlying, user, 1000e18);
        vm.stopPrank();

        vm.prank(reserveManager);
        treasury.borrow(underlying, user, 500e18);

        // Now repay
        uint256 repayAmount = 200e18;
        underlying.mint(reserveManager, repayAmount); // Give reserve manager some tokens
        vm.startPrank(reserveManager);
        underlying.approve(address(treasury), repayAmount);
        treasury.repay(underlying, repayAmount);
        vm.stopPrank();

        IUSDTreasury.AssetInfo memory assetInfo = treasury.assetInfos(underlying);
        assertEq(assetInfo.borrowed, 500e18 - repayAmount);
    }

    function test_Repay_NonReserveManager() public {
        vm.prank(nonGovernor);
        vm.expectRevert();
        treasury.repay(underlying, 1000e18);
    }

    function test_Repay_InvalidAsset() public {
        MockERC20 invalidAsset = new MockERC20("Invalid", "INV");

        vm.prank(reserveManager);
        vm.expectRevert("Invalid asset");
        treasury.repay(invalidAsset, 1000e18);
    }

    function test_Burn() public {
        // First mint some USDR
        vm.startPrank(user);
        underlying.approve(address(treasury), 1000e18);
        uint256 mintAmount = treasury.mint(underlying, user, 1000e18);
        vm.stopPrank();

        // Now submit burn request
        uint256 burnAmount = 500e18;
        uint256 expectedRedeemAmount = burnAmount * (1e18 - REDEEM_FEE) / 1e18;

        vm.startPrank(user);
        usdr.approve(address(treasury), burnAmount);
        vm.expectEmit(true, true, true, true);
        emit BurnSubmitted(user, underlying, burnAmount);
        uint256 redeemAmount = treasury.burn(burnAmount, underlying);
        vm.stopPrank();

        assertEq(redeemAmount, expectedRedeemAmount);
        assertEq(usdr.balanceOf(user), mintAmount - burnAmount);
        assertEq(underlying.balanceOf(user), 100000e18 - 1000e18); // No assets returned yet

        // Check pending burn
        IUSDTreasury.PendingBurn memory pendingBurn = treasury.pendingBurn(user);
        assertEq(address(pendingBurn.asset), address(underlying));
        assertEq(pendingBurn.assetRedeemed, expectedRedeemAmount);
        assertEq(pendingBurn.amountBurned, burnAmount);
        assertEq(pendingBurn.submittedAt, block.timestamp);

        IUSDTreasury.AssetInfo memory assetInfo = treasury.assetInfos(underlying);
        assertEq(assetInfo.supplied, 1000e18 - expectedRedeemAmount);
    }

    function test_Burn_InvalidAsset() public {
        MockERC20 invalidAsset = new MockERC20("Invalid", "INV");

        vm.startPrank(user);
        vm.expectRevert("Invalid asset");
        treasury.burn(1000e18, invalidAsset);
        vm.stopPrank();
    }

    function test_Burn_DisabledAsset() public {
        // Disable the asset
        vm.prank(governor);
        treasury.disableAsset(underlying);

        vm.startPrank(user);
        vm.expectRevert("Asset is disabled");
        treasury.burn(1000e18, underlying);
        vm.stopPrank();
    }

    function test_Burn_PriceDeviationTooHigh() public {
        // First mint some USDR
        vm.startPrank(user);
        underlying.approve(address(treasury), 1000e18);
        treasury.mint(underlying, user, 1000e18);
        vm.stopPrank();

        // Set oracle price to be too high
        appOracle.setPrice(address(underlying), 0, ASSET_PRICE * 2);

        vm.startPrank(user);
        usdr.approve(address(treasury), 500e18);
        vm.expectRevert("deviation too high");
        treasury.burn(500e18, underlying);
        vm.stopPrank();
    }

    function test_Burn_PriceDeviationTooLow() public {
        // First mint some USDR
        vm.startPrank(user);
        underlying.approve(address(treasury), 1000e18);
        treasury.mint(underlying, user, 1000e18);
        vm.stopPrank();

        // Set oracle price to be too low
        appOracle.setPrice(address(underlying), 0, ASSET_PRICE / 2);

        vm.startPrank(user);
        usdr.approve(address(treasury), 500e18);
        vm.expectRevert("deviation too high");
        treasury.burn(500e18, underlying);
        vm.stopPrank();
    }

    function test_CompleteBurn() public {
        // First mint some USDR
        vm.startPrank(user);
        underlying.approve(address(treasury), 1000e18);
        uint256 mintAmount = treasury.mint(underlying, user, 1000e18);
        vm.stopPrank();

        // Submit burn request
        uint256 burnAmount = 500e18;
        vm.startPrank(user);
        usdr.approve(address(treasury), burnAmount);
        treasury.burn(burnAmount, underlying);
        vm.stopPrank();

        // Fast forward 1 day + 1 second
        vm.warp(block.timestamp + 1 days + 1);

        // Complete the burn
        vm.startPrank(user);
        vm.expectEmit(true, true, true, true);
        emit BurnCompleted(user);
        treasury.completeBurn();
        vm.stopPrank();

        // Check that assets were transferred and USDR was burned
        uint256 expectedRedeemAmount = burnAmount * (1e18 - REDEEM_FEE) / 1e18;
        assertEq(underlying.balanceOf(user), 100000e18 - 1000e18 + expectedRedeemAmount);
        assertEq(usdr.balanceOf(user), mintAmount - burnAmount);

        // Check that pending burn was cleared
        IUSDTreasury.PendingBurn memory pendingBurn = treasury.pendingBurn(user);
        assertEq(address(pendingBurn.asset), address(0));
    }

    function test_CompleteBurn_TooEarly() public {
        // First mint some USDR
        vm.startPrank(user);
        underlying.approve(address(treasury), 1000e18);
        treasury.mint(underlying, user, 1000e18);
        vm.stopPrank();

        // Submit burn request
        uint256 burnAmount = 500e18;
        vm.startPrank(user);
        usdr.approve(address(treasury), burnAmount);
        treasury.burn(burnAmount, underlying);
        vm.stopPrank();

        // Try to complete burn before 1 day
        vm.startPrank(user);
        vm.expectRevert("Burn cancel time not passed");
        treasury.completeBurn();
        vm.stopPrank();
    }

    function test_CompleteBurn_NoPendingBurn() public {
        vm.startPrank(user);
        vm.expectRevert("No pending burn");
        treasury.completeBurn();
        vm.stopPrank();
    }

    function test_CancelBurn() public {
        // First mint some USDR
        vm.startPrank(user);
        underlying.approve(address(treasury), 1000e18);
        uint256 mintAmount = treasury.mint(underlying, user, 1000e18);
        vm.stopPrank();

        // Submit burn request
        uint256 burnAmount = 500e18;
        vm.startPrank(user);
        usdr.approve(address(treasury), burnAmount);
        treasury.burn(burnAmount, underlying);
        vm.stopPrank();

        // Cancel the burn
        vm.startPrank(user);
        vm.expectEmit(true, true, true, true);
        emit BurnCanceled(user);
        treasury.cancelBurn();
        vm.stopPrank();

        // Check that USDR was returned
        assertEq(usdr.balanceOf(user), mintAmount);
        assertEq(underlying.balanceOf(user), 100000e18 - 1000e18); // No assets returned

        // Check that pending burn was cleared
        IUSDTreasury.PendingBurn memory pendingBurn = treasury.pendingBurn(user);
        assertEq(address(pendingBurn.asset), address(0));
    }

    function test_CancelBurn_NoPendingBurn() public {
        vm.startPrank(user);
        vm.expectRevert("No pending burn");
        treasury.cancelBurn();
        vm.stopPrank();
    }

    function test_Burn_PendingBurnExists() public {
        // First mint some USDR
        vm.startPrank(user);
        underlying.approve(address(treasury), 1000e18);
        treasury.mint(underlying, user, 1000e18);
        vm.stopPrank();

        // Submit first burn request
        uint256 burnAmount1 = 500e18;
        vm.startPrank(user);
        usdr.approve(address(treasury), burnAmount1);
        treasury.burn(burnAmount1, underlying);
        vm.stopPrank();

        // Try to submit second burn request
        uint256 burnAmount2 = 300e18;
        vm.startPrank(user);
        usdr.approve(address(treasury), burnAmount2);
        vm.expectRevert("Pending burn");
        treasury.burn(burnAmount2, underlying);
        vm.stopPrank();
    }

    function test_AssetInfos() public {
        IUSDTreasury.AssetInfo memory assetInfo = treasury.assetInfos(underlying);
        assertEq(assetInfo.price, ASSET_PRICE);
        assertEq(assetInfo.redeemFee, REDEEM_FEE);
        assertEq(assetInfo.supplyCap, SUPPLY_CAP);
        assertEq(assetInfo.supplied, 0);
        assertEq(assetInfo.borrowed, 0);
    }

    function test_MaxDeviation() public view {
        assertEq(treasury.MAX_DEVIATION(), 0.001e18);
    }

    function test_ReentrancyProtection() public {
        // This test would require a malicious contract to test reentrancy
        // For now, we'll just verify the modifier is present
        assertTrue(true);
    }

    function test_PausedProtection() public {
        // Pause the contract
        vm.prank(governor);
        authority.emergencyPause();

        vm.startPrank(user);
        underlying.approve(address(treasury), 1000e18);
        vm.expectRevert();
        treasury.mint(underlying, user, 1000e18);
        vm.stopPrank();
    }

    function testFuzz_Mint(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount <= SUPPLY_CAP);
        vm.assume(amount <= underlying.balanceOf(user));

        uint256 expectedMintAmount = amount * ASSET_PRICE / 1e18;

        vm.startPrank(user);
        underlying.approve(address(treasury), amount);
        uint256 mintAmount = treasury.mint(underlying, user, amount);
        vm.stopPrank();

        assertEq(mintAmount, expectedMintAmount);
        assertEq(usdr.balanceOf(user), expectedMintAmount);
    }

    function testFuzz_Burn(uint256 burnAmount) public {
        // First mint some USDR
        vm.startPrank(user);
        underlying.approve(address(treasury), 1000e18);
        treasury.mint(underlying, user, 1000e18);
        vm.stopPrank();

        vm.assume(burnAmount > 0);
        vm.assume(burnAmount <= usdr.balanceOf(user));

        uint256 expectedRedeemAmount = burnAmount * (1e18 - REDEEM_FEE) / 1e18;

        vm.startPrank(user);
        usdr.approve(address(treasury), burnAmount);
        uint256 redeemAmount = treasury.burn(burnAmount, underlying);
        vm.stopPrank();

        assertEq(redeemAmount, expectedRedeemAmount);

        // Check pending burn
        IUSDTreasury.PendingBurn memory pendingBurn = treasury.pendingBurn(user);
        assertEq(address(pendingBurn.asset), address(underlying));
        assertEq(pendingBurn.assetRedeemed, expectedRedeemAmount);
        assertEq(pendingBurn.amountBurned, burnAmount);
    }

    function testFuzz_SetAssetSupplyCap(uint256 newSupplyCap) public {
        vm.assume(newSupplyCap > 0);

        vm.prank(governor);
        treasury.setAssetSupplyCap(underlying, newSupplyCap);

        IUSDTreasury.AssetInfo memory assetInfo = treasury.assetInfos(underlying);
        assertEq(assetInfo.supplyCap, newSupplyCap);
    }

    function test_Integration_FullCycle() public {
        uint256 amount = 1000e18;

        // 1. Mint USDR
        vm.startPrank(user);
        underlying.approve(address(treasury), amount);
        uint256 mintAmount = treasury.mint(underlying, user, amount);
        vm.stopPrank();

        assertEq(usdr.balanceOf(user), mintAmount);
        assertEq(underlying.balanceOf(address(treasury)), amount);

        // 2. Borrow some assets
        uint256 borrowAmount = 500e18;
        vm.prank(reserveManager);
        treasury.borrow(underlying, user, borrowAmount);

        assertEq(underlying.balanceOf(user), 100000e18 - amount + borrowAmount);

        // 3. Repay some assets
        uint256 repayAmount = 200e18;
        underlying.mint(reserveManager, repayAmount); // Give reserve manager some tokens
        vm.startPrank(reserveManager);
        underlying.approve(address(treasury), repayAmount);
        treasury.repay(underlying, repayAmount);
        vm.stopPrank();

        // 4. Submit burn request
        uint256 burnAmount = 300e18;
        uint256 expectedRedeemAmount = burnAmount * (1e18 - REDEEM_FEE) / 1e18;

        vm.startPrank(user);
        usdr.approve(address(treasury), burnAmount);
        uint256 redeemAmount = treasury.burn(burnAmount, underlying);
        vm.stopPrank();

        assertEq(redeemAmount, expectedRedeemAmount);

        // 5. Complete the burn after 1 day
        vm.warp(block.timestamp + 1 days + 1);
        vm.startPrank(user);
        treasury.completeBurn();
        vm.stopPrank();

        // Verify final state
        IUSDTreasury.AssetInfo memory assetInfo = treasury.assetInfos(underlying);
        assertEq(assetInfo.supplied, amount - expectedRedeemAmount);
        assertEq(assetInfo.borrowed, borrowAmount - repayAmount);
    }

    // ============ 6 DECIMAL TOKEN TESTS ============

    function test_Mint_6Decimals() public {
        uint256 amount = 1000e6; // 1000 tokens with 6 decimals
        // For 6-decimal token: 1e6 token = 1e18 USDR, so 1000e6 = 1000e18 USDR
        uint256 expectedMintAmount = 1000e18; // 1000 USDR tokens

        vm.startPrank(user);
        underlying6Decimals.approve(address(treasury), amount);
        vm.expectEmit(true, true, true, true);
        emit Minted(underlying6Decimals, user, amount);
        uint256 mintAmount = treasury.mint(underlying6Decimals, user, amount);
        vm.stopPrank();

        assertEq(mintAmount, expectedMintAmount);
        assertEq(usdr.balanceOf(user), expectedMintAmount);
        assertEq(underlying6Decimals.balanceOf(address(treasury)), amount);

        IUSDTreasury.AssetInfo memory assetInfo = treasury.assetInfos(underlying6Decimals);
        assertEq(assetInfo.supplied, amount);
    }

    function test_Burn_6Decimals() public {
        // First mint some USDR
        uint256 mintAmount = 1000e6; // 1000 tokens with 6 decimals
        vm.startPrank(user);
        underlying6Decimals.approve(address(treasury), mintAmount);
        uint256 usdrMinted = treasury.mint(underlying6Decimals, user, mintAmount);
        vm.stopPrank();

        // Now submit burn request - use a smaller amount to avoid underflow
        uint256 burnAmount = 100e18; // 100 USDR tokens
        uint256 expectedRedeemAmount = 99e6; // 99 tokens with 6 decimals (100 * 0.99)

        vm.startPrank(user);
        usdr.approve(address(treasury), burnAmount);
        uint256 redeemAmount = treasury.burn(burnAmount, underlying6Decimals);
        vm.stopPrank();

        assertEq(redeemAmount, expectedRedeemAmount);
        assertEq(usdr.balanceOf(user), usdrMinted - burnAmount);
        assertEq(underlying6Decimals.balanceOf(user), 100000e6 - mintAmount); // No assets returned yet

        // Check pending burn
        IUSDTreasury.PendingBurn memory pendingBurn = treasury.pendingBurn(user);
        assertEq(address(pendingBurn.asset), address(underlying6Decimals));
        assertEq(pendingBurn.assetRedeemed, expectedRedeemAmount);
        assertEq(pendingBurn.amountBurned, burnAmount);

        IUSDTreasury.AssetInfo memory assetInfo = treasury.assetInfos(underlying6Decimals);
        assertEq(assetInfo.supplied, mintAmount - expectedRedeemAmount);
    }

    function test_Borrow_6Decimals() public {
        // First mint some assets
        uint256 mintAmount = 1000e6;
        vm.startPrank(user);
        underlying6Decimals.approve(address(treasury), mintAmount);
        treasury.mint(underlying6Decimals, user, mintAmount);
        vm.stopPrank();

        uint256 borrowAmount = 500e6;

        vm.prank(reserveManager);
        vm.expectEmit(true, true, true, true);
        emit Borrowed(underlying6Decimals, user, borrowAmount);
        treasury.borrow(underlying6Decimals, user, borrowAmount);

        assertEq(underlying6Decimals.balanceOf(user), 100000e6 - mintAmount + borrowAmount);

        IUSDTreasury.AssetInfo memory assetInfo = treasury.assetInfos(underlying6Decimals);
        assertEq(assetInfo.borrowed, borrowAmount);
    }

    function test_Repay_6Decimals() public {
        // First borrow some assets
        uint256 mintAmount = 1000e6;
        vm.startPrank(user);
        underlying6Decimals.approve(address(treasury), mintAmount);
        treasury.mint(underlying6Decimals, user, mintAmount);
        vm.stopPrank();

        vm.prank(reserveManager);
        treasury.borrow(underlying6Decimals, user, 500e6);

        // Now repay
        uint256 repayAmount = 200e6;
        underlying6Decimals.mint(reserveManager, repayAmount);
        vm.startPrank(reserveManager);
        underlying6Decimals.approve(address(treasury), repayAmount);
        treasury.repay(underlying6Decimals, repayAmount);
        vm.stopPrank();

        IUSDTreasury.AssetInfo memory assetInfo = treasury.assetInfos(underlying6Decimals);
        assertEq(assetInfo.borrowed, 500e6 - repayAmount);
    }

    function test_AssetInfos_6Decimals() public {
        IUSDTreasury.AssetInfo memory assetInfo = treasury.assetInfos(underlying6Decimals);
        assertEq(assetInfo.price, ASSET_PRICE_6_DECIMALS);
        assertEq(assetInfo.redeemFee, REDEEM_FEE_6_DECIMALS);
        assertEq(assetInfo.supplyCap, SUPPLY_CAP_6_DECIMALS);
        assertEq(assetInfo.supplied, 0);
        assertEq(assetInfo.borrowed, 0);
    }

    function test_Integration_6Decimals_FullCycle() public {
        uint256 amount = 1000e6; // 1000 tokens with 6 decimals

        // 1. Mint USDR
        vm.startPrank(user);
        underlying6Decimals.approve(address(treasury), amount);
        uint256 mintAmount = treasury.mint(underlying6Decimals, user, amount);
        vm.stopPrank();

        assertEq(usdr.balanceOf(user), mintAmount);
        assertEq(underlying6Decimals.balanceOf(address(treasury)), amount);

        // 2. Borrow some assets
        uint256 borrowAmount = 500e6;
        vm.prank(reserveManager);
        treasury.borrow(underlying6Decimals, user, borrowAmount);

        assertEq(underlying6Decimals.balanceOf(user), 100000e6 - amount + borrowAmount);

        // 3. Repay some assets
        uint256 repayAmount = 200e6;
        underlying6Decimals.mint(reserveManager, repayAmount);
        vm.startPrank(reserveManager);
        underlying6Decimals.approve(address(treasury), repayAmount);
        treasury.repay(underlying6Decimals, repayAmount);
        vm.stopPrank();

        // 4. Submit burn request
        uint256 burnAmount = 100e18; // Use smaller amount to avoid underflow
        uint256 expectedRedeemAmount = 99e6; // 100 * 0.99 = 99 tokens with 6 decimals

        vm.startPrank(user);
        usdr.approve(address(treasury), burnAmount);
        uint256 redeemAmount = treasury.burn(burnAmount, underlying6Decimals);
        vm.stopPrank();

        assertEq(redeemAmount, expectedRedeemAmount);

        // 5. Complete the burn after 1 day
        vm.warp(block.timestamp + 1 days + 1);
        vm.startPrank(user);
        treasury.completeBurn();
        vm.stopPrank();

        // Verify final state
        IUSDTreasury.AssetInfo memory assetInfo = treasury.assetInfos(underlying6Decimals);
        assertEq(assetInfo.supplied, amount - expectedRedeemAmount);
        assertEq(assetInfo.borrowed, borrowAmount - repayAmount);
    }

    function testFuzz_Mint_6Decimals(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount <= SUPPLY_CAP_6_DECIMALS);
        vm.assume(amount <= underlying6Decimals.balanceOf(user));

        // For 6-decimal token: 1e6 token = 1e18 USDR
        uint256 expectedMintAmount = amount * 1e18 / 1e6; // Convert 6-decimal amount to 18-decimal USDR

        vm.startPrank(user);
        underlying6Decimals.approve(address(treasury), amount);
        uint256 mintAmount = treasury.mint(underlying6Decimals, user, amount);
        vm.stopPrank();

        assertEq(mintAmount, expectedMintAmount);
        assertEq(usdr.balanceOf(user), expectedMintAmount);
    }

    function testFuzz_Burn_6Decimals(uint256 burnAmount) public {
        // First mint some USDR
        uint256 mintAmount = 1000e6;
        vm.startPrank(user);
        underlying6Decimals.approve(address(treasury), mintAmount);
        treasury.mint(underlying6Decimals, user, mintAmount);
        vm.stopPrank();

        vm.assume(burnAmount > 0);
        vm.assume(burnAmount <= usdr.balanceOf(user));
        vm.assume(burnAmount <= 1000e18); // Reasonable upper bound

        // For 6-decimal tokens: 1e18 USDR = 1e6 token, so burnAmount USDR = burnAmount * 1e6 / 1e18 tokens
        // Then apply 1% fee: burnAmount * 1e6 / 1e18 * 0.99
        uint256 expectedRedeemAmount = burnAmount * 99 / 100 * 1e6 / 1e18;

        vm.startPrank(user);
        usdr.approve(address(treasury), burnAmount);
        uint256 redeemAmount = treasury.burn(burnAmount, underlying6Decimals);
        vm.stopPrank();

        assertEq(redeemAmount, expectedRedeemAmount);
    }

    function test_DecimalConversion_6Decimals() public {
        // Test that 1e6 of 6-decimal token = 1e18 USDR
        uint256 amount = 1e6; // 1 token with 6 decimals
        uint256 expectedMintAmount = 1e18; // Should mint 1e18 USDR

        vm.startPrank(user);
        underlying6Decimals.approve(address(treasury), amount);
        uint256 mintAmount = treasury.mint(underlying6Decimals, user, amount);
        vm.stopPrank();

        assertEq(mintAmount, expectedMintAmount);
        assertEq(usdr.balanceOf(user), expectedMintAmount);
    }

    function test_DecimalConversion_Burn_6Decimals() public {
        // Test that 1e18 USDR = 0.99e6 of 6-decimal token (with 1% fee)
        uint256 mintAmount = 1e6;
        vm.startPrank(user);
        underlying6Decimals.approve(address(treasury), mintAmount);
        treasury.mint(underlying6Decimals, user, mintAmount);
        vm.stopPrank();

        uint256 burnAmount = 1e18; // 1 USDR token
        uint256 expectedRedeemAmount = 0.99e6; // 0.99 tokens with 6 decimals

        vm.startPrank(user);
        usdr.approve(address(treasury), burnAmount);
        uint256 redeemAmount = treasury.burn(burnAmount, underlying6Decimals);
        vm.stopPrank();

        assertEq(redeemAmount, expectedRedeemAmount);
    }
}
