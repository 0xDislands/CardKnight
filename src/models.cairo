use array::ArrayTrait;
use debug::PrintTrait;
use starknet::ContractAddress;
use cubit::f64::types::vec3::{Vec3};

#[derive(Model, Copy, Drop, Serde)]
struct Card {
    #[key]
    game_id: u32,
    #[key]
    x: u8,
    #[key]
    y: u8,
    card: CardType,
    health: u32,
    armor: u32,
    exp: u32,
}

#[derive(Model, Copy, Drop, Serde)]
struct Game {
    #[key]
    game_id: u32,
    #[key]
    player: ContractAddress,
    highest_score: u64,
}

#[derive(Model, Copy, Drop, Serde)]
struct Player {
    #[key]
    game_id: u32,
    #[key]
    player: ContractAddress,
    health: u64,
    armor: u64,
    exp: u64,
    high_score: u64
    total_moves: u64,
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