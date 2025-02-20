// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {Script} from "../lib/forge-std/Script.sol";
import {IPOFactory} from "../src/IPOFactory.sol";
import {ERC20Token} from "../src/ERC20Token.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy USDC mock first
        ERC20Token usdc = new ERC20Token("USD Coin", "USDC");
        
        // Deploy the factory
        IPOFactory factory = new IPOFactory();
        
        // Create an IPO through the factory
        factory.createIPO("Test Token", "TTK", address(usdc));

        vm.stopBroadcast();
    }
} 