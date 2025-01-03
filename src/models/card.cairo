use card_knight::models::player::IPlayer;
use card_knight::models::player::{Player, IPlayerImpl};
use card_knight::models::game::{Direction, TagType};
use starknet::ContractAddress;

use card_knight::config::card::{
    MONSTER1_BASE_HP, MONSTER1_MULTIPLE, MONSTER2_BASE_HP, MONSTER2_MULTIPLE, MONSTER3_BASE_HP,
    MONSTER3_MULTIPLE, MONSTER1_XP, MONSTER2_XP, MONSTER3_XP, BOSS_XP, HEAL_XP, POISON_XP,
    BOSS_BASE_HP, SHIELD_XP, CHEST_XP, POISON_TURN, INCREASE_HP_RATIO, card_sequence
};
use card_knight::config::map::{MAP_RANGE};
use card_knight::utils::random_index;

use dojo::model::{ModelStorage, ModelValueStorage};
use dojo::world::{IWorld, IWorldDispatcher, IWorldDispatcherTrait, WorldStorage};


#[derive(Copy, Drop, Serde, PartialEq)]
#[dojo::model]
struct Card {
    #[key]
    game_id: u32,
    #[key]
    x: u32,
    #[key]
    y: u32,
    card_id: CardIdEnum,
    hp: u32,
    max_hp: u32,
    shield: u32,
    max_shield: u32,
    xp: u32,
    tag: TagType,
    flipped: bool
}

#[generate_trait]
impl ICardImpl of ICardTrait {
    fn apply_effect(mut world_storage: WorldStorage, mut player: Player, card: Card) -> Player {
        match card.card_id {
            CardIdEnum::Player => { return player; },
            CardIdEnum::Monster1 => {
                player.take_damage(card.hp);
                player.add_exp(MONSTER1_XP);
                return player;
            },
            CardIdEnum::Monster2 => {
                player.take_damage(card.hp);
                player.add_exp(MONSTER2_XP);
                return player;
            },
            CardIdEnum::Monster3 => {
                player.take_damage(card.hp);
                player.add_exp(MONSTER3_XP);
                return player;
            },
            CardIdEnum::Boss1 => {
                let damage = card.hp + card.shield;
                player.take_damage(damage);
                player.add_exp(BOSS_XP);
                Self::flip_cards(world_storage, player.game_id, false);
                return player;
            },
            CardIdEnum::ItemHeal => {
                player.heal(card.hp);
                player.add_exp(HEAL_XP);
                return player;
            },
            CardIdEnum::ItemPoison => {
                player.take_damage(card.hp);
                player.add_exp(POISON_XP);
                player.poisoned = POISON_TURN;
                return player;
            },
            CardIdEnum::ItemChest => {
                let index = random_index(player.hp + player.x + card.x, player.y + card.y, 3);
                let card_value = random_index(
                    player.hp + player.x + card.x, player.y + card.y, player.hp / 2
                );

                //  heal
                if (index == 0) {
                    let new_card = Card {
                        game_id: card.game_id,
                        x: card.x,
                        y: card.y,
                        card_id: CardIdEnum::ItemHeal,
                        hp: card_value,
                        max_hp: card_value,
                        shield: 0,
                        max_shield: 0,
                        xp: HEAL_XP,
                        tag: TagType::None,
                        flipped: false,
                    };
                    world_storage.write_model(@new_card);
                } else if (index == 1) {
                    //  posion
                    let new_card = Card {
                        game_id: card.game_id,
                        x: card.x,
                        y: card.y,
                        card_id: CardIdEnum::ItemPoison,
                        hp: card_value,
                        max_hp: card_value,
                        shield: 0,
                        max_shield: 0,
                        xp: POISON_XP,
                        tag: TagType::None,
                        flipped: false,
                    };
                    world_storage.write_model(@new_card);
                } else if (index == 2) {
                    //  shield
                    let new_card = Card {
                        game_id: card.game_id,
                        x: card.x,
                        y: card.y,
                        card_id: CardIdEnum::ItemShield,
                        hp: 0,
                        max_hp: 0,
                        shield: card_value,
                        max_shield: 0,
                        xp: SHIELD_XP,
                        tag: TagType::None,
                        flipped: false,
                    };
                    world_storage.write_model(@new_card);
                }
                return player;
            },
            CardIdEnum::ItemChestMiniGame => {
                // Handle ItemChestMiniGame case
                // TODO
                return player;
            },
            CardIdEnum::ItemChestEvil => {
                // Handle ItemChestEvil case
                // apply poison or monster
                let index = random_index(player.hp + player.x + card.x, player.y + card.y, 2);

                // damage
                if (index == 0) {
                    player.take_damage(card.hp);
                } else {
                    // add xp
                    player.add_exp(CHEST_XP);
                }

                return player;
            },
            CardIdEnum::ItemShield => {
                player
                    .shield =
                        if (player.shield + card.shield > player.max_shield) {
                            player.max_shield
                        } else {
                            player.shield + card.shield
                        };
                player.add_exp(SHIELD_XP);
                return player;
            },
            _ => { return player; }
        }
    }


    fn is_corner(player: Player) -> bool {
        let is_x_corner = player.x == MAP_RANGE || player.x == 0;
        let is_y_corner = player.y == MAP_RANGE || player.y == 0;
        if is_x_corner && is_y_corner {
            return true;
        } else {
            return false;
        }
    }

    fn is_inside(x: u32, y: u32) -> bool {
        let x_cond: bool = (x <= MAP_RANGE);
        let y_cond: bool = (y <= MAP_RANGE);
        if x_cond && y_cond {
            return true;
        } else {
            return false;
        }
    }

    fn is_move_inside(move: Direction, x: u32, y: u32) -> bool {
        match move {
            Direction::Up => { MAP_RANGE >= y + 1 },
            Direction::Down => { y > 0 },
            Direction::Left => { x > 0 },
            Direction::Right => { MAP_RANGE >= x + 1 }
        }
    }


    fn move_to_position(game_id: u32, mut old_card: Card, new_x: u32, new_y: u32) -> Card {
        old_card.x = new_x;
        old_card.y = new_y;
        return old_card;
    }

    // Temporarily use custom fn to get_neighbour_cards ,
    // in future development we will use Origami's grid map (Vec2 instead of X,Y) for both model and
    // internal functions, might need to finish early so we won't have trouble in db when migrate,
    // which might caused by mismatch data type
    fn get_neighbour_card(
        world_storage: WorldStorage, game_id: u32, x: u32, y: u32, direction: Direction
    ) -> (bool, Card) {
        let mut neighbour_card: Card = world_storage.read_model((game_id, x, y)); // Dummy default
        let is_inside = Self::is_move_inside(direction, x, y);

        if !is_inside {
            return (is_inside, neighbour_card);
        }

        match direction {
            Direction::Up(()) => {
                neighbour_card = world_storage.read_model((game_id, x, y + 1));
            },
            Direction::Down(()) => {
                neighbour_card = world_storage.read_model((game_id, x, y - 1));
            },
            Direction::Left(()) => {
                neighbour_card = world_storage.read_model((game_id, x - 1, y));
            },
            Direction::Right(()) => {
                neighbour_card = world_storage.read_model((game_id, x + 1, y));
            }
        }
        (is_inside, neighbour_card)
    }


    fn get_move_card(
        mut world_storage: WorldStorage, game_id: u32, x: u32, y: u32, player: Player
    ) -> Card {
        let mut card: Card = world_storage.read_model((game_id, x, y)); // Dummy default

        let mut straightGrid_x = 0;
        let mut straightGrid_y = 0;

        if (card.x >= player.x) {
            let direction_x = card.x - player.x;
            if (player.x >= direction_x) {
                straightGrid_x = player.x - direction_x;
            } else {
                straightGrid_x = MAP_RANGE + 1;
            }
        } else {
            let direction_x = player.x - card.x;
            straightGrid_x = player.x + direction_x;
        }

        if (card.y >= player.y) {
            let direction_y = card.y - player.y;
            if (player.y >= direction_y) {
                straightGrid_y = player.y - direction_y;
            } else {
                straightGrid_y = MAP_RANGE + 1;
            }
        } else {
            let direction_y = player.y - card.y;
            straightGrid_y = player.y + direction_y;
        }

        if Self::is_inside(straightGrid_x, straightGrid_y) {
            let card_: Card = world_storage
                .read_model((game_id, straightGrid_x, straightGrid_y)); // Dummy default

            return (card_);
        };

        let mut neighbour_cards: @Array<Card> = {
            let mut arr: Array<Card> = Self::get_all_neighbours(world_storage, game_id, x, y);

            @arr
        };

        let arr_len = neighbour_cards.len();

        if arr_len == 1 {
            return *(neighbour_cards.at(0));
        };

        if (card.x == player.x) {
            if (card.y < player.y) {
                let mut i = 0;
                loop {
                    if (arr_len == i) {
                        break i;
                    }

                    if *(neighbour_cards.at(i)).x > player.x {
                        break i;
                    }
                    i += 1;
                };
                if (i != arr_len) {
                    return (*(neighbour_cards.at(i)));
                }
            }
            if (card.y > player.y) {
                let mut i = 0;
                loop {
                    if (arr_len == i) {
                        break i;
                    }
                    if *(neighbour_cards.at(i)).x < player.x {
                        break i;
                    }
                    i += 1;
                };
                if (i != arr_len) {
                    return (*(neighbour_cards.at(i)));
                }
            }
        }

        if (card.y == player.y) {
            if (card.x > player.x) {
                let mut i = 0;
                loop {
                    if (arr_len == i) {
                        break i;
                    }
                    if *(neighbour_cards.at(i)).y > player.y {
                        break i;
                    }
                    i += 1;
                };
                if (i != arr_len) {
                    return (*(neighbour_cards.at(i)));
                }
            }
            if (card.x < player.x) {
                let mut i = 0;
                loop {
                    if (arr_len == i) {
                        break i;
                    }
                    if *(neighbour_cards.at(i)).y < player.y {
                        break i;
                    }
                    i += 1;
                };
                if (i != arr_len) {
                    return (*(neighbour_cards.at(i)));
                }
            }
        }
        // get random  inside neighbour_cards
        let index = random_index(x, y, arr_len);
        *(neighbour_cards.at(index))
    }

    fn spawn_card(
        mut world_storage: WorldStorage, game_id: u32, x: u32, y: u32, player: Player
    ) -> (Card, bool) {
        let mut card_sequence = card_sequence();
        let mut sequence = player.sequence;
        if sequence >= card_sequence.len() {
            sequence = 0;
        }
        let card_id = card_sequence.at(sequence);
        let mut new_player = player;
        new_player.sequence = sequence + 1;

        world_storage.write_model(@new_player);

        let max_hp = {
            match card_id {
                CardIdEnum::Player => 0,
                CardIdEnum::Monster1 => { MONSTER1_BASE_HP * MONSTER1_MULTIPLE },
                CardIdEnum::Monster2 => { MONSTER2_BASE_HP * MONSTER2_MULTIPLE },
                CardIdEnum::Monster3 => { MONSTER3_BASE_HP * MONSTER3_MULTIPLE },
                CardIdEnum::Boss1 => BOSS_BASE_HP,
                CardIdEnum::ItemHeal => 0,
                CardIdEnum::ItemPoison => 0,
                CardIdEnum::ItemChest => 0,
                CardIdEnum::ItemChestMiniGame => 0,
                CardIdEnum::ItemChestEvil => 0,
                CardIdEnum::ItemShield => 0,
                _ => 0,
            }
        };

        let xp = {
            match card_id {
                CardIdEnum::Player => 0,
                CardIdEnum::Monster1 => MONSTER1_XP,
                CardIdEnum::Monster2 => MONSTER2_XP,
                CardIdEnum::Monster3 => MONSTER3_XP,
                CardIdEnum::Boss1 => BOSS_XP,
                CardIdEnum::ItemHeal => HEAL_XP,
                CardIdEnum::ItemPoison => POISON_XP,
                CardIdEnum::ItemChest => 0,
                CardIdEnum::ItemChestMiniGame => 0,
                CardIdEnum::ItemChestEvil => 0,
                CardIdEnum::ItemShield => 0,
                _ => 0,
            }
        };
        let tag_type = Self::get_tag(*card_id, x, y);

        let card = Card {
            game_id: game_id,
            x: x,
            y: y,
            card_id: *card_id,
            hp: max_hp,
            max_hp: max_hp,
            shield: 0,
            max_shield: 0,
            xp: xp,
            tag: tag_type,
            flipped: false,
        };
        world_storage.write_model(@card);
        let is_boss = if (card.card_id == CardIdEnum::Boss1) {
            true
        } else {
            false
        };
        if (is_boss) {
            Self::flip_cards(world_storage, game_id, true);
        }

        return (card, is_boss);
    }


    fn flip_cards(mut world_storage: WorldStorage, game_id: u32, flip: bool) {
        let mut x: u32 = 0;
        let mut y: u32 = 0;
        while x <= MAP_RANGE {
            while y <= MAP_RANGE {
                let mut card: Card = world_storage.read_model((game_id, x, y)); // Dummy default
                if (card.card_id != CardIdEnum::Boss1 && card.card_id != CardIdEnum::Player) {
                    card.flipped = flip;
                    world_storage.write_model(@card);
                }

                y = y + 1;
            };
            y = 0;
            x = x + 1;
        };
    }


    fn is_boss_active(world_storage: WorldStorage, game_id: u32, flip: bool) -> bool {
        let mut is_active = false;
        let mut x: u32 = 0;
        let mut y: u32 = 0;
        while x <= MAP_RANGE {
            while y <= MAP_RANGE {
                let mut card: Card = world_storage.read_model((game_id, x, y)); // Dummy default
                if (card.card_id == CardIdEnum::Boss1) {
                    is_active = true;
                    break;
                }
                y = y + 1;
            };
            y = 0;
            x = x + 1;
        };
        is_active
    }


    fn get_tag(card_id: CardIdEnum, x: u32, y: u32) -> TagType {
        let is_monster = match card_id {
            CardIdEnum::Monster1 => true,
            CardIdEnum::Monster2 => true,
            CardIdEnum::Monster3 => true,
            CardIdEnum::Boss1 => true,
            _ => false,
        };
        if (!is_monster) {
            return (TagType::None);
        }
        if (x == 0 && y == 0) {
            return (TagType::Growth);
        } else if (x == 1 && y == 0) {
            return (TagType::NoMagic);
        } else if (x == 0 && y == 1) {
            return (TagType::Revenge);
        } else if (x == 1 && y == 1) {
            return (TagType::NoHope);
        } else if (x == 2 && y == 1) {
            //TODO updated for test
            //return (TagType::Silent);
            return (TagType::None);

        }
        TagType::None
    }

    fn is_monster(self: @Card,) -> bool {
        match self.card_id {
            CardIdEnum::Monster1 => true,
            CardIdEnum::Monster2 => true,
            CardIdEnum::Monster3 => true,
            CardIdEnum::Boss1 => true,
            _ => false,
        }
    }

    fn get_all_neighbours(
        world: WorldStorage, game_id: u32, mut x: u32, mut y: u32,
    ) -> Array<Card> {
        let mut arr: Array<Card> = ArrayTrait::new();
        let (isInsideU, neighbour_up) = Self::get_neighbour_card(
            world, game_id, x, y, Direction::Up
        );
        let (isInsideD, neighbour_down) = Self::get_neighbour_card(
            world, game_id, x, y, Direction::Down
        );
        let (isInsideL, neighbour_left) = Self::get_neighbour_card(
            world, game_id, x, y, Direction::Left
        );
        let (isInsideR, neighbour_right) = Self::get_neighbour_card(
            world, game_id, x, y, Direction::Right
        );

        if isInsideU {
            arr.append(neighbour_up);
        }
        if isInsideD {
            arr.append(neighbour_down);
        }
        if isInsideL {
            arr.append(neighbour_left);
        }
        if isInsideR {
            arr.append(neighbour_right);
        }

        arr
    }

    fn apply_growth_tag(ref self: Card) {
        let hp = self.max_hp / 10;
        self.max_hp += hp;
        self.hp += hp;
    }

    fn apply_revenge_tag(ref self: Card) {
        if (self.hp >= self.max_hp) {
            return ();
        }
        let mut hp = self.hp * INCREASE_HP_RATIO / 100;
        hp = if (hp == 0) {
            1
        } else {
            hp
        };
        self.hp += hp;
        self.max_hp = self.max_hp + hp;
    }
}


#[derive(Serde, Drop, Copy, PartialEq, Introspect)]
enum CardIdEnum {
    None,
    Player,
    Monster1,
    Monster2,
    Monster3,
    Boss1,
    ItemHeal,
    ItemPoison,
    ItemChest,
    ItemChestMiniGame,
    ItemChestEvil,
    ItemShield,
    Hex
}

impl ImplCardIdEnumIntoFelt252 of Into<CardIdEnum, felt252> {
    fn into(self: CardIdEnum) -> felt252 {
        match self {
            CardIdEnum::None => 0,
            CardIdEnum::Player => 0,
            CardIdEnum::Monster1 => 1,
            CardIdEnum::Monster2 => 2,
            CardIdEnum::Monster3 => 3,
            CardIdEnum::Boss1 => 4,
            CardIdEnum::ItemHeal => 5,
            CardIdEnum::ItemPoison => 6,
            CardIdEnum::ItemChest => 7,
            CardIdEnum::ItemChestMiniGame => 8,
            CardIdEnum::ItemChestEvil => 9,
            CardIdEnum::ItemShield => 10,
            CardIdEnum::Hex => 11
        }
    }
}
