package caverace

import rl "vendor:raylib"

// BOMB_FLASH_MAX_ALPHA caps the additive glow's peak intensity so the ticking
// bomb reads as glowing hotter, not as flashing blown-out white.
BOMB_FLASH_MAX_ALPHA :: f32(0.6)

// draw_level_tiles draws only persistent map layers. Spawn grids remain part of
// the loaded file data, while active entities are rendered separately.
draw_level_tiles :: proc(level: ^Level, terrain: rl.Texture, sprites: ^Sprite_Assets) {
	for grid_y in 0 ..< MAP_HEIGHT {
		for grid_x in 0 ..< MAP_WIDTH {
			screen_x, screen_y := grid_position_to_screen({grid_x, grid_y})

			draw_sprite(terrain, level.data.background[grid_x][grid_y], screen_x, screen_y)

			if tile := level.data.treasure[grid_x][grid_y]; tile != 0 {
				draw_sprite(sprites.treasure, tile, screen_x, screen_y)
			}
			if tile := level.data.item[grid_x][grid_y]; tile != 0 {
				draw_sprite(sprites.objects, tile, screen_x, screen_y)
			}
		}
	}
}

// draw_lava_ambience selects a small, stable subset of lava-background cells
// for low-opacity flames and heat lines. The selection depends only on grid
// position, while ui_clock animates it without touching simulation state.
draw_lava_ambience :: proc(
	level: ^Level,
	effects: ^Effect_Assets,
	clock: f64,
	reduced_flashes: bool,
) {
	max_flames := 8
	if reduced_flashes do max_flames = 4
	flames_drawn := 0
	for grid_y in 0 ..< MAP_HEIGHT {
		for grid_x in 0 ..< MAP_WIDTH {
			tile := level.data.background[grid_x][grid_y]
			if tile < 25 || tile > 49 do continue
			selector := grid_x * 19 + grid_y * 31
			if selector % 11 != 0 do continue
			x, y := grid_position_to_screen({grid_x, grid_y})
			pulse := story_effect_pulse(clock, selector % 23, 31, reduced_flashes)
			alpha := f32(0.24) + pulse * 0.12
			if reduced_flashes do alpha *= 0.68
			draw_flame_effect(
				effects.flame,
				f32(x + MAP_TILE_SIZE / 2),
				f32(y + MAP_TILE_SIZE - 3),
				7,
				15,
				clock + f64(selector) * 0.07,
				alpha,
				reduced_flashes,
			)
			line_offset := i32(pulse * 3)
			rl.DrawLine(
				x + 8 + line_offset,
				y + 8,
				x + 24 - line_offset,
				y + 8,
				rl.Fade(rl.ORANGE, alpha * 0.20),
			)
			flames_drawn += 1
			if flames_drawn >= max_flames do return
		}
	}
}

// draw_level_entities renders bombs, player, enemies, and explosion overlays in
// the legacy layer order after persistent map tiles are drawn.
draw_level_entities :: proc(
	gameplay: ^Gameplay,
	sprites: ^Sprite_Assets,
	effects: ^Effect_Assets,
	clock: f64,
	high_contrast_preview: bool,
	reduced_flashes: bool,
) {
	for &bomb in gameplay.bombs {
		preview, visible := bomb_danger_footprint(&bomb, gameplay.difficulty)
		if !visible do continue
		for cell_index in 0 ..< preview.cell_count {
			x, y := grid_position_to_screen(preview.cells[cell_index].position)
			rl.DrawRectangle(x, y, MAP_TILE_SIZE, MAP_TILE_SIZE, rl.Fade(rl.RED, 0.20))
			rl.DrawRectangleLines(x, y, MAP_TILE_SIZE, MAP_TILE_SIZE, rl.GOLD)
			if high_contrast_preview {
				for offset: i32 = 4; offset < MAP_TILE_SIZE; offset += 8 {
					rl.DrawLine(x + offset, y, x, y + offset, rl.WHITE)
					rl.DrawLine(x + MAP_TILE_SIZE, y + offset, x + offset, y + MAP_TILE_SIZE, rl.WHITE)
				}
			}
		}
	}

	for &bomb, bomb_index in gameplay.bombs {
		if !bomb.active do continue
		screen_x, screen_y := grid_position_to_screen(bomb.position)
		rl.DrawEllipse(
			screen_x + MAP_TILE_SIZE / 2,
			screen_y + MAP_TILE_SIZE - 3,
			9,
			3,
			rl.Fade(rl.BLACK, 0.26),
		)
		draw_sprite(sprites.bomb, BOMB_TICKING_SPRITE, screen_x, screen_y)
		flash := bomb_flash_alpha(bomb.fuse_ticks)
		if flash > 0 {
			// Additive blending only lights up the bomb's own opaque pixels,
			// so the fuse reads as the sprite itself glowing hotter rather
			// than a border blinking on the tile behind it.
			rl.BeginBlendMode(.ADDITIVE)
			draw_sprite(
				sprites.bomb,
				BOMB_TICKING_SPRITE,
				screen_x,
				screen_y,
				rl.Fade(rl.GOLD, flash * BOMB_FLASH_MAX_ALPHA),
			)
			rl.EndBlendMode()
		}
		draw_flame_effect(
			effects.flame,
			f32(screen_x + 20),
			f32(screen_y + 13),
			7,
			14,
			clock + f64(bomb_index) * 0.37,
			0.38 + flash * 0.34,
			reduced_flashes,
		)
	}

	player_screen_x, player_screen_y := player_screen_position(&gameplay.player)
	player_sprite := player_sprite_index(&gameplay.player)
	player_visible := contact_grace_player_visible(max(
		gameplay.player.contact_grace_ticks,
		gameplay.player.blast_grace_ticks,
	))
	if player_visible {
		draw_player_sprite(sprites.player, player_sprite, player_screen_x, player_screen_y)
	}

	for &enemy in enemy_slots(gameplay) {
		if !enemy.active do continue
		enemy_screen_x, enemy_screen_y := enemy_screen_position(&enemy)
		draw_sprite(sprites.enemy, enemy.kind, enemy_screen_x, enemy_screen_y)
	}

	// Explosion sprites overlay bombs and actors, matching the legacy draw order.
	for explosion_index in 0 ..< MAX_BOMBS {
		explosion := &gameplay.explosions[explosion_index]
		if !explosion.active do continue
		for cell_index in 0 ..< explosion.cell_count {
			cell := explosion.cells[cell_index]
			explosion_screen_x, explosion_screen_y := grid_position_to_screen(cell.position)
			sprite_index := explosion_sprite_index(cell.kind, explosion.age_step)
			draw_sprite(
				sprites.bomb,
				sprite_index,
				explosion_screen_x,
				explosion_screen_y,
			)
		}
	}
}

// draw_sprite renders one 32x32 cell from a grid-packed sprite sheet; all
// level, actor, explosion, and HUD drawing shares this helper.
// sprite_index counts cells left-to-right, then top-to-bottom, wrapping at the
// sheet's own width, matching the packing tool that produced these sheets.
// tint defaults to opaque white (the sprite's own colors, unmodified); callers
// that need a colored glow pass a translucent tint instead.
draw_sprite :: proc(texture: rl.Texture, sprite_index: u8, x, y: i32, tint: rl.Color = rl.WHITE) {
	index := i32(sprite_index)
	columns := texture.width / MAP_TILE_SIZE
	source := rl.Rectangle {
		x      = f32(index % columns) * MAP_TILE_SIZE,
		y      = f32(index / columns) * MAP_TILE_SIZE,
		width  = MAP_TILE_SIZE,
		height = MAP_TILE_SIZE,
	}
	position := rl.Vector2 {f32(x), f32(y)}
	rl.DrawTextureRec(texture, source, position, tint)
}

// draw_player_sprite renders the high-resolution animation cell slightly
// larger than one map tile, anchored at the tile's feet. The simulation and
// collision box remain exactly 32x32; only the character artwork overlaps the
// surrounding cells. A soft ground shadow makes the larger pose feel planted.
draw_player_sprite :: proc(
	texture: rl.Texture,
	sprite_index: u8,
	x, y: i32,
) {
	index := i32(sprite_index)
	size := f32(PLAYER_RENDER_SIZE)
	source := rl.Rectangle {
		x      = 0,
		y      = f32(index * PLAYER_SPRITE_SIZE),
		width  = PLAYER_SPRITE_SIZE,
		height = PLAYER_SPRITE_SIZE,
	}
	destination := rl.Rectangle {
		x      = f32(x + MAP_TILE_SIZE / 2),
		y      = f32(y + MAP_TILE_SIZE),
		width  = size,
		height = size,
	}
	origin := rl.Vector2 {size * 0.5, size}
	rl.DrawEllipse(x + MAP_TILE_SIZE / 2, y + MAP_TILE_SIZE - 3, 10, 3, rl.Fade(rl.BLACK, 0.28))
	rl.DrawTexturePro(texture, source, destination, origin, 0, rl.WHITE)
}
