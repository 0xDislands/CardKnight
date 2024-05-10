use starknet::ContractAddress;
use card_knight::models::{Direction};

#[dojo::interface]
trait IActions {
    fn start_game();
    fn move(game_id: u32, direction: Direction);
    // fn cascade_move(game_id: u32, x: u32, y: u32, direction: Direction);
}

#[dojo::contract]
mod actions {
    use starknet::{ContractAddress, get_caller_address};
    use card_knight::models::{Card, Game, Player, CardType, Direction};
    use card_knight::systems::cards::cards::ICardsImpl;
    use card_knight::utils::{spawn_coords, type_at_position};
    use card_knight::config::{BASE_HP, HP_PER_LEVEL};

    use super::IActions;

    #[abi(embed_v0)]
    impl PlayerActionsImpl of IActions<ContractState> {
        fn start_game(world: IWorldDispatcher) {
            let game_id = 1;
            let player = get_caller_address();
            set!(world, (Game { game_id: game_id, player, highest_score: 0 }));

            let mut x: u32 = 0;
            let mut y: u32 = 0;
            let (player_x, player_y) = spawn_coords(player, game_id);
            // loop through every square in 3x3 board
            while x < 3 {
                while y < 3 { 
                    if (x == player_x) && (y == player_y) {
                        let (_, value) = type_at_position(x, y);
                        set!(
                            world,
                            (
                                Card {
                                    game_id,
                                    x: x,
                                    y: y,
                                    card_type: CardType::Player,
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
                                    high_score: 0,
                                    total_moves: 0,
                                },
                            )
                        );
                        y += 1;
                        continue;
                    }
                    let (card_type, value) = type_at_position(x, y);
                    if card_type == 1 {
                        let monster_health: u32 = 2 ;
                        set!(
                            world,
                            (
                                Card {
                                    game_id,
                                    x: x,
                                    y: y,
                                    card_type: CardType::Monster,
                                    hp: monster_health,
                                    max_hp: monster_health,
                                    shield: 0,
                                    max_shield: 0,
                                }
                            )
                        );
                    } else if (card_type == 0) {
                        set!(
                            world,
                            (
                                Card {
                                    game_id,
                                    x,
                                    y,
                                    card_type: CardType::Item,
                                    hp: value,
                                    max_hp: value,
                                    shield: 0,
                                    max_shield: 0,
                                }
                            )
                        );
                    }
                    y += 1;
                };
                y = 0;
                x += 1;
            };
        }

        fn move(world: IWorldDispatcher, game_id: u32, direction: Direction) {
            let player_address = get_caller_address();
            let mut player = get!(world, (game_id, player_address),(Player));
            let (next_x, next_y) = match direction {
                Direction::Up => (player.x, player.y + 1),
                Direction::Down => (player.x, player.y - 1),
                Direction::Left => (player.x - 1, player.y),
                Direction::Right => (player.x + 1, player.y)
            };
            let existingCard = get!(world, (game_id, next_x, next_y), (Card));
            // Apply Effect 
            let result = ICardsImpl::apply_effect(player, existingCard);
            delete!(world, (existingCard));
            set!(world, (result));
            if (ICardsImpl::is_corner(player)) {
                let x_destination = player.x;
                let y_destination = player.y;
                let x_direction = player.x; // - move_card.x - developing in cards.cairo
            }
            else {
                let heroCard = ICardsImpl::move_to_position(world, game_id, player.x, player.y, existingCard.x, existingCard.y);
                set!(world, (heroCard));
            }

        }

        // fn cascade_move(world: IWorldDispatcher, game_id: u32, x: u32, y: u32, direction: Direction) {
        //     let card = get!(world, (game_id, x, y), (Card));
        //     let player = get!(world, (game_id, player), (Player));
        //     return true;
        // }

    }
}
