// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Test }      from "../modules/forge-std/src/Test.sol";
import { MockERC20 } from "../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { MapleWithdrawalManager } from "../contracts/MapleWithdrawalManager.sol";

import { MockGlobals, MockPool, MockPoolManager } from "./utils/Mocks.sol";

contract MapleWithdrawalManagerTestBase is Test {

    address internal governor     = makeAddr("governor");
    address internal lp           = makeAddr("lp");
    address internal poolDelegate = makeAddr("poolDelegate");

    address internal pm;
    address internal wm;

    MockERC20       internal asset;
    MockGlobals     internal globals;
    MockPool        internal pool;
    MockPoolManager internal poolManager;

    MapleWithdrawalManager internal withdrawalManager;

    function setUp() public virtual {
        // Create all mocks.
        asset       = new MockERC20("Wrapped Ether", "WETH", 18);
        globals     = new MockGlobals(address(governor));
        pool        = new MockPool("Maple Pool", "MP-WETH", 18, address(asset), poolDelegate);
        poolManager = new MockPoolManager(address(pool), poolDelegate, address(globals));

        pool.__setPoolManager(address(poolManager));

        withdrawalManager = new MapleWithdrawalManager(address(pool));

        wm = address(withdrawalManager);
        pm = address(poolManager);
    }

}
