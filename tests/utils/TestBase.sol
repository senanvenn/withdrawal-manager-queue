// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { Test }      from "../../modules/forge-std/src/Test.sol";
import { MockERC20 } from "../../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { MapleWithdrawalManager } from "../../contracts/MapleWithdrawalManager.sol";

import { MapleWithdrawalManagerHarness }          from "./Harnesses.sol";
import { MockGlobals, MockPool, MockPoolManager } from "./Mocks.sol";

contract TestBase is Test {

    address governor         = makeAddr("governor");
    address lp               = makeAddr("lp");
    address operationalAdmin = makeAddr("operationalAdmin");
    address poolDelegate     = makeAddr("poolDelegate");
    address redeemer         = makeAddr("redeemer");

    address pm;
    address wm;

    MockERC20       asset;
    MockGlobals     globals;
    MockPool        pool;
    MockPoolManager poolManager;

    MapleWithdrawalManagerHarness internal withdrawalManager;

    function setUp() public virtual {
        // Create all mocks.
        asset       = new MockERC20("Wrapped Ether", "WETH", 18);
        globals     = new MockGlobals(address(governor));
        pool        = new MockPool("Maple Pool", "MP-WETH", 18, address(asset), poolDelegate);
        poolManager = new MockPoolManager(address(pool), poolDelegate, address(globals));

        globals.__setOperationalAdmin(operationalAdmin);
        pool.__setPoolManager(address(poolManager));

        withdrawalManager = new MapleWithdrawalManagerHarness(address(pool), address(globals));

        wm = address(withdrawalManager);
        pm = address(poolManager);
    }

    function assertRequest(uint128 requestId, address owner, uint256 shares) internal {
        ( address owner_, uint256 shares_ ) = withdrawalManager.requests(requestId);

        assertEq(owner_,  owner);
        assertEq(shares_, shares);
    }

    function assertQueue(uint128 nextRequestId, uint128 lastRequestId) internal {
        ( uint128 nextRequestId_, uint128 lastRequestId_ ) = withdrawalManager.queue();

        assertEq(nextRequestId_, nextRequestId);
        assertEq(lastRequestId_, lastRequestId);
    }

}
