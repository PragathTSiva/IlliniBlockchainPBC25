// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20Token.sol";
import "./IPOCrossLaunch.sol";

contract IPOFactory {
    event IPOCreated(address tokenAddress, address ipoAddress);

    /// @notice Deploys a new token and associated IPO cross contract.
    /// @param name The token’s name.
    /// @param symbol The token’s ticker.
    /// @return ipoAddress The address of the newly created IPO cross auction contract.
    function createIPO(string calldata name, string calldata symbol) external returns (address ipoAddress) {
        // Deploy a token with a 1 billion supply (with 18 decimals).
        uint256 supply = 1e9 * (10 ** 18);
        ERC20Token token = new ERC20Token(name, symbol, 18, supply);

        // Deploy the IPO cross contract. The auction owner is msg.sender.
        IPOCrossLaunch ipo = new IPOCrossLaunch(address(token), msg.sender);

        // Transfer the entire token supply from the factory (the deployer of the token)
        // to the IPO cross contract.
        token.transfer(address(ipo), token.balanceOf(address(this)));

        // Transfer token ownership to the IPO cross contract.
        token.transferOwnership(address(ipo));

        emit IPOCreated(address(token), address(ipo));
        return address(ipo);
    }
}
