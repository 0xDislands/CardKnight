use starknet::ContractAddress;

use integer::{u128s_from_felt252, U128sFromFelt252Result, u128_safe_divmod};

use card_knight::config::{map::{X_RANGE, Y_RANGE, MAP_AMPLITUDE}};

use card_knight::models::{
    game::{Game, Direction}, card::{Card, CardIdEnum, ICardImpl},
    player::{Player, IPlayerImpl, LevelUpOptions}
};

use cubit::f64::procgen::simplex3;
use cubit::f64::types::fixed::FixedTrait;
use cubit::f64::types::vec3::Vec3Trait;

fn spawn_coords(player: ContractAddress, mut salt: u32) -> (u32, u32) {
    let player: felt252 = player.into();
    let salt: felt252 = salt.into();

    let hash = pedersen::pedersen(player, salt);
    let rnd_seed = match u128s_from_felt252(hash) {
        U128sFromFelt252Result::Narrow(low) => low,
        U128sFromFelt252Result::Wide((_high, low)) => low,
    };
    let (_rnd_seed, x_) = u128_safe_divmod(rnd_seed, X_RANGE.try_into().unwrap());
    let (_rnd_seed, y_) = u128_safe_divmod(rnd_seed, Y_RANGE.try_into().unwrap());
    let x_: u32 = x_.try_into().unwrap();
    let y_: u32 = y_.try_into().unwrap();
    return (x_, y_);
}

fn monster_type_at_position(x: u32, y: u32) -> (u32, u32) {
    let vec = Vec3Trait::new(
        FixedTrait::from_felt(x.into()) / FixedTrait::from_felt(MAP_AMPLITUDE.into()),
        FixedTrait::from_felt(0),
        FixedTrait::from_felt(y.into()) / FixedTrait::from_felt(MAP_AMPLITUDE.into())
    );

    // compute simplex noise
    let simplex_value = simplex3::noise(vec);

    // compute the value between -1 and 1 to a value between 0 and 1
    let fixed_value = (simplex_value + FixedTrait::from_unscaled_felt(1))
        / FixedTrait::from_unscaled_felt(2);

    // make it an integer between 0 and 100
    let value: u32 = FixedTrait::floor(fixed_value * FixedTrait::from_unscaled_felt(100))
        .try_into()
        .unwrap();

    if (value > 50) {
        return (1, value); // Monster
    } else {
        return (0, value); // Item
    }
}

fn get_level_up_options(x: u32, y: u32, sequence: u32) -> Array<LevelUpOptions> {
    let vec = Vec3Trait::new(
        FixedTrait::from_felt(x.into()) / FixedTrait::from_felt(MAP_AMPLITUDE.into()),
        FixedTrait::from_felt(0),
        FixedTrait::from_felt(y.into()) / FixedTrait::from_felt(MAP_AMPLITUDE.into())
    );

    // compute simplex noise
    let simplex_value = simplex3::noise(vec);

    // compute the value between -1 and 1 to a value between 0 and 1
    let fixed_value = (simplex_value + FixedTrait::from_unscaled_felt(1))
        / FixedTrait::from_unscaled_felt(2);

    // make it an integer between 0 and 100
    let value: u32 = FixedTrait::floor(fixed_value * FixedTrait::from_unscaled_felt(100))
        .try_into()
        .unwrap();

    if (value > 20) {
        let mut options = ArrayTrait::new();
        options.append(LevelUpOptions::IncreaseMaxHp);
        options.append(LevelUpOptions::AddHp);
        return options;
    } else if (value > 20 && value < 40) {
        let mut options = ArrayTrait::new();
        options.append(LevelUpOptions::IncreaseMaxArmour);
        options.append(LevelUpOptions::AddHp);
        return options;
    } else if (value > 40 && value < 60) {
        let mut options = ArrayTrait::new();
        options.append(LevelUpOptions::IncreaseMaxHp);
        options.append(LevelUpOptions::AddHp);
        return options;
    } else if (value > 60 && value < 80) {
        let mut options = ArrayTrait::new();
        options.append(LevelUpOptions::IncreaseMaxHp);
        options.append(LevelUpOptions::AddHp);
        return options;
    } else if (value > 80 && value < 100) {
        let mut options = ArrayTrait::new();
        options.append(LevelUpOptions::AddArmour);
        options.append(LevelUpOptions::AddHp);
        return options;
    } else {
        let mut options = ArrayTrait::new();
        options.append(LevelUpOptions::IncreaseMaxHp);
        options.append(LevelUpOptions::AddHp);
        return options;
    }
}


fn random_index(x: u32, y: u32, max: u32) -> u32 {
    let vec = Vec3Trait::new(
        FixedTrait::from_felt(x.into()) / FixedTrait::from_felt(MAP_AMPLITUDE.into()),
        FixedTrait::from_felt(0),
        FixedTrait::from_felt(y.into()) / FixedTrait::from_felt(MAP_AMPLITUDE.into())
    );

    // compute simplex noise
    let simplex_value = simplex3::noise(vec);

    // compute the value between -1 and 1 to a value between 0 and 1
    let fixed_value = (simplex_value + FixedTrait::from_unscaled_felt(1))
        / FixedTrait::from_unscaled_felt(2);

    // make it an integer between 0 and 100
    let value: u32 = FixedTrait::floor(fixed_value * FixedTrait::from_unscaled_felt(100))
        .try_into()
        .unwrap();

    let randomIndex = value - (value / max) * max;
    randomIndex
}

