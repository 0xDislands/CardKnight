use card_knight::models::player::{Hero, Player};
use starknet::ContractAddress;


// Player Config
const PLAYER_STARTING_POINT: (u32, u32) =
    (1, 1); // 3x3 board, start by (0,0) -> 1,1 is middle board 


fn default_player(
    player_address: ContractAddress, game_id: u32, x: u32, y: u32, hero: Hero
) -> Player {
    let hp = match hero {
        Hero::Knight => { 10 },
        Hero::Shaman => { 8 },
        Hero::Vampire => { 9 },
    };

    let player = Player {
        game_id,
        player_address,
        x: x,
        y: y,
        hp: hp,
        max_hp: hp,
        shield: 0,
        max_shield: 10,
        exp: 0,
        total_xp: 0,
        level: 1,
        high_score: 0,
        sequence: 0,
        alive: true,
        poisoned: 0,
        turn: 0,
        heroId: hero
    };
    player
}
