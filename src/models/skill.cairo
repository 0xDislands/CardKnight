use starknet::ContractAddress;
use dojo::world::{IWorld, IWorldDispatcher, IWorldDispatcherTrait};


#[derive(Serde, Drop, Copy, PartialEq, Introspect)]
enum Skill {
    SkillFire,
}

#[derive(Copy, Drop, Serde, PartialEq)]
#[dojo::model]
struct PlayerSkill {
    #[key]
    game_id: u32,
    #[key]
    player: ContractAddress,
    #[key]
    skill: Skill,
    cooldown: u32, //
}

