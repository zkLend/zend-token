use core::poseidon::hades_permutation;

use starknet::testing::{pop_log};
use starknet::{
    get_contract_address, syscalls::{deploy_syscall}, ClassHash, contract_address_const,
    ContractAddress
};

use airdrop::airdrop::{Airdrop, IAirdropDispatcher, IAirdropDispatcherTrait};
use airdrop::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};

use tests::deploy::{deploy_airdrop, deploy_erc20};
use tests::mock::erc20::ERC20::Transfer;

fn deploy_token(name: felt252, symbol: felt252, initial_supply: u128) -> IERC20Dispatcher {
    deploy_erc20(name, symbol, 18, initial_supply.into(), get_contract_address())
}

fn hash_claim(recipient: ContractAddress, total_amount: u128) -> felt252 {
    let (leaf, _, _) = hades_permutation(recipient.into(), total_amount.into(), 2);
    leaf
}


#[test]
fn test_claim_single_recipient() {
    starknet::testing::set_block_timestamp(10000);

    let token = deploy_token('AIRDROP', 'AD', 100);
    let recipient = contract_address_const::<2345>();

    let leaf = hash_claim(recipient, 100);

    let airdrop = deploy_airdrop(token.contract_address, leaf, 10000, 100);

    token.transfer(airdrop.contract_address, 100);

    assert_eq!(airdrop.claim(recipient, 100, array![].span()), true);

    let log = pop_log::<Airdrop::Claimed>(airdrop.contract_address).unwrap();
    assert_eq!(log.recipient, recipient);
    assert_eq!(log.amount, 25);
    assert_eq!(log.total_amount, 100);

    assert_eq!(token.balanceOf(recipient), 25);
    assert_eq!(token.balanceOf(airdrop.contract_address), 75);

    // Claiming again on the same timestamp yields no more tokens

    assert_eq!(airdrop.claim(recipient, 100, array![].span()), false);

    let log = pop_log::<Airdrop::Claimed>(airdrop.contract_address).unwrap();
    assert_eq!(log.recipient, recipient);
    assert_eq!(log.amount, 0);
    assert_eq!(log.total_amount, 100);

    assert_eq!(token.balanceOf(recipient), 25);
    assert_eq!(token.balanceOf(airdrop.contract_address), 75);

    // 1/5 time passsed

    starknet::testing::set_block_timestamp(10020);

    assert_eq!(airdrop.claim(recipient, 100, array![].span()), true);

    let log = pop_log::<Airdrop::Claimed>(airdrop.contract_address).unwrap();
    assert_eq!(log.recipient, recipient);
    assert_eq!(log.amount, 15);
    assert_eq!(log.total_amount, 100);

    assert_eq!(token.balanceOf(recipient), 40);
    assert_eq!(token.balanceOf(airdrop.contract_address), 60);

    // Again, claiming again on the same timestamp yields no more tokens

    assert_eq!(airdrop.claim(recipient, 100, array![].span()), false);

    let log = pop_log::<Airdrop::Claimed>(airdrop.contract_address).unwrap();
    assert_eq!(log.recipient, recipient);
    assert_eq!(log.amount, 0);
    assert_eq!(log.total_amount, 100);

    assert_eq!(token.balanceOf(recipient), 40);
    assert_eq!(token.balanceOf(airdrop.contract_address), 60);

    // Another 1/5 time passsed

    starknet::testing::set_block_timestamp(10040);

    assert_eq!(airdrop.claim(recipient, 100, array![].span()), true);

    let log = pop_log::<Airdrop::Claimed>(airdrop.contract_address).unwrap();
    assert_eq!(log.recipient, recipient);
    assert_eq!(log.amount, 15);
    assert_eq!(log.total_amount, 100);

    assert_eq!(token.balanceOf(recipient), 55);
    assert_eq!(token.balanceOf(airdrop.contract_address), 45);

    // Passed the entire vesting duration

    starknet::testing::set_block_timestamp(20000);

    assert_eq!(airdrop.claim(recipient, 100, array![].span()), true);

    let log = pop_log::<Airdrop::Claimed>(airdrop.contract_address).unwrap();
    assert_eq!(log.recipient, recipient);
    assert_eq!(log.amount, 45);
    assert_eq!(log.total_amount, 100);

    assert_eq!(token.balanceOf(recipient), 100);
    assert_eq!(token.balanceOf(airdrop.contract_address), 0);
}
