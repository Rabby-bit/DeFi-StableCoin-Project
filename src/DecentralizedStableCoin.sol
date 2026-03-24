//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DecentralizedStableCoin is ERC20, ERC20Burnable, Ownable {
    error DecentralizedStableCoin__AmountMustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__CantMintZeroTokens();
    error DecentralizedStableCoin__CantMintToAZeroAddress();

    constructor() ERC20("DecentralizedStableCoin", "DSC") Ownable(msg.sender) {}

    //  function burn(address account, uint256 value) public onlyOwner{
    //     _burn(account , value);

    //  }
    function burn(uint256 value) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (value <= 0) {
            revert DecentralizedStableCoin__AmountMustBeMoreThanZero();
        }
        if (balance < value) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(value);
    }

    function mint(address account, uint256 value) external onlyOwner returns (bool) {
        if (account == address(0)) {
            revert DecentralizedStableCoin__CantMintToAZeroAddress();
        }
        if (value <= 0) {
            revert DecentralizedStableCoin__CantMintZeroTokens();
        }
        _mint(account, value);
        return true;
    }
}
