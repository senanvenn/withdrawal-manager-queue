// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase } from "../utils/TestBase.sol";

contract ProcessRedemptionsTests is TestBase {

    uint256 assetsDeposited = 100e18;
    uint256 sharesLocked    = 250e18;

    function setUp() public override {
        super.setUp();

        asset.mint(address(pool), assetsDeposited);
        pool.mint(wm, sharesLocked);

        poolManager.__setTotalAssets(assetsDeposited);
        withdrawalManager.__setTotalShares(sharesLocked);
    }

    function test_processRedemptions_notRedeemer() external {
        vm.expectRevert("WM:NOT_REDEEMER");
        withdrawalManager.processRedemptions(sharesLocked);
    }

    function test_processRedemptions_zeroShares() external {
        vm.prank(poolDelegate);
        vm.expectRevert("WM:PR:ZERO_SHARES");
        withdrawalManager.processRedemptions(0);
    }

    function test_processRedemptions_lowShares() external {
        vm.prank(poolDelegate);
        vm.expectRevert("WM:PR:LOW_SHARES");
        withdrawalManager.processRedemptions(sharesLocked + 1);
    }

    function test_processRedemptions_lowLiquidity() external {
        asset.burn(address(pool), 1);

        vm.prank(poolDelegate);
        vm.expectRevert("WM:PR:LOW_LIQUIDITY");
        withdrawalManager.processRedemptions(sharesLocked);
    }

    function test_processRedemptions_poolDelegate() external {
        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(sharesLocked);

        assertEq(pool.balanceOf(wm), sharesLocked);

        assertQueue({ nextRequestId: 1, lastRequestId: 0 });
    }

    function test_processRedemptions_governor() external {
        vm.prank(governor);
        withdrawalManager.processRedemptions(sharesLocked);

        assertEq(pool.balanceOf(wm), sharesLocked);

        assertQueue({ nextRequestId: 1, lastRequestId: 0 });
    }

    function test_processRedemptions_operationalAdmin() external {
        vm.prank(operationalAdmin);
        withdrawalManager.processRedemptions(sharesLocked);

        assertEq(pool.balanceOf(wm), sharesLocked);

        assertQueue({ nextRequestId: 1, lastRequestId: 0 });
    }

    function test_processRedemptions_bot() external {
        globals.__setIsInstanceOf(true);

        vm.prank(redeemer);
        withdrawalManager.processRedemptions(sharesLocked);

        assertEq(pool.balanceOf(wm), sharesLocked);

        assertQueue({ nextRequestId: 1, lastRequestId: 0 });
    }

    function test_processRedemptions_manual_complete() external {
        withdrawalManager.__setManualWithdrawal(lp, true);
        withdrawalManager.__setRequest(1, lp, sharesLocked);
        withdrawalManager.__setQueue(1, 1);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(sharesLocked);

        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), sharesLocked);

        assertEq(withdrawalManager.totalShares(), sharesLocked);

        assertEq(withdrawalManager.requestIds(lp), 1);

        assertRequest({ requestId: 1, owner: lp, shares: sharesLocked });

        assertQueue({ nextRequestId: 2, lastRequestId: 1 });
    }

    function test_processRedemptions_manual_partial() external {
        withdrawalManager.__setManualWithdrawal(lp, true);
        withdrawalManager.__setRequest(1, lp, sharesLocked);
        withdrawalManager.__setQueue(1, 1);

        // Only half of the liquidity is available.
        asset.burn(address(pool), assetsDeposited / 2);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(sharesLocked / 2);

        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), sharesLocked);

        assertEq(withdrawalManager.totalShares(), sharesLocked);

        assertEq(withdrawalManager.requestIds(lp), 1);

        assertRequest({ requestId: 1, owner: lp, shares: sharesLocked });

        assertQueue({ nextRequestId: 1, lastRequestId: 1 });
    }

    function test_processRedemptions_automatic_complete() external {
        withdrawalManager.__setRequest(1, lp, sharesLocked);
        withdrawalManager.__setQueue(1, 1);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(sharesLocked);

        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(withdrawalManager.totalShares(), 0);

        assertEq(withdrawalManager.requestIds(lp), 0);

        assertRequest({ requestId: 1, owner: address(0), shares: 0 });

        assertQueue({ nextRequestId: 2, lastRequestId: 1 });
    }

    function test_processRedemptions_automatic_partial() external {
        withdrawalManager.__setRequest(1, lp, sharesLocked);
        withdrawalManager.__setQueue(1, 1);

        // Only half of the liquidity is available.
        asset.burn(address(pool), assetsDeposited / 2);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(sharesLocked / 2);

        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), sharesLocked / 2);

        assertEq(withdrawalManager.totalShares(), sharesLocked / 2);

        assertEq(withdrawalManager.requestIds(lp), 1);

        assertRequest({ requestId: 1, owner: lp, shares: sharesLocked / 2 });

        assertQueue({ nextRequestId: 1, lastRequestId: 1 });
    }

    function test_processRedemptions_multiple() external {
        address lp1 = makeAddr("lp1");
        address lp2 = makeAddr("lp2");

        withdrawalManager.__setRequest(1, lp1, 100e18);
        withdrawalManager.__setRequest(2, lp2, 150e18);
        withdrawalManager.__setQueue(1, 2);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(sharesLocked);

        assertEq(pool.balanceOf(wm),  0);
        assertEq(pool.balanceOf(lp1), 0);
        assertEq(pool.balanceOf(lp2), 0);

        assertEq(withdrawalManager.totalShares(), 0);

        assertEq(withdrawalManager.requestIds(lp1), 0);
        assertEq(withdrawalManager.requestIds(lp2), 0);

        assertRequest({ requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ requestId: 2, owner: address(0), shares: 0 });

        assertQueue({ nextRequestId: 3, lastRequestId: 2 });
    }

}
