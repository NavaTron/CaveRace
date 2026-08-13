package caverace

import "core:fmt"
import "core:os"

// Launch_Options stores the legacy compatibility switch parsed once and then
// mapped by Application to gameplay policy.
Launch_Options :: struct {
	cheats_enabled: bool,
}

// parse_launch_options recognizes the command-line switches once at startup
// and reports unknown arguments without failing the launch.
parse_launch_options :: proc() -> Launch_Options {
	options: Launch_Options

	for argument in os.args[1:] {
		switch argument {
		case "-powerblast":
			options.cheats_enabled = true
		case:
			fmt.println("Unknown argument: ", argument)
		}
	}

	return options
}

// print_launch_options reports usage and active compatibility modes after
// parsing, before platform initialization begins.
print_launch_options :: proc(options: Launch_Options) {
	if len(os.args) == 1 {
		fmt.println()
		fmt.println("Use: -powerblast for cheats, key F1 to F5.")
	}

	if options.cheats_enabled {
		fmt.println("Cheats enabled! Press F1 to F5 for powerups.")
	}
}
