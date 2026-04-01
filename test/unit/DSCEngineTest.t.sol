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
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract DSCEngineTest is Test {
    error DSCEngine__ValueShouldBeMoreThanZero();
    error DSCEngine__NotAnAllowedTokenAddress();

    DeployDSC deployer;
    DSCEngine dsc_engine;
    DecentralizedStableCoin dsc;
    HelperConfig helperConfig;
    address[] tokenAddresses;
    address[] priceFeeds;
    address wETHtokenAddress;
    address wBTCtokenAddress;
    address wETHpriceFeed;
    address wBTCpriceFeed;
    uint256 deployerKey;
    address user;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsc_engine, helperConfig) = deployer.run();
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();
        wETHtokenAddress = config.wETHtokenAddress;
        wBTCtokenAddress = config.wBTCtokenAddress;
        wETHpriceFeed = config.wETHpriceFeed;
        wBTCpriceFeed = config.wBTCpriceFeed;
        user = makeAddr("user");
        ERC20Mock(wETHtokenAddress).mint(user, 1000e18);
        ERC20Mock(wETHtokenAddress).approveInternal(user, address(dsc_engine), 1000e18);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////CONSTRUCTOR TESTS//////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    function test__constructor() public {
        ////Arrange
        tokenAddresses = [wETHtokenAddress, wBTCtokenAddress];
        priceFeeds = [wETHpriceFeed];

        ////Act && ASSERT
        vm.expectRevert(DSCEngine.DSCEngine__TokensAndPriceMustBeEqual.selector);
        dsc_engine = new DSCEngine(tokenAddresses, priceFeeds, address(dsc));
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////FUNCTION  DEPOSITCOLLATERAL//////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////

    function test__CheckCollateral() public {
        console.log("User balance before deposit: ", ERC20Mock(wETHtokenAddress).balanceOf(user));
        //mint(address account, uint256 amount)
        uint256 amount = 20;
        //Act
        vm.startPrank(user);
        dsc_engine.depositCollateral(wETHtokenAddress, amount);
        vm.stopPrank();

        //Assert
        console.log("User balance after deposit: ", ERC20Mock(wETHtokenAddress).balanceOf(user));
    }

    function test__CheckCollateralRevertWhenAmountIsZero() public {
        console.log("User balance before deposit: ", ERC20Mock(wETHtokenAddress).balanceOf(user));
        //mint(address account, uint256 amount)
        uint256 amount = 0;
        //Act
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine__ValueShouldBeMoreThanZero.selector);
        dsc_engine.depositCollateral(wETHtokenAddress, amount);
        vm.stopPrank();

        //Assert
        console.log("User balance after deposit: ", ERC20Mock(wETHtokenAddress).balanceOf(user));
    }

    function test__CheckCollateralAllowedTokenRevert() public {
        //Arrange
        address tokenAddress = address(0);
        uint256 amount = 20;
        //Act
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine__NotAnAllowedTokenAddress.selector);
        dsc_engine.depositCollateral(tokenAddress, amount);
        vm.stopPrank();
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////FUNCTION MINTDSC//////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    function test__CheckmintDSC() public {
        //Arrange
        uint256 amount = 10e18;
        //Act
        vm.startPrank(user);
        dsc_engine.depositCollateral(wETHtokenAddress, amount);
        dsc_engine.mintDSC(5);
        vm.stopPrank();
    }

    function test__mintDSCWhenAmountIsZero() public {
        //Arrange
        uint256 amount = 20;
        ///Act
        vm.startPrank(user);
        dsc_engine.depositCollateral(wETHtokenAddress, amount);
        vm.expectRevert(DSCEngine.DSCEngine__ValueShouldBeMoreThanZero.selector);
        dsc_engine.mintDSC(0);
        vm.stopPrank();
    }

    function test__mintDSCWhenMintingIsntSuccessFull() public {
        ////Here i will need to simulate an account that will reject the token
        /// Then finally check if it reverts
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////FUNCTION REDEEMCOLLATERAL//////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function test__CheckRedeemCollateralFucntion() public {
        ////
        uint256 amount = 30e18;
        uint256 amountCollateral = 15e18;
        vm.startPrank(user);
        console.log("Balance of user before deposit", IERC20(wETHtokenAddress).balanceOf(user));

        uint256 userBalanceBeforeDeposit = IERC20(wETHtokenAddress).balanceOf(user);
        dsc_engine.depositCollateral(wETHtokenAddress, amount);

        console.log("Balance of user after deposit", IERC20(wETHtokenAddress).balanceOf(user));
        uint256 userBalanceAfterDeposit = IERC20(wETHtokenAddress).balanceOf(user);
        dsc_engine.mintDSC(5);

        dsc_engine.redeemCollateral(wETHtokenAddress, amountCollateral);
        console.log("Balance of user after redeem", IERC20(wETHtokenAddress).balanceOf(user));
        uint256 userBalanceAfterRedeem = IERC20(wETHtokenAddress).balanceOf(user);
        vm.stopPrank();

        assertEq(userBalanceAfterRedeem, userBalanceBeforeDeposit - amountCollateral);
    }

    // function test__CheckRedeemCollateralFunctionRevertWhenHealthFactorIsBroken() public {
    //     ERC20Mock(wETHtokenAddress).mint(user, 10e18);
    //     ERC20Mock(wETHtokenAddress).approveInternal(user, address(dsc_engine), 10e18);
    //     uint256 amount = 7e18;
    //     vm.startPrank(user);
    //     // console.log("HF before:", getHealthFactor(user));
    //     dsc_engine.depositCollateral(wETHtokenAddress, amount);
    //     dsc_engine.mintDSC(7e18);
    //     vm.expectRevert(DSCEngine.DSCEngine__HealthBelowThreshold.selector);
    //     dsc_engine.redeemCollateral(wETHtokenAddress, 6e18);
    //     // console.log("HF after:", getHealthFactor(user));
    //     vm.stopPrank();
    // }
}
