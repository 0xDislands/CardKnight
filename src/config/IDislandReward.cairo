use starknet::ContractAddress;

#[dojo::interface]
pub trait IDislandReward {
    fn add_xdil(ref world: IWorldDispatcher, player: ContractAddress, score: u128);
}
