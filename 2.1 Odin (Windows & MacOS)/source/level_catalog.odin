package caverace

// Level_Metadata adds modern presentation and tuning data beside the preserved
// 1,625-byte level format. Par times and pursuit chances are initial
// Milestone 4 targets. They are intentionally generous and remain
// subject to the documented cohort balance pass; medals never gate content.
Level_Metadata :: struct {
	name:                  string,
	theme:                 Tile_Theme,
	treasure_total:         int,
	par_seconds:            f32,
	enemy_pursuit_chance:   f32,
}

// treasure_total counts come from the shipped level files; par_seconds and
// enemy_pursuit_chance ramp with campaign position and remain generous
// initial targets, subject to the documented cohort balance pass.
LEVEL_METADATA :: [LEVEL_COUNT]Level_Metadata {
	{"Intro",    .Forest,  9,  90, 0.00},
	{"Forest 1", .Forest, 10, 120, 0.00},
	{"Forest 2", .Forest,  9, 130, 0.00},
	{"Forest 3", .Forest, 18, 150, 0.00},
	{"Forest 4", .Forest, 15, 160, 0.05},
	{"Forest 5", .Forest, 13, 170, 0.05},
	{"Desert 1", .Desert,  6, 150, 0.05},
	{"Desert 2", .Desert, 16, 190, 0.10},
	{"Desert 3", .Desert,  8, 170, 0.10},
	{"Desert 4", .Desert,  8, 190, 0.10},
	{"Desert 5", .Desert, 12, 210, 0.15},
	{"Winter 1", .Winter,  6, 190, 0.15},
	{"Winter 2", .Winter, 13, 220, 0.15},
	{"Winter 3", .Winter, 12, 220, 0.20},
	{"Winter 4", .Winter,  8, 200, 0.20},
	{"Winter 5", .Winter,  5, 180, 0.20},
	{"Lava 1",   .Lava,    8, 210, 0.25},
	{"Lava 2",   .Lava,   14, 250, 0.25},
	{"Lava 3",   .Lava,   23, 300, 0.25},
	{"Lava 4",   .Lava,   14, 260, 0.30},
	{"Lava 5",   .Lava,   14, 260, 0.30},
	{"Lava 6",   .Lava,    0, 180, 0.30},
	{"Lava 7",   .Lava,    5, 220, 0.35},
	{"Lava 8",   .Lava,    5, 230, 0.35},
	{"End",      .Forest, 41, 420, 0.40},
}

#assert(len(LEVEL_METADATA) == LEVEL_COUNT)

// level_metadata looks up one cave's fixed presentation and tuning data.
// level_index must already be validated (0..<LEVEL_COUNT); callers own that
// bounds check since it comes from run-controlled state, never raw input.
level_metadata :: proc(level_index: int) -> Level_Metadata {
	assert(level_index >= 0 && level_index < LEVEL_COUNT)
	metadata := LEVEL_METADATA
	return metadata[level_index]
}
