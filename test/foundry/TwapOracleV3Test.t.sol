// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./BaseTest.sol";
import "../../contracts/oracles/pricefeeds/v2/TwapOracleV3.sol";
import "../../contracts/mocks/MockOracleV2.sol";
import "../../contracts/mocks/MockERC20.sol";

contract TwapOracleV3Test is BaseTest {
    TwapOracleV3 public twapOracle;
    MockOracleV2 public twapOracleMock;
    MockERC20 public mockAsset;

    uint256 public constant MAX_OBSERVATIONS = 5;
    uint256 public constant EPOCH_DURATION = 23 hours;
    uint256 public constant MAX_STALENESS = 25 hours;

    function setUp() public {
        setUpBaseTest();

        // Deploy mock asset and oracle
        mockAsset = new MockERC20("Mock Asset", "MOCK");
        twapOracleMock = new MockOracleV2(1e18, 2e18, address(mockAsset)); // 1 RZR = $2 USD

        // Touch timestamp to ensure it's not stale (after BaseTest warped forward 10 days)
        twapOracleMock.touchTimestamp();

        vm.startPrank(owner);

        // Deploy TwapOracleV3
        twapOracle = new TwapOracleV3(twapOracleMock, MAX_OBSERVATIONS, address(authority));

        vm.stopPrank();
    }

    function test_Constructor() public {
        // Verify initial state
        assertEq(address(twapOracle.oracle()), address(twapOracleMock), "Oracle address should be set correctly");
        assertEq(twapOracle.lastUpdateTime(), block.timestamp, "Last update time should be set to current timestamp");

        // Verify initial TWAP prices (should be initialized with the same price for all observations)
        (uint256 twapRzr, uint256 twapUsd) = twapOracle.getTwap();
        assertEq(twapRzr, 1e18, "Initial TWAP RZR price should be 1e18");
        assertEq(twapUsd, 2e18, "Initial TWAP USD price should be 2e18");

        // Verify observations array is initialized
        for (uint256 i = 0; i < MAX_OBSERVATIONS; i++) {
            TwapOracleV3.Observation memory obs = twapOracle.observations(i);
            assertEq(obs.timestamp, block.timestamp, "Observation timestamp should be current time");
            assertEq(obs.priceUsd, 2e18, "Observation USD price should be 2e18");
            assertEq(obs.priceRzr, 1e18, "Observation RZR price should be 1e18");
        }
    }

    function test_ConstructorReverts() public {
        // Test with zero oracle address
        vm.expectRevert("Invalid oracle address");
        new TwapOracleV3(IOracleV2(address(0)), MAX_OBSERVATIONS, address(authority));

        // Test with zero max observations
        vm.expectRevert("Max observations must be > 0");
        new TwapOracleV3(twapOracleMock, 0, address(authority));

        // Test with stale price
        MockOracleV2 staleOracle = new MockOracleV2(1e18, 2e18, address(mockAsset));
        vm.warp(block.timestamp + MAX_STALENESS + 1);
        vm.expectRevert("Price is stale");
        new TwapOracleV3(staleOracle, MAX_OBSERVATIONS, address(authority));
    }

    function test_Update() public {
        uint256 initialTime = block.timestamp;

        // Warp to allow update (after EPOCH_DURATION)
        vm.warp(initialTime + EPOCH_DURATION + 1);

        // Change oracle price
        twapOracleMock.setPrice(2e18, 4e18); // 1 RZR = $4 USD

        // Update as executor
        vm.prank(owner);
        twapOracle.update();

        // Verify last update time
        assertEq(twapOracle.lastUpdateTime(), block.timestamp, "Last update time should be updated");

        // Verify TWAP calculation
        (uint256 twapRzr, uint256 twapUsd) = twapOracle.getTwap();

        // Expected calculation:
        // Old TWAP: 1e18 * 5 = 5e18 (RZR), 2e18 * 5 = 10e18 (USD)
        // New price: 2e18 (RZR), 4e18 (USD)
        // New TWAP: (5e18 - 1e18 + 2e18) / 5 = 6e18 / 5 = 1.2e18
        // New TWAP: (10e18 - 2e18 + 4e18) / 5 = 12e18 / 5 = 2.4e18
        assertEq(twapRzr, 1.2e18, "TWAP RZR price should be updated correctly");
        assertEq(twapUsd, 2.4e18, "TWAP USD price should be updated correctly");
    }

    function test_UpdateReverts() public {
        // Test updating too early
        vm.expectRevert("Too early to update");
        vm.prank(owner);
        twapOracle.update();

        // Test updating with stale price
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        vm.warp(block.timestamp + MAX_STALENESS + 1);

        vm.expectRevert("Price is stale");
        vm.prank(owner);
        twapOracle.update();

        // Test updating with invalid price (both zero)
        vm.warp(block.timestamp - MAX_STALENESS - 1);
        twapOracleMock.setPrice(0, 0);

        vm.expectRevert("Invalid price");
        vm.prank(owner);
        twapOracle.update();
    }

    function test_UpdateMultipleTimes() public {
        uint256 initialTime = block.timestamp;

        // First update
        vm.warp(initialTime + EPOCH_DURATION + 1);
        twapOracleMock.setPrice(2e18, 4e18);

        vm.prank(owner);
        twapOracle.update();

        // Second update
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        twapOracleMock.setPrice(3e18, 6e18);

        vm.prank(owner);
        twapOracle.update();

        // Third update
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        twapOracleMock.setPrice(4e18, 8e18);

        vm.prank(owner);
        twapOracle.update();

        // Verify TWAP calculation after multiple updates
        (uint256 twapRzr, uint256 twapUsd) = twapOracle.getTwap();

        // Expected calculation after 3 updates:
        // Initial: 5 observations of (1e18, 2e18)
        // Update 1: Replace oldest with (2e18, 4e18) -> TWAP: (1.2e18, 2.4e18)
        // Update 2: Replace oldest with (3e18, 6e18) -> TWAP: (1.4e18, 2.8e18)
        // Update 3: Replace oldest with (4e18, 8e18) -> TWAP: (2.2e18, 4.4e18)
        assertEq(twapRzr, 2.2e18, "TWAP RZR price should be correct after multiple updates");
        assertEq(twapUsd, 4.4e18, "TWAP USD price should be correct after multiple updates");
    }

    function test_UpdateCircularBuffer() public {
        uint256 initialTime = block.timestamp;

        // Perform updates to cycle through all observations
        for (uint256 i = 0; i < MAX_OBSERVATIONS + 2; i++) {
            vm.warp(initialTime + (i + 1) * EPOCH_DURATION + 1);

            // Set different prices for each update
            uint256 newPriceRzr = (i + 2) * 1e18; // 2e18, 3e18, 4e18, 5e18, 6e18, 7e18, 8e18
            uint256 newPriceUsd = newPriceRzr * 2; // 4e18, 6e18, 8e18, 10e18, 12e18, 14e18, 16e18

            twapOracleMock.setPrice(newPriceRzr, newPriceUsd);

            vm.prank(owner);
            twapOracle.update();
        }

        // After cycling through all observations, the oldest ones should be replaced
        (uint256 twapRzr, uint256 twapUsd) = twapOracle.getTwap();

        // The TWAP should now be based on the most recent 5 observations
        // which should be: 4e18, 5e18, 6e18, 7e18, 8e18 for RZR
        // and: 8e18, 10e18, 12e18, 14e18, 16e18 for USD
        uint256 expectedRzr = (4e18 + 5e18 + 6e18 + 7e18 + 8e18) / 5;
        uint256 expectedUsd = (8e18 + 10e18 + 12e18 + 14e18 + 16e18) / 5;

        assertEq(twapRzr, expectedRzr, "TWAP RZR price should be correct after cycling through buffer");
        assertEq(twapUsd, expectedUsd, "TWAP USD price should be correct after cycling through buffer");
    }

    function test_GetPriceForAmount() public {
        // Test getting price for amount
        (uint256 priceRzr, uint256 priceUsd, uint256 lastUpdated) = twapOracle.getPriceForAmount(1e18);

        (uint256 twapRzr, uint256 twapUsd) = twapOracle.getTwap();
        assertEq(priceRzr, twapRzr, "Price RZR should match TWAP RZR");
        assertEq(priceUsd, twapUsd, "Price USD should match TWAP USD");
        assertEq(lastUpdated, twapOracle.lastUpdateTime(), "Last updated should match oracle's last update time");
    }

    function test_Asset() public {
        // Test asset function
        IERC20Metadata asset = twapOracle.asset();
        assertEq(address(asset), address(mockAsset), "Asset should match mock asset");
    }

    function test_OnlyExecutor() public {
        // Test that only executor can update
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        twapOracleMock.setPrice(2e18, 4e18);

        vm.expectRevert("UNAUTHORIZED");
        vm.prank(user1);
        twapOracle.update();

        // Owner should be able to update
        vm.prank(owner);
        twapOracle.update();
    }

    function test_ObservationsArray() public {
        // Test observations function
        for (uint256 i = 0; i < MAX_OBSERVATIONS; i++) {
            TwapOracleV3.Observation memory obs = twapOracle.observations(i);
            assertEq(obs.timestamp, block.timestamp, "Observation timestamp should be correct");
            assertEq(obs.priceUsd, 2e18, "Observation USD price should be correct");
            assertEq(obs.priceRzr, 1e18, "Observation RZR price should be correct");
        }

        // Test out of bounds access
        vm.expectRevert();
        twapOracle.observations(MAX_OBSERVATIONS);
    }

    function test_Constants() public {
        // Test immutable constants
        assertEq(twapOracle.MAX_STALENESS(), MAX_STALENESS, "MAX_STALENESS should be correct");
        assertEq(twapOracle.EPOCH_DURATION(), EPOCH_DURATION, "EPOCH_DURATION should be correct");
    }
}
