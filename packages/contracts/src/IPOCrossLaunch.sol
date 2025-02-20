// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {ERC20Mintable} from "./ERC20Mintable.sol";
// import {suint256} from "fhevm/lib/TFHE.sol";

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

        uint256 usdcAmount = uint256(price) * uint256(quantity) / 1e18;
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
        bool success = USDC.transfer(msg.sender, refundAmount);
        require(success, "USDC refund failed");
        
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
                bool success = USDC.transfer(participant, refundAmount);
                require(success, "USDC refund failed");
                emit EmergencyRefund(participant, refundAmount);
                
                totalUSDCLocked -= refundAmount;
                delete buyOrders[participant];
                hasOrder[participant] = false;
            }
        }
        
        auctionEnded = true;
    }

    function calculateWeightedAveragePrice() public view returns (uint256) {
        uint256 totalPriceTimesQuantity = 0;
        uint256 totalQuantity = 0;

        for (uint i = 0; i < participants.length; i++) {
            address participant = participants[i];
            if (hasOrder[participant]) {
                Order memory order = buyOrders[participant];
                totalPriceTimesQuantity += uint256(order.price) * uint256(order.quantity);
                totalQuantity += uint256(order.quantity);
            }
        }
        
        require(totalQuantity > 0, "No orders have been placed.");
        return totalPriceTimesQuantity / totalQuantity;
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
        uint256 maxDistribution = (tokenTotalSupply * 60) / 100;
        uint256 distributed = 0;

        // Sort participants by price (highest to lowest)
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

        // Distribute tokens and refund USDC
        for (uint i = 0; i < participants.length && distributed < maxDistribution; i++) {
            address buyer = participants[i];
            if (hasOrder[buyer]) {
                Order memory order = buyOrders[buyer];
                if (uint256(order.price) >= clearingPrice) {
                    uint256 quantityToFulfill = uint256(order.quantity);
                    uint256 remainingDistribution = maxDistribution - distributed;
                    
                    if (quantityToFulfill > remainingDistribution) {
                        quantityToFulfill = remainingDistribution;
                        
                        uint256 unfilledQuantity = uint256(order.quantity) - quantityToFulfill;
                        uint256 refundAmount = uint256(order.price) * unfilledQuantity / 1e18;
                        bool success = USDC.transfer(buyer, refundAmount);
                        require(success, "USDC refund failed");
                        totalUSDCLocked -= refundAmount;
                    }

                    bool success = token.transfer(buyer, quantityToFulfill);
                    require(success, "Token transfer failed");
                    distributed += quantityToFulfill;
                    
                    totalUSDCLocked -= order.usdcAmount;
                    delete buyOrders[buyer];
                    hasOrder[buyer] = false;
                } else {
                    bool success = USDC.transfer(buyer, order.usdcAmount);
                    require(success, "USDC refund failed");
                    totalUSDCLocked -= order.usdcAmount;
                    delete buyOrders[buyer];
                    hasOrder[buyer] = false;
                }
            }
        }
        
        require(totalUSDCLocked == 0, "Not all USDC has been accounted for");
        emit AuctionFinalized(clearingPrice);
    }
}
