pragma solidity 0.6.4;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";

contract BSCToken is ERC20, Ownable {
    uint256 public INITIAL_SUPPLY = 100000000000000000000000000000;

    constructor() ERC20("BSC Token", "BSC") public {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}