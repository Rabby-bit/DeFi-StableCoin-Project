//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {
    ERC20Mock
} from "@chainlink-brownie-contracts/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/mocks/ERC20Mock.sol";
import {HelperConfig, CONSTANTS} from "script/HelperConfig.s.sol";

contract DSCEngineTest is Test {
    error DSCEngine__ValueShouldBeMoreThanZero();
    error DSCEngine__NotAnAllowedTokenAddress();

    DeployDSC deployer;
    DSCEngine dsc_engine;
    DecentralizedStableCoin dsc;
    HelperConfig helperConfig;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsc_engine, helperConfig) = deployer.run();
    }

    function test__CheckCollateral() public {
        //Arrange
        address user = makeAddr("user");
        vm.deal(user, 30 ether);
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();
        address tokenAddress = config.wETHtokenAddress;
        ERC20Mock(tokenAddress).mint(user, 100e18);
        ERC20Mock(tokenAddress).approveInternal(user, address(dsc_engine), 100e18);

        console.log("User balance before deposit: ", ERC20Mock(tokenAddress).balanceOf(user));
        //mint(address account, uint256 amount)
        uint256 amount = 20;
        //Act
        vm.startPrank(user);
        dsc_engine.depositCollateral(tokenAddress, amount);
        vm.stopPrank();

        //Assert
        console.log("User balance after deposit: ", ERC20Mock(tokenAddress).balanceOf(user));
    }

    function test__CheckCollateralRevertWhenAmountIsZero() public {
        //Arrange
        address user = makeAddr("user");
        vm.deal(user, 30 ether);
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();
        address tokenAddress = config.wETHtokenAddress;
        ERC20Mock(tokenAddress).mint(user, 100e18);
        ERC20Mock(tokenAddress).approveInternal(user, address(dsc_engine), 100e18);

        console.log("User balance before deposit: ", ERC20Mock(tokenAddress).balanceOf(user));
        //mint(address account, uint256 amount)
        uint256 amount = 0;
        //Act
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine__ValueShouldBeMoreThanZero.selector);
        dsc_engine.depositCollateral(tokenAddress, amount);
        vm.stopPrank();

        //Assert
        console.log("User balance after deposit: ", ERC20Mock(tokenAddress).balanceOf(user));
    }

    function test__CheckCollateralAllowedTokenRevert() public {
        //Arrange
        address user = makeAddr("user");
        vm.deal(user, 30 ether);
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();
        address tokenAddress = address(0);
        uint256 amount = 20;
        //Act
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine__NotAnAllowedTokenAddress.selector);
        dsc_engine.depositCollateral(tokenAddress, amount);
        vm.stopPrank();
    }

    function test__CheckmintDSC() public {
        //Arrange
        //Arrange
        address user = makeAddr("user");
        uint256 amount = 20;
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();
        address tokenAddress = config.wETHtokenAddress;
        ERC20Mock(tokenAddress).mint(user, 1000e18);
        ERC20Mock(tokenAddress).approveInternal(user, address(dsc_engine), 100000e18);

        //Act
        vm.startPrank(user);
        dsc_engine.depositCollateral(tokenAddress, amount);
        dsc_engine.mintDSC(5);
        vm.stopPrank();

        //Assert
        //  console.log("User balance after Mint" , mintDSC.balanceOf(user));
    }
}
