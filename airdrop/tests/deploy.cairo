use array::ArrayTrait;
use option::OptionTrait;
use result::ResultTrait;
use traits::{Into, TryInto};

use starknet::ContractAddress;
use starknet::syscalls::deploy_syscall;

use governance::{airdrop::{Airdrop, IAirdropDispatcher}, interfaces::erc20::{IERC20Dispatcher}};

use tests::mock;


fn deploy_airdrop(token: ContractAddress, root: felt252) -> IAirdropDispatcher {
    let (contract_address, _) = deploy_syscall(
        Airdrop::TEST_CLASS_HASH.try_into().unwrap(), 0, array![token.into(), root].span(), false
    )
        .unwrap();

    IAirdropDispatcher { contract_address }
}

fn deploy_erc20(
    name: felt252, symbol: felt252, decimals: u8, initial_supply: u256, recipient: ContractAddress
) -> IERC20Dispatcher {
    let (contract_address, _) = deploy_syscall(
        mock::erc20::ERC20::TEST_CLASS_HASH.try_into().unwrap(),
        0,
        array![
            name,
            symbol,
            decimals.into(),
            initial_supply.low.into(),
            initial_supply.high.into(),
            recipient.into()
        ]
            .span(),
        false
    )
        .unwrap();

    IERC20Dispatcher { contract_address }
}
