// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console, Vm} from "forge-std/Test.sol";
import {IPOFactory} from "../src/IPOFactory.sol";
import {IPOCrossLaunch} from "../src/IPOCrossLaunch.sol";
import {ERC20Token} from "../src/ERC20Token.sol";

contract IPOCrossTest is Test {
    IPOFactory public factory;
    IPOCrossLaunch public ipo;
    ERC20Token public token;
    ERC20Token public usdc;
    
    address public constant BUYER1 = address(0x111);
    address public constant BUYER2 = address(0x222);
    address public constant BUYER3 = address(0x333);
    
    function setUp() public {
        // Deploy USDC mock
        usdc = new ERC20Token("USD Coin", "USDC");
        
        factory = new IPOFactory();
        // Create a new IPO by deploying a token and its associated IPO cross auction
        address ipoAddress = factory.createIPO("TestToken", "TTK", address(usdc));
        ipo = IPOCrossLaunch(payable(ipoAddress));
        token = ERC20Token(ipo.token());
        
        // Mint USDC to test addresses
        usdc.mint(BUYER1, 1000000 * 10**6); // 1M USDC
        usdc.mint(BUYER2, 1000000 * 10**6);
        usdc.mint(BUYER3, 1000000 * 10**6);
    }

    function test_IPOCreation() public {
        // Expect a token supply of 1 billion (1e9) tokens with 18 decimals
        uint256 expectedSupply = 1e9 * (10 ** 18);
        assertEq(token.totalSupply(), expectedSupply, "Token total supply should be 1 billion");
        assertEq(token.owner(), address(ipo), "Token owner should be IPOCrossLaunch contract");
        assertEq(address(ipo.USDC()), address(usdc), "USDC address should match");
    }

    function test_PlaceBuyOrder() public {
        uint256 price = 100;      // 100 USDC per token
        uint256 quantity = 1000;  // 1,000 tokens
        uint256 usdcRequired = price * quantity; // 100,000 USDC required
        
        vm.startPrank(BUYER1);
        usdc.approve(address(ipo), usdcRequired);
        ipo.placeBuyOrder(price, quantity);
        vm.stopPrank();

        // Verify order was stored correctly
        (uint256 orderPrice, uint256 orderQuantity) = ipo.getOrder(BUYER1);
        assertEq(orderPrice, price, "Order price should be 100");
        assertEq(orderQuantity, quantity, "Order quantity should be 1000");
        
        // Verify USDC was transferred
        assertEq(usdc.balanceOf(address(ipo)), usdcRequired, "IPO should have received USDC");
        assertEq(ipo.totalUSDCLocked(), usdcRequired, "Total USDC locked should match");
    }

    function test_PlaceBuyOrder_InsufficientBalance() public {
        uint256 price = 100;
        uint256 quantity = 1000;
        
        // Set BUYER1 balance to 0
        vm.startPrank(BUYER1);
        uint256 balance = usdc.balanceOf(BUYER1);
        usdc.transfer(BUYER2, balance);
        
        usdc.approve(address(ipo), price * quantity);
        vm.expectRevert("Insufficient USDC balance");
        ipo.placeBuyOrder(price, quantity);
        vm.stopPrank();
    }

    function test_PlaceBuyOrder_InsufficientAllowance() public {
        uint256 price = 100;
        uint256 quantity = 1000;
        
        vm.startPrank(BUYER1);
        // Don't approve USDC
        vm.expectRevert("Insufficient USDC allowance");
        ipo.placeBuyOrder(price, quantity);
        vm.stopPrank();
    }

    function test_CancelBuyOrder() public {
        uint256 price = 150;
        uint256 quantity = 500;
        uint256 usdcAmount = price * quantity;
        
        vm.startPrank(BUYER1);
        usdc.approve(address(ipo), usdcAmount);
        ipo.placeBuyOrder(price, quantity);
        
        uint256 initialBalance = usdc.balanceOf(BUYER1);
        ipo.cancelBuyOrder();
        vm.stopPrank();
        
        // Verify USDC was refunded
        assertEq(usdc.balanceOf(BUYER1), initialBalance, "USDC should be refunded");
        assertEq(ipo.totalUSDCLocked(), 0, "No USDC should be locked");
        
        vm.expectRevert("No active order");
        ipo.getOrder(BUYER1);
    }

    function test_EmergencyRefund() public {
        // Place multiple orders
        vm.startPrank(BUYER1);
        usdc.approve(address(ipo), 1000000);
        ipo.placeBuyOrder(100, 1000);
        vm.stopPrank();

        vm.startPrank(BUYER2);
        usdc.approve(address(ipo), 1000000);
        ipo.placeBuyOrder(150, 2000);
        vm.stopPrank();

        uint256 buyer1InitialBalance = usdc.balanceOf(BUYER1);
        uint256 buyer2InitialBalance = usdc.balanceOf(BUYER2);
        
        // Trigger emergency refund
        ipo.emergencyRefund();
        
        assertTrue(ipo.auctionEnded(), "Auction should be ended");
        assertEq(ipo.totalUSDCLocked(), 0, "All USDC should be refunded");
        assertEq(usdc.balanceOf(BUYER1), buyer1InitialBalance, "BUYER1 should be refunded");
        assertEq(usdc.balanceOf(BUYER2), buyer2InitialBalance, "BUYER2 should be refunded");
    }

    function test_WeightedAveragePrice() public {
        // Set up two orders from different addresses
        vm.startPrank(BUYER1);
        usdc.approve(address(ipo), 100000);
        ipo.placeBuyOrder(100, 1000); // 100 * 1000 = 100,000
        vm.stopPrank();

        vm.startPrank(BUYER2);
        usdc.approve(address(ipo), 100000);
        ipo.placeBuyOrder(200, 500);  // 200 * 500 = 100,000
        vm.stopPrank();

        // (100*1000 + 200*500) / (1000+500) = (100000 + 100000) / 1500 = 200000 / 1500 = ~133
        uint256 clearingPrice = ipo.calculateWeightedAveragePrice();
        assertEq(clearingPrice, 133, "Clearing price should be 133 (integer division)");
    }

    function test_FinalizeAuction() public {
        // Place orders
        vm.startPrank(BUYER1);
        usdc.approve(address(ipo), 200000);
        ipo.placeBuyOrder(100, 2000);  // 200,000 USDC
        vm.stopPrank();

        vm.startPrank(BUYER2);
        usdc.approve(address(ipo), 450000);
        ipo.placeBuyOrder(150, 3000);  // 450,000 USDC
        vm.stopPrank();

        vm.startPrank(BUYER3);
        usdc.approve(address(ipo), 250000);
        ipo.placeBuyOrder(50, 5000);   // 250,000 USDC
        vm.stopPrank();

        uint256 initialUSDCLocked = ipo.totalUSDCLocked();
        
        // Finalize auction
        ipo.finalizeAuction();
        
        assertTrue(ipo.auctionEnded(), "Auction should be finalized");
        assertEq(ipo.totalUSDCLocked(), 0, "All USDC should be processed");

        // Verify token distributions
        uint256 buyer1Balance = token.balanceOf(BUYER1);
        uint256 buyer2Balance = token.balanceOf(BUYER2);
        uint256 buyer3Balance = token.balanceOf(BUYER3);
        
        assertEq(buyer3Balance, 0, "Buyer3 should not receive tokens (bid too low)");
        
        // Verify USDC refunds for below-clearing-price orders
        assertEq(usdc.balanceOf(BUYER3), 1000000 * 10**6, "BUYER3 should be fully refunded");

        // Verify total distribution cap
        uint256 distributed = buyer1Balance + buyer2Balance;
        uint256 totalSupply = token.totalSupply();
        uint256 maxDistribution = (totalSupply * 60) / 100;
        assertTrue(distributed <= maxDistribution, "Distributed tokens should be within 60% cap");
    }

    function test_UpdateExistingOrder() public {
        vm.startPrank(BUYER1);
        usdc.approve(address(ipo), 1000000);
        
        // Place initial order
        ipo.placeBuyOrder(100, 1000);
        uint256 initialUSDCLocked = ipo.totalUSDCLocked();
        
        // Update order
        ipo.placeBuyOrder(150, 2000);
        vm.stopPrank();
        
        (uint256 price, uint256 quantity) = ipo.getOrder(BUYER1);
        assertEq(price, 150, "Updated price should be 150");
        assertEq(quantity, 2000, "Updated quantity should be 2000");
        assertEq(ipo.totalUSDCLocked(), 150 * 2000, "USDC locked should reflect new order");
    }
}
