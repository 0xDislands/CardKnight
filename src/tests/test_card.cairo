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
            skill::{Skill, PlayerSkill},
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
    fn test_simple_functions() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();
        let mut player = player_setup(caller);

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

        let mut player = player_setup(caller);
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
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        // deploy world with models
        let world = spawn_test_world!();

        // deploy systems contract
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        // set authorizations
        world.grant_writer(Model::<Game>::selector(), contract_address);
        world.grant_writer(Model::<Card>::selector(), contract_address);
        world.grant_writer(Model::<Player>::selector(), contract_address);
        world.grant_writer(Model::<PlayerSkill>::selector(), contract_address);

        actions_system.start_game(1, Hero::Knight);
        let mut player = get!(world, (1, caller), (Player));
        assert(player.game_id == 1, 'Error gameid');
        assert(player.player == caller, 'Error player');
        assert(player.x == 1, 'Error x');
        assert(player.y == 1, 'Error 1');
        assert(player.max_hp == 10, 'Error max_hp');

        let mut player_card = get!(world, (1, 1, 1), (Card));
        assert(player_card.x == 1, 'Error x');
        assert(player_card.y == 1, 'Error y');
        assert(player_card.card_id == CardIdEnum::Player, 'Error card_id');
        assert(player_card.flipped == false, 'Error flipped');

        ICardImpl::flip_cards(world, 1, true);

        let mut player_card = get!(world, (1, 1, 1), (Card));
        assert(player_card.flipped == false, 'Error flipped1');

        let mut card0 = get!(world, (1, 0, 0), (Card));
        assert(card0.flipped, 'Error flipped2');

        let mut card1 = get!(world, (1, 0, 1), (Card));
        assert(card1.flipped, 'Error flipped3');

        let mut card2 = get!(world, (1, 2, 2), (Card));
        if (card2.card_id != CardIdEnum::Boss1 && card2.card_id != CardIdEnum::Player) {
            assert(card2.flipped, 'Error flipped4');
        }
    }


    #[test]
    #[available_gas(3000000000000000)]
    fn test_get_neighbour_card() {
        // caller
        let _caller = starknet::contract_address_const::<0x0>();

        // deploy world with models
        let world = spawn_test_world!();

        // deploy systems contract
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        // set authorizations
        world.grant_writer(Model::<Game>::selector(), contract_address);
        world.grant_writer(Model::<Card>::selector(), contract_address);
        world.grant_writer(Model::<Player>::selector(), contract_address);
        world.grant_writer(Model::<PlayerSkill>::selector(), contract_address);

        actions_system.start_game(1, Hero::Knight);

        let mut up_card = get!(world, (1, 1, 2), (Card));
        let mut left_card = get!(world, (1, 0, 1), (Card));

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
        // caller
        let caller = starknet::contract_address_const::<0x0>();

        // deploy world with models
        let world = spawn_test_world!();

        // deploy systems contract
        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        // set authorizations
        world.grant_writer(Model::<Game>::selector(), contract_address);
        world.grant_writer(Model::<Card>::selector(), contract_address);
        world.grant_writer(Model::<Player>::selector(), contract_address);
        world.grant_writer(Model::<PlayerSkill>::selector(), contract_address);

        actions_system.start_game(1, Hero::Knight);

        let mut player = get!(world, (1, caller), (Player));

        let mut card_sequence = card_sequence();
        let card_id = card_sequence.at(player.sequence);

        let (card, is_boss) = ICardImpl::spawn_card(world, 1, 0, 0, player);
        assert(!is_boss, 'Error is boss');
        assert(card.x == 0, 'Error x');
        assert(card.y == 0, 'Error y');
        assert(card.card_id == *card_id, 'Error card_id');
        let mut player = get!(world, (1, caller), (Player));
        assert(player.sequence == 1, 'Error sequence');

        let _card_id2 = card_sequence.at(player.sequence);

        let (card, is_boss) = ICardImpl::spawn_card(world, 1, 2, 2, player);
        assert(!is_boss, 'Error is boss');
        assert(card.x == 2, 'Error x');
        assert(card.y == 2, 'Error y');
        assert(card.card_id == CardIdEnum::ItemHeal, 'Error card_id2');
        assert(card.xp == HEAL_XP, 'Error HEAL_XP');

        let mut player = get!(world, (1, caller), (Player));
        assert(player.sequence == 2, 'Error sequence');

        let mut updated_card = get!(world, (1, 2, 2), (Card));
        assert(updated_card == card, 'Error card storage');
    }


    #[test]
    #[available_gas(3000000000000000)]
    fn get_all_neighbours() {
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

        world_setup(world);
        let mut player = player_setup(caller);
        set!(world, (player));

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


    fn world_setup(world: IWorldDispatcher,) {
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
                            flipped: false,
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
