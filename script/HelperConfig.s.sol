// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";
import {
    ERC20Mock
} from "@chainlink-brownie-contracts/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/mocks/ERC20Mock.sol";

abstract contract CONSTANTS {
    address public constant SEPOLIA_PRICEFEED_BTC_USD = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
    address public constant SEPOLIA_PRICEFEED_ETH_USD = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    //Chain ID
    uint256 public constant SEPOLIA_CHAINID = 11155111;
    uint256 public constant LOCAL_CHAINID = 31337;

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;
    uint256 public constant INITIAL_BALANCE = 10000e19; // 1000 WETH
    uint256 public constant ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
}

contract HelperConfig is Script, CONSTANTS {
    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        address wETHtokenAddress;
        address wBTCtokenAddress;
        address wETHpriceFeed;
        address wBTCpriceFeed;
        uint256 deployerKey;
    }

    constructor() {
        if (block.chainid == SEPOLIA_CHAINID) {
            activeNetworkConfig = getSepoliaNetworkConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilNetworkConfig();
        }
    }

    function getSepoliaNetworkConfig() public returns (NetworkConfig memory) {
        return NetworkConfig({
            wETHtokenAddress: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wBTCtokenAddress: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            wETHpriceFeed: SEPOLIA_PRICEFEED_ETH_USD,
            wBTCpriceFeed: SEPOLIA_PRICEFEED_BTC_USD,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilNetworkConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.wETHpriceFeed != address(0)) {
            return activeNetworkConfig;
        }
        vm.startBroadcast();
        MockV3Aggregator wETHmockPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        ERC20Mock wETH = new ERC20Mock("Wrapped Ether", "WETH", msg.sender, INITIAL_BALANCE);

        MockV3Aggregator wBTCmockPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        ERC20Mock wBTC = new ERC20Mock("Wrapped Bitcoin", "WBTC", msg.sender, INITIAL_BALANCE);

        vm.stopBroadcast();

        return NetworkConfig({
            wETHtokenAddress: address(wETH),
            wBTCtokenAddress: address(wBTC),
            wETHpriceFeed: address(wETHmockPriceFeed),
            wBTCpriceFeed: address(wBTCmockPriceFeed),
            deployerKey: ANVIL_PRIVATE_KEY
        });
    }

    function getActiveNetworkConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }
}
