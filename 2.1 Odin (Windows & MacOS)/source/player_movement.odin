package caverace

// Subtile_Position is a simulation-space coordinate measured in fixed movement
// steps. It lets collision code remain independent of render offsets and pixel
// scale while retaining exact integer movement.
Subtile_Position :: struct {
	x: int,
	y: int,
}

// direction_delta maps a cardinal direction to its grid offset whenever player
// or enemy movement selects a target cell.
direction_delta :: proc(direction: Direction) -> Grid_Position {
	switch direction {
	case .Down:  return {0, 1}
	case .Up:    return {0, -1}
	case .Right: return {1, 0}
	case .Left:  return {-1, 0}
	case .None:  return {}
	}
	return {}
}

// action_direction converts only movement actions to directions.
action_direction :: proc(action: Gameplay_Action) -> Direction {
	switch action {
	case .Move_Down:  return .Down
	case .Move_Up:    return .Up
	case .Move_Right: return .Right
	case .Move_Left:  return .Left
	case .None: return .None
	}
	return .None
}

// movement_subtile_position interpolates an actor in simulation units. One map
// cell is exactly MOVEMENT_STEPS_PER_TILE units on each axis.
movement_subtile_position :: proc(
	move_from, move_to: Grid_Position,
	movement_step: int,
) -> Subtile_Position {
	delta_x := move_to.x - move_from.x
	delta_y := move_to.y - move_from.y
	return {
		move_from.x * MOVEMENT_STEPS_PER_TILE + delta_x * movement_step,
		move_from.y * MOVEMENT_STEPS_PER_TILE + delta_y * movement_step,
	}
}

// movement_grid_position maps an interpolated simulation position to the map
// cell used by explosion effects. Integer division preserves the legacy edge
// behavior for actors moving left or up.
movement_grid_position :: proc(
	move_from, move_to: Grid_Position,
	movement_step: int,
) -> (position: Grid_Position, ok: bool) {
	subtile := movement_subtile_position(move_from, move_to, movement_step)
	if subtile.x < 0 || subtile.y < 0 do return {}, false
	position = {
		subtile.x / MOVEMENT_STEPS_PER_TILE,
		subtile.y / MOVEMENT_STEPS_PER_TILE,
	}
	return position, is_in_map(position)
}

// cell_has_bomb safely queries the separate occupancy grid used by movement
// rules without indexing an out-of-bounds position.
cell_has_bomb :: proc(occupancy: ^Map_Grid, position: Grid_Position) -> bool {
	return is_in_map(position) && occupancy[position.x][position.y] != 0
}

// is_walkable applies map bounds, terrain, item, and bomb rules before either a
// player or enemy begins moving to a neighboring cell.
is_walkable :: proc(
	data: ^Map_Data,
	bomb_occupancy: ^Map_Grid,
	position: Grid_Position,
) -> bool {
	if !is_in_map(position) do return false
	if data.background[position.x][position.y] >= WALKABLE_TERRAIN_LIMIT do return false
	if data.item[position.x][position.y] > PASSABLE_ITEM_LIMIT do return false
	return !cell_has_bomb(bomb_occupancy, position)
}

// begin_player_action captures the player's interpolation endpoints at an
// action boundary, leaving the target unchanged when movement is blocked.
begin_player_action :: proc(gameplay: ^Gameplay, action: Gameplay_Action) {
	player := &gameplay.player
	player.move_from = player.position
	player.move_to = player.position
	player.movement_step = 0
	player.direction = action_direction(action)

	if player.direction == .None do return
	delta := direction_delta(player.direction)
	target := Grid_Position {
		player.position.x + delta.x,
		player.position.y + delta.y,
	}
	if is_walkable(&gameplay.level.data, &gameplay.bomb_occupancy, target) {
		player.move_to = target
	}
}

// gameplay_input_holds_direction reads one cardinal direction without applying
// the normal action-boundary priority. Half-tile reversal only cares about the
// direction exactly opposite the current movement.
gameplay_input_holds_direction :: proc(
	input: ^Gameplay_Input_Buffer,
	direction: Direction,
) -> bool {
	switch direction {
	case .Down:  return input.move_down
	case .Up:    return input.move_up
	case .Right: return input.move_right
	case .Left:  return input.move_left
	case .None:  return false
	}
	return false
}

// try_reverse_player_at_halfway swaps the interpolation endpoints only at the
// exact 16-pixel midpoint. Swapping at equal progress preserves the rendered
// and collision position, then the remaining six ticks return to the original
// tile. Perpendicular input remains queued for the next tile boundary.
try_reverse_player_at_halfway :: proc(gameplay: ^Gameplay) -> bool {
	player := &gameplay.player
	if player.movement_step != PLAYER_REVERSAL_STEP do return false
	if player.move_from == player.move_to || player.direction == .None do return false

	reverse := opposite_direction(player.direction)
	input := &gameplay.tick_state.input
	if !gameplay_input_holds_direction(input, reverse) do return false
	// Holding both directions means "continue" and avoids keyboard/controller
	// diagonal jitter selecting an accidental reversal.
	if gameplay_input_holds_direction(input, player.direction) do return false
	if !is_walkable(&gameplay.level.data, &gameplay.bomb_occupancy, player.move_from) {
		return false
	}

	player.move_from, player.move_to = player.move_to, player.move_from
	player.direction = reverse
	return true
}

// advance_player_action_step updates interpolation progress for the current
// action and commits the target grid cell on its final step.
advance_player_action_step :: proc(player: ^Player_State, completed_steps: int) {
	player.movement_step = clamp(completed_steps, 0, MOVEMENT_STEPS_PER_TILE)
	if player.direction != .None {
		cycle_ticks := PLAYER_DIRECTION_FRAME_COUNT * PLAYER_ANIMATION_TICKS_PER_FRAME
		player.animation_ticks = (player.animation_ticks + 1) % cycle_ticks
	}
	if player.movement_step == MOVEMENT_STEPS_PER_TILE {
		player.position = player.move_to
	}
}

// movement_screen_position converts simulation-space interpolation into pixels.
// Division supports the selected 12-tick cadence without requiring a whole
// number of pixels per fixed tick and lands exactly on every cell boundary.
movement_screen_position :: proc(
	move_from, move_to: Grid_Position,
	movement_step: int,
) -> (x, y: i32) {
	subtile := movement_subtile_position(move_from, move_to, movement_step)
	return i32(MAP_OFFSET_X + subtile.x * MAP_TILE_SIZE / MOVEMENT_STEPS_PER_TILE),
	       i32(MAP_OFFSET_Y + subtile.y * MAP_TILE_SIZE / MOVEMENT_STEPS_PER_TILE)
}

// player_subtile_position exposes the player's interpolated simulation
// coordinate for collision checks without involving the renderer.
player_subtile_position :: proc(player: ^Player_State) -> Subtile_Position {
	return movement_subtile_position(
		player.move_from,
		player.move_to,
		player.movement_step,
	)
}

// player_screen_position exposes the player's current interpolated position to
// rendering.
player_screen_position :: proc(player: ^Player_State) -> (x, y: i32) {
	return movement_screen_position(
		player.move_from,
		player.move_to,
		player.movement_step,
	)
}

// player_direction_first_sprite maps a facing direction to the first frame of
// its six-pose animation cycle. None falls back to the front-facing idle pose.
player_direction_first_sprite :: proc(direction: Direction) -> int {
	switch direction {
	case .Down:  return PLAYER_DOWN_FIRST_SPRITE
	case .Up:    return PLAYER_UP_FIRST_SPRITE
	case .Left:  return PLAYER_LEFT_FIRST_SPRITE
	case .Right: return PLAYER_RIGHT_FIRST_SPRITE
	case .None:  return PLAYER_IDLE_SPRITE
	}
	return PLAYER_IDLE_SPRITE
}

// player_sprite_index advances independently of tile interpolation so the
// six-pose walk plays at a readable 10 FPS instead of completing at 30 FPS
// during every 0.2-second tile movement. Idle always returns the first
// front-facing frame so the miner looks toward the player when stopped.
player_sprite_index :: proc(player: ^Player_State) -> u8 {
	if player.direction == .None {
		return PLAYER_IDLE_SPRITE
	}

	frame := (player.animation_ticks / PLAYER_ANIMATION_TICKS_PER_FRAME) %
		PLAYER_DIRECTION_FRAME_COUNT
	return u8(player_direction_first_sprite(player.direction) + frame)
}
