#[cfg(test)]
mod tests {
    use starknet::class_hash::Felt252TryIntoClassHash;
    use starknet::ContractAddress;

    // import world dispatcher
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};
    use dojo::model::{Model, ModelTest, ModelIndex, ModelEntityTest};

    // import test utils
    use dojo::utils::test::deploy_contract;

    // import test utils
    use card_knight::{
        systems::{actions::{actions, IActionsDispatcher, IActionsDispatcherTrait}},
        models::{
            game::{Game, Direction, GameState, TagType},
            card::{Card, CardIdEnum, ICardImpl, ICardTrait,}, player::{Player, IPlayer, Hero},
            skill::{Skill, PlayerSkill, IPlayerSkill},
        },
        config::level,
        config::card::{
            MONSTER1_BASE_HP, MONSTER1_MULTIPLE, MONSTER2_BASE_HP, MONSTER2_MULTIPLE,
            MONSTER3_BASE_HP, MONSTER3_MULTIPLE, MONSTER1_XP, MONSTER2_XP, MONSTER3_XP, BOSS_XP,
            HEAL_XP, POISON_XP, SHIELD_XP, CHEST_XP, POISON_TURN, INCREASE_HP_RATIO, card_sequence
        }
    };


    #[test]
    #[available_gas(3000000000000000)]
    fn test_setup() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        // deploy world with models
        let world = spawn_test_world!();

        // deploy systems contract
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let _actions_system = IActionsDispatcher { contract_address };

        // set authorizations
        world.grant_writer(Model::<Game>::selector(), contract_address);
        world.grant_writer(Model::<Card>::selector(), contract_address);
        world.grant_writer(Model::<Player>::selector(), contract_address);
        world.grant_writer(Model::<PlayerSkill>::selector(), contract_address);

        world_setup(world, false);
        let player = player_setup(caller);
        set!(world, (player));

        let mut card = get!(world, (1, 1, 1), (Card));

        assert(card.card_id == CardIdEnum::Player, 'Error cardid');
        assert(card.hp == 10, 'Error hp');
        assert(card.xp == 0, 'Error xp');

        let mut card = get!(world, (1, 0, 1), (Card));
        assert(card.card_id == CardIdEnum::Monster1, 'Error cardid');
        assert(card.hp == 10, 'Error hp');
        assert(card.xp == 2, 'Error xp');

        let mut card = get!(world, (1, 2, 2), (Card));
        assert(card.card_id == CardIdEnum::Monster1, 'Error cardid');
        assert(card.hp == 10, 'Error hp');
        assert(card.xp == 2, 'Error xp');
    }


    #[test]
    #[available_gas(3000000000000000)]
    fn test_skill_fire() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        // deploy world with models
        let world = spawn_test_world!();

        // deploy systems contract
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let _actions_system = IActionsDispatcher { contract_address };

        // set authorizations
        world.grant_writer(Model::<Game>::selector(), contract_address);
        world.grant_writer(Model::<Card>::selector(), contract_address);
        world.grant_writer(Model::<Player>::selector(), contract_address);
        world.grant_writer(Model::<PlayerSkill>::selector(), contract_address);

        world_setup(world, false);
        let mut player = player_setup(caller);
        set!(world, (player));

        let mut player_skill = get!(world, (1, caller, Skill::SkillFire), (PlayerSkill));
        player.turn = 10;
        player_skill.use_skill(player, Skill::SkillFire, world, Direction::Up);

        let mut card = get!(world, (1, 0, 1), (Card));
        assert(card.card_id == CardIdEnum::Monster1, 'Error cardid');
        assert(card.hp == 8, 'Error hp');
        assert(card.xp == 2, 'Error xp');

        let mut card = get!(world, (1, 1, 1), (Card));
        assert(card.hp == 10, 'Error hp');

        let mut card = get!(world, (1, 2, 1), (Card));
        assert(card.hp == 8, 'Error hp');

        let mut card = get!(world, (1, 2, 2), (Card));
        assert(card.hp == 8, 'Error hp');
    }


    #[test]
    #[available_gas(3000000000000000)]
    fn test_skill_fire_with_no_magic() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        // deploy world with models
        let world = spawn_test_world!();

        // deploy systems contract
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let _actions_system = IActionsDispatcher { contract_address };

        // set authorizations
        world.grant_writer(Model::<Game>::selector(), contract_address);
        world.grant_writer(Model::<Card>::selector(), contract_address);
        world.grant_writer(Model::<Player>::selector(), contract_address);
        world.grant_writer(Model::<PlayerSkill>::selector(), contract_address);

        world_setup(world, false);
        let mut player = player_setup(caller);
        set!(world, (player));

        set!(
            world,
            (
                Card {
                    game_id: 1,
                    x: 2,
                    y: 2,
                    card_id: CardIdEnum::Monster1,
                    hp: 10,
                    max_hp: 10,
                    shield: 0,
                    max_shield: 0,
                    xp: 2,
                    tag: TagType::NoMagic,
                    flipped: false,
                },
            )
        );

        set!(
            world,
            (
                Card {
                    game_id: 1,
                    x: 0,
                    y: 0,
                    card_id: CardIdEnum::ItemHeal,
                    hp: 10,
                    max_hp: 10,
                    shield: 0,
                    max_shield: 0,
                    xp: 2,
                    tag: TagType::None,
                    flipped: false,
                },
            )
        );

        let mut player_skill = get!(world, (1, caller, Skill::SkillFire), (PlayerSkill));
        player.turn = 10;
        player_skill.use_skill(player, Skill::SkillFire, world, Direction::Up);

        let mut card = get!(world, (1, 2, 1), (Card));
        assert(card.hp == 8, 'Error hp');

        let mut card = get!(world, (1, 2, 2), (Card));
        assert(card.hp == 10, 'Error hp');

        let mut card = get!(world, (1, 0, 0), (Card));
        assert(card.hp == 10, 'Error hp');
    }


    #[test]
    #[available_gas(3000000000000000)]
    fn test_skill_powerup_slash() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        // deploy world with models
        let world = spawn_test_world!();

        // deploy systems contract
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let _actions_system = IActionsDispatcher { contract_address };

        // set authorizations
        world.grant_writer(Model::<Game>::selector(), contract_address);
        world.grant_writer(Model::<Card>::selector(), contract_address);
        world.grant_writer(Model::<Player>::selector(), contract_address);
        world.grant_writer(Model::<PlayerSkill>::selector(), contract_address);

        world_setup(world, false);
        let mut player = player_setup(caller);
        set!(world, (player));

        let mut player_skill = get!(world, (1, caller, Skill::PowerupSlash), (PlayerSkill));
        player.turn = 10;
        player_skill.use_skill(player, Skill::PowerupSlash, world, Direction::Up);

        let mut card = get!(world, (1, 0, 0), (Card));

        // println!("card hp {}", card.hp);

        assert(card.hp == 10, 'Error hp1');

        let mut card = get!(world, (1, 1, 0), (Card));
        assert(card.hp == 7, 'Error hp2');

        let mut card = get!(world, (1, 0, 1), (Card));
        assert(card.hp == 7, 'Error hp3');
    }


    #[test]
    #[available_gas(3000000000000000)]
    fn test_skill_powerup_slash_with_boss() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        // deploy world with models
        let world = spawn_test_world!();

        // deploy systems contract
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let _actions_system = IActionsDispatcher { contract_address };

        // set authorizations
        world.grant_writer(Model::<Game>::selector(), contract_address);
        world.grant_writer(Model::<Card>::selector(), contract_address);
        world.grant_writer(Model::<Player>::selector(), contract_address);
        world.grant_writer(Model::<PlayerSkill>::selector(), contract_address);

        world_setup(world, true);

        let mut player = player_setup(caller);
        set!(world, (player));
        let boss = boss_setup(CardIdEnum::Boss1, 1);
        set!(world, (boss));

        let mut card = get!(world, (1, 0, 0), (Card));
        assert(card.flipped == true, 'Error flipped');

        let mut card = get!(world, (1, 1, 2), (Card));
        assert(card.flipped == true, 'Error flipped');

        let mut player_skill = get!(world, (1, caller, Skill::PowerupSlash), (PlayerSkill));
        player.turn = 10;

        player_skill.use_skill(player, Skill::PowerupSlash, world, Direction::Up);

        let mut card = get!(world, (1, 2, 2), (Card));
        assert(card.hp == 10, 'Error hp2');

        let mut card = get!(world, (1, 1, 2), (Card));
        assert(card.flipped == false, 'Error flipped');
        assert(card.hp == 7, 'Error hp3');

        let mut card = get!(world, (1, 1, 9), (Card));
        assert(card.flipped == false, 'Error flipped');
        assert(card.card_id != CardIdEnum::Boss1, 'Error card_id');
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_skill_meteor() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        // deploy world with models
        let world = spawn_test_world!();

        // deploy systems contract
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let _actions_system = IActionsDispatcher { contract_address };

        // set authorizations
        world.grant_writer(Model::<Game>::selector(), contract_address);
        world.grant_writer(Model::<Card>::selector(), contract_address);
        world.grant_writer(Model::<Player>::selector(), contract_address);
        world.grant_writer(Model::<PlayerSkill>::selector(), contract_address);

        world_setup(world, true);

        let mut player = player_setup(caller);
        set!(world, (player));

        let mut player_skill = get!(world, (1, caller, Skill::Meteor), (PlayerSkill));
        player.turn = 10;
        player.max_hp = 8;

        player_skill.use_skill(player, Skill::Meteor, world, Direction::Up);

        let mut card = get!(world, (1, 0, 1), (Card));
        assert(card.card_id == CardIdEnum::Monster1, 'Error cardid');
        assert(card.hp == 8, 'Error hp');
        assert(card.xp == 2, 'Error xp');

        let mut card = get!(world, (1, 1, 1), (Card));
        assert(card.hp == 10, 'Error hp');

        let mut card = get!(world, (1, 2, 1), (Card));
        assert(card.hp == 8, 'Error hp');

        let mut card = get!(world, (1, 2, 2), (Card));
        assert(card.hp == 8, 'Error hp');
    }
    #[test]
    #[available_gas(3000000000000000)]
    fn test_hex() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        // deploy world with models
        let world = spawn_test_world!();

        // deploy systems contract
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let _actions_system = IActionsDispatcher { contract_address };

        // set authorizations
        world.grant_writer(Model::<Game>::selector(), contract_address);
        world.grant_writer(Model::<Card>::selector(), contract_address);
        world.grant_writer(Model::<Player>::selector(), contract_address);
        world.grant_writer(Model::<PlayerSkill>::selector(), contract_address);

        world_setup(world, true);

        let mut player = player_setup(caller);
        set!(world, (player));

        let mut player_skill = get!(world, (1, caller, Skill::Hex), (PlayerSkill));
        player.turn = 10;
        player.max_hp = 8;

        player_skill.use_skill(player, Skill::Hex, world, Direction::Up);

        let mut card = get!(world, (1, 1, 2), (Card));
        assert(card.card_id == CardIdEnum::Hex, 'Error cardid');
        assert(card.hp == 0, 'Error hp');
        assert(card.xp == 0, 'Error xp');
    }
    #[test]
    #[available_gas(3000000000000000)]
    fn test_regeneration() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        // deploy world with models
        let world = spawn_test_world!();

        // deploy systems contract
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let _actions_system = IActionsDispatcher { contract_address };

        // set authorizations
        world.grant_writer(Model::<Game>::selector(), contract_address);
        world.grant_writer(Model::<Card>::selector(), contract_address);
        world.grant_writer(Model::<Player>::selector(), contract_address);
        world.grant_writer(Model::<PlayerSkill>::selector(), contract_address);

        world_setup(world, true);

        let mut player = player_setup(caller);
        set!(world, (player));

        let mut player_skill = get!(world, (1, caller, Skill::Regeneration), (PlayerSkill));
        player.turn = 10;
        player.max_hp = 100;
        player.hp = 10;

        player_skill.use_skill(player, Skill::Regeneration, world, Direction::Up);
        let player = get!(world, (1, caller), (Player));
        assert(player.hp == 100, 'Error hp');
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_life_steal() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        // deploy world with models
        let world = spawn_test_world!();

        // deploy systems contract
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let _actions_system = IActionsDispatcher { contract_address };

        // set authorizations
        world.grant_writer(Model::<Game>::selector(), contract_address);
        world.grant_writer(Model::<Card>::selector(), contract_address);
        world.grant_writer(Model::<Player>::selector(), contract_address);
        world.grant_writer(Model::<PlayerSkill>::selector(), contract_address);

        world_setup(world, true);

        let mut player = player_setup(caller);
        set!(world, (player));

        let mut player_skill = get!(world, (1, caller, Skill::LifeSteal), (PlayerSkill));
        player.turn = 10;
        player.max_hp = 10;
        player.hp = 9;

        player_skill.use_skill(player, Skill::LifeSteal, world, Direction::Up);
        let player = get!(world, (1, caller), (Player));
        assert(player.hp == 10, 'Error hp');

        let mut card = get!(world, (1, 1, 2), (Card));
        println!("card hp {}", card.hp);
        assert(card.hp == 7, 'Error hp2');
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_shuffle() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        // deploy world with models
        let world = spawn_test_world!();

        // deploy systems contract
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let _actions_system = IActionsDispatcher { contract_address };

        // set authorizations
        world.grant_writer(Model::<Game>::selector(), contract_address);
        world.grant_writer(Model::<Card>::selector(), contract_address);
        world.grant_writer(Model::<Player>::selector(), contract_address);
        world.grant_writer(Model::<PlayerSkill>::selector(), contract_address);

        world_setup(world, true);

        let mut player = player_setup(caller);
        set!(world, (player));

        let mut card = get!(world, (1, 0, 0), (Card));
        card.hp = 123;
        set!(world, (card));

        let mut card = get!(world, (1, 1, 0), (Card));
        card.hp = 456;
        set!(world, (card));

        let mut card = get!(world, (1, 2, 2), (Card));
        card.hp = 789;
        set!(world, (card));

        let mut initial_positions = ArrayTrait::new();
        let mut x: u32 = 0;
        let mut y: u32 = 0;
        while x <= 2 {
            while y <= 2 {
                if x != 1 || y != 1 { // Exclude player position
                    let card = get!(world, (1, x, y), (Card));
                    initial_positions.append((x, y, card.hp));
                }
                y += 1;
            };
            y = 0;
            x += 1;
        };

        let mut player_skill = get!(world, (1, caller, Skill::Shuffle), (PlayerSkill));
        player.turn = 10;

        player_skill.use_skill(player, Skill::Shuffle, world, Direction::Up);

        // Check if cards have been shuffled
        let mut shuffled = false;
        x = 0;
        y = 0;
        while x <= 2 {
            while y <= 2 {
                if x != 1 || y != 1 { // Exclude player position
                    let card = get!(world, (1, x, y), (Card));
                    let mut i = 0;
                    loop {
                        if i == initial_positions.len() {
                            break;
                        }
                        let (init_x, init_y, hp) = *initial_positions.at(i);
                        if init_x == x && init_y == y && hp != card.hp {
                            shuffled = true;
                            break;
                        }
                        i += 1;
                    };
                    if shuffled {
                        break;
                    }
                }
                y += 1;
            };
            if shuffled {
                break;
            }
            y = 0;
            x += 1;
        };

        assert(shuffled, 'Cards were not shuffled');
    }


    #[test]
    #[available_gas(3000000000000000)]
    fn test_curse_skill() {
        // Setup
        let caller = starknet::contract_address_const::<0x0>();
        let world = spawn_test_world!();
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let _actions_system = IActionsDispatcher { contract_address };

        // Set authorizations
        world.grant_writer(Model::<Game>::selector(), contract_address);
        world.grant_writer(Model::<Card>::selector(), contract_address);
        world.grant_writer(Model::<Player>::selector(), contract_address);
        world.grant_writer(Model::<PlayerSkill>::selector(), contract_address);

        world_setup(world, false);

        // Create a monster card
        let monster_card = Card {
            game_id: 1,
            x: 2,
            y: 2,
            card_id: CardIdEnum::Monster1,
            hp: 100,
            max_hp: 100,
            shield: 0,
            max_shield: 0,
            xp: 0,
            tag: TagType::None,
            flipped: false,
        };
        set!(world, (monster_card));
        let mut player = player_setup(caller);
        set!(world, (player));

        let player_skill = get!(world, (1, caller, Skill::Curse), (PlayerSkill));
        player.turn = 10;
        // Use curse skill
        player_skill.use_curse_skill(world, 1, 2, 2);

        // Check if the monster's HP was reduced by half
        let cursed_card = get!(world, (1, 2, 2), (Card));
        assert(cursed_card.hp == 50, 'Error cursed card hp');
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_swap_skill() {
        // Setup
        let caller = starknet::contract_address_const::<0x0>();
        let world = spawn_test_world!();
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let _actions_system = IActionsDispatcher { contract_address };

        // Set authorizations
        world.grant_writer(Model::<Game>::selector(), contract_address);
        world.grant_writer(Model::<Card>::selector(), contract_address);
        world.grant_writer(Model::<Player>::selector(), contract_address);
        world.grant_writer(Model::<PlayerSkill>::selector(), contract_address);

        world_setup(world, false);

        // Setup player
        let mut player = player_setup(caller);
        player.x = 1;
        player.y = 1;
        player.turn = 10; // Ensure turn is high enough to pass cooldown check
        set!(world, (player));

        // Setup player card
        let player_card = Card {
            game_id: 1,
            x: 1,
            y: 1,
            card_id: CardIdEnum::Player,
            hp: 100,
            max_hp: 100,
            shield: 0,
            max_shield: 0,
            xp: 0,
            tag: TagType::None,
            flipped: false,
        };
        set!(world, (player_card));

        // Setup target card to swap with
        let target_card = Card {
            game_id: 1,
            x: 1,
            y: 2,
            card_id: CardIdEnum::Monster1,
            hp: 50,
            max_hp: 50,
            shield: 0,
            max_shield: 0,
            xp: 0,
            tag: TagType::None,
            flipped: false,
        };
        set!(world, (target_card));

        let player_skill = get!(world, (1, caller, Skill::Teleport), (PlayerSkill));

        // Use swap skill
        player_skill.use_swap_skill(player, world, Direction::Up);

        // Check if player position has changed
        let updated_player = get!(world, (1, caller), (Player));
        assert(updated_player.x == 1 && updated_player.y == 2, 'Error position ');

        // Check if cards have swapped positions
        let swapped_player_card = get!(world, (1, 1, 2), (Card));
        let swapped_target_card = get!(world, (1, 1, 1), (Card));

        assert(swapped_player_card.card_id == CardIdEnum::Player, 'Error new position');
        assert(swapped_target_card.card_id == CardIdEnum::Monster1, 'Error old position');
    }

    #[test]
    #[should_panic(expected: ('Card not monster',))]
    #[available_gas(3000000000000000)]
    fn test_curse_skill_panic() {
        // Setup
        let caller = starknet::contract_address_const::<0x0>();
        let world = spawn_test_world!();
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let _actions_system = IActionsDispatcher { contract_address };

        // Set authorizations
        world.grant_writer(Model::<Game>::selector(), contract_address);
        world.grant_writer(Model::<Card>::selector(), contract_address);
        world.grant_writer(Model::<Player>::selector(), contract_address);
        world.grant_writer(Model::<PlayerSkill>::selector(), contract_address);

        world_setup(world, false);

        // Create a monster card
        let monster_card = Card {
            game_id: 1,
            x: 2,
            y: 2,
            card_id: CardIdEnum::ItemShield,
            hp: 100,
            max_hp: 100,
            shield: 0,
            max_shield: 0,
            xp: 0,
            tag: TagType::None,
            flipped: false,
        };
        set!(world, (monster_card));
        let mut player = player_setup(caller);
        set!(world, (player));

        let player_skill = get!(world, (1, caller, Skill::Curse), (PlayerSkill));
        player.turn = 10;
        // Use curse skill
        player_skill.use_curse_skill(world, 1, 2, 2);

        // Check if the monster's HP was reduced by half
        let cursed_card = get!(world, (1, 2, 2), (Card));
        assert(cursed_card.hp == 50, 'Error cursed card hp');
    }


    #[test]
    #[should_panic(expected: ('Skill cooldown',))]
    #[available_gas(3000000000000000)]
    fn test_skill_cooldown_panic() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        // deploy world with models
        let world = spawn_test_world!();

        // deploy systems contract
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let _actions_system = IActionsDispatcher { contract_address };

        // set authorizations
        world.grant_writer(Model::<Game>::selector(), contract_address);
        world.grant_writer(Model::<Card>::selector(), contract_address);
        world.grant_writer(Model::<Player>::selector(), contract_address);
        world.grant_writer(Model::<PlayerSkill>::selector(), contract_address);

        world_setup(world, false);
        let mut player = player_setup(caller);
        set!(world, (player));

        let mut player_skill = get!(world, (1, caller, Skill::SkillFire), (PlayerSkill));
        player.turn = 0;
        player_skill.use_skill(player, Skill::SkillFire, world, Direction::Up);
    }


    fn world_setup(world: IWorldDispatcher, flipped: bool) {
        let mut x: u32 = 0;
        let mut y: u32 = 0;

        // loop through every square in 3x3 board
        while x <= 2 {
            while y <= 2 {
                set!(
                    world,
                    (
                        Card {
                            game_id: 1,
                            x: x,
                            y: y,
                            card_id: CardIdEnum::Monster1,
                            hp: 10,
                            max_hp: 10,
                            shield: 0,
                            max_shield: 0,
                            xp: 2,
                            tag: TagType::None,
                            flipped: flipped,
                        },
                    )
                );
                y += 1;
            };
            y = 0;
            x += 1;
        };

        set!(
            world,
            (
                Card {
                    game_id: 1,
                    x: 1,
                    y: 1,
                    card_id: CardIdEnum::Player,
                    hp: 10,
                    max_hp: 10,
                    shield: 0,
                    max_shield: 0,
                    xp: 0,
                    tag: TagType::None,
                    flipped: false,
                },
            )
        );
    }


    fn card_setup(card_id: CardIdEnum, hp: u32) -> Card {
        Card {
            game_id: 1,
            x: 2,
            y: 2,
            card_id: card_id,
            hp: hp,
            max_hp: 10,
            shield: 0,
            max_shield: 0,
            xp: 2,
            tag: TagType::None,
            flipped: false,
        }
    }

    fn boss_setup(card_id: CardIdEnum, hp: u32) -> Card {
        Card {
            game_id: 1,
            x: 1,
            y: 0,
            card_id: card_id,
            hp: hp,
            max_hp: 10,
            shield: 0,
            max_shield: 0,
            xp: 2,
            tag: TagType::None,
            flipped: false,
        }
    }


    fn player_setup(caller: ContractAddress) -> Player {
        Player {
            game_id: 1,
            player: caller,
            x: 1,
            y: 1,
            hp: 10,
            max_hp: 10,
            shield: 0,
            max_shield: 10,
            exp: 5,
            total_xp: 10,
            level: 1,
            high_score: 0,
            sequence: 0,
            alive: true,
            poisoned: 0,
            turn: 0,
            heroId: Hero::Knight
        }
    }
}
