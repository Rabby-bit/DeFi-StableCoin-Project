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
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";

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

    function test__CheckRedeemCollateralFunctionRevertWhenHealthFactorIsBroken() public {
        ERC20Mock(wETHtokenAddress).mint(user, 10e18);
        ERC20Mock(wETHtokenAddress).approveInternal(user, address(dsc_engine), 10e18);
        uint256 amount = 1;
        vm.startPrank(user);
        dsc_engine.depositCollateral(wETHtokenAddress, amount);
        (uint256 collateral, uint256 debt) = dsc_engine.getAccountInformation(user);
        console.log("Collateral:", collateral);
        console.log("Debt:", debt);
        dsc_engine.mintDSC(7);
        (uint256 collateralmint, uint256 debtmint) = dsc_engine.getAccountInformation(user);
        uint256 healthFactorAfterMint = dsc_engine.getHealthFactor(user);
        console.log("Collateral:", collateralmint);
        console.log("Debt:", debtmint);
        console.log("Health Factor:", healthFactorAfterMint);
        vm.expectRevert(DSCEngine.DSCEngine__HealthBelowThreshold.selector);
        dsc_engine.redeemCollateral(wETHtokenAddress, amount);
        (uint256 collateralredeem, uint256 debtredeem) = dsc_engine.getAccountInformation(user);
        console.log("Collateral:", collateralredeem);
        console.log("Debt:", debtredeem);
        vm.stopPrank();
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////FUNCTION REDEEMCOLLATERALFORDSC//////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function test__redeemCollateralforDSC() public {
        uint256 amountToBurn = 4;
        uint256 amount = 20;
        uint256 amountToMint = 5;
        uint256 amountCollateral = 2;
        address user2 = makeAddr("user2");
        ERC20Mock(wETHtokenAddress).mint(user2, 1000e18);
        ERC20Mock(wETHtokenAddress).approveInternal(user2, address(dsc_engine), 1000e18);

        vm.startPrank(user2);
        dsc_engine.depositCollateral(wETHtokenAddress, amount);
        dsc_engine.mintDSC(amountToBurn);
        uint256 dsc_engineBalance = IERC20(wETHtokenAddress).balanceOf(address(dsc_engine));
        console.log("Balance of user before deposit", IERC20(wETHtokenAddress).balanceOf(address(dsc_engine)));
        //i think will need an approval here for the dsc token to be able to burn it from the user address
        //approve(address spender, uint256 value) external returns (bool);
        IERC20(address(dsc)).approve(address(dsc_engine), amountToBurn);

        dsc_engine.redeemCollateralforDSC(amountToBurn, wETHtokenAddress, amountCollateral);

        uint256 dsc_engineBalanceAfterRedeem = IERC20(wETHtokenAddress).balanceOf(address(dsc_engine));
        console.log("Balance of user before deposit", IERC20(wETHtokenAddress).balanceOf(address(dsc_engine)));
        vm.stopPrank();

        assertEq(dsc_engineBalanceAfterRedeem, dsc_engineBalance - amountCollateral);
    }

    function test__redeemCollateralforDSCRevertAtLessThanZero() public {
        uint256 amountToBurn = 4;
        uint256 amount = 20;
        uint256 amountToMint = 5;
        uint256 amountCollateral = 0;
        address user2 = makeAddr("user2");
        ERC20Mock(wETHtokenAddress).mint(user2, 1000e18);
        ERC20Mock(wETHtokenAddress).approveInternal(user2, address(dsc_engine), 1000e18);

        vm.startPrank(user2);
        dsc_engine.depositCollateral(wETHtokenAddress, amount);
        dsc_engine.mintDSC(amountToBurn);
        uint256 dsc_engineBalance = IERC20(wETHtokenAddress).balanceOf(address(dsc_engine));
        console.log("Balance of user before deposit", IERC20(wETHtokenAddress).balanceOf(address(dsc_engine)));
        //i think will need an approval here for the dsc token to be able to burn it from the user address
        //approve(address spender, uint256 value) external returns (bool);
        IERC20(address(dsc)).approve(address(dsc_engine), amountToBurn);
        vm.expectRevert(DSCEngine.DSCEngine__ValueShouldBeMoreThanZero.selector);
        dsc_engine.redeemCollateralforDSC(amountToBurn, wETHtokenAddress, amountCollateral);
        vm.stopPrank();
    }

    function test__redeemCollateralforDSCRevertAtNotAllowedTokenAddress() public {
        uint256 amountToBurn = 4;
        uint256 amount = 20;
        uint256 amountToMint = 5;
        uint256 amountCollateral = 0;
        address user2 = makeAddr("user2");
        ERC20Mock(wETHtokenAddress).mint(user2, 1000e18);
        ERC20Mock(wETHtokenAddress).approveInternal(user2, address(dsc_engine), 1000e18);

        vm.startPrank(user2);
        dsc_engine.depositCollateral(wETHtokenAddress, amount);
        dsc_engine.mintDSC(amountToBurn);
        uint256 dsc_engineBalance = IERC20(wETHtokenAddress).balanceOf(address(dsc_engine));
        console.log("Balance of user before deposit", IERC20(wETHtokenAddress).balanceOf(address(dsc_engine)));
        //i think will need an approval here for the dsc token to be able to burn it from the user address
        //approve(address spender, uint256 value) external returns (bool);
        IERC20(address(dsc)).approve(address(dsc_engine), amountToBurn);
        vm.expectRevert(DSCEngine.DSCEngine__NotAnAllowedTokenAddress.selector);
        dsc_engine.redeemCollateralforDSC(amountToBurn, address(0), amountCollateral);
        vm.stopPrank();
    }
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////FUNCTION LIQUIDATION//////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function test__liquidateFunctionRevertWhenUserHasCollateral() public {
        //Arrange
        ///Hmm in this situation the value of the ETH should go downnn
        //How??
        vm.startPrank(user);
        uint256 amount = 4;
        dsc_engine.depositCollateral(wETHtokenAddress, amount);
        dsc_engine.mintDSC(100);
        (uint256 collateral, uint256 debt) = dsc_engine.getAccountInformation(user);
        uint256 healthfactor = dsc_engine.getHealthFactor(user);
        console.log("Collateral:", collateral);
        console.log("Debt:", debt);
        console.log("healthfactor:", healthfactor);
        vm.stopPrank();

        address liquidator = makeAddr("liquidator");
        vm.startPrank(liquidator);
        vm.expectRevert(DSCEngine.DSCEngine__UserHasEnoughCollateral.selector);
        dsc_engine.liquidate(wETHtokenAddress, user, 40);
        vm.stopPrank();

        //Act
        //Assert
    }

    function test__liquidateFunction() public {
        //Arrange
        ///Hmm in this situation the value of the ETH should go downnn
        //How??
        vm.startPrank(user);
        uint256 amountU = 2;
        dsc_engine.depositCollateral(wETHtokenAddress, amountU);
        dsc_engine.mintDSC(100);
        (uint256 collateral, uint256 debt) = dsc_engine.getAccountInformation(user);
        uint256 healthfactor = dsc_engine.getHealthFactor(user);
        console.log("Collateral:", collateral);
        console.log("Debt:", debt);
        console.log("healthfactor:", healthfactor);
        vm.stopPrank();

        MockV3Aggregator(wETHpriceFeed).updateAnswer(80e8);

        address liquidator = makeAddr("liquidator");
        vm.startPrank(liquidator);
        ERC20Mock(wETHtokenAddress).mint(liquidator, 10000e18);
        ERC20Mock(wETHtokenAddress).approveInternal(liquidator, address(dsc_engine), 10000e18);
        uint256 amount = 5;
        dsc_engine.depositCollateral(wETHtokenAddress, amount);
        IERC20(address(dsc)).approve(address(dsc_engine), amount);

        dsc_engine.mintDSC(50);

        uint256 debtToCover = 40;
        IERC20(address(dsc)).approve(address(dsc_engine), debtToCover);

        dsc_engine.liquidate(wETHtokenAddress, user, 40);
        vm.stopPrank();
    }

    function test__liquidateFunctionRevertInvalidCollateral() public {
        //Arrange
        ///Hmm in this situation the value of the ETH should go downnn
        //How??
        vm.startPrank(user);
        uint256 amountU = 2;
        dsc_engine.depositCollateral(wETHtokenAddress, amountU);
        dsc_engine.mintDSC(100);
        (uint256 collateral, uint256 debt) = dsc_engine.getAccountInformation(user);
        uint256 healthfactor = dsc_engine.getHealthFactor(user);
        console.log("Collateral:", collateral);
        console.log("Debt:", debt);
        console.log("healthfactor:", healthfactor);
        vm.stopPrank();

        MockV3Aggregator(wETHpriceFeed).updateAnswer(80e8);

        address liquidator = makeAddr("liquidator");
        vm.startPrank(liquidator);
        ERC20Mock(wETHtokenAddress).mint(liquidator, 10000e18);
        ERC20Mock(wETHtokenAddress).approveInternal(liquidator, address(dsc_engine), 10000e18);
        uint256 amount = 5;
        dsc_engine.depositCollateral(wETHtokenAddress, amount);
        IERC20(address(dsc)).approve(address(dsc_engine), amount);

        dsc_engine.mintDSC(50);

        uint256 debtToCover = 40;
        IERC20(address(dsc)).approve(address(dsc_engine), debtToCover);

        vm.expectRevert(DSCEngine.DSCEngine__NotAnAllowedTokenAddress.selector);
        dsc_engine.liquidate(address(0), user, 40);
        vm.stopPrank();
    }

    function test__liquidateFunctionRevertAmountZero() public {
        //Arrange
        ///Hmm in this situation the value of the ETH should go downnn
        //How??
        vm.startPrank(user);
        uint256 amountU = 2;
        dsc_engine.depositCollateral(wETHtokenAddress, amountU);
        dsc_engine.mintDSC(100);
        (uint256 collateral, uint256 debt) = dsc_engine.getAccountInformation(user);
        uint256 healthfactor = dsc_engine.getHealthFactor(user);
        console.log("Collateral:", collateral);
        console.log("Debt:", debt);
        console.log("healthfactor:", healthfactor);
        vm.stopPrank();

        MockV3Aggregator(wETHpriceFeed).updateAnswer(80e8);

        address liquidator = makeAddr("liquidator");
        vm.startPrank(liquidator);
        ERC20Mock(wETHtokenAddress).mint(liquidator, 10000e18);
        ERC20Mock(wETHtokenAddress).approveInternal(liquidator, address(dsc_engine), 10000e18);
        uint256 amount = 5;
        dsc_engine.depositCollateral(wETHtokenAddress, amount);
        IERC20(address(dsc)).approve(address(dsc_engine), amount);

        dsc_engine.mintDSC(50);

        uint256 debtToCover = 40;
        IERC20(address(dsc)).approve(address(dsc_engine), debtToCover);

        vm.expectRevert(DSCEngine.DSCEngine__ValueShouldBeMoreThanZero.selector);
        dsc_engine.liquidate(wETHtokenAddress, user, 0);
        vm.stopPrank();
    }

    function test__getAccountInfo() public {
        vm.startPrank(user);
        uint256 amountU = 2;
        dsc_engine.depositCollateral(wETHtokenAddress, amountU);
        dsc_engine.mintDSC(100);
        (uint256 collateral, uint256 debt) = dsc_engine.getAccountInformation(user);
        uint256 healthfactor = dsc_engine.getHealthFactor(user);
        console.log("Collateral:", collateral);
        console.log("Debt:", debt);
        console.log("healthfactor:", healthfactor);
        uint256 healthFactor = dsc_engine.getHealthFactor(user);
        vm.stopPrank();

        assertEq(healthfactor, healthFactor);
    }

    // function test__liquidateFunctionRevertNotENoughCollateral() public {
    //     //Arrange
    //     ///Hmm in this situation the value of the ETH should go downnn
    //     //How??
    //     vm.startPrank(user);
    //     uint256 amountU = 2;
    //     dsc_engine.depositCollateral(wETHtokenAddress, amountU);
    //     dsc_engine.mintDSC(100);
    //     (uint256 collateral, uint256 debt) = dsc_engine.getAccountInformation(user);
    //     uint256 healthfactor = dsc_engine.getHealthFactor(user);
    //     console.log("Collateral:", collateral);
    //     console.log("Debt:", debt);
    //     console.log("healthfactor:" , healthfactor);
    //     vm.stopPrank();

    //     MockV3Aggregator(wETHpriceFeed).updateAnswer(800e8);

    //     address liquidator = makeAddr("liquidator");
    //     vm.startPrank(liquidator);
    //     ERC20Mock(wETHtokenAddress).mint(liquidator, 10000e18);
    //     ERC20Mock(wETHtokenAddress).approveInternal(liquidator, address(dsc_engine), 10000e18);
    //     uint256 amount = 5;
    //     dsc_engine.depositCollateral(wETHtokenAddress,amount);
    //      IERC20(address(dsc)).approve(address(dsc_engine), amount);

    //     dsc_engine.mintDSC(50);

    //     uint256 debtToCover = 40;
    //     IERC20(address(dsc)).approve(address(dsc_engine), debtToCover);

    //     vm.expectRevert(DSCEngine.DSCEngine__NotENoughCollateral.selector);
    //     dsc_engine.liquidate(wETHtokenAddress, user, 40);
    //     vm.stopPrank();

    // }
}
