use starknet::ContractAddress;
use card_knight::config::level::{
    FIRE_SKILL_LEVEL, SKILL_CD, SLASH_SKILL_LEVEL, METEOR_SKILL_LEVEL, SWAP_SKILL_LEVEL,
    SKILL_LEVEL, BIG_SKILL_CD,
};
use card_knight::models::game::{Direction, TagType};

use card_knight::config::map::{MAP_RANGE};
use card_knight::models::{card::{Card, CardIdEnum, ICardImpl, ICardTrait}, player::Player};
use card_knight::utils::random_index;

use dojo::model::{ModelStorage, ModelValueStorage};
use dojo::world::{IWorld, IWorldDispatcher, IWorldDispatcherTrait, WorldStorage};

#[derive(Serde, Drop, Copy, PartialEq, Introspect)]
enum Skill {
    PowerupSlash,
    Teleport, //     Swap
    Hex,
    Regeneration,
    LifeSteal,
    Shuffle,
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
        mut world_storage: WorldStorage,
        direction: Direction,
    ) {
        if (skill == Skill::SkillFire) {
            assert(
                *self.last_use == 0 || *self.last_use + SKILL_CD <= player.turn, 'Skill cooldown',
            );

            let mut x: u32 = 0;
            let mut y: u32 = 0;
            while x <= MAP_RANGE {
                while y <= MAP_RANGE {
                    let mut card: Card = world_storage
                        .read_model((player.game_id, x, y)); // Dummy default

                    if (card.is_monster() && card.tag != TagType::NoMagic) {
                        card.hp -= card.hp / 4;
                        if (card.hp == 0) {
                            if (card.card_id == CardIdEnum::Boss1) {
                                ICardImpl::flip_cards(world_storage, player.game_id, false);
                            }
                            ICardImpl::spawn_card(
                                world_storage, player.game_id, card.x, card.y, player,
                            );
                        } else {
                            world_storage.write_model(@card);
                        }
                    }
                    y = y + 1;
                };
                y = 0;
                x = x + 1;
            };
        } else if (skill == Skill::PowerupSlash) {
            assert(
                *self.last_use == 0 || *self.last_use + SKILL_CD <= player.turn, 'Skill cooldown',
            );
            assert(
                ICardImpl::is_move_inside(direction, player.x, player.y), 'Invalid skil direction',
            );

            let (next_x, next_y) = match direction {
                Direction::Up => { (player.x, player.y + 1) },
                Direction::Down => { (player.x, player.y - 1) },
                Direction::Left => { (player.x - 1, player.y) },
                Direction::Right => { (player.x + 1, player.y) },
            };

            let mut card: Card = world_storage.read_model((player.game_id, next_x, next_y));
            if (card.is_monster() && card.tag != TagType::NoMagic) {
                if (card.card_id == CardIdEnum::Boss1) {
                    ICardImpl::flip_cards(world_storage, player.game_id, false);
                }
                ICardImpl::spawn_card(world_storage, player.game_id, card.x, card.y, player);
            }
        } else if (skill == Skill::Meteor) {
            assert(
                *self.last_use == 0 || *self.last_use + SKILL_CD <= player.turn, 'Skill cooldown',
            );

            let mut x: u32 = 0;
            let mut y: u32 = 0;
            let damage = player.max_hp / 4;
            while x <= MAP_RANGE {
                while y <= MAP_RANGE {
                    let mut card: Card = world_storage
                        .read_model((player.game_id, x, y)); // Dummy default

                    if (card.is_monster() && card.tag != TagType::NoMagic) {
                        if (card.hp < damage) {
                            if (card.card_id == CardIdEnum::Boss1) {
                                ICardImpl::flip_cards(world_storage, player.game_id, false);
                            }
                            ICardImpl::spawn_card(
                                world_storage, player.game_id, card.x, card.y, player,
                            );
                        } else {
                            card.hp -= damage;
                            world_storage.write_model(@card);
                        }
                    }
                    y += 1;
                };
                y = 0;
                x = x + 1;
            };
        } else if (skill == Skill::Hex) {
            assert(
                *self.last_use == 0 || *self.last_use + SKILL_CD <= player.turn, 'Skill cooldown',
            );

            assert(
                ICardImpl::is_move_inside(direction, player.x, player.y), 'Invalid skil direction',
            );

            let (next_x, next_y) = match direction {
                Direction::Up => { (player.x, player.y + 1) },
                Direction::Down => { (player.x, player.y - 1) },
                Direction::Left => { (player.x - 1, player.y) },
                Direction::Right => { (player.x + 1, player.y) },
            };
            let mut card: Card = world_storage
                .read_model((player.game_id, next_x, next_y)); // Dummy default

            assert(card.tag != TagType::NoMagic, 'immune to skill');
            assert(card.card_id != CardIdEnum::Boss1, 'Hex cant target boss');

            if (card.is_monster()) {
                let new_card = Card {
                    game_id: card.game_id,
                    x: next_x,
                    y: next_y,
                    card_id: CardIdEnum::Hex,
                    hp: 0,
                    max_hp: 0,
                    shield: 0,
                    max_shield: 0,
                    xp: 0,
                    tag: TagType::None,
                    flipped: false,
                };
                world_storage.write_model(@new_card);
            }
        } else if (skill == Skill::Regeneration) {
            assert(
                *self.last_use == 0 || *self.last_use + BIG_SKILL_CD <= player.turn,
                'Skill cooldown',
            );
            player.hp = player.max_hp;
            world_storage.write_model(@player);
        } else if (skill == Skill::LifeSteal) {
            assert(
                *self.last_use == 0 || *self.last_use + SKILL_CD <= player.turn, 'Skill cooldown',
            );
            assert(
                ICardImpl::is_move_inside(direction, player.x, player.y), 'Invalid skil direction',
            );
            let (next_x, next_y) = match direction {
                Direction::Up => { (player.x, player.y + 1) },
                Direction::Down => { (player.x, player.y - 1) },
                Direction::Left => { (player.x - 1, player.y) },
                Direction::Right => { (player.x + 1, player.y) },
            };
            let mut card: Card = world_storage
                .read_model((player.game_id, next_x, next_y)); // Dummy default
            assert(card.tag != TagType::NoMagic, 'immune to skill');
            assert(card.card_id != CardIdEnum::Boss1, 'LifeSteal cant target boss');
            assert(card.is_monster(), 'LifeSteal  target not monster');

            let damage = card.hp / 4 + 1;
            if (player.hp + damage > player.max_hp) {
                player.hp = player.max_hp;
            } else {
                player.hp = player.hp + damage;
            }

            world_storage.write_model(@player);
            if (card.hp <= damage) {
                ICardImpl::spawn_card(world_storage, player.game_id, card.x, card.y, player);
            } else {
                card.hp = card.hp - damage;
                world_storage.write_model(@card);
            }
        } else if (skill == Skill::Shuffle) {
            assert(
                *self.last_use == 0 || *self.last_use + SKILL_CD <= player.turn, 'Skill cooldown',
            );
            let mut x: u32 = 0;
            let mut y: u32 = 0;
            while x <= MAP_RANGE {
                while y <= MAP_RANGE {
                    if (x != player.x && y != player.y) {
                        let rx = random_index(
                            x + player.x + player.game_id, y + player.x + player.game_id, 3,
                        );
                        let ry = random_index(
                            x + player.y + player.game_id, y + player.y + player.game_id, 3,
                        );
                        if (rx != player.x && ry != player.y) {
                            let mut card: Card = world_storage.read_model((player.game_id, x, y));
                            let mut card2: Card = world_storage
                                .read_model((player.game_id, rx, ry));
                            card.x = rx;
                            card.y = ry;
                            card2.x = x;
                            card2.y = y;
                            world_storage.write_model(@card);
                            world_storage.write_model(@card2);
                        }
                    }
                    y = y + 1;
                };
                y = 0;
                x = x + 1;
            };
        }
    }
    fn use_curse_skill(
        self: @PlayerSkill, mut world_storage: WorldStorage, game_id: u32, x: u32, y: u32,
    ) {
        let mut card: Card = world_storage.read_model((game_id, x, y));
        assert(card.tag != TagType::NoMagic, 'immune to skill');
        assert(card.is_monster(), 'Card not monster');
        let damage = card.hp / 2;
        card.hp = card.hp - damage;
        world_storage.write_model(@card);
    }


    fn use_swap_skill(
        self: @PlayerSkill, mut player: Player, mut world_storage: WorldStorage, x: u32, y: u32,
    ) {
        assert(*self.last_use == 0 || *self.last_use + SKILL_CD <= player.turn, 'Skill cooldown');

        let mut move_card: Card = world_storage.read_model((player.game_id, x, y));
        move_card.x = player.x;
        move_card.y = player.y;
        world_storage.write_model(@move_card);

        player.x = x;
        player.y = y;
        world_storage.write_model(@player);
    }
}
