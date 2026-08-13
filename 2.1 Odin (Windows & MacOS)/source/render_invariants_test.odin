package caverace

import "core:testing"

@(test)
test_presentation_rectangle_preserves_aspect_ratio :: proc(t: ^testing.T) {
	native := presentation_rectangle(WINDOW_WIDTH, WINDOW_HEIGHT)
	testing.expect_value(t, native.x, f32(0))
	testing.expect_value(t, native.y, f32(0))
	testing.expect_value(t, native.width, f32(WINDOW_WIDTH))
	testing.expect_value(t, native.height, f32(WINDOW_HEIGHT))

	tall := presentation_rectangle(1600, 1200)
	testing.expect_value(t, tall.x, f32(0))
	testing.expect_value(t, tall.y, f32(120))
	testing.expect_value(t, tall.width, f32(1600))
	testing.expect_value(t, tall.height, f32(960))

	wide := presentation_rectangle(1000, 480)
	testing.expect_value(t, wide.x, f32(100))
	testing.expect_value(t, wide.y, f32(0))
	testing.expect_value(t, wide.width, f32(800))
	testing.expect_value(t, wide.height, f32(480))
}

@(test)
test_centered_ui_geometry_uses_current_canvas_width :: proc(t: ^testing.T) {
	testing.expect_value(t, centered_ui_x(TUTORIAL_PROMPT_WIDTH), 172)
	testing.expect_value(t, centered_ui_x(BINDING_WAIT_PANEL_WIDTH), 233)
	testing.expect_value(
		t,
		centered_ui_x(TUTORIAL_PROMPT_WIDTH) + TUTORIAL_PROMPT_WIDTH / 2,
		WINDOW_WIDTH / 2,
	)
	testing.expect_value(
		t,
		centered_ui_x(BINDING_WAIT_PANEL_WIDTH) + BINDING_WAIT_PANEL_WIDTH / 2,
		WINDOW_WIDTH / 2,
	)
}

@(test)
test_render_state_visibility_contract :: proc(t: ^testing.T) {
	testing.expect(t, gameplay_world_is_visible(.Playing))
	testing.expect(t, gameplay_world_is_visible(.Dead))
	testing.expect(t, gameplay_world_is_visible(.Won))
	testing.expect(t, !gameplay_world_is_visible(.Load_Level))
	testing.expect(t, !gameplay_world_is_visible(.Load_Failed))
	testing.expect(t, !gameplay_world_is_visible(.Game_Over))
	testing.expect(t, !gameplay_world_is_visible(.Game_Won))

	game: Game
	game.screen = .Tutorial
	testing.expect(t, game_effect_overlay_is_visible(&game))
	game.screen = .Main_Menu
	testing.expect(t, !game_effect_overlay_is_visible(&game))
	game.screen = .Playing
	game.gameplay.state = .Playing
	testing.expect(t, game_effect_overlay_is_visible(&game))
	game.gameplay.state = .Dead
	testing.expect(t, game_effect_overlay_is_visible(&game))
	game.gameplay.state = .Game_Won
	testing.expect(t, game_effect_overlay_is_visible(&game))
	game.gameplay.state = .Won
	testing.expect(t, !game_effect_overlay_is_visible(&game))
	game.gameplay.state = .Game_Over
	testing.expect(t, !game_effect_overlay_is_visible(&game))
}

@(test)
test_effect_animation_bounds :: proc(t: ^testing.T) {
	testing.expect_value(t, effect_loop_frame(-1, EFFECT_FLAME_FPS, EFFECT_FLAME_FRAME_COUNT), 0)
	testing.expect_value(t, effect_loop_frame(1, EFFECT_FLAME_FPS, EFFECT_FLAME_FRAME_COUNT), 15)
	testing.expect_value(t, effect_loop_frame(4, EFFECT_FLAME_FPS, EFFECT_FLAME_FRAME_COUNT), 0)
	testing.expect_value(t, story_effect_count(7, false), 7)
	testing.expect_value(t, story_effect_count(7, true), 4)
	testing.expect_value(t, story_effect_count(1, true), 1)

	testing.expect_value(t, treasure_toast_alpha(TREASURE_TOAST_SECONDS), f32(0))
	testing.expect_value(t, treasure_toast_alpha(TREASURE_TOAST_SECONDS - TREASURE_TOAST_FADE_SECONDS), f32(1))
	testing.expect_value(t, treasure_toast_alpha(TREASURE_TOAST_FADE_SECONDS), f32(1))
	testing.expect_value(t, treasure_toast_alpha(0), f32(0))
}

@(test)
test_screen_shake_is_bounded_and_disableable :: proc(t: ^testing.T) {
	feedback := Game_Feedback {
		shake_remaining = SCREEN_SHAKE_SECONDS,
		shake_strength  = 1,
	}
	x, y := screen_shake_offset(feedback, 100)
	testing.expect_value(t, x, i32(2))
	testing.expect_value(t, y, i32(0))
	x, y = screen_shake_offset(feedback, 0)
	testing.expect_value(t, x, i32(0))
	testing.expect_value(t, y, i32(0))
	feedback.shake_phase = 1
	x, y = screen_shake_offset(feedback, 100)
	testing.expect_value(t, x, i32(0))
	testing.expect_value(t, y, i32(-2))
}

@(test)
test_shipped_campaign_levels_are_valid :: proc(t: ^testing.T) {
	resource_root := "source"
	if resource_root_is_usable(".") do resource_root = "."
	testing.expect(t, resource_root_is_usable(resource_root), "could not locate shipped test resources")

	for level_index in 0 ..< LEVEL_COUNT {
		level: Level
		loaded := load_level(&level, level_index, resource_root)
		if !testing.expectf(t, loaded, "level %d failed to load", level_index) do continue
		testing.expect_value(t, validate_level_data(&level.data), Level_Data_Error.None)

		gameplay: Gameplay
		gameplay.level = level
		setup_error := setup_level_state(&gameplay)
		if !testing.expectf(t, setup_error == .None, "level %d failed setup: %v", level_index, setup_error) do continue
		testing.expectf(
			t,
			gameplay.treasure_total == level_metadata(level_index).treasure_total,
			"level %d treasure metadata is %d but file contains %d",
			level_index,
			level_metadata(level_index).treasure_total,
			gameplay.treasure_total,
		)
	}
}
