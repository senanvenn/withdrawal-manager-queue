// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { MockERC20 } from "../../modules/erc20/contracts/test/mocks/MockERC20.sol";

contract MockGlobals {

    address public governor;
    address public operationalAdmin;

    bool internal _isInstance;
    bool internal _isValidScheduledCall;

    bool public protocolPaused;

    mapping(address => bool) public isPoolDeployer;

    constructor (address governor_) {
        governor = governor_;
    }

    function isInstanceOf(bytes32, address) external view returns (bool isInstance_) {
        isInstance_ = _isInstance;
    }

    function __setIsInstanceOf(bool isInstance_) external {
        _isInstance = isInstance_;
    }

    function __setOperationalAdmin(address operationalAdmin_) external {
        operationalAdmin = operationalAdmin_;
    }

}

contract MockPool is MockERC20 {

    address public manager;
    address public poolDelegate;

    uint256 public sharePrice;

    MockERC20 _asset;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address asset_,
        address poolDelegate_
    )
        MockERC20(name_, symbol_, decimals_)
    {
        _asset = MockERC20(asset_);

        poolDelegate = poolDelegate_;
        sharePrice   = 1;
    }

    function asset() external view returns (address asset_) {
        asset_ = address(_asset);
    }

    // TODO: Remove burn and spy on call parameters in tests.
    function redeem(uint256 shares_, address receiver_, address owner_) external returns (uint256 assets_) {
        _burn(owner_, shares_);
    }

    function __setPoolManager(address poolManager_) external {
        manager = poolManager_;
    }

}

contract MockPoolManager {

    address public globals;
    address public pool;
    address public poolDelegate;

    uint256 public totalAssets;
    uint256 public unrealizedLosses;

    constructor(address pool_, address poolDelegate_, address globals_) {
        globals      = globals_;
        pool         = pool_;
        poolDelegate = poolDelegate_;
    }

    function __setTotalAssets(uint256 totalAssets_) external  {
        totalAssets = totalAssets_;
    }

}
