// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20InterfaceUpgradable {
    function pricePerShare() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);
}