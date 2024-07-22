use starknet::ContractAddress;
use dojo::world::{IWorld, IWorldDispatcher, IWorldDispatcherTrait};
use card_knight::config::level::{
    FIRE_SKILL_LEVEL, SKILL_CD, SLASH_SKILL_LEVEL, METEOR_SKILL_LEVEL, SWAP_SKILL_LEVEL,
    SKILL_LEVEL, BIG_SKILL_CD,
};
use card_knight::models::game::{Direction, TagType};

use card_knight::config::map::{MAP_RANGE};
use card_knight::models::{card::{Card, CardIdEnum, ICardImpl, ICardTrait}, player::Player};
use card_knight::utils::random_index;

#[derive(Serde, Drop, Copy, PartialEq, Introspect)]
enum Skill {
    PowerupSlash,
    Teleport, //     Swap
    Hex,
    Regeneration,
    LifeSteal,
    Shuffle,
    UnfairTrade,
    Curse,
    SkillFire,
    Meteor,
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


#[generate_trait]
impl IPlayerSkillImpl of IPlayerSkill {
    fn is_active(self: @PlayerSkill, level: u32) -> bool {
        level >= SKILL_LEVEL
    }


    fn use_skill(
        self: @PlayerSkill,
        mut player: Player,
        skill: Skill,
        world: IWorldDispatcher,
        direction: Direction
    ) {
        if (skill == Skill::SkillFire) {
            assert(*self.last_use + SKILL_CD <= player.turn, 'Skill cooldown');

            let mut x: u32 = 0;
            let mut y: u32 = 0;
            while x <= MAP_RANGE {
                while y <= MAP_RANGE {
                    let mut card = get!(world, (player.game_id, x, y), (Card));
                    if (card.is_monster() && card.tag != TagType::NoMagic) {
                        card.hp -= card.hp / 4;
                        if (card.hp == 0) {
                            if (card.card_id == CardIdEnum::Boss1) {
                                ICardImpl::flip_cards(world, player.game_id, false);
                            }
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

                if (card.is_monster() && card.tag != TagType::NoMagic) {
                    let damage = card.max_hp / 4 + 1;
                    if (card.hp <= damage) {
                        if (card.card_id == CardIdEnum::Boss1) {
                            ICardImpl::flip_cards(world, player.game_id, false);
                        }
                        ICardImpl::spawn_card(world, player.game_id, card.x, card.y, player);
                    } else {
                        card.hp = card.hp - damage;
                        set!(world, (card));
                    }
                }
            }
        } else if (skill == Skill::Meteor) {
            assert(*self.last_use + SKILL_CD <= player.turn, 'Skill cooldown');

            let mut x: u32 = 0;
            let mut y: u32 = 0;
            let damage = player.max_hp;
            while x <= MAP_RANGE {
                while y <= MAP_RANGE {
                    let mut card = get!(world, (player.game_id, x, y), (Card));
                    if (card.is_monster() && card.tag != TagType::NoMagic) {
                        if (card.hp < damage) {
                            if (card.card_id == CardIdEnum::Boss1) {
                                ICardImpl::flip_cards(world, player.game_id, false);
                            }
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
        } else if (skill == Skill::Hex) {
            assert(*self.last_use + SKILL_CD <= player.turn, 'Skill cooldown');

            assert(
                ICardImpl::is_move_inside(direction, player.x, player.y), 'Invalid skil direction'
            );

            let (next_x, next_y) = match direction {
                Direction::Up => { (player.x, player.y + 1) },
                Direction::Down => { (player.x, player.y - 1) },
                Direction::Left => { (player.x - 1, player.y) },
                Direction::Right => { (player.x + 1, player.y) }
            };
            let mut card = get!(world, (player.game_id, next_x, next_y), (Card));
            assert(card.tag != TagType::NoMagic, 'immune to skill');
            assert(card.card_id != CardIdEnum::Boss1, 'Hex cant target boss');
            if (card.is_monster()) {
                let new_card = Card {
                    game_id: card.game_id,
                    x: next_x,
                    y: next_y,
                    card_id: CardIdEnum::ItemHeal,
                    hp: 0,
                    max_hp: 0,
                    shield: 0,
                    max_shield: 0,
                    xp: 0,
                    tag: TagType::None,
                    flipped: false,
                };
                set!(world, (new_card));
            }
        } else if (skill == Skill::Regeneration) {
            assert(*self.last_use + BIG_SKILL_CD <= player.turn, 'Skill cooldown');
            player.hp = player.max_hp;
            set!(world, (player));
        } else if (skill == Skill::LifeSteal) {
            assert(*self.last_use + SKILL_CD <= player.turn, 'Skill cooldown');
            assert(
                ICardImpl::is_move_inside(direction, player.x, player.y), 'Invalid skil direction'
            );
            let (next_x, next_y) = match direction {
                Direction::Up => { (player.x, player.y + 1) },
                Direction::Down => { (player.x, player.y - 1) },
                Direction::Left => { (player.x - 1, player.y) },
                Direction::Right => { (player.x + 1, player.y) }
            };
            let mut card = get!(world, (player.game_id, next_x, next_y), (Card));
            assert(card.tag != TagType::NoMagic, 'immune to skill');
            assert(card.card_id != CardIdEnum::Boss1, 'LifeSteal cant target boss');
            assert(card.is_monster(), 'LifeSteal  target not monster');

            let damage = card.hp / 4 + 1;
            if (player.hp + damage > player.max_hp) {
                player.hp = player.max_hp;
            } else {
                player.hp = player.hp + damage;
            }

            set!(world, (player));
            if (card.hp <= damage) {
                ICardImpl::spawn_card(world, player.game_id, card.x, card.y, player);
            } else {
                card.hp = card.hp - damage;
                set!(world, (card));
            }
        } else if (skill == Skill::Shuffle) {
            assert(*self.last_use + SKILL_CD <= player.turn, 'Skill cooldown');
            let mut x: u32 = 0;
            let mut y: u32 = 0;
            while x <= MAP_RANGE {
                while y <= MAP_RANGE {
                    if (x != player.x && y != player.y) {
                        let rx = random_index(
                            x + player.x + player.game_id, y + player.x + player.game_id, 3
                        );
                        let ry = random_index(
                            x + player.y + player.game_id, y + player.y + player.game_id, 3
                        );
                        if (rx != player.x && ry != player.y) {
                            let mut card = get!(world, (player.game_id, x, y), (Card));
                            let mut card2 = get!(world, (player.game_id, rx, ry), (Card));
                            card.x = rx;
                            card.y = ry;
                            card2.x = x;
                            card2.y = y;
                            set!(world, (card));
                            set!(world, (card));
                        }
                    }
                    y = y + 1;
                };
                x = x + 1;
            };
        }
    }
    fn use_curse_skill(self: @PlayerSkill, world: IWorldDispatcher, game_id: u32, x: u32, y: u32) {
        let mut card = get!(world, (game_id, x, y), (Card));
        assert(card.tag != TagType::NoMagic, 'immune to skill');
        assert(card.is_monster(), 'Card not monster');
        let damage = card.hp / 2;
        card.hp = card.hp - damage;
        set!(world, (card));
    }


    fn use_swap_skill(
        self: @PlayerSkill,
        mut player: Player,
        skill: Skill,
        world: IWorldDispatcher,
        direction: Direction
    ) {
        assert(skill == Skill::Teleport, 'Not swap skil');
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
