use array::ArrayTrait;
use debug::PrintTrait;
use starknet::ContractAddress;
use cubit::f64::types::vec3::{Vec3};
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

#[derive(Model, Copy, Drop, Serde)]
struct Card {
    #[key]
    game_id: u32,
    #[key]
    x: u32,
    #[key]
    y: u32,
    card_type: CardType,
    hp: u32,
    max_hp: u32,
    shield: u32,
    max_shield: u32
}

#[derive(Model, Copy, Drop, Serde)]
struct Game {
    #[key]
    game_id: u32,
    #[key]
    player: ContractAddress,
    highest_score: u64
}

#[derive(Model, Copy, Drop, Serde)]
struct Player {
    #[key]
    game_id: u32,
    #[key]
    player: ContractAddress,
    x: u32,
    y: u32,
    hp: u32,
    max_hp: u32,
    shield: u32,
    max_shield: u32,
    exp: u32,
    high_score: u32,
    total_moves: u32,
}

#[derive(Serde, Drop, Copy, PartialEq, Introspect)]
enum CardType {
    Player,
    Monster,
    Item,
    Hidden,
    None,
}

#[derive(Serde, Drop, Copy, PartialEq, Introspect)]
enum Direction {
    Up,
    Down,
    Left,
    Right,
}