use starknet::ContractAddress;
use card_knight::models::game::{Direction, TagType};
use card_knight::models::skill::{Skill, PlayerSkill};
use card_knight::models::player::{Hero};

#[dojo::interface]
trait IActions {
    fn search_game(ref world: IWorldDispatcher, hero: Hero);
    fn quit_game(ref world: IWorldDispatcher) ;
    fn start_game(ref world: IWorldDispatcher,);

    fn move(ref world: IWorldDispatcher, direction: Direction);
    fn use_skill(ref world: IWorldDispatcher, skill: Skill, direction: Direction);
    fn use_swap_skill(ref world: IWorldDispatcher, skill: Skill, direction: Direction);
    fn use_curse_skill(ref world: IWorldDispatcher, x: u32, y: u32);
    fn level_up(ref world: IWorldDispatcher, upgrade: u32);
}

#[dojo::contract]
mod actions {
    use starknet::{ContractAddress, get_caller_address};
    use card_knight::models::{
        game::{
            Game, Direction, GameState, TagType, apply_tag_effects, is_silent, PlayerGameData,
            PlayerGameState, GamePoints
        },
        card::{Card, CardIdEnum, ICardImpl, ICardTrait}, player::{Player, IPlayer, Hero}
    };
    use card_knight::models::skill::{Skill, PlayerSkill, IPlayerSkill};

    use card_knight::utils::{spawn_coords, monster_type_at_position};
    use card_knight::config::{
        card::{
            MONSTER1_BASE_HP, MONSTER1_MULTIPLE, MONSTER2_BASE_HP, MONSTER2_MULTIPLE,
            MONSTER3_BASE_HP, MONSTER3_MULTIPLE, HEAL_HP, SHIELD_HP, MONSTER1_XP, HEAL_XP,
        },
        player::{PLAYER_STARTING_POINT, default_player},
        level::{MONSTER_TO_START_WITH, ITEM_TO_START_WITH},
    };
    use card_knight::config::level::{SKILL_LEVEL, BIG_SKILL_CD,};
    use card_knight::config::map::{PLAYER_LIMIT,};

    use poseidon::PoseidonTrait;
    use hash::HashStateTrait;


    use super::IActions;

    #[abi(embed_v0)]
    impl PlayerActionsImpl of IActions<ContractState> {
        fn search_game(ref world: IWorldDispatcher, hero: Hero) {
            let player_address = get_caller_address();
            let mut player_data = get!(world, (player_address), (PlayerGameData));
            assert(player_data.game_state == PlayerGameState::None, 'Player already playing');

            let mut game_id = 1;
            while true {
                let mut game = get!(world, (game_id), (Game));
                if (game.player_count <= PLAYER_LIMIT) {
                    game.player_count += 1;
                    if (game.state == GameState::None) {
                        game.state = GameState::Started;
                    }
                    set!(world, (game));
                    player_data.game_id = game_id;
                    player_data.game_state = PlayerGameState::Playing;
                    set!(world, (player_data));
                    let (player_x, player_y) = PLAYER_STARTING_POINT;

                    let mut player = default_player(
                        player_address, game_id, player_x, player_y, hero
                    );

                    set!(world, (player));
                    set!(
                        world,
                        (
                            GamePoints {
                                game_id, index: game.player_count, player_address, score: 0, 
                            },
                        )
                    );

                    break;
                }
            }
        }
        fn quit_game(ref world: IWorldDispatcher) {
            let player_address = get_caller_address();
            let mut player_data = get!(world, (player_address), (PlayerGameData));
            assert(player_data.game_state == PlayerGameState::Playing, 'Player not active');

            let mut game = get!(world, (player_data.game_id), (Game));
            game.player_count -= 1;
            set!(world, (game));

            player_data.game_id = 0;
            player_data.game_state = PlayerGameState::None;
            set!(world, (player_data));
        }

        fn start_game(ref world: IWorldDispatcher,) {
            let player_address = get_caller_address();
            let mut player_data = get!(world, (player_address), (PlayerGameData));
            assert(player_data.game_state == PlayerGameState::Playing, 'Player not playing');
            let game_id = player_data.game_id;

            let mut x: u32 = 0;
            let mut y: u32 = 0;
            let (player_x, player_y) = PLAYER_STARTING_POINT;

            let mut MONSTER_COUNT = MONSTER_TO_START_WITH;
            let mut ITEM_COUNT = ITEM_TO_START_WITH;
            let mut player = get!(world, (game_id, player_address), (Player));

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
                                    hp: player.hp,
                                    max_hp: player.max_hp,
                                    shield: player.shield,
                                    max_shield: player.max_shield,
                                    xp: 0,
                                    tag: TagType::None
                                },
                            )
                        );

                        y += 1;
                        continue;
                    }
                    let (card_id, value) = monster_type_at_position(x, y);

                    if (card_id == 1 && MONSTER_COUNT > 0) {
                        let monster_health: u32 = 2;
                        set!(
                            world,
                            (Card {
                                game_id,
                                x: x,
                                y: y,
                                card_id: CardIdEnum::Monster1,
                                hp: monster_health,
                                max_hp: monster_health,
                                shield: 0,
                                max_shield: 0,
                                xp: MONSTER1_XP,
                                tag: TagType::None
                            })
                        );
                        MONSTER_COUNT -= 1;
                    } else if (ITEM_COUNT > 0) {
                        set!(
                            world,
                            (Card {
                                game_id,
                                x,
                                y,
                                card_id: CardIdEnum::ItemHeal,
                                hp: value,
                                max_hp: value,
                                shield: 0,
                                max_shield: 0,
                                xp: HEAL_XP,
                                tag: TagType::None
                            })
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
        fn move(ref world: IWorldDispatcher, direction: Direction) {
            let player_address = get_caller_address();
            let mut player_data = get!(world, (player_address), (PlayerGameData));
            assert(player_data.game_state == PlayerGameState::Playing, 'Player not playing');
            let game_id = player_data.game_id;

            let mut player = get!(world, (game_id, player_address), (Player));
            let old_player_card = get!(world, (game_id, player.x, player.y), (Card));
            // delete!(world, (old_player_card));
            let (next_x, next_y) = match direction {
                Direction::Up => {
                    println!("Moving up");
                    (player.x, player.y + 1)
                },
                Direction::Down => {
                    assert!(player.y != 0, "Invalid move");
                    println!("Moving down");
                    (player.x, player.y - 1)
                },
                Direction::Left => {
                    assert!(player.x != 0, "Invalid move");
                    println!("Moving left");
                    (player.x - 1, player.y)
                },
                Direction::Right => {
                    println!("Moving right");
                    (player.x + 1, player.y)
                }
            };
            assert!(ICardImpl::is_inside(next_x, next_y) == true, "Invalid move");
            let existingCard = get!(world, (game_id, next_x, next_y), (Card));
            // Apply Effect was made to handle all kind of card => update apply_effect when more cases are added
            let result = ICardImpl::apply_effect(world, player, existingCard);
            player = result;

            // if card is ItemChest dont change any position 
            if (existingCard.card_id == CardIdEnum::ItemChest) {
                player.turn += 1;
                if (player.poisoned != 0) {
                    player.take_damage(1);
                    player.poisoned -= 1;
                }
                set!(world, (player));
                return ();
            };

            // delete!(world, (existingCard));
            let new_player_card = Card {
                game_id,
                x: next_x,
                y: next_y,
                card_id: CardIdEnum::Player,
                hp: player.hp,
                max_hp: player.max_hp,
                shield: player.shield,
                max_shield: player.max_shield,
                xp: 0,
                tag: TagType::None
            };

            // Move cards after use
            let moveCard = ICardImpl::get_move_card(
                world, game_id, existingCard.x, existingCard.y, player
            );
            let mut moveCard_x = moveCard.x;
            let mut moveCard_y = moveCard.y;
            if (ICardImpl::is_corner(player)) {
                let mut x_destination = player.x;
                let mut y_destination = player.y;

                let is_x_pos = player.x >= moveCard_x;
                let is_y_pos = player.y >= moveCard_y;

                let x_direction = if (is_x_pos) {
                    player.x - moveCard_x
                } else {
                    moveCard_x - player.x
                };
                let y_direction = if (is_y_pos) {
                    player.y - moveCard_y
                } else {
                    moveCard_y - player.y
                };

                while true {
                    println!("Calculating old_x & old_y");
                    let old_x = if (is_x_pos && x_direction <= x_destination) {
                        x_destination - x_direction
                    } else if (!is_x_pos) {
                        x_destination + x_direction
                    } else {
                        break;
                    };

                    let old_y = if (is_y_pos && y_direction <= y_destination) {
                        y_destination - y_direction
                    } else if (!is_y_pos) {
                        y_destination + y_direction
                    } else {
                        break;
                    };

                    if ICardImpl::is_inside(old_x, old_y) {
                        let card = get!(world, (game_id, old_x, old_y), (Card));
                        let card_move = ICardImpl::move_to_position(
                            world, game_id, card, x_destination, y_destination
                        );
                        set!(world, (card_move));
                        x_destination = old_x;
                        y_destination = old_y;
                    } else {
                        break;
                    }
                };
                moveCard_x = x_destination;
                moveCard_y = y_destination;
            } else {
                let card_move = ICardImpl::move_to_position(
                    world, game_id, moveCard, old_player_card.x, old_player_card.y
                );
                set!(world, (card_move));
            }

            set!(world, (new_player_card));
            player.x = existingCard.x;
            player.y = existingCard.y;
            player.turn += 1;
            if (player.poisoned != 0) {
                player.take_damage(1);
                player.poisoned -= 1;
            }
            set!(world, (player));
            apply_tag_effects(world, player);

            // spawn new card at the end of the move
            ICardImpl::spawn_card(world, game_id, moveCard_x, moveCard_y, player);
        }


        fn use_skill(ref world: IWorldDispatcher, skill: Skill, direction: Direction) {
            let player_address = get_caller_address();
            let mut player_data = get!(world, (player_address), (PlayerGameData));
            assert(player_data.game_state == PlayerGameState::Playing, 'Player not playing');
            let game_id = player_data.game_id;

            let mut player = get!(world, (game_id, player_address), (Player));
            player.validate_skill(skill);
            let mut player_skill = get!(world, (game_id, player_address, skill), (PlayerSkill));
            assert(!is_silent(world, player), 'Silence active');

            assert(player_skill.is_active(player.level), 'User level not enough');
            player_skill.use_skill(player, skill, world, direction);
            player_skill.last_use = player.turn;
            set!(world, (player_skill));
        }


        fn use_swap_skill(ref world: IWorldDispatcher, skill: Skill, direction: Direction) {
            let player_address = get_caller_address();
            let mut player_data = get!(world, (player_address), (PlayerGameData));
            assert(player_data.game_state == PlayerGameState::Playing, 'Player not playing');
            let game_id = player_data.game_id;

            let mut player = get!(world, (game_id, player_address), (Player));
            player.validate_skill(skill);

            let mut player_skill = get!(world, (game_id, player_address, skill), (PlayerSkill));
            assert(!is_silent(world, player), 'Silence active');

            assert(
                ICardImpl::is_move_inside(direction, player.x, player.y), 'Invalid swap direction'
            );

            assert(player_skill.is_active(player.level), 'User level not enough');
            player_skill.use_swap_skill(player, skill, world, direction);
            player_skill.last_use = player.turn;
            set!(world, (player_skill));
            player.turn += 1;
            if (player.poisoned != 0) {
                player.take_damage(1);
                player.poisoned -= 1;
            }
            set!(world, (player));
        }


        fn use_curse_skill(ref world: IWorldDispatcher, x: u32, y: u32) {
            let player_address = get_caller_address();
            let mut player_data = get!(world, (player_address), (PlayerGameData));
            assert(player_data.game_state == PlayerGameState::Playing, 'Player not playing');
            let game_id = player_data.game_id;

            let skill = Skill::Curse;
            let mut player = get!(world, (game_id, player_address), (Player));
            player.validate_skill(skill);

            let mut player_skill = get!(world, (game_id, player_address, skill), (PlayerSkill));
            assert(!is_silent(world, player), 'Silence active');
            assert(x < 3 && y < 3, 'Position not valid');
            assert(player_skill.last_use + BIG_SKILL_CD <= player.turn, 'Skill cooldown');

            assert(player_skill.is_active(player.level), 'User level not enough');
            player_skill.use_curse_skill(world, player.game_id, x, y);
            player_skill.last_use = player.turn;
            set!(world, (player_skill));
        }

        fn level_up(ref world: IWorldDispatcher, upgrade: u32) {
            let player_address = get_caller_address();
            let mut player_data = get!(world, (player_address), (PlayerGameData));
            assert(player_data.game_state == PlayerGameState::Playing, 'Player not playing');
            let game_id = player_data.game_id;

            let mut player = get!(world, (game_id, player_address), (Player));
            player.level_up(upgrade);
        }
    }
}
