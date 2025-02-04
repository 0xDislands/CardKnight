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
            skill::{Skill, PlayerSkill, IPlayerSkill},
        },
        config::level,
        config::card::{
            MONSTER1_BASE_HP, MONSTER1_MULTIPLE, MONSTER2_BASE_HP, MONSTER2_MULTIPLE,
            MONSTER3_BASE_HP, MONSTER3_MULTIPLE, MONSTER1_XP, MONSTER2_XP, MONSTER3_XP, BOSS_XP,
            HEAL_XP, POISON_XP, SHIELD_XP, CHEST_XP, POISON_TURN, INCREASE_HP_RATIO, card_sequence
        }
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
    fn test_setup() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"actions").unwrap();
        let _card_knight = IActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);

        let mut card: Card = world.read_model((1, 1, 1));
        assert(card.card_id == CardIdEnum::Player, 'Error cardid');
        assert(card.hp == 10, 'Error hp');
        assert(card.xp == 0, 'Error xp');

        let mut card: Card = world.read_model((1, 0, 1));
        assert(card.card_id == CardIdEnum::Monster1, 'Error cardid');
        assert(card.hp == 10, 'Error hp');
        assert(card.xp == 2, 'Error xp');

        let mut card: Card = world.read_model((1, 2, 2));
        assert(card.card_id == CardIdEnum::Monster1, 'Error cardid');
        assert(card.hp == 10, 'Error hp');
        assert(card.xp == 2, 'Error xp');
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_skill_fire() {
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"actions").unwrap();
        let _card_knight = IActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);

        let mut player_skill: PlayerSkill = world.read_model((1, caller, Skill::SkillFire));
        player.turn = 10;
        player_skill.use_skill(player, Skill::SkillFire, world, Direction::Up);

        let mut card: Card = world.read_model((1, 0, 1));
        assert(card.card_id == CardIdEnum::Monster1, 'Error cardid');
        assert(card.hp == 8, 'Error hp');
        assert(card.xp == 2, 'Error xp');

        let mut card: Card = world.read_model((1, 1, 1));
        assert(card.hp == 10, 'Error hp');

        let mut card: Card = world.read_model((1, 2, 1));
        assert(card.hp == 8, 'Error hp');

        let mut card: Card = world.read_model((1, 2, 2));
        assert(card.hp == 8, 'Error hp');
    }


    #[test]
    #[available_gas(3000000000000000)]
    fn test_skill_fire_with_no_magic() {
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"actions").unwrap();
        let _card_knight = IActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);

        let card = Card {
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
        };
        world.write_model(@card);

        let card = Card {
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
        };
        world.write_model(@card);

        let mut player_skill: PlayerSkill = world.read_model((1, caller, Skill::SkillFire));
        player.turn = 10;
        player_skill.use_skill(player, Skill::SkillFire, world, Direction::Up);

        let mut card: Card = world.read_model((1, 2, 1));
        assert(card.hp == 8, 'Error hp');

        let mut card: Card = world.read_model((1, 2, 2));
        assert(card.hp == 10, 'Error hp');

        let mut card: Card = world.read_model((1, 0, 0));
        assert(card.hp == 10, 'Error hp');
    }


    #[test]
    #[available_gas(3000000000000000)]
    fn test_skill_powerup_slash() {
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"actions").unwrap();
        let _card_knight = IActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);

        let mut player_skill: PlayerSkill = world.read_model((1, caller, Skill::PowerupSlash));
        player.turn = 10;
        player_skill.use_skill(player, Skill::PowerupSlash, world, Direction::Up);

    }


    #[test]
    #[available_gas(3000000000000000)]
    fn test_skill_powerup_slash_with_boss() {
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"actions").unwrap();
        let _card_knight = IActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, true);

        let mut player = player_setup(caller);
        world.write_model(@player);

        let boss = boss_setup(CardIdEnum::Boss1, 1);
        world.write_model(@boss);

        let mut card: Card = world.read_model((1, 0, 0));
        assert(card.flipped == true, 'Error flipped1');

        let mut card: Card = world.read_model((1, 1, 2));
        assert(card.flipped == true, 'Error flipped2');

        let mut player_skill: PlayerSkill = world.read_model((1, caller, Skill::PowerupSlash));
        player.turn = 10;

        player_skill.use_skill(player, Skill::PowerupSlash, world, Direction::Up);
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_skill_meteor() {
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"actions").unwrap();
        let _card_knight = IActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);

        let mut player_skill: PlayerSkill = world.read_model((1, caller, Skill::Meteor));
        player.turn = 10;
        player.max_hp = 8;

        player_skill.use_skill(player, Skill::Meteor, world, Direction::Up);

        let mut card: Card = world.read_model((1, 0, 1));
        assert(card.card_id == CardIdEnum::Monster1, 'Error cardid');
        assert(card.hp == 8, 'Error hp');
        assert(card.xp == 2, 'Error xp');

        let mut card: Card = world.read_model((1, 1, 1));
        assert(card.hp == 10, 'Error hp');

        let mut card: Card = world.read_model((1, 2, 1));
        assert(card.hp == 8, 'Error hp');

        let mut card: Card = world.read_model((1, 2, 2));
        assert(card.hp == 8, 'Error hp');
    }
    #[test]
    #[available_gas(3000000000000000)]
    fn test_hex() {
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"actions").unwrap();
        let _card_knight = IActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);

        let mut player_skill: PlayerSkill = world.read_model((1, caller, Skill::Hex));
        player.turn = 10;
        player.max_hp = 8;

        player_skill.use_skill(player, Skill::Hex, world, Direction::Up);

        let mut card: Card = world.read_model((1, 1, 2));
        assert(card.card_id == CardIdEnum::Hex, 'Error cardid');
        assert(card.hp == 0, 'Error hp');
        assert(card.xp == 0, 'Error xp');
    }
    #[test]
    #[available_gas(3000000000000000)]
    fn test_regeneration() {
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"actions").unwrap();
        let _card_knight = IActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);

        let mut player_skill: PlayerSkill = world.read_model((1, caller, Skill::Regeneration));
        player.turn = 10;
        player.max_hp = 100;
        player.hp = 10;

        player_skill.use_skill(player, Skill::Regeneration, world, Direction::Up);
        let player: Player = world.read_model((1, caller));
        assert(player.hp == 100, 'Error hp');
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_life_steal() {
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"actions").unwrap();
        let _card_knight = IActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);

        let mut player_skill: PlayerSkill = world.read_model((1, caller, Skill::LifeSteal));
        player.turn = 10;
        player.max_hp = 10;
        player.hp = 9;

        player_skill.use_skill(player, Skill::LifeSteal, world, Direction::Up);
        let player: Player = world.read_model((1, caller));
        assert(player.hp == 10, 'Error hp');

        let mut card: Card = world.read_model((1, 1, 2));

        assert(card.hp == 7, 'Error hp2');
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_shuffle() {
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"actions").unwrap();
        let _card_knight = IActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);

        let mut card: Card = world.read_model((1, 0, 0));
        card.hp = 123;
        world.write_model(@card);

        let mut card: Card = world.read_model((1, 1, 0));
        card.hp = 456;
        world.write_model(@card);

        let mut card: Card = world.read_model((1, 2, 2));
        card.hp = 789;
        world.write_model(@card);

        let mut initial_positions = ArrayTrait::new();
        let mut x: u32 = 0;
        let mut y: u32 = 0;
        while x <= 2 {
            while y <= 2 {
                if x != 1 || y != 1 { // Exclude player position
                    let card: Card = world.read_model((1, x, y));
                    initial_positions.append((x, y, card.hp));
                }
                y += 1;
            };
            y = 0;
            x += 1;
        };

        let mut player_skill: PlayerSkill = world.read_model((1, caller, Skill::Shuffle));
        player.turn = 10;

        player_skill.use_skill(player, Skill::Shuffle, world, Direction::Up);

        // Check if cards have been shuffled
        let mut shuffled = false;
        x = 0;
        y = 0;
        while x <= 2 {
            while y <= 2 {
                if x != 1 || y != 1 { // Exclude player position
                    let card: Card = world.read_model((1, x, y));
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
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"actions").unwrap();
        let _card_knight = IActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);

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
        world.write_model(@monster_card);
        let mut player = player_setup(caller);
        world.write_model(@player);

        let player_skill: PlayerSkill = world.read_model((1, caller, Skill::Curse));
        player.turn = 10;
        // Use curse skill
        player_skill.use_curse_skill(world, 1, 2, 2);

        // Check if the monster's HP was reduced by half
        let cursed_card: Card = world.read_model((1, 2, 2));
        assert(cursed_card.hp == 50, 'Error cursed card hp');
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_swap_skill() {
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"actions").unwrap();
        let _card_knight = IActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        // Setup player
        let mut player = player_setup(caller);
        player.x = 1;
        player.y = 1;
        player.turn = 10; // Ensure turn is high enough to pass cooldown check
        world.write_model(@player);

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
        world.write_model(@player_card);

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
        world.write_model(@target_card);

        let player_skill: PlayerSkill = world.read_model((1, caller, Skill::Teleport));

        // Use swap skill
        player_skill.use_swap_skill(player, world, 1, 2);

        // Check if player position has changed
        let updated_player: Player = world.read_model((1, caller));
        assert(updated_player.x == 1 && updated_player.y == 2, 'Error position ');

        // Check if cards have swapped positions
        let swapped_target_card: Card = world.read_model((1, 1, 1));
        assert(swapped_target_card.card_id == CardIdEnum::Monster1, 'Error old position');
    }


    #[test]
    #[should_panic(expected: ('Card not monster',))]
    #[available_gas(3000000000000000)]
    fn test_curse_skill_panic() {
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"actions").unwrap();
        let _card_knight = IActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);

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
        world.write_model(@monster_card);
        let mut player = player_setup(caller);
        world.write_model(@player);

        let player_skill: PlayerSkill = world.read_model((1, caller, Skill::Curse));
        player.turn = 10;
        // Use curse skill
        player_skill.use_curse_skill(world, 1, 2, 2);

        // Check if the monster's HP was reduced by half
        let cursed_card: Card = world.read_model((1, 2, 2));
        assert(cursed_card.hp == 50, 'Error cursed card hp');
    }


    #[test]
    #[should_panic(expected: ('Skill cooldown',))]
    #[available_gas(3000000000000000)]
    fn test_skill_cooldown_panic() {
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"actions").unwrap();
        let _card_knight = IActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);

        let mut player_skill: PlayerSkill = world.read_model((1, caller, Skill::SkillFire));
        player.turn = 0;
        player_skill.last_use = 3;
        player_skill.use_skill(player, Skill::SkillFire, world, Direction::Up);
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
