// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

abstract contract AccessControlled {
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor() { owner = msg.sender; }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "owner=0");
        owner = newOwner;
    }
}
