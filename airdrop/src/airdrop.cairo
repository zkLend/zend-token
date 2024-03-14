use core::array::Span;

use starknet::{ContractAddress};

use airdrop::interfaces::erc20::{IERC20Dispatcher};


#[starknet::interface]
pub trait IAirdrop<TContractState> {
    // Return the root of the airdrop
    fn get_root(self: @TContractState) -> felt252;

    // Return the token being dropped
    fn get_token(self: @TContractState) -> IERC20Dispatcher;

    // Return the claiming start time
    fn get_start_time(self: @TContractState) -> u64;

    // Return the vesting peroid duration in seconds
    fn get_vesting_duration(self: @TContractState) -> u64;

    // Return the claimed amount of a recipient
    fn get_claimed_amount(self: @TContractState, recipient: ContractAddress) -> u128;

    // Calculates the total claimable amount based on timestamp alone
    fn calculate_total_claimable(self: @TContractState, total_amount: u128) -> u128;

    // Claim the airdrop.
    // The `total_amount` sent in here is the total allocation amount, which is subject to vesting.
    // Therefore, users will likely receive smaller amounts depending on when they claim.
    // Returns true iif amount _actually_ claimed is larger than 0.
    fn claim(
        ref self: TContractState,
        recipient: ContractAddress,
        total_amount: u128,
        proof: Span<felt252>
    ) -> bool;
}

#[starknet::contract]
pub mod Airdrop {
    use core::array::{ArrayTrait, SpanTrait};
    use core::hash::{LegacyHash};
    use core::num::traits::one::{One};
    use core::num::traits::zero::{Zero};
    use core::poseidon::hades_permutation;

    use starknet::{ContractAddress, get_block_timestamp};

    use airdrop::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};

    use super::{IAirdrop};

    #[storage]
    struct Storage {
        root: felt252,
        token: IERC20Dispatcher,
        start_time: u64,
        vesting_duration: u64,
        claimed_amounts: LegacyMap<ContractAddress, u128>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Claimed: Claimed,
    }

    #[derive(Drop, starknet::Event)]
    struct Claimed {
        recipient: ContractAddress,
        amount: u128,
        total_amount: u128
    }


    #[constructor]
    fn constructor(
        ref self: ContractState,
        token: IERC20Dispatcher,
        root: felt252,
        start_time: u64,
        vesting_duration: u64
    ) {
        self.root.write(root);
        self.token.write(token);
        self.start_time.write(start_time);
        self.vesting_duration.write(vesting_duration);
    }

    #[abi(embed_v0)]
    impl AirdropImpl of IAirdrop<ContractState> {
        fn get_root(self: @ContractState) -> felt252 {
            self.root.read()
        }

        fn get_token(self: @ContractState) -> IERC20Dispatcher {
            self.token.read()
        }

        fn get_start_time(self: @ContractState) -> u64 {
            self.start_time.read()
        }

        fn get_vesting_duration(self: @ContractState) -> u64 {
            self.vesting_duration.read()
        }

        fn get_claimed_amount(self: @ContractState, recipient: ContractAddress) -> u128 {
            self.claimed_amounts.read(recipient)
        }

        fn calculate_total_claimable(self: @ContractState, total_amount: u128) -> u128 {
            calculate_claimable_amount(self, total_amount)
        }

        fn claim(
            ref self: ContractState,
            recipient: ContractAddress,
            total_amount: u128,
            proof: Span<felt252>
        ) -> bool {
            assert(Zeroable::is_non_zero(total_amount), 'ZERO_TOTAL_AMOUNT');
            assert(get_block_timestamp() >= self.start_time.read(), 'AIRDROP_NOT_STARTED');

            let (leaf, _, _) = hades_permutation(recipient.into(), total_amount.into(), 2);
            assert(self.root.read() == compute_pedersen_root(leaf, proof), 'INVALID_PROOF');

            let total_claimable_amount = calculate_claimable_amount(@self, total_amount);
            let already_claimed_amount = self.claimed_amounts.read(recipient);

            if total_claimable_amount > already_claimed_amount {
                let current_amount_claimed = total_claimable_amount - already_claimed_amount;
                self.claimed_amounts.write(recipient, total_claimable_amount);

                self
                    .emit(
                        Event::Claimed(
                            Claimed {
                                recipient: recipient,
                                amount: current_amount_claimed,
                                total_amount: total_amount
                            }
                        )
                    );

                self.token.read().transfer(recipient, current_amount_claimed.into());

                true
            } else {
                self
                    .emit(
                        Event::Claimed(
                            Claimed { recipient: recipient, amount: 0, total_amount: total_amount }
                        )
                    );

                false
            }
        }
    }

    fn compute_pedersen_root(current: felt252, mut proof: Span<felt252>) -> felt252 {
        match proof.pop_front() {
            Option::Some(proof_element) => {
                compute_pedersen_root(hash_function(current, *proof_element), proof)
            },
            Option::None => { current },
        }
    }

    fn hash_function(a: felt252, b: felt252) -> felt252 {
        let a_u256: u256 = a.into();
        if a_u256 < b.into() {
            core::pedersen::pedersen(a, b)
        } else {
            core::pedersen::pedersen(b, a)
        }
    }

    fn calculate_claimable_amount(self: @ContractState, total_amount: u128) -> u128 {
        let current_time = get_block_timestamp();
        let start_time = self.start_time.read();

        if current_time < start_time {
            0
        } else {
            let duration_elapsed = current_time - start_time;
            let vesting_duration = self.vesting_duration.read();

            if duration_elapsed >= vesting_duration {
                // All vested already
                total_amount
            } else {
                // Hard-coded to be 25% of total amount
                let unlocked_amount = total_amount / 4;
                let vesting_amount = total_amount - unlocked_amount;

                let vested_amount = vesting_amount
                    * duration_elapsed.into()
                    / vesting_duration.into();

                unlocked_amount + vested_amount
            }
        }
    }
}
