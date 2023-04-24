// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPortal {
  function readAddress(uint256 id, bytes32 key) external view returns (address data);

  function deposit(
    uint256 poolId,
    uint256 mingETH,
    uint256 deadline,
    address receiver
  ) external payable returns (uint256 boughtgETH, uint256 mintedgETH);
}
