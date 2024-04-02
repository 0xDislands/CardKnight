use starknet::ContractAddress;

#[dojo::interface]
trait IActions<ContractState> {
    fn move(
        self: @ContractState,
        curr_position: (u32, u32),
        next_position: (u32, u32),
        caller: ContractAddress, //player
        game_id: felt252
    );
    fn spawn_game(
        self: @ContractState, white_address: ContractAddress, black_address: ContractAddress, 
    );
}

#[dojo::contract]
mod actions {
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};
    use debug::PrintTrait;
    use starknet::{ContractAddress, get_caller_address};
    use aeternum::models::{Square, Card, Game, Player, CardType};
    use super::IActions;
    use aeternum::utils::{is_out_of_board, is_right_piece_move, is_piece_is_mine};

    #[storage]
    struct Storage {
        world_dispatcher: IWorldDispatcher, 
    }

    #[external(v0)]
    impl PlayerActionsImpl of IActions<ContractState> {
        fn spawn_game(
            self: @ContractState, white_address: ContractAddress, black_address: ContractAddress
        ) {
            let world = self.world_dispatcher.read();
            let game_id = pedersen::pedersen(white_address.into(), black_address.into());
            let player = get_caller_address();
            set!(
                world,
                (
                    Game {
                        game_id: game_id,
                        player
                    },
                )
            );

            set!(world, (Square { game_id: game_id, x: 2, y: 2, card: CardType::Player, health: 10, armor: 0 }));

            set!(world, (Square { game_id: game_id, x: 2, y: 2, card: CardType::Player, health: 10, armor: 0 }));

            
        }

        fn move(
            self: @ContractState,
            curr_position: (u32, u32),
            next_position: (u32, u32),
            caller: ContractAddress, //player
            game_id: felt252
        ) {
            let world = self.world_dispatcher.read();

            let (current_x, current_y) = curr_position;
            let (next_x, next_y) = next_position;
            current_x.print();
            current_y.print();

            next_x.print();
            next_y.print();

            let mut current_square = get!(world, (game_id, current_x, current_y), (Square));

            // check if next_position is out of board or not
            assert(is_out_of_board(next_position), 'Should be inside board');

            // check if this is the right piece type move
            assert(
                is_right_piece_move(current_square.piece, curr_position, next_position),
                'Should be right piece move'
            );
            let target_piece = current_square.piece;
            // make current_square piece none and move piece to next_square 
            current_square.piece = PieceType::None(());
            let mut next_square = get!(world, (game_id, next_x, next_y), (Square));

            // check the piece already in next_suqare
            let maybe_next_square_piece = next_square.piece;

            if maybe_next_square_piece == PieceType::None(()) {
                next_square.piece = target_piece;
            } else {
                if is_piece_is_mine(maybe_next_square_piece) {
                    panic(array!['Already same color piece exist'])
                } else {
                    next_square.piece = target_piece;
                }
            }

            set!(world, (next_square));
            set!(world, (current_square));
        }
    }
}