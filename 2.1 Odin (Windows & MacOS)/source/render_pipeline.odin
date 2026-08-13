package caverace

import rl "vendor:raylib"

// Render_Context is the read-only-by-convention boundary between game state,
// loaded presentation resources, and the rendering modules. Keeping the pair
// together prevents every layer coordinator from growing its own parameter
// list as presentation features are added.
Render_Context :: struct {
	game:   ^Game,
	assets: ^Assets,
}

// draw_game is the fixed-canvas render entry point. Its phases define the
// global stacking contract: active screen, screen-local effects, modal UI,
// automation notice, and finally full-screen feedback.
draw_game :: proc(game: ^Game, assets: ^Assets) {
	ctx := Render_Context {game = game, assets = assets}
	draw_active_screen(&ctx)
	draw_screen_effect_overlay(&ctx)
	draw_modal_overlay(&ctx)
	draw_automation_overlay(&ctx)
	draw_global_feedback_overlay(&ctx)
}

// draw_active_screen owns only content local to the selected App_Screen.
// Cross-screen overlays are deliberately handled by later pipeline phases.
draw_active_screen :: proc(ctx: ^Render_Context) {
	game := ctx.game
	assets := ctx.assets
	switch game.screen {
	case .Branding:
		rl.DrawTexture(assets.screens.branding, 0, 0, rl.WHITE)
		draw_branding_effects(
			game.branding_elapsed_seconds,
			&assets.effects,
			game.settings.reduced_flashes,
		)
	case .Intro:
		draw_front_end(game.front_end, &assets.screens)
		draw_story_effects(game.front_end, &assets.effects, game.settings.reduced_flashes)
	case .Main_Menu:
		background_index := MAIN_MENU_FIRST_IMAGE
		if game.menu.page == .How_To_Play do background_index = MAIN_MENU_LAST_IMAGE
		rl.DrawTexture(assets.screens.front_end[background_index], 0, 0, rl.WHITE)
		draw_main_menu(game, &assets.effects)
	case .Tutorial:
		draw_gameplay(ctx)
		// The level-result panel takes over as soon as the tutorial's single
		// enemy is destroyed, so its instruction must leave at the same time.
		if game.gameplay.state != .Won do draw_tutorial_prompt(game)
	case .Playing:
		draw_gameplay(ctx)
	}
}

game_effect_overlay_is_visible :: proc(game: ^Game) -> bool {
	if game.screen == .Tutorial do return true
	return game.screen == .Playing &&
	       (game.gameplay.state == .Playing || game.gameplay.state == .Dead ||
	        game.gameplay.state == .Game_Won)
}

draw_screen_effect_overlay :: proc(ctx: ^Render_Context) {
	if game_effect_overlay_is_visible(ctx.game) {
		draw_game_effects(&ctx.game.effects)
	}
}

draw_modal_overlay :: proc(ctx: ^Render_Context) {
	game := ctx.game
	if (game.screen == .Playing || game.screen == .Tutorial) && game.pause.open {
		draw_game_pause(game)
	}
}

draw_automation_overlay :: proc(ctx: ^Render_Context) {
	if ctx.game.autoplay.active do draw_autoplay_prompt()
}

draw_global_feedback_overlay :: proc(ctx: ^Render_Context) {
	draw_game_feedback(ctx.game.feedback)
}
