use starknet::ContractAddress;
use card_knight::models::{game::Direction};

#[dojo::interface]
trait IActions {
    fn start_game(game_id: u32);
    fn move(game_id: u32, direction: Direction);
}

#[dojo::contract]
mod actions {
    use starknet::{ContractAddress, get_caller_address};
    use card_knight::models::{game::{Game, Direction, GameState}, card::{Card, CardIdEnum, ICardImpl, ICardTrait}, player::Player};
    use card_knight::utils::{spawn_coords, monster_type_at_position};
    use card_knight::config::{
        card::{MONSTER1_BASE_HP, MONSTER1_MULTIPLE, MONSTER2_BASE_HP, MONSTER2_MULTIPLE, MONSTER3_BASE_HP, MONSTER3_MULTIPLE, HEAL_HP, SHIELD_HP},
        player::PLAYER_STARTING_POINT, 
        level::{MONSTER_TO_START_WITH, ITEM_TO_START_WITH},
    };

    use super::IActions;

    #[abi(embed_v0)]
    impl PlayerActionsImpl of IActions<ContractState> {
        fn start_game(world: IWorldDispatcher, game_id: u32) {
            let player = get_caller_address();
            set!(world, (Game { game_id: game_id, player, highest_score: 0, game_state: GameState::Playing }));

            let mut x: u32 = 0;
            let mut y: u32 = 0;
            let (player_x, player_y) = PLAYER_STARTING_POINT;

            let mut MONSTER_COUNT = MONSTER_TO_START_WITH;
            let mut ITEM_COUNT = ITEM_TO_START_WITH;
            
            // loop through every square in 3x3 board
            while x <= 2 {
                while y <= 2 { 
                    if (x == player_x) && (y == player_y) {
                        set!(
                            world,
                            (
                                Card {
                                    game_id,
                                    x: x,
                                    y: y,
                                    card_id: CardIdEnum::Player,
                                    hp: 10,
                                    max_hp: 10,
                                    shield: 0,
                                    max_shield: 10
                                },
                            )
                        );
                        set!(
                            world,
                            (
                                Player {
                                    game_id,
                                    player,
                                    x: x,
                                    y: y,
                                    hp: 10,
                                    max_hp: 10,
                                    shield: 0,
                                    max_shield: 10,
                                    exp: 0,
                                    level: 0,
                                    high_score: 0,
                                    sequence: 0,
                                },
                            )
                        );
                        y += 1;
                        continue;
                    }
                    let (card_id, value) = monster_type_at_position(x, y);
                    if (MONSTER_COUNT > 0) {
                        let monster_health: u32 = 2 ;
                        set!(
                            world,
                            (
                                Card {
                                    game_id,
                                    x: x,
                                    y: y,
                                    card_id: CardIdEnum::Monster1,
                                    hp: monster_health,
                                    max_hp: monster_health,
                                    shield: 0,
                                    max_shield: 0,
                                }
                            )
                        );
                        MONSTER_COUNT -= 1;
                    } else if (ITEM_COUNT > 0) {
                        set!(
                            world,
                            (
                                Card {
                                    game_id,
                                    x,
                                    y,
                                    card_id: CardIdEnum::ItemHeal,
                                    hp: value,
                                    max_hp: value,
                                    shield: 0,
                                    max_shield: 0,
                                }
                            )
                        );
                        ITEM_COUNT -= 1;
                    }
                    y += 1;
                };
                y = 0;
                x += 1;
            };
        }


        // Will update assert  
        fn move(world: IWorldDispatcher, game_id: u32, direction: Direction) {
            let player_address = get_caller_address();
            let mut player = get!(world, (game_id, player_address),(Player));
            let old_player_card = get!(world, (game_id, player.x, player.y), (Card));
            // delete!(world, (old_player_card));
            let (next_x, next_y) = match direction {
                Direction::Up => {
                    (player.x, player.y + 1)
                },
                Direction::Down => {
                    assert!(player.y > 0, "Invalid move");
                    (player.x, player.y - 1)
                },
                Direction::Left => {
                    assert!(player.x > 0, "Invalid move");
                    (player.x - 1, player.y)
                },
                Direction::Right => (player.x + 1, player.y)
            };
            assert!(ICardImpl::is_inside(next_x, next_y), "Invalid move");
            let existingCard = get!(world, (game_id, next_x, next_y), (Card));
            // Apply Effect was made to handle all kind of card => update apply_effect when more cases are added
            let result = ICardImpl::apply_effect(player, existingCard);
            player = result;
            player.x = existingCard.x;
            player.y = existingCard.y;
            // delete!(world, (existingCard));
            let new_player_card = Card {
                game_id,
                x: player.x,
                y: player.y,
                card_id: CardIdEnum::Player,
                hp: player.hp,
                max_hp: player.max_hp,
                shield: player.shield,
                max_shield: player.max_shield,
            };
            set!(world, (new_player_card));
            set!(world, (player));
            let moveCard = ICardImpl::get_move_cards(world, game_id, player.x, player.y, player);
            let mut moveCard_x = moveCard.x;
            let mut moveCard_y = moveCard.y;
            if (ICardImpl::is_corner(player)) {
                let mut x_destination = player.x;
                let mut y_destination = player.y;
                let x_direction = player.x - moveCard.x;
                let y_direction = player.y - moveCard.y;
                while true { 
                    let old_x = x_destination - x_direction;
                    let old_y = y_destination - y_direction;
                    println!("old_x: {}, old_y: {}", old_x, old_y);
                    if !ICardImpl::is_inside(old_x, old_y) {
                        println!("break");
                        break;
                    }
                    else {
                        let card = get!(world, (game_id, old_x, old_y), (Card));
                        ICardImpl::move_to_position(world, game_id, card.x, card.y, x_destination, y_destination);
                        x_destination = old_x;
                        y_destination = old_y;
                    }
                };
                moveCard_x = x_destination;
                moveCard_y = y_destination;
            }
            else {
                ICardImpl::move_to_position(world, game_id, moveCard_x, moveCard_y, existingCard.x, existingCard.y);
            }

            // spawn new card at the end of the move
            ICardImpl::spawn_card(world, game_id, moveCard_x, moveCard_y, player);
        }

    }
}
