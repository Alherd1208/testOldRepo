// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./libs/Ownable.sol";
import "./libs/IBEP20.sol";
import "./IPriceGetter.sol";
import "./IBaboon.sol";


contract PriceGetter is Ownable, IPriceGetter
{
    IBaboon public _targetToken;

    function setTargetToken(IBaboon baboonToken) public onlyOwner
    {
        _targetToken = baboonToken;
    }

    function convertToTarget(uint256 inAmount, address fromToken) public view override returns(uint256, bool)
    {
        PairInfo[] memory pairs = _targetToken.getPairs();
        uint256 averageValue = 0;
        uint8 pairCount = 0;
        for (uint32 i = 0; i < pairs.length; ++i)
        {
            if (pairs[i].otherAddress == fromToken)
            {
                (uint256 value, bool success) = convert(inAmount, fromToken, address(_targetToken), pairs[i].pairAddress);
                if (!success) continue;

                averageValue = (averageValue * pairCount + value) / (++pairCount);
            }
        }
        if (pairCount < 1) return (0, false);
        
        return (averageValue, true);
    }

    function convertFromTarget(uint256 inAmount, address toToken) public view override returns(uint256, bool)
    {
        PairInfo[] memory pairs = _targetToken.getPairs();
        uint256 averageValue = 0;
        uint8 pairCount = 0;
        for (uint32 i = 0; i < pairs.length; ++i)
        {
            if (pairs[i].otherAddress == toToken)
            {
                (uint256 value, bool success) = convert(inAmount, address(_targetToken), toToken, pairs[i].pairAddress);
                if (!success) continue;

                averageValue = (averageValue * pairCount + value) / (++pairCount);
            }
        }
        if (pairCount < 1) return (0, false);
        
        return (averageValue, true);       
    }

    // calculate price based on pair reserves
   function convert(uint256 inAmount, address fromToken, address toToken, address pairAddr) public view returns(uint256 outAmount, bool success)
   {
        try IBEP20(fromToken).balanceOf(pairAddr) returns (uint256 fromBalance)
        {
            try IBEP20(toToken).balanceOf(pairAddr) returns(uint256 toBalance)
            {
                require(fromBalance != 0 && toBalance != 0, "pool is empty");
                return (inAmount * toBalance * (10 ** IBEP20(fromToken).decimals()) / (fromBalance * (10 ** IBEP20(toToken).decimals())), true);
            }
            catch
            {
                return (0, false);
            }           
        }
        catch 
        {
            return (0, false);
        }
   }


    constructor(IBaboon baboonToken)
    {
        _targetToken = baboonToken;
    }
}