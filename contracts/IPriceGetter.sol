// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import "./libs/IBEP20.sol";

interface IPriceGetter
{
    function convertToTarget(uint256 inAmount, address fromToken) external view returns(uint256, bool);
    function convertFromTarget(uint256 inAmount, address toToken) external view returns(uint256, bool);
}
