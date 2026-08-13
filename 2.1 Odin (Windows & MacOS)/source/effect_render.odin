package caverace

import "core:math"
import rl "vendor:raylib"

EFFECT_EXPLOSION_COLUMNS     :: 5
EFFECT_EXPLOSION_ROWS        :: 5
EFFECT_EXPLOSION_FRAME_COUNT :: 25
EFFECT_EXPLOSION_FPS         :: 30.0

EFFECT_FLAME_COLUMNS     :: 15
EFFECT_FLAME_ROWS        :: 4
EFFECT_FLAME_FRAME_COUNT :: 60
EFFECT_FLAME_FPS         :: 15.0

// effect_loop_frame derives a stable looping frame directly from a cosmetic
// clock, so menu and story ambience needs no mutable animation state.
effect_loop_frame :: proc(clock, frames_per_second: f64, frame_count: int) -> int {
	if frame_count <= 1 do return 0
	return int(max(clock, 0) * frames_per_second) % frame_count
}

// draw_effect_frame renders one cell from an arbitrary grid atlas around a
// center point. Fractional cell sizes are intentional: some source VFX sheets
// use a non-power-of-two logical grid inside a power-of-two texture.
draw_effect_frame :: proc(
	texture: rl.Texture,
	columns, rows, frame_count, frame_index: int,
	center_x, center_y, width, height: f32,
	tint: rl.Color = rl.WHITE,
	rotation: f32 = 0,
) {
	assert(columns > 0 && rows > 0)
	assert(frame_count > 0 && frame_count <= columns * rows)
	frame := clamp(frame_index, 0, frame_count - 1)
	cell_width := f32(texture.width) / f32(columns)
	cell_height := f32(texture.height) / f32(rows)
	source := rl.Rectangle {
		x      = f32(frame % columns) * cell_width,
		y      = f32(frame / columns) * cell_height,
		width  = cell_width,
		height = cell_height,
	}
	destination := rl.Rectangle {
		x      = center_x,
		y      = center_y,
		width  = width,
		height = height,
	}
	origin := rl.Vector2 {width / 2, height / 2}
	rl.DrawTexturePro(texture, source, destination, origin, rotation, tint)
}

// draw_flame_effect bottom-aligns the loop so it stays attached to a torch or
// fuse while its silhouette changes from frame to frame. Optional rotation
// pivots around that attachment point to follow an illustrated flame's lean.
draw_flame_effect :: proc(
	texture: rl.Texture,
	bottom_x, bottom_y, width, height: f32,
	clock: f64,
	alpha: f32 = 1,
	reduced_flashes := false,
	rotation: f32 = 0,
) {
	fps := EFFECT_FLAME_FPS
	accessibility_alpha := alpha
	if reduced_flashes {
		fps *= 0.5
		accessibility_alpha *= 0.68
	}
	frame := effect_loop_frame(clock, fps, EFFECT_FLAME_FRAME_COUNT)
	cell_width := f32(texture.width) / f32(EFFECT_FLAME_COLUMNS)
	cell_height := f32(texture.height) / f32(EFFECT_FLAME_ROWS)
	source := rl.Rectangle {
		x      = f32(frame % EFFECT_FLAME_COLUMNS) * cell_width,
		y      = f32(frame / EFFECT_FLAME_COLUMNS) * cell_height,
		width  = cell_width,
		height = cell_height,
	}
	destination := rl.Rectangle {
		x      = bottom_x,
		y      = bottom_y,
		width  = width,
		height = height,
	}
	origin := rl.Vector2 {width / 2, height}
	rl.DrawTexturePro(
		texture,
		source,
		destination,
		origin,
		rotation,
		rl.Fade(rl.WHITE, clamp(accessibility_alpha, 0, 1)),
	)
}

// draw_ambient_smoke builds a continuous deterministic plume from the two
// organic smoke masks. It is suitable for screen ambience, not blast timing.
draw_ambient_smoke :: proc(
	effects: ^Effect_Assets,
	origin: Story_Point,
	clock: f64,
	base_size: f32,
	tint: rl.Color,
	alpha: f32,
	reduced_flashes := false,
) {
	particle_count := 5
	if reduced_flashes do particle_count = 3
	for particle_index in 0 ..< particle_count {
		phase := f32(math.mod(clock * 0.22 + f64(particle_index) / f64(particle_count), 1))
		drift: f32 = 1
		if particle_index % 2 == 0 do drift = -1
		x := f32(origin.x) + drift * phase * f32(7 + particle_index * 2)
		y := f32(origin.y) - phase * base_size * 1.45
		size := base_size * (0.58 + phase * 0.72)
		fade := (1 - phase) * alpha
		if reduced_flashes do fade *= 0.72
		texture := effects.smoke[particle_index % len(effects.smoke)]
		source := rl.Rectangle {width = f32(texture.width), height = f32(texture.height)}
		destination := rl.Rectangle {x = x, y = y, width = size, height = size}
		origin_offset := rl.Vector2 {size / 2, size / 2}
		rotation := f32(particle_index * 37) + phase * 18 * drift
		rl.DrawTexturePro(
			texture,
			source,
			destination,
			origin_offset,
			rotation,
			rl.Fade(tint, clamp(fade, 0, 1)),
		)
	}
}

// draw_story_explosion repeats a short blast with a long quiet interval so a
// static story illustration feels alive without flashing continuously.
draw_story_explosion :: proc(
	effects: ^Effect_Assets,
	center: Story_Point,
	clock: f64,
	size, alpha: f32,
	reduced_flashes := false,
) {
	cycle_seconds := 3.6
	cycle := math.mod(clock, cycle_seconds)
	active_seconds := f64(EFFECT_EXPLOSION_FRAME_COUNT) / EFFECT_EXPLOSION_FPS
	if cycle >= active_seconds do return
	frame := min(int(cycle * EFFECT_EXPLOSION_FPS), EFFECT_EXPLOSION_FRAME_COUNT - 1)
	texture := effects.explosion
	draw_alpha := alpha
	if reduced_flashes {
		texture = effects.explosion_smoke
		draw_alpha *= 0.64
	}
	draw_effect_frame(
		texture,
		EFFECT_EXPLOSION_COLUMNS,
		EFFECT_EXPLOSION_ROWS,
		EFFECT_EXPLOSION_FRAME_COUNT,
		frame,
		f32(center.x),
		f32(center.y),
		size,
		size,
		rl.Fade(rl.WHITE, clamp(draw_alpha, 0, 1)),
	)
}
