// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

interface IPoolLike {

    function manager() external view returns (address poolManager_);

}

interface IPoolManagerLike {

    function poolDelegate() external view returns (address poolDelegate_);

}
