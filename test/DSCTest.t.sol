//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {Test} from "forge-std/Test.sol";

contract DSCTest is Test {

  DecentralizedStableCoin public DSC;
  address user;

  error DecentralizedStableCoin__BurnAmountExceedsBalance();

  function setUp() public {
   address user = makeAddr("user");
   vm.startPrank(user);
   DecentralizedStableCoin DSC = new DecentralizedStableCoin();
   vm.stopPrank();
  
  }

  function test__IfBurnWorks() public {
    //Arrange 
    address user = makeAddr("user");
    vm.startPrank(user);
    DecentralizedStableCoin DSC = new DecentralizedStableCoin();
    DSC.mint(user, 100); 
    DSC.burn(20);
    vm.stopPrank();
    //Assert
    uint256 balance = DSC.balanceOf(user);
    assertEq(80, balance);
}

function test__IfItRevert_BurnAmountExceedsBalance() public {

    address user = makeAddr("user");
    vm.startPrank(user);
    DecentralizedStableCoin DSC = new DecentralizedStableCoin();
    vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__BurnAmountExceedsBalance.selector);
    DSC.burn(20);
    vm.stopPrank();

}

function test__IfItRevert_AmountMustBeMoreThanZero() public {
    address user = makeAddr("user");
    vm.startPrank(user);
    DecentralizedStableCoin DSC = new DecentralizedStableCoin();
    vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__AmountMustBeMoreThanZero.selector);
    DSC.burn(0);
    vm.stopPrank();
}

function test__ifRevert_CantMintToAZeroAddress() public {
   address user = makeAddr("user");
    vm.startPrank(user);
    DecentralizedStableCoin DSC = new DecentralizedStableCoin();
    vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__CantMintToAZeroAddress.selector);
    DSC.mint(address(0), 100); 
    vm.stopPrank(); 
}

function test_ifRevert_CantMintZeroTokens() public {
    address user = makeAddr("user");
    vm.startPrank(user);
    DecentralizedStableCoin DSC = new DecentralizedStableCoin();
    vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__CantMintZeroTokens.selector);
    DSC.mint(user, 0); 
    vm.stopPrank();
}


















}