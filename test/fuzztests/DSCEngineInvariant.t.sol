//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Handler} from "test/fuzztests/Handler.t.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DSCEngineInvariant is StdInvariant, Test {
    DSCEngine public dsc_engine;
    DecentralizedStableCoin public dsc;
    DeployDSC public deployer;
    HelperConfig public helperConfig;
    address wETHtokenAddress;
    address wBTCtokenAddress;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;
    uint256 public constant LIQUIDATION_PRECISION = 100;

    Handler public handler;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsc_engine, helperConfig) = deployer.run();
        handler = new Handler(dsc_engine, dsc, helperConfig);
        targetContract(address(handler));
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();
        wETHtokenAddress = config.wETHtokenAddress;
        wBTCtokenAddress = config.wBTCtokenAddress;
    }

    function invariant_TotalSupplyDSCLessThanCollateralValue() public {
        uint256 totalSupplyOfDSC = dsc_engine.getTotalSupply();

        uint256 totalCollateralETH = dsc_engine.getTotalCollateralValueUSD(wETHtokenAddress);
        uint256 totalCollateralBTC = dsc_engine.getTotalCollateralValueUSD(wBTCtokenAddress);

        uint256 totalValue = totalCollateralETH + totalCollateralBTC;

        uint256 adjustedCollateralValue = (totalValue * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        assertLe(totalSupplyOfDSC, adjustedCollateralValue);
    }
}
