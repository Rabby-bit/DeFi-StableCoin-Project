// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure function

pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract DSCEngine is ReentrancyGuard {
    error DSCEngine__ValueShouldBeMoreThanZero();
    error DSCEngine__NotAnAllowedTokenAddress();

    modifier moreThanZero(uint256 value) {
        if (value == 0) {
            revert DSCEngine__ValueShouldBeMoreThanZero();
        }
        _;
    }

    modifier allowedToken(address tokenAddress) {
        if (s_tokentoPriceFeed[tokenAddress] == address(0)) {
            revert DSCEngine__NotAnAllowedTokenAddress();
        }
        _;
    }

    mapping(address token => address priceFeed) private s_tokentoPriceFeed;
    mapping(address sender => mapping(address tokenAddress => uint256 value)) private s_collateralDeposited;

    constructor(address[] memory tokenAddress, address[] memory priceFeed) {
        for (uint256 i = 0; i < tokenAddress.length; i++) {
            s_tokentoPriceFeed[tokenAddress[i]] = priceFeed[i];
        }
    }

    function depositCollateral(address tokenAddress, uint256 value)
        external
        allowedToken(tokenAddress)
        moreThanZero(value)
        nonReentrant
        returns (bool)
    {
        bool success = IERC20(tokenAddress).transferFrom(msg.sender, address(this), value);
        s_collateralDeposited[msg.sender][tokenAddress] += value;

        return true;
    }

    function burnDSC() external {}

    function mintDSC() external {}

    function redeemCollateral() external {}

    function redeemCollateralforDSC() external {}

    function liquidate() external {}

    function getHealthFactor() external view returns (uint256) {}
}
