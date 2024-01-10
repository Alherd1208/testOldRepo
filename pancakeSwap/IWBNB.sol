// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.17;

interface IWBNB {
    function deposit() external payable;

    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;
}
