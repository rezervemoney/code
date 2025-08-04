// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
pragma abicoder v2;

import "forge-std/Test.sol";
import "../../contracts/core/RebaseController.sol";
import "../../contracts/core/RZR.sol";
import "../../contracts/core/sRZR.sol";
import "../../contracts/core/AppTreasury.sol";
import "../../contracts/core/AppStaking.sol";
import "../../contracts/mocks/MockERC20.sol";
import "../../contracts/mocks/MockOracleV2.sol";
import "../../contracts/mocks/MockEndpoint.sol";
import "../../contracts/core/AppAuthority.sol";
import "../../contracts/core/AppBondDepository.sol";
import "../../contracts/core/AppOracle.sol";
import "../../contracts/core/AppBurner.sol";
import "../../contracts/periphery/Staking4626.sol";
import "../../contracts/periphery/LoyaltyList.sol";
import "../../contracts/oracles/crosschain/TotalSupplyOracle.sol";
import "../../contracts/oracles/crosschain/TotalReservesOracle.sol";
import "../../contracts/periphery/bridge/BridgeL1.sol";

contract BaseTest is Test {
    RebaseController public rebaseController;
    RZR public app;
    sRZR public sapp;
    AppTreasury public treasury;
    AppStaking public staking;
    MockERC20 public mockQuoteToken;
    MockERC20 public mockQuoteToken2;
    MockERC20 public mockQuoteToken3;

    AppOracle public appOracle;

    MockOracleV2 public mockOracle;
    MockOracleV2 public mockOracle2;
    MockOracleV2 public mockOracle3;

    MockEndpoint public lz;

    LoyaltyList public loyaltyList;

    AppAuthority public authority;
    AppBondDepository public bondDepository;
    AppBurner public burner;

    Staking4626 public staking4626;

    TotalReservesOracle public totalReservesOracle;
    TotalSupplyOracle public totalSupplyOracle;
    BridgeL1 public bridgeL1;

    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public offchainUpdater = makeAddr("offchainUpdater");
    address public operationsTreasury = makeAddr("operationsTreasury");

    function setUpBaseTest() public {
        vm.warp(block.timestamp + 10 days);

        vm.startPrank(owner);

        authority = new AppAuthority();

        // Deploy mock quote token
        mockQuoteToken = new MockERC20("Mock Token", "MTK");
        mockQuoteToken2 = new MockERC20("Mock Token 2", "MTK2");
        mockQuoteToken3 = new MockERC20("Mock Token 3", "MTK3");

        // Deploy mock oracle
        mockOracle = new MockOracleV2(0, 1e18, address(mockQuoteToken)); // 1:1 price
        mockOracle2 = new MockOracleV2(0, 2e18, address(mockQuoteToken2)); // 2:1 price
        mockOracle3 = new MockOracleV2(0, 0.5e18, address(mockQuoteToken3)); // 0.5:1 price

        // Deploy RZR token
        lz = new MockEndpoint();
        app = new RZR(address(lz), address(authority));

        // Deploy sRZR token
        sapp = new sRZR(address(authority));

        // Deploy TotalSupplyOracle
        totalSupplyOracle = new TotalSupplyOracle();
        totalSupplyOracle.initialize(address(authority), offchainUpdater, address(app));

        // Deploy TotalReservesOracle
        totalReservesOracle = new TotalReservesOracle();
        totalReservesOracle.initialize(address(authority), offchainUpdater);

        appOracle = new AppOracle();
        appOracle.initialize(address(authority), address(app));
        appOracle.updateOracle(address(mockQuoteToken), address(mockOracle), 3600);
        appOracle.updateOracle(address(mockQuoteToken2), address(mockOracle2), 3600);
        appOracle.updateOracle(address(mockQuoteToken3), address(mockOracle3), 3600);

        // Deploy Burner
        burner = new AppBurner();
        burner.initialize(address(appOracle), address(app), address(authority), address(totalSupplyOracle));

        // Deploy Treasury
        treasury = new AppTreasury();
        treasury.initialize(address(app), address(appOracle), address(authority));
        treasury.enable(address(mockQuoteToken));

        // Deploy Staking
        staking = new AppStaking();
        staking.initialize(address(app), address(sapp), address(authority), address(burner), address(totalSupplyOracle));

        // Deploy LoyaltyList
        loyaltyList = new LoyaltyList(address(authority));

        // Deploy AppBondDepository
        bondDepository = new AppBondDepository();
        bondDepository.initialize(
            address(app), address(staking), address(treasury), address(authority), address(loyaltyList)
        );

        // Deploy BridgeL1
        bridgeL1 = new BridgeL1();
        bridgeL1.initialize(
            address(lz),
            owner,
            address(authority),
            address(staking),
            address(staking4626),
            address(app),
            address(treasury),
            address(totalReservesOracle),
            address(totalSupplyOracle)
        );

        sapp.setStakingContract(address(staking));

        // Deploy RebaseController
        rebaseController = new RebaseController();
        rebaseController.initialize(
            address(app),
            address(appOracle),
            address(staking),
            address(authority),
            address(burner),
            address(totalSupplyOracle),
            address(totalReservesOracle)
        );
        rebaseController.setTargetPcts(0.1e18, 0.15e18, 0.5e18, 0.5e18);

        staking4626 = new Staking4626();
        staking4626.initialize("RZR Vault", "vRZR", address(staking), address(authority), address(lz), owner);

        authority.addPolicy(address(treasury));
        authority.addPolicy(address(rebaseController));
        authority.addPolicy(address(owner));
        authority.addPolicy(address(burner));
        authority.addExecutor(address(owner));
        authority.addBondManager(address(owner));
        authority.addExecutor(address(rebaseController));
        authority.addGovernor(address(owner));
        authority.setOperationsTreasury(operationsTreasury);
        authority.setTreasury(address(treasury));
        authority.addReserveDepositor(address(bondDepository));
        authority.setBridge(address(bridgeL1));

        vm.label(address(app), "RZR");
        vm.label(address(sapp), "sRZR");
        vm.label(address(treasury), "Treasury");
        vm.label(address(staking), "Staking");
        vm.label(address(rebaseController), "RebaseController");
        vm.label(address(bondDepository), "AppBondDepository");
        vm.label(address(burner), "Burner");
        vm.label(address(authority), "Authority");
        vm.label(address(mockQuoteToken), "Mock Quote Token");
        vm.label(address(mockQuoteToken2), "Mock Quote Token 2");
        vm.label(address(mockQuoteToken3), "Mock Quote Token 3");
        vm.label(address(staking4626), "Staking4626");

        vm.label(address(appOracle), "RZR Oracle");
        vm.label(address(mockOracle), "Mock Oracle");
        vm.label(address(mockOracle2), "Mock Oracle 2");
        vm.label(address(mockOracle3), "Mock Oracle 3");

        vm.stopPrank();

        _syncOracles();
    }

    function _syncOracles() internal {
        _syncTotalSupplyOracle();
        _syncReservesOracle();
    }

    function _syncTotalSupplyOracle() internal {
        uint256 totalSupply = app.totalSupply();
        vm.prank(offchainUpdater);
        totalSupplyOracle.updateTotalSupplyOffchain(totalSupply);

        // // sync onchain total supply
        // vm.prank(address(bridgeL1));
        // totalSupplyOracle.setCrosschainTotalSupply(1, 0);
    }

    function _syncReservesOracle() internal {
        // sync on chain
        vm.prank(address(owner));
        bridgeL1.syncMainnetReserves();

        (uint256 rzrReserves, uint256 usdReserves) = totalReservesOracle.getOnchainReserves();

        // sync off chain
        vm.prank(offchainUpdater);
        totalReservesOracle.updateReservesOffchain(rzrReserves, usdReserves);
    }
}
