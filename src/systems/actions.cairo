use starknet::ContractAddress;
use card_knight::models::game::{Direction, TagType};
use card_knight::models::skill::{Skill, PlayerSkill};
use card_knight::models::player::{Hero, Scores};

#[starknet::interface]
trait IActions<T> {
    fn start_game(ref self: T, game_id: u32, hero: Hero);
    fn move(ref self: T, game_id: u32, direction: Direction);
    fn move_to_deal(ref self: T, game_id: u32, direction: Direction, selection: bool,);
    fn use_skill(ref self: T, game_id: u32, skill: Skill, direction: Direction);
    fn use_swap_skill(ref self: T, game_id: u32, x: u32, y: u32);
    fn use_curse_skill(ref self: T, game_id: u32, x: u32, y: u32);
    fn level_up(ref self: T, game_id: u32, upgrade: u32);
    fn set_contract(ref self: T, index: u128, new_address: ContractAddress);

    fn get_total_weekly_players(self: @T, week: u64) -> u128;
    fn get_player_weekly_highest_score(self: @T, player: ContractAddress, week: u64) -> u32;
    fn get_weekly_scores(
        self: @T, player: ContractAddress, week: u64, start: u128, end: u128,
    ) -> Array<Scores>;

    fn winner_of_the_week(self: @T, week: u64) -> ContractAddress;
    fn hero_skills(self: @T, hero: Hero) -> (Skill, Skill, Skill);
    fn levelUpWaiting(self: @T, user: ContractAddress, game_id: u32) -> bool;
    fn levelUpOptions(self: @T, user: ContractAddress, game_id: u32) -> (ByteArray, ByteArray);
    fn hero_skills_cd(self: @T, game_id: u32, player_address: ContractAddress) -> (u32, u32, u32);
    fn skill_cd(self: @T, game_id: u32, player_address: ContractAddress, skill: Skill) -> u32;


    fn open_lock(ref self: T, game_id: u32, direction: Direction, wheel_result: bool,);

    fn demon_deals(self: @T, user: ContractAddress, game_id: u32,) -> (ByteArray, ByteArray);
}

#[dojo::contract]
mod actions {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use card_knight::models::{
        game::{Game, Direction, GameState, TagType},
        card::{Card, CardIdEnum, ICardImpl, ICardTrait},
        player::{Player, IPlayer, Hero, Scores, WeeklyIndex, TotalWeeklyPlayers, WeeklyWinner},
    };
    use card_knight::models::skill::{Skill, PlayerSkill, IPlayerSkill};
    use card_knight::models::game::{apply_tag_effects, is_silent, Contracts};

    use card_knight::utils::{spawn_coords, monster_type_at_position};
    use card_knight::config::{
        card::{
            MONSTER1_BASE_HP, MONSTER1_MULTIPLE, MONSTER2_BASE_HP, MONSTER2_MULTIPLE,
            MONSTER3_BASE_HP, MONSTER3_MULTIPLE, HEAL_HP, SHIELD_HP, MONSTER1_XP, HEAL_XP,
            POISON_XP, SHIELD_XP,
        },
        player::PLAYER_STARTING_POINT, level::{MONSTER_TO_START_WITH, ITEM_TO_START_WITH},
        config::STRK_RECEIVER,
    };
    use card_knight::config::IDislandReward::{
        IDislandRewardDispatcher, IDislandRewardDispatcherTrait,
    };
    use card_knight::config::level::{SKILL_LEVEL, BIG_SKILL_CD, SKILL_CD};
    use card_knight::config::level;
    use poseidon::PoseidonTrait;
    use hash::HashStateTrait;


    use dojo::model::{ModelStorage, ModelValueStorage};
    use dojo::world::{IWorld, IWorldDispatcher, IWorldDispatcherTrait, WorldStorage};


    use super::IActions;
    const WEEK: u64 = 604800;
    // TODO test fails when activated
    // The only requirement is that the function is named `dojo_init`.
    fn dojo_init(ref self: ContractState, core: ContractAddress, rewards: ContractAddress) {
        let mut world = self.world(@"card_knight");
        let mut contract: Contracts = world.read_model(2);
        contract.address = rewards;
        world.write_model(@contract);
        let mut contract: Contracts = world.read_model(1);
        contract.address = core;
        world.write_model(@contract);
    }
    
    #[abi(embed_v0)]
    impl PlayerActionsImpl of IActions<ContractState> {
        fn start_game(ref self: ContractState, game_id: u32, hero: Hero) {
            let player = get_caller_address();

            let mut world = self.world(@"card_knight");
            let mut game: Game = world.read_model((game_id, player));
            game.game_state = GameState::Playing;

            world.write_model(@game);

            let mut x: u32 = 0;
            let mut y: u32 = 0;
            let (player_x, player_y) = PLAYER_STARTING_POINT;

            let mut MONSTER_COUNT = MONSTER_TO_START_WITH;

            // loop through every square in 3x3 board
            while x <= 2 {
                while y <= 2 {
                    if (x == player_x) && (y == player_y) {
                        world
                            .write_model(
                                @Card {
                                    game_id,
                                    x: x,
                                    y: y,
                                    card_id: CardIdEnum::Player,
                                    hp: 20,
                                    max_hp: 20,
                                    shield: 0,
                                    max_shield: 10,
                                    xp: 0,
                                    tag: TagType::None,
                                    flipped: false,
                                },
                            );

                        let mut player = Player {
                            game_id,
                            player,
                            x: x,
                            y: y,
                            hp: 20,
                            max_hp: 20,
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
                            heroId: hero,
                        };

                        world.write_model(@player);

                        y += 1;
                        continue;
                    } else {
                        let (card_id, value) = monster_type_at_position(x, y);

                        if (card_id == 1 && MONSTER_COUNT > 0) {
                            let monster_health: u32 = 2;
                            world
                                .write_model(
                                    @Card {
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
                                    },
                                );

                            MONSTER_COUNT -= 1;
                        } else {
                            world
                                .write_model(
                                    @Card {
                                        game_id,
                                        x,
                                        y,
                                        card_id: CardIdEnum::ItemHeal,
                                        hp: 3,
                                        max_hp: 3,
                                        shield: 0,
                                        max_shield: 0,
                                        xp: HEAL_XP,
                                        tag: TagType::None,
                                        flipped: false,
                                    },
                                );
                        }
                    }
                    y += 1;
                };
                y = 0;
                x += 1;
            };
        }


        fn open_lock(
            ref self: ContractState, game_id: u32, direction: Direction, wheel_result: bool,
        ) {
            let player_address = get_caller_address();

            let mut world = self.world(@"card_knight");
            let mut player: Player = world.read_model((game_id, player_address));

            assert(self.levelUpWaiting(player_address, game_id) == false, 'Level up waiting');

            assert(player.hp != 0, 'Player is dead');
            let mut _old_player_card: Card = world.read_model((game_id, player.x, player.y));

            // delete!(world, (old_player_card));
            let (next_x, next_y) = match direction {
                Direction::Up => { (player.x, player.y + 1) },
                Direction::Down => {
                    assert!(player.y != 0, "Invalid move");
                    (player.x, player.y - 1)
                },
                Direction::Left => {
                    assert!(player.x != 0, "Invalid move");
                    (player.x - 1, player.y)
                },
                Direction::Right => { (player.x + 1, player.y) },
            };
            assert!(ICardImpl::is_inside(next_x, next_y) == true, "Invalid move");

            let mut existingCard: Card = world.read_model((game_id, next_x, next_y));

            assert(existingCard.card_id == CardIdEnum::Lock, 'Invalid card move to Lock');
            if (wheel_result == false) {
                player.hp = player.hp - 1;
                world.write_model(@player);
                return ();
            }

            let rnd = (player.x.into() * 3 + player.y.into() * 3 + game_id.into() + player.hp) % 10;

            if (rnd < 5) {
                let new_card = Card {
                    game_id: game_id,
                    x: next_x,
                    y: next_y,
                    card_id: CardIdEnum::ItemHeal,
                    hp: rnd,
                    max_hp: rnd,
                    shield: 0,
                    max_shield: 0,
                    xp: HEAL_XP,
                    tag: TagType::None,
                    flipped: existingCard.flipped,
                };
                world.write_model(@new_card);
            } else if (rnd < 8) {
                let new_card = Card {
                    game_id: game_id,
                    x: next_x,
                    y: next_y,
                    card_id: CardIdEnum::ItemShield,
                    hp: 0,
                    max_hp: 0,
                    shield: 3,
                    max_shield: 5,
                    xp: SHIELD_XP,
                    tag: TagType::None,
                    flipped: existingCard.flipped,
                };
                world.write_model(@new_card);
            } else {
                let new_card = Card {
                    game_id: game_id,
                    x: next_x,
                    y: next_y,
                    card_id: CardIdEnum::ItemPoison,
                    hp: 1,
                    max_hp: 1,
                    shield: 0,
                    max_shield: 0,
                    xp: POISON_XP,
                    tag: TagType::None,
                    flipped: existingCard.flipped,
                };
                world.write_model(@new_card);
            }
        }

        fn demon_deals(
            self: @ContractState, user: ContractAddress, game_id: u32,
        ) -> (ByteArray, ByteArray) {
            let mut world = self.world(@"card_knight");
            let mut player: Player = world.read_model((game_id, user));

            let rnd = (player.x.into() * 3 + player.y.into() * 3 + game_id.into() + player.hp) % 10;
            let hp_ = player.hp / 3;

            if (rnd < 5) {
                let option1: ByteArray = format!("Lose {} HP", hp_);
                let option2: ByteArray = "Gain 3 XP";
                return (option1, option2);
            } else if (rnd < 8) {
                let option1: ByteArray = "Lose 3 HP";
                let option2: ByteArray = "Gain 2 XP";
                return (option1, option2);
            }

            let option1: ByteArray = "Lose 10% point.";
            let option2: ByteArray = "Reset skill cooldown";

            (option1, option2)
        }

        // Will update assert
        fn move_to_deal(
            ref self: ContractState, game_id: u32, direction: Direction, selection: bool,
        ) {
            let player_address = get_caller_address();

            let mut world = self.world(@"card_knight");
            let mut player: Player = world.read_model((game_id, player_address));

            assert(self.levelUpWaiting(player_address, game_id) == false, 'Level up waiting');

            assert(player.hp != 0, 'Player is dead');
            let mut _old_player_card: Card = world.read_model((game_id, player.x, player.y));

            // delete!(world, (old_player_card));
            let (next_x, next_y) = match direction {
                Direction::Up => { (player.x, player.y + 1) },
                Direction::Down => {
                    assert!(player.y != 0, "Invalid move");
                    (player.x, player.y - 1)
                },
                Direction::Left => {
                    assert!(player.x != 0, "Invalid move");
                    (player.x - 1, player.y)
                },
                Direction::Right => { (player.x + 1, player.y) },
            };
            assert!(ICardImpl::is_inside(next_x, next_y) == true, "Invalid move");

            let mut existingCard: Card = world.read_model((game_id, next_x, next_y));

            assert(existingCard.card_id == CardIdEnum::DemonsDeal, 'Invalid card move to DD');

            if (selection) {
                let rnd = (player.x.into() * 3
                    + player.y.into() * 3
                    + game_id.into()
                    + player.hp) % 10;
                let hp_ = player.hp / 3;

                if (rnd < 5) {
                    player.hp = player.hp - hp_;
                    player.exp += 3;
                    player.total_xp += 3;
                } else if (rnd < 8) {
                    player.hp = player.hp - 3;
                    player.exp += 2;
                    player.total_xp += 2;
                } else {
                    player.exp = player.exp - player.exp / 10;
                    player.total_xp = player.total_xp - player.total_xp / 10;
                    player.turn = player.turn + 5;
                }
            }

            // if card is ItemChest dont change any position
            if (existingCard.card_id == CardIdEnum::ItemChest) {
                player.turn += 1;
                if (player.poisoned != 0) {
                    player.take_damage(1);
                    player.poisoned -= 1;
                }
                world.write_model(@player);

                return ();
            };

            let mut old_player_card: Card = world.read_model((game_id, player.x, player.y));

            // Move cards after use
            let moveCard = ICardImpl::get_move_card(
                world, game_id, existingCard.x, existingCard.y, player,
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
                        let mut card: Card = world.read_model((game_id, old_x, old_y));
                        let card_move = ICardImpl::move_to_position(
                            game_id, card, x_destination, y_destination,
                        );
                        world.write_model(@card_move);

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
                    game_id, moveCard, old_player_card.x, old_player_card.y,
                );
                world.write_model(@card_move);
            }

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
                xp: player.exp,
                tag: TagType::None,
                flipped: old_player_card.flipped,
            };
            world.write_model(@new_player_card);

            player.x = existingCard.x;
            player.y = existingCard.y;
            player.turn += 1;

            if (player.poisoned != 0) {
                player.take_damage(1);
                player.poisoned -= 1;
            }
            world.write_model(@player);
            apply_tag_effects(world, player);
            if (player.alive == false) {
                let week = get_block_timestamp() / WEEK;
                let mut week_index: WeeklyIndex = world.read_model((week, player_address));

                if (week_index.index == 0) {
                    let mut total_players: TotalWeeklyPlayers = world.read_model(week);

                    // Start from 0
                    week_index.index = total_players.total + 1;
                    world.write_model(@week_index);
                    total_players.total += 1;
                    world.write_model(@total_players);
                };

                let mut scores: Scores = world.read_model((week, week_index.index));
                if scores.high_score < player.total_xp {
                    scores.high_score = player.total_xp;
                    world.write_model(@scores);
                    let mut weekly_winner: WeeklyWinner = world.read_model(week);

                    if (weekly_winner.score < scores.high_score) {
                        weekly_winner.address = player_address;
                        weekly_winner.score = scores.high_score;
                        world.write_model(@weekly_winner);
                    }
                }
                // Player is dead game finished transfer xdil

            }

            ICardImpl::spawn_card(world, game_id, moveCard_x, moveCard_y, player);
        }


        // Will update assert
        fn move(ref self: ContractState, game_id: u32, direction: Direction) {
            let player_address = get_caller_address();

            let mut world = self.world(@"card_knight");
            let mut player: Player = world.read_model((game_id, player_address));

            assert(self.levelUpWaiting(player_address, game_id) == false, 'Level up waiting');

            assert(player.hp != 0, 'Player is dead');
            let mut _old_player_card: Card = world.read_model((game_id, player.x, player.y));

            // delete!(world, (old_player_card));
            let (next_x, next_y) = match direction {
                Direction::Up => { (player.x, player.y + 1) },
                Direction::Down => {
                    assert!(player.y != 0, "Invalid move");
                    (player.x, player.y - 1)
                },
                Direction::Left => {
                    assert!(player.x != 0, "Invalid move");
                    (player.x - 1, player.y)
                },
                Direction::Right => { (player.x + 1, player.y) },
            };
            assert!(ICardImpl::is_inside(next_x, next_y) == true, "Invalid move");

            let mut existingCard: Card = world.read_model((game_id, next_x, next_y));
            assert(
                existingCard.card_id != CardIdEnum::DemonsDeal
                    && existingCard.card_id != CardIdEnum::Lock,
                'Invalid card move to DD'
            );

            // Apply Effect was made to handle all kind of card => update apply_effect when more
            // cases are added
            let result = ICardImpl::apply_effect(world, player, existingCard);
            player = result;

            // if card is ItemChest dont change any position
            if (existingCard.card_id == CardIdEnum::ItemChest) {
                player.turn += 1;
                if (player.poisoned != 0) {
                    player.take_damage(1);
                    player.poisoned -= 1;
                }
                world.write_model(@player);

                return ();
            };

            let mut old_player_card: Card = world.read_model((game_id, player.x, player.y));

            // Move cards after use
            let moveCard = ICardImpl::get_move_card(
                world, game_id, existingCard.x, existingCard.y, player,
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
                        let mut card: Card = world.read_model((game_id, old_x, old_y));
                        let card_move = ICardImpl::move_to_position(
                            game_id, card, x_destination, y_destination,
                        );
                        world.write_model(@card_move);

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
                    game_id, moveCard, old_player_card.x, old_player_card.y,
                );
                world.write_model(@card_move);
            }

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
                xp: player.exp,
                tag: TagType::None,
                flipped: old_player_card.flipped,
            };
            world.write_model(@new_player_card);

            player.x = existingCard.x;
            player.y = existingCard.y;
            player.turn += 1;

            if (player.poisoned != 0) {
                player.take_damage(1);
                player.poisoned -= 1;
            }
            world.write_model(@player);
            apply_tag_effects(world, player);
            if (player.alive == false) {
                let week = get_block_timestamp() / WEEK;
                let mut week_index: WeeklyIndex = world.read_model((week, player_address));

                if (week_index.index == 0) {
                    let mut total_players: TotalWeeklyPlayers = world.read_model(week);

                    // Start from 0
                    week_index.index = total_players.total + 1;
                    world.write_model(@week_index);
                    total_players.total += 1;
                    world.write_model(@total_players);
                };

                let mut scores: Scores = world.read_model((week, week_index.index));
                if scores.high_score < player.total_xp {
                    scores.high_score = player.total_xp;
                    world.write_model(@scores);
                    let mut weekly_winner: WeeklyWinner = world.read_model(week);

                    if (weekly_winner.score < scores.high_score) {
                        weekly_winner.address = player_address;
                        weekly_winner.score = scores.high_score;
                        world.write_model(@weekly_winner);
                    }
                }
                // Player is dead game finished transfer xdil

            }

            ICardImpl::spawn_card(world, game_id, moveCard_x, moveCard_y, player);
        }


        fn use_skill(ref self: ContractState, game_id: u32, skill: Skill, direction: Direction) {
            let player_address = get_caller_address();

            let mut world = self.world(@"card_knight");

            let mut player: Player = world.read_model((game_id, player_address));
            assert(player.hp != 0, 'Player is dead');

            player.validate_skill(skill);

            let mut player_skill: PlayerSkill = world.read_model((game_id, player_address, skill));
            assert(!is_silent(world, player), 'Silence active');

            assert(player_skill.is_active(player.level), 'User level not enough');
            player_skill.use_skill(player, skill, world, direction);
            player_skill.last_use = player.turn;
            world.write_model(@player_skill);

            let mut player: Player = world.read_model((game_id, player_address));
            let mut old_player_card: Card = world.read_model((game_id, player.x, player.y));
            let new_player_card = Card {
                game_id,
                x: player.x,
                y: player.y,
                card_id: CardIdEnum::Player,
                hp: player.hp,
                max_hp: player.max_hp,
                shield: player.shield,
                max_shield: player.max_shield,
                xp: player.exp,
                tag: TagType::None,
                flipped: old_player_card.flipped,
            };
            world.write_model(@new_player_card);
        }


        fn use_swap_skill(ref self: ContractState, game_id: u32, x: u32, y: u32) {
            let player_address = get_caller_address();
            let mut world = self.world(@"card_knight");

            let mut player: Player = world.read_model((game_id, player_address));
            let skill = Skill::Teleport;
            player.validate_skill(skill);

            let mut player_skill: PlayerSkill = world.read_model((game_id, player_address, skill));
            assert(!is_silent(world, player), 'Silence active');

            assert(x < 3 && y < 3, 'Invalid swap inputs');
            if (player.x == x) {
                assert(player.y != y, 'Invalid swap inputs');
            };

            assert(player_skill.is_active(player.level), 'User level not enough');
            player_skill.use_swap_skill(player, world, x, y);

            player = world.read_model((game_id, player_address));

            player_skill.last_use = player.turn;
            world.write_model(@player_skill);
            player.turn += 1;
            if (player.poisoned != 0) {
                player.take_damage(1);
                player.poisoned -= 1;
            }

            let mut old_player_card: Card = world.read_model((game_id, player.x, player.y));
            let new_player_card = Card {
                game_id,
                x: player.x,
                y: player.y,
                card_id: CardIdEnum::Player,
                hp: player.hp,
                max_hp: player.max_hp,
                shield: player.shield,
                max_shield: player.max_shield,
                xp: player.exp,
                tag: TagType::None,
                flipped: old_player_card.flipped,
            };
            world.write_model(@new_player_card);

            world.write_model(@player);
        }


        fn use_curse_skill(ref self: ContractState, game_id: u32, x: u32, y: u32) {
            let player_address = get_caller_address();
            let mut world = self.world(@"card_knight");

            let skill = Skill::Curse;
            let mut player: Player = world.read_model((game_id, player_address));
            assert(player.hp != 0, 'Player is dead');

            player.validate_skill(skill);

            let mut player_skill: PlayerSkill = world.read_model((game_id, player_address, skill));
            assert(!is_silent(world, player), 'Silence active');
            assert(x < 3 && y < 3, 'Position not valid');
            assert(
                player_skill.last_use == 0 || player_skill.last_use + BIG_SKILL_CD <= player.turn,
                'Skill cooldown',
            );

            assert(player_skill.is_active(player.level), 'User level not enough');
            player_skill.use_curse_skill(world, player.game_id, x, y);
            player_skill.last_use = player.turn;
            world.write_model(@player_skill);
        }

        fn level_up(ref self: ContractState, game_id: u32, upgrade: u32) {
            let player_address = get_caller_address();
            let mut world = self.world(@"card_knight");
            let mut player: Player = world.read_model((game_id, player_address));
            assert(player.hp != 0, 'Player is dead');
            player.level_up(upgrade);

            let mut old_player_card: Card = world.read_model((game_id, player.x, player.y));

            let new_player_card = Card {
                game_id,
                x: player.x,
                y: player.y,
                card_id: CardIdEnum::Player,
                hp: player.hp,
                max_hp: player.max_hp,
                shield: player.shield,
                max_shield: player.max_shield,
                xp: player.exp,
                tag: TagType::None,
                flipped: old_player_card.flipped,
            };
            world.write_model(@new_player_card);
            world.write_model(@player);
        }

        // 0 -> second owner
        // 1-> core contract
        // 2-> reward contract
        fn set_contract(ref self: ContractState, index: u128, new_address: ContractAddress) {
            let strk_receiver: ContractAddress = STRK_RECEIVER.try_into().unwrap();
            let mut world = self.world(@"card_knight");
            let mut owner: Contracts = world.read_model(0);

            assert(
                get_caller_address() == strk_receiver || get_caller_address() == owner.address,
                'Caller not owner',
            );
            let mut contract: Contracts = world.read_model(index);
            contract.address = new_address;
            world.write_model(@contract);
        }

        fn get_total_weekly_players(self: @ContractState, week: u64) -> u128 {
            let mut world = self.world(@"card_knight");

            let mut total_players: TotalWeeklyPlayers = world.read_model(week);

            total_players.total
        }

        fn get_player_weekly_highest_score(
            self: @ContractState, player: ContractAddress, week: u64,
        ) -> u32 {
            let mut world = self.world(@"card_knight");
            let mut week_index: WeeklyIndex = world.read_model((week, player));
            let mut scores: Scores = world.read_model((week, week_index.index));
            scores.high_score
        }


        fn get_weekly_scores(
            self: @ContractState, player: ContractAddress, week: u64, start: u128, end: u128,
        ) -> Array<Scores> {
            let mut scores: Array<Scores> = ArrayTrait::new();
            let mut world = self.world(@"card_knight");
            let mut total_players: TotalWeeklyPlayers = world.read_model(week);

            let mut end_ = if end > total_players.total {
                total_players.total
            } else {
                end
            };

            let mut i = start;
            loop {
                if i > end_ {
                    break;
                }
                let mut score: Scores = world.read_model((week, i));
                scores.append(score);
                i += 1;
            };
            scores
        }

        fn winner_of_the_week(self: @ContractState, week: u64) -> ContractAddress {
            let mut world = self.world(@"card_knight");
            let mut weekly_winner: WeeklyWinner = world.read_model(week);
            weekly_winner.address
        }

        fn hero_skills_cd(
            self: @ContractState, game_id: u32, player_address: ContractAddress,
        ) -> (u32, u32, u32) {
            let mut world = self.world(@"card_knight");
            let mut player_: Player = world.read_model((game_id, player_address));

            let (skill1, skill2, skill3) = self.hero_skills(player_.heroId);
            let cd1 = self.skill_cd(game_id, player_address, skill1);
            let cd2 = self.skill_cd(game_id, player_address, skill2);
            let cd3 = self.skill_cd(game_id, player_address, skill3);

            (cd1, cd2, cd3)
        }

        fn skill_cd(
            self: @ContractState, game_id: u32, player_address: ContractAddress, skill: Skill,
        ) -> u32 {
            let mut world = self.world(@"card_knight");
            let mut player: Player = world.read_model((game_id, player_address));

            let mut player_skill: PlayerSkill = world.read_model((game_id, player_address, skill));

            if (player_skill.last_use == 0) {
                return 0;
            }
            if (skill == Skill::Regeneration || skill == Skill::Curse) {
                if (player.turn >= player_skill.last_use + BIG_SKILL_CD) {
                    return (0);
                } else {
                    return (player_skill.last_use + BIG_SKILL_CD - player.turn);
                }
            }
            if (player.turn >= player_skill.last_use + SKILL_CD) {
                return (0);
            }
            player_skill.last_use + SKILL_CD - player.turn
        }


        fn hero_skills(self: @ContractState, hero: Hero) -> (Skill, Skill, Skill) {
            if (hero == Hero::Knight) {
                (Skill::PowerupSlash, Skill::Teleport, Skill::Regeneration)
            } else if (hero == Hero::Shaman) {
                (Skill::Hex, Skill::Shuffle, Skill::Meteor)
            } else {
                (Skill::LifeSteal, Skill::Teleport, Skill::Curse)
            }
        }


        fn levelUpWaiting(self: @ContractState, user: ContractAddress, game_id: u32) -> bool {
            let mut world = self.world(@"card_knight");
            let mut player: Player = world.read_model((game_id, user));
            let level = player.level;

            let result = match level {
                0 => false,
                1 => player.total_xp >= level::LEVEL2_XP,
                2 => player.total_xp >= level::LEVEL3_XP,
                3 => player.total_xp >= level::LEVEL4_XP,
                4 => player.total_xp >= level::LEVEL5_XP,
                5 => player.total_xp >= level::LEVEL6_XP,
                _ => false,
            };
            result
        }

        fn levelUpOptions(
            self: @ContractState, user: ContractAddress, game_id: u32,
        ) -> (ByteArray, ByteArray) {
            let mut world = self.world(@"card_knight");
            let mut player: Player = world.read_model((game_id, user));
            let level = player.level;

            match level {
                0 => {
                    let option1: ByteArray = "";
                    let option2: ByteArray = "";
                    (option1, option2)
                },
                1 => {
                    if player.total_xp >= level::LEVEL2_XP {
                        let option1: ByteArray = "+20% Max HP";
                        let option2: ByteArray = "Heal 40% of max HP";
                        (option1, option2)
                    } else {
                        let option1: ByteArray = "";
                        let option2: ByteArray = "";
                        (option1, option2)
                    }
                },
                2 => {
                    if player.total_xp >= level::LEVEL3_XP {
                        let option1: ByteArray = "+20% Max Armor";
                        let option2: ByteArray = "Full Heal";
                        (option1, option2)
                    } else {
                        let option1: ByteArray = "";
                        let option2: ByteArray = "";
                        (option1, option2)
                    }
                },
                3 => {
                    if player.total_xp >= level::LEVEL4_XP {
                        let option1: ByteArray = "+30% Max HP";
                        let option2: ByteArray = "Heal 60% of max HP";
                        (option1, option2)
                    } else {
                        let option1: ByteArray = "";
                        let option2: ByteArray = "";
                        (option1, option2)
                    }
                },
                4 => {
                    if player.total_xp >= level::LEVEL5_XP {
                        let option1: ByteArray = "+30% Max Armor";
                        let option2: ByteArray = "Full Heal";
                        (option1, option2)
                    } else {
                        let option1: ByteArray = "";
                        let option2: ByteArray = "";
                        (option1, option2)
                    }
                },
                5 => {
                    if player.total_xp >= level::LEVEL6_XP {
                        let option1: ByteArray = "+30% Max HP";
                        let option2: ByteArray = "Full Heal";
                        (option1, option2)
                    } else {
                        let option1: ByteArray = "";
                        let option2: ByteArray = "";
                        (option1, option2)
                    }
                },
                _ => {
                    let option1: ByteArray = "";
                    let option2: ByteArray = "";
                    (option1, option2)
                },
            }
        }
    }
}
