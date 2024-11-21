#[cfg(test)]
mod tests {
    use starknet::class_hash::Felt252TryIntoClassHash;
    use starknet::ContractAddress;

    // import test utils
    use card_knight::{
        systems::{
            actions::{
                CardKnightActions, ICardKnightActionsDispatcher, ICardKnightActionsDispatcherTrait
            }
        },
        models::{
            game::{Game, Direction, GameState, TagType},
            card::{Card, CardIdEnum, ICardImpl, ICardTrait,}, player::{Player, IPlayer, Hero},
            skill::{Skill, PlayerSkill},
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
    fn test_simple_functions() {
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"CardKnightActions").unwrap();
        let card_knight = ICardKnightActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);

        assert(!ICardImpl::is_corner(player), 'Error corner');

        player.x = 0;
        player.y = 0;
        assert(ICardImpl::is_corner(player), 'Error corner');

        assert(ICardImpl::is_inside(0, 0), 'Error is_inside');
        assert(ICardImpl::is_inside(2, 2), 'Error is_inside');
        assert(!ICardImpl::is_inside(2, 3), 'Error is_inside');
        assert(!ICardImpl::is_inside(4, 1), 'Error is_inside');

        let mut card = Card {
            game_id: 1,
            x: 1,
            y: 1,
            card_id: CardIdEnum::ItemShield,
            hp: 2,
            max_hp: 20,
            shield: 1,
            max_shield: 0,
            xp: 1,
            tag: TagType::None,
            flipped: false,
        };

        card.apply_growth_tag();

        assert(card.max_hp == 22, 'Error max hp1');
        assert(card.hp == 4, 'Error hp');

        card.hp = 100;
        card.max_hp = 120;

        card.apply_revenge_tag();

        let increase = 100 * INCREASE_HP_RATIO / 100;
        assert(card.max_hp == 120 + increase, 'Error max hp2');
        assert(card.hp == 100 + increase, 'Error hp');

        card.hp = 1;
        card.max_hp = 10;

        card.apply_revenge_tag();

        let increase = 1;
        assert(card.max_hp == 10 + increase, 'Error max hp3');
        assert(card.hp == 1 + increase, 'Error hp');
    }


    #[test]
    #[available_gas(3000000000000000)]
    fn test_apply_effect() {
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"CardKnightActions").unwrap();
        let card_knight = ICardKnightActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);

        let mut card1 = card_setup(CardIdEnum::Monster1, 5);
        card1.xp = 2;
        player.hp = 10;
        player.total_xp = 0;
        player.exp = 0;

        player = ICardImpl::apply_effect(world, player, card1);

        assert(player.hp == 5, 'Error hp');
        assert(player.total_xp == MONSTER1_XP, 'Error total_xp');

        let mut card2 = card_setup(CardIdEnum::ItemHeal, 5);
        card2.hp = 2;
        player.hp = 1;
        player.total_xp = 0;
        player.exp = 0;

        player = ICardImpl::apply_effect(world, player, card2);

        assert(player.hp == 3, 'Error hp');
        assert(player.total_xp == HEAL_XP, 'Error total_xp');

        let mut card3 = card_setup(CardIdEnum::ItemPoison, 5);
        card3.hp = 2;
        player.hp = 5;
        player.total_xp = 0;
        player.exp = 0;

        player = ICardImpl::apply_effect(world, player, card3);

        assert(player.hp == 3, 'Error hp');
        assert(player.total_xp == POISON_XP, 'Error total_xp');
        assert(player.poisoned == POISON_TURN, 'Error poisoned');

        let mut card4 = card_setup(CardIdEnum::ItemShield, 5);
        card4.hp = 0;
        card4.shield = 4;

        player.hp = 5;
        player.shield = 5;
        player.total_xp = 0;
        player.exp = 0;

        player = ICardImpl::apply_effect(world, player, card4);

        assert(player.hp == 5, 'Error hp');
        assert(player.total_xp == SHIELD_XP, 'Error total_xp');
        assert(player.shield == 9, 'Error shield');
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_flip_cards() {
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"CardKnightActions").unwrap();
        let card_knight = ICardKnightActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);

        card_knight.start_game(1, Hero::Knight);
        let mut player: Player = world.read_model((1, caller));
        assert(player.game_id == 1, 'Error gameid');
        assert(player.player == caller, 'Error player');
        assert(player.x == 1, 'Error x');
        assert(player.y == 1, 'Error 1');
        assert(player.max_hp == 10, 'Error max_hp');

        let mut player_card: Card = world.read_model((1, 1, 1));
        assert(player_card.x == 1, 'Error x');
        assert(player_card.y == 1, 'Error y');
        assert(player_card.card_id == CardIdEnum::Player, 'Error card_id');
        assert(player_card.flipped == false, 'Error flipped');

        ICardImpl::flip_cards(world, 1, true);

        let mut player_card: Card = world.read_model((1, 1, 1));
        assert(player_card.flipped == false, 'Error flipped1');

        let mut card0: Card = world.read_model((1, 0, 0));
        assert(card0.flipped, 'Error flipped2');

        let mut card1: Card = world.read_model((1, 0, 1));
        assert(card1.flipped, 'Error flipped3');

        let mut card2: Card = world.read_model((1, 2, 2));
        if (card2.card_id != CardIdEnum::Boss1 && card2.card_id != CardIdEnum::Player) {
            assert(card2.flipped, 'Error flipped4');
        }
    }


    #[test]
    #[available_gas(3000000000000000)]
    fn test_get_neighbour_card() {
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"CardKnightActions").unwrap();
        let card_knight = ICardKnightActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);

        card_knight.start_game(1, Hero::Knight);

        let mut up_card: Card = world.read_model((1, 1, 2));
        let mut left_card: Card = world.read_model((1, 0, 1));

        let (is_inside, _card) = ICardImpl::get_neighbour_card(world, 1, 1, 1, Direction::Up);
        assert(is_inside, 'Error inside');
        assert(up_card == _card, 'Error up card');

        let (is_inside, _card) = ICardImpl::get_neighbour_card(world, 1, 1, 1, Direction::Left);
        assert(is_inside, 'Error inside');
        assert(left_card == _card, 'Error left card');

        let (is_inside, _card) = ICardImpl::get_neighbour_card(world, 1, 0, 0, Direction::Left);
        assert(!is_inside, 'Error inside2');
    }


    #[test]
    #[available_gas(3000000000000000)]
    fn test_spawn_card() {
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"CardKnightActions").unwrap();
        let card_knight = ICardKnightActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);

        card_knight.start_game(1, Hero::Knight);

        let mut player: Player = world.read_model((1, caller));

        let mut card_sequence = card_sequence();
        let card_id = card_sequence.at(player.sequence);

        let (card, is_boss) = ICardImpl::spawn_card(world, 1, 0, 0, player);
        assert(!is_boss, 'Error is boss');
        assert(card.x == 0, 'Error x');
        assert(card.y == 0, 'Error y');
        assert(card.card_id == *card_id, 'Error card_id');
        let mut player: Player = world.read_model((1, caller));
        assert(player.sequence == 1, 'Error sequence');

        let _card_id2 = card_sequence.at(player.sequence);

        let (card, is_boss) = ICardImpl::spawn_card(world, 1, 2, 2, player);
        assert(!is_boss, 'Error is boss');
        assert(card.x == 2, 'Error x');
        assert(card.y == 2, 'Error y');
        assert(card.card_id == CardIdEnum::ItemHeal, 'Error card_id2');
        assert(card.xp == HEAL_XP, 'Error HEAL_XP');

        let mut player: Player = world.read_model((1, caller));
        assert(player.sequence == 2, 'Error sequence');

        let mut updated_card: Card = world.read_model((1, 2, 2));
        assert(updated_card == card, 'Error card storage');
    }


    #[test]
    #[available_gas(3000000000000000)]
    fn get_all_neighbours() {
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (actions_system_addr, _) = world.dns(@"CardKnightActions").unwrap();
        let card_knight = ICardKnightActionsDispatcher { contract_address: actions_system_addr };

        world_setup(world, false);

        let mut player = player_setup(caller);
        world.write_model(@player);

        let cards = ICardImpl::get_all_neighbours(world, 1, 1, 1);

        assert(cards.len() == 4, 'Error cards len');

        assert(*cards.at(0).x == 1, 'Error x');
        assert(*cards.at(0).y == 2, 'Error y');

        assert(*cards.at(1).x == 1, 'Error x');
        assert(*cards.at(1).y == 0, 'Error y');

        assert(*cards.at(2).x == 0, 'Error x');
        assert(*cards.at(2).y == 1, 'Error y');

        assert(*cards.at(3).x == 2, 'Error x');
        assert(*cards.at(3).y == 1, 'Error y');
    }


    // Helper functions
    fn namespace_def() -> NamespaceDef {
        let ndef = NamespaceDef {
            namespace: "card_knight", resources: [
                TestResource::Model(m_Card::TEST_CLASS_HASH),
                TestResource::Model(m_Player::TEST_CLASS_HASH),
                TestResource::Model(m_PlayerSkill::TEST_CLASS_HASH),
                TestResource::Model(m_Game::TEST_CLASS_HASH),
                TestResource::Contract(CardKnightActions::TEST_CLASS_HASH),
            ].span()
        };
        ndef
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"card_knight", @"CardKnightActions")
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
