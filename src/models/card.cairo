use card_knight::models::player::Player;
use card_knight::models::game::Direction;
use starknet::ContractAddress;

use dojo::world::{IWorld, IWorldDispatcher, IWorldDispatcherTrait};
use card_knight::config::card::{MONSTER1_BASE_HP, MONSTER1_MULTIPLE, MONSTER2_BASE_HP, MONSTER2_MULTIPLE, MONSTER3_BASE_HP, MONSTER3_MULTIPLE};

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
}

#[generate_trait]
impl ICardImpl of ICardTrait {
    fn apply_effect(mut player: Player, card: Card) -> Player {
        match card.card_id {
            CardIdEnum::Player => { return player; },
            CardIdEnum::Monster1 => {
                // let mut damage = card.hp;
                // if (player.shield > 0) {
                //     if (player.shield - damage <= 0) {
                //         damage -= player.shield;
                //         player.shield = 0;
                //         player.hp -= damage;
                //     } else {
                //         player.shield -= damage;
                //     };
                // } else {
                //     // if remain_hp <= 0 ## This WILL BE WRITTEN WHEN MOVEMENT LOGIC IS FINISHED
                //     player.hp = player.hp - card.hp;
                // };
                return player;
            },
            CardIdEnum::Monster2 => {
                // Handle Monster2 case
                return player;
            },
            CardIdEnum::Monster3 => {
                // Handle Monster3 case
                return player;
            },
            CardIdEnum::Boss1 => {
                // Handle Boss1 case
                return player;
            },
            CardIdEnum::ItemHeal => {
                // Handle ItemHeal case
                return player;
            },
            CardIdEnum::ItemPoison => {
                // Handle ItemPoison case
                return player;
            },
            CardIdEnum::ItemChest => {
                // Handle ItemChest case
                return player;
            },
            CardIdEnum::ItemChestMiniGame => {
                // Handle ItemChestMiniGame case
                return player;
            },
            CardIdEnum::ItemChestEvil => {
                // Handle ItemChestEvil case
                return player;
            },
            CardIdEnum::ItemShield => {
                // Handle ItemShield case
                return player;
            },
            CardIdEnum::SkillFire => {
                // Handle SkillFire case
                return player;
            }
        }
    }

    fn is_corner(player: Player) -> bool {
        if player.x == 2 || player.y == 2 || player.x == 0 || player.y == 0 {
            return true;
        } else {
            return false;
        }
    }

    fn is_inside(x: u32, y: u32) -> bool {
        let WIDTH: u32 = 3; // 3x3 map
        if x <= WIDTH && y <= WIDTH {
            return true;
        } else {
            return false;
        }
    }

    fn move_to_position(
        world: IWorldDispatcher, game_id: u32, old_x: u32, old_y: u32, new_x: u32, new_y: u32
    ) {
        let mut card = get!(world, (game_id, old_x, old_y), (Card));
        card.x = new_x;
        card.y = new_y;
        set!(world, (card));
    }

    // Temporarily use custom fn to get_neighbour_cards ,
    // in future development we will use Origami's grid map (Vec2 instead of X,Y) for both model and
    // internal functions, might need to finish early so we won't have trouble in db when migrate,
    // which might caused by mismatch data type
    fn get_neighbour_card(
        world: IWorldDispatcher, game_id: u32, mut x: u32, mut y: u32, direction: Direction
    ) -> Card {
        let mut neighbour_card = get!(world, (game_id, x, y), (Card)); // dummy
        match direction {
            Direction::Up(()) => { if Self::is_inside(x, y + 1) {
                neighbour_card.y += 1;
            }; },
            Direction::Down(()) => { if Self::is_inside(x, y - 1) {
                neighbour_card.y -= 1;
            }; },
            Direction::Left(()) => { if Self::is_inside(x - 1, y) {
                neighbour_card.x -= 1;
            }; },
            Direction::Right(()) => { if Self::is_inside(x + 1, y) {
                neighbour_card.x += 1;
            }; }
        }

        return neighbour_card;
    }

    fn get_move_cards(
        world: IWorldDispatcher, game_id: u32, x: u32, y: u32, player: Player
    ) -> Card {
        let card = get!(world, (game_id, x, y), (Card));
        let direction_x = card.x - player.x;
        let direction_y = card.y - player.y;
        let straightGrid_x = player.x - direction_x;
        let straightGrid_y = player.y - direction_y;

        if Self::is_inside(straightGrid_x, straightGrid_y) {
            return get!(world, (game_id, straightGrid_x, straightGrid_y), (Card));
        };

        let mut neighbour_cards: @Array<Card> = {
            let mut arr: Array<Card> = ArrayTrait::new();

            let neighbour_up = Self::get_neighbour_card(world, game_id, x, y, Direction::Up);
            let neighbour_down = Self::get_neighbour_card(world, game_id, x, y, Direction::Down);
            let neighbour_left = Self::get_neighbour_card(world, game_id, x, y, Direction::Left);
            let neighbour_right = Self::get_neighbour_card(world, game_id, x, y, Direction::Right);

            if Self::is_inside(neighbour_up.x, neighbour_up.y) && neighbour_up != card {
                arr.append(neighbour_up);
            }
            if Self::is_inside(neighbour_down.x, neighbour_down.y) && neighbour_down != card {
                arr.append(neighbour_down);
            }
            if Self::is_inside(neighbour_left.x, neighbour_left.y) && neighbour_left != card {
                arr.append(neighbour_left);
            }
            if Self::is_inside(neighbour_right.x, neighbour_right.y) && neighbour_right != card {
                arr.append(neighbour_right);
            }

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
                    if *(neighbour_cards.at(i)).x < player.x {
                        break *(neighbour_cards.at(i));
                    }
                    i += 1;
                };
            }
            if (card.y > player.y) {
                let mut i = 0;
                loop {
                    if *(neighbour_cards.at(i)).x < player.x {
                        break *(neighbour_cards.at(i));
                    }
                    i += 1;
                };
            }
        }

        if (card.y == player.y) {
            if (card.x > player.x) {
                let mut i = 0;
                loop {
                    if *(neighbour_cards.at(i)).y > player.y {
                        break *(neighbour_cards.at(i));
                    }
                    i += 1;
                };
            }
            if (card.x < player.x) {
                let mut i = 0;
                loop {
                    if *(neighbour_cards.at(i)).y < player.y {
                        break *(neighbour_cards.at(i));
                    }
                    i += 1;
                };
            }
        }

        return get!(world, (game_id, x, y), (Card));

        if Self::is_inside(straightGrid_x, straightGrid_y) {
            return get!(world, (game_id, x, y), (Card));
        } else {
            return get!(world, (game_id, x, y), (Card));
        }
    }

    fn spawn_card(world: IWorldDispatcher, game_id: u32, x: u32, y: u32, player: Player) {
        let mut card_sequence = ArrayTrait::new();
        card_sequence.append(CardIdEnum::Monster1);
        card_sequence.append(CardIdEnum::ItemHeal);
        card_sequence.append(CardIdEnum::Monster2);
        card_sequence.append(CardIdEnum::ItemPoison);
        card_sequence.append(CardIdEnum::Monster3);
        card_sequence.append(CardIdEnum::ItemChest);
        card_sequence.append(CardIdEnum::Monster1);
        card_sequence.append(CardIdEnum::ItemHeal);
        card_sequence.append(CardIdEnum::Monster2);
        card_sequence.append(CardIdEnum::ItemChestMiniGame);
        card_sequence.append(CardIdEnum::Monster3);
        card_sequence.append(CardIdEnum::ItemChestEvil);
        card_sequence.append(CardIdEnum::Monster1);
        card_sequence.append(CardIdEnum::ItemShield);
        card_sequence.append(CardIdEnum::Monster2);
        card_sequence.append(CardIdEnum::SkillFire);
        card_sequence.append(CardIdEnum::Boss1);
        card_sequence.append(CardIdEnum::ItemChestEvil);
        card_sequence.append(CardIdEnum::Monster1);
        card_sequence.append(CardIdEnum::ItemHeal);
        card_sequence.append(CardIdEnum::Monster2);
        card_sequence.append(CardIdEnum::ItemChestMiniGame);
        card_sequence.append(CardIdEnum::Monster3);
        card_sequence.append(CardIdEnum::ItemChestEvil);
        let mut sequence = player.sequence;
        if sequence >= card_sequence.len() {
            sequence = 0;
        }
        let card_id = card_sequence.at(sequence);
        let mut new_player = player;
        new_player.sequence = sequence + 1;
        set!(world, (new_player));
        let max_hp = {
            match card_id {
                CardIdEnum::Player => 0,
                CardIdEnum::Monster1 => {
                    player.level * MONSTER1_BASE_HP * MONSTER1_MULTIPLE
                },
                CardIdEnum::Monster2 => {
                    player.level * MONSTER2_BASE_HP * MONSTER2_MULTIPLE
                },
                CardIdEnum::Monster3 => {
                    player.level * MONSTER3_BASE_HP * MONSTER3_MULTIPLE
                },
                CardIdEnum::Boss1 => 40,
                CardIdEnum::ItemHeal => 0,
                CardIdEnum::ItemPoison => 0,
                CardIdEnum::ItemChest => 0,
                CardIdEnum::ItemChestMiniGame => 0,
                CardIdEnum::ItemChestEvil => 0,
                CardIdEnum::ItemShield => 0,
                CardIdEnum::SkillFire => 0
            }
        };
        let card = Card {
            game_id: game_id,
            x: x,
            y: y,
            card_id: *card_id,
            hp: max_hp,
            max_hp: max_hp,
            shield: 0,
            max_shield: 0
        };
        set!(world, (card));
    }
}


#[derive(Serde, Drop, Copy, PartialEq, Introspect)]
enum CardIdEnum {
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
    SkillFire
}

impl ImplCardIdEnumIntoFelt252 of Into<CardIdEnum, felt252> {
    fn into(self: CardIdEnum) -> felt252 {
        match self {
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
            CardIdEnum::SkillFire => 11,
        }
    }
}
