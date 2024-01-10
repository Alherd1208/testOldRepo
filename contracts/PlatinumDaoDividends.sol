// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./libs/IBEP20.sol";
import "./libs/Ownable.sol";

contract PlatinumDao is Ownable
{

    // todo: replace for all dao members and lunar bananas players
    function withdraw(address tokenAddress, uint256 amount) public onlyOwner
    {
        IBEP20(tokenAddress).transfer(owner(), amount);
    }

    function checkBalance(address tokenAddress) public view returns(uint256)
    {
        return IBEP20(tokenAddress).balanceOf(address(this));
    }


    constructor()
    {

    }
}