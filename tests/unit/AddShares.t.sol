// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { MapleWithdrawalManagerTestBase } from "../MapleWithdrawalManager.t.sol";

contract AddSharesTests is MapleWithdrawalManagerTestBase {

    function setUp() public override {
        super.setUp();

        // Simulate LP transfer into PM.
        pool.mint(pm, 2);

        vm.prank(pm);
        pool.approve(wm, 2);
    }

    function test_addShares_notPoolManager() external {
        vm.expectRevert("WM:NOT_PM");
        withdrawalManager.addShares(1, lp);
    }

    function test_addShares_emptyRequest() external {
        vm.prank(pm);
        vm.expectRevert("WM:AS:ZERO_SHARES");
        withdrawalManager.addShares(0, lp);
    }

    function test_addShares_alreadyInQueue() external {
        vm.prank(pm);
        withdrawalManager.addShares(1, lp);

        vm.prank(pm);
        vm.expectRevert("WM:AS:IN_QUEUE");
        withdrawalManager.addShares(1, lp);
    }

    function test_addShares_failedTransfer() external {
        vm.prank(pm);
        vm.expectRevert("WM:AS:FAILED_TRANSFER");
        withdrawalManager.addShares(3, lp);
    }

    function test_addShares_newRequestAddedToQueue() external {
        ( , uint128 lastRequestId ) = withdrawalManager.queue();

        assertEq(lastRequestId, 0);

        vm.prank(pm);
        withdrawalManager.addShares(1, lp);

        ( , lastRequestId ) = withdrawalManager.queue();

        assertEq(lastRequestId, 1);
    }

    function test_addShares_success() external {
        vm.prank(pm);
        withdrawalManager.addShares(1, lp);

        ( , uint128 lastRequestId ) = withdrawalManager.queue();

        assertEq(lastRequestId, 1);

        ( address owner_, uint256 shares_ ) = withdrawalManager.requests(lastRequestId);

        assertEq(shares_,                              1);
        assertEq(withdrawalManager.totalShares(),      1);
        assertEq(withdrawalManager.requestIds(owner_), lastRequestId);

        address lp2 = makeAddr("lp2");

        vm.prank(pm);
        withdrawalManager.addShares(1, lp2);

        ( , lastRequestId ) = withdrawalManager.queue();

        assertEq(lastRequestId, 2);

        ( owner_, shares_ ) = withdrawalManager.requests(lastRequestId);

        assertEq(shares_,                              1);
        assertEq(withdrawalManager.totalShares(),      2);
        assertEq(withdrawalManager.requestIds(owner_), lastRequestId);
    }

}
