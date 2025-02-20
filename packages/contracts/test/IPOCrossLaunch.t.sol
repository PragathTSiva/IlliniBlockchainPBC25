// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console, Vm} from "../lib/forge-std/src/Test.sol";
import {IPOFactory} from "../src/IPOFactory.sol";
import {IPOCrossLaunch} from "../src/IPOCrossLaunch.sol";
import {ERC20Mintable} from "../src/ERC20Mintable.sol";

contract IPOCrossTest is Test {
    IPOFactory public factory;
    IPOCrossLaunch public ipo;
    ERC20Mintable public token;
    ERC20Mintable public usdc;
    
    address public constant BUYER1 = address(0x111);
    address public constant BUYER2 = address(0x222);
    address public constant BUYER3 = address(0x333);
    
    function setUp() public {
        // Deploy USDC mock
        usdc = new ERC20Mintable("USD Coin", "USDC");
        
        factory = new IPOFactory();
        factory.setUSDC(address(usdc));
        // Create a new IPO by deploying a token and its associated IPO cross auction
        address ipoAddress = factory.createIPO("TestToken", "TTK");
        ipo = IPOCrossLaunch(payable(ipoAddress));
        token = ERC20Mintable(ipo.token());
        
        // Mint USDC to test addresses (1M USDC each)
        usdc.mint(BUYER1, 1_000_000 * 1e18); 
        usdc.mint(BUYER2, 1_000_000 * 1e18);
        usdc.mint(BUYER3, 1_000_000 * 1e18);
    }

    function test_IPOCreation() public {
        // Expect a token supply of 1 billion (1e9) tokens with 18 decimals
        uint256 expectedSupply = 1e9 * 1e18;
        assertEq(token.totalSupply(), expectedSupply, "Token total supply should be 1 billion");
        assertEq(token.owner(), address(ipo), "Token owner should be IPOCrossLaunch contract");
        assertEq(address(ipo.USDC()), address(usdc), "USDC address should match");
    }

    function test_PlaceBuyOrder() public {
        uint256 price = 100 * 1e18;      // 100 USDC per token
        uint256 quantity = 1000 * 1e18;  // 1,000 tokens
        uint256 usdcRequired = price * quantity / 1e18; // 100,000 USDC
        
        vm.startPrank(BUYER1);
        usdc.approve(address(ipo), usdcRequired);
        ipo.placeBuyOrder(suint256(price), suint256(quantity));
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
        uint256 price = 100 * 1e18;
        uint256 quantity = 1000 * 1e18;
        
        // Set BUYER1 balance to 0
        vm.startPrank(BUYER1);
        uint256 balance = usdc.balanceOf(BUYER1);
        usdc.transfer(BUYER2, balance);
        
        usdc.approve(address(ipo), price * quantity / 1e18);
        vm.expectRevert("Insufficient USDC balance");
        ipo.placeBuyOrder(suint256(price), suint256(quantity));
        vm.stopPrank();
    }

    function test_PlaceBuyOrder_InsufficientAllowance() public {
        uint256 price = 100 * 1e18;
        uint256 quantity = 1000 * 1e18;
        
        vm.startPrank(BUYER1);
        // Don't approve USDC
        vm.expectRevert("Insufficient USDC allowance");
        ipo.placeBuyOrder(suint256(price), suint256(quantity));
        vm.stopPrank();
    }

    function test_CancelBuyOrder() public {
        uint256 price = 150 * 1e18;
        uint256 quantity = 500 * 1e18;
        uint256 usdcAmount = price * quantity / 1e18;
        
        vm.startPrank(BUYER1);
        usdc.approve(address(ipo), usdcAmount);
        ipo.placeBuyOrder(suint256(price), suint256(quantity));
        
        uint256 initialBalance = usdc.balanceOf(BUYER1);
        ipo.cancelBuyOrder();
        vm.stopPrank();
        
        // Verify USDC was refunded
        assertEq(usdc.balanceOf(BUYER1), initialBalance + usdcAmount, "USDC should be refunded");
        assertEq(ipo.totalUSDCLocked(), 0, "No USDC should be locked");
        
        vm.expectRevert("No active order");
        ipo.getOrder(BUYER1);
    }

    function test_EmergencyRefund() public {
        // Place multiple orders
        vm.startPrank(BUYER1);
        uint256 buyer1Amount = 100 * 1e18 * 1000 * 1e18 / 1e18; // 100,000 * 1e18
        usdc.approve(address(ipo), buyer1Amount);
        ipo.placeBuyOrder(suint256(100 * 1e18), suint256(1000 * 1e18));
        vm.stopPrank();

        vm.startPrank(BUYER2);
        uint256 buyer2Amount = 150 * 1e18 * 2000 * 1e18 / 1e18; // 300,000 * 1e18
        usdc.approve(address(ipo), buyer2Amount);
        ipo.placeBuyOrder(suint256(150 * 1e18), suint256(2000 * 1e18));
        vm.stopPrank();

        uint256 buyer1InitialBalance = usdc.balanceOf(BUYER1);
        uint256 buyer2InitialBalance = usdc.balanceOf(BUYER2);
        
        // Trigger emergency refund
        ipo.emergencyRefund();
        
        assertTrue(ipo.auctionEnded(), "Auction should be ended");
        assertEq(ipo.totalUSDCLocked(), 0, "All USDC should be refunded");
        assertEq(usdc.balanceOf(BUYER1), buyer1InitialBalance + buyer1Amount, "BUYER1 should be refunded");
        assertEq(usdc.balanceOf(BUYER2), buyer2InitialBalance + buyer2Amount, "BUYER2 should be refunded");
    }

    function test_WeightedAveragePrice() public {
        // Set up two orders from different addresses
        vm.startPrank(BUYER1);
        usdc.approve(address(ipo), 100_000 * 1e18);
        ipo.placeBuyOrder(suint256(100 * 1e18), suint256(1000 * 1e18)); // 100 * 1000 = 100,000
        vm.stopPrank();

        vm.startPrank(BUYER2);
        usdc.approve(address(ipo), 100_000 * 1e18);
        ipo.placeBuyOrder(suint256(200 * 1e18), suint256(500 * 1e18));  // 200 * 500 = 100,000
        vm.stopPrank();

        // (100*1000 + 200*500) / (1000+500) = (100000 + 100000) / 1500 = 200000 / 1500 = 133.333...
        uint256 clearingPrice = ipo.calculateWeightedAveragePrice();
        assertEq(clearingPrice, 133333333333333333333, "Clearing price should be 133.333...");
    }

    function test_FinalizeAuction() public {
        // Place orders
        vm.startPrank(BUYER1);
        usdc.approve(address(ipo), 200_000 * 1e18);
        ipo.placeBuyOrder(suint256(100 * 1e18), suint256(2000 * 1e18));  // 200,000 USDC
        vm.stopPrank();

        vm.startPrank(BUYER2);
        usdc.approve(address(ipo), 450_000 * 1e18);
        ipo.placeBuyOrder(suint256(150 * 1e18), suint256(3000 * 1e18));  // 450,000 USDC
        vm.stopPrank();

        vm.startPrank(BUYER3);
        usdc.approve(address(ipo), 250_000 * 1e18);
        ipo.placeBuyOrder(suint256(50 * 1e18), suint256(5000 * 1e18));   // 250,000 USDC
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
        assertEq(usdc.balanceOf(BUYER3), 1_000_000 * 1e18, "BUYER3 should be fully refunded");

        // Verify total distribution cap
        uint256 distributed = buyer1Balance + buyer2Balance;
        uint256 totalSupply = token.totalSupply();
        uint256 maxDistribution = (totalSupply * 60) / 100;
        assertTrue(distributed <= maxDistribution, "Distributed tokens should be within 60% cap");
    }
}
