use starknet::ContractAddress;
use card_knight::config::map::{MAP_RANGE};
use card_knight::models::player::{Player, IPlayer, Hero};
use card_knight::models::card::{Card, ICardTrait};
use dojo::model::{ModelStorage, ModelValueStorage};
use dojo::world::{IWorld, IWorldDispatcher, IWorldDispatcherTrait, WorldStorage};


#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct Game {
    #[key]
    game_id: u32,
    #[key]
    player: ContractAddress,
    highest_score: u64,
    game_state: GameState,
}

#[derive(Serde, Drop, Copy, PartialEq, Introspect)]
enum GameState {
    None,
    Playing,
    Win,
    Lose,
    WaitingForLevelUpOption,
}

#[derive(Serde, Drop, Copy, PartialEq, Introspect)]
enum Direction {
    Up,
    Down,
    Left,
    Right,
}

#[derive(Serde, Drop, Copy, PartialEq, Introspect)]
enum TagType {
    None,
    Growth,
    NoMagic,
    Revenge,
    NoHope,
    Silent,
}

// set contracts
// 0 -> second owner
// 1-> ref contract
// 2-> reward contract

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct Contracts {
    #[key]
    index: u128,
    address: ContractAddress,
}


fn apply_tag_effects(mut world_storage: WorldStorage, player: Player) {
    let mut x: u32 = 0;
    let mut y: u32 = 0;
    while x <= MAP_RANGE {
        while y <= MAP_RANGE {
            // Read the card model at the given coordinates
            let mut card: Card = world_storage.read_model((player.game_id, x, y));

            // Apply tag effects based on the card's tag
            match card.tag {
                TagType::None => {},
                TagType::Growth => {
                    card.apply_growth_tag();
                    world_storage.write_model(@card); // Write the modified card back to storage
                },
                TagType::NoMagic => {},
                TagType::Revenge => {
                    card.apply_revenge_tag();
                    world_storage.write_model(@card); // Write the modified card back to storage
                },
                TagType::NoHope => {},
                TagType::Silent => {},
            };

            y += 1;
        };
        y = 0;
        x += 1;
    };
}


fn is_silent(world_storage: WorldStorage, player: Player) -> bool {
    let mut x: u32 = 0;
    let mut y: u32 = 0;
    let mut any_silent = false;

    while x <= MAP_RANGE {
        while y <= MAP_RANGE {
            // Read the card model at the given coordinates
            let card: Card = world_storage.read_model((player.game_id, x, y));

            // Check if the card's tag is Silent
            if card.tag == TagType::Silent {
                any_silent = true;
            }

            y += 1;
        };
        y = 0;
        x += 1;
    };
    any_silent
}

