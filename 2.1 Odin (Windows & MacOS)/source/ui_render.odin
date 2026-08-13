package caverace

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

// duration_text_cstring formats a tick count as mm:ss.t into caller-owned
// storage, or a placeholder when a duration has not been set.
duration_text_cstring :: proc(buffer: []byte, ticks: int) -> cstring {
	if ticks <= 0 do return format_cstring(buffer, "--:--.-")
	total_seconds := ticks / GAMEPLAY_TICK_HZ
	tenths := (ticks % GAMEPLAY_TICK_HZ) * 10 / GAMEPLAY_TICK_HZ
	return format_cstring(buffer, "%02d:%02d.%d", total_seconds / 60, total_seconds % 60, tenths)
}

// format_cstring is the shared allocation-free formatting boundary for
// renderers that need to measure text before drawing it.
format_cstring :: proc(buffer: []byte, format: string, args: ..any) -> cstring {
	formatted := fmt.bprintf(buffer[:len(buffer) - 1], format, ..args)
	buffer[len(formatted)] = 0
	return cstring(raw_data(buffer[:]))
}

draw_ui_format :: proc(x, y, size: i32, color: rl.Color, format: string, args: ..any) {
	buffer: [256]byte
	rl.DrawText(format_cstring(buffer[:], format, ..args), x, y, size, color)
}

// centered_ui_x resolves horizontal UI geometry against the current fixed
// canvas instead of retaining coordinates from an older screen width.
centered_ui_x :: proc(width: i32) -> i32 {
	return (WINDOW_WIDTH - width) / 2
}

// ui_pulse is presentation-only and never gates gameplay or input.
ui_pulse :: proc(clock: f64, period_seconds: f64) -> f32 {
	phase := math.mod(clock, period_seconds) / period_seconds
	return f32((math.sin(phase * math.TAU - math.PI / 2) + 1) / 2)
}

draw_selection_glow :: proc(x, y, width, height: i32, pulse: f32) {
	glow_alpha := 0.14 + pulse * 0.10
	rl.DrawRectangle(x, y, width, height, rl.Fade(rl.GOLD, glow_alpha))
	rl.DrawRectangle(x, y, 3, height, rl.Fade(rl.GOLD, 0.85 + pulse * 0.15))
}

// draw_menu_panel is shared by settings, bindings, pause-adjacent screens,
// and level results. It returns the resolved left edge for relative layouts.
draw_menu_panel :: proc(
	title: cstring,
	height: i32 = 310,
	width: i32 = 480,
	panel_y: i32 = 58,
) -> i32 {
	panel_x := (WINDOW_WIDTH - width) / 2
	rl.DrawRectangle(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, rl.Fade(rl.BLACK, 0.12))
	rl.DrawRectangle(panel_x + 5, panel_y + 6, width, height, rl.Fade(rl.BLACK, 0.55))
	rl.DrawRectangle(panel_x, panel_y, width, height, rl.Fade(rl.BLACK, 0.84))
	rl.DrawRectangle(panel_x + 1, panel_y + 1, width - 2, 42, rl.Fade(rl.DARKBROWN, 0.42))
	rl.DrawRectangleLines(panel_x, panel_y, width, height, rl.GOLD)
	rl.DrawRectangleLines(panel_x + 3, panel_y + 3, width - 6, height - 6, rl.Fade(rl.GOLD, 0.28))
	title_width := rl.MeasureText(title, 24)
	rl.DrawText(title, (WINDOW_WIDTH - title_width) / 2, panel_y + 14, 24, rl.GOLD)
	return panel_x
}

MENU_PANEL_CONTENT_GAP :: 48

draw_menu_value_row :: proc(
	label_x, value_right_x, y, size: i32,
	color: rl.Color,
	label: cstring,
	value_format: string,
	args: ..any,
) {
	rl.DrawText(label, label_x, y, size, color)
	value_buffer: [32]byte
	value := format_cstring(value_buffer[:], value_format, ..args)
	value_width := rl.MeasureText(value, size)
	rl.DrawText(value, value_right_x - value_width, y, size, color)
}
