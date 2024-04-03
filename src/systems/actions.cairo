use starknet::ContractAddress;

#[dojo::interface]
trait IActions {
    fn start_game();
}

#[dojo::contract]
mod actions {
    use starknet::{ContractAddress, get_caller_address};
    use aeternum::models::{Card, Game, Player, CardType};
    use aeternum::utils::{spawn_coords, type_at_position};
    use aeternum::config::{BASE_HP, HP_PER_LEVEL};

    use super::IActions;

    #[abi(embed_v0)]
    impl PlayerActionsImpl of IActions<ContractState> {
        fn start_game(world: IWorldDispatcher) {
            let game_id = world.uuid();
            let player = get_caller_address();
            set!(world, (Game { game_id: game_id, player, highest_score: 0, },));

            let mut x: u8 = 1;
            let mut y: u8 = 1;
            let (player_x, player_y) = spawn_coords(player, game_id);
            // loop through every square in 3x3 board
            while x <= 3 {
                while y <= 3 { 
                    if (x == player_x) && (y == player_y) {
                        set!(
                            world,
                            (
                                Card {
                                    game_id,
                                    x: x,
                                    y: y,
                                    card: CardType::Player,
                                    health: 10,
                                    armor: 0,
                                    exp: 0
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
    }
}
