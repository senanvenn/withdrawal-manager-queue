// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { ERC20Helper }           from "../modules/erc20-helper/src/ERC20Helper.sol";
import { IMapleProxyFactory }    from "../modules/maple-proxy-factory/contracts/interfaces/IMapleProxyFactory.sol";
import { MapleProxiedInternals } from "../modules/maple-proxy-factory/contracts/MapleProxiedInternals.sol";

import { IMapleWithdrawalManager } from "./interfaces/IMapleWithdrawalManager.sol";

import {
    IERC20Like,
    IGlobalsLike,
    IPoolLike,
    IPoolManagerLike
} from "./interfaces/Interfaces.sol";

import { MapleWithdrawalManagerStorage } from "./proxy/MapleWithdrawalManagerStorage.sol";

// TODO: Add interface (with events).
// TODO: Optimize struct if possible.
// TODO: Optimize storage loads of the struct.
// TODO: Add reentrancy checks.
// TODO: Check for a better way to clear storage for mapping

contract MapleWithdrawalManager is IMapleWithdrawalManager, MapleWithdrawalManagerStorage , MapleProxiedInternals {

    /**************************************************************************************************************************************/
    /*** Modifiers                                                                                                                      ***/
    /**************************************************************************************************************************************/

    modifier onlyRedeemer {
        address globals_ = globals();

        require(
            msg.sender == IPoolManagerLike(poolManager).poolDelegate() ||
            msg.sender == IGlobalsLike(globals_).governor() ||
            msg.sender == IGlobalsLike(globals_).operationalAdmin() ||
            IGlobalsLike(globals_).isInstanceOf("WITHDRAWAL_REDEEMER", msg.sender),
            "WM:NOT_REDEEMER"
        );

        _;
    }

    modifier onlyPoolManager {
        require(msg.sender == poolManager, "WM:NOT_PM");

        _;
    }

    modifier onlyPoolDelegate {
        require(msg.sender == poolDelegate(), "WM:NOT_PD");
        _;
    }

    /**************************************************************************************************************************************/
    /*** Proxy Functions                                                                                                                ***/
    /**************************************************************************************************************************************/

    function migrate(address migrator_, bytes calldata arguments_) external {
        require(msg.sender == _factory(),        "WM:M:NOT_FACTORY");
        require(_migrate(migrator_, arguments_), "WM:M:FAILED");
    }

    function setImplementation(address implementation_) external {
        require(msg.sender == _factory(), "WM:SI:NOT_FACTORY");
        _setImplementation(implementation_);
    }

    function upgrade(uint256 version_, bytes calldata arguments_) external {
        address poolDelegate_ = poolDelegate();

        require(msg.sender == poolDelegate_ || msg.sender == securityAdmin(), "WM:U:NOT_AUTHORIZED");

        IGlobalsLike mapleGlobals_ = IGlobalsLike(globals());

        if (msg.sender == poolDelegate_) {
            require(mapleGlobals_.isValidScheduledCall(msg.sender, address(this), "WM:UPGRADE", msg.data), "WM:U:INVALID_SCHED_CALL");

            mapleGlobals_.unscheduleCall(msg.sender, "WM:UPGRADE", msg.data);
        }

        IMapleProxyFactory(_factory()).upgradeInstance(version_, arguments_);
    }

    /**************************************************************************************************************************************/
    /*** State-Changing Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    function addShares(uint256 shares_, address owner_) external override onlyPoolManager {
        require(shares_ > 0,             "WM:AS:ZERO_SHARES");
        require(requestIds[owner_] == 0, "WM:AS:IN_QUEUE");

        uint128 lastRequestId_ = ++queue.lastRequestId;

        queue.requests[lastRequestId_] = WithdrawalRequest(owner_, shares_);

        requestIds[owner_] = lastRequestId_;

        // Increase the number of shares locked.
        totalShares += shares_;

        require(ERC20Helper.transferFrom(pool, msg.sender, address(this), shares_), "WM:AS:FAILED_TRANSFER");
    }

    function processExit(
        uint256 shares_,
        address owner_
    )
        external override onlyPoolManager returns (
            uint256 redeemableShares_,
            uint256 resultingAssets_
        )
    {
        ( redeemableShares_, resultingAssets_ ) = owner_ == address(this)
            ? _calculateRedemption(shares_)
            : _processManualExit(shares_, owner_);
    }

    function processRedemptions(uint256 sharesToProcess_) external override onlyRedeemer {
        require(sharesToProcess_ > 0, "WM:PR:ZERO_SHARES");

        ( uint256 redeemableShares_, ) = _calculateRedemption(sharesToProcess_);

        // Revert if there are insufficient shares to process.
        require(sharesToProcess_ <= totalShares, "WM:PR:LOW_SHARES");

        // Revert if there are insufficient assets to redeem all shares.
        require(sharesToProcess_ == redeemableShares_, "WM:PR:LOW_LIQUIDITY");

        uint128 nextRequestId_ = queue.nextRequestId;
        uint128 lastRequestId_ = queue.lastRequestId;

        // Iterate through the loop and process as many requests as possible.
        // Stop iterating when there are no more shares to process or if you have reached the end of the queue.
        while (sharesToProcess_ > 0 && nextRequestId_ <= lastRequestId_) {
            ( uint256 sharesProcessed_, bool isProcessed_ ) = _processRequest(nextRequestId_, sharesToProcess_);

            // If the request has not been processed keep it at the start of the queue.
            // This request will be next in line to be processed on the next call.
            if (!isProcessed_) break;

            sharesToProcess_ -= sharesProcessed_;

            ++nextRequestId_;
        }

        // Adjust the new start of the queue.
        queue.nextRequestId = nextRequestId_;
    }

    function removeShares(uint256 shares_, address owner_) external override onlyPoolManager returns (uint256 sharesReturned_) {
        require(shares_ > 0,            "WM:RS:ZERO_SHARES");
        require(requestIds[owner_] > 0, "WM:RS:NOT_IN_QUEUE");

        uint128 requestId_ = requestIds[owner_];

        uint256 currentShares_ = queue.requests[requestId_].shares;

        require(shares_ <= currentShares_, "WM:RS:DECREASE_SHARES_ONLY");

        uint256 sharesRemaining_ = currentShares_ - shares_;

        totalShares -= shares_;

        // If there are no shares remaining, cancel the withdrawal request.
        if (sharesRemaining_ == 0) {
            _cancelRequest(owner_, requestId_);
        } else {
            queue.requests[requestId_].shares = sharesRemaining_;
        }

        require(ERC20Helper.transfer(pool, owner_, shares_), "WM:RS:TRANSFER_FAIL");

        sharesReturned_ = shares_;
    }

    function removeRequest(address owner_) external override onlyPoolDelegate {
        require(requestIds[owner_] > 0, "WM:RR:NOT_IN_QUEUE");

        uint128 requestId_ = requestIds[owner_];

        uint256 shares_ = queue.requests[requestId_].shares;

        totalShares -= shares_;

        _cancelRequest(owner_, requestId_);

        require(ERC20Helper.transfer(pool, owner_, shares_), "WM:RR:TRANSFER_FAIL");
    }

    function setManualWithdrawal(address owner_, bool isManual_) external override onlyPoolDelegate {
        uint128 requestId_ = requestIds[owner_];

        // TODO: Check if this is required.
        require(requestId_ == 0, "WM:SMW:IN_QUEUE");

        isManual[owner_] = isManual_;
    }

    /**************************************************************************************************************************************/
    /*** Internal Functions                                                                                                             ***/
    /**************************************************************************************************************************************/

    function _cancelRequest(address owner_, uint128 requestId_) internal {
        delete requestIds[owner_];
        delete queue.requests[requestId_];
    }

    // TODO: Add fuzz tests to check the ER calculation.
    function _calculateRedemption(uint256 sharesToRedeem_) internal view returns (uint256 redeemableShares_, uint256 resultingAssets_) {
        IPoolManagerLike poolManager_ = IPoolManagerLike(poolManager);

        uint256 totalSupply_           = IPoolLike(pool).totalSupply();
        uint256 totalAssetsWithLosses_ = poolManager_.totalAssets() - poolManager_.unrealizedLosses();
        uint256 availableLiquidity_    = IERC20Like(asset()).balanceOf(pool);
        uint256 requiredLiquidity_     = totalAssetsWithLosses_ * sharesToRedeem_ / totalSupply_;

        bool partialLiquidity_ = availableLiquidity_ < requiredLiquidity_;

        redeemableShares_ = partialLiquidity_ ? sharesToRedeem_ * availableLiquidity_ / requiredLiquidity_ : sharesToRedeem_;
        resultingAssets_  = totalAssetsWithLosses_ * redeemableShares_  / totalSupply_;
    }

    // TODO: Optimize the request deletion.
    function _decreaseRequest(uint128 requestId_, address owner_, uint256 shares_) internal {
        // Update the withdrawal request.
        uint256 remainingShares_ = queue.requests[requestId_].shares -= shares_;

        // Adjust the total amount of shares locked.
        totalShares -= shares_;

        // Cancel the request if all shares have been redeemed.
        if (remainingShares_ == 0) {
            delete requestIds[owner_];
            delete queue.requests[requestId_];
        }
    }

    function _min(uint256 a_, uint256 b_) internal pure returns (uint256 min_) {
        min_ = a_ < b_ ? a_ : b_;
    }

    function _processManualExit(
        uint256 shares_,
        address owner_
    )
        internal returns (
            uint256 redeemableShares_,
            uint256 resultingAssets_
        )
    {
        // Only manual users can redeem.
        require(isManual[owner_], "WM:PE:NOT_MANUAL");

        uint128 requestId_ = requestIds[owner_];

        // Only users with an existing request can redeem.
        require(requestId_ != 0, "WM:PE:NO_REQUEST");

        // Only users who have a processed request can redeem.
        require(requestId_ < queue.nextRequestId, "WM:PE:NOT_PROCESSED");

        // The original `shares_` parameter is ignored.
        shares_ = queue.requests[requestId_].shares;

        ( redeemableShares_, resultingAssets_ ) = _calculateRedemption(shares_);

        _decreaseRequest(requestId_, owner_, redeemableShares_);

        require(ERC20Helper.transfer(pool, owner_, redeemableShares_), "WM:PE:TRANSFER_FAIL");
    }

    // TODO: Optimizations on automatic withdrawals (batch `redeem()` call if possible).
    function _processRequest(
        uint128 requestId_,
        uint256 maximumSharesToProcess_
    )
        internal returns (
            uint256 processedShares_,
            bool    isProcessed_
        )
    {
        WithdrawalRequest memory request_ = queue.requests[requestId_];

        // If the request has already been cancelled, skip it.
        if (request_.owner == address(0)) return (0, true);

        // Process only up to the maximum amount of shares.
        uint256 sharesToProcess_ = _min(request_.shares, maximumSharesToProcess_);

        // Calculate how many shares can actually be redeemed.
        ( processedShares_, ) = _calculateRedemption(sharesToProcess_);

        isProcessed_ = processedShares_ == request_.shares;

        if (!isManual[request_.owner]) {
            _decreaseRequest(requestId_, request_.owner, processedShares_);

            IPoolLike(pool).redeem(processedShares_, request_.owner, address(this));
        }
    }

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function asset() public view override returns (address asset_) {
        asset_ = IPoolLike(pool).asset();
    }

    function factory() external view override returns (address factory_) {
        factory_ = _factory();
    }

    function globals() public view override returns (address globals_) {
        globals_ = IMapleProxyFactory(_factory()).mapleGlobals();
    }

    function governor() public view override returns (address governor_) {
        governor_ = IGlobalsLike(globals()).governor();
    }

    function implementation() external view override returns (address implementation_) {
        implementation_ = _implementation();
    }

    function poolDelegate() public view override returns (address poolDelegate_) {
        poolDelegate_ = IPoolManagerLike(poolManager).poolDelegate();
    }

    function previewRedeem(
        address owner_,
        uint256 shares_
    )
        public view override returns (
            uint256 redeemableShares_,
            uint256 resultingAssets_
        )
    {
        uint128 requestId_ = requestIds[owner_];

        // Only manual users can call redeem.
        if (!isManual[owner_]) return ( 0, 0 );

        // Only users with a pending request can call redeem.
        if (requestId_ == 0) return ( 0, 0 );

        // Only users who have had their request processed can redeem.
        if (requestId_ >= queue.nextRequestId) return (0, 0);

        WithdrawalRequest memory request_ = queue.requests[requestId_];

        // The original `shares_` parameter is ignored.
        shares_ = request_.shares;

        ( redeemableShares_, resultingAssets_ ) = _calculateRedemption(shares_);
    }

    function requests(uint128 requestId_) external view override returns (address owner_, uint256 shares_) {
        owner_  = queue.requests[requestId_].owner;
        shares_ = queue.requests[requestId_].shares;
    }

    function securityAdmin() public view override returns (address securityAdmin_) {
        securityAdmin_ = IGlobalsLike(globals()).securityAdmin();
    }

}
