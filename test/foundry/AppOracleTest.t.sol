// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./BaseTest.sol";
import "../../contracts/core/AppOracle.sol";
import "../../contracts/mocks/MockOracleV2.sol";
import "../../contracts/mocks/MockERC20.sol";

contract AppOracleTest is BaseTest {
    MockERC20 public usdc;
    MockOracleV2 public usdcPriceOracle;

    function setUp() public {
        setUpBaseTest();

        // Deploy tokens
        usdc = new MockERC20("USDC", "USDC");
        usdc.setDecimals(6);

        vm.startPrank(owner);

        // Deploy price oracles - 1 USDC = $1 USD, 1 USDC = 1 RZR
        usdcPriceOracle = new MockOracleV2(0, 1e18, address(usdc));

        // Set up oracles
        appOracle.setTokenPrice(1e18);
        appOracle.updateOracle(address(usdc), address(usdcPriceOracle), 3600); // 1 hour staleness
    }

    function test_UpdateOracle() public {
        // Create new oracle
        MockOracleV2 newOracle = new MockOracleV2(0, 2e18, address(usdc));

        // Update oracle as governor
        appOracle.updateOracle(address(app), address(newOracle), 3600);

        // Verify oracle was updated
        assertEq(address(appOracle.oracles(app)), address(newOracle), "Oracle should be updated");
        assertEq(appOracle.maxStaleness(app), 3600, "Max staleness should be updated");
    }

    function test_UpdateOracleReverts() public {
        vm.stopPrank();

        // Try to update oracle as non-governor
        vm.prank(user1);
        vm.expectRevert("UNAUTHORIZED");
        appOracle.updateOracle(address(app), address(usdcPriceOracle), 3600);

        // Try to update with zero address token
        vm.prank(owner);
        vm.expectRevert(IAppOracle.InvalidTokenAddress.selector);
        appOracle.updateOracle(address(0), address(usdcPriceOracle), 3600);

        // Try to update with zero address oracle
        vm.prank(owner);
        vm.expectRevert(IAppOracle.InvalidOracleAddress.selector);
        appOracle.updateOracle(address(app), address(0), 3600);
    }

    function test_GetPrice() public {
        // Get USDC price
        (uint256 rzrAmount, uint256 usdAmount, uint256 lastUpdatedAt) = appOracle.getPriceForAmount(address(usdc), 1e6);
        assertEq(usdAmount, 1e18, "USDC price should be 1 USD");
        assertEq(rzrAmount, 0, "USDC price in RZR should be 0 RZR");
        assertGt(lastUpdatedAt, 0, "Last updated timestamp should be set");

        // Update USDC price
        usdcPriceOracle.setPrice(0, 2e18);
        (rzrAmount, usdAmount, lastUpdatedAt) = appOracle.getPriceForAmount(address(usdc), 1e6);
        assertEq(usdAmount, 2e18, "USDC price should be 2 USD");
        assertEq(rzrAmount, 0, "USDC price in RZR should be 0 RZR");
    }

    function test_GetPriceReverts() public {
        // Try to get price for non-existent oracle
        MockERC20 newToken = new MockERC20("NEW", "NEW");
        newToken.setDecimals(18);
        vm.expectRevert(abi.encodeWithSelector(IAppOracle.OracleNotFound.selector, address(newToken)));
        appOracle.getPrice(address(newToken));
    }

    function test_GetPriceForAmount() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        (uint256 rzrAmount, uint256 usdAmount, uint256 lastUpdatedAt) =
            appOracle.getPriceForAmount(address(usdc), amount);
        assertEq(usdAmount, 1000 * 1e18, "1.000 USDC should be worth 1000 USD");
        assertEq(rzrAmount, 0, "1.000 USDC should be worth 0 RZR");

        // Update USDC price to $2
        usdcPriceOracle.setPrice(0, 2e18);
        (rzrAmount, usdAmount, lastUpdatedAt) = appOracle.getPriceForAmount(address(usdc), amount);
        assertEq(usdAmount, 2000 * 1e18, "1.000 USDC should be worth 2000 USD");
        assertEq(rzrAmount, 0, "1.000 USDC should be worth 0 RZR");
    }

    function test_GetPriceForAmountReverts() public {
        // Try to get price for non-existent oracle
        MockERC20 newToken = new MockERC20("NEW", "NEW");
        newToken.setDecimals(18);
        vm.expectRevert(abi.encodeWithSelector(IAppOracle.OracleNotFound.selector, address(newToken)));
        appOracle.getPriceForAmount(address(newToken), 1e18);
    }

    function test_DecimalHandling() public {
        // Create token with 8 decimals
        MockERC20 token8 = new MockERC20("TOKEN8", "TK8");
        token8.setDecimals(8);
        MockOracleV2 oracle8 = new MockOracleV2(0, 1e18, address(token8));

        // Set up oracle
        appOracle.updateOracle(address(token8), address(oracle8), 3600);

        // Test price calculations
        uint256 amount = 1000 * 1e8; // 1000 tokens
        (uint256 rzrAmount, uint256 usdAmount,) = appOracle.getPriceForAmount(address(token8), amount);
        assertEq(usdAmount, 1000 * 1e18, "Price should be correctly scaled");
        assertEq(rzrAmount, 0, "RZR price should be 0");
    }

    function test_PriceUpdates() public {
        // Initial prices
        assertEq(appOracle.getTokenPrice(), 1e18, "Initial RZR floor price should be 1 USD");

        (uint256 rzrAmount, uint256 usdAmount,) = appOracle.getPriceForAmount(address(usdc), 1e6);
        assertEq(usdAmount, 1e18, "Initial USDC price should be 1 USD");
        assertEq(rzrAmount, 0, "Initial USDC price in RZR should be 0 RZR");

        // Update prices
        appOracle.setTokenPrice(2e18); // RZR floor price = $2
        usdcPriceOracle.setPrice(0, 1.5e18); // USDC = $1.5 USD, 0 RZR

        // Verify updated prices
        assertEq(appOracle.getTokenPrice(), 2e18, "Updated RZR floor price should be 2 USD");

        (rzrAmount, usdAmount,) = appOracle.getPriceForAmount(address(usdc), 1e6);
        assertEq(usdAmount, 1.5e18, "Updated USDC price should be 1.5 USD");
        assertEq(rzrAmount, 0, "Updated USDC price in RZR should be 0 RZR");
    }

    function test_SetTokenPrice() public {
        // Initial floor price
        assertEq(appOracle.getTokenPrice(), 1e18, "Initial floor price should be 1 USD");

        // Update floor price
        appOracle.setTokenPrice(2e18);
        assertEq(appOracle.getTokenPrice(), 2e18, "Floor price should be updated to 2 USD");

        // Try to decrease floor price (should revert)
        vm.expectRevert("floor price can only increase");
        appOracle.setTokenPrice(1e18);
    }

    function test_SetTokenPriceReverts() public {
        vm.stopPrank();

        // Try to set token price as non-policy
        vm.prank(user1);
        vm.expectRevert("UNAUTHORIZED");
        appOracle.setTokenPrice(2e18);
    }

    function test_StalenessCheck() public {
        // Create oracle with very short staleness period
        MockOracleV2 shortStalenessOracle = new MockOracleV2(1e18, 1e18, address(usdc));
        appOracle.updateOracle(address(usdc), address(shortStalenessOracle), 1); // 1 second staleness

        // Should work initially
        appOracle.getPrice(address(usdc));

        // Wait for staleness period to expire
        vm.warp(block.timestamp + 2);

        // Should revert due to staleness
        vm.expectRevert("Oracle is stale");
        appOracle.getPrice(address(usdc));
    }

    function test_InvalidOraclePrice() public {
        // Create oracle that returns zero prices
        MockOracleV2 invalidOracle = new MockOracleV2(0, 0, address(usdc));

        // Should revert when trying to update with invalid oracle
        vm.expectRevert("Invalid price");
        appOracle.updateOracle(address(usdc), address(invalidOracle), 3600);
    }
}
