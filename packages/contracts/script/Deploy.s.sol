// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {Script} from "../lib/forge-std/src/Script.sol";
import {IPOFactory} from "../src/IPOFactory.sol";
import {ERC20Mintable} from "../src/ERC20Mintable.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy USDC mock first
        ERC20Mintable usdc = new ERC20Mintable("USD Coin", "USDC");
        
        // Deploy the factory
        IPOFactory factory = new IPOFactory();
        factory.setUSDC(address(usdc));
        // Create an IPO through the factory
        factory.createIPO("Test Token", "TTK");

        vm.stopBroadcast();
    }
} 