use starknet::ContractAddress;
use dojo::world::{IWorld, IWorldDispatcher, IWorldDispatcherTrait};
use card_knight::config::level::{
    FIRE_SKILL_LEVEL, SKILL_CD, SLASH_SKILL_LEVEL, METEOR_SKILL_LEVEL, SWAP_SKILL_LEVEL
};
use card_knight::models::game::{Direction};

use card_knight::config::map::{MAP_RANGE};
use card_knight::models::{card::{Card, CardIdEnum, ICardImpl, ICardTrait}, player::Player};
#[derive(Serde, Drop, Copy, PartialEq, Introspect)]
enum Skill {
    SkillFire,
    PowerupSlash,
    Meteor,
    Swap
}

#[derive(Copy, Drop, Serde, PartialEq)]
#[dojo::model]
struct PlayerSkill {
    #[key]
    game_id: u32,
    #[key]
    player: ContractAddress,
    #[key]
    skill: Skill,
    last_use: u32,
}

impl SkillFelt252 of Into<Skill, felt252> {
    fn into(self: Skill) -> felt252 {
        match self {
            Skill::SkillFire => 1,
            Skill::PowerupSlash => 2,
            Skill::Meteor => 3,
            Skill::Swap => 4
        }
    }
}

#[generate_trait]
impl IPlayerSkillImpl of IPlayerSkill {
    fn is_active(self: @PlayerSkill, level: u32) -> bool {
        let is_active = match self.skill {
            Skill::SkillFire => if (level >= FIRE_SKILL_LEVEL) {
                true
            } else {
                false
            },
            Skill::PowerupSlash => if (level >= SLASH_SKILL_LEVEL) {
                true
            } else {
                false
            },
            Skill::Meteor => if (level >= METEOR_SKILL_LEVEL) {
                true
            } else {
                false
            },
            Skill::Swap => if (level >= SWAP_SKILL_LEVEL) {
                true
            } else {
                false
            },
            _ => false
        };
        is_active
    }

    fn use_skill(self: @PlayerSkill, player: Player, skill: Skill, world: IWorldDispatcher) {
        if (skill == Skill::SkillFire) {
            assert(*self.last_use + SKILL_CD <= player.turn, 'Skill cooldown');

            let mut x: u32 = 0;
            let mut y: u32 = 0;
            while x <= MAP_RANGE {
                while y <= MAP_RANGE {
                    let mut card = get!(world, (player.game_id, x, y), (Card));
                    if (card.is_monster()) {
                        card.hp -= 1;
                        if (card.hp == 0) {
                            ICardImpl::spawn_card(world, player.game_id, card.x, card.y, player);
                        } else {
                            set!(world, (card));
                        }
                    }

                    y = y + 1;
                };
                x = x + 1;
            };
        } else if (skill == Skill::PowerupSlash) {
            assert(*self.last_use + SKILL_CD <= player.turn, 'Skill cooldown');
            let mut neighbour_cards: Array<Card> = ICardTrait::get_all_neighbours(
                world, player.game_id, player.x, player.y
            );
            let arr_len = neighbour_cards.len();

            let mut i = 0;
            while i < arr_len {
                let mut card = *neighbour_cards.at(i);

                if (card.is_monster()) {
                    let damage = card.max_hp / 4 + 1;
                    if (card.hp <= damage) {
                        ICardImpl::spawn_card(world, player.game_id, card.x, card.y, player);
                    } else {
                        card.hp = card.hp - damage;
                        set!(world, (card));
                    }
                }
            }
        }
        if (skill == Skill::Meteor) {
            assert(*self.last_use + SKILL_CD <= player.turn, 'Skill cooldown');

            let mut x: u32 = 0;
            let mut y: u32 = 0;
            let damage = player.max_hp;
            while x <= MAP_RANGE {
                while y <= MAP_RANGE {
                    let mut card = get!(world, (player.game_id, x, y), (Card));
                    if (card.is_monster()) {
                        if (card.hp < damage) {
                            ICardImpl::spawn_card(world, player.game_id, card.x, card.y, player);
                        } else {
                            card.hp -= damage;
                            set!(world, (card));
                        }
                    }

                    y = y + 1;
                };
                x = x + 1;
            };
        }
    }

    fn use_swap_skill(
        self: @PlayerSkill,
        mut player: Player,
        skill: Skill,
        world: IWorldDispatcher,
        direction: Direction
    ) {
        assert(skill == Skill::Swap, 'Not swap skil');
        assert(*self.last_use + SKILL_CD <= player.turn, 'Skill cooldown');
        let mut player_card = get!(world, (player.game_id, player.x, player.y), (Card));
        let (next_x, next_y) = match direction {
            Direction::Up => { (player.x, player.y + 1) },
            Direction::Down => { (player.x, player.y - 1) },
            Direction::Left => { (player.x - 1, player.y) },
            Direction::Right => { (player.x + 1, player.y) }
        };
        let mut move_card = get!(world, (player.game_id, next_x, next_y), (Card));
        move_card.x = player_card.x;
        move_card.y = player_card.y;
        player_card.x = next_x;
        player_card.y = next_y;
        player.x = next_x;
        player.y = next_y;
        set!(world, (move_card));
        set!(world, (player_card));
        set!(world, (player));
    }
}
