// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./libs/erc/ERC1155.sol";

import "@openzeppelin/contracts/utils/Strings.sol";

import "./IBaboonRank.sol";
import "./IPriceGetter.sol";
import "./IBaboon.sol";
import "./libs/IBEP20.sol";


struct RankPrice
{
    uint256 price;
    uint8 index;
}

struct WalletArr
{
    address[] wallets;
}


contract BaboonHero is ERC1155 {

    //string[] public names; //string array of names
    uint[] public ids; //uint array of ids
    string public baseMetadataURI; //the token metadata URI

    address private owner; // owner
    IBaboon baboonSM; // Baboon SmartContract
    IPriceGetter baboonPriceGetterSM;
    address public platinumDaoSM; // smart contract for dividends

    address dead = 0x0000000000000000000000000000000000000000; // dead wallet

    uint8 public ranksLength = 11; // number of ranks

    uint16 public minPriceDuration = 60 * 5; // TODO: x30

    WalletArr[11] walletsOfRank; // current rank's data

    uint16[11] rankEffects = [10, 12, 15, 20, 28, 41, 62, 96, 151, 240, 384]; // rank effects

    /*
    constructor is executed when the factory contract calls its own deployERC1155 method
    */
    constructor(string memory _uri, IBaboon _baboonSM, address _platinumDaoSM, IPriceGetter _baboonPriceGetterSM) ERC1155(_uri) {
        //names = _names;
        ids = [0,1,2,3,4,5,6,7,8,9,10];
        owner = msg.sender;
        //createMapping();
        setURI(_uri);
        baseMetadataURI = _uri;
        //name = _contractName;

        baboonSM = _baboonSM;
        platinumDaoSM = _platinumDaoSM;
        baboonPriceGetterSM = _baboonPriceGetterSM;

        //baboonRankDividendsSM = new BaboonRankDividends();
        for (uint32 i = 0; i < walletsOfRank.length; ++i)
        {
            walletsOfRank[i].wallets.push(dead);
        }

    }   

    function setMinPriceDuration(uint16 inMinPriceDuration) public
    {
        require(msg.sender == owner);
        minPriceDuration = inMinPriceDuration;
    }
    
    // TODO: delete function. only set once in constructor and forever
    function resetBaboonSM(IBaboon _baboonSM) public
    {
        require(msg.sender == owner);
        baboonSM = _baboonSM;
    }

    // TODO: delete function. only set once in constructor and forever
    function resetBaboonPriceGetterSM(IPriceGetter _baboonPriceGetter) public
    {
        require(msg.sender == owner);
        baboonPriceGetterSM = _baboonPriceGetter;
    }
    
    // TODO: delete function. only set once in constructor and forever
    function resetPlatinumDaoSM(address _platinumDaoSM) public
    {
        require(msg.sender == owner);
        platinumDaoSM = _platinumDaoSM;
    }

    function uri() public view returns (string memory) {
        return string(baseMetadataURI);
    }

    /*
    used to change metadata, only owner access
    */
    function setURI(string memory newuri) public {
        require(msg.sender == owner);
        _setURI(newuri);
    }

    function mintRank(address tokenAddress, uint8 fromRank, uint8 toRank) public
    {
      uint256 allowanceValue = IBEP20(tokenAddress).allowance(msg.sender, address(this));
      require(allowanceValue > 0, "allowance == 0");
      // get price in BOON token from tokenValue
      require(fromRank == 0 || balanceOf(msg.sender, fromRank) > 0, "not enough ranks to convert");
      (uint256 tokenValue, bool successGetPrice) = getRankPrice_Internal(fromRank, toRank, tokenAddress, block.timestamp - minPriceDuration);
      require(successGetPrice, "can't calculate rank price");
      require(toRank > 0 && toRank < walletsOfRank.length, "incorrect rankIndex");

      IBEP20(tokenAddress).transferFrom(msg.sender, platinumDaoSM, tokenValue);

      if (fromRank > 0) _burn(msg.sender, fromRank, 1);
      _mint(msg.sender, toRank, 1, "");

      emit onChangedRank(msg.sender, getRank(msg.sender));
    }

    function burnRank(uint8 rank, uint32 amount) public
    {
        _burn(msg.sender, uint256(rank), amount);
        emit onChangedRank(msg.sender, getRank(msg.sender));
    }

    event onChangedRank(address indexed addr, uint8 indexed rank);

    // !!!!!!!!!! RANK !!!!!!!!!
    function _afterTokenTransfer(address, address from, address to, uint256[] memory _ids, uint256[] memory, bytes memory) internal override 
    {
        for (uint256 i = 0; i < _ids.length; ++i)
        {
            if (from != address(0))
            {
                require(_ids[i] < walletsOfRank.length && _ids[i] > 0, "invalid rank index");
                RankData memory fromData = rankDataOf(from, _ids[i]);
                if (fromData.balance == 0)
                {
                    require(fromData.index < walletsOfRank[_ids[i]].wallets.length, "invalid wallet index to rank data");   
                    address lastAddr = walletsOfRank[_ids[i]].wallets[walletsOfRank[_ids[i]].wallets.length - 1];   
                    walletsOfRank[_ids[i]].wallets[fromData.index] = lastAddr;
                    walletsOfRank[_ids[i]].wallets.pop();

                    setIndex(_ids[i], lastAddr, fromData.index);
                    setIndex(_ids[i], from, 0);
                }
            }

            if (to != address(0))
            {
                RankData memory toData = rankDataOf(to, _ids[i]);
                if (toData.index == 0)
                {
                    walletsOfRank[_ids[i]].wallets.push(to);
                    setIndex(_ids[i], to, uint32(walletsOfRank[_ids[i]].wallets.length - 1));
                }
            }
        }
    }

    function getRank(address addr) public view returns(uint8 rank)
    {
        int256 lastIndex = int256(uint256(ranksLength - 1));
        for (int256 i = lastIndex; i >= 0; --i)
        {
            if (balanceOf(addr, uint256(i)) > 0)
            {
                return uint8(uint256(i));
            }
        }
        return 0;
    }

    function getRankPrice(uint8 fromIndex, uint8 toIndex, address tokenAddress) public view returns(uint256 price, bool success)
    {
        return getRankPrice_Internal(fromIndex, toIndex, tokenAddress, block.timestamp);
    }

    function getRankPrice_Internal(uint8 fromIndex, uint8 toIndex, address tokenAddress, uint256 curTime) internal view returns (uint256 price, bool success) 
    {    
        if (toIndex >= ranksLength) return (0, false);

        if (toIndex <= fromIndex) return (0, true);    

        uint256 boonValue = baboonSM.getPriceModifier(curTime) * (rankEffects[toIndex] - rankEffects[fromIndex]) / 10;

        if (tokenAddress == address(baboonSM)) return (boonValue, true);
        return baboonPriceGetterSM.convertFromTarget(boonValue, tokenAddress);
    }

    function getMinRankPrice(uint8 fromRank, uint8 toRank, address tokenAddress) public view returns(uint256 price, bool success)
    {
      return getRankPrice_Internal(fromRank, toRank, tokenAddress, block.timestamp - minPriceDuration);
    }

    function getAllRankPrices(uint8 fromRank, address tokenAddress) public view returns(RankPrice[] memory outRankPrices)
    {
        require(fromRank < ranksLength, "invalid fromRank");
        outRankPrices = new RankPrice[](ranksLength - fromRank - 1);

        uint8 j = 0;
        for(uint8 i = fromRank + 1; i < ranksLength; ++i)
        {
            (uint256 tokenValue, bool success) = getRankPrice_Internal(fromRank, i, tokenAddress, block.timestamp);
            if (success) 
            {
                outRankPrices[j].index = i;
                outRankPrices[j].price = tokenValue;
                ++j;
            }
        }
    }
}