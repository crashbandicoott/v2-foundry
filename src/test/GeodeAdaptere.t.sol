// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {
    GeodeAdapter,
    InitializationParams
} from "../adapters/geode/GeodeAdapter.sol";

import {IAlchemistV2} from "../interfaces/IAlchemistV2.sol";
import {IWETH9} from "../interfaces/external/IWETH9.sol";
import {IPortal} from "../interfaces/external/geode/IPortal.sol";
import {IERC20InterfaceUpgradable} from "../interfaces/external/geode/IERC20InterfaceUpgradable.sol";

import {IWhitelist} from "../interfaces/IWhitelist.sol";

import {SafeERC20} from "../libraries/SafeERC20.sol";

contract GeodeAdapterTest is DSTestPlus {
    uint256 constant BPS = 10000;
    address constant alchemistAdmin = 0x9e2b6378ee8ad2A4A95Fe481d63CAba8FB0EBBF9;
    address constant alchemistAlETHWhitelist = 0xA3dfCcbad1333DC69997Da28C961FF8B2879e653;

    IERC20InterfaceUpgradable constant token = IERC20InterfaceUpgradable(0x0); // TODO: write correct address here
    IWETH9 constant weth = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IAlchemistV2 constant alchemist = IAlchemistV2(0x062Bf725dC4cDF947aa79Ca2aaCCD4F385b13b5c); // Alchemist alETH
    IPortal constant portal = IPortal(0x0); // TODO: write correct address here

    GeodeAdapter adapter;

    function setUp() external {
        adapter = new GeodeAdapter(InitializationParams({
            token:              address(token),
            underlyingToken:    address(weth),
            alchemist:          address(alchemist),
            portal:             address(portal),
            poolId:             4                   // TODO: write the correct poolId for alchemix here   
        }));

        hevm.startPrank(alchemistAdmin);
        alchemist.setTokenAdapter(address(token), address(adapter));
        IWhitelist(alchemistAlETHWhitelist).add(address(this));
        alchemist.setMaximumExpectedValue(address(token), 1000000000e18);
        hevm.stopPrank();
    }

    function testRoundTrip() external {
        deal(address(weth), address(this), 1e18);
        
        uint256 startingBalance = token.balanceOf(address(alchemist));

        SafeERC20.safeApprove(address(weth), address(alchemist), 1e18);
        uint256 shares = alchemist.depositUnderlying(address(token), 1e18, address(this), 0);

        // Test that price function returns value within 1% of actual
        uint256 underlyingValue = shares * adapter.price() / 10**SafeERC20.expectDecimals(address(token));
        assertGt(underlyingValue, 1e18 * 9900 / BPS);
        
        uint256 unwrapped = alchemist.withdrawUnderlying(address(token), shares, address(this), shares * 9900 / 10000);

        uint256 endBalance = token.balanceOf(address(alchemist));
        
        assertEq(weth.balanceOf(address(this)), unwrapped);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(adapter)), 0);
        assertApproxEq(endBalance, startingBalance, 100);
    }
}