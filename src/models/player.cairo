use starknet::ContractAddress;
use dojo::world::{IWorld, IWorldDispatcher, IWorldDispatcherTrait};
use card_knight::config::EXP_TO_LEVEL_UP;

#[derive(Model, Copy, Drop, Serde, PartialEq)]
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
    level: u32,
    high_score: u32,
    sequence: u32,
}

#[generate_trait]
impl IPlayerImpl of IPlayer {

    fn level_up(world: IWorldDispatcher, player: Player, option: LevelUpOptions) {
        let mut new_player = player;
        match option {
            LevelUpOptions::IncreaseMaxHp => {
                new_player.max_hp += 1;
            },
            LevelUpOptions::AddHp => {
                new_player.hp += 1;
            },
            LevelUpOptions::IncreaseMaxArmour => {
                new_player.max_shield += 1;
            },
            LevelUpOptions::AddArmour => {
                new_player.shield += 1;
            }
        }
        set!(world, (new_player));
    }

    fn add_exp(world: IWorldDispatcher, player: Player) {
        let mut new_player = player;
        new_player.exp += 1;
        if (new_player.exp > EXP_TO_LEVEL_UP) {
            new_player.exp = 0;
            new_player.level += 1;
            IPlayerImpl::level_up(world, new_player, LevelUpOptions::IncreaseMaxHp);
        }
        set!(world, (new_player));
    }
}

#[derive(Serde, Drop, Copy, PartialEq, Introspect)]
enum LevelUpOptions {
    IncreaseMaxHp,
    AddHp,
    IncreaseMaxArmour,
    AddArmour
}

impl GameStatusFelt252 of Into<LevelUpOptions, felt252> {
    fn into(self: LevelUpOptions) -> felt252 {
        match self {
            LevelUpOptions::IncreaseMaxHp => 0,
            LevelUpOptions::AddHp => 1,
            LevelUpOptions::IncreaseMaxArmour => 2,
            LevelUpOptions::AddArmour => 3,
        }
    }
}
