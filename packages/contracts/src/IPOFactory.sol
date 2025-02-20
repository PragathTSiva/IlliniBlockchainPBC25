pragma solidity ^0.8.0;

import "./ERC20Token.sol";
import "./IPOCrossLaunch.sol";
import "./lib/Ownable.sol";

contract IPOFactory is Ownable {
    event IPOCreated(address tokenAddress, address ipoAddress);
    address public usdc;

    constructor() Ownable(msg.sender) {
    }

    function setUSDC(address _usdc) external onlyOwner {
        usdc = _usdc;
    }

    function createIPO(string calldata name, string calldata symbol) external returns (address ipoAddress) {
        uint256 supply = 1e9 * (10 ** 18);
        ERC20Mintable token = new ERC20Mintable(name, symbol);
        token.mint(address(this), supply);

        IPOCrossLaunch ipo = new IPOCrossLaunch(address(token), usdc, msg.sender);

        token.transfer(address(ipo), token.balanceOf(address(this)));

        token.transferOwnership(address(ipo));

        emit IPOCreated(address(token), address(ipo));
        return address(ipo);
    }
}
