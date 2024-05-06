use starknet::ContractAddress;
use card_knight::models::{Direction};

#[dojo::interface]
trait IActions {
    fn start_game();
    fn move(game_id: u32, direction: Direction);
}

#[dojo::contract]
mod actions {
    use starknet::{ContractAddress, get_caller_address};
    use card_knight::models::{Card, Game, Player, CardType, Direction, CardTrait, CardImpl};
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
            match direction {
                Direction::Up => {
                    let x = player.x;
                    let y = player.y + 1;
                    let existingCard = get!(world, (game_id, x, y), (Card));
                    let playerCard = get!(world, (game_id, player), (Player));
                    // Item
                    if (existingCard.card_type == CardType::Item) {
                        set!(
                            world,
                            (
                                Card {
                                    game_id,
                                    x,
                                    y,
                                    card_type: CardType::Player,
                                    hp: playerCard.hp,
                                    max_hp: playerCard.max_hp,
                                    shield: playerCard.shield,
                                    max_shield: playerCard.max_shield,
                                }
                            )
                        )
                    }
                },
                Direction::Down => {
                    let x = player.x;
                    let y = player.y - 1;
                },
                Direction::Left => {
                    let x = player.x - 1;
                    let y = player.y;
                },
                Direction::Right => {
                    let x = player.x + 1;
                    let y = player.y;
                }
            }
        }

    }
}
