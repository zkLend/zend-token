// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity =0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    uint8 token_decimals;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) ERC20(_name, _symbol) {
        token_decimals = _decimals;
    }

    function decimals() public view override returns (uint8) {
        return token_decimals;
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}
