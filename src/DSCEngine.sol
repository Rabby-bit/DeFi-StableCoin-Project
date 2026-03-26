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
import {
    AggregatorV3Interface
} from "@chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract DSCEngine is ReentrancyGuard {
    error DSCEngine__ValueShouldBeMoreThanZero();
    error DSCEngine__NotAnAllowedTokenAddress();
    error DSCEngine__HealthBelowThreshold();
    error DSCEngine__NotAbleToMint();

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
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

    uint256 public constant LIQUIDATION_THRESHOLD = 2e18; //200%
    uint256 public constant PRICE_FEED_PRECISION = 1e8;
    uint256 public constant PRECISION = 1e18;

    address[] allowedTokens;
    DecentralizedStableCoin private immutable i_dsc;

    mapping(address token => address priceFeed) private s_tokentoPriceFeed;
    mapping(address sender => mapping(address tokenAddress => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountMinted) private s_addresstoAmountMinted;

    constructor(address[] memory tokenAddress, address[] memory priceFeed, address dscAddress) {
        for (uint256 i = 0; i < tokenAddress.length; i++) {
            s_tokentoPriceFeed[tokenAddress[i]] = priceFeed[i];
            allowedTokens.push(tokenAddress[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    function depositCollateral(address tokenAddress, uint256 amount)
        external
        allowedToken(tokenAddress)
        moreThanZero(amount)
        nonReentrant
        returns (bool)
    {
        bool success = IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");
        s_collateralDeposited[msg.sender][tokenAddress] += amount;

        return true;
    }

    function burnDSC() external {}

    /*

    */
    function mintDSC(uint256 amountToMint) external moreThanZero(amountToMint) nonReentrant returns (bool) {
        s_addresstoAmountMinted[msg.sender] += amountToMint;
        revertWhengetHealthFactorisBroken(msg.sender);
        bool success = i_dsc.mint(msg.sender, amountToMint);

        if (!success) {
            revert DSCEngine__NotAbleToMint();
        }
        return true;
    }

    function redeemCollateral() external {}

    function redeemCollateralforDSC() external {}

    function liquidate() external {}

    //////////////////////////////////////////////////////////////////////////////////
    /////////////////////Public ////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////
    function getHealthFactor(address user) public view returns (uint256 healthfactor) {
        //Health Factor = (Total Collateral Value * Weighted Average Liquidation Threshold) / Total Borrow Value
        (uint256 totalCollateralValue, uint256 totalBorrowValue) = getAccountInformation(user);
        uint256 healthfactor = uint256(((totalCollateralValue * LIQUIDATION_THRESHOLD) / PRECISION) / totalBorrowValue);
        return healthfactor;
    }

    //////////////////////////////////////////////////////////////////////////////////
    /////////////////////Private && Internal ////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

    function revertWhengetHealthFactorisBroken(address user) internal view returns (bool) {
        uint256 healthfactor = getHealthFactor(user);
        if (healthfactor <= 1e18) {
            revert DSCEngine__HealthBelowThreshold();
        }
        return true;
    }

    function getCollateralAmount(address user, address tokenAddress) internal view returns (uint256 amount) {
        uint256 amount = s_collateralDeposited[user][tokenAddress];
        return amount;
    }

    function getPrice(address tokenAddress) internal view returns (int256 priceToken) {
        address priceFeedAddress = s_tokentoPriceFeed[tokenAddress];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return price;
    }

    function getAmountinUsd(address tokenAddress, address user) internal view returns (uint256 amountinUsd) {
        int256 price = getPrice(tokenAddress);
        uint256 amount = getCollateralAmount(user, tokenAddress);
        uint256 amountinUsd = (uint256(price) * amount) / PRICE_FEED_PRECISION;
        return amountinUsd;
    }

    function getAccountInformation(address user)
        internal
        view
        returns (uint256 totalCollateralValue, uint256 totalBorrowValue)
    {
        uint256 totalCollateralValue = 0;
        for (uint256 i = 0; i < allowedTokens.length; i++) {
            address token = allowedTokens[i];
            uint256 usdValue = getAmountinUsd(token, user);
            totalCollateralValue += usdValue;
        }
        totalBorrowValue = s_addresstoAmountMinted[user];
        return (totalCollateralValue, totalBorrowValue);
    }
}
