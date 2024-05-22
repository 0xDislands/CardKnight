use starknet::ContractAddress;
use card_knight::models::{game::Direction};

#[dojo::interface]
trait IActions {
    fn start_game();
    fn move(game_id: u32, direction: Direction);
}

#[dojo::contract]
mod actions {
    use starknet::{ContractAddress, get_caller_address};
    use card_knight::models::{game::{Game, Direction, GameState}, card::{Card, CardTypeEnum, ICardImpl}, player::Player};
    use card_knight::utils::{spawn_coords, type_at_position};
    use card_knight::config::{BASE_HP, HP_PER_LEVEL};

    use super::IActions;

    #[abi(embed_v0)]
    impl PlayerActionsImpl of IActions<ContractState> {
        fn start_game(world: IWorldDispatcher) {
            let game_id = 1;
            let player = get_caller_address();
            set!(world, (Game { game_id: game_id, player, highest_score: 0, game_state: GameState::Playing }));

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
                                    card_type: CardTypeEnum::Player,
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
                                    card_type: CardTypeEnum::Monster,
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
                                    card_type: CardTypeEnum::Item,
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
            let result = ICardImpl::apply_effect(player, existingCard);
            delete!(world, (existingCard));
            set!(world, (result));
            // Move Player
            player.x = existingCard.x;
            player.y = existingCard.y;
            set!(world, (player));
            let moveCard = ICardImpl::get_move_cards(world, game_id, player.x, player.y, player);
            let mut moveCard_x = moveCard.x;
            let mut moveCard_y = moveCard.y;
            if (ICardImpl::is_corner(player)) {
                let mut x_destination = player.x;
                let mut y_destination = player.y;
                let x_direction = player.x;
                let y_direction = player.y;
                let mut i = true; 
                loop {
                    if i == false {
                        break;
                    }
                    let old_x = x_destination - x_direction;
                    let old_y = y_destination - y_direction;
                    if ICardImpl::is_inside(old_x, old_y) {
                        let card = get!(world, (game_id, old_x, old_y), (Card));
                        let new_x = x_destination;
                        let new_y = y_destination;
                        ICardImpl::move_to_position(world, game_id, new_x, new_y, card.x, card.y);
                        x_destination = old_x;
                        y_destination = old_y;
                    }
                    else {
                        i = false;
                    }
                };
                moveCard_x = x_destination;
                moveCard_y = y_destination;
            }
            else {
                ICardImpl::move_to_position(world, game_id, player.x, player.y, existingCard.x, existingCard.y);
            }
            // spawn new card
            ICardImpl::spawn_card(world, game_id, moveCard_x, moveCard_y, player);
            
        }

    }
}
