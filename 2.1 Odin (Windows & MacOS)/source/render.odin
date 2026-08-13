package caverace

import rl "vendor:raylib"

draw_autoplay_prompt :: proc() {
	message: cstring = "AUTOPLAY - PRESS ANY KEY OR CLICK"
	font_size: i32 = 16
	width := rl.MeasureText(message, font_size)
	x := (WINDOW_WIDTH - width) / 2
	rl.DrawRectangle(x - 10, 7, width + 20, 24, rl.Fade(rl.BLACK, 0.88))
	rl.DrawRectangleLines(x - 10, 7, width + 20, 24, rl.GOLD)
	rl.DrawText(message, x, 11, font_size, rl.WHITE)
}

pause_menu_item_label :: proc(item: Pause_Menu_Item) -> cstring {
	switch item {
	case .Resume:        return "RESUME"
	case .Restart_Level: return "RESTART LEVEL"
	case .Settings:      return "SETTINGS"
	case .Controls:      return "CONTROLS"
	case .Main_Menu:     return "MAIN MENU"
	}
	return ""
}

// Pause panel geometry: narrow and bottom-anchored like Settings/Bindings, so
// as much of the frozen gameplay behind it stays visible as possible. Its
// title isn't drawn by the shared draw_menu_panel band (this panel keeps its
// own fade-in animation independent of that helper), so it uses its own
// title/content clearances tuned for the larger size-20/32 pause text.
PAUSE_TITLE_TOP    :: 16
PAUSE_CONTENT_TOP  :: 60
PAUSE_ROW_SPACING  :: 32
PAUSE_ROW_HEIGHT   :: 26

// draw_game_pause renders the keyboard/controller pause menu and destructive
// action confirmation without mutating gameplay.
draw_game_pause :: proc(game: ^Game) {
	pause := &game.pause
	if pause.page == .Settings {
		draw_settings_menu(game)
		return
	}
	if pause.page == .Controls {
		draw_bindings_menu(game)
		return
	}
	panel_x, panel_y, panel_width, panel_height := pause_panel_geometry()
	ease := f32(clamp(game.pause.elapsed_seconds / 0.15, 0, 1))

	rl.DrawRectangle(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, rl.Fade(rl.BLACK, 0.72 * ease))
	rl.DrawRectangle(panel_x, panel_y, panel_width, panel_height, rl.Fade(rl.BLACK, ease))
	rl.DrawRectangleLines(panel_x, panel_y, panel_width, panel_height, rl.Fade(rl.GOLD, ease))

	title: cstring = "PAUSED"
	title_size: i32 = 32
	title_width := rl.MeasureText(title, title_size)
	rl.DrawText(
		title,
		(WINDOW_WIDTH - title_width) / 2,
		panel_y + PAUSE_TITLE_TOP,
		title_size,
		rl.Fade(rl.GOLD, ease),
	)

	if pause.confirmation != .None {
		prompt: cstring = "RESTART THIS LEVEL?"
		if pause.confirmation == .Main_Menu {
			prompt = "ABANDON RUN FOR MAIN MENU?"
		}
		prompt_width := rl.MeasureText(prompt, 18)
		rl.DrawText(prompt, (WINDOW_WIDTH - prompt_width) / 2, panel_y + 70, 18, rl.WHITE)
		confirm_rect, cancel_rect := pause_confirmation_rects()
		confirm_hovered := ui_rect_contains(confirm_rect, game.pointer)
		cancel_hovered := ui_rect_contains(cancel_rect, game.pointer)
		confirm_color := rl.GOLD if confirm_hovered else rl.LIGHTGRAY
		cancel_color := rl.GOLD if cancel_hovered else rl.LIGHTGRAY
		rl.DrawRectangle(i32(confirm_rect.x), i32(confirm_rect.y), i32(confirm_rect.width), i32(confirm_rect.height), rl.Fade(rl.BLACK, 0.92))
		rl.DrawRectangleLines(i32(confirm_rect.x), i32(confirm_rect.y), i32(confirm_rect.width), i32(confirm_rect.height), confirm_color)
		rl.DrawRectangle(i32(cancel_rect.x), i32(cancel_rect.y), i32(cancel_rect.width), i32(cancel_rect.height), rl.Fade(rl.BLACK, 0.92))
		rl.DrawRectangleLines(i32(cancel_rect.x), i32(cancel_rect.y), i32(cancel_rect.width), i32(cancel_rect.height), cancel_color)
		confirm_label: cstring = "CONFIRM"
		cancel_label: cstring = "CANCEL"
		rl.DrawText(confirm_label, i32(confirm_rect.x) + (i32(confirm_rect.width) - rl.MeasureText(confirm_label, 16)) / 2, i32(confirm_rect.y) + 6, 16, confirm_color)
		rl.DrawText(cancel_label, i32(cancel_rect.x) + (i32(cancel_rect.width) - rl.MeasureText(cancel_label, 16)) / 2, i32(cancel_rect.y) + 6, 16, cancel_color)

		cancel_key: cstring = "ESC" if game.last_input_device == .Keyboard else "B"
		hint_buffer: [128]byte
		hint := format_cstring(
			hint_buffer[:],
			"%s: CONFIRM    %s: CANCEL",
			action_prompt(.Confirm, game.last_input_device, game.settings.bindings, game.settings.controller_bindings),
			cancel_key,
		)
		hint_width := rl.MeasureText(hint, 14)
		rl.DrawText(hint, (WINDOW_WIDTH - hint_width) / 2, panel_y + 154, 14, rl.GOLD)
		return
	}

	prefix_x := panel_x + MENU_SIDE_INSET
	label_x := panel_x + MENU_SIDE_INSET + 16
	glow_x := panel_x + MENU_GLOW_INSET
	glow_width := panel_width - MENU_GLOW_INSET * 2

	pulse := ui_pulse(game.ui_clock, 1.6)
	for item_index in 0 ..< len(Pause_Menu_Item) {
		item := Pause_Menu_Item(item_index)
		label := pause_menu_item_label(item)
		color := rl.WHITE
		prefix: cstring = "  "
		y := panel_y + PAUSE_CONTENT_TOP + i32(item_index) * PAUSE_ROW_SPACING
		if pause.selected == item {
			draw_selection_glow(glow_x, y - 3, glow_width, PAUSE_ROW_HEIGHT, pulse * ease)
			color = rl.GOLD
			prefix = "> "
		}
		rl.DrawText(prefix, prefix_x, y, 20, rl.Fade(color, ease))
		rl.DrawText(label, label_x, y, 20, rl.Fade(color, ease))
	}
}

main_menu_item_label :: proc(item: Main_Menu_Item) -> cstring {
	switch item {
	case .Start_Game:   return "START GAME"
	case .Tutorial:     return "TUTORIAL"
	case .How_To_Play:  return "HOW TO PLAY"
	case .Settings:     return "SETTINGS"
	case .Replay_Story: return "REPLAY STORY"
	case .Quit:         return "QUIT"
	}
	return ""
}

// main_menu_item_gap adds breathing room between the primary, secondary, and
// quit action groups so the list reads with clear hierarchy instead of one
// flat block.
main_menu_item_gap :: proc(item_index: int) -> i32 {
	gap: i32 = 0
	if item_index > 1 do gap += 8
	if item_index > 4 do gap += 8
	return gap
}

// draw_main_menu_ambience adds a handful of slow, story-effect-style twinkles
// over the crystal clusters flanking the title art, plus a
// lit fuse (smoke, spark, and rising embers, the same treatment the TNT_Fuse
// story panel uses) on the bomb the miner is holding, so the menu feels
// alive even before the player touches a control. The daytime title art has
// no starry sky to twinkle in, so the crystal glints sit on the crystals
// themselves instead.
draw_main_menu_ambience :: proc(game: ^Game, effects: ^Effect_Assets) {
	points := [7]Story_Point {
		{48, 285}, {65, 306}, {69, 375}, {33, 424}, {87, 421},
		{751, 367}, {774, 390},
	}
	for point, point_index in points {
		pulse := story_effect_pulse(game.ui_clock, point_index * 6, 26, game.settings.reduced_flashes)
		draw_story_glint(point, 2, rl.SKYBLUE, pulse, 1, game.settings.reduced_flashes)
	}
	draw_story_fuse({418, 286}, game.ui_clock, 9, 1, game.settings.reduced_flashes)
	draw_flame_effect(
		effects.flame,
		419,
		295,
		9,
		22,
		game.ui_clock,
		0.76,
		game.settings.reduced_flashes,
		-4,
	)
	draw_ambient_smoke(
		effects,
		{419, 278},
		game.ui_clock,
		14,
		rl.LIGHTGRAY,
		0.26,
		game.settings.reduced_flashes,
	)
	draw_ambient_smoke(
		effects,
		{720, 174},
		game.ui_clock + 1.7,
		38,
		rl.GRAY,
		0.18,
		game.settings.reduced_flashes,
	)
	volcano_pulse := story_effect_pulse(game.ui_clock, 5, 31, game.settings.reduced_flashes)
	draw_story_light(
		{720, 176},
		44,
		rl.ORANGE,
		0.18 + volcano_pulse * 0.12,
		1,
		game.settings.reduced_flashes,
	)
}

// main_menu_content_height returns the exact space the action list needs, so
// the card can be sized to fit its content instead of leaving empty space
// where the title used to sit.
main_menu_content_height :: proc() -> i32 {
	last_index := len(Main_Menu_Item) - 1
	last_y := MAIN_MENU_LIST_TOP + i32(last_index) * 24 + main_menu_item_gap(last_index)
	return last_y + 22 + MAIN_MENU_LIST_TOP
}

MAIN_MENU_LIST_TOP :: 16

main_menu_panel_geometry :: proc(elapsed_seconds: f64) -> (x, y, width, height: i32) {
	x = 70
	y = 210

	width = 170
	height = main_menu_content_height()

	ease := clamp(f32(elapsed_seconds) / 0.28, 0, 1)
	ease = ease * ease * (3 - 2 * ease)
	x += i32((1 - ease) * 22)

	return
}

// draw_main_menu_page preserves the title scene by keeping navigation in a
// compact command card on the quiet right side of the original artwork. A
// soft vignette replaces the old flat panel so the art stays the focus, and
// the card eases in when the menu is entered. The card has no title of its
// own and is sized to fit exactly around the action list.
draw_main_menu_page :: proc(game: ^Game, effects: ^Effect_Assets) {
	panel_x, panel_y, panel_width, panel_height := main_menu_panel_geometry(game.menu.page_elapsed_seconds)

	ease := clamp(f32(game.menu.page_elapsed_seconds) / 0.28, 0, 1)
	ease = ease * ease * (3 - 2 * ease)
	pulse := ui_pulse(game.ui_clock, 1.6)

	draw_main_menu_ambience(game, effects)

	// Soft drop shadow, then a top/bottom vignette instead of a flat panel so
	// the artwork stays visible at the card's edges while the center, where
	// the text lives, stays readable.
	rl.DrawRectangle(panel_x + 5, panel_y + 6, panel_width, panel_height, rl.Fade(rl.BLACK, 0.45 * ease))
	half_height := panel_height / 2
	rl.DrawRectangleGradientV(panel_x, panel_y, panel_width, half_height, rl.Fade(rl.BLACK, 0.40 * ease), rl.Fade(rl.BLACK, 0.82 * ease))
	rl.DrawRectangleGradientV(panel_x, panel_y + half_height, panel_width, panel_height - half_height, rl.Fade(rl.BLACK, 0.82 * ease), rl.Fade(rl.BLACK, 0.40 * ease))
	rl.DrawRectangleLines(panel_x - 3, panel_y - 3, panel_width + 6, panel_height + 6, rl.Fade(rl.GOLD, 0.22 * ease))
	rl.DrawRectangle(panel_x, panel_y, 4, panel_height, rl.Fade(rl.GOLD, ease))
	rl.DrawRectangleLines(panel_x, panel_y, panel_width, panel_height, rl.Fade(rl.GOLD, 0.72 * ease))

	for item_index in 0 ..< len(Main_Menu_Item) {
		y := panel_y + MAIN_MENU_LIST_TOP + i32(item_index) * 24 + main_menu_item_gap(item_index)
		color := rl.Fade(rl.LIGHTGRAY, ease)
		label_x := panel_x + 29
		if game.menu.selected == item_index {
			draw_selection_glow(panel_x + 10, y - 3, panel_width - 20, 22, pulse)
			rl.DrawText(">", panel_x + 17, y, 16, rl.Fade(rl.GOLD, (0.85 + pulse * 0.15) * ease))
			color = rl.Fade(rl.GOLD, ease)
		}
		rl.DrawText(main_menu_item_label(Main_Menu_Item(item_index)), label_x, y, 16, color)
	}
}

// Shared geometry for the narrow, bottom-anchored, value-aligned menu panels
// (Settings, Bindings) so both stay visually consistent and the art behind
// them stays as visible as possible.
MENU_NARROW_PANEL_WIDTH :: 340
MENU_ROW_SPACING        :: 20
MENU_ROW_HEIGHT         :: 19
MENU_PANEL_BOTTOM_MARGIN :: 12
MENU_SIDE_INSET         :: 20
MENU_GLOW_INSET         :: 12
BINDING_WAIT_PANEL_WIDTH :: 334

// menu_narrow_panel_height sizes a narrow panel to exactly fit row_count rows
// at the given spacing, with no separate control-hint footer, so it stays
// correctly fitted if the row count or spacing ever changes.
menu_narrow_panel_height :: proc(row_count: int, row_spacing: i32 = MENU_ROW_SPACING, row_height: i32 = MENU_ROW_HEIGHT) -> i32 {
	last_offset := MENU_PANEL_CONTENT_GAP + i32(row_count - 1) * row_spacing
	return last_offset + row_height + 14
}

draw_setting_value_control :: proc(
	panel_x, y: i32,
	color: rl.Color,
	value_format: string,
	args: ..any,
) {
	left_x := panel_x + SETTINGS_DECREMENT_OFFSET
	right_x := panel_x + SETTINGS_INCREMENT_OFFSET
	left_label: cstring = "<"
	right_label: cstring = ">"
	arrow_size: i32 = 16
	arrow_inset := (SETTINGS_CONTROL_WIDTH - rl.MeasureText(left_label, arrow_size)) / 2
	rl.DrawText(left_label, left_x + arrow_inset, y, arrow_size, color)
	rl.DrawText(right_label, right_x + arrow_inset, y, arrow_size, color)
	value_buffer: [32]byte
	value := format_cstring(value_buffer[:], value_format, ..args)
	value_width := rl.MeasureText(value, 16)
	value_center := panel_x + SETTINGS_VALUE_CENTER_OFFSET
	rl.DrawText(value, value_center - value_width / 2, y, 16, color)
}

// draw_settings_menu anchors its panel to the bottom of the screen with a
// small margin and keeps it narrower than the other menu panels, so the
// title art stays visible above and beside it.
draw_settings_menu :: proc(game: ^Game) {
	height := menu_narrow_panel_height(len(Settings_Menu_Item))
	panel_y := WINDOW_HEIGHT - height - MENU_PANEL_BOTTOM_MARGIN
	panel_x := draw_menu_panel("SETTINGS", height, MENU_NARROW_PANEL_WIDTH, panel_y)
	settings := &game.settings
	pulse := ui_pulse(game.ui_clock, 1.6)

	prefix_x := panel_x + MENU_SIDE_INSET
	label_x := panel_x + MENU_SIDE_INSET + 16
	glow_x := panel_x + MENU_GLOW_INSET
	glow_width: i32 = MENU_NARROW_PANEL_WIDTH - MENU_GLOW_INSET * 2

	for item_index in 0 ..< len(Settings_Menu_Item) {
		item := Settings_Menu_Item(item_index)
		color := rl.LIGHTGRAY
		prefix: cstring = "  "
		y := panel_y + MENU_PANEL_CONTENT_GAP + i32(item_index) * MENU_ROW_SPACING
		if game.menu.selected == item_index {
			draw_selection_glow(glow_x, y - 2, glow_width, MENU_ROW_HEIGHT, pulse)
			color = rl.GOLD
			prefix = "> "
		}
		rl.DrawText(prefix, prefix_x, y, 16, color)
		switch item {
		case .Music:
			rl.DrawText("MUSIC", label_x, y, 16, color)
			draw_setting_value_control(panel_x, y, color, "%d%%", settings.music_volume)
		case .Sfx:
			rl.DrawText("SFX", label_x, y, 16, color)
			draw_setting_value_control(panel_x, y, color, "%d%%", settings.sfx_volume)
		case .Display_Mode:
			mode: cstring = "WINDOWED"
			if settings.display_mode == .Borderless do mode = "BORDERLESS"
			rl.DrawText("DISPLAY", label_x, y, 16, color)
			draw_setting_value_control(panel_x, y, color, "%s", mode)
		case .Window_Scale:
			rl.DrawText("WINDOW SCALE", label_x, y, 16, color)
			draw_setting_value_control(panel_x, y, color, "%dx", settings.window_scale)
		case .Reduced_Flashes:
			rl.DrawText("REDUCED FLASHES", label_x, y, 16, color)
			draw_setting_value_control(panel_x, y, color, "%s", "ON" if settings.reduced_flashes else "OFF")
		case .Screen_Shake:
			rl.DrawText("SCREEN SHAKE", label_x, y, 16, color)
			draw_setting_value_control(panel_x, y, color, "%d%%", settings.screen_shake)
		case .Controller_Rumble:
			rl.DrawText("CONTROLLER RUMBLE", label_x, y, 16, color)
			draw_setting_value_control(panel_x, y, color, "%s", "ON" if settings.controller_rumble else "OFF")
		case .High_Contrast:
			rl.DrawText("DANGER HATCHING", label_x, y, 16, color)
			draw_setting_value_control(panel_x, y, color, "%s", "ON" if settings.high_contrast_preview else "OFF")
		case .Pause_On_Focus_Loss:
			rl.DrawText("FOCUS PAUSE", label_x, y, 16, color)
			draw_setting_value_control(panel_x, y, color, "%s", "ON" if settings.pause_on_focus_loss else "OFF")
		case .Difficulty:
			rl.DrawText("DIFFICULTY", label_x, y, 16, color)
			draw_setting_value_control(panel_x, y, color, "%s", difficulty_label(settings.difficulty))
		case .Bindings:           rl.DrawText("REMAP CONTROLS", label_x, y, 16, color)
		case .Back:               rl.DrawText("BACK", label_x, y, 16, color)
		}
	}
}

// draw_bindings_menu shares the Settings panel's narrow, bottom-anchored,
// value-aligned layout so the two panels read as one consistent family.
draw_bindings_menu :: proc(game: ^Game) {
	title: cstring = "KEYBOARD BINDINGS ->"
	if game.menu.binding_device == .Controller do title = "CONTROLLER BINDINGS ->"
	row_count := len(Input_Action) + 1
	height := menu_narrow_panel_height(row_count)
	panel_y := WINDOW_HEIGHT - height - MENU_PANEL_BOTTOM_MARGIN
	panel_x := draw_menu_panel(title, height, MENU_NARROW_PANEL_WIDTH, panel_y)
	pulse := ui_pulse(game.ui_clock, 1.6)

	prefix_x := panel_x + MENU_SIDE_INSET
	label_x := panel_x + MENU_SIDE_INSET + 16
	value_right := panel_x + MENU_NARROW_PANEL_WIDTH - MENU_SIDE_INSET
	glow_x := panel_x + MENU_GLOW_INSET
	glow_width: i32 = MENU_NARROW_PANEL_WIDTH - MENU_GLOW_INSET * 2

	for action_index in 0 ..< len(Input_Action) {
		action := Input_Action(action_index)
		color := rl.LIGHTGRAY
		prefix: cstring = "  "
		y := panel_y + MENU_PANEL_CONTENT_GAP + i32(action_index) * MENU_ROW_SPACING
		if game.menu.selected == action_index {
			draw_selection_glow(glow_x, y - 2, glow_width, MENU_ROW_HEIGHT, pulse)
			color = rl.GOLD
			prefix = "> "
		}
		rl.DrawText(prefix, prefix_x, y, 16, color)
		if game.menu.binding_device == .Keyboard {
			draw_menu_value_row(label_x, value_right, y, 16, color, input_action_label(action), "%s", keyboard_key_label(game.settings.bindings[action]))
		} else {
			draw_menu_value_row(label_x, value_right, y, 16, color, input_action_label(action), "%s", controller_button_label(game.settings.controller_bindings[action]))
		}
	}

	back_index := len(Input_Action)
	back_y := panel_y + MENU_PANEL_CONTENT_GAP + i32(back_index) * MENU_ROW_SPACING
	back_color := rl.LIGHTGRAY
	back_prefix: cstring = "  "
	if game.menu.selected == back_index {
		draw_selection_glow(glow_x, back_y - 2, glow_width, MENU_ROW_HEIGHT, pulse)
		back_color = rl.GOLD
		back_prefix = "> "
	}
	rl.DrawText(back_prefix, prefix_x, back_y, 16, back_color)
	rl.DrawText("BACK", label_x, back_y, 16, back_color)

	info_y := panel_y + 100
	if game.menu.binding_waiting {
		info_x := centered_ui_x(BINDING_WAIT_PANEL_WIDTH)
		rl.DrawRectangle(info_x, info_y, BINDING_WAIT_PANEL_WIDTH, 70, rl.BLACK)
		rl.DrawRectangleLines(info_x, info_y, BINDING_WAIT_PANEL_WIDTH, 70, rl.GOLD)
		waiting := "PRESS A KEY FOR %s"
		if game.menu.binding_device == .Controller do waiting = "PRESS A BUTTON FOR %s"
		waiting_buffer: [96]byte
		waiting_text := format_cstring(
			waiting_buffer[:],
			waiting,
			input_action_label(game.menu.binding_action),
		)
		waiting_width := rl.MeasureText(waiting_text, 18)
		rl.DrawText(waiting_text, centered_ui_x(waiting_width), info_y + 16, 18, rl.WHITE)
		cancel_text: cstring = "ESC CANCELS"
		cancel_width := rl.MeasureText(cancel_text, 14)
		rl.DrawText(cancel_text, centered_ui_x(cancel_width), info_y + 46, 14, rl.LIGHTGRAY)
	} else if game.menu.binding_conflict_seconds > 0 {
		msg: cstring = "KEY ALREADY USED"
		msg_width := rl.MeasureText(msg, 16)
		rl.DrawText(msg, centered_ui_x(msg_width), info_y + 28, 16, rl.RED)
	}
}

// draw_main_menu dispatches to the active menu page's own drawing procedure.
draw_main_menu :: proc(game: ^Game, effects: ^Effect_Assets) {
	switch game.menu.page {
	case .Settings:    draw_settings_menu(game)
	case .Bindings:    draw_bindings_menu(game)
	case .How_To_Play:
	case .Main:
		draw_main_menu_page(game, effects)
	}
}

// medal_color maps a level-result medal to the color its label and badge
// render in, reused by draw_level_result.
medal_color :: proc(medal: Medal) -> rl.Color {
	switch medal {
	case .Gold:   return rl.GOLD
	case .Silver: return rl.LIGHTGRAY
	case .Bronze: return rl.ORANGE
	case .None:   return rl.GRAY
	}
	return rl.GRAY
}

// Level-result geometry keeps the portrait and summary in two distinct
// columns. The footer spans both columns below a divider, so neither the
// total nor the continue prompt competes with the score card above it.
LEVEL_RESULT_PANEL_X          :: (WINDOW_WIDTH - 520) / 2
LEVEL_RESULT_PANEL_Y          :: 30
LEVEL_RESULT_PANEL_WIDTH      :: 520
LEVEL_RESULT_PANEL_HEIGHT     :: 340
LEVEL_RESULT_PORTRAIT_X       :: LEVEL_RESULT_PANEL_X + 20
LEVEL_RESULT_PORTRAIT_Y       :: LEVEL_RESULT_PANEL_Y + 64
LEVEL_RESULT_PORTRAIT_WIDTH   :: 154
LEVEL_RESULT_PORTRAIT_HEIGHT  :: 190
LEVEL_RESULT_STAT_X           :: LEVEL_RESULT_PANEL_X + 202
LEVEL_RESULT_STAT_RIGHT       :: LEVEL_RESULT_PANEL_X + LEVEL_RESULT_PANEL_WIDTH - 28

// draw_level_result_stat_row uses one shared baseline and a fixed right edge
// for every value. A subtle rule separates the rows without adding another
// box around the already compact summary column.
draw_level_result_stat_row :: proc(y: i32, label, value: cstring, value_color := rl.WHITE) {
	rl.DrawText(label, LEVEL_RESULT_STAT_X, y, 15, rl.LIGHTGRAY)
	value_width := rl.MeasureText(value, 15)
	rl.DrawText(value, LEVEL_RESULT_STAT_RIGHT - value_width, y, 15, value_color)
	rl.DrawRectangle(
		LEVEL_RESULT_STAT_X,
		y + 23,
		LEVEL_RESULT_STAT_RIGHT - LEVEL_RESULT_STAT_X,
		1,
		rl.Fade(rl.GOLD, 0.16),
	)
}

// draw_level_result draws the simplified "cave complete" summary: a random
// celebration portrait beside the medal earned, time versus par, treasure
// collected, aliens defeated, and the score gained this level.
draw_level_result :: proc(game: ^Game, assets: ^Assets) {
	result := &game.gameplay.level_result
	title_buffer: [32]byte
	title := format_cstring(title_buffer[:], "CAVE %d COMPLETE", result.level_index + 1)
	draw_menu_panel(title, LEVEL_RESULT_PANEL_HEIGHT, LEVEL_RESULT_PANEL_WIDTH, LEVEL_RESULT_PANEL_Y)

	// The portrait sits in its own inset card, with the medal overlapping the
	// lower edge like an award plaque. This visually associates the medal with
	// the celebration instead of centering it ambiguously between both columns.
	rl.DrawRectangle(
		LEVEL_RESULT_PORTRAIT_X + 3,
		LEVEL_RESULT_PORTRAIT_Y + 4,
		LEVEL_RESULT_PORTRAIT_WIDTH,
		LEVEL_RESULT_PORTRAIT_HEIGHT,
		rl.Fade(rl.BLACK, 0.50),
	)
	rl.DrawRectangle(
		LEVEL_RESULT_PORTRAIT_X,
		LEVEL_RESULT_PORTRAIT_Y,
		LEVEL_RESULT_PORTRAIT_WIDTH,
		LEVEL_RESULT_PORTRAIT_HEIGHT,
		rl.Fade(rl.DARKBROWN, 0.20),
	)
	rl.DrawRectangleLines(
		LEVEL_RESULT_PORTRAIT_X,
		LEVEL_RESULT_PORTRAIT_Y,
		LEVEL_RESULT_PORTRAIT_WIDTH,
		LEVEL_RESULT_PORTRAIT_HEIGHT,
		rl.Fade(rl.GOLD, 0.42),
	)
	portrait := assets.sprites.level_complete[result.celebration_sprite]
	portrait_scale: f32 = 0.80
	portrait_x := LEVEL_RESULT_PORTRAIT_X + (LEVEL_RESULT_PORTRAIT_WIDTH - i32(LEVEL_COMPLETE_SPRITE_WIDTH * portrait_scale)) / 2
	portrait_y := LEVEL_RESULT_PORTRAIT_Y + 10
	rl.DrawTextureEx(portrait, {f32(portrait_x), f32(portrait_y)}, 0, portrait_scale, rl.WHITE)

	medal_buffer: [24]byte
	medal_text := format_cstring(medal_buffer[:], "%s MEDAL", medal_label(result.medal))
	medal_width := rl.MeasureText(medal_text, 16)
	badge_width := medal_width + 30
	badge_x := LEVEL_RESULT_PORTRAIT_X + (LEVEL_RESULT_PORTRAIT_WIDTH - badge_width) / 2
	badge_y: i32 = LEVEL_RESULT_PORTRAIT_Y + LEVEL_RESULT_PORTRAIT_HEIGHT - 18
	badge_color := medal_color(result.medal)
	rl.DrawRectangle(badge_x, badge_y, badge_width, 28, rl.Fade(rl.BLACK, 0.94))
	rl.DrawRectangleLines(badge_x, badge_y, badge_width, 28, badge_color)
	rl.DrawRectangle(badge_x + 4, badge_y + 4, 3, 20, rl.Fade(badge_color, 0.72))
	rl.DrawRectangle(badge_x + badge_width - 7, badge_y + 4, 3, 20, rl.Fade(badge_color, 0.72))
	rl.DrawText(medal_text, badge_x + (badge_width - medal_width) / 2, badge_y + 6, 16, badge_color)

	section_label: cstring = "RUN SUMMARY"
	rl.DrawText(section_label, LEVEL_RESULT_STAT_X, LEVEL_RESULT_PANEL_Y + 62, 12, rl.Fade(rl.GOLD, 0.72))
	rl.DrawRectangle(
		LEVEL_RESULT_STAT_X + rl.MeasureText(section_label, 12) + 10,
		LEVEL_RESULT_PANEL_Y + 68,
		LEVEL_RESULT_STAT_RIGHT - LEVEL_RESULT_STAT_X - rl.MeasureText(section_label, 12) - 10,
		1,
		rl.Fade(rl.GOLD, 0.30),
	)

	time_buffer, par_buffer: [16]byte
	treasure_buffer, aliens_buffer: [16]byte
	stat_y: i32 = LEVEL_RESULT_PANEL_Y + 84
	draw_level_result_stat_row(
		stat_y,
		"TIME",
		duration_text_cstring(time_buffer[:], result.elapsed_ticks),
		result.under_par ? rl.GREEN : rl.WHITE,
	)
	stat_y += 30
	draw_level_result_stat_row(stat_y, "PAR", duration_text_cstring(par_buffer[:], result.par_ticks), rl.LIGHTGRAY)
	stat_y += 30
	draw_level_result_stat_row(
		stat_y,
		"TREASURE",
		format_cstring(treasure_buffer[:], "%d / %d", result.treasure_collected, result.treasure_total),
		result.all_treasure ? rl.GREEN : rl.WHITE,
	)
	stat_y += 30
	draw_level_result_stat_row(
		stat_y,
		"ALIENS DEFEATED",
		format_cstring(aliens_buffer[:], "%d", result.enemies_destroyed),
	)

	// Score earned gets its own heavier row so it is the summary's focal
	// point; %+d also renders score corrections cleanly instead of "+-N".
	score_y: i32 = LEVEL_RESULT_PANEL_Y + 216
	rl.DrawRectangle(
		LEVEL_RESULT_STAT_X - 8,
		score_y,
		LEVEL_RESULT_STAT_RIGHT - LEVEL_RESULT_STAT_X + 16,
		42,
		rl.Fade(rl.GOLD, 0.10),
	)
	rl.DrawRectangleLines(
		LEVEL_RESULT_STAT_X - 8,
		score_y,
		LEVEL_RESULT_STAT_RIGHT - LEVEL_RESULT_STAT_X + 16,
		42,
		rl.Fade(rl.GOLD, 0.48),
	)
	rl.DrawText("SCORE EARNED", LEVEL_RESULT_STAT_X, score_y + 11, 17, rl.GOLD)
	score_buffer: [24]byte
	score_text := format_cstring(score_buffer[:], "%+d", result.score_delta)
	score_width := rl.MeasureText(score_text, 20)
	rl.DrawText(score_text, LEVEL_RESULT_STAT_RIGHT - score_width, score_y + 9, 20, rl.GOLD)

	footer_y: i32 = LEVEL_RESULT_PANEL_Y + LEVEL_RESULT_PANEL_HEIGHT - 68
	rl.DrawRectangle(
		LEVEL_RESULT_PANEL_X + 16,
		footer_y,
		LEVEL_RESULT_PANEL_WIDTH - 32,
		1,
		rl.Fade(rl.GOLD, 0.38),
	)
	total_buffer: [32]byte
	total_text := format_cstring(total_buffer[:], "TOTAL SCORE %08d", result.final_score)
	total_width := rl.MeasureText(total_text, 14)
	rl.DrawText(total_text, (WINDOW_WIDTH - total_width) / 2, footer_y + 10, 14, rl.WHITE)

	prompt_buffer: [64]byte
	prompt_text := format_cstring(
		prompt_buffer[:], "%s: CONTINUE",
		action_prompt(.Confirm, game.last_input_device, game.settings.bindings, game.settings.controller_bindings),
	)
	prompt_width := rl.MeasureText(prompt_text, 13)
	rl.DrawText(prompt_text, (WINDOW_WIDTH - prompt_width) / 2, footer_y + 37, 13, rl.GOLD)
}

// draw_game_feedback overlays the transition fade after all screen content,
// using the alpha computed by the non-rendering feedback logic.
draw_game_feedback :: proc(feedback: Game_Feedback) {
	if fade_alpha := transition_fade_alpha(feedback); fade_alpha > 0 {
		rl.DrawRectangle(
			0,
			0,
			WINDOW_WIDTH,
			WINDOW_HEIGHT,
			rl.Fade(rl.BLACK, fade_alpha),
		)
	}
}
