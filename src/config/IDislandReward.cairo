use starknet::ContractAddress;

#[starknet::interface]
pub trait IDislandReward<T> {
    fn add_xdil(ref self: T, player: ContractAddress, score: u128);
}
