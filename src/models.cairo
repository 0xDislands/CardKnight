use array::ArrayTrait;
use debug::PrintTrait;
use starknet::ContractAddress;
use cubit::f64::types::vec3::{Vec3};

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

trait CardTrait {
    fn apply_effect(player: Player, card: Card) -> Player;
}

impl CardImpl of CardTrait {
    fn apply_effect(player: Player, card: Card) -> Player {
        let mut ref_player = player;
        match card.card_type {
            CardType::Monster => {
                let mut damage = card.hp;
                if (ref_player.shield > 0) {
                    if (ref_player.shield - damage <= 0) {
                        damage -= ref_player.shield;
                        ref_player.shield = 0;
                        ref_player.hp -= damage;
                    }
                    else {
                        ref_player.shield -= damage;
                    };
                } else {
                    // if remain_hp <= 0 ## This WILL BE WRITTEN WHEN MOVEMENT LOGIC IS FINISHED
                    ref_player.hp = ref_player.hp - card.hp;
                };
                return ref_player;
            },
            CardType::Player => {
                return ref_player;
            },
            CardType::Item => {
                return ref_player;
            },
            CardType::Hidden => {
                return ref_player;
            },
            CardType::None => {
                return ref_player;
            }
        }
    }
}