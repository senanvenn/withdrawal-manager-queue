// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

contract MapleWithdrawalManagerStorage {

    /**************************************************************************************************************************************/
    /*** Structs                                                                                                                        ***/
    /**************************************************************************************************************************************/

    struct WithdrawalRequest {
        address owner;
        uint256 shares;
    }

    struct Queue {
        uint128 nextRequestId;  // Identifier of the next request that will be processed.
        uint128 lastRequestId;  // Identifier of the last created request.
        mapping(uint128 => WithdrawalRequest) requests;  // Maps withdrawal requests to their positions in the queue.
    }

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    address public asset;
    address public globals;
    address public pool;
    address public poolManager;

    uint256 public totalShares;  // Total amount of shares pending redemption.

    Queue public queue;

    mapping(address => bool) public isManual;  // Defines which users use automated withdrawals (false by default).

    mapping(address => uint128) public requestIds;  // Maps users to their withdrawal requests identifiers.

}
