package caverace

import rl "vendor:raylib"

MAX_EFFECT_PARTICLES :: 64
MAX_SCORE_POPUPS     :: 8
MAX_BLAST_EFFECTS    :: 8
MAX_TEXTURED_PUFFS   :: 24

BLAST_FIRE_SECONDS  :: f64(EFFECT_EXPLOSION_FRAME_COUNT) / EFFECT_EXPLOSION_FPS
BLAST_TOTAL_SECONDS :: 1.55

TREASURE_TOAST_SECONDS      :: 2.2
TREASURE_TOAST_FADE_SECONDS :: 0.35

Effect_Kind :: enum {
	Explosion,
	Damage,
	Pickup,
	Treasure,
	Dust,
	Enemy,
	Victory,
}

Puff_Kind :: enum {
	Dust,
	Enemy,
}

Effect_Particle :: struct {
	active:            bool,
	x, y:              f32,
	velocity_x:        f32,
	velocity_y:        f32,
	remaining_seconds: f64,
	duration_seconds:  f64,
	kind:              Effect_Kind,
}

Score_Popup :: struct {
	active:            bool,
	x, y:              f32,
	points:            int,
	remaining_seconds: f64,
}

// Blast_Effect is the short, cosmetic center burst drawn over the legacy
// grid-shaped explosion. Its lifetime never controls damage or bomb slots.
Blast_Effect :: struct {
	active:          bool,
	x, y:            f32,
	elapsed_seconds: f64,
	duration_seconds: f64,
}

// Textured_Puff provides one expanding organic dust/slime cloud while the
// smaller Effect_Particles supply sparks and debris around it.
Textured_Puff :: struct {
	active:          bool,
	x, y:            f32,
	drift_x:         f32,
	elapsed_seconds: f64,
	duration_seconds: f64,
	start_size:      f32,
	end_size:        f32,
	rotation:        f32,
	texture_index:   int,
	kind:            Puff_Kind,
}

// Game_Effects is fixed-capacity presentation state. It never owns gameplay
// outcomes and may advance or be dropped without changing simulation state.
Game_Effects :: struct {
	particles: [MAX_EFFECT_PARTICLES]Effect_Particle,
	popups:    [MAX_SCORE_POPUPS]Score_Popup,
	blasts:    [MAX_BLAST_EFFECTS]Blast_Effect,
	puffs:     [MAX_TEXTURED_PUFFS]Textured_Puff,
	// A one-shot "TREASURE x/y" readout so a pickup's progress toward the
	// cave's total is legible without a permanent HUD counter.
	treasure_toast_remaining: f64,
	treasure_toast_collected: int,
	treasure_toast_total:     int,
}

blast_effect_slot :: proc(effects: ^Game_Effects) -> ^Blast_Effect {
	oldest_index := 0
	oldest_elapsed := effects.blasts[0].elapsed_seconds
	for &blast, index in effects.blasts {
		if !blast.active do return &blast
		if blast.elapsed_seconds > oldest_elapsed {
			oldest_index = index
			oldest_elapsed = blast.elapsed_seconds
		}
	}
	return &effects.blasts[oldest_index]
}

spawn_blast_effect :: proc(effects: ^Game_Effects, position: Grid_Position) {
	x, y := grid_position_to_screen(position)
	blast := blast_effect_slot(effects)
	blast^ = {
		active           = true,
		x                = f32(x + MAP_TILE_SIZE / 2),
		y                = f32(y + MAP_TILE_SIZE / 2),
		duration_seconds = BLAST_TOTAL_SECONDS,
	}
}

textured_puff_slot :: proc(effects: ^Game_Effects) -> ^Textured_Puff {
	oldest_index := 0
	oldest_elapsed := effects.puffs[0].elapsed_seconds
	for &puff, index in effects.puffs {
		if !puff.active do return &puff
		if puff.elapsed_seconds > oldest_elapsed {
			oldest_index = index
			oldest_elapsed = puff.elapsed_seconds
		}
	}
	return &effects.puffs[oldest_index]
}

spawn_textured_puff :: proc(
	effects: ^Game_Effects,
	gameplay: ^Gameplay,
	position: Grid_Position,
	kind: Puff_Kind,
) {
	x, y := grid_position_to_screen(position)
	puff := textured_puff_slot(effects)
	duration := 0.72
	start_size: f32 = 22
	end_size: f32 = 43
	if kind == .Enemy {
		duration = 0.86
		start_size = 25
		end_size = 46
	}
	puff^ = {
		active           = true,
		x                = f32(x + MAP_TILE_SIZE / 2),
		y                = f32(y + MAP_TILE_SIZE / 2),
		drift_x          = f32(gameplay_cosmetic_random_max(gameplay, 13) - 6),
		duration_seconds = duration,
		start_size       = start_size,
		end_size         = end_size,
		rotation         = f32(gameplay_cosmetic_random_max(gameplay, 360)),
		texture_index    = gameplay_cosmetic_random_max(gameplay, 2),
		kind             = kind,
	}
}

// effect_particle_slot returns a free slot, or the slot nearest expiry if the
// fixed pool is full, so a burst never allocates and never drops the newest
// particle in favor of one about to disappear anyway.
effect_particle_slot :: proc(effects: ^Game_Effects) -> ^Effect_Particle {
	oldest_index := 0
	oldest_remaining := effects.particles[0].remaining_seconds
	for &particle, index in effects.particles {
		if !particle.active do return &particle
		if particle.remaining_seconds < oldest_remaining {
			oldest_index = index
			oldest_remaining = particle.remaining_seconds
		}
	}
	return &effects.particles[oldest_index]
}

// score_popup_slot mirrors effect_particle_slot's recycle-oldest behavior for
// the separate, smaller popup pool.
score_popup_slot :: proc(effects: ^Game_Effects) -> ^Score_Popup {
	oldest_index := 0
	oldest_remaining := effects.popups[0].remaining_seconds
	for &popup, index in effects.popups {
		if !popup.active do return &popup
		if popup.remaining_seconds < oldest_remaining {
			oldest_index = index
			oldest_remaining = popup.remaining_seconds
		}
	}
	return &effects.popups[oldest_index]
}

// spawn_effect_burst fills count particle slots with randomized velocity and
// lifetime, drawing only from the cosmetic RNG stream so purely visual
// variation can never influence deterministic gameplay.
spawn_effect_burst :: proc(
	effects: ^Game_Effects,
	gameplay: ^Gameplay,
	x, y: f32,
	count: int,
	kind: Effect_Kind,
) {
	for _ in 0 ..< count {
		particle := effect_particle_slot(effects)
		direction_x := gameplay_cosmetic_random_max(gameplay, 201) - 100
		direction_y := gameplay_cosmetic_random_max(gameplay, 161) - 120
		duration := 0.35 + f64(gameplay_cosmetic_random_max(gameplay, 31)) / 100
		particle^ = {
			active            = true,
			x                 = x,
			y                 = y,
			velocity_x        = f32(direction_x) * 0.45,
			velocity_y        = f32(direction_y) * 0.45,
			remaining_seconds = duration,
			duration_seconds  = duration,
			kind              = kind,
		}
	}
}

spawn_grid_effect_burst :: proc(
	effects: ^Game_Effects,
	gameplay: ^Gameplay,
	position: Grid_Position,
	count: int,
	kind: Effect_Kind,
) {
	x, y := grid_position_to_screen(position)
	spawn_effect_burst(
		effects,
		gameplay,
		f32(x + MAP_TILE_SIZE / 2),
		f32(y + MAP_TILE_SIZE / 2),
		count,
		kind,
	)
}

spawn_score_popup :: proc(
	effects: ^Game_Effects,
	position: Grid_Position,
	points: int,
) {
	if points <= 0 do return
	x, y := grid_position_to_screen(position)
	popup := score_popup_slot(effects)
	popup^ = {
		active            = true,
		x                 = f32(x + 4),
		y                 = f32(y - 2),
		points            = points,
		remaining_seconds = 0.8,
	}
}

// request_game_effects translates committed gameplay events into bounded
// cosmetic state using only the separate cosmetic RNG stream.
request_game_effects :: proc(
	effects: ^Game_Effects,
	gameplay: ^Gameplay,
	ticks: ^Gameplay_Tick_Result,
	victory_started: bool,
	reduced_flashes: bool,
) {
	burst_scale := 1
	if reduced_flashes do burst_scale = 2
	for index in 0 ..< ticks.explosions_started {
		spawn_blast_effect(effects, ticks.explosion_positions[index])
		spawn_grid_effect_burst(
			effects,
			gameplay,
			ticks.explosion_positions[index],
			8 / burst_scale,
			.Explosion,
		)
	}
	destruction_effect_limit := 12
	if reduced_flashes do destruction_effect_limit = 6
	for index in 0 ..< min(ticks.destructibles_destroyed, destruction_effect_limit) {
		position := ticks.destructible_positions[index]
		spawn_textured_puff(effects, gameplay, position, .Dust)
		spawn_grid_effect_burst(
			effects,
			gameplay,
			position,
			4 / burst_scale,
			.Dust,
		)
	}
	for index in 0 ..< ticks.enemies_destroyed {
		spawn_textured_puff(effects, gameplay, ticks.enemy_destroyed_positions[index], .Enemy)
		spawn_grid_effect_burst(
			effects,
			gameplay,
			ticks.enemy_destroyed_positions[index],
			5 / burst_scale,
			.Enemy,
		)
	}
	if ticks.player_damaged {
		spawn_grid_effect_burst(
			effects,
			gameplay,
			gameplay.player.position,
			10 / burst_scale,
			.Damage,
		)
	}
	if ticks.items_collected > 0 || ticks.items_salvaged > 0 {
		spawn_grid_effect_burst(
			effects,
			gameplay,
			gameplay.player.position,
			8 / burst_scale,
			.Pickup,
		)
	}
	if ticks.treasures_collected > 0 {
		spawn_grid_effect_burst(
			effects,
			gameplay,
			gameplay.player.position,
			10 / burst_scale,
			.Treasure,
		)
		effects.treasure_toast_remaining = TREASURE_TOAST_SECONDS
		effects.treasure_toast_collected = gameplay.treasure_collected
		effects.treasure_toast_total = gameplay.treasure_total
	}

	tuning := gameplay_tuning(gameplay.difficulty)
	spawn_score_popup(
		effects,
		gameplay.player.position,
		ticks.items_collected * tuning.score_item_pickup +
			ticks.items_salvaged * tuning.score_capped_item_salvage,
	)
	spawn_score_popup(
		effects,
		gameplay.player.position,
		ticks.treasures_collected * tuning.score_treasure_pickup,
	)
	for index in 0 ..< ticks.enemies_destroyed {
		spawn_score_popup(
			effects,
			ticks.enemy_destroyed_positions[index],
			tuning.score_enemy_destroyed,
		)
	}

	if victory_started {
		victory_count := 48
		if reduced_flashes do victory_count = 24
		for _ in 0 ..< victory_count {
			x := f32(32 + gameplay_cosmetic_random_max(gameplay, WINDOW_WIDTH - 64))
			y := f32(48 + gameplay_cosmetic_random_max(gameplay, 180))
			spawn_effect_burst(effects, gameplay, x, y, 1, .Victory)
		}
	}
}

advance_game_effects :: proc(effects: ^Game_Effects, frame_seconds: f64) {
	delta := clamp(frame_seconds, 0, MAX_FRAME_DELTA_SECONDS)
	for &particle in effects.particles {
		if !particle.active do continue
		particle.x += particle.velocity_x * f32(delta)
		particle.y += particle.velocity_y * f32(delta)
		particle.velocity_y += 42 * f32(delta)
		particle.remaining_seconds = max(particle.remaining_seconds - delta, 0)
		if particle.remaining_seconds == 0 do particle.active = false
	}
	for &popup in effects.popups {
		if !popup.active do continue
		popup.y -= 18 * f32(delta)
		popup.remaining_seconds = max(popup.remaining_seconds - delta, 0)
		if popup.remaining_seconds == 0 do popup.active = false
	}
	for &blast in effects.blasts {
		if !blast.active do continue
		blast.elapsed_seconds += delta
		if blast.elapsed_seconds >= blast.duration_seconds {
			blast.active = false
		}
	}
	for &puff in effects.puffs {
		if !puff.active do continue
		puff.elapsed_seconds += delta
		if puff.elapsed_seconds >= puff.duration_seconds {
			puff.active = false
		}
	}
	effects.treasure_toast_remaining = max(effects.treasure_toast_remaining - delta, 0)
}

// draw_game_world_effects stays below the HUD and UI overlays. The original
// directional blast cells remain visible underneath, preserving an exact
// read of the damaging footprint while the center gains modern visual weight.
draw_game_world_effects :: proc(
	effects: ^Game_Effects,
	assets: ^Effect_Assets,
	reduced_flashes: bool,
) {
	for puff in effects.puffs {
		if !puff.active do continue
		progress := f32(clamp(puff.elapsed_seconds / puff.duration_seconds, 0, 1))
		size := puff.start_size + (puff.end_size - puff.start_size) * progress
		alpha := (1 - progress) * f32(0.46)
		tint := rl.Color{184, 132, 82, 255}
		if puff.kind == .Enemy {
			tint = rl.Color{86, 180, 76, 255}
			alpha = (1 - progress) * 0.42
		}
		if reduced_flashes do alpha *= 0.72
		texture := assets.smoke[puff.texture_index]
		source := rl.Rectangle {width = f32(texture.width), height = f32(texture.height)}
		destination := rl.Rectangle {
			x      = puff.x + puff.drift_x * progress,
			y      = puff.y - progress * 10,
			width  = size,
			height = size,
		}
		origin := rl.Vector2 {size / 2, size / 2}
		rl.DrawTexturePro(
			texture,
			source,
			destination,
			origin,
			puff.rotation + progress * 16,
			rl.Fade(tint, alpha),
		)
	}

	for blast in effects.blasts {
		if !blast.active do continue
		frame: int
		texture: rl.Texture
		alpha, size: f32
		if reduced_flashes {
			texture = assets.explosion_smoke
			progress := f32(clamp(blast.elapsed_seconds / BLAST_TOTAL_SECONDS, 0, 1))
			frame = min(int(progress * EFFECT_EXPLOSION_FRAME_COUNT), EFFECT_EXPLOSION_FRAME_COUNT - 1)
			alpha = 0.52 * (1 - progress * 0.65)
			size = 68 + progress * 14
		} else if blast.elapsed_seconds < BLAST_FIRE_SECONDS {
			texture = assets.explosion
			frame = min(
				int(blast.elapsed_seconds * EFFECT_EXPLOSION_FPS),
				EFFECT_EXPLOSION_FRAME_COUNT - 1,
			)
			alpha = 0.88
			size = 76
		} else {
			texture = assets.explosion_smoke
			tail_progress := f32(clamp(
				(blast.elapsed_seconds - BLAST_FIRE_SECONDS) /
					(BLAST_TOTAL_SECONDS - BLAST_FIRE_SECONDS),
				0,
				1,
			))
			frame = min(9 + int(tail_progress * 16), EFFECT_EXPLOSION_FRAME_COUNT - 1)
			alpha = (1 - tail_progress) * 0.58
			size = 76 + tail_progress * 18
		}
		draw_effect_frame(
			texture,
			EFFECT_EXPLOSION_COLUMNS,
			EFFECT_EXPLOSION_ROWS,
			EFFECT_EXPLOSION_FRAME_COUNT,
			frame,
			blast.x,
			blast.y,
			size,
			size,
			rl.Fade(rl.WHITE, alpha),
		)
	}

	for particle, particle_index in effects.particles {
		if !particle.active || particle.kind == .Victory do continue
		draw_effect_particle(particle, particle_index)
	}
}

// treasure_toast_alpha eases the readout in, holds it, then eases it back out
// over its fixed lifetime.
treasure_toast_alpha :: proc(remaining_seconds: f64) -> f32 {
	if remaining_seconds <= 0 do return 0
	if remaining_seconds > TREASURE_TOAST_SECONDS - TREASURE_TOAST_FADE_SECONDS {
		return f32((TREASURE_TOAST_SECONDS - remaining_seconds) / TREASURE_TOAST_FADE_SECONDS)
	}
	if remaining_seconds < TREASURE_TOAST_FADE_SECONDS {
		return f32(remaining_seconds / TREASURE_TOAST_FADE_SECONDS)
	}
	return 1
}

// draw_treasure_toast draws the "TREASURE x/y" readout only while its timer
// is active, using treasure_toast_alpha's fade-in/hold/fade-out envelope.
draw_treasure_toast :: proc(effects: ^Game_Effects) {
	alpha := treasure_toast_alpha(effects.treasure_toast_remaining)
	if alpha <= 0 do return
	buffer: [32]byte
	text := format_cstring(buffer[:], "TREASURE  %d/%d", effects.treasure_toast_collected, effects.treasure_toast_total)
	width := rl.MeasureText(text, 15)
	x := (WINDOW_WIDTH - width) / 2
	rl.DrawRectangle(x - 10, 6, width + 20, 20, rl.Fade(rl.BLACK, 0.55 * alpha))
	rl.DrawText(text, x, 9, 15, rl.Fade(rl.SKYBLUE, alpha))
}

effect_color :: proc(kind: Effect_Kind) -> rl.Color {
	switch kind {
	case .Explosion: return rl.ORANGE
	case .Damage:    return rl.RED
	case .Pickup:    return rl.GREEN
	case .Treasure:  return rl.SKYBLUE
	case .Dust:      return rl.Color{194, 142, 88, 255}
	case .Enemy:     return rl.Color{94, 205, 74, 255}
	case .Victory:   return rl.GOLD
	}
	return rl.WHITE
}

draw_effect_particle :: proc(particle: Effect_Particle, particle_index: int) {
	alpha := f32(clamp(
		particle.remaining_seconds / particle.duration_seconds,
		0,
		1,
	))
	x, y := i32(particle.x), i32(particle.y)
	color := rl.Fade(effect_color(particle.kind), alpha)
	switch particle.kind {
	case .Pickup:
		rl.DrawCircle(x, y, 2.5, color)
		rl.DrawLine(x - 3, y, x + 3, y, rl.Fade(rl.WHITE, alpha * 0.68))
		rl.DrawLine(x, y - 3, x, y + 3, rl.Fade(rl.WHITE, alpha * 0.68))
	case .Treasure:
		treasure_color := color
		if particle_index % 2 == 0 do treasure_color = rl.Fade(rl.GOLD, alpha)
		rl.DrawLine(x - 3, y, x + 3, y, treasure_color)
		rl.DrawLine(x, y - 3, x, y + 3, treasure_color)
		rl.DrawRectangle(x - 1, y - 1, 3, 3, rl.Fade(rl.WHITE, alpha * 0.82))
	case .Enemy:
		rl.DrawCircle(x, y, 2.5, color)
		rl.DrawRectangle(x - 1, y + 1, 3, 2, rl.Fade(rl.DARKGREEN, alpha * 0.72))
	case .Dust:
		size: i32 = 2
		if particle_index % 3 == 0 do size = 3
		rl.DrawRectangle(x, y, size, size, color)
	case .Victory:
		rl.DrawRectangle(x, y, 2, 2, color)
	case .Explosion, .Damage:
		rl.DrawRectangle(x, y, 3, 3, color)
	}
}

draw_game_effects :: proc(effects: ^Game_Effects) {
	for particle, particle_index in effects.particles {
		if !particle.active || particle.kind != .Victory do continue
		draw_effect_particle(particle, particle_index)
	}
	for popup in effects.popups {
		if !popup.active do continue
		alpha := f32(clamp(popup.remaining_seconds / 0.8, 0, 1))
		draw_ui_format(i32(popup.x), i32(popup.y), 14, rl.Fade(rl.GOLD, alpha), "+%d", popup.points)
	}
	draw_treasure_toast(effects)
}
