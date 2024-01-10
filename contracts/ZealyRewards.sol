// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./libs/IBEP20.sol";

struct Quizer
{
    address addr;
    uint256 amount;
}


contract ZealyRewards
{
    address public _owner;

    IBEP20 public _qBNB;

    function setqBNBAddr(IBEP20 inqBNB) public
    {
        require(msg.sender == _owner);
        _qBNB = inqBNB;
    }

    function Distribute(Quizer[] memory Quizers) public
    {
        require(msg.sender == _owner);
        for (uint32 i = 0; i < Quizers.length; ++i)
        {
            _qBNB.transfer(Quizers[i].addr, Quizers[i].amount);
        }
    }

    function SendMoney(uint256 amount) public
    {
        (bool success, bytes memory returndata) = address(_qBNB).delegatecall(
            abi.encodeWithSignature("transfer(address,uint256)", msg.sender, amount)
        );
        // (bool success, bytes memory returndata) = address(_qBNB).delegatecall(
        //     abi.encodeWithSignature("balanceOf(address)", msg)
        // );

        require(success, "transfer failed");
    }

    constructor()
    {
        _owner = msg.sender;
    }
}