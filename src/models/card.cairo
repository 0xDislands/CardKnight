use card_knight::models::player::Player;
use card_knight::models::game::Direction;
use starknet::ContractAddress;

use dojo::world::{IWorld, IWorldDispatcher, IWorldDispatcherTrait};

#[derive(Model, Copy, Drop, Serde, PartialEq)]
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
    fn apply_effect(player: Player, card: Card) -> Player {
        let mut ref_player = player;
        match card.card_type {
            CardTypeEnum::Monster => {
                let mut damage = card.hp;
                if (ref_player.shield > 0) {
                    if (ref_player.shield - damage <= 0) {
                        damage -= ref_player.shield;
                        ref_player.shield = 0;
                        ref_player.hp -= damage;
                    } else {
                        ref_player.shield -= damage;
                    };
                } else {
                    // if remain_hp <= 0 ## This WILL BE WRITTEN WHEN MOVEMENT LOGIC IS FINISHED
                    ref_player.hp = ref_player.hp - card.hp;
                };
                return ref_player;
            },
            CardTypeEnum::Player => { return ref_player; },
            CardTypeEnum::Item => { return ref_player; },
            CardTypeEnum::Hidden => { return ref_player; },
            CardTypeEnum::None => { return ref_player; }
        }
    }

    fn is_corner(player: Player) -> bool {
        if player.x == 3 || player.y == 3 || player.x == 0 || player.y == 0 {
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
        world: IWorldDispatcher, game_id: u32, x: u32, y: u32, new_x: u32, new_y: u32
    ) {
        let mut card = get!(world, (game_id, x, y), (Card));
        card.x = new_x;
        card.y = new_y;
        set!(world, (card));
    }

    // Temporarily use custom fn to get_neighbour_cards , 
    // in future development we will use Origami's grid map for both model and internal functions, 
    // might need to finish early so we won't have trouble in db when migrate, which might caused by mismatch data type;
    fn get_neighbour_card(
        world: IWorldDispatcher, game_id: u32, mut x: u32, mut y: u32, direction: Direction
    ) -> Card {
        let mut neighbour_card = get!(world, (game_id, x, y), (Card)); // dummy
        match direction {
            Direction::Up(()) => { if ICardImpl::is_inside(x, y + 1) {
                neighbour_card.y += 1;
            }; },
            Direction::Down(()) => {
                if ICardImpl::is_inside(x, y - 1) {
                    neighbour_card.y -= 1;
                };
            },
            Direction::Left(()) => {
                if ICardImpl::is_inside(x - 1, y) {
                    neighbour_card.x -= 1;
                };
            },
            Direction::Right(()) => {
                if ICardImpl::is_inside(x + 1, y) {
                    neighbour_card.x += 1;
                };
            }
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

        if ICardImpl::is_inside(straightGrid_x, straightGrid_y) {
            return get!(world, (game_id, straightGrid_x, straightGrid_y), (Card));
        };

        let mut neighbour_cards: @Array<Card> = {
            let mut arr: Array<Card> = ArrayTrait::new();

            let neighbour_up = ICardImpl::get_neighbour_card(world, game_id, x, y, Direction::Up);
            let neighbour_down = ICardImpl::get_neighbour_card(
                world, game_id, x, y, Direction::Down
            );
            let neighbour_left = ICardImpl::get_neighbour_card(
                world, game_id, x, y, Direction::Left
            );
            let neighbour_right = ICardImpl::get_neighbour_card(
                world, game_id, x, y, Direction::Right
            );

            if ICardImpl::is_inside(neighbour_up.x, neighbour_up.y) && neighbour_up != card {
                arr.append(neighbour_up);
            }
            if ICardImpl::is_inside(neighbour_down.x, neighbour_down.y) && neighbour_down != card {
                arr.append(neighbour_down);
            }
            if ICardImpl::is_inside(neighbour_left.x, neighbour_left.y) && neighbour_left != card {
                arr.append(neighbour_left);
            }
            if ICardImpl::is_inside(neighbour_right.x, neighbour_right.y)
                && neighbour_right != card {
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

        if ICardImpl::is_inside(straightGrid_x, straightGrid_y) {
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
        let mut card = get!(world, (game_id, x, y), (Card));
        set!(world, (card));
    }
}



#[derive(Serde, Drop, Copy, PartialEq, Introspect)]
enum CardTypeEnum {
    Player,
    Monster1,
    Monster2,
    Monster3,
    Item,
    Hidden,
    None,
}

#[derive(Serde, Drop, Copy, PartialEq, Introspect)]
enum CardIdEnum {
    Monster1(MonsterAttributes),
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

// This struct representing the attributes of a monster
# [derive(Serde, Copy, Drop, Introspect, PartialEq, Print)]
struct MonsterAttributes {
    hp_base: bool,
    multiple: Option<u32>, // Assuming felt252 is represented as u32 for simplicity
    rhyno_values: Option<(u128, u128)>,
}

impl ImplCardIdEnumIntoFelt252 of Into<CardIdEnum, felt252> {
    fn into(self: CardIdEnum) -> felt252 {
        match self {
            CardIdEnum::Monster1 => 0,
            CardIdEnum::Monster2 => 1,
            CardIdEnum::Monster3 => 2,
            CardIdEnum::Boss1 => 3,
            CardIdEnum::ItemHeal => 4,
            CardIdEnum::ItemPoison => 5,
            CardIdEnum::ItemChest => 6,
            CardIdEnum::ItemChestMiniGame => 7,
            CardIdEnum::ItemChestEvil => 8,
            CardIdEnum::ItemShield => 9,
            CardIdEnum::SkillFire => 10
        }
    }
}