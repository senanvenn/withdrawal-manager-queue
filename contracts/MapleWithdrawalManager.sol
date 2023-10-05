// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";

import { IPoolLike, IPoolManagerLike } from "./interfaces/Interfaces.sol";

import { MapleWithdrawalManagerStorage } from "./MapleWithdrawalManagerStorage.sol";

// TODO: Add interface (with events).
// TODO: Optimize struct if possible.
// TODO: Optimize storage loads of the struct.
// TODO: Replace constructor with the usual proxy functions and initializer.
// TODO: Add reentrancy checks.
// TODO: Check for a better way to clear storage for mapping

contract MapleWithdrawalManager is MapleWithdrawalManagerStorage {

    /**************************************************************************************************************************************/
    /*** Modifiers                                                                                                                      ***/
    /**************************************************************************************************************************************/

    modifier onlyPoolManager {
        require(msg.sender == poolManager, "WM:NOT_PM");
        _;
    }

    modifier onlyPoolDelegate {
        require(msg.sender == IPoolManagerLike(poolManager).poolDelegate(), "WM:NOT_PD");
        _;
    }

    /**************************************************************************************************************************************/
    /*** Initialization                                                                                                                 ***/
    /**************************************************************************************************************************************/

    constructor(address pool_) {
        pool        = pool_;
        poolManager = IPoolLike(pool_).manager();

        queue.nextRequestId = 1;  // Initialize queue with index 1
    }

    /**************************************************************************************************************************************/
    /*** State-Changing Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    function addShares(uint256 shares_, address owner_) external onlyPoolManager {
        require(shares_ > 0,             "WM:AS:ZERO_SHARES");
        require(requestIds[owner_] == 0, "WM:AS:IN_QUEUE");

        uint128 lastRequestId_ = ++queue.lastRequestId;

        queue.requests[lastRequestId_] = WithdrawalRequest(owner_, shares_);

        requestIds[owner_] = lastRequestId_;

        // Increase the number of shares locked.
        totalShares += shares_;

        require(ERC20Helper.transferFrom(pool, msg.sender, address(this), shares_), "WM:AS:FAILED_TRANSFER");
    }

    function removeShares(uint256 shares_, address owner_) external onlyPoolManager returns (uint256 sharesReturned_) {
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

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function requests(uint128 requestId_) external view returns (address owner_, uint256 shares_) {
        owner_  = queue.requests[requestId_].owner;
        shares_ = queue.requests[requestId_].shares;
    }

    /**************************************************************************************************************************************/
    /*** Internal Functions                                                                                                             ***/
    /**************************************************************************************************************************************/

    function _cancelRequest(address owner_, uint128 requestId_) internal {
        delete requestIds[owner_];
        delete queue.requests[requestId_];
    }

}
