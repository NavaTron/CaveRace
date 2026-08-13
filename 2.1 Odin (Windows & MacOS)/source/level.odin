package caverace

import "core:fmt"
import "core:mem"
import "core:os"

Map_Grid :: [MAP_WIDTH][MAP_HEIGHT]u8

// Exact layout stored in the CaveRace 1,625-byte level files (25x13 tiles,
// 5 layers of 1 byte per tile).
Map_Data :: struct {
	background: Map_Grid,
	item:       Map_Grid,
	treasure:   Map_Grid,
	enemy:      Map_Grid,
	player:     Map_Grid,
}

#assert(size_of(Map_Data) == 1625)

// Level contains only data loaded from the original level file. Mutable player,
// enemy, and bomb state is owned by Gameplay.
Level :: struct {
	data: Map_Data,
}

// Level_Data_Error identifies the first invalid map layer found while validating
// a binary level before it replaces active data.
Level_Data_Error :: enum {
	None,
	Invalid_Background,
	Invalid_Item,
	Invalid_Treasure,
	Invalid_Enemy,
	Invalid_Player,
}

// The campaign order matches the 2.0 Windows Phone edition: an intro cave,
// five caves each in four themed sets, and a final "End" cave.
LEVEL_COUNT :: 25

LEVEL_FILENAMES :: [LEVEL_COUNT]string {
	"intro.bin",
	"forest_1.bin",
	"forest_2.bin",
	"forest_3.bin",
	"forest_4.bin",
	"forest_5.bin",
	"desert_1.bin",
	"desert_2.bin",
	"desert_3.bin",
	"desert_4.bin",
	"desert_5.bin",
	"winter_1.bin",
	"winter_2.bin",
	"winter_3.bin",
	"winter_4.bin",
	"winter_5.bin",
	"lava_1.bin",
	"lava_2.bin",
	"lava_3.bin",
	"lava_4.bin",
	"lava_5.bin",
	"lava_6.bin",
	"lava_7.bin",
	"lava_8.bin",
	"end.bin",
}

// validate_level_data checks every stored tile index before a level may replace
// active state, preventing later sprite and map accesses from leaving bounds.
validate_level_data :: proc(data: ^Map_Data) -> Level_Data_Error {
	for grid_y in 0 ..< MAP_HEIGHT {
		for grid_x in 0 ..< MAP_WIDTH {
			if data.background[grid_x][grid_y] >= TERRAIN_SPRITE_COUNT {
				return .Invalid_Background
			}
			if data.item[grid_x][grid_y] >= ITEM_SPRITE_COUNT {
				return .Invalid_Item
			}
			if data.treasure[grid_x][grid_y] >= TREASURE_SPRITE_COUNT {
				return .Invalid_Treasure
			}
			if data.enemy[grid_x][grid_y] >= ENEMY_SPRITE_COUNT {
				return .Invalid_Enemy
			}
			if data.player[grid_x][grid_y] > PLAYER_SPAWN_MARKER {
				return .Invalid_Player
			}
		}
	}
	return .None
}

// load_level resolves a numbered level beneath the selected resource root and
// is called only while Gameplay is in Load_Level.
load_level :: proc(level: ^Level, level_index: int, resource_root: string = "") -> bool {
	if level_index < 0 || level_index >= LEVEL_COUNT {
		fmt.eprintln("Invalid level index:", level_index)
		return false
	}
	level_filenames := LEVEL_FILENAMES
	path, path_ok := resource_path(
		resource_root,
		{RESOURCE_LEVEL_DIRECTORY, level_filenames[level_index]},
	)
	if !path_ok {
		fmt.eprintln("Failed to construct the level path for index:", level_index)
		return false
	}
	defer delete(path)
	return load_level_from_path(level, path)
}

// load_level_from_path reads and validates one exact legacy binary file into a
// local value, replacing the destination only after every check succeeds.
load_level_from_path :: proc(level: ^Level, path: string) -> bool {
	file, open_error := os.open(path)
	if open_error != nil {
		fmt.eprintln("Failed to open level:", path, open_error)
		return false
	}
	defer os.close(file)

	file_size, size_error := os.file_size(file)
	if size_error != nil {
		fmt.eprintln("Failed to inspect level:", path, size_error)
		return false
	}

	if file_size != i64(size_of(Map_Data)) {
		fmt.eprintf(
			"Level %s has an invalid size: expected %d bytes, got %d.\n",
			path,
			size_of(Map_Data),
			file_size,
		)
		return false
	}

	data: Map_Data
	data_bytes := mem.byte_slice(&data, size_of(data))
	bytes_read, read_error := os.read_full(file, data_bytes)
	if read_error != nil || bytes_read != len(data_bytes) {
		fmt.eprintln("Failed to read level:", path, read_error)
		return false
	}

	if validation_error := validate_level_data(&data); validation_error != .None {
		fmt.eprintln("Level contains invalid map data:", path, validation_error)
		return false
	}

	level^ = Level {data = data}
	return true
}
