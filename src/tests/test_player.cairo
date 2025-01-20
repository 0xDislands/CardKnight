#[cfg(test)]
mod tests {
    use starknet::class_hash::Felt252TryIntoClassHash;
    use starknet::ContractAddress;

    // import test utils
    use card_knight::{
        systems::{},
        models::{
            game::{Game, Direction, GameState, TagType},
            card::{Card, CardIdEnum, ICardImpl, ICardTrait,}, player::{Player, IPlayer, Hero},
            skill::{Skill, PlayerSkill},
        },
        config::level
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
    fn test_add_exp() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();
        let mut player = player_setup(caller);

        player.add_exp(5);
        assert!(player.exp == 10, "Error exp");
        assert!(player.total_xp == 15, "Error total_xp");

        player.add_exp(0);
        assert!(player.exp == 10, "Error exp");
        assert!(player.total_xp == 15, "Error total_xp");

        player.add_exp(20);
        assert!(player.exp == 30, "Error exp");
        assert!(player.total_xp == 35, "Error total_xp");
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_take_damage_and_heal() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();
        let mut player = player_setup(caller);

        player.take_damage(0);
        assert!(player.shield == 0, "Error shield1");
        assert!(player.hp == 10, "Error hp");

        player.take_damage(5);
        assert!(player.shield == 0, "Error shield2");
        assert!(player.hp == 5, "Error hp");

        player.take_damage(10);
        assert!(player.shield == 0, "Error shield3");
        assert!(player.hp == 0, "Error hp");
        assert!(player.alive == false, "Error alive");

        player.heal(10);
        player.shield = 10;
        assert!(player.hp == 10, "Error hp");

        player.heal(5);
        assert!(player.hp == 10, "Error hp");

        player.take_damage(5);
        assert!(player.shield == 5, "Error shield4");
        assert!(player.hp == 10, "Error hp");

        player.take_damage(10);
        assert!(player.shield == 0, "Error shield5");
        assert!(player.hp == 5, "Error hp");
    }


    #[test]
    #[available_gas(3000000000000000)]
    fn test_validate_skill() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();
        let mut player = player_setup(caller);

        player.validate_skill(Skill::PowerupSlash);
        player.validate_skill(Skill::Teleport);
        player.validate_skill(Skill::Regeneration);

        player.heroId = Hero::Shaman;

        player.validate_skill(Skill::Hex);
        player.validate_skill(Skill::Shuffle);
        player.validate_skill(Skill::Meteor);

        player.heroId = Hero::Vampire;

        player.validate_skill(Skill::LifeSteal);
        player.validate_skill(Skill::Teleport);
        player.validate_skill(Skill::Curse);
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_level_up() {
        // caller
        let caller = starknet::contract_address_const::<0x0>();
        let mut player = player_setup(caller);

        player.total_xp = level::LEVEL2_XP + 2;
        player.exp = level::LEVEL2_XP + 2;

        player.level_up(1);

        assert!(player.total_xp == level::LEVEL2_XP + 2, "Error total_xp");
        assert!(player.exp == 2, "Error exp");
        assert!(player.max_hp == 10 + 2, "Error max_hp");

        player.total_xp = level::LEVEL3_XP + 1;
        player.exp = level::LEVEL3_XP + 1;
        player.hp = 1;

        player.level_up(2);

        assert!(player.total_xp == level::LEVEL3_XP + 1, "Error total_xp");
        assert!(player.exp == 1, "Error exp");
        assert!(player.hp == player.max_hp, "Error max_hp");

        player.total_xp = level::LEVEL4_XP + 3;
        player.exp = level::LEVEL4_XP + 3;
        player.max_hp = 20;

        player.level_up(1);

        assert!(player.total_xp == level::LEVEL4_XP + 3, "Error total_xp");
        assert!(player.exp == 3, "Error exp");
        assert!(player.max_hp == 20 + 6, "Error max_hp");
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
