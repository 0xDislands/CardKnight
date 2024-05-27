use starknet::ContractAddress;

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct Game {
    #[key]
    game_id: u32,
    #[key]
    player: ContractAddress,
    highest_score: u64,
    game_state: GameState
}

#[derive(Serde, Drop, Copy, PartialEq, Introspect)]
enum GameState {
    None,
    Playing,
    Win,
    Lose,
    WaitingForLevelUpOption
}

#[derive(Serde, Drop, Copy, PartialEq, Introspect)]
enum Direction {
    Up,
    Down,
    Left,
    Right,
}