// fn move_player(world: &mut IWorldDispatcher, game_id: u32, current_x: u8, current_y: u8,
// direction: Direction) {
//     let player = get_caller_address();
//     let (mut x, mut y) = match direction {
//         Direction::Up => (current_x, current_y + 1),
//         Direction::Down => (current_x, current_y - 1),
//         Direction::Left => (current_x - 1, current_y),
//         Direction::Right => (current_x + 1, current_y),
//     };

//     // Assuming get_card_at returns an Option<Card> and set_card_at replaces or sets a card at
//     the given position if let Some(target_card) = get_card_at(world, game_id, x, y) {
//         // Handle cascading movement
//     }

//     // Move the player to the new position
//     let player_card = get_player_card(world, game_id, player);
//     set_card_at(world, game_id, x, y, player_card);

//     // Spawn a new card at the original position
//     spawn_new_card_at(world, game_id, current_x, current_y);
// }


