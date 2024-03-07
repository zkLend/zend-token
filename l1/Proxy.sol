// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity =0.8.21;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// This contract exists only to bring `ProxyAdmin` and `TransparentUpgradeableProxy` into scope.
contract Proxy {}
