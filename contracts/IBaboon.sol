// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import "./libs/IBEP20.sol";

struct PairInfo
{
    address otherAddress;
    address pairAddress;
}

interface IBaboon
{
    function getPriceModifier(uint256 curTime) external view returns(uint256 coef);
    function getPairs() external view returns(PairInfo[] memory pairs);
}
