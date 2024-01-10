// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;


import "./libs/BEP20.sol";
import "./libs/IBEP20.sol";
import "./libs/ABDK64x64.sol";
import "./libs/ABDKQuad.sol";

import "../pancakeSwap/IPancakeFactory.sol";
import "../pancakeSwap/IPancakePair.sol";
import "../pancakeSwap/IPancakeRouter02.sol";
import "../pancakeSwap/IWBNB.sol";

import "./IBaboon.sol";
import "./IBaboonRank.sol";


struct DividendReceiverInfo
{
    address addr;
     uint256 amount;
}

struct DAOMember
{
    address wallet;
    uint16 x100Percent;
}

struct WalletInfo
{
    uint256 balance;
    address addr;
    uint32 averageBuyDate;
    uint8 rank;
}



contract Baboon is BEP20, IBaboon
{
    //IUniswapV2Router02 public uniswapV2Router;
    //address public  uniswapV2Pair;

    address public _goldDaoSM; // silver DAO members dividends smart contract
    IBaboonRank public _rankSM; // BaboonRank contract

    PairInfo[] public _pairs; // pancakeSwap pairs (sushiSwap, uniswap, ...)
    mapping (address => bool) public _pairAddrMap;
   
    // pancakeSwap 
    // IPancakeRouter02 public pancakeSwapRouter;
    // IPancakeFactory public pancakeSwapFactory;
    // address public pancakeSwapPair;

    uint32 public _totalFee10000x;     // total fees   x 10000;
    uint32 public _lunarFee10000x;     // lunar fees   x 10000;
    uint32 public _martianFee10000x;   // martian fees x 10000;
    uint32 public _burnFee10000x;    // market fees  x 10000;
    uint32 public _daoFee10000x;       // dao fees     x 10000;

    uint256 public _lunarPool;          // current amount for lunar rewards;
    uint256 public _nextLunarPool;      // next amount for lunar rewards;
    uint256 public _martianPool;        // current amount for martian rewards;
    uint256 public _nextMartianPool;    // next amount ofr martian rewards;
    uint32 public _martianWinnersCount; // temporary var during DistributeRewards function;

    uint256 public _lastMartianTotalRewardAmount;  // last martian reward amount;
    uint256 public _lastMartianWinnersAmount;      // last martian winners count;

    uint256 public _gasLimit; // for distribute dividends function

    address _dead = address(0); // dead wallet

    mapping (address => bool) private _isExcludedFromFees;   // wallets excluded from fees
    mapping (address => bool) private _excludeFromDividends; // wallets excluded from dividends

    uint256 public _lunarRewardTime;          // next lunar reward time
    uint256 public _lunarPeriod =  3600; // 259200;     // lunar cicle period in seconds; 60 * 60 * 24 * 3
    uint8 public _lunarIndex = 0;

    uint256 public _priceCoef = 100000;

    mapping (address => uint32) public _averageBuyDate; // average buy date [in seconds] since 1970 01 01

    function getPairs() public view override returns(PairInfo[] memory) {return _pairs; }

    function debug_SetLunarPeriod(uint256 inLunarPeriod) public onlyOwner { _lunarPeriod = inLunarPeriod; }
    function renounceOwnership() public virtual override onlyOwner { require(false); }
    function setPriceCoef(uint256 inPriceCoef) public onlyOwner { _priceCoef = inPriceCoef; }

    function setBaboonRankSM(address rankSM) public onlyOwner
    {
        //require(address(_rankSM) == address(0), "can be triggered only once");
        _rankSM = IBaboonRank(rankSM);
    }

    // ToDo: delete function. set in constructor once and forever
    function setGoldDAOSM(address goldDaoSM) public onlyOwner
    {
        //require(address(_goldDAOSM) == address(0), "can be triggered only once");
        _goldDaoSM = goldDaoSM;
    }

    function addPair(address otherAddress, address pairAddress) public onlyOwner
    {
        require(!_pairAddrMap[pairAddress], "pair is already stored");

        _pairs.push(PairInfo(otherAddress, pairAddress));
        _pairAddrMap[pairAddress] = true;
    }

    function removePair(address otherAddress, address pairAddress) public onlyOwner
    {
        require(_pairs.length > 1, "can't remove last pair");
        for (uint256 i = 0; i < _pairs.length; ++i)
        {
            if (_pairs[i].otherAddress == otherAddress && _pairs[i].pairAddress == pairAddress)
            {
                _pairs[i] = _pairs[_pairs.length - 1];
                _pairs.pop();
                _pairAddrMap[pairAddress] = false;
                return;
            }
        }
    }

    // get wallets information
    function getWalletsInfo(address[] memory wallets) public view returns(WalletInfo[] memory outWalletsInfo)
    {
        require(address(_rankSM) != _dead, "rank contract not initialized !");
        outWalletsInfo = new WalletInfo[](wallets.length);
        for (uint32 i = 0; i < wallets.length; ++i)
        {
            outWalletsInfo[i] = WalletInfo(balanceOf(wallets[i]), wallets[i], getAverageBuyDate(wallets[i]), _rankSM.getRank(wallets[i]));
        }
    }

    // set new gas limit for distribute reward function
    function setGasLimit(uint256 gasLimit) public onlyOwner
    {
        _gasLimit = gasLimit;
    }

    // get average buy date [in seconds] since 1970 01 01
    function getAverageBuyDate(address addr) public view returns (uint32)
    {
        return _averageBuyDate[addr] == 0 ? uint32(block.timestamp) : _averageBuyDate[addr];
    }

    // set average buy date. use only during buy action !
    function setAverageBuyDateDuringBuyAction(address addr, uint256 addTokens) internal
    {
        uint40 ARB = _averageBuyDate[addr];
        uint256 curBalance = balanceOf(addr);
        uint32 curA = uint32(ARB);

        uint32 curTime = uint32(block.timestamp);
        if (curA == 0) curA = curTime;

        uint32 prevPower = curTime - curA;
        uint32 averagePower = uint32((curBalance * uint256(prevPower) + addTokens) / (curBalance + addTokens));
        _averageBuyDate[addr] = curTime - averagePower;
    }

    function isNextMartianReward() public view returns(bool result) { return _lunarIndex >= 9; }
    function getMartianRewardTime() public view returns(uint256 result) { return _lunarRewardTime + ((9 - _lunarIndex) * _lunarPeriod); }
    function getMartianPeriod() public view returns(uint256 result) {return _lunarPeriod * 10; }

    function startNewCycle() public onlyOwner
    {
        ++_lunarIndex;
        if (_lunarIndex >= 10)
        {
            _lastMartianTotalRewardAmount = _martianPool + _lunarPool;
            _lastMartianWinnersAmount = _martianWinnersCount;
            _martianWinnersCount = 0;

            _martianPool = _nextMartianPool * 9 / 10;
            _nextMartianPool -= _martianPool;
            _lunarIndex = 0;
        }

        _lunarRewardTime = block.timestamp + _lunarPeriod;
        _lunarPool = _nextLunarPool * 9 / 10;
        _nextLunarPool -= _lunarPool;
    }

    event onDistributeDividendsEvent(uint32 outNextFirstIndex, uint256 outGasUsed);

    function distributeDividends(DividendReceiverInfo[] memory DividendReceiverArr) public onlyOwner
    {
        uint256 gasLeft = gasleft();
        uint256 gasUsed = 0;

        uint32 curTime = uint32(block.timestamp);

        uint32 i = 0;
       if (!isNextMartianReward())
       {    
           while(gasUsed < _gasLimit && i < DividendReceiverArr.length)
            {
                _approve(address(this), DividendReceiverArr[i].addr, allowance(address(this), DividendReceiverArr[i].addr) + (DividendReceiverArr[i].amount));
                ++i;
                gasUsed += gasLeft - gasleft();
                gasLeft = gasleft();
            }
       }
       else
       {
           while(gasUsed < _gasLimit && i < DividendReceiverArr.length)
            {
                _approve(address(this), DividendReceiverArr[i].addr, allowance(address(this), DividendReceiverArr[i].addr) + (DividendReceiverArr[i].amount));
                             
                // apply Martian Halving
                uint32 averageBuyDate = _averageBuyDate[DividendReceiverArr[i].addr];
                uint32 nextPower = uint32(uint64(curTime - averageBuyDate) * 2718 / 10000);
                _averageBuyDate[DividendReceiverArr[i].addr] = curTime - nextPower;

                ++i;
                gasUsed += gasLeft - gasleft();
                gasLeft = gasleft();
            }     
            _martianWinnersCount += i;
       }

        emit onDistributeDividendsEvent(i, gasUsed);
    }

    function getPriceModifier(uint256 curTime) external view returns(uint256 coef)
    {
        uint256 minTime = _lunarRewardTime - _lunarPeriod;
        curTime = curTime > minTime ? curTime : minTime;
        uint256 lunarTimePast = _lunarRewardTime >= curTime ? _lunarPeriod - (_lunarRewardTime - curTime) : 0;
        uint256 lunarNRE = (lunarTimePast ** 2) * 1000000000 / (_lunarPeriod ** 2);

        uint256 martianPeriod = getMartianPeriod();
        uint256 martianRewardTime = getMartianRewardTime();
        uint256 martianTimePast = martianRewardTime >= curTime ? martianPeriod - (martianRewardTime - curTime) : 0;
        uint256 martianNRE = (martianTimePast ** 2) * 9000000000 / (martianPeriod ** 2);

        uint256 Nre = 1000000000 + lunarNRE + martianNRE;
        uint256 Result = (_lastMartianTotalRewardAmount / 10) / (_lastMartianWinnersAmount + 1);
        Result = Result < 1 ? 1 : Result;
        return Result * _priceCoef * Nre / 1000000000 / 100000;
    }

    function _transfer( address sender, address recipient, uint256 amount) internal override
    {
        uint256 receiveAmount = amount;

        if ((_pairAddrMap[sender] || _pairAddrMap[recipient]) &&
         !(_isExcludedFromFees[sender] || _isExcludedFromFees[recipient]))
        {
            // increase martian rewards
            uint256 burnAmount = amount * uint256(_burnFee10000x) / 10000;
            _burn(sender, burnAmount);

            // calculate fee amount
            uint256 fee_amount = amount * _totalFee10000x / 10000;
            // sub fee amount from transfer amount
            receiveAmount = amount - fee_amount;

            // increase lunar and martian rewards
            uint256 addLunarAmount = amount * uint256(_lunarFee10000x) / 10000;        
            uint256 addMartianAmount = amount * uint256(_martianFee10000x) / 10000;
            BEP20._transfer(sender, address(this), addLunarAmount + addMartianAmount);

            uint256 addCurrentLunarAmount = addLunarAmount * 9 / 10;
            _lunarPool += addCurrentLunarAmount;
            _nextLunarPool += addLunarAmount - addCurrentLunarAmount;

            uint256 addCurrentMartianAmount = addMartianAmount * 9 / 10;
            _martianPool += addCurrentMartianAmount;
            _nextMartianPool += addMartianAmount - addCurrentMartianAmount;

            // save market amount
            uint256 silverDAOAmount = amount * uint256(_daoFee10000x) / 10000;
            BEP20._transfer(sender, _goldDaoSM, silverDAOAmount);
        }

        BEP20._transfer(sender, recipient, receiveAmount);
        setAverageBuyDateDuringBuyAction(recipient, amount);
    }


    constructor(address goldDaoSM) BEP20()
    {
        _goldDaoSM = goldDaoSM;

        _lunarFee10000x = 248;     // 2.48 %
        _martianFee10000x = 152;   // 1.52 %
        _burnFee10000x = 50;       // 0.5  %
        _daoFee10000x = 50;        // 0.5  %
        _totalFee10000x = 500;     // 5.0  %

        // ToDo delete start
        // addPair(0x8a0029Fd6b58bc005eB265d3437b43ba84E560b7, 0x10ED43C718714eb63d5aA57B78B54704E256024E);
        // ToDo delete end

        _gasLimit = 300_000 wei;

        _lunarRewardTime = block.timestamp + _lunarPeriod;

        // IPancakeRouter02 _pancakeRouter = IPancakeRouter02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);
        // IPancakeFactory _pancakeFactory = IPancakeFactory(_pancakeRouter.factory());
        // address _pancakePair = IPancakeFactory(_pancakeRouter.factory()).createPair(address(this), _pancakeRouter.WETH());
        // pancakeSwapRouter = _pancakeRouter;
        // pancakeSwapFactory = _pancakeFactory;
        // pancakeSwapPair = _pancakePair;
        // _approve(address(this), address(pancakeSwapRouter), type(uint256).max);

        _lastMartianTotalRewardAmount = 7_500_000_000 * 10 ** 18;
        _lastMartianWinnersAmount = 700;
        
        _isExcludedFromFees[_dead] = true; // Zero Address
        _isExcludedFromFees[msg.sender] = true; // Owner Address
        _isExcludedFromFees[address(this)] = true; // Contract Address

        _excludeFromDividends[_dead] = true;
        _excludeFromDividends[msg.sender] = true;
        _excludeFromDividends[address(this)] = true;

        mint(30_000_000_000 ether);

        // transfer(0x9eBC0b5D50c394B307dA6906a7fAf6B7425c5153, 12_000_000_000 ether);
        // _approve(0x9eBC0b5D50c394B307dA6906a7fAf6B7425c5153, 
        // _msgSender(), type(uint256).max);

        // transferFrom(0x9eBC0b5D50c394B307dA6906a7fAf6B7425c5153,
        // 0xC9b67BA1BC527960f6A046Fe9E650250c0b63501, 1_000_000_000 ether); // to Andrew

        // transferFrom(0x9eBC0b5D50c394B307dA6906a7fAf6B7425c5153,
        // 0xDE4d7139A896878Be80e1E72a0135e8fc4dA1795, 1_100_000_000 ether); // to Ivan

        // transferFrom(0x9eBC0b5D50c394B307dA6906a7fAf6B7425c5153,
        // 0xf4Db1a85046315e74e6a0b4bADfd5025395D31bc, 1_200_000_000 ether);

        // transferFrom(0x9eBC0b5D50c394B307dA6906a7fAf6B7425c5153,
        // 0xC9b67BA1BC527960f6A046Fe9E650250c0b63501, 1_300_000_000 ether);

        // transferFrom(0x9eBC0b5D50c394B307dA6906a7fAf6B7425c5153,
        // 0x90D5C0b7456Fd07B3811669A5D5F13067E7335C8, 1_400_000_000 ether);

        // transferFrom(0x9eBC0b5D50c394B307dA6906a7fAf6B7425c5153,
        // 0x050F86a43f43A1B0923eA0130DFDc93295bb6B88, 1_500_000_000 ether);

        // transferFrom(0x9eBC0b5D50c394B307dA6906a7fAf6B7425c5153,
        // 0x658900F999cE0D57E5D25f89d3C7FACaB7941A6A, 100_000_000 ether);
        // transferFrom(0x9eBC0b5D50c394B307dA6906a7fAf6B7425c5153,
        // 0x8015FB8AB20fd09A660eEf06F930b4536100C2c7, 200_000_000 ether);

        // transferFrom(0x9eBC0b5D50c394B307dA6906a7fAf6B7425c5153,
        // 0x55773C0dB6Db62267A179c223de2216E3a58699C, 300_000_000 ether);
        // transferFrom(0x9eBC0b5D50c394B307dA6906a7fAf6B7425c5153,
        // 0x5CD4f18C1bD2D7FC778f504221de85f821e88DE7, 400_000_000 ether);
        // transferFrom(0x9eBC0b5D50c394B307dA6906a7fAf6B7425c5153,
        // 0xcc3953849Aa19040381439ac0366372Cda620887, 500_000_000 ether);
        // transferFrom(0x9eBC0b5D50c394B307dA6906a7fAf6B7425c5153,
        // 0x545399a748BF7E2BEfD45beADd143aA7B9b59cb5, 210_000_000 ether);

        // transferFrom(0x9eBC0b5D50c394B307dA6906a7fAf6B7425c5153,
        // 0x455E07b5898b0b41D57aa11A91FDB4235f885cd6, 220_000_000 ether);
        // transferFrom(0x9eBC0b5D50c394B307dA6906a7fAf6B7425c5153,
        // 0xc2252574BB8B9a2d1443462D4407C6aAbF74ED00, 230_000_000 ether);
        // transferFrom(0x9eBC0b5D50c394B307dA6906a7fAf6B7425c5153,
        // 0xe22E11ab784fBfe352f48b49B7947522D2327440, 240_000_000 ether);
        // transferFrom(0x9eBC0b5D50c394B307dA6906a7fAf6B7425c5153,
        // 0x5642fB39234B7Fbc127CDC3CD8bfd0Fb58ECcD80, 250_000_000 ether);
    }
}