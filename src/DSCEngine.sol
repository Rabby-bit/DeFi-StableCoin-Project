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
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DSCEngine is ReentrancyGuard {
    error DSCEngine__ValueShouldBeMoreThanZero();
    error DSCEngine__NotAnAllowedTokenAddress();
    error DSCEngine__HealthBelowThreshold();
    error DSCEngine__NotAbleToMint();
    error DSCEngine___UnableToBurnDSC();
    error DSCEngine___UnableToTransferCollateralToTheCollateral();
    error DSCEngine___UnableToTransferCollateralToTheEngine();
    error DSCEngine___UnableToTransferCollateralValueToUser();
    error DSCEngine__InsufficientCollateral();
    error DSCEngine__UserHasEnoughCollateral();
    error DSCEngine__NotENoughCollateral();
    error DSCEngine__HealthFactorNotImproved();
    error DSCEngine__TransferNotSuccess();
    error DSCEngine__CantBurnWhatYouDontHave();
    error DSCEngine___NotEnoughCollateral();
    error DSCEngine__TokensAndPriceMustBeEqual();

    event DSCEngine___DscStableCoinBurnt(uint256 indexed amountDSC);
    event DSCEngine__LiquiadationHappened(
        address indexed liquiadtor, address indexed userliquidated, uint256 indexed debtToCovered
    );

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

    uint256 public constant LIQUIDATION_THRESHOLD = 50; //200%
    uint256 public constant PRICE_FEED_PRECISION = 1e8;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant LIQUIDATION_BONUS = 10;
    uint256 public constant LIQUIDATION_PRECISION = 100;
    uint256 public constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;

    address[] allowedTokens;
    DecentralizedStableCoin private immutable i_dsc;

    mapping(address token => address priceFeed) private s_tokentoPriceFeed;
    mapping(address sender => mapping(address tokenAddress => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountMinted) private s_addresstoAmountMinted;
    mapping(address user => uint256 amountDSC) private s_addresstoAmountRedeemed;
    mapping(address user => uint256 DscBurned) private s_addresstoAmountOfDSCburned;

    constructor(address[] memory tokenAddress, address[] memory priceFeed, address dscAddress) {
        for (uint256 i = 0; i < tokenAddress.length; i++) {
            s_tokentoPriceFeed[tokenAddress[i]] = priceFeed[i];
            allowedTokens.push(tokenAddress[i]);

            if (tokenAddress.length != priceFeed.length) {
                revert DSCEngine__TokensAndPriceMustBeEqual();
            }
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
    //////I THINK THIS WILL WORK HAND IN HAND WITH THE REDDEM COLLATERAL
    //////CAUSE AS THE USER REDEEMS COLLATERAL THE DSC STABLECOIN WILL BE BURNED TOO

    function burnDSC(uint256 amountToBurn) public moreThanZero(amountToBurn) returns (bool) {
        ///This is a function that allows a user to burn their DSC
        ///To make it more modular made this function
        /// function _burn(address burnFor,uint256 amount) internal view
        _burn(msg.sender, amountToBurn);
        return true;
    }

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

    function redeemCollateral(address tokenAddress, uint256 amountCollateral)
        public
        allowedToken(tokenAddress)
        moreThanZero(amountCollateral)
        nonReentrant
        returns (bool)
    {
        //This is a function thta allows a user to redeem/ retrieve their collateral
        ///To make it more modular made this function
        ///function _redeemCollateral(address collateralAddress, uint256 amount,
        // address moneyTo, address moneyFrom)
        //  revertWhengetHealthFactorisBroken(msg.sender);
        _redeemCollateral(tokenAddress, amountCollateral, msg.sender, msg.sender);
        revertWhengetHealthFactorisBroken(msg.sender);
        return true;
    }

    function redeemCollateralforDSC(uint256 amountToBurn, address tokenAddress, uint256 amountCollateral)
        external
        allowedToken(tokenAddress)
        moreThanZero(amountCollateral)
        returns (bool)
    {
        //this will do the two burn and redeeem
        burnDSC(amountToBurn);
        redeemCollateral(tokenAddress, amountCollateral);
        return true;
    }

    function liquidate(address collateralAddress, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        allowedToken(collateralAddress)
        nonReentrant
    {
        //////////////////////////Checks////////////////////////////////////
        uint256 startingHealthFactor = getHealthFactor(user);
        if (startingHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__UserHasEnoughCollateral();
        }
        uint256 collateralAmount = getTokenAmount(collateralAddress, debtToCover);
        uint256 bonus = (collateralAmount * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 transferToLiquidator = collateralAmount + bonus;
        if (s_collateralDeposited[user][collateralAddress] < transferToLiquidator) {
            revert DSCEngine__NotENoughCollateral();
        }

        ////////////////////// INTERACTIONS//////////////////////////////////////
        //////This is important to do before the effects because we are transfering from the liquidator to the contract
        bool success = i_dsc.transferFrom(msg.sender, address(this), debtToCover);
        if (!success) {
            revert DSCEngine__TransferNotSuccess();
        }
        ////////////////////EFFECTS//////////////////////////////////////
        _burnFromLiquidation(user, debtToCover);
        s_collateralDeposited[user][collateralAddress] -= transferToLiquidator;

        /////////////////////INTERACTIONS////////////////////////////////////
        _redeemCollateral(collateralAddress, transferToLiquidator, msg.sender, user);

        uint256 endingHealthFactor = getHealthFactor(user);
        if (endingHealthFactor <= startingHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        emit DSCEngine__LiquiadationHappened(msg.sender, user, debtToCover);
    }

    //////////////////////////////////////////////////////////////////////////////////
    /////////////////////Public ////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////
    function getHealthFactor(address user) public view returns (uint256 healthfactor) {
        //Health Factor = (Total Collateral Value * Weighted Average Liquidation Threshold) / Total Borrow Value
        (uint256 totalCollateralValue, uint256 totalBorrowValue) = getAccountInformation(user);
        if (totalBorrowValue == 0) return type(uint256).max;
        uint256 numerator = uint256(totalCollateralValue * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        healthfactor = (numerator * PRECISION) / totalBorrowValue;
        return healthfactor;
    }

    //////////////////////////////////////////////////////////////////////////////////
    /////////////////////Private && Internal ////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

    function _burnFromLiquidation(address user, uint256 amount) internal {
        s_addresstoAmountMinted[user] -= amount;
        i_dsc.burn(amount); // burn from contract balance
    }

    function _burn(address burnFor, uint256 amount) internal {
        if (s_addresstoAmountMinted[burnFor] < amount) {
            revert DSCEngine__CantBurnWhatYouDontHave();
        }
        /// mapping(address user => uint256 amountMinted) private s_addresstoAmountMinted;
        s_addresstoAmountMinted[burnFor] -= amount;
        i_dsc.transferFrom(burnFor, address(this), amount);
        // i_dsc.approve(address(this), amount);
        i_dsc.burn(amount);
    }

    function _redeemCollateral(address collateralAddress, uint256 amount, address moneyTo, address moneyFrom) internal {
        /// mapping(address sender => mapping(address tokenAddress => uint256 amount)) private s_collateralDeposited;
        if (s_collateralDeposited[moneyFrom][collateralAddress] < amount) {
            revert DSCEngine___NotEnoughCollateral();
        }

        s_collateralDeposited[moneyFrom][collateralAddress] -= amount;

        bool success = IERC20(collateralAddress).transfer(moneyTo, amount);
        revertWhengetHealthFactorisBroken(moneyFrom);
        if (!success) {
            revert DSCEngine__TransferNotSuccess();
        }
    }

    function revertWhengetHealthFactorisBroken(address user) internal view returns (bool) {
        uint256 healthfactor = getHealthFactor(user);
        if (healthfactor < 1e18) {
            revert DSCEngine__HealthBelowThreshold();
        }
        return true;
    }

    function getCollateralAmount(address user, address tokenAddress) internal view returns (uint256 amount) {
        amount = s_collateralDeposited[user][tokenAddress];
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
        amountinUsd = (uint256(price) * amount) / PRICE_FEED_PRECISION;
        return amountinUsd;
    }

    function _getUsdValue(address tokenAddress, uint256 amount) internal view returns (uint256 getUsdValue) {
        int256 price = getPrice(tokenAddress);
        getUsdValue = (uint256(price) * amount) / PRICE_FEED_PRECISION;
        return getUsdValue;
    }

    function getTokenAmount(address tokenAddress, uint256 usdValue) internal view returns (uint256 tokenAmount) {
        int256 price = getPrice(tokenAddress);
        ///In solidity precision and scaling is important
        /// in maths is correct
        // uint256 tokenAmount = usdValue / price;
        // usd value in solidity is e18 , how ever price is e8
        ///usdValue(2) = 2e18 * 1e18(precision)
        /// price(1) = 1e8 * 1e10(additional feed)= 1e18
        tokenAmount = (usdValue * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);

        return tokenAmount;
    }

    function getAccountInformation(address user)
        public
        view
        returns (uint256 totalCollateralValue, uint256 totalBorrowValue)
    {
        totalCollateralValue = 0;
        for (uint256 i = 0; i < allowedTokens.length; i++) {
            address token = allowedTokens[i];
            uint256 usdValue = getAmountinUsd(token, user);
            totalCollateralValue += usdValue;
        }
        totalBorrowValue = s_addresstoAmountMinted[user];
        return (totalCollateralValue, totalBorrowValue);
    }
}
