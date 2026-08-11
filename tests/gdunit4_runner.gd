extends "res://addons/gut/gut_cmdln.gd"
## Headless GUT runner — Sprint 1 task 1-5 (QA GUT-1..2).
##
## Thin subclass of GUT's official command-line entry point (v9.6.1 — the
## version verified against Godot 4.6; v9.7.1 regressed stub_params.gd, see
## tests/README.md) so the project keeps ONE canonical invocation per CI rules
## / coding standards:
##
##     godot --headless --script tests/gdunit4_runner.gd
##
## GUT reads res://.gutconfig.json (dirs, include_subdirs, prefix/suffix,
## log_level, should_exit). In headless mode GUT always exits after the run
## and returns EXIT_ERROR (nonzero) when any test fails, EXIT_OK (0) when the
## suite is green — so CI can gate on the exit code.
##
## Optional overrides (GUT CLI): pass args after `--`, e.g.
##     godot --headless --script tests/gdunit4_runner.gd -- -glog=2 -gselect=res://tests/unit/core/game_enums_test.gd
## Command-line args take precedence over .gutconfig.json (GUT option order:
## default < .gutconfig.json < command line).
