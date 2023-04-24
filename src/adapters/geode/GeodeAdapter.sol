//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;


import {Unauthorized} from "../../base/ErrorMessages.sol";
import {MutexLock} from "../../base/MutexLock.sol";

import {SafeERC20} from "../../libraries/SafeERC20.sol";

import {ITokenAdapter} from "../../interfaces/ITokenAdapter.sol";
import {IWETH9} from "../../interfaces/external/IWETH9.sol";
import {IPortal} from "../../interfaces/external/geode/IPortal.sol";
import {ISwap} from "../../interfaces/external/geode/ISwap.sol";
import {IERC20InterfaceUpgradable} from "../../interfaces/external/geode/IERC20InterfaceUpgradable.sol";

struct InitializationParams {
    address token;
    address underlyingToken;
    address alchemist;
    address portal;
    uint256 poolId;
}


contract GeodeAdapter is ITokenAdapter, MutexLock {
    string public constant override version = "1.0.0";

    address public immutable override token;            // ALCH-GEODE token
    address public immutable override underlyingToken;  // WETH
    address public immutable alchemist;
    IPortal public immutable portal;
    uint256 public immutable poolId;

    constructor(InitializationParams memory params) {
        token           = params.token;
        underlyingToken = params.underlyingToken;
        alchemist       = params.alchemist;
        portal          = IPortal(params.portal);
        poolId          = params.poolId;

    }

    /// @dev Checks that the message sender is the alchemist that the adapter is bound to.
    modifier onlyAlchemist() {
        if (msg.sender != alchemist) {
            revert Unauthorized("Not alchemist");
        }
        _;
    }

    receive() external payable {
        if (msg.sender != underlyingToken && msg.sender != portal.readAddress(poolId, "liquidityPool")) {
            revert Unauthorized("Payments only permitted from WETH or pool");
        }
    }

    /// @inheritdoc ITokenAdapter
    function price() external view returns (uint256) {
        return IERC20InterfaceUpgradable(token).pricePerShare();
    }

    /// @inheritdoc ITokenAdapter
    function wrap(
        uint256 amount,
        address recipient
    ) external lock onlyAlchemist returns (uint256) {
        // Transfer the tokens from the message sender.
        SafeERC20.safeTransferFrom(underlyingToken, msg.sender, address(this), amount);

        // Unwrap the WETH into ETH.
        IWETH9(underlyingToken).withdraw(amount);

        // Wrap the ETH into ALCH-GEODE token
        (uint256 boughtgETH, uint256 mintedgETH) = portal.deposit{value: amount}(poolId, 0, block.timestamp + 10, recipient);
        
        return boughtgETH + mintedgETH;
    }

    // @inheritdoc ITokenAdapter
    function unwrap(
        uint256 amount,
        address recipient
    ) external lock onlyAlchemist returns (uint256) {
        // Transfer the tokens (ALCH-GEODE token) from the message sender.
        SafeERC20.safeTransferFrom(token, msg.sender, address(this), amount);

        // Unwrap the ALCH-GEODE token
        uint256 received = ISwap(portal.readAddress(poolId, "liquidityPool")).swap{value: amount}(1, 0, amount, 0, block.timestamp + 10);

        // Wrap the ETH that we received
        IWETH9(underlyingToken).deposit{value: received}();

        // Transfer the tokens to the recipient.
        SafeERC20.safeTransfer(underlyingToken, recipient, received);
        return received;
    }
}
