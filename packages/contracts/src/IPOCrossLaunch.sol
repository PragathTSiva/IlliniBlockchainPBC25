// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

// Uncomment and adjust the following import if you have a Seismic shielded types library.
// import "@seismic/crypto-lib.sol"; 
import {ERC20Token} from "./ERC20Token.sol";
// For demonstration, we assume that suint256 is a type alias for a shielded uint256.
// You may need to adjust this to your actual Seismic implementation.

contract IPOCrossLaunch {
    // Struct to store buy order information using shielded types.
    struct Order {
        suint256 price;    // Price per token (in USD, shielded)
        suint256 quantity; // Quantity of tokens desired (shielded)
    }

    // Mapping to store buy orders by address.
    mapping(address => Order) private buyOrders;
    mapping(address => bool) private hasOrder;
    address[] private participants;

    address public owner;
    uint256 public startTime;  // Timestamp when this contract was deployed.
    bool public auctionEnded;

    // The ERC20 token that will be distributed.
    ERC20Token public token;

    // Updated Events using uint256 instead of shielded suint256.
    event ClearingPrice(uint256 price);
    event OrderPlaced(address indexed buyer, uint256 price2, uint256 quantity);
    event OrderCancelled(address indexed buyer);
    event AuctionFinalized(uint256 clearingPrice);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier auctionActive() {
        require(!auctionEnded, "Auction has ended");
        _;
    }

    /// @param tokenAddress The address of the ERC20 token deployed in the factory.
    /// @param auctionOwner The address allowed to end the auction.
    constructor(address tokenAddress, address auctionOwner) {
        token = ERC20Token(tokenAddress);
        owner = auctionOwner;
        startTime = block.timestamp;
        auctionEnded = false;
    }

    /// @notice Place or update a buy order.
    /// @param price The bid price per token (as a shielded suint256).
    /// @param quantity The amount of tokens to buy (as a shielded suint256).
    function placeBuyOrder(suint256 price, suint256 quantity) external auctionActive {
        if (!hasOrder[msg.sender]) {
            participants.push(msg.sender);
        }
        buyOrders[msg.sender] = Order(price, quantity);
        hasOrder[msg.sender] = true;
        emit OrderPlaced(msg.sender, uint256(price), uint256(quantity));
    }

    /// @notice Cancel an existing buy order.
    function cancelBuyOrder() external auctionActive {
        require(hasOrder[msg.sender], "No active order found");
        delete buyOrders[msg.sender];
        hasOrder[msg.sender] = false;
        emit OrderCancelled(msg.sender);
    }

    /// @notice Compute the weighted average price (the "clearing price") of all active orders.
    /// @return The weighted average price as a uint256.
    function calculateWeightedAveragePrice() public view returns (uint256) {
        suint256 totalPrice = suint256(uint256(0));
        suint256 totalQuantity = suint256(uint256(0));

        for (uint i = 0; i < participants.length; i++) {
            address participant = participants[i];
            if (hasOrder[participant]) {
                Order memory order = buyOrders[participant];
                // Multiply price by quantity and accumulate.
                totalPrice = suint256(uint256(totalPrice) + (uint256(order.price) * uint256(order.quantity)));
                totalQuantity = suint256(uint256(totalQuantity) + uint256(order.quantity));
            }
        }
        require(uint256(totalQuantity) > 0, "No orders have been placed.");
        uint256 avgPrice = uint256(totalPrice) / uint256(totalQuantity);
        return avgPrice;
    }

    /// @notice Emit an event showing the current clearing price.
    function displayClearingPrice() public {
        uint256 clearingPrice = calculateWeightedAveragePrice();
        emit ClearingPrice(clearingPrice);
    }

    /// @notice Finalize the auction (only callable by the owner). After finalization:
    ///         - No new orders are accepted.
    ///         - Orders with bid prices >= clearing price are fulfilled,
    ///           but only up to 60% of the token supply is distributed.
    function finalizeAuction() external onlyOwner auctionActive {
        auctionEnded = true;
        uint256 clearingPrice = calculateWeightedAveragePrice();
        emit ClearingPrice(clearingPrice);

        uint256 tokenTotalSupply = token.totalSupply();
        suint256 tokenTotalSupplyS = suint256(tokenTotalSupply);
        suint256 maxDistribution = suint256((uint256(tokenTotalSupplyS) * 60) / 100);
        suint256 distributed = suint256(uint256(0));

        for (uint i = 0; i < participants.length && uint256(distributed) < uint256(maxDistribution); i++) {
            address buyer = participants[i];
            if (hasOrder[buyer]) {
                Order memory order = buyOrders[buyer];
                // Only fulfill orders with a bid price at or above the clearing price.
                if (uint256(order.price) >= clearingPrice) {
                    suint256 quantityToFulfill = order.quantity;
                    if (uint256(distributed) + uint256(quantityToFulfill) > uint256(maxDistribution)) {
                        quantityToFulfill = suint256(uint256(maxDistribution) - uint256(distributed));
                    }
                    token.transfer(buyer, uint256(quantityToFulfill));
                    distributed = suint256(uint256(distributed) + uint256(quantityToFulfill));
                }
            }
        }
        emit AuctionFinalized(clearingPrice);
    }

    /// @notice View the order details for a given buyer.
    /// @param buyer The address to check.
    /// @return price The bid price and quantity from the order (both uint256).
    function getOrder(address buyer) external view returns (uint256 price, uint256 quantity) {
        require(hasOrder[buyer], "No active order");
        Order memory order = buyOrders[buyer];
        return (uint256(order.price), uint256(order.quantity));
    }
}
