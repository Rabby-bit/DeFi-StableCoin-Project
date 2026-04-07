//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test , console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {
    ERC20Mock
} from "@chainlink-brownie-contracts/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/mocks/ERC20Mock.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract Handler is Test {
    DSCEngine public dsc_engine;
    DecentralizedStableCoin public dsc;
    DeployDSC public deployer;
    HelperConfig public helperConfig;
    address wETHtokenAddress;
    address wBTCtokenAddress;
    uint256 amount;

    address[] public actors;
    address public currentActor;
    address[] public usersWithCollateral;

    address[] allowedTokens;

    uint256 public ghost_depositSum;
    uint256 public ghost_withdrawnSum;
    uint256 public ghost_mintedSum;
    uint96 public constant MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(DSCEngine _dsc_engine, DecentralizedStableCoin _dsc, HelperConfig _helperConfig) {
        dsc_engine = _dsc_engine;
        dsc = _dsc;
        helperConfig = _helperConfig;

        allowedTokens = dsc_engine.getAllowedTokens();
        wETHtokenAddress = allowedTokens[0];
        wBTCtokenAddress = allowedTokens[1];

        for (uint256 i = 0; i < 5; i++) {
            actors.push(makeAddr(string(abi.encodePacked("actor", i))));
        }
    }

    function _useActor(uint256 seed) internal {
        currentActor = actors[bound(seed, 0, actors.length - 1)];
        vm.startPrank(currentActor);
    }

    function _getTokenAddress(uint256 tokenSeed) internal view returns (address) {
        if (tokenSeed % 2 == 0) {
            return wETHtokenAddress;
        } else {
            return wBTCtokenAddress;
        }
    }

    ///function depositCollateral(address tokenAddress, uint256 amount)
    function mintandDepositCollateralDSCE(uint256 tokenSeed, uint256 amount) public {
        address token = _getTokenAddress(tokenSeed);
        amount = bound(amount, 1, MAX_DEPOSIT_SIZE);

        _useActor(tokenSeed);
        ERC20Mock(token).mint(currentActor, amount);
        ERC20Mock(token).approve(address(dsc_engine), amount);
        dsc_engine.depositCollateral(token, amount);
        vm.stopPrank();
        ghost_depositSum += amount;
        usersWithCollateral.push(currentActor);
    }

    function mintDSCoin(uint256 tokenSeed, uint256 amount) external {
        amount = bound(amount, 1, MAX_DEPOSIT_SIZE);
        _useActor(tokenSeed);
         try dsc_engine.mintDSC(amount) {
        // Only runs if mint succeeds
        ghost_mintedSum += amount;

        uint256 hf = dsc_engine.getHealthFactor(currentActor);
        console.log("Health factor after minting: ", hf);

    } catch {

    }

    vm.stopPrank();
    }

    function redeemCollateral(uint256 tokenSeed, uint256 amountCollateral) public {
        address token = _getTokenAddress(tokenSeed);


        _useActor(tokenSeed);
        uint256 deposited = dsc_engine.getCollateralBalanceOfUser(currentActor, token);
        if (deposited == 0) {
        vm.stopPrank();
        return;
        }

    amountCollateral = bound(amountCollateral, 1, deposited);
        try dsc_engine.redeemCollateral(token, amountCollateral) {
        ghost_depositSum -= amountCollateral;
        ghost_withdrawnSum += amountCollateral;
        } catch {
        // ignore revert
        }
        vm.stopPrank();

    }

    function burnDSC(uint256 tokenSeed, uint256 amountToBurn) public {

        amountToBurn = bound(amountToBurn, 1, MAX_DEPOSIT_SIZE);

        _useActor(tokenSeed);
         uint256 balance = dsc.balanceOf(currentActor);
         if (balance == 0) return;
        
         try dsc_engine.burnDSC(amountToBurn) {
        ghost_mintedSum -= amountToBurn;
        } catch {
        // ignore revert
         }
        vm.stopPrank();
    }

    /// function liquidate(uint256 collateralSeed, address userToBeLiquidated, uint256 debtToCover) public {
    //     ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
    //     dscEngine.liquidate(address(collateral), userToBeLiquidated, debtToCover);
    // } liquidate(address collateralAddress, address user, uint256 debtToCover)
    function liquidate(uint256 collateralSeed, uint256 userSeed, uint256 debtToCover) public {
        address collateral = _getTokenAddress(collateralSeed);
        debtToCover = bound(debtToCover, 1, MAX_DEPOSIT_SIZE);
        if (usersWithCollateral.length == 0) return;
        address userToBeLiquidated = usersWithCollateral[bound(userSeed, 0, usersWithCollateral.length - 1)];

        uint256 healthfactor = dsc_engine.getHealthFactor(userToBeLiquidated);
        if (healthfactor >= 1) return;

        _useActor(collateralSeed);
        dsc_engine.liquidate(collateral, userToBeLiquidated, debtToCover);
        vm.stopPrank();
    }
}
