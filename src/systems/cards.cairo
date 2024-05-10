use starknet::ContractAddress;
use card_knight::models::{Card, Player, Direction};
use array::ArrayTrait;
use dojo::world::{IWorldDispatcher};


#[dojo::interface]
trait ICards {
    fn apply_effect(player: Player, card: Card) -> Player;
    fn is_corner(player: Player) -> bool;
    fn is_inside(x: u32, y: u32) -> bool;
    fn move_to_position(game_id: u32, x: u32, y: u32, new_x: u32, new_y: u32) -> Card;
    fn get_neighbour_card(world: IWorldDispatcher, game_id: u32, x: u32, y: u32, direction: Direction) -> Card;
}

#[dojo::contract]
mod cards {
    use starknet::{ContractAddress, get_caller_address};
    use card_knight::models::{Card, Game, Player, CardType, Direction};

    
    use array::ArrayTrait;


    use super::ICards;

    #[generate_trait]
    impl ICardsImpl of ICardsTrait {
        fn apply_effect(player: Player, card: Card) -> Player {
            let mut ref_player = player;
            match card.card_type {
                CardType::Monster => {
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
                CardType::Player => { return ref_player; },
                CardType::Item => { return ref_player; },
                CardType::Hidden => { return ref_player; },
                CardType::None => { return ref_player; }
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
        ) -> Card {
            let mut card = get!(world, (game_id, x, y), (Card));
            card.x = new_x;
            card.y = new_y;
            return card;
        }

        // Temporarily use custom fn to get_neighbour_cards , 
        // in future development we will use Origami's grid map for both model and internal functions, 
        // might need to finish early so we won't have trouble in db when migrate, which might caused by mismatch data type;
        fn get_neighbour_card(world: IWorldDispatcher, game_id: u32, mut x: u32, mut y: u32, direction: Direction) -> Card {
            let mut neighbour_card = get!(world, (game_id, x, y), (Card)); // dummy
            match direction {
                Direction::Up(()) => { if ICardsImpl::is_inside(x, y + 1) {
                    neighbour_card.y += 1;
                }; },
                Direction::Down(()) => { if ICardsImpl::is_inside(x, y - 1) {
                    neighbour_card.y -= 1;
                }; },
                Direction::Left(()) => { if ICardsImpl::is_inside(x - 1, y) {
                    neighbour_card.x -= 1; 
                }; },
                Direction::Right(()) => { if ICardsImpl::is_inside(x + 1, y) {
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

            let mut neighbour_cards: Array<Card> = {
                let mut arr: Array<Card> = ArrayTrait::new();

                arr.append(ICardsImpl::get_neighbour_card(world, game_id, x, y, Direction::Up));
                arr.append(ICardsImpl::get_neighbour_card(world, game_id, x, y, Direction::Down));
                arr.append(ICardsImpl::get_neighbour_card(world, game_id, x, y, Direction::Left));
                arr.append(ICardsImpl::get_neighbour_card(world, game_id, x, y, Direction::Right));
            };

            let arr_len = {
                let a = neighbour_cards.span().len();
                
            };
            // if neighbour_cards.len() == 1 {

            // }; 

            return get!(world, (game_id, x, y), (Card));

            if ICardsImpl::is_inside(straightGrid_x, straightGrid_y) {
                return get!(world, (game_id, x, y), (Card));
            } else {
                return get!(world, (game_id, x, y), (Card));
            }
        }
    }
}
