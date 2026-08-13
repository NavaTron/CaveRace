package caverace

import "core:testing"

halfway_gameplay_for_test :: proc() -> Gameplay {
	gameplay: Gameplay
	gameplay.player.position = {2, 2}
	gameplay.player.move_from = {2, 2}
	gameplay.player.move_to = {3, 2}
	gameplay.player.movement_step = PLAYER_REVERSAL_STEP
	gameplay.player.direction = .Right
	return gameplay
}

@(test)
test_halfway_opposite_input_reverses_without_position_jump :: proc(t: ^testing.T) {
	gameplay := halfway_gameplay_for_test()
	gameplay.tick_state.input.move_left = true
	before := player_subtile_position(&gameplay.player)

	testing.expect(t, try_reverse_player_at_halfway(&gameplay))
	after := player_subtile_position(&gameplay.player)
	testing.expect_value(t, after.x, before.x)
	testing.expect_value(t, after.y, before.y)
	testing.expect_value(t, gameplay.player.direction, Direction.Left)
	testing.expect_value(t, gameplay.player.move_from.x, 3)
	testing.expect_value(t, gameplay.player.move_to.x, 2)

	advance_player_action_step(&gameplay.player, PLAYER_REVERSAL_STEP + 1)
	returning := player_subtile_position(&gameplay.player)
	testing.expect(t, returning.x < after.x)
}

@(test)
test_halfway_reversal_rejects_perpendicular_or_ambiguous_input :: proc(t: ^testing.T) {
	gameplay := halfway_gameplay_for_test()
	gameplay.tick_state.input.move_up = true
	testing.expect(t, !try_reverse_player_at_halfway(&gameplay))

	gameplay.tick_state.input.move_left = true
	gameplay.tick_state.input.move_right = true
	testing.expect(t, !try_reverse_player_at_halfway(&gameplay))
}

@(test)
test_halfway_reversal_rejects_blocked_origin_or_wrong_progress :: proc(t: ^testing.T) {
	gameplay := halfway_gameplay_for_test()
	gameplay.tick_state.input.move_left = true
	gameplay.bomb_occupancy[2][2] = BOMB_TICKING_SPRITE
	testing.expect(t, !try_reverse_player_at_halfway(&gameplay))

	gameplay.bomb_occupancy[2][2] = 0
	gameplay.player.movement_step = PLAYER_REVERSAL_STEP - 1
	testing.expect(t, !try_reverse_player_at_halfway(&gameplay))
}
