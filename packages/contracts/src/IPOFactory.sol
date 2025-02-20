pragma solidity ^0.8.0;

import "./ERC20Token.sol";
import "./IPOCrossLaunch.sol";

contract IPOFactory {
    event IPOCreated(address tokenAddress, address ipoAddress);

    function createIPO(string calldata name, string calldata symbol) external returns (address ipoAddress) {
        uint256 supply = 1e9 * (10 ** 18);
        ERC20Token token = new ERC20Token(name, symbol, 18, supply);

        IPOCrossLaunch ipo = new IPOCrossLaunch(address(token), msg.sender);

        token.transfer(address(ipo), token.balanceOf(address(this)));

        token.transferOwnership(address(ipo));

        emit IPOCreated(address(token), address(ipo));
        return address(ipo);
    }
}
