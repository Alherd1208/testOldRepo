// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../libs/Ownable.sol";
import "../libs/IBEP20.sol";
import "../../pancakeSwap/IPancakeRouter02.sol";

struct investor
{
    address addr;
    uint256 investmentsUSDT;
}



struct token
{
    address addr;
    uint256 balance;
}

struct info
{
    uint256 curTotalInvestmentsUSDT;
    uint256 maxTotalInvestmentsUSDT;
    uint256 curInvestmentsPerWalletUSDT;
    uint256 maxInvestmentsPerWalletUSDT;
    token[] balances;
    address[] acceptableTokens;
}

contract SeedRound is Ownable
{
    mapping (address => uint32) _investorsMap;
    investor[] _investors;

    uint256 _totalInvestmentsUSDT = 0;

    uint256 _maxTotalInvestmentsUSDT = 100 ether;
    uint256 _maxInvestmentsPerWalletUSDT = 10 ether;
    uint256 _tolerance = 101;
    uint256 _tolerancePerWallet = 105;

    function getInfo() external view returns(info memory outValue)
    {
        uint32 index = _investorsMap[msg.sender];
        require(index != 0, "you are not in wl !");
        outValue.curTotalInvestmentsUSDT = _totalInvestmentsUSDT;
        outValue.maxTotalInvestmentsUSDT = _maxTotalInvestmentsUSDT;
        outValue.curInvestmentsPerWalletUSDT = _investors[index].investmentsUSDT;
        outValue.maxInvestmentsPerWalletUSDT = _maxInvestmentsPerWalletUSDT;
        outValue.balances = getAllTokenBalances(msg.sender);
        outValue.acceptableTokens = getAllAcceptableTokens();
    }

    function getAllInvestors() external view onlyOwner returns(investor[] memory outValue)
    {
        outValue = _investors;
    }

    function getAllAcceptableTokens() public view returns(address[] memory outTokens)
    {
        outTokens = _acceptableTokenArr;
    }

    mapping (address => uint32) _acceptableTokens;
    address[] _acceptableTokenArr;

    address public _wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public _usdt = 0x55d398326f99059fF775485246999027B3197955;
    IPancakeRouter02 public _router = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    function setTolerance(uint256 inTolerance) external onlyOwner
    {
        require(inTolerance > 100 && inTolerance < 150, "invalid tolerance");
        _tolerance = inTolerance;
    }

    function setTolerancePerWallet(uint256 inTolerance) external onlyOwner
    {
        require(inTolerance > 100 && inTolerance < 150, "invalid tolerance");
        _tolerancePerWallet = inTolerance;
    }



    function investCoin() payable external
    {
        uint32 index = _investorsMap[msg.sender];
        require(index != 0, "you are not in WL !");
        uint256 outValue = getAmountInUSDT(_wbnb, msg.value);
        require(_totalInvestmentsUSDT + outValue <= _maxTotalInvestmentsUSDT * _tolerance / 100, "investment exeeded max total value");
        require(_investors[index].investmentsUSDT + outValue <= _maxInvestmentsPerWalletUSDT * _tolerancePerWallet / 100, "investment exceeded max value per wallet");
        _investors[index].investmentsUSDT += outValue;
        _totalInvestmentsUSDT += outValue;
    }

    function getAmountInUSDT(address inTokenAddr, uint256 inAmount) public view returns(uint256)
    {
        if (inTokenAddr == _usdt) return inAmount;

        address[] memory path = new address[](2);
        path[0] = inTokenAddr;
        path[1] = _usdt;
        uint256[] memory amounts = _router.getAmountsOut(inAmount, path);
        return amounts[1];
    }

    function investTokenFrom(address inAddr, address inTokenAddr, uint256 inValue) external onlyOwner
    {
        require(_acceptableTokens[inTokenAddr] != 0, "this token is not acceptable for investments");
        uint32 index = _investorsMap[inAddr];
        require(index != 0, "you are not in WL !");
        uint256 outValue = getAmountInUSDT(inTokenAddr, inValue);
        require(_totalInvestmentsUSDT + outValue <= _maxTotalInvestmentsUSDT * _tolerance / 100, "investment exceeded max total value");
        require(_investors[index].investmentsUSDT + outValue <= _maxInvestmentsPerWalletUSDT * _tolerancePerWallet / 100, "investment exceeded max value per wallet");
        IBEP20(inTokenAddr).transferFrom(inAddr, address(this), inValue);
        _investors[index].investmentsUSDT += outValue;
        _totalInvestmentsUSDT += outValue;   
    }

    function investToken(address inTokenAddr, uint256 inValue) external
    {
        require(_acceptableTokens[inTokenAddr] != 0, "this token is not acceptable for investments");
        uint32 index = _investorsMap[msg.sender];
        require(index != 0, "you are not in WL !");
        uint256 outValue = getAmountInUSDT(inTokenAddr, inValue);
        require(_totalInvestmentsUSDT + outValue <= _maxTotalInvestmentsUSDT * _tolerance / 100, "investment exceeded max total value");
        require(_investors[index].investmentsUSDT + outValue <= _maxInvestmentsPerWalletUSDT * _tolerancePerWallet / 100, "investment exceeded max value per wallet");
        IBEP20(inTokenAddr).transferFrom(msg.sender, address(this), inValue);
        _investors[index].investmentsUSDT += outValue;
        _totalInvestmentsUSDT += outValue; 
    }

    function addToWL(address inAddr) external onlyOwner
    {
        _investors.push() = investor(inAddr, 0);
        _investorsMap[inAddr] = uint32(_investors.length - 1);
    }

    function removeFromWL(address inAddr) external onlyOwner
    {
        require(_investors.length > 1, "can't delete last investor");
        uint32 index = _investorsMap[inAddr];
        require(index != 0, "there is no such investor");
        _investors[index] = _investors[_investors.length - 1];
        _investors.pop();
        _investorsMap[inAddr] = 0;
    }

    function addInvestmentsToken(address inAddr) external onlyOwner
    {
        require(_acceptableTokens[inAddr] == 0, "token is already in the list");
        _acceptableTokenArr.push(inAddr);
        _acceptableTokens[inAddr] = uint32(_acceptableTokenArr.length - 1);

    }

    function removeInvestmentsToken(address inAddr) external onlyOwner
    {
        require(_acceptableTokenArr.length > 1, "can't delete last token");
        require(_acceptableTokens[inAddr] != 0, "no such token in the list");
        uint32 index = _acceptableTokens[inAddr];
        _acceptableTokenArr[index] = _acceptableTokenArr[_acceptableTokenArr.length - 1];
        _acceptableTokens[inAddr] = 0;
        _acceptableTokens[_acceptableTokenArr[index]] = index;
        _acceptableTokenArr.pop();
    }

    function getCoinBalance() external view returns(uint256)
    {
        return address(this).balance;
    }

    function withdrawCoin() external onlyOwner
    {
        (bool success,) = owner().call{value:address(this).balance}("");
        require(success, "withdraw failed");
    }

    function withdrawToken(address inTokenAddr) external onlyOwner
    {
        uint256 balance = IBEP20(inTokenAddr).balanceOf(address(this));
        require(balance > 0, "smart contract has zero balance of this token");
        IBEP20(inTokenAddr).transfer(owner(), balance);
    }

    function getTokenBalance(address inTokenAddr) public view returns(uint256)
    {
        return IBEP20(inTokenAddr).balanceOf(address(this));
    }

    function getAllTokenBalances(address addr) public view returns(token[] memory)
    {
        token[] memory lbalances = new token[](_acceptableTokenArr.length);
        for (uint32 i = 0; i < _acceptableTokenArr.length; ++i)
        {
            if (_acceptableTokenArr[i] == address(0)) continue;
            lbalances[i] = token(_acceptableTokenArr[i], IBEP20(_acceptableTokenArr[i]).balanceOf(addr));
        }
        return lbalances;
    }

    function setWBNB(address inAddr) external onlyOwner
    {
        _wbnb = inAddr;
    }

    function setUSDT(address inAddr) external onlyOwner
    {
        _usdt = inAddr;
    }

    function setRouter(IPancakeRouter02 inAddr) external onlyOwner
    {
        _router = inAddr;
    }


    constructor()
    {
        _acceptableTokenArr.push(address(0));
        _acceptableTokenArr.push(_usdt);
        _acceptableTokens[_usdt] = uint32(_acceptableTokenArr.length - 1);
        _acceptableTokenArr.push(_wbnb);
        _acceptableTokens[_wbnb] = uint32(_acceptableTokenArr.length - 1);
        _investors.push() = investor(address(0), 0);
    }
    // constructor(IPancakeRouter02 routerAddr, address wbnbAddr, address usdtAddr)
    // {
    //     _router = routerAddr;
    //     _wbnb = wbnbAddr;
    //     _usdt = usdtAddr;

    //     _acceptableTokenArr.push(address(0));
    //     _investors.push() = investor(address(0), 0);
    // }
}