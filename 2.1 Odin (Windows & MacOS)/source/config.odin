package caverace

WINDOW_WIDTH  :: 800
WINDOW_HEIGHT :: 480
WINDOW_TITLE  :: "CaveRace 2"

GAMEPLAY_TICK_HZ             :: 60
GAMEPLAY_TICK_SECONDS        :: 1.0 / f64(GAMEPLAY_TICK_HZ)
MAX_FRAME_DELTA_SECONDS      :: 0.25
MAX_GAMEPLAY_TICKS_PER_FRAME :: 15

TARGET_RENDER_FPS :: 60

// 25x13 tiles at 0,0 fills the window edge-to-edge; unlike 1.5, there is no
// border frame, so the status bar (gameplay_hud.odin) owns the leftover strip
// below the map instead of a margin around it.
MAP_WIDTH     :: 25
MAP_HEIGHT    :: 13
MAP_TILE_SIZE :: 32
MAP_OFFSET_X  :: 0
MAP_OFFSET_Y  :: 0

// Tile_Theme is game data selected for each loaded level. The renderer maps
// the value to a texture, but simulation state does not depend on raylib.
Tile_Theme :: enum {
	Desert,
	Forest,
	Lava,
	Winter,
}

// Fixed content counts describe the shipped level and sprite data.
TERRAIN_SPRITE_COUNT  :: 50
ITEM_SPRITE_COUNT     :: 13
TREASURE_SPRITE_COUNT :: 7
ENEMY_SPRITE_COUNT    :: 15
PLAYER_SPRITE_SIZE    :: 64
PLAYER_SPRITE_COUNT   :: 24
PLAYER_RENDER_SIZE    :: 48
BOMB_SPRITE_COUNT     :: 17
TOOLS_SPRITE_COUNT    :: 4

#assert(MAP_OFFSET_X * 2 + MAP_WIDTH * MAP_TILE_SIZE == WINDOW_WIDTH)
#assert(MAP_OFFSET_Y + MAP_HEIGHT * MAP_TILE_SIZE <= WINDOW_HEIGHT)
