// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {ERC20Mintable} from "./ERC20Mintable.sol";

contract IPOCrossLaunch {
    struct Order {
        suint256 price;
        suint256 quantity;
        uint256 index;
        uint256 usdcAmount;
    }

    mapping(address => Order) private buyOrders;
    mapping(address => bool) private hasOrder;
    address[] private participants;

    address public owner;
    uint256 public startTime;
    bool public auctionEnded;
    uint256 public totalUSDCLocked;

    ERC20Mintable public token;
    ERC20Mintable public USDC;

    event ClearingPrice(uint256 price);
    event AuctionFinalized(uint256 clearingPrice);
    event EmergencyRefund(address user, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier auctionActive() {
        require(!auctionEnded, "Auction has ended");
        _;
    }

    constructor(address tokenAddress, address usdcAddress, address auctionOwner) {
        token = ERC20Mintable(tokenAddress);
        USDC = ERC20Mintable(usdcAddress);
        owner = auctionOwner;
        startTime = block.timestamp;
        auctionEnded = false;
    }

    function placeBuyOrder(suint256 price, suint256 quantity) external auctionActive {
        require(!hasOrder[msg.sender], "Order already exists");

        uint256 usdcAmount = uint256(price * quantity);
        require(USDC.balanceOf(msg.sender) >= usdcAmount, "Insufficient USDC balance");
        require(USDC.allowance(msg.sender, address(this)) >= usdcAmount, "Insufficient USDC allowance");

        bool success = USDC.transferFrom(msg.sender, address(this), usdcAmount);
        require(success, "USDC transfer failed");

        participants.push(msg.sender);
        buyOrders[msg.sender] = Order(price, quantity, participants.length - 1, usdcAmount);
        hasOrder[msg.sender] = true;

        totalUSDCLocked += usdcAmount;
    }

    function cancelBuyOrder() external auctionActive {
        require(hasOrder[msg.sender], "No active order found");
        
        uint256 refundAmount = buyOrders[msg.sender].usdcAmount;
        require(USDC.transfer(msg.sender, refundAmount), "USDC refund failed");
        
        totalUSDCLocked -= refundAmount;
        delete buyOrders[msg.sender];
        hasOrder[msg.sender] = false;
    }

    function emergencyRefund() external onlyOwner auctionActive {
        require(!auctionEnded, "Auction already finalized");
        
        for (uint i = 0; i < participants.length; i++) {
            address participant = participants[i];
            if (hasOrder[participant]) {
                uint256 refundAmount = buyOrders[participant].usdcAmount;
                require(USDC.transfer(participant, refundAmount), "USDC refund failed");
                emit EmergencyRefund(participant, refundAmount);
                
                delete buyOrders[participant];
                hasOrder[participant] = false;
            }
        }
        
        totalUSDCLocked = 0;
        auctionEnded = true;
    }

    function calculateWeightedAveragePrice() public view returns (uint256) {
        suint256 totalPrice = suint256(uint256(0));
        suint256 totalQuantity = suint256(uint256(0));

        for (uint i = 0; i < participants.length; i++) {
            address participant = participants[i];
            if (hasOrder[participant]) {
                Order memory order = buyOrders[participant];
                totalPrice = totalPrice + (order.price * order.quantity);
                totalQuantity = totalQuantity + order.quantity;
            }
        }
        
        uint256 avgPrice = uint256(totalPrice / totalQuantity);
        require(uint256(totalQuantity) > 0, "No orders have been placed.");
        return avgPrice;
    }

    function displayClearingPrice() public {
        uint256 clearingPrice = calculateWeightedAveragePrice();
        emit ClearingPrice(clearingPrice);
    }

    function finalizeAuction() external onlyOwner auctionActive {
        auctionEnded = true;
        uint256 clearingPrice = calculateWeightedAveragePrice();
        emit ClearingPrice(clearingPrice);

        uint256 tokenTotalSupply = token.totalSupply();
        suint256 tokenTotalSupplyS = suint256(tokenTotalSupply);
        suint256 maxDistribution = suint256((uint256(tokenTotalSupplyS) * 60) / 100);
        suint256 distributed = suint256(uint256(0));

        for (uint i = 0; i < participants.length - 1; i++) {
            for (uint j = 0; j < participants.length - i - 1; j++) {
                address addr1 = participants[j];
                address addr2 = participants[j + 1];
                
                if (hasOrder[addr1] && hasOrder[addr2]) {
                    Order memory order1 = buyOrders[addr1];
                    Order memory order2 = buyOrders[addr2];
                    
                    if (uint256(order1.price) < uint256(order2.price)) {
                        address temp = participants[j];
                        participants[j] = participants[j + 1];
                        participants[j + 1] = temp;
                    }
                }
            }
        }

        for (uint i = 0; i < participants.length && uint256(distributed) < uint256(maxDistribution); i++) {
            address buyer = participants[i];
            if (hasOrder[buyer]) {
                Order memory order = buyOrders[buyer];
                if (uint256(order.price) >= clearingPrice) {
                    suint256 quantityToFulfill = order.quantity;
                    suint256 remainingDistribution = suint256(uint256(maxDistribution) - uint256(distributed));
                    
                    if (uint256(quantityToFulfill) > uint256(remainingDistribution)) {
                        quantityToFulfill = remainingDistribution;
                        
                        uint256 unfilledQuantity = uint256(order.quantity - quantityToFulfill);
                        uint256 refundAmount = uint256(order.price) * unfilledQuantity;
                        require(USDC.transfer(buyer, refundAmount), "USDC refund failed");
                        totalUSDCLocked -= refundAmount;
                        
                        buyOrders[buyer].quantity = order.quantity - quantityToFulfill;
                        buyOrders[buyer].usdcAmount -= refundAmount;
                    } else {
                        delete buyOrders[buyer];
                        hasOrder[buyer] = false;
                    }

                    token.transfer(buyer, uint256(quantityToFulfill));
                    distributed = distributed + quantityToFulfill;
                } else {
                    require(USDC.transfer(buyer, order.usdcAmount), "USDC refund failed");
                    totalUSDCLocked -= order.usdcAmount;
                    delete buyOrders[buyer];
                    hasOrder[buyer] = false;
                }
            }
        }
        
        require(totalUSDCLocked == 0, "Not all USDC has been accounted for");
        emit AuctionFinalized(clearingPrice);
    }

    function getOrder(address buyer) external view returns (uint256 price, uint256 quantity) {
        require(hasOrder[buyer], "No active order");
        Order memory order = buyOrders[buyer];
        return (uint256(order.price), uint256(order.quantity));
    }
}
