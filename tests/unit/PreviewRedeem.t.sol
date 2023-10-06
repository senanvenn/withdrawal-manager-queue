// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase } from "../utils/TestBase.sol";

contract PreviewRedeemTests is TestBase {

    uint256 assetsDeposited = 100e18;
    uint256 sharesToRedeem  = 250e18;

    function setUp() public override {
        super.setUp();

        asset.mint(address(pool), assetsDeposited);
        pool.mint(wm, sharesToRedeem);

        poolManager.__setTotalAssets(assetsDeposited);
    }

    function test_previewRedeem_notManual() external {
        ( uint256 redeemableShares_, uint256 resultingAssets_ ) = withdrawalManager.previewRedeem(lp, sharesToRedeem);

        assertEq(redeemableShares_, 0);
        assertEq(resultingAssets_,  0);
    }

    function test_previewRedeem_noRequest() external {
        withdrawalManager.__setManualWithdrawal(lp, true);

        ( uint256 redeemableShares_, uint256 resultingAssets_ ) = withdrawalManager.previewRedeem(lp, sharesToRedeem);

        assertEq(redeemableShares_, 0);
        assertEq(resultingAssets_,  0);
    }

    function test_previewRedeem_notProcessed() external {
        withdrawalManager.__setManualWithdrawal(lp, true);
        withdrawalManager.__setRequest(1, lp, sharesToRedeem);

        ( uint256 redeemableShares_, uint256 resultingAssets_ ) = withdrawalManager.previewRedeem(lp, sharesToRedeem);

        assertEq(redeemableShares_, 0);
        assertEq(resultingAssets_,  0);
    }

    function test_previewRedeem_complete() external {
        withdrawalManager.__setManualWithdrawal(lp, true);
        withdrawalManager.__setRequest(1, lp, sharesToRedeem);
        withdrawalManager.__setQueue(2, 1);

        ( uint256 redeemableShares_, uint256 resultingAssets_ ) = withdrawalManager.previewRedeem(lp, sharesToRedeem);

        assertEq(redeemableShares_, sharesToRedeem);
        assertEq(resultingAssets_,  assetsDeposited);
    }

    function test_previewRedeem_partial() external {
        withdrawalManager.__setManualWithdrawal(lp, true);
        withdrawalManager.__setRequest(1, lp, sharesToRedeem);
        withdrawalManager.__setQueue(2, 1);

        // Only half of the liquidity is available.
        asset.burn(address(pool), assetsDeposited / 2);

        ( uint256 redeemableShares_, uint256 resultingAssets_ ) = withdrawalManager.previewRedeem(lp, sharesToRedeem);

        assertEq(redeemableShares_, sharesToRedeem / 2);
        assertEq(resultingAssets_,  assetsDeposited / 2);
    }

}
