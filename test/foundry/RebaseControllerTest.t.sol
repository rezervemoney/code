// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
pragma abicoder v2;

import "forge-std/Test.sol";
import "./BaseTest.sol";
import "../../contracts/core/RebaseController.sol";
import "../../contracts/core/RZR.sol";
import "../../contracts/core/sRZR.sol";
import "../../contracts/core/AppTreasury.sol";
import "../../contracts/core/AppStaking.sol";
import "../../contracts/mocks/MockERC20.sol";
import "../../contracts/mocks/MockOracle.sol";
import "../../contracts/interfaces/IAppOracle.sol";
import "forge-std/console.sol";

contract RebaseControllerTest is BaseTest {
    event Rebased(uint256 epochMint, uint256 toStakers, uint256 toOps, uint256 toBurner);

    function setUp() public {
        setUpBaseTest();

        vm.startPrank(owner);
        authority.addPolicy(owner);

        // Mint some quote tokens to treasury to simulate PCV
        mockQuoteToken.mint(address(treasury), 1_000_000e18);
        treasury.syncReserves();
    }

    function test_Initialization() public view {
        assertEq(address(rebaseController.app()), address(app));
        assertEq(address(rebaseController.treasury()), address(treasury));
        assertEq(address(rebaseController.staking()), address(staking));
        assertEq(address(rebaseController.burner()), address(burner));
        assertEq(rebaseController.lastEpochTime(), 0);
    }

    function test_BackingRatioZeroSupply() public view {
        assertEq(rebaseController.currentBackingRatio(), 0);
    }

    function test_BackingRatioWithSupply() public {
        // Mint some RZR tokens to simulate supply
        app.mint(owner, 1_000_000e18);

        // Treasury has 1M quote tokens (1:1 price)
        uint256 backingRatio = rebaseController.currentBackingRatio();
        assertEq(backingRatio, 1e18); // 1:1 backing
    }

    function test_ProjectedMintZeroSupply() public view {
        (, uint256 epochMint, uint256 toStakers, uint256 toOps, uint256 toBurner) =
            rebaseController.projectedEpochRate();
        assertEq(epochMint, 0);
        assertEq(toStakers, 0);
        assertEq(toOps, 0);
        assertEq(toBurner, 0);
    }

    function test_ProjectedMintWithBacking() public {
        // Mint RZR tokens to create supply
        app.mint(owner, 1_000_000e18);

        // Test with 1:1 backing (100%)
        (, uint256 epochMint, uint256 toStakers, uint256 toOps, uint256 toBurner) =
            rebaseController.projectedEpochRate();
        assertEq(epochMint, 0); // Below 100% backing
        assertEq(toStakers, 0);
        assertEq(toOps, 0);
        assertEq(toBurner, 0);

        // Add more PCV to treasury to increase backing ratio
        mockQuoteToken.mint(address(treasury), 500_000e18);
        treasury.syncReserves();

        // Test with 1.5:1 backing (150%)
        (, epochMint, toStakers, toOps, toBurner) = rebaseController.projectedEpochRate();
        assertGt(epochMint, 0); // Should have positive mint
        assertGt(toStakers, 0); // Should have staker rewards
        assertGt(toOps, 0); // Should have ops rewards
        assertGt(toBurner, 0); // Should have new floor price
    }

    function test_ExecuteEpochBeforeReady() public {
        vm.expectRevert("epoch not ready");
        rebaseController.executeEpoch();
    }

    function test_ExecuteEpochSuccess() public {
        // Mint RZR tokens to create supply
        app.mint(owner, 1_000_000e18);
        app.mint(user1, 1_000e18);

        // Add PCV to treasury to ensure positive rebase
        mockQuoteToken.mint(address(treasury), 2_000_000e18);
        treasury.syncReserves();

        // stake some tokens so that rewards can accumulate
        app.approve(address(staking), 100e18);
        staking.createPosition(user1, 100e18, 100e18, 0);

        // Fast forward to next epoch
        uint256 epochLength = rebaseController.EPOCH();
        vm.warp(block.timestamp + epochLength);

        // Get projected values
        (, uint256 epochMint, uint256 toStakers, uint256 toOps, uint256 toBurner) =
            rebaseController.projectedEpochRate();

        uint256 stakingBalanceBefore = app.balanceOf(address(staking));
        uint256 opsBalanceBefore = app.balanceOf(address(authority.operationsTreasury()));

        vm.expectEmit(true, true, true, true);
        emit Rebased(epochMint, toStakers, toOps, toBurner);
        rebaseController.executeEpoch();

        // Verify rewards were minted and sent to staking
        uint256 stakingBalance = app.balanceOf(address(staking));
        assertApproxEqRel(stakingBalance, toStakers + stakingBalanceBefore, 0.001e18);

        // Verify ops treasury received tokens
        uint256 opsBalance = app.balanceOf(address(authority.operationsTreasury()));
        assertApproxEqRel(opsBalance, toOps + opsBalanceBefore, 0.001e18);
    }

    function test_ExecuteEpochInsufficientReserves() public {
        // Mint RZR tokens to create supply
        app.mint(owner, 1_000_000e18);

        // Don't add any PCV to treasury

        // Fast forward to next epoch
        uint256 epochLength = rebaseController.EPOCH();
        vm.warp(block.timestamp + epochLength);

        // Execute epoch should succeed but not mint rewards
        (, uint256 epochMint, uint256 toStakers, uint256 toOps, uint256 toBurner) =
            rebaseController.projectedEpochRate();
        vm.expectEmit(true, true, true, true);
        emit Rebased(epochMint, toStakers, toOps, toBurner);

        rebaseController.executeEpoch();

        // Verify no rewards were minted
        uint256 stakingBalance = app.balanceOf(address(staking));
        assertEq(stakingBalance, 0);
    }

    function test_ProjectedEpochRateRaw() public view {
        // Test with zero supply
        (uint256 apr, uint256 epochMint, uint256 toStakers, uint256 toOps, uint256 toBurner) =
            rebaseController.projectedEpochRateRaw(1e18, 0, 0);
        assertEq(apr, 0);
        assertEq(epochMint, 0);
        assertEq(toStakers, 0);
        assertEq(toOps, 0);
        assertEq(toBurner, 0);

        // Test with 1:1 backing
        (apr, epochMint, toStakers, toOps, toBurner) = rebaseController.projectedEpochRateRaw(1e18, 1e18, 0);
        assertEq(apr, 0); // Below 100% backing
        assertEq(epochMint, 0);
        assertEq(toStakers, 0);
        assertEq(toOps, 0);
        assertEq(toBurner, 0);

        // Test with 1.5:1 backing
        (apr, epochMint, toStakers, toOps, toBurner) = rebaseController.projectedEpochRateRaw(3e18, 2e18, 1e18);
        assertEq(apr, 500); // Should have positive APR
        assertGt(epochMint, 0);
        assertGt(toStakers, 0);
        assertGt(toOps, 0);
        assertGt(toBurner, 0);

        // Test with 2:1 backing
        (apr, epochMint, toStakers, toOps, toBurner) = rebaseController.projectedEpochRateRaw(3e18, 1.5e18, 1e18);
        assertEq(apr, 1250); // Should have positive APR
        assertGt(epochMint, 0);
        assertGt(toStakers, 0);
        assertGt(toOps, 0);
        assertGt(toBurner, 0);

        // Test with 2.5:1 backing
        (apr, epochMint, toStakers, toOps, toBurner) = rebaseController.projectedEpochRateRaw(2.5e18, 1e18, 1e18);
        assertEq(apr, 2000); // Should be at CEIL_APR
        assertGt(epochMint, 0);
        assertGt(toStakers, 0);
        assertGt(toOps, 0);
        assertGt(toBurner, 0);
    }
}
