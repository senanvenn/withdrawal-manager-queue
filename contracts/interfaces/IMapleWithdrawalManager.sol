// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

interface IMapleWithdrawalManager {

    /**************************************************************************************************************************************/
    /*** Events                                                                                                                         ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Emitted when a manual redemption takes place.
     *  @param owner           Address of the account.
     *  @param sharesDecreased Amount of shares redeemed.
     */
    event ManualSharesDecreased(address indexed owner, uint256 sharesDecreased);

    /**
     *  @dev   Emitted when a manual redemption is processed.
     *  @param owner       Address of the account.
     *  @param sharesAdded Amount of shares added to the redeemable amount.
     */
    event ManualSharesIncreased(address indexed owner, uint256 sharesAdded);

    /**
     *  @dev   Emitted when the withdrawal type of an account is updated.
     *  @param owner     Address of the account.
     *  @param isManual `true` if the withdrawal is manual, `false` if it is automatic.
     */
    event ManualWithdrawalSet(address indexed owner, bool isManual);

    /**
     *  @dev   Emitted when a withdrawal request is created.
     *  @param requestId Identifier of the withdrawal request.
     *  @param owner     Address of the owner of the shares.
     *  @param shares    Amount of shares requested for redemption.
     */
    event RequestCreated(uint128 indexed requestId, address owner, uint256 shares);

    /**
     *  @dev   Emitted when a withdrawal request is updated.
     *  @param requestId Identifier of the withdrawal request.
     *  @param shares    Amount of shares reduced during a redemption request.
     */
    event RequestDecreased(uint128 indexed requestId, uint256 shares);

    /**
     *  @dev   Emitted when a withdrawal request is processed.
     *  @param requestId Identifier of the withdrawal request.
     *  @param owner     The owner of the shares.
     *  @param shares    Amount of redeemable shares.
     *  @param assets    Amount of withdrawable assets.
     */
    event RequestProcessed(uint128 indexed requestId, address indexed owner, uint256 shares, uint256 assets);

    /**
     *  @dev   Emitted when a withdrawal request is removed.
     *  @param requestId Identifier of the withdrawal request.
     */
    event RequestRemoved(uint128 indexed requestId);

    /**************************************************************************************************************************************/
    /*** State-Changing Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Add shares to the withdrawal manager.
     *  @param shares Amount of shares to add.
     *  @param owner  Address of the owner of shares.
     */
    function addShares(uint256 shares, address owner) external;

    /**
     *  @dev    Processes a withdrawal request.
     *          Uses the current exchange rate to calculate the amount of assets withdrawn.
     *          NOTE: The `shares` value is ignored.
     *  @param  shares           Amount of shares that should be redeemed.
     *  @param  owner            Address of the account to process.
     *  @return redeemableShares Amount of shares that will be burned.
     *  @return resultingAssets  Amount of assets that will be withdrawn.
     */
    function processExit(uint256 shares, address owner) external returns (uint256 redeemableShares, uint256 resultingAssets);

    /**
     *  @dev   Processes pending redemption requests.
     *         Requests are processed in the order they were submitted.
     *         Automatic withdrawal requests will be fulfilled atomically.
     *  @param sharesToProcess Maximum number of shares that will be processed during the call.
     */
    function processRedemptions(uint256 sharesToProcess) external;

    /**
     *  @dev    Removes shares from the withdrawal manager.
     *  @param  shares         Amount of shares to remove.
     *  @param  owner          Address of the owner of shares.
     *  @return sharesReturned Amount of shares that were returned.
     */
    function removeShares(uint256 shares, address owner) external returns (uint256 sharesReturned);

    /**
     *  @dev   Removes a withdrawal request from the queue.
     *         Can only be called by the pool delegate.
     *  @param owner Address of the owner of shares.
     */
    function removeRequest(address owner) external;

    /**
     *  @dev   Defines if an account will withdraw shares manually or automatically.
     *  @param account  Address of the account.
     *  @param isManual `true` if the account withdraws manually, `false` if the withdrawals are performed automatically.
     */
    function setManualWithdrawal(address account, bool isManual) external;

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Returns the address of the underlying pool asset.
     *  @param asset Address of the underlying pool asset.
     */
    function asset() external view returns (address asset);

    /**
     *  @dev   Return the address of the factory contract.
     *  @param factory Address of the factory contract.
     */
    function factory() external view returns (address factory);

    /**
     *  @dev   Returns the address of the globals contract.
     *  @param globals Address of the globals contract.
     */
    function globals() external view returns (address globals);

    /**
     *  @dev   Return the address of the governor.
     *  @param governor Address of the governor contract.
     */
    function governor() external view returns (address governor);

    /**
     *  @dev   Returns the address of the implementation contract.
     *  @param implementation Address of the implementation contract.
     */
    function implementation() external view returns (address implementation);

    /**
     *  @dev   Returns the address of the pool delegate.
     *  @param poolDelegate Address of the pool delegate.
     */
    function poolDelegate() external view returns (address poolDelegate);

    /**
     *  @dev    Returns the amount of shares that can be redeemed.
     *          NOTE: The `shares` value is ignored.
     *  @param  owner            Address of the share owner
     *  @param  shares           Amount of shares to redeem.
     *  @return redeemableShares Amount of shares that can be redeemed.
     *  @return resultingAssets  Amount of assets that can be withdrawn.
     */
    function previewRedeem(address owner, uint256 shares) external view returns (uint256 redeemableShares, uint256 resultingAssets);

    /**
     *  @dev    Returns the owner and amount of shares associated with a withdrawal request.
     *  @param  requestId Identifier of the withdrawal request.
     *  @return owner     Address of the share owner.
     *  @return shares    Amount of shares pending redemption.
     */
    function requests(uint128 requestId) external view returns (address owner, uint256 shares);

    /**
     *  @dev   Returns the address of the security admin.
     *  @param securityAdmin Address of the security admin.
     */
    function securityAdmin() external view returns (address securityAdmin);

}
