package caverace

Medal :: enum {
	None,
	Bronze,
	Silver,
	Gold,
}

Level_Stats :: struct {
	elapsed_ticks:    int,
	start_score:      int,
	hits:             int,
	enemies_destroyed: int,
}

Level_Result :: struct {
	level_index:        int,
	elapsed_ticks:      int,
	par_ticks:          int,
	treasure_collected: int,
	treasure_total:     int,
	enemies_destroyed:  int,
	all_treasure:       bool,
	under_par:          bool,
	score_delta:        int,
	final_score:        int,
	medal:              Medal,
	celebration_sprite: int,
}

medal_for_conditions :: proc(all_treasure, under_par: bool) -> Medal {
	if all_treasure && under_par do return .Gold
	if all_treasure || under_par do return .Silver
	return .Bronze
}

medal_label :: proc(medal: Medal) -> cstring {
	switch medal {
	case .None:   return "NONE"
	case .Bronze: return "BRONZE"
	case .Silver: return "SILVER"
	case .Gold:   return "GOLD"
	}
	return ""
}

// begin_level_tracking starts a fresh per-level stats ledger, recording the
// player's current score as the baseline finalize_level_result later
// subtracts from to report this level's score delta.
begin_level_tracking :: proc(gameplay: ^Gameplay) {
	gameplay.level_stats = {start_score = gameplay.player.score}
	gameplay.level_result = {}
	gameplay.level_tracking_active = true
}

// finalize_level_result computes medal conditions, applies the level-clear
// score bonuses, and builds the exact ledger the level-result screen draws.
// Called once, exactly when the last enemy is cleared.
finalize_level_result :: proc(gameplay: ^Gameplay) {
	metadata := level_metadata(gameplay.level_index)
	all_treasure := gameplay.treasure_total > 0 &&
		gameplay.treasure_collected == gameplay.treasure_total
	par_ticks := int(metadata.par_seconds * GAMEPLAY_TICK_HZ)
	under_par := par_ticks > 0 && gameplay.level_stats.elapsed_ticks <= par_ticks
	no_damage := gameplay.level_stats.hits == 0

	apply_score_event(&gameplay.player, .Level_Won, gameplay.difficulty)
	if all_treasure do apply_score_event(&gameplay.player, .All_Treasure, gameplay.difficulty)
	if no_damage do apply_score_event(&gameplay.player, .No_Damage, gameplay.difficulty)
	if under_par do apply_score_event(&gameplay.player, .Under_Par, gameplay.difficulty)

	stats := gameplay.level_stats
	gameplay.level_result = {
		level_index          = gameplay.level_index,
		elapsed_ticks        = stats.elapsed_ticks,
		par_ticks            = par_ticks,
		treasure_collected   = gameplay.treasure_collected,
		treasure_total       = gameplay.treasure_total,
		enemies_destroyed    = stats.enemies_destroyed,
		all_treasure         = all_treasure,
		under_par            = under_par,
		final_score          = gameplay.player.score,
		medal                = medal_for_conditions(all_treasure, under_par),
		celebration_sprite   = gameplay_cosmetic_random_max(gameplay, LEVEL_COMPLETE_SPRITE_COUNT),
	}
	gameplay.level_result.score_delta =
		gameplay.level_result.final_score - stats.start_score
}
