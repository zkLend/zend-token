// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity =0.8.21;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract ZendToken is ERC20Upgradeable, Ownable2StepUpgradeable {
    uint256 private constant TOTAL_SUPPLY = 100000000e18;

    bool private v2_initialized;

    function __ZendToken_init(address genesis_holder) public initializer {
        __ERC20_init("zkLend Token", "ZEND");

        _mint(genesis_holder, TOTAL_SUPPLY);
    }

    function __ZendToken_upgrade_v2(address initial_owner) public {
        require(!v2_initialized, "ZendToken: v2 already initialized");
        v2_initialized = true;
        _transferOwnership(initial_owner);
    }

    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
    }
}
