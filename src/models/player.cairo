use starknet::ContractAddress;
use card_knight::config::level;
use card_knight::models::skill::{Skill, PlayerSkill};

use dojo::model::{ModelStorage, ModelValueStorage};
use dojo::world::{IWorld, IWorldDispatcher, IWorldDispatcherTrait, WorldStorage};

#[derive(Serde, Drop, Copy, PartialEq, Introspect)]
enum Hero {
    Knight,
    Shaman,
    Vampire,
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
    heroId: Hero,
}

#[derive(Copy, Drop, Serde, PartialEq)]
#[dojo::model]
struct WeeklyIndex {
    #[key]
    week: u64,
    #[key]
    player: ContractAddress,
    index: u128,
}

#[derive(Copy, Drop, Serde, PartialEq)]
#[dojo::model]
struct Scores {
    // keep weekly scores
    #[key]
    week: u64,
    #[key]
    index: u128,
    player: ContractAddress,
    high_score: u32,
}

#[derive(Copy, Drop, Serde, PartialEq)]
#[dojo::model]
struct TotalWeeklyPlayers {
    // keep weekly scores
    #[key]
    week: u64,
    total: u128,
}

#[derive(Copy, Drop, Serde, PartialEq)]
#[dojo::model]
struct WeeklyWinner {
    #[key]
    week: u64,
    address: ContractAddress,
    score: u32,
}


#[generate_trait]
impl IPlayerImpl of IPlayer {
    fn level_up(ref self: Player, upgrade: u32) {
        match self.level {
            0 => {},
            1 => {
                assert(self.total_xp >= level::LEVEL2_XP, 'Cant level up');
                self.exp = self.total_xp - level::LEVEL2_XP;
                if (upgrade == 1) {
                    let new_max_hp = self.max_hp + self.max_hp * level::LEVEL2_UP1 / 10;
                    self.max_hp = new_max_hp;
                } else {
                    let heal = self.max_hp * level::LEVEL2_UP2 / 10;
                    self.heal(heal);
                }
            },
            2 => {
                assert(self.total_xp >= level::LEVEL3_XP, 'Cant level up');
                self.exp = self.total_xp - level::LEVEL3_XP;
                if (upgrade == 1) {
                    let new_max = self.max_shield + self.max_shield * level::LEVEL3_UP1 / 10;
                    self.max_shield = new_max;
                } else {
                    self.heal(self.max_hp);
                }
            },
            3 => {
                assert(self.total_xp >= level::LEVEL4_XP, 'Cant level up');
                self.exp = self.total_xp - level::LEVEL4_XP;
                if (upgrade == 1) {
                    let new_max_hp = self.max_hp + self.max_hp * level::LEVEL4_UP1 / 10;
                    self.max_hp = new_max_hp;
                } else {
                    self.heal(level::LEVEL4_UP2);
                }
            },
            4 => {
                assert(self.total_xp >= level::LEVEL5_XP, 'Cant level up');
                self.exp = self.total_xp - level::LEVEL5_XP;
                if (upgrade == 1) {
                    let new_max = self.max_shield + self.max_shield * level::LEVEL5_UP1 / 10;
                    self.max_shield = new_max;
                } else {
                    self.heal(self.max_hp);
                }
            },
            5 => {
                assert(self.total_xp >= level::LEVEL6_XP, 'Cant level up');
                self.exp = self.total_xp - level::LEVEL6_XP;
                if (upgrade == 1) {
                    let new_max = self.max_shield + self.max_shield * level::LEVEL6_UP1 / 10;
                    self.max_hp = new_max;
                } else {
                    self.heal(self.max_hp);
                }
            },
            _ => {
                let expected_xp = level::LEVEL6_XP + (self.level - 5) * level::LEVEL7_PLUS;
                assert(self.total_xp >= expected_xp, 'Cant level up');
                self.exp = self.total_xp - expected_xp;
                if (upgrade == 1) {
                    self.shield = self.max_shield;
                } else {
                    self.heal(self.max_hp);
                }
            },
        }
        self.level += 1;
    }


    fn add_exp(ref self: Player, value: u32) {
        if value == 0 {
            return ();
        }
        self.exp += value;
        self.total_xp += value;
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
                self.shield -= damage;
                damage = 0;
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
                    'Invalid Knight skill',
                );
            },
            Hero::Shaman => {
                assert(
                    skill == Skill::Hex || skill == Skill::Shuffle || skill == Skill::Meteor,
                    'Invalid Shaman skill',
                );
            },
            Hero::Vampire => {
                assert(
                    skill == Skill::LifeSteal || skill == Skill::Teleport || skill == Skill::Curse,
                    'Invalid Vampire skill',
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
    AddArmour,
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
