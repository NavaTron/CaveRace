package caverace

import rl "vendor:raylib"

// The playfield fills the window edge-to-edge (config.odin), so the status
// bar owns the strip below it instead of a border-baked frame. Icon
// coordinates below are tuned to the carved slot positions baked into
// status_bar.png and the visible-content bounding box of each icon in
// status_tools.png; re-measure both if either art asset changes.
HUD_STATUS_BAR_Y      :: MAP_HEIGHT * MAP_TILE_SIZE
HUD_STATUS_BAR_HEIGHT :: WINDOW_HEIGHT - HUD_STATUS_BAR_Y

HUD_LIVES_X       :: 174
HUD_LIVES_Y       :: 416
HUD_LIVES_SPACING :: 29

HUD_ENERGY_X       :: 158
HUD_ENERGY_Y       :: 446
HUD_ENERGY_SPACING :: 14

HUD_BOMBS_X       :: 511
HUD_BOMBS_Y       :: 446
HUD_BOMBS_SPACING :: 29

HUD_POWER_X       :: 511
HUD_POWER_Y       :: 415
HUD_POWER_SPACING :: 16

HUD_READOUT_CENTER_X :: 400
HUD_SCORE_Y          :: 424
HUD_LEVEL_NAME_Y     :: 458

HUD_TEXT_FONT_SIZE :: 16

TOOLS_LIFE_SPRITE   :: 0
TOOLS_ENERGY_SPRITE :: 1
TOOLS_POWER_SPRITE  :: 2
TOOLS_BOMB_SPRITE   :: 3

#assert(TOOLS_LIFE_SPRITE < TOOLS_SPRITE_COUNT)
#assert(TOOLS_ENERGY_SPRITE < TOOLS_SPRITE_COUNT)
#assert(TOOLS_POWER_SPRITE < TOOLS_SPRITE_COUNT)
#assert(TOOLS_BOMB_SPRITE < TOOLS_SPRITE_COUNT)

// draw_gameplay_hud draws the status bar strip below the playfield: its
// background, the life/energy/power/bomb icon rows, the live score, and the
// current cave's name.
draw_gameplay_hud :: proc(gameplay: ^Gameplay, status_bar: rl.Texture, tools: rl.Texture) {
	rl.DrawTexture(status_bar, 0, HUD_STATUS_BAR_Y, rl.WHITE)

	player := &gameplay.player
	for icon_index in 0 ..< player.lives {
		draw_sprite(
			tools,
			TOOLS_LIFE_SPRITE,
			i32(HUD_LIVES_X + icon_index * HUD_LIVES_SPACING),
			HUD_LIVES_Y,
		)
	}
	for icon_index in 0 ..< player.energy {
		draw_sprite(
			tools,
			TOOLS_ENERGY_SPRITE,
			i32(HUD_ENERGY_X + icon_index * HUD_ENERGY_SPACING),
			HUD_ENERGY_Y,
		)
	}

	for icon_index in 0 ..< available_bomb_count(gameplay) {
		draw_sprite(
			tools,
			TOOLS_BOMB_SPRITE,
			i32(HUD_BOMBS_X + icon_index * HUD_BOMBS_SPACING),
			HUD_BOMBS_Y,
		)
	}
	for icon_index in 0 ..< player.bomb_power {
		draw_sprite(
			tools,
			TOOLS_POWER_SPRITE,
			i32(HUD_POWER_X + icon_index * HUD_POWER_SPACING),
			HUD_POWER_Y,
		)
	}

	// Center both readouts inside their carved plates. Formatting into local
	// buffers lets us measure the final strings first; the 1px black shadow
	// keeps them readable without shifting the visible white glyphs.
	score_buffer: [32]byte
	score_text := format_cstring(score_buffer[:], "%d", player.score)
	score_x := HUD_READOUT_CENTER_X - rl.MeasureText(score_text, HUD_TEXT_FONT_SIZE) / 2
	rl.DrawText(score_text, score_x - 1, HUD_SCORE_Y - 1, HUD_TEXT_FONT_SIZE, rl.BLACK)
	rl.DrawText(score_text, score_x, HUD_SCORE_Y, HUD_TEXT_FONT_SIZE, rl.WHITE)

	level_name_buffer: [32]byte
	level_name_text := format_cstring(
		level_name_buffer[:],
		"%s",
		level_metadata(gameplay.level_index).name,
	)
	level_name_x := HUD_READOUT_CENTER_X - rl.MeasureText(level_name_text, HUD_TEXT_FONT_SIZE) / 2
	rl.DrawText(level_name_text, level_name_x - 1, HUD_LEVEL_NAME_Y - 1, HUD_TEXT_FONT_SIZE, rl.BLACK)
	rl.DrawText(level_name_text, level_name_x, HUD_LEVEL_NAME_Y, HUD_TEXT_FONT_SIZE, rl.WHITE)
}
