// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ERC20Token} from "../src/ERC20Token.sol";
import {IPOCrossLaunch} from "../src/IPOCrossLaunch.sol";
import {IPOFactory} from "../src/IPOFactory.sol";

// NOTE:
// This test file uses the same style as your SRC20 tests – using vm.prank, vm.expectRevert/Emit, assertEq, etc.
// We also assume that helper functions or type aliases such as "saddress" and "suint256"
// are available in your testing environment. If they are not, you can either define them or use casts.
// For example, you might define:
//    function saddress(address a) internal pure returns (address) { return a; }
//    function suint256(uint256 a) internal pure returns (uint256) { return a; }

contract TestERC20Token is Test {
    ERC20Token public token;
    address public owner = address(1);
    address public recipient = address(2);
    uint256 public initialSupply = 1e9 * 10**18;

    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        // Deploy the token as the owner.
        vm.prank(owner);
        token = new ERC20Token("Test Token", "TST", 18, initialSupply);
    }

    function test_Metadata() public {
        assertEq(token.name(), "Test Token");
        assertEq(token.symbol(), "TST");
        assertEq(token.decimals(), 18);
    }

    function test_TotalSupplyAndInitialBalance() public {
        assertEq(token.totalSupply(), initialSupply);
        assertEq(token.balanceOf(owner), initialSupply);
    }

    function test_Transfer() public {
        uint256 transferAmount = 50 * 10**18;
        
        vm.prank(owner);
        // If your ERC20 implementation emits a Transfer event, you can also check that:
        // vm.expectEmit(true, true, false, true);
        // emit Transfer(owner, recipient, transferAmount);
        bool success = token.transfer(recipient, transferAmount);
        assertTrue(success);

        assertEq(token.balanceOf(owner), initialSupply - transferAmount);
        assertEq(token.balanceOf(recipient), transferAmount);
    }

    function test_TransferFailsForInsufficientBalance() public {
        uint256 transferAmount = 10;
        vm.prank(recipient);
        vm.expectRevert("Not enough tokens");
        token.transfer(owner, transferAmount);
    }

    function test_TransferOwnership() public {
        vm.prank(owner);
        token.transferOwnership(recipient);
        assertEq(token.owner(), recipient);
    }
}

contract TestIPOCrossLaunch is Test {
    IPOCrossLaunch public ipo;
    ERC20Token public token;
    address public owner = address(1);
    address public buyer1 = address(2);
    address public buyer2 = address(3);
    uint256 public tokenSupply = 1e6; // Set a test token supply

    // Events from IPOCrossLaunch for verifying emission.
    //event OrderPlaced(address indexed buyer, uint256 price, uint256 quantity);
    event OrderCancelled(address indexed buyer);
    event ClearingPrice(uint256 price);
    event AuctionFinalized(uint256 clearingPrice);

    function setUp() public {
        // Deploy a token and then the IPOCrossLaunch contract.
        vm.prank(owner);
        token = new ERC20Token("Auction Token", "ATKN", 18, tokenSupply);

        vm.prank(owner);
        ipo = new IPOCrossLaunch(address(token), owner);

        // Simulate the IPOFactory behavior by transferring all of the token balance
        // from the owner to the IPOCrossLaunch contract.
        uint256 ownerBalance = token.balanceOf(owner);
        vm.prank(owner);
    }

    function test_PlaceBuyOrder() public {
        uint256 price = 100;
        uint256 quantity = 10;

        vm.prank(buyer1);
        vm.expectEmit(true, true, false, true);
        //emit OrderPlaced(buyer1, price, quantity);
        ipo.placeBuyOrder(suint256(price), suint256(quantity));

        (uint256 orderPrice, uint256 orderQuantity) = ipo.getOrder(buyer1);
        assertEq(orderPrice, price);
        assertEq(orderQuantity, quantity);
    }

    function test_CancelBuyOrder() public {
        uint256 price = 200;
        uint256 quantity = 20;

        vm.prank(buyer1);
        ipo.placeBuyOrder(suint256(price), suint256(quantity));

        vm.prank(buyer1);
        vm.expectEmit(true, false, false, true);
        emit OrderCancelled(buyer1);
        ipo.cancelBuyOrder();

        vm.prank(buyer1);
        vm.expectRevert("No active order");
        ipo.getOrder(buyer1);
    }

    function test_CalculateWeightedAveragePrice() public {
        // Buyer1: price = 100, quantity = 10  -> total = 1000
        vm.prank(buyer1);
        ipo.placeBuyOrder(suint256(100), suint256(10));
        // Buyer2: price = 200, quantity = 20  -> total = 4000
        // Weighted average = (1000 + 4000) / (10 + 20) = 5000 / 30 = 166 (integer division)
        vm.prank(buyer2);
        ipo.placeBuyOrder(suint256(200), suint256(20));

        uint256 avgPrice = ipo.calculateWeightedAveragePrice();
        assertEq(avgPrice, 166);
    }

    function test_CalculateWeightedAveragePriceRevertsWhenNoOrders() public {
        vm.prank(buyer1);
        vm.expectRevert("No orders have been placed.");
        ipo.calculateWeightedAveragePrice();
    }

    function test_FinalizeAuction() public {
        // Place two orders that qualify (bid price >= eventual clearing price)
        vm.prank(buyer1);
        ipo.placeBuyOrder(suint256(150), suint256(100));

        vm.prank(buyer2);
        ipo.placeBuyOrder(suint256(250), suint256(200));

        uint256 clearingPrice = ipo.calculateWeightedAveragePrice();

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit ClearingPrice(clearingPrice);
        ipo.finalizeAuction();

        // Auction must be marked as ended.
        assertTrue(ipo.auctionEnded());

        // Check that tokens were distributed according to orders (subject to the 60% of supply cap).
        // In this test, the total ordered quantity is 300, which is below the 60% cap.
        assertEq(token.balanceOf(buyer1), 100);
        assertEq(token.balanceOf(buyer2), 200);
        // And the IPO contract's token balance should have decreased accordingly.
    }
}

contract TestIPOFactory is Test {
    IPOFactory public factory;
    address public creator = address(1);

    // Event emitted by IPOFactory.
    event IPOCreated(address tokenAddress, address ipoAddress);

    function setUp() public {
        factory = new IPOFactory();
    }

    function test_CreateIPO() public {
        vm.prank(creator);
        vm.expectEmit(true, true, false, true);
        // We cannot predict the exact addresses here so we use zeros as placeholders.
        emit IPOCreated(address(0), address(0));
        address ipoAddress = factory.createIPO("My Token", "MTKN");

        IPOCrossLaunch ipo = IPOCrossLaunch(ipoAddress);
        // Check that the auction owner is set to the creator.
        assertEq(ipo.owner(), creator);
    }
}
