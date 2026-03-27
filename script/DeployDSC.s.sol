// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DeployDSC is Script {
    DecentralizedStableCoin public dsc;
    DSCEngine public dsc_engine;
    HelperConfig public helperConfig;
    address[] tokenAddresses;
    address[] priceFeeds;
    //constructor(address[] memory tokenAddress, address[] memory priceFeed, address dscAddress)

    function run() external returns (DecentralizedStableCoin, DSCEngine, HelperConfig) {
        helperConfig = new HelperConfig();
        (
            address wETHtokenAddress,
            address wBTCtokenAddress,
            address wETHpriceFeed,
            address wBTCpriceFeed,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        tokenAddresses = [wETHtokenAddress, wBTCtokenAddress];
        priceFeeds = [wETHpriceFeed, wBTCpriceFeed];

        vm.startBroadcast();
        dsc = new DecentralizedStableCoin();
        dsc_engine = new DSCEngine(tokenAddresses, priceFeeds, address(dsc));
        dsc.transferOwnership(address(dsc_engine));
        vm.stopBroadcast();

        return (dsc, dsc_engine, helperConfig);
    }
}
