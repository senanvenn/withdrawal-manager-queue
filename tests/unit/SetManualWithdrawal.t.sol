// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase } from "../utils/TestBase.sol";

contract SetManualWithdrawalTests is TestBase {

    function test_setManualWithdrawal_notPoolDelegate() external {
        vm.expectRevert("WM:NOT_PD");
        withdrawalManager.setManualWithdrawal(lp, true);
    }

    function test_setManualWithdrawal_existingRequest() external {
        withdrawalManager.__setRequest(1, lp, 100e18);

        vm.prank(poolDelegate);
        vm.expectRevert("WM:SMW:IN_QUEUE");
        withdrawalManager.setManualWithdrawal(lp, true);
    }

    function test_setManualWithdrawal_success() external {
        assertEq(withdrawalManager.isManual(lp), false);

        vm.prank(poolDelegate);
        withdrawalManager.setManualWithdrawal(lp, true);

        assertEq(withdrawalManager.isManual(lp), true);
    }

}