// SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

interface IBaboonRank {

  function getRank(address addr) external view returns(uint8);

  event onMintRank(address indexed addr, uint8 indexed rank);
}
