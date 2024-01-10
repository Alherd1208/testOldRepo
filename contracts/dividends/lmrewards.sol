// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract LMRewards
{
    uint256 _lPool = 0;
    uint256 _nextLPool = 0;    

    uint256 _mPool = 0;
    uint256 _nextMPool = 0;

    uint16 _lPart = 162;
    uint16 _mPart = 262;

    function totalRewards() external view returns(uint256)
    {
        return _lPool + _mPool + _nextLPool + _nextMPool;
    }

    function addRewards(uint256 addTotal) external
    {
        _nextMPool += addTotal * 10 / _mPart;
        _nextLPool += addTotal * 10 / _lPart;
        _mPool += addTotal * 90 / _mPart;
        _lPool += addTotal * 90 / _lPart;
    }

//     function startNewCycle() external
//     {
//         ++_lunarIndex;
//         if (_lunarIndex >= 10)
//         {
//             _lastMartianTotalRewardAmount = _martianPool + _lunarPool;
//             _lastMartianWinnersAmount = _martianWinnersCount;
//             _martianWinnersCount = 0;

//             _martianPool = _nextMartianPool * 9 / 10;
//             _nextMartianPool -= _martianPool;
//             _lunarIndex = 0;
//         }

//         _lunarRewardTime = block.timestamp + _lunarPeriod;
//         _lunarPool = _nextLunarPool * 9 / 10;
//         _nextLunarPool -= _lunarPool;
//     }

//    event onDistributeDividendsEvent(uint32 outNextFirstIndex, uint256 outGasUsed);

//     function distributeDividends(DividendReceiverInfo[] memory DividendReceiverArr) public onlyOwner
//     {
//         uint256 gasLeft = gasleft();
//         uint256 gasUsed = 0;

//         uint32 curTime = uint32(block.timestamp);

//         uint32 i = 0;
//        if (!isNextMartianReward())
//        {    
//            while(gasUsed < _gasLimit && i < DividendReceiverArr.length)
//             {
//                 _approve(address(this), DividendReceiverArr[i].addr, allowance(address(this), DividendReceiverArr[i].addr) + (DividendReceiverArr[i].amount));
//                 ++i;
//                 gasUsed += gasLeft - gasleft();
//                 gasLeft = gasleft();
//             }
//        }
//        else
//        {
//            while(gasUsed < _gasLimit && i < DividendReceiverArr.length)
//             {
//                 _approve(address(this), DividendReceiverArr[i].addr, allowance(address(this), DividendReceiverArr[i].addr) + (DividendReceiverArr[i].amount));
                             
//                 // apply Martian Halving
//                 uint32 averageBuyDate = _averageBuyDate[DividendReceiverArr[i].addr];
//                 uint32 nextPower = uint32(uint64(curTime - averageBuyDate) * 2718 / 10000);
//                 _averageBuyDate[DividendReceiverArr[i].addr] = curTime - nextPower;

//                 ++i;
//                 gasUsed += gasLeft - gasleft();
//                 gasLeft = gasleft();
//             }     
//             _martianWinnersCount += i;
//        }

//         emit onDistributeDividendsEvent(i, gasUsed);
//     }
}