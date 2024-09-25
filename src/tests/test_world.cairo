#[cfg(test)]
mod tests {
    use starknet::class_hash::Felt252TryIntoClassHash;

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
        }
    };


    #[test]
    #[available_gas(3000000000000000)]
    fn test_game_start() {
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
    }
}
