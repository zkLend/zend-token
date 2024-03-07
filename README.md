<p align="center">
  <h1 align="center">zend-token</h1>
</p>

**ZEND token implementation**

## L1 token

The [L1 token contract](./l1/ZendToken.sol) is a simple child contract of the OpenZeppelin reference ERC20 implementation.

### Prerequisites

Install [Foundry](https://github.com/foundry-rs/foundry) for Solidity compilation. Check your Foundry installation with:

```console
forge --version
```

### Building

To build the contract simply run:

```console
forge build
```

Built artifacts will be available in the `./out` folder.

## L2 token

The L2 token contract is _not_ manually deployed. Instead, it's automatically deployed by the [L2 token bridge contract](https://github.com/starknet-io/starkgate-contracts/blob/d62a255307d2f3de65665f18316766a2c69ead78/src/cairo/token_bridge.cairo) when a [permissionless token enrollment](https://docs.starknet.io/documentation/tools/starkgate-adding_a_token/) is triggered on the [L1 token bridge manager contract](https://github.com/starknet-io/starkgate-contracts/blob/d62a255307d2f3de65665f18316766a2c69ead78/src/solidity/StarkgateManager.sol). Therefore, the L2 token contract code to be deployed is completely up to the official StarkGate configuration. Any L2 token contract instance deployed this way is mintable only from the bridge contract.

> [!NOTE]
>
> As of this writing, the L2 token _class hash_ deployed by StarkGate is [`0x05ffbcfeb50d200a0677c48a129a11245a3fc519d1d98d76882d1c9a1b19c6ed`](https://starkscan.co/class/0x05ffbcfeb50d200a0677c48a129a11245a3fc519d1d98d76882d1c9a1b19c6ed).

Despite our lack of control over the implementation, the token contract is still [reproduced here](./l2/openzeppelin/token/erc20_v070/erc20.cairo) (along with dependencies) from its [upstream source](https://github.com/starknet-io/starkgate-contracts/blob/d62a255307d2f3de65665f18316766a2c69ead78/src/openzeppelin/token/erc20_v070/erc20.cairo) for reference.

Additionally, due to the fact that none of the major Starknet block explorers offer Cairo 1 contract verification as of this writing, this repo provides tools for [deterministic compilation](#deterministic-compilation-with-docker) as a means of [verification](#verifying-class-hash).

### Building directly

With the `starknet-compile` command from [starkware-libs/cairo](https://github.com/starkware-libs/cairo) installed, run:

```console
mkdir -p ./build
starknet-compile . -c openzeppelin::token::erc20_v070::erc20::ERC20 ./build/ERC20.json
```

> [!TIP]
>
> You must install `v2.3.0` or newer for `starknet-compile` to be able to compile successfully.

The compiled contract is available at `./build/ERC20.json`.

### Deterministic compilation with Docker

To ensure deterministic compilation output, a [script](./scripts/compile_l2_with_docker.sh) is provided that generates the exact same class as the one used in production:

```console
./scripts/compile_l2_with_docker.sh
```

The compiled contract is available at `./build/ERC20.json`.

### Verifying class hash

Either [built directly](#building-directly) or [with Docker](#deterministic-compilation-with-docker), you may verify that the class hash of the compiled contract artifact with the `starkli class-hash` command from [Starkli](https://github.com/xJonathanLEI/starkli).

## Deployed addresses

This section lists deployed contract addresses.

### Mainnet

- Ethereum: [0xb2606492712D311be8f41d940AFE8CE742A52D44](https://etherscan.io/address/0xb2606492712D311be8f41d940AFE8CE742A52D44)
- Starknet: [0x00585c32b625999e6e5e78645ff8df7a9001cf5cf3eb6b80ccdd16cb64bd3a34](https://starkscan.co/contract/0x00585c32b625999e6e5e78645ff8df7a9001cf5cf3eb6b80ccdd16cb64bd3a34)

## License

Licensed under either of

- Apache License, Version 2.0 ([LICENSE-APACHE](./LICENSE-APACHE) or <http://www.apache.org/licenses/LICENSE-2.0>)
- MIT license ([LICENSE-MIT](./LICENSE-MIT) or <http://opensource.org/licenses/MIT>)

at your option, except the content in [`./l2/`](./l2/), which is licensed with its upstream source.
