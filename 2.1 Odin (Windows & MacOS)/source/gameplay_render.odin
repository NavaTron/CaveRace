package caverace

import rl "vendor:raylib"

TUTORIAL_PROMPT_WIDTH :: 456

// draw_tutorial_prompt shows the current step's instruction and a skip/pause
// footer, swapping to a "start campaign" prompt once the tutorial completes.
draw_tutorial_prompt :: proc(game: ^Game) {
	panel_x := centered_ui_x(TUTORIAL_PROMPT_WIDTH)
	rl.DrawRectangle(panel_x, 312, TUTORIAL_PROMPT_WIDTH, 42, rl.Fade(rl.BLACK, 0.9))
	rl.DrawRectangleLines(panel_x, 312, TUTORIAL_PROMPT_WIDTH, 42, rl.GOLD)
	instruction := tutorial_instruction(game.tutorial.step)
	width := rl.MeasureText(instruction, 16)
	rl.DrawText(instruction, centered_ui_x(width), 318, 16, rl.WHITE)
	footer_buffer: [128]byte
	footer: cstring
	if game.tutorial.step == .Complete {
		footer = format_cstring(
			footer_buffer[:],
			"%s: START CAMPAIGN",
			action_prompt(.Confirm, game.last_input_device, game.settings.bindings, game.settings.controller_bindings),
		)
	} else {
		skip_label: cstring = "ESC" if game.last_input_device == .Keyboard else "B"
		footer = format_cstring(
			footer_buffer[:],
			"%s: SKIP     %s: PAUSE",
			skip_label,
			action_prompt(.Pause, game.last_input_device, game.settings.bindings, game.settings.controller_bindings),
		)
	}
	footer_width := rl.MeasureText(footer, 13)
	rl.DrawText(footer, centered_ui_x(footer_width), 337, 13, rl.GOLD)
}

// Outcome ambience remains screen-local and is rendered before lifecycle
// prompts, keeping prompt readability independent from effect changes.
draw_game_over_ambience :: proc(game: ^Game, effects: ^Effect_Assets) {
	portal_pulse := story_effect_pulse(game.ui_clock, 3, 32, game.settings.reduced_flashes)
	draw_story_light(
		{563, 147},
		94,
		rl.MAGENTA,
		0.22 + portal_pulse * 0.14,
		1,
		game.settings.reduced_flashes,
	)
	draw_ambient_smoke(
		effects,
		{563, 190},
		game.ui_clock,
		46,
		rl.Color{96, 76, 112, 255},
		0.20,
		game.settings.reduced_flashes,
	)

	eyes := [3]Story_Point {{565, 93}, {466, 218}, {655, 218}}
	for eye, eye_index in eyes {
		pulse := story_effect_pulse(game.ui_clock, eye_index * 7, 26, game.settings.reduced_flashes)
		draw_story_light(
			eye,
			16,
			rl.RED,
			0.54 + pulse * 0.30,
			1,
			game.settings.reduced_flashes,
		)
	}

	upper_lantern_pulse := story_effect_pulse(game.ui_clock, 5, 27, game.settings.reduced_flashes)
	draw_story_light({406, 190}, 18, rl.GOLD, 0.58 + upper_lantern_pulse * 0.24, 1, game.settings.reduced_flashes)
	draw_flame_effect(effects.flame, 406, 202, 8, 16, game.ui_clock + 0.5, 0.48, game.settings.reduced_flashes)
	lower_lantern_pulse := story_effect_pulse(game.ui_clock, 11, 29, game.settings.reduced_flashes)
	draw_story_light({274, 421}, 24, rl.GOLD, 0.62 + lower_lantern_pulse * 0.26, 1, game.settings.reduced_flashes)
	draw_flame_effect(effects.flame, 274, 437, 11, 23, game.ui_clock, 0.62, game.settings.reduced_flashes)

	crystals := [4]Story_Point {{37, 365}, {65, 425}, {165, 451}, {751, 451}}
	for crystal, crystal_index in crystals {
		pulse := story_effect_pulse(game.ui_clock, crystal_index * 6 + 2, 25, game.settings.reduced_flashes)
		color := rl.SKYBLUE
		if crystal_index < 2 do color = rl.MAGENTA
		draw_story_glint(crystal, 3, color, pulse, 1, game.settings.reduced_flashes)
	}
}

draw_you_won_ambience :: proc(game: ^Game, effects: ^Effect_Assets) {
	right_torch_pulse := story_effect_pulse(game.ui_clock, 4, 25, game.settings.reduced_flashes)
	draw_story_light({750, 194}, 34, rl.ORANGE, 0.62 + right_torch_pulse * 0.26, 1, game.settings.reduced_flashes)
	draw_flame_effect(
		effects.flame,
		751,
		207,
		18,
		47,
		game.ui_clock,
		0.72,
		game.settings.reduced_flashes,
		-6,
	)
	left_lantern_pulse := story_effect_pulse(game.ui_clock, 10, 27, game.settings.reduced_flashes)
	draw_story_light({38, 319}, 23, rl.GOLD, 0.62 + left_lantern_pulse * 0.26, 1, game.settings.reduced_flashes)
	draw_flame_effect(
		effects.flame,
		38,
		337,
		10,
		22,
		game.ui_clock + 0.8,
		0.58,
		game.settings.reduced_flashes,
	)

	treasure := [7]Story_Point {
		{486, 75}, {523, 281}, {550, 354}, {450, 386},
		{589, 384}, {403, 405}, {760, 426},
	}
	for point, point_index in treasure {
		pulse := story_effect_pulse(game.ui_clock, point_index * 5 + 3, 24, game.settings.reduced_flashes)
		color := rl.SKYBLUE
		if point_index == 2 do color = rl.RED
		if point_index == 4 do color = rl.GREEN
		draw_story_glint(point, i32(3 + point_index % 2), color, pulse, 1, game.settings.reduced_flashes)
	}
}

gameplay_world_is_visible :: proc(state: Gameplay_State) -> bool {
	return state == .Playing || state == .Dead || state == .Won
}

// draw_gameplay_world declares the gameplay stacking contract in one place.
// Keep additions in the appropriate phase so effects cannot accidentally
// cover actors, collision previews, or the HUD.
draw_gameplay_world :: proc(ctx: ^Render_Context) {
	game := ctx.game
	assets := ctx.assets
	gameplay := &game.gameplay
	assert(gameplay_world_is_visible(gameplay.state))

	// 1. Persistent terrain and object tiles.
	draw_level_tiles(&gameplay.level, assets.tiles[gameplay.theme], &assets.sprites)

	// 2. Theme ambience that belongs behind actors.
	if gameplay.theme == .Lava {
		draw_lava_ambience(
			&gameplay.level,
			&assets.effects,
			game.ui_clock,
			game.settings.reduced_flashes,
		)
	}

	// 3. Bombs, actors, danger previews, and legacy blast cells.
	draw_level_entities(
		gameplay,
		&assets.sprites,
		&assets.effects,
		game.ui_clock,
		game.settings.high_contrast_preview,
		game.settings.reduced_flashes,
	)

	// 4. Presentation-only world particles and textured effects.
	draw_game_world_effects(
		&game.effects,
		&assets.effects,
		game.settings.reduced_flashes,
	)

	// 5. Stable gameplay HUD; later screen overlays may sit above it.
	draw_gameplay_hud(gameplay, assets.screens.status_bar, assets.sprites.tools)
}

// draw_terminal_gameplay_screen handles screens which replace the cave
// completely. Returning true prevents any world layer from leaking through.
draw_terminal_gameplay_screen :: proc(ctx: ^Render_Context) -> bool {
	game := ctx.game
	assets := ctx.assets
	switch game.gameplay.state {
	case .Game_Over:
		rl.DrawTexture(assets.screens.game_over, 0, 0, rl.WHITE)
		draw_game_over_ambience(game, &assets.effects)
		return true
	case .Game_Won:
		rl.DrawTexture(assets.screens.you_won, 0, 0, rl.WHITE)
		draw_you_won_ambience(game, &assets.effects)
		return true
	case .Load_Level, .Playing, .Dead, .Won, .Load_Failed:
	}
	return false
}

// draw_gameplay_lifecycle_overlay maps simulation lifecycle states to their
// presentation without knowing how the world below was assembled.
draw_gameplay_lifecycle_overlay :: proc(ctx: ^Render_Context) {
	game := ctx.game
	switch game.gameplay.state {
	case .Load_Level:
		draw_gameplay_message("Loading level...")
	case .Dead:
		menu_label: cstring = "B" if game.last_input_device == .Controller else "ESC"
		draw_gameplay_message_format(
			"YOU DIED - %s OR %s TO RETRY, %s FOR MENU",
			action_prompt(.Confirm, game.last_input_device, game.settings.bindings, game.settings.controller_bindings),
			action_prompt(.Restart, game.last_input_device, game.settings.bindings, game.settings.controller_bindings),
			menu_label,
		)
	case .Won:
		draw_level_result(game, ctx.assets)
	case .Load_Failed:
		menu_label: cstring = "B" if game.last_input_device == .Controller else "ESC"
		draw_gameplay_message_format(
			"LOAD FAILED - %s TO RETRY, %s FOR MENU",
			action_prompt(.Confirm, game.last_input_device, game.settings.bindings, game.settings.controller_bindings),
			menu_label,
		)
	case .Playing, .Game_Won, .Game_Over:
	}
}

// draw_gameplay coordinates mutually exclusive terminal and cave render paths.
draw_gameplay :: proc(ctx: ^Render_Context) {
	if draw_terminal_gameplay_screen(ctx) do return
	if gameplay_world_is_visible(ctx.game.gameplay.state) {
		draw_gameplay_world(ctx)
	}
	draw_gameplay_lifecycle_overlay(ctx)
}

draw_gameplay_message :: proc(message: cstring) {
	font_size: i32 = 20
	text_width := rl.MeasureText(message, font_size)
	text_x := (WINDOW_WIDTH - text_width) / 2
	text_y := WINDOW_HEIGHT / 2 - font_size / 2
	rl.DrawRectangle(text_x - 12, text_y - 8, text_width + 24, font_size + 16, rl.BLACK)
	rl.DrawText(message, text_x, text_y, font_size, rl.WHITE)
}

draw_gameplay_message_format :: proc(format: string, args: ..any) {
	buffer: [256]byte
	draw_gameplay_message(format_cstring(buffer[:], format, ..args))
}
