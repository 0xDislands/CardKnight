use starknet::ContractAddress;
use card_knight::models::game::{Direction, TagType};
use card_knight::models::skill::{Skill, PlayerSkill};
use card_knight::models::player::{Hero};

#[dojo::interface]
trait IActions {
    fn start_game(ref world: IWorldDispatcher, game_id: u32, hero: Hero);
    fn move(ref world: IWorldDispatcher, game_id: u32, direction: Direction);
    fn use_skill(ref world: IWorldDispatcher, game_id: u32, skill: Skill, direction: Direction);
    fn use_swap_skill(
        ref world: IWorldDispatcher, game_id: u32, skill: Skill, direction: Direction
    );
    fn use_curse_skill(ref world: IWorldDispatcher, game_id: u32, x: u32, y: u32);
    fn level_up(ref world: IWorldDispatcher, game_id: u32, upgrade: u32);
}

#[dojo::contract]
mod actions {
    use starknet::{ContractAddress, get_caller_address};
    use card_knight::models::{
        game::{Game, Direction, GameState, TagType},
        card::{Card, CardIdEnum, ICardImpl, ICardTrait,}, player::{Player, IPlayer, Hero}
    };
    use card_knight::models::skill::{Skill, PlayerSkill, IPlayerSkill};
    use card_knight::models::game::{apply_tag_effects, is_silent};

    use card_knight::utils::{spawn_coords, monster_type_at_position};
    use card_knight::config::{
        card::{
            MONSTER1_BASE_HP, MONSTER1_MULTIPLE, MONSTER2_BASE_HP, MONSTER2_MULTIPLE,
            MONSTER3_BASE_HP, MONSTER3_MULTIPLE, HEAL_HP, SHIELD_HP, MONSTER1_XP, HEAL_XP,
        },
        player::PLAYER_STARTING_POINT, level::{MONSTER_TO_START_WITH, ITEM_TO_START_WITH},
    };
    use card_knight::config::level::{SKILL_LEVEL, BIG_SKILL_CD,};
    use poseidon::PoseidonTrait;
    use hash::HashStateTrait;


    use super::IActions;

    #[abi(embed_v0)]
    impl PlayerActionsImpl of IActions<ContractState> {
        fn start_game(ref world: IWorldDispatcher, game_id: u32, hero: Hero) {
            let player = get_caller_address();
            set!(
                world,
                (Game {
                    game_id: game_id, player, highest_score: 0, game_state: GameState::Playing
                })
            );

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
                                    max_shield: 10,
                                    xp: 0,
                                    tag: TagType::None,
                                    flipped: false,
                                },
                            )
                        );

                        let mut player = Player {
                            game_id,
                            player,
                            x: x,
                            y: y,
                            hp: 10,
                            max_hp: 10,
                            shield: 0,
                            max_shield: 10,
                            exp: 0,
                            total_xp: 0,
                            level: 1,
                            high_score: 0,
                            sequence: 0,
                            alive: true,
                            poisoned: 0,
                            turn: 0,
                            heroId: hero
                        };
                        player.set_init_hero();
                        set!(world, (player));
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
                                tag: TagType::None,
                                flipped: false,
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
                                tag: TagType::None,
                                flipped: false,
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
        fn move(ref world: IWorldDispatcher, game_id: u32, direction: Direction) {
            let player_address = get_caller_address();
            let mut player = get!(world, (game_id, player_address), (Player));
            assert(player.hp != 0, 'Player is dead');
            let old_player_card = get!(world, (game_id, player.x, player.y), (Card));
            // delete!(world, (old_player_card));
            let (next_x, next_y) = match direction {
                Direction::Up => {
                    (player.x, player.y + 1)
                },
                Direction::Down => {
                    assert!(player.y != 0, "Invalid move");
                    (player.x, player.y - 1)
                },
                Direction::Left => {
                    assert!(player.x != 0, "Invalid move");
                    (player.x - 1, player.y)
                },
                Direction::Right => {
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
                tag: TagType::None,
                flipped: false,
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


        fn use_skill(
            ref world: IWorldDispatcher, game_id: u32, skill: Skill, direction: Direction
        ) {
            let player_address = get_caller_address();
            let mut player = get!(world, (game_id, player_address), (Player));
            assert(player.hp != 0, 'Player is dead');

            player.validate_skill(skill);
            let mut player_skill = get!(world, (game_id, player_address, skill), (PlayerSkill));
            assert(!is_silent(world, player), 'Silence active');

            assert(player_skill.is_active(player.level), 'User level not enough');
            player_skill.use_skill(player, skill, world, direction);
            player_skill.last_use = player.turn;
            set!(world, (player_skill));
        }


        fn use_swap_skill(
            ref world: IWorldDispatcher, game_id: u32, skill: Skill, direction: Direction
        ) {
            let player_address = get_caller_address();
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


        fn use_curse_skill(ref world: IWorldDispatcher, game_id: u32, x: u32, y: u32) {
            let player_address = get_caller_address();

            let skill = Skill::Curse;
            let mut player = get!(world, (game_id, player_address), (Player));
            assert(player.hp != 0, 'Player is dead');

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

        fn level_up(ref world: IWorldDispatcher, game_id: u32, upgrade: u32) {
            let player_address = get_caller_address();
            let mut player = get!(world, (game_id, player_address), (Player));
            assert(player.hp != 0, 'Player is dead');
            player.level_up(upgrade);
        }
    }
}
