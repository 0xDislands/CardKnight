use starknet::ContractAddress;
use dojo::world::{IWorld, IWorldDispatcher, IWorldDispatcherTrait};
use card_knight::config::{level::EXP_TO_LEVEL_UP};
use card_knight::models::skill::{Skill, PlayerSkill};


#[derive(Serde, Drop, Copy, PartialEq, Introspect)]
enum Hero {
    Knight,
    Shaman,
    Vampire
}

#[derive(Copy, Drop, Serde, PartialEq)]
#[dojo::model]
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
    total_xp: u32,
    level: u32,
    high_score: u32,
    sequence: u32,
    alive: bool,
    poisoned: u32,
    turn: u32,
    heroId: Hero
}

#[generate_trait]
impl IPlayerImpl of IPlayer {
    fn level_up(ref self: Player, option: LevelUpOptions) {
        match option {
            LevelUpOptions::IncreaseMaxHp => { self.max_hp += 1; },
            LevelUpOptions::AddHp => { self.hp += 1; },
            LevelUpOptions::IncreaseMaxArmour => { self.max_shield += 1; },
            LevelUpOptions::AddArmour => { self.shield += 1; }
        }
    }

    fn add_exp(ref self: Player, value: u32) {
        if value == 0 {
            return ();
        }

        self.exp += value;
        self.total_xp += value;
        if (self.exp > EXP_TO_LEVEL_UP) {
            self.exp = 0;
            self.level += 1;
            self.level_up(LevelUpOptions::IncreaseMaxHp);
        }
    }

    fn take_damage(ref self: Player, mut damage: u32) {
        if damage == 0 {
            return ();
        }

        if (self.shield > 0) {
            if (self.shield <= damage) {
                damage -= self.shield;
                self.shield = 0;
            } else {
                damage = 0;
                self.shield -= damage;
            };
        }
        self.hp = if (self.hp < damage) {
            0
        } else {
            self.hp - damage
        };
        if (self.hp == 0) {
            self.alive = false;
        }
    }
    fn heal(ref self: Player, value: u32) {
        self.hp = if (self.hp + value > self.max_hp) {
            self.max_hp
        } else {
            self.hp + value
        };
    }

    fn set_init_hero(ref self: Player) {
        match self.heroId {
            Hero::Knight => { self.hp = 10 },
            Hero::Shaman => { self.hp = 8 },
            Hero::Vampire => { self.hp = 9 },
        }
    }

    fn validate_skill(self: @Player, skill: Skill) {
        match self.heroId {
            Hero::Knight => {
                assert(
                    skill == Skill::PowerupSlash
                        || skill == Skill::Teleport
                        || skill == Skill::Regeneration,
                    'Invalid hero skill'
                );
            },
            Hero::Shaman => {
                assert(
                    skill == Skill::Hex || skill == Skill::Shuffle || skill == Skill::Meteor,
                    'Invalid hero skill'
                );
            },
            Hero::Vampire => {
                assert(
                    skill == Skill::LifeSteal || skill == Skill::Teleport || skill == Skill::Curse,
                    'Invalid hero skill'
                );
            },
        }
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
