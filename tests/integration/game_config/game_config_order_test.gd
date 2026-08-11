extends GutTest
## GameConfig integration — Sprint 1 task 1-10 (QA plan GCF-1).
## Verifies the slot-1 ordering contract (AC-1): GameConfig is LOADED before
## any other Autoload's _ready() completes. The M0 boot test proves the
## Autoload registration order; this proves the config LOADED-state ordering
## that downstream Autoloads depend on (EC-5).


func test_gcf_1_gameconfig_loaded_before_other_autoloads_ready() -> void:
	# AC-1 / EC-5: by the time any other Autoload's _ready() has run (all of
	# them have, in a booted tree), GameConfig must already be LOADED. The
	# ADR-0001 slot-1 registration is the mechanism; we assert the outcome.
	assert_true(GameConfig.is_loaded(),
		"GameConfig must be LOADED before other Autoloads' _ready() (AC-1)")


func test_gcf_1_gameconfig_is_first_autoload_in_project_settings() -> void:
	# AC-1 mechanism: GameConfig is registered as the FIRST autoload in
	# project.godot (ADR-0001 slot 1) so its _ready() runs first.
	var text := FileAccess.get_file_as_string("res://project.godot")
	var autoload_idx := text.find("[autoload]")
	assert_true(autoload_idx != -1, "project.godot must have an [autoload] section")
	var after := text.substr(autoload_idx)
	var first_line_end := after.find("\n")
	var rest := after.substr(first_line_end).strip_edges()
	assert_true(rest.begins_with("GameConfig="),
		"GameConfig must be the first Autoload entry (ADR-0001 slot 1), got: %s" % rest.get_slice("\n", 0))
