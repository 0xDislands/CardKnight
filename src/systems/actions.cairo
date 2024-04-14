use starknet::ContractAddress;
use aeternum::models::{Direction};

#[dojo::interface]
trait IActions {
    fn start_game();
    fn move(game_id: u32, current_x: u8, current_y: u8, direction: Direction);
}

#[dojo::contract]
mod actions {
    use starknet::{ContractAddress, get_caller_address};
    use aeternum::models::{Card, Game, Player, CardType, Direction};
    use aeternum::utils::{spawn_coords, type_at_position};
    use aeternum::config::{BASE_HP, HP_PER_LEVEL};

    use super::IActions;

    #[abi(embed_v0)]
    impl PlayerActionsImpl of IActions<ContractState> {
        fn start_game(world: IWorldDispatcher) {
            let game_id = 1;
            let player = get_caller_address();
            set!(world, (Game { game_id: game_id, player, highest_score: 0, },));

            let mut x: u8 = 0;
            let mut y: u8 = 0;
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
                                    card: CardType::Player,
                                    health: value,
                                    armor: 0,
                                    exp: 0
                                },
                            )
                        );
                        set!(
                            world,
                            (
                                Player {
                                    game_id,
                                    player,
                                    health: value,
                                    armor: 0,
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
                        let monster_health: u32 = BASE_HP * value ;
                        set!(
                            world,
                            (
                                Card {
                                    game_id,
                                    x: x,
                                    y: y,
                                    card: CardType::Monster,
                                    health: monster_health,
                                    armor: 0,
                                    exp: value,
                                }
                            )
                        )
                    } else if card_type == 0 {
                        set!(
                            world,
                            (
                                Card {
                                    game_id,
                                    x: x,
                                    y: y,
                                    card: CardType::Item,
                                    health: 0,
                                    armor: 0,
                                    exp: value,
                                }
                            )
                        )
                    }
                    y += 1;
                };
                y = 0;
                x += 1;
            };
        }

        fn move(world: IWorldDispatcher, game_id: u32, current_x: u8, current_y: u8, direction: Direction) {
            let player = get_caller_address();
            match direction {
                Direction::Up => {
                    let x =  current_x;
                    let y = current_y + 1;
                    let existingCard = get!(world, (game_id, x, y), (Card));
                    let playerCard = get!(world, (game_id, player), (Player));
                    // Item
                    if (existingCard.card == CardType::Item) {
                        set!(
                            world,
                            (
                                Card {
                                    game_id,
                                    x,
                                    y,
                                    card: CardType::Player,
                                    health: playerCard.health + existingCard.exp,
                                    armor: playerCard.armor,
                                    exp: playerCard.exp + existingCard.exp
                                    total_moves: playerCard.total_moves + 1,
                                }
                            )
                        )
                    }
                },
                Direction::Down => {
                    let x =  current_x;
                    let y = current_y - 1;
                },
                Direction::Left => {
                    let x =  current_x - 1;
                    let y = current_y;
                },
                Direction::Right => {
                    let x = current_x + 1;
                    let y = current_y;
                },
            }
        }
    }
}
