// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC20} from "./ERC20Token.sol";
import {Ownable} from "./lib/Ownable.sol";

contract ERC20Mintable is ERC20, Ownable {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) Ownable(msg.sender) {}

    function mint(address to, uint256 amount) public onlyOwner returns (bool) {
        _mint(to, amount);
        return true;
    }
}