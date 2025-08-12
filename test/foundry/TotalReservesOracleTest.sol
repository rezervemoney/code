// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../contracts/oracles/crosschain/TotalReservesOracle.sol";
import "../../contracts/core/AppAuthority.sol";
import "../../contracts/mocks/MockEndpoint.sol";
import "./BaseTest.sol";
import "forge-std/console.sol";

contract TotalReservesOracleTest is BaseTest {
    address public bridge = makeAddr("bridge");

    function setUp() public {
        setUpBaseTest();

        vm.startPrank(owner);

        // Set bridge address
        authority.setBridge(bridge);

        vm.stopPrank();

        vm.label(address(totalReservesOracle), "TotalReservesOracle");
        vm.label(offchainUpdater, "OffchainUpdater");
        vm.label(bridge, "Bridge");
    }

    function test_Initialize() public view {
        assertEq(address(totalReservesOracle.authority()), address(authority));
        assertEq(totalReservesOracle.offchainUpdater(), offchainUpdater);
        assertEq(totalReservesOracle.maxDeviation(), 1e16); // 1% (100 basis points)
        assertEq(totalReservesOracle.staleness(), 1 days);
    }

    function test_Initialize_RevertIfAlreadyInitialized() public {
        vm.expectRevert();
        totalReservesOracle.initialize(address(authority), offchainUpdater);
    }

    function test_GetOnchainReserves() public {
        uint256 rzrReserves = 1000e18;
        uint256 usdReserves = 2000e18;

        vm.prank(bridge);
        totalReservesOracle.setCrosschainReserves(1, rzrReserves, usdReserves);

        (uint256 actualRzr, uint256 actualUsd) = totalReservesOracle.getOnchainReserves();
        assertEq(actualRzr, rzrReserves);
        assertEq(actualUsd, usdReserves);
    }

    function test_GetOffchainReserves() public {
        uint256 rzrReserves = 1500e18;
        uint256 usdReserves = 2500e18;

        vm.prank(offchainUpdater);
        totalReservesOracle.updateReservesOffchain(rzrReserves, usdReserves);

        (uint256 actualRzr, uint256 actualUsd) = totalReservesOracle.getOffchainReserves();
        assertEq(actualRzr, rzrReserves);
        assertEq(actualUsd, usdReserves);
    }

    function test_GetOffchainReserves_RevertIfStale() public {
        uint256 rzrReserves = 1500e18;
        uint256 usdReserves = 2500e18;

        vm.prank(offchainUpdater);
        totalReservesOracle.updateReservesOffchain(rzrReserves, usdReserves);

        // Fast forward past staleness period
        vm.warp(block.timestamp + 2 days);

        vm.expectRevert("Offchain reserves are stale");
        totalReservesOracle.getOffchainReserves();
    }

    function test_GetTotalReserves() public {
        // Set up onchain reserves
        uint256 onchainRzr = 1000e18;
        uint256 onchainUsd = 2000e18;

        vm.prank(bridge);
        totalReservesOracle.setCrosschainReserves(1, onchainRzr, onchainUsd);

        // Set up offchain reserves within deviation
        uint256 offchainRzr = 1005e18; // Within 1% of 1000e18 (1000 * 1.005 = 1005)
        uint256 offchainUsd = 2010e18; // Within 1% of 2000e18 (2000 * 1.005 = 2010)

        vm.prank(offchainUpdater);
        totalReservesOracle.updateReservesOffchain(offchainRzr, offchainUsd);

        // Set up credits
        uint256 creditRzr = 100e18;
        uint256 creditUsd = 200e18;

        vm.prank(owner);
        totalReservesOracle.setReservesCreditRzr(creditRzr);

        vm.prank(owner);
        totalReservesOracle.setReservesCreditUsd(creditUsd);

        (uint256 totalRzr, uint256 totalUsd) = totalReservesOracle.getTotalReserves();
        assertEq(totalRzr, onchainRzr + creditRzr);
        assertEq(totalUsd, onchainUsd + creditUsd);
    }

    function test_GetTotalReserves_RevertIfRzrDeviationTooHigh() public {
        // Set up onchain reserves
        uint256 onchainRzr = 1000e18;
        uint256 onchainUsd = 2000e18;

        vm.prank(bridge);
        totalReservesOracle.setCrosschainReserves(1, onchainRzr, onchainUsd);

        // Set up offchain reserves with RZR deviation too high
        uint256 offchainRzr = 1100e18; // More than 1% higher than 1000e18 (1000 * 1.1 = 1100)
        uint256 offchainUsd = 2010e18; // Within 1% of 2000e18

        vm.prank(offchainUpdater);
        totalReservesOracle.updateReservesOffchain(offchainRzr, offchainUsd);

        vm.expectRevert("RZR reserves deviation too low");
        totalReservesOracle.getTotalReserves();
    }

    function test_GetTotalReserves_RevertIfUsdDeviationTooHigh() public {
        // Set up onchain reserves
        uint256 onchainRzr = 1000e18;
        uint256 onchainUsd = 2000e18;

        vm.prank(bridge);
        totalReservesOracle.setCrosschainReserves(1, onchainRzr, onchainUsd);

        // Set up offchain reserves with USD deviation too high
        uint256 offchainRzr = 1005e18; // Within 1% of 1000e18
        uint256 offchainUsd = 2400e18; // More than 1% higher than 2000e18

        vm.prank(offchainUpdater);
        totalReservesOracle.updateReservesOffchain(offchainRzr, offchainUsd);

        vm.expectRevert("USD reserves deviation too high");
        totalReservesOracle.getTotalReserves();
    }

    function test_UpdateReservesOffchain() public {
        uint256 rzrReserves = 2000e18;
        uint256 usdReserves = 3000e18;

        vm.prank(offchainUpdater);
        totalReservesOracle.updateReservesOffchain(rzrReserves, usdReserves);

        assertEq(totalReservesOracle.offchainRzrReserves(), rzrReserves);
        assertEq(totalReservesOracle.offchainUsdReserves(), usdReserves);
        assertEq(totalReservesOracle.lastUpdatedOffchainAt(), block.timestamp);
    }

    function test_UpdateReservesOffchain_RevertIfNotOffchainUpdater() public {
        vm.expectRevert("Only updater");
        totalReservesOracle.updateReservesOffchain(1000e18, 2000e18);
    }

    function test_SetOffchainUpdater() public {
        address newUpdater = makeAddr("newUpdater");

        vm.prank(owner);
        totalReservesOracle.setOffchainUpdater(newUpdater);

        assertEq(totalReservesOracle.offchainUpdater(), newUpdater);
    }

    function test_SetOffchainUpdater_RevertIfNotGovernor() public {
        vm.expectRevert("UNAUTHORIZED");
        totalReservesOracle.setOffchainUpdater(makeAddr("newUpdater"));
    }

    function test_OverwriteCrosschainReserves() public {
        uint256 eid = 1;
        uint256 rzrReserves = 800e18;
        uint256 usdReserves = 1600e18;

        vm.prank(owner);
        totalReservesOracle.overwriteCrosschainReserves(eid, rzrReserves, usdReserves);

        (uint256 actualRzr, uint256 actualUsd) = totalReservesOracle.getCrosschainReserves(eid);
        assertEq(actualRzr, rzrReserves);
        assertEq(actualUsd, usdReserves);
    }

    function test_OverwriteCrosschainReserves_RevertIfNotGovernor() public {
        vm.expectRevert("UNAUTHORIZED");
        totalReservesOracle.overwriteCrosschainReserves(1, 1000e18, 2000e18);
    }

    function test_OverwriteOnchainReserves() public {
        uint256 rzrReserves = 1200e18;
        uint256 usdReserves = 2400e18;

        vm.prank(bridge);
        totalReservesOracle.setCrosschainReserves(1, rzrReserves, usdReserves);

        (uint256 actualRzr, uint256 actualUsd) = totalReservesOracle.getCrosschainReserves(1);
        assertEq(actualRzr, rzrReserves);
        assertEq(actualUsd, usdReserves);
    }

    function test_OverwriteOnchainReserves_RevertIfNotGovernor() public {
        vm.expectRevert("UNAUTHORIZED");
        totalReservesOracle.setCrosschainReserves(1, 1000e18, 2000e18);
    }

    function test_SetReservesCreditRzr() public {
        uint256 credit = 200e18;

        vm.prank(owner);
        totalReservesOracle.setReservesCreditRzr(credit);

        assertEq(totalReservesOracle.reservesCreditRzr(), credit);
    }

    function test_SetReservesCreditRzr_RevertIfNotGovernor() public {
        vm.expectRevert("UNAUTHORIZED");
        totalReservesOracle.setReservesCreditRzr(100e18);
    }

    function test_SetReservesCreditUsd() public {
        uint256 credit = 300e18;

        vm.prank(owner);
        totalReservesOracle.setReservesCreditUsd(credit);

        assertEq(totalReservesOracle.reservesCreditUsd(), credit);
    }

    function test_SetReservesCreditUsd_RevertIfNotGovernor() public {
        vm.expectRevert("UNAUTHORIZED");
        totalReservesOracle.setReservesCreditUsd(100e18);
    }

    function test_SetCrosschainReserves() public {
        uint256 eid = 1;
        uint256 oldRzr = 500e18;
        uint256 oldUsd = 1000e18;
        uint256 newRzr = 700e18;
        uint256 newUsd = 1400e18;

        // Set initial crosschain reserves
        vm.prank(owner);
        totalReservesOracle.overwriteCrosschainReserves(eid, oldRzr, oldUsd);

        // Set initial l2chain total reserves
        vm.prank(bridge);
        totalReservesOracle.setCrosschainReserves(eid, oldRzr, oldUsd);

        // Update via bridge
        vm.prank(bridge);
        totalReservesOracle.setCrosschainReserves(eid, newRzr, newUsd);

        (uint256 actualRzr, uint256 actualUsd) = totalReservesOracle.getCrosschainReserves(eid);
        assertEq(actualRzr, newRzr);
        assertEq(actualUsd, newUsd);
    }

    function test_SetCrosschainReserves_RevertIfNotBridge() public {
        vm.expectRevert("UNAUTHORIZED");
        totalReservesOracle.setCrosschainReserves(1, 1000e18, 2000e18);
    }

    function test_SetMaxDeviation() public {
        uint256 newDeviation = 0.02e18; // 2%

        vm.prank(owner);
        totalReservesOracle.setMaxDeviation(newDeviation);

        assertEq(totalReservesOracle.maxDeviation(), newDeviation);
    }

    function test_SetMaxDeviation_RevertIfNotGovernor() public {
        vm.expectRevert("UNAUTHORIZED");
        totalReservesOracle.setMaxDeviation(0.02e18);
    }

    function test_SetStaleness() public {
        uint256 newStaleness = 2 days;

        vm.prank(owner);
        totalReservesOracle.setStaleness(newStaleness);

        assertEq(totalReservesOracle.staleness(), newStaleness);
    }

    function test_SetStaleness_RevertIfNotGovernor() public {
        vm.expectRevert("UNAUTHORIZED");
        totalReservesOracle.setStaleness(2 days);
    }

    function test_Events() public {
        // Test ReservesOffchainUpdated event
        vm.expectEmit(true, true, true, false);
        emit ITotalReservesOracle.ReservesOffchainUpdated(1000e18, 2000e18, block.timestamp);
        vm.prank(offchainUpdater);
        totalReservesOracle.updateReservesOffchain(1000e18, 2000e18);

        // Test OffchainUpdaterUpdated event
        address newUpdater = makeAddr("newUpdater");
        vm.expectEmit(true, false, false, false);
        emit ITotalReservesOracle.OffchainUpdaterUpdated(newUpdater);
        vm.prank(owner);
        totalReservesOracle.setOffchainUpdater(newUpdater);

        // Test CrosschainReservesUpdated event
        vm.expectEmit(true, true, true, false);
        emit ITotalReservesOracle.CrosschainReservesUpdated(1, 500e18, 1000e18, block.timestamp);
        vm.prank(owner);
        totalReservesOracle.overwriteCrosschainReserves(1, 500e18, 1000e18);

        // Test ReservesOnchainUpdated event
        vm.expectEmit(true, true, false, false);
        emit ITotalReservesOracle.ReservesOnchainUpdated(1000e18, 2000e18);
        vm.prank(bridge);
        totalReservesOracle.setCrosschainReserves(1, 1000e18, 2000e18);

        // Test ReservesCreditRzrUpdated event
        vm.expectEmit(true, false, false, false);
        emit ITotalReservesOracle.ReservesCreditRzrUpdated(200e18);
        vm.prank(owner);
        totalReservesOracle.setReservesCreditRzr(200e18);

        // Test ReservesCreditUsdUpdated event
        vm.expectEmit(true, false, false, false);
        emit ITotalReservesOracle.ReservesCreditUsdUpdated(300e18);
        vm.prank(owner);
        totalReservesOracle.setReservesCreditUsd(300e18);
    }

    function test_ComplexScenario() public {
        // Set up initial state
        uint256 l2chainRzr = 300e18;
        uint256 l2chainUsd = 600e18;
        uint256 creditRzr = 100e18;
        uint256 creditUsd = 200e18;

        // Set onchain reserves
        vm.prank(bridge);
        totalReservesOracle.setCrosschainReserves(1, l2chainRzr, l2chainUsd);

        // Set offchain reserves (within 1% deviation)
        vm.prank(offchainUpdater);
        totalReservesOracle.updateReservesOffchain(
            (l2chainRzr * 10050) / 10000, // 0.5% higher
            (l2chainUsd * 10050) / 10000 // 0.5% higher
        );

        vm.startPrank(owner);
        // Set credits
        totalReservesOracle.setReservesCreditRzr(creditRzr);
        totalReservesOracle.setReservesCreditUsd(creditUsd);
        vm.stopPrank();

        // Set crosschain reserves for multiple chains
        vm.prank(bridge);
        totalReservesOracle.setCrosschainReserves(1, 200e18, 400e18);
        vm.prank(bridge);
        totalReservesOracle.setCrosschainReserves(2, 200e18, 400e18);

        // Update via bridge
        vm.prank(bridge);
        totalReservesOracle.setCrosschainReserves(1, 100e18, 200e18);

        // Verify final state
        (uint256 chain1Rzr, uint256 chain1Usd) = totalReservesOracle.getCrosschainReserves(1);
        (uint256 chain2Rzr, uint256 chain2Usd) = totalReservesOracle.getCrosschainReserves(2);
        assertEq(chain1Rzr, 100e18);
        assertEq(chain2Rzr, 200e18);
        assertEq(chain1Usd, 200e18);
        assertEq(chain2Usd, 400e18);

        (uint256 totalRzr, uint256 totalUsd) = totalReservesOracle.getTotalReserves();
        assertEq(totalRzr, l2chainRzr + creditRzr);
        assertEq(totalUsd, l2chainUsd + creditUsd);
    }
}
