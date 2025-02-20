// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console, Vm} from "forge-std/Test.sol";
import {IPOFactory} from "../src/IPOFactory.sol";
import {IPOCrossLaunch} from "../src/IPOCrossLaunch.sol";
import {ERC20Token} from "../src/ERC20Token.sol";

// Redeclare the OrderPlaced event so we can test for it.
// event OrderPlaced(address indexed buyer, suint256 price, suint256 quantity);

contract IPOCrossTest is Test {
    IPOFactory public factory;
    IPOCrossLaunch public ipo;
    ERC20Token public token;

    // Runs before each test.
    function setUp() public {
        factory = new IPOFactory();
        // Create a new IPO by deploying a token and its associated IPO cross auction.
        address ipoAddress = factory.createIPO("TestToken", "TTK");
        ipo = IPOCrossLaunch(payable(ipoAddress));
        token = ipo.token();
    }

    function test_IPOCreation() public view {
        // Expect a token supply of 1 billion (1e9) tokens with 18 decimals.
        uint256 expectedSupply = 1e9 * (10 ** 18);
        assertEq(token.totalSupply(), expectedSupply, "Token total supply should be 1 billion");
        // The IPO contract should own the token.
        assertEq(token.owner(), address(ipo), "Token owner should be IPOCrossLaunch contract");
    }

    function test_PlaceBuyOrder() public {
        // Use shielded values for price and quantity.
        suint256 price = suint256(100);      // Example: bid price of 100 USD
        suint256 quantity = suint256(1000);    // Example: order for 1,000 tokens

        // Expect the OrderPlaced event.
        vm.expectEmit(true, true, false, false);
        // emit OrderPlaced(msg.sender, price, quantity);

        ipo.placeBuyOrder(price, quantity);

        // Verify that the order was stored correctly.
        (uint256 orderPrice, uint256 orderQuantity) = ipo.getOrder(msg.sender);
        assertEq(orderPrice, 100, "Order price should be 100");
        assertEq(orderQuantity, 1000, "Order quantity should be 1000");
    }

    function test_CancelBuyOrder() public {
        ipo.placeBuyOrder(suint256(150), suint256(500));
        ipo.cancelBuyOrder();
        vm.expectRevert("No active order");
        ipo.getOrder(msg.sender);
    }

    function test_WeightedAveragePrice() public {
        // Set up two orders from different addresses:
        // buyer1: price = 100, quantity = 1,000
        // buyer2: price = 200, quantity = 500
        address buyer1 = address(0x123);
        address buyer2 = address(0x456);

        vm.prank(buyer1);
        ipo.placeBuyOrder(suint256(100), suint256(1000));

        vm.prank(buyer2);
        ipo.placeBuyOrder(suint256(200), suint256(500));

        // Calculate weighted average:
        // (100*1000 + 200*500) / (1000+500) = (100000 + 100000) / 1500 = 200000 / 1500 = ~133 (integer division)
        uint256 clearingPrice = ipo.calculateWeightedAveragePrice();
        assertEq(uint256(clearingPrice), 133, "Clearing price should be 133 (integer division)");
    }

    function test_FinalizeAuction() public {
        // Set up three orders:
        // buyer1: price = 100, quantity = 2,000
        // buyer2: price = 150, quantity = 3,000
        // buyer3: price = 50,  quantity = 5,000 (should be below the clearing price)
        address buyer1 = address(0x111);
        address buyer2 = address(0x222);
        address buyer3 = address(0x333);

        vm.prank(buyer1);
        ipo.placeBuyOrder(suint256(100), suint256(2000));

        vm.prank(buyer2);
        ipo.placeBuyOrder(suint256(150), suint256(3000));

        vm.prank(buyer3);
        ipo.placeBuyOrder(suint256(50), suint256(5000));

        // Finalize auction as the owner. In our setUp, msg.sender (this contract) is the auction owner.
        ipo.finalizeAuction();
        assertTrue(ipo.auctionEnded(), "Auction should be finalized");

        // Verify token distributions:
        // Orders with bid price below the clearing price (buyer3) should not receive tokens.
        uint256 buyer1Balance = token.balanceOf(buyer1);
        uint256 buyer2Balance = token.balanceOf(buyer2);
        uint256 buyer3Balance = token.balanceOf(buyer3);
        assertEq(buyer3Balance, 0, "Buyer3 should not receive tokens");

        // Verify that the total tokens distributed do not exceed 60% of the total supply.
        uint256 distributed = buyer1Balance + buyer2Balance;
        uint256 totalSupply = token.totalSupply();
        uint256 maxDistribution = (totalSupply * 60) / 100;
        assertTrue(distributed <= maxDistribution, "Distributed tokens should be within 60% cap");
    }
}
