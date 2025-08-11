// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../../contracts/oracles/crosschain/TotalSupplyOracle.sol";
import "../../contracts/core/RZR.sol";
import "../../contracts/core/AppAuthority.sol";
import "../../contracts/mocks/MockEndpoint.sol";
import "./BaseTest.sol";
import "forge-std/console.sol";

contract TotalSupplyOracleTest is BaseTest {
    address public bridge = makeAddr("bridge");

    function setUp() public {
        setUpBaseTest();

        vm.startPrank(owner);

        // Set bridge address
        authority.setBridge(bridge);

        vm.stopPrank();

        vm.label(address(totalSupplyOracle), "TotalSupplyOracle");
        vm.label(offchainUpdater, "OffchainUpdater");
        vm.label(bridge, "Bridge");
    }

    function test_Initialize() public view {
        assertEq(address(totalSupplyOracle.authority()), address(authority));
        assertEq(totalSupplyOracle.offchainUpdater(), offchainUpdater);
        assertEq(address(totalSupplyOracle.rzr()), address(app));
        assertEq(totalSupplyOracle.maxDeviation(), 0.05e18); // 5%
        assertEq(totalSupplyOracle.staleness(), 24.5 hours);
    }

    function test_Initialize_RevertIfAlreadyInitialized() public {
        vm.expectRevert();
        totalSupplyOracle.initialize(address(authority), offchainUpdater, address(app));
    }

    function test_GetOnchainTotalSupply() public {
        // Set up initial state
        uint256 l2chainSupply = 1000e18;
        uint256 rzrSupply = 500e18;

        vm.prank(owner);
        totalSupplyOracle.overwriteCrosschainTotalSupply(1, l2chainSupply);

        // Mint some RZR tokens
        vm.prank(owner);
        app.mint(address(this), rzrSupply);

        uint256 expectedTotal = l2chainSupply + rzrSupply;
        assertEq(totalSupplyOracle.getOnchainTotalSupply(), expectedTotal);
    }

    function test_GetOffchainTotalSupply() public {
        uint256 offchainSupply = 1500e18;

        vm.prank(offchainUpdater);
        totalSupplyOracle.updateTotalSupplyOffchain(offchainSupply);

        assertEq(totalSupplyOracle.getOffchainTotalSupply(), offchainSupply);
    }

    function test_GetOffchainTotalSupply_RevertIfStale() public {
        uint256 offchainSupply = 1500e18;

        vm.prank(offchainUpdater);
        totalSupplyOracle.updateTotalSupplyOffchain(offchainSupply);

        // Fast forward past staleness period
        vm.warp(block.timestamp + 25 hours);

        vm.expectRevert("Offchain total supply is stale");
        totalSupplyOracle.getOffchainTotalSupply();
    }

    function test_GetTotalSupply() public {
        // Set up onchain supply
        uint256 l2chainSupply = 1000e18;
        uint256 rzrSupply = 500e18;

        vm.prank(owner);
        totalSupplyOracle.overwriteCrosschainTotalSupply(1, l2chainSupply);

        vm.prank(owner);
        app.mint(address(this), rzrSupply);

        // Set up offchain supply within deviation (within 1% of 1500e18)
        uint256 offchainSupply = 1510e18; // Within 1% of 1500e18 (1500 * 1.0067 = 1510)

        vm.prank(offchainUpdater);
        totalSupplyOracle.updateTotalSupplyOffchain(offchainSupply);

        // Set up credits and unbacked
        uint256 credit = 100e18;
        uint256 unbacked = 50e18;

        vm.prank(owner);
        totalSupplyOracle.setTotalSupplyCredit(credit);

        vm.prank(owner);
        totalSupplyOracle.setTotalSupplyUnbacked(unbacked);

        uint256 expectedTotal = l2chainSupply + rzrSupply + credit - unbacked;
        assertEq(totalSupplyOracle.getTotalSupply(), expectedTotal);
    }

    function test_GetTotalSupply_RevertIfDeviationTooHigh() public {
        // Set up onchain supply
        uint256 l2chainSupply = 1000e18;
        uint256 rzrSupply = 500e18;

        vm.prank(owner);
        totalSupplyOracle.overwriteCrosschainTotalSupply(1, l2chainSupply);

        vm.prank(owner);
        app.mint(address(this), rzrSupply);

        // Set up offchain supply outside deviation (more than 1% difference)
        uint256 offchainSupply = 1600e18; // More than 1% higher than 1500e18 (1500 * 1.067 = 1600)

        vm.prank(offchainUpdater);
        totalSupplyOracle.updateTotalSupplyOffchain(offchainSupply);

        vm.expectRevert("deviation too low");
        totalSupplyOracle.getTotalSupply();
    }

    function test_ToggleEid() public {
        uint256 eid = 1;

        // Initially disabled
        assertEq(totalSupplyOracle.isEidEnabled(eid), false);

        vm.prank(owner);
        totalSupplyOracle.toggleEid(eid);

        // Now enabled
        assertEq(totalSupplyOracle.isEidEnabled(eid), true);

        vm.prank(owner);
        totalSupplyOracle.toggleEid(eid);

        // Back to disabled
        assertEq(totalSupplyOracle.isEidEnabled(eid), false);
    }

    function test_ToggleEid_RevertIfNotGovernor() public {
        vm.expectRevert("UNAUTHORIZED");
        totalSupplyOracle.toggleEid(1);
    }

    function test_UpdateTotalSupplyOffchain() public {
        uint256 offchainSupply = 2000e18;

        vm.prank(offchainUpdater);
        totalSupplyOracle.updateTotalSupplyOffchain(offchainSupply);

        assertEq(totalSupplyOracle.offchainTotalSupply(), offchainSupply);
        assertEq(totalSupplyOracle.lastUpdatedOffchainAt(), block.timestamp);
    }

    function test_UpdateTotalSupplyOffchain_RevertIfNotOffchainUpdater() public {
        vm.expectRevert("Only offchainUpdater");
        totalSupplyOracle.updateTotalSupplyOffchain(1000e18);
    }

    function test_SetOffchainUpdater() public {
        address newUpdater = makeAddr("newUpdater");

        vm.prank(owner);
        totalSupplyOracle.setOffchainUpdater(newUpdater);

        assertEq(totalSupplyOracle.offchainUpdater(), newUpdater);
    }

    function test_SetOffchainUpdater_RevertIfNotGovernor() public {
        vm.expectRevert("UNAUTHORIZED");
        totalSupplyOracle.setOffchainUpdater(makeAddr("newUpdater"));
    }

    function test_OverwriteCrosschainTotalSupply() public {
        uint256 eid = 1;
        uint256 crosschainSupply = 800e18;

        // Enable the EID first
        vm.prank(owner);
        totalSupplyOracle.toggleEid(eid);

        vm.prank(owner);
        totalSupplyOracle.overwriteCrosschainTotalSupply(eid, crosschainSupply);

        assertEq(totalSupplyOracle.crosschainTotalSupply(eid), crosschainSupply);
    }

    function test_SetTotalSupplyCredit() public {
        uint256 credit = 200e18;

        vm.prank(owner);
        totalSupplyOracle.setTotalSupplyCredit(credit);

        assertEq(totalSupplyOracle.totalSupplyCredit(), credit);
    }

    function test_SetTotalSupplyCredit_RevertIfNotGovernor() public {
        vm.expectRevert("UNAUTHORIZED");
        totalSupplyOracle.setTotalSupplyCredit(100e18);
    }

    function test_SetTotalSupplyUnbacked() public {
        uint256 unbacked = 150e18;

        vm.prank(owner);
        totalSupplyOracle.setTotalSupplyUnbacked(unbacked);

        assertEq(totalSupplyOracle.totalSupplyUnbacked(), unbacked);
    }

    function test_SetTotalSupplyUnbacked_RevertIfNotGovernor() public {
        vm.expectRevert("UNAUTHORIZED");
        totalSupplyOracle.setTotalSupplyUnbacked(100e18);
    }

    function test_SetCrosschainTotalSupply() public {
        uint256 eid = 1;
        uint256 oldSupply = 500e18;
        uint256 newSupply = 700e18;

        // Enable the EID first
        vm.prank(owner);
        totalSupplyOracle.toggleEid(eid);

        // Set initial crosschain supply
        vm.prank(owner);
        totalSupplyOracle.overwriteCrosschainTotalSupply(eid, oldSupply);

        // Update via bridge
        vm.prank(bridge);
        totalSupplyOracle.setCrosschainTotalSupply(eid, newSupply);

        assertEq(totalSupplyOracle.crosschainTotalSupply(eid), newSupply);
    }

    function test_SetCrosschainTotalSupply_RevertIfNotBridge() public {
        vm.expectRevert("UNAUTHORIZED");
        totalSupplyOracle.setCrosschainTotalSupply(1, 1000e18);
    }

    function test_Events() public {
        // Test TotalSupplyOffchainUpdated event
        vm.expectEmit(true, true, false, true);
        emit ITotalSupplyOracle.TotalSupplyOffchainUpdated(1000e18, block.timestamp);
        vm.prank(offchainUpdater);
        totalSupplyOracle.updateTotalSupplyOffchain(1000e18);

        // Test OffchainUpdaterUpdated event
        address newUpdater = makeAddr("newUpdater");
        vm.expectEmit(true, false, false, false);
        emit ITotalSupplyOracle.OffchainUpdaterUpdated(newUpdater);
        vm.prank(owner);
        totalSupplyOracle.setOffchainUpdater(newUpdater);

        // Test CrosschainTotalSupplyUpdated event
        vm.prank(owner);
        totalSupplyOracle.toggleEid(1);
        vm.expectEmit(true, true, true, false);
        emit ITotalSupplyOracle.CrosschainTotalSupplyUpdated(1, 500e18, block.timestamp);
        vm.prank(owner);
        totalSupplyOracle.overwriteCrosschainTotalSupply(1, 500e18);

        // Test TotalSupplyCreditUpdated event
        vm.expectEmit(true, false, false, false);
        emit ITotalSupplyOracle.TotalSupplyCreditUpdated(200e18);
        vm.prank(owner);
        totalSupplyOracle.setTotalSupplyCredit(200e18);

        // Test TotalSupplyUnbackedUpdated event
        vm.expectEmit(true, false, false, false);
        emit ITotalSupplyOracle.TotalSupplyUnbackedUpdated(100e18);
        vm.prank(owner);
        totalSupplyOracle.setTotalSupplyUnbacked(100e18);

        // Test EidToggled event
        vm.expectEmit(true, true, false, false);
        emit ITotalSupplyOracle.EidToggled(1, false);
        vm.prank(owner);
        totalSupplyOracle.toggleEid(1);
    }

    function test_ComplexScenario() public {
        // Set up initial state
        uint256 l2chainSupply = 550e18;
        uint256 rzrSupply = 500e18;
        uint256 credit = 100e18;
        uint256 unbacked = 50e18;

        // Set onchain supply
        vm.prank(owner);
        totalSupplyOracle.overwriteCrosschainTotalSupply(1, l2chainSupply);

        // Mint RZR tokens
        vm.prank(owner);
        app.mint(address(this), rzrSupply);

        // Set offchain supply (within 1% deviation)
        vm.prank(offchainUpdater);
        totalSupplyOracle.updateTotalSupplyOffchain((l2chainSupply + rzrSupply) * 10025 / 10000); // 0.25% higher

        vm.startPrank(owner);
        // Set credits and unbacked
        totalSupplyOracle.setTotalSupplyCredit(credit);
        totalSupplyOracle.setTotalSupplyUnbacked(unbacked);

        // Enable some chains
        totalSupplyOracle.toggleEid(1);
        totalSupplyOracle.toggleEid(2);

        // Set crosschain supplies
        totalSupplyOracle.overwriteCrosschainTotalSupply(1, 300e18);
        totalSupplyOracle.overwriteCrosschainTotalSupply(2, 200e18);
        totalSupplyOracle.overwriteCrosschainTotalSupply(3, 500e18);
        vm.stopPrank();

        // Update via bridge
        vm.prank(bridge);
        totalSupplyOracle.setCrosschainTotalSupply(1, 350e18);

        // Verify final state
        assertEq(totalSupplyOracle.isEidEnabled(1), true);
        assertEq(totalSupplyOracle.isEidEnabled(2), true);
        assertEq(totalSupplyOracle.crosschainTotalSupply(1), 350e18);
        assertEq(totalSupplyOracle.crosschainTotalSupply(2), 200e18);
        assertEq(totalSupplyOracle.getTotalSupply(), l2chainSupply + rzrSupply + credit - unbacked);
    }
}
