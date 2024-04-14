use starknet::ContractAddress;

use integer::{u128s_from_felt252, U128sFromFelt252Result, u128_safe_divmod};

use aeternum::config::{X_RANGE, Y_RANGE, MAP_AMPLITUDE};

use cubit::f64::procgen::simplex3;
use cubit::f64::types::fixed::FixedTrait;
use cubit::f64::types::vec3::Vec3Trait;

fn spawn_coords(player: ContractAddress, mut salt: u32) -> (u8, u8) {
    let player: felt252 = player.into();
    let salt: felt252 = salt.into();
    let mut x = 10;
    let mut y = 10;
    let hash = pedersen::pedersen(player, salt);
    let rnd_seed = match u128s_from_felt252(hash) {
            U128sFromFelt252Result::Narrow(low) => low,
            U128sFromFelt252Result::Wide((high, low)) => low,
    };
    let (rnd_seed, x_) = u128_safe_divmod(rnd_seed, X_RANGE.try_into().unwrap());
    let (rnd_seed, y_) = u128_safe_divmod(rnd_seed, Y_RANGE.try_into().unwrap());
    let x_: u8 = x_.try_into().unwrap();
    let y_: u8 = y_.try_into().unwrap();
    return (x_, y_);
}

fn type_at_position(x: u8, y: u8) -> (u32, u32) {
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

    if (value > 30) {
        return (1, value); // Monster
    } else {
        return (0, value); // Item
    }
}

fn cascade_move(world: IWorldDispatcher, game_id: u32, x: u8, y: u8, direction: Direction) {
    if let Some(card) = get_card_at(world, game_id, x, y) {
        let (next_x, next_y) = match direction {
            Direction::Up => (x, y + 1),
            Direction::Down => (x, y - 1),
            Direction::Left => (x - 1, y),
            Direction::Right => (x + 1, y),
        };
        // Check if the next position is within bounds and free
        if is_position_free(world, game_id, next_x, next_y) {
            // Move the card to the next position
            set_card_at(world, game_id, next_x, next_y, card);
            // Optionally, clear the current position
        } else {
            // Recurse if the next position is occupied
            cascade_move(world, game_id, next_x, next_y, direction);
        }
    }
}