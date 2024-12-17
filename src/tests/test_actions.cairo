#[cfg(test)]
mod tests {
    use starknet::class_hash::Felt252TryIntoClassHash;
    use starknet::ContractAddress;

    // import test utils
    use card_knight::{
        systems::{actions::{actions, IActionsDispatcher, IActionsDispatcherTrait}},
        models::{
            game::{Game, Direction, GameState, TagType},
            card::{Card, CardIdEnum, ICardImpl, ICardTrait,}, player::{Player, IPlayer, Hero},
            skill::{Skill, PlayerSkill},
        },
        config::level,
        config::card::{
            MONSTER1_BASE_HP, MONSTER1_MULTIPLE, MONSTER2_BASE_HP, MONSTER2_MULTIPLE,
            MONSTER3_BASE_HP, MONSTER3_MULTIPLE, HEAL_HP, SHIELD_HP, MONSTER1_XP, HEAL_XP,
            card_sequence, POISON_TURN, SHIELD_XP, POISON_XP, BOSS_XP
        },
    };


    use dojo::model::{ModelStorage, ModelValueStorage};
    use dojo::event::EventStorage;
    use dojo::world::{
        IWorld, IWorldDispatcher, IWorldDispatcherTrait, WorldStorage, WorldStorageTrait
    };
    use dojo_cairo_test::{
        spawn_test_world, NamespaceDef, TestResource, ContractDefTrait, ContractDef,
        WorldStorageTestTrait
    };

    use card_knight::models::game::m_Game;
    use card_knight::models::card::m_Card;
    use card_knight::models::player::m_Player;
    use card_knight::models::skill::m_PlayerSkill;

    #[test]
    #[available_gas(3000000000000000)]
    fn test_game_start() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"actions").unwrap();
        let card_knight = IActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);

        let hero = Hero::Knight;
        card_knight.start_game(1, hero);

        // Check if player was created
        let mut player: Player = world.read_model((1, caller));
        assert(player.game_id == 1, 'Wrong game ID for player');
        assert(player.player == caller, 'Wrong player address');
        assert(player.heroId == hero, 'Wrong hero type');
        assert(player.hp == 10, 'Wrong initial HP');
        assert(player.max_hp == 10, 'Wrong max HP');
        assert(player.level == 1, 'Wrong initial level');

        let mut player_card: Card = world.read_model((1, 1, 1));

        assert(player_card.x == 1, 'Error x');
        assert(player_card.y == 1, 'Error y');
        assert(player_card.card_id == CardIdEnum::Player, 'Error card_id');

        // Check if cards were created
        let mut total_cards = 0;
        let mut player_card_found = false;
        let mut total_monsters: u32 = 0;
        let mut x: u32 = 0;
        let mut y: u32 = 0;
        while x < 3 {
            while y < 3 {
                let card: Card = world.read_model((1, x, y));

                if card.card_id != CardIdEnum::None {
                    total_cards += 1;
                    if card.card_id == CardIdEnum::Monster1 {
                        total_monsters += 1;
                    }
                    if card.card_id == CardIdEnum::Player {
                        player_card_found = true;
                        assert(
                            card.x == player.x && card.y == player.y,
                            'Player card in wrong position'
                        );
                    }
                }
                y += 1;
            };
            y = 0;
            x += 1;
        };
        assert(total_cards == 9, 'Wrong number of cards');
        assert(player_card_found, 'Player card not found');
        assert(total_monsters < 5, 'Wrong number of monsters');
    }

    // TODO panic expected but test fails
    #[test]
    #[should_panic(expected: ('Player is dead', 'ENTRYPOINT_FAILED'))]
    #[available_gas(3000000000000000)]
    fn test_use_skill_dead_panic() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"actions").unwrap();
        let card_knight = IActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);

        let hero = Hero::Knight;
        card_knight.start_game(1, hero);

        // Check if player was created
        let mut player: Player = world.read_model((1, caller));
        player.hp = 0;
        world.write_model(@player);
        card_knight.use_skill(1, Skill::Regeneration, Direction::Up);
    }
    // TODO panic expected but test fails
    #[test]
    #[should_panic(expected: ('User level not enough', 'ENTRYPOINT_FAILED'))]
    #[available_gas(3000000000000000)]
    fn test_use_skill_level_panic() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"actions").unwrap();
        let card_knight = IActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);

        let hero = Hero::Knight;
        card_knight.start_game(1, hero);

        // Check if player was created
        let mut player: Player = world.read_model((1, caller));
        player.hp = 11;
        world.write_model(@player);
        card_knight.use_skill(1, Skill::Regeneration, Direction::Up);
    }


    #[test]
    #[should_panic(expected: ('Invalid Knight skill', 'ENTRYPOINT_FAILED'))]
    #[available_gas(3000000000000000)]
    fn test_use_skill_invalid_panic() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"actions").unwrap();
        let card_knight = IActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);

        let hero = Hero::Knight;
        card_knight.start_game(1, hero);

        // Check if player was created
        let mut player: Player = world.read_model((1, caller));
        player.hp = 10;
        world.write_model(@player);
        card_knight.use_skill(1, Skill::Hex, Direction::Up);
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_use_skill() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"actions").unwrap();
        let card_knight = IActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);

        let hero = Hero::Knight;
        card_knight.start_game(1, hero);

        let mut player: Player = world.read_model((1, caller));
        player.hp = 5;
        player.max_hp = 10;
        player.level = 10;
        player.turn = 10;

        world.write_model(@player);
        card_knight.use_skill(1, Skill::Regeneration, Direction::Up);

        let mut player: Player = world.read_model((1, caller));
        assert(player.hp == 10, 'Error hp');

        let mut player_skill: PlayerSkill = world.read_model((1, caller, Skill::Regeneration));
        assert(player_skill.last_use == player.turn, 'Error last_use');
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_swap_skill() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"actions").unwrap();
        let card_knight = IActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);

        let hero = Hero::Knight;
        card_knight.start_game(1, hero);

        let mut player: Player = world.read_model((1, caller));
        player.hp = 5;
        player.max_hp = 10;
        player.level = 10;
        player.turn = 10;
        world.write_model(@player);

        card_knight.use_swap_skill(1, Direction::Up);

        let mut player_skill: PlayerSkill = world.read_model((1, caller, Skill::Teleport));

        assert(player_skill.last_use == player.turn, 'Error last_use');

        let mut player: Player = world.read_model((1, caller));
        assert(player.x == 1 && player.y == 2, 'Error position');
        assert(player.turn == 11, 'Error turn');
    }


    #[test]
    #[should_panic(expected: ('Invalid swap direction', 'ENTRYPOINT_FAILED'))]
    #[available_gas(3000000000000000)]
    fn test_swap_skill_panic() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"actions").unwrap();
        let card_knight = IActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);

        let hero = Hero::Knight;
        card_knight.start_game(1, hero);

        let mut player: Player = world.read_model((1, caller));
        player.hp = 5;
        player.max_hp = 10;
        player.level = 10;
        player.turn = 10;
        player.y = 2;
        world.write_model(@player);
        card_knight.use_swap_skill(1, Direction::Up);
    }


    #[test]
    #[available_gas(3000000000000000)]
    fn test_curse_skill() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"actions").unwrap();
        let card_knight = IActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);

        let hero = Hero::Vampire;
        card_knight.start_game(1, hero);

        world_setup(world, false);

        let mut player: Player = world.read_model((1, caller));
        player.hp = 5;
        player.max_hp = 10;
        player.level = 10;
        player.turn = 10;
        world.write_model(@player);

        card_knight.use_curse_skill(1, 0, 0);

        let mut player: Player = world.read_model((1, caller));
        assert(player.x == 1 && player.y == 1, 'Error position');
        assert(player.turn == 10, 'Error turn');

        let mut card: Card = world.read_model((1, 0, 0));
        assert(card.hp == 5, 'Error hp');
    }


    #[test]
    #[available_gas(3000000000000000)]
    fn level_up() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"actions").unwrap();
        let card_knight = IActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);

        let hero = Hero::Vampire;
        card_knight.start_game(1, hero);

        world_setup(world, false);

        let mut player: Player = world.read_model((1, caller));
        player.hp = 10;
        player.max_hp = 10;
        player.level = 1;
        player.total_xp = 10;
        world.write_model(@player);

        card_knight.level_up(1, 1,);

        let mut player: Player = world.read_model((1, caller));
        assert(player.max_hp == 12, 'Error max_hp1');
        assert(player.hp == 10, 'Error hp');
        assert(player.level == 2, 'Error level');
        assert(player.total_xp == 10, 'Error total_xp');
        assert(player.exp == player.total_xp - level::LEVEL2_XP, 'Error exp');

        player.hp = 10;
        player.max_hp = 20;
        world.write_model(@player);

        card_knight.level_up(1, 2,);

        let mut player: Player = world.read_model((1, caller));
        assert(player.max_hp == 20, 'Error max_hp2');
        assert(player.hp == 20, 'Error hp');
        assert(player.level == 3, 'Error level');
        assert(player.total_xp == 10, 'Error total_xp');
        assert(player.exp == player.total_xp - level::LEVEL3_XP, 'Error exp');
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_move() {
        // Setup
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"actions").unwrap();
        let card_knight = IActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);
        let game_id = 1;
        card_knight.start_game(game_id, Hero::Knight);
        world_setup(world, false);

        // Initial player position
        let mut initial_player: Player = world.read_model((game_id, caller));
        let initial_x = initial_player.x;
        let initial_y = initial_player.y;
        initial_player.hp = 30;
        initial_player.max_hp = 30;
        initial_player.level = 1;

        world.write_model(@initial_player);

        // Move player
        card_knight.move(game_id, Direction::Right);

        // Check new player position
        let moved_player: Player = world.read_model((game_id, caller));
        assert(moved_player.x == initial_x + 1, 'Player did not move right');
        assert(moved_player.y == initial_y, 'Player y pos');
        assert(moved_player.hp == 20, 'Error card hp ');
        assert(moved_player.max_hp == 30, 'Error max hp');
        assert(moved_player.exp == MONSTER1_XP, 'Error exp');
        assert(moved_player.sequence == 1, 'Error sequence');

        // Check if player card moved
        let player_card: Card = world.read_model((game_id, moved_player.x, moved_player.y));
        assert(player_card.card_id == CardIdEnum::Player, 'Player card ');
        assert(player_card.x == initial_x + 1, 'Player card x ');
        assert(player_card.y == initial_y, 'Player card y ');

        let mut card_sequence = card_sequence();
        let card_id = card_sequence.at(0);

        let old_pos: Card = world.read_model((game_id, initial_x, initial_y));
        assert(old_pos.card_id == CardIdEnum::Monster1, 'Player card ');

        assert(old_pos.max_hp == 10, 'Error old_pos max ');
        assert(old_pos.hp == 10, 'Error old_pos hp ');
        assert(old_pos.xp == 2, 'Error old_pos xp ');

        let new_card: Card = world.read_model((game_id, initial_x - 1, initial_y));
        assert(new_card.card_id == CardIdEnum::Monster1, 'Player card ');

        assert(
            new_card.max_hp == moved_player.level * MONSTER1_BASE_HP * MONSTER1_MULTIPLE,
            'Error new_card max '
        );
        assert(
            new_card.hp == moved_player.level * MONSTER1_BASE_HP * MONSTER1_MULTIPLE,
            'Error new_card hp '
        );
        assert(new_card.xp == MONSTER1_XP, 'Error new_card xp ');

        let card = Card {
            game_id: 1,
            x: 2,
            y: 2,
            card_id: CardIdEnum::ItemHeal,
            hp: 3,
            max_hp: 10,
            shield: 0,
            max_shield: 0,
            xp: 0,
            tag: TagType::None,
            flipped: false,
        };
        world.write_model(@card);

        card_knight.move(game_id, Direction::Up);

        // Check new player position
        let moved_player: Player = world.read_model((game_id, caller));
        assert(moved_player.x == 2, 'Player did not move right');
        assert(moved_player.y == 2, 'Player y pos');
        assert(moved_player.hp == 23, 'Error card hp ');
        assert(moved_player.max_hp == 30, 'Error max hp');
        assert(moved_player.exp == MONSTER1_XP + HEAL_XP, 'Error exp');
        assert(moved_player.sequence == 2, 'Error sequence');

        // Check if player card moved
        let player_card: Card = world.read_model((game_id, moved_player.x, moved_player.y));
        assert(player_card.card_id == CardIdEnum::Player, 'Player card ');
        assert(player_card.x == 2, 'Player card x ');
        assert(player_card.y == 2, 'Player card y ');

        let old_pos: Card = world.read_model((game_id, 2, 1));
        assert(old_pos.card_id == CardIdEnum::Monster1, 'Player card ');
        assert(old_pos.max_hp == 10, 'Error old_pos max ');
        assert(old_pos.hp == 10, 'Error old_pos hp ');
        assert(old_pos.xp == 2, 'Error old_pos xp ');

        let new_card: Card = world.read_model((game_id, 2, 0));
        assert(new_card.card_id == CardIdEnum::ItemHeal, 'Error new_card card_id ');
        assert(new_card.xp == HEAL_XP, 'Error new_card xp ');

        let card = Card {
            game_id: 1,
            x: 1,
            y: 2,
            card_id: CardIdEnum::ItemPoison,
            hp: 4,
            max_hp: 10,
            shield: 0,
            max_shield: 0,
            xp: 0,
            tag: TagType::None,
            flipped: false,
        };
        world.write_model(@card);

        card_knight.move(game_id, Direction::Left);

        // Check new player position
        let mut moved_player: Player = world.read_model((game_id, caller));
        assert(moved_player.x == 1, 'Player did not move right');
        assert(moved_player.y == 2, 'Player y pos');
        assert(moved_player.hp == 18, 'Error card hp ');
        assert(moved_player.max_hp == 30, 'Error max hp');
        assert(moved_player.exp == MONSTER1_XP + HEAL_XP + POISON_XP, 'Error exp');
        assert(moved_player.sequence == 3, 'Error sequence');
        assert(moved_player.poisoned == POISON_TURN - 1, 'Error poisoned');

        // Check if player card moved
        let player_card: Card = world.read_model((game_id, 1, 2));
        assert(player_card.card_id == CardIdEnum::Player, 'Player card ');
        assert(player_card.x == 1, 'Player card x ');
        assert(player_card.y == 2, 'Player card y ');

        let old_pos: Card = world.read_model((game_id, 2, 2));
        assert(old_pos.card_id == CardIdEnum::Monster1, 'Player card ');
        assert(old_pos.max_hp == 10, 'Error old_pos max ');
        assert(old_pos.hp == 10, 'Error old_pos hp ');
        assert(old_pos.xp == 2, 'Error old_pos xp ');

        let card = Card {
            game_id: 1,
            x: 1,
            y: 1,
            card_id: CardIdEnum::ItemShield,
            hp: 4,
            max_hp: 10,
            shield: 5,
            max_shield: 0,
            xp: 0,
            tag: TagType::None,
            flipped: false,
        };
        world.write_model(@card);
        // Check shield card effect

        moved_player.shield = 5;
        moved_player.max_shield = 10;
        world.write_model(@moved_player);

        card_knight.move(game_id, Direction::Down);

        let moved_player: Player = world.read_model((game_id, caller));
        assert(moved_player.x == 1, 'Player did not move right');
        assert(moved_player.y == 1, 'Player y pos');
        assert(moved_player.hp == 18, 'Error card hp7 ');
        assert(moved_player.max_hp == 30, 'Error max hp');
        assert(moved_player.exp == MONSTER1_XP + HEAL_XP + POISON_XP + SHIELD_XP, 'Error exp');
        assert(moved_player.sequence == 4, 'Error sequence');
        assert(moved_player.poisoned == POISON_TURN - 2, 'Error poisoned');
        assert(moved_player.shield == 9, 'Error shield');
        assert(moved_player.turn == 4, 'Error turn');

        // Check if player card moved
        let player_card: Card = world.read_model((game_id, 1, 1));
        assert(player_card.card_id == CardIdEnum::Player, 'Player card ');
        assert(player_card.x == 1, 'Player card x ');
        assert(player_card.y == 1, 'Player card y ');
    }


    #[test]
    #[available_gas(3000000000000000)]
    fn test_move_boss() {
        // Setup
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"actions").unwrap();
        let card_knight = IActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);
        let game_id = 1;
        card_knight.start_game(game_id, Hero::Knight);

        world_setup(world, false);

        // Initial player position
        let mut initial_player: Player = world.read_model((game_id, caller));
        let initial_x = initial_player.x;
        let initial_y = initial_player.y;
        initial_player.hp = 30;
        initial_player.max_hp = 30;
        initial_player.level = 1;
        initial_player.sequence = 15;

        world.write_model(@initial_player);
        world.write_model(@initial_player);

        // Move player
        card_knight.move(game_id, Direction::Down);

        // Check new player position
        let moved_player: Player = world.read_model((game_id, caller));
        assert(moved_player.x == initial_x, 'Player did not move right');
        assert(moved_player.y == initial_y - 1, 'Player y pos');
        assert(moved_player.hp == 20, 'Error card hp ');
        assert(moved_player.max_hp == 30, 'Error max hp');
        assert(moved_player.exp == MONSTER1_XP, 'Error exp');
        assert(moved_player.sequence == 16, 'Error sequence');

        // Check if player card moved
        let player_card: Card = world.read_model((game_id, moved_player.x, moved_player.y));
        assert(player_card.card_id == CardIdEnum::Player, 'Player card ');
        assert(player_card.x == initial_x, 'Player card x ');
        assert(player_card.y == initial_y - 1, 'Player card y ');

        let mut card_sequence = card_sequence();

        let mut old_pos: Card = world.read_model((game_id, initial_x, initial_y));
        assert(old_pos.card_id == CardIdEnum::Monster1, 'Player card ');

        assert(old_pos.max_hp == 10, 'Error old_pos max ');
        assert(old_pos.hp == 10, 'Error old_pos hp ');
        assert(old_pos.xp == 2, 'Error old_pos xp ');

        let mut new_card: Card = world.read_model((game_id, 1, 2));
        assert(new_card.card_id == CardIdEnum::Boss1, 'Error new_card card_id ');
        assert(new_card.xp == BOSS_XP, 'Error new_card xp ');
        assert(new_card.hp == 40, 'Error new_card xp ');

        new_card.x = 1;
        new_card.y = 1;

        old_pos.x = 1;
        old_pos.y = 2;

        world.write_model(@new_card);
        world.write_model(@old_pos);

        // Check if all cards are flipped
        let mut x: u32 = 0;
        let mut y: u32 = 0;
        while x <= 2 {
            while y <= 2 {
                let mut card: Card = world.read_model((game_id, x, y));
                if (card.card_id != CardIdEnum::Boss1 && card.card_id != CardIdEnum::Player) {
                    assert(card.flipped == true, 'Error flipped');
                }
                y = y + 1;
            };
            y = 0;
            x = x + 1;
        };

        let mut moved_player: Player = world.read_model((game_id, caller));
        moved_player.hp = 100;
        moved_player.max_hp = 100;
        world.write_model(@moved_player);

        card_knight.move(game_id, Direction::Up);

        let moved_player: Player = world.read_model((game_id, caller));
        assert(moved_player.x == 1, 'Player did not up');
        assert(moved_player.y == 1, 'Player y pos');

        // Check if all cards are flipped back after boss is defeated
        let mut x: u32 = 0;
        let mut y: u32 = 0;
        while x <= 2 {
            while y <= 2 {
                let mut card: Card = world.read_model((game_id, x, y));
                if (card.card_id != CardIdEnum::Boss1 && card.card_id != CardIdEnum::Player) {
                    assert(card.flipped == false, 'Error still flipped');
                }

                y = y + 1;
            };
            y = 0;
            x = x + 1;
        };
    }


    #[test]
    #[should_panic(expected: ('Invalid move', 'ENTRYPOINT_FAILED'))]
    #[available_gas(3000000000000000)]
    fn test_move_panic() {
        // Setup
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"actions").unwrap();
        let card_knight = IActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);
        let game_id = 1;
        card_knight.start_game(game_id, Hero::Knight);
        world_setup(world, false);

        // Initial player position
        let mut initial_player: Player = world.read_model((game_id, caller));
        initial_player.hp = 30;
        initial_player.max_hp = 30;
        initial_player.level = 1;
        initial_player.x = 2;
        initial_player.y = 2;
        world.write_model(@initial_player);

        // Move player
        card_knight.move(game_id, Direction::Right);
    }

    #[test]
    #[should_panic(expected: ('Player is dead', 'ENTRYPOINT_FAILED'))]
    #[available_gas(3000000000000000)]
    fn test_move_dead_player_panic() {
        // Setup
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"actions").unwrap();
        let card_knight = IActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);
        let game_id = 1;
        card_knight.start_game(game_id, Hero::Knight);
        world_setup(world, false);

        // Initial player position
        let mut initial_player: Player = world.read_model((game_id, caller));
        initial_player.hp = 0;
        initial_player.max_hp = 0;
        initial_player.level = 1;
        world.write_model(@initial_player);

        // Move player
        card_knight.move(game_id, Direction::Right);
    }


    // Helper functions
    fn namespace_def() -> NamespaceDef {
        let ndef = NamespaceDef {
            namespace: "card_knight", resources: [
                TestResource::Model(m_Card::TEST_CLASS_HASH),
                TestResource::Model(m_Player::TEST_CLASS_HASH),
                TestResource::Model(m_PlayerSkill::TEST_CLASS_HASH),
                TestResource::Model(m_Game::TEST_CLASS_HASH),
                TestResource::Contract(actions::TEST_CLASS_HASH),
            ].span()
        };
        ndef
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"card_knight", @"actions")
                .with_writer_of([dojo::utils::bytearray_hash(@"card_knight")].span())
        ].span()
    }


    fn world_setup(mut world_storage: WorldStorage, flipped: bool) {
        let mut x: u32 = 0;
        let mut y: u32 = 0;

        // loop through every square in 3x3 board
        while x <= 2 {
            while y <= 2 {
                let new_card = Card {
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
                };
                world_storage.write_model(@new_card);
                y += 1;
            };
            y = 0;
            x += 1;
        };

        let new_player = Card {
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
        };
        world_storage.write_model(@new_player);
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
