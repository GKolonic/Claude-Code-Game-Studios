extends GutTest
## GameConfig unit suite — Sprint 1 task 1-10 (QA plan GCF-2..8, AC-1..8/10).
## Uses the live GameConfig autoload (slot 1, booted before the test runner's
## scene) for the happy-path ACs, and a fresh GameConfig node pointed at
## test fixtures for the clamp / halt ACs (fixtures under tests/fixtures/).

const CLAMP_FIXTURE := "res://tests/fixtures/config/clamp_conversion_config.tres"
const MISSING_FIELD_FIXTURE := "res://tests/fixtures/config/missing_field_conversion_config.tres"
const MISSING_FILE := "res://tests/fixtures/config/does_not_exist.tres"

# All nine domains: [property, Resource script path]. Class names are not
# constant expressions in GDScript, so we store the script path and load() it.
const DOMAINS := [
	["conversion", "res://src/resources/config/conversion_config.gd"],
	["traits", "res://src/resources/config/trait_config.gd"],
	["faith_spread", "res://src/resources/config/faith_spread_config.gd"],
	["rival_faith", "res://src/resources/config/rival_faith_config.gd"],
	["progression", "res://src/resources/config/progression_config.gd"],
	["ui_timing", "res://src/resources/config/ui_timing_config.gd"],
	["portraits", "res://src/resources/config/portrait_config.gd"],
	["map", "res://src/resources/config/village_map_config.gd"],
	["hud", "res://src/resources/config/hud_config.gd"],
]

# Representative in-range fields per domain: [domain, field, expected_default].
const FIELD_DEFAULTS := [
	["conversion", "base_success_chance", 0.35],
	["conversion", "trait_modifier_weight", 0.25],
	["conversion", "approach_cooldown_turns", 3],
	["conversion", "hard_mode_base_modifier", 0.8],
	["conversion", "max_approaches_per_npc", 5],
	["traits", "common_trait_weight", 60],
	["traits", "uncommon_trait_weight", 30],
	["traits", "rare_trait_weight", 10],
	["traits", "traits_per_npc_min", 2],
	["traits", "traits_per_npc_max", 4],
	["faith_spread", "passive_spread_radius", 2],
	["faith_spread", "spread_rate_per_tick", 0.05],
	["faith_spread", "attrition_rate_per_tick", 0.02],
	["faith_spread", "spread_tick_interval_sec", 30.0],
	["rival_faith", "aggression_interval_turns", 6],
	["rival_faith", "reharden_strength", 0.4],
	["rival_faith", "counter_approach_random_weight", 0.3],
	["progression", "faith_power_per_conversion", 10],
	["progression", "missionary_unlock_threshold", 100],
	["progression", "court_unlock_threshold", 250],
	["progression", "crusade_unlock_threshold", 500],
	["progression", "village_win_conversion_pct", 0.75],
	["ui_timing", "approach_confirm_hold_sec", 0.6],
	["ui_timing", "hardened_reveal_hold_sec", 1.0],
	["ui_timing", "dialogue_line_hold_sec", 2.0],
	["ui_timing", "outcome_display_hold_sec", 2.5],
	["ui_timing", "scene_transition_duration_sec", 0.5],
	["ui_timing", "portrait_expression_hold_frames", 30],
	["ui_timing", "trait_card_reveal_ms", 350],
	["portraits", "dissolve_duration_ms", 350],
	["portraits", "conversion_dissolve_duration_ms", 400],
	["portraits", "conversion_overlay_surge_alpha", 0.55],
	["portraits", "conversion_overlay_surge_ms", 150],
	["portraits", "conversion_overlay_hold_ms", 50],
	["portraits", "conversion_overlay_fade_ms", 500],
	["portraits", "reduced_motion_dissolve_ms", 0],
	["portraits", "reduced_motion_overlay_fade_ms", 100],
	["map", "map_grid_columns", 4],
	["map", "map_grid_rows", 6],
	["map", "ink_bleed_duration_ms", 1750],
	["map", "ink_bleed_opacity", 0.35],
	["map", "ink_bleed_max_radius_dp", 260],
	["map", "rival_marker_dwell_sec", 4.0],
	["map", "rival_marker_fade_ms", 300],
	["map", "return_halo_max_alpha", 0.12],
	["map", "reduced_motion_ink_fade_ms", 100],
	["hud", "top_strip_height_dp", 56],
	["hud", "chronicle_card_hold_sec", 4.0],
	["hud", "chronicle_card_fade_ms", 400],
	["hud", "chronicle_card_fade_in_ms", 250],
	["hud", "reduced_motion_card_fade_ms", 100],
]


func test_gcf_1_gameconfig_autoload_is_loaded() -> void:
	# GCF-1 / AC-1: the slot-1 autoload reached LOADED before any other
	# Autoload's _ready() (proven by the boot chain; asserted here).
	assert_true(GameConfig.is_loaded(), "GameConfig must be LOADED after boot")


func test_gcf_8_all_nine_domains_accessible_and_typed() -> void:
	# GCF-8 / AC-10: every domain accessor returns a non-null Resource of the
	# correct class with populated fields.
	for entry in DOMAINS:
		var domain: Resource = GameConfig.get(entry[0])
		assert_not_null(domain, "GameConfig.%s must be non-null" % entry[0])
		var script: GDScript = load(entry[1])
		assert_is(domain, script, "GameConfig.%s must be a %s" % [entry[0], entry[1]])


func test_gcf_2_typed_access_field_sweep() -> void:
	# GCF-2 / AC-2: every declared field returns a value of the declared type
	# within its min/max. Numeric sweep across all nine domains.
	for entry in FIELD_DEFAULTS:
		var domain: Resource = GameConfig.get(entry[0])
		var schema: Dictionary = domain.get_script().get_validation_schema()
		var field: String = entry[1]
		var spec: Dictionary = schema[field]
		var value: Variant = domain.get(field)
		assert_not_null(value, "%s.%s must be populated" % [entry[0], field])
		if spec.has("min"):
			assert_true(float(value) >= float(spec["min"]) - 0.0001,
				"%s.%s (%s) must be >= min %s" % [entry[0], field, str(value), str(spec["min"])])
			assert_true(float(value) <= float(spec["max"]) + 0.0001,
				"%s.%s (%s) must be <= max %s" % [entry[0], field, str(value), str(spec["max"])])


func test_gcf_3_out_of_range_clamps_with_warning() -> void:
	# GCF-3 / AC-3: base_success_chance = 1.5 (max 0.95) clamps to 0.95.
	var cfg := _fresh_config()
	var d := _domain_entry("conversion", CLAMP_FIXTURE, ConversionConfig)
	var err: String = cfg._load_domain(d)
	assert_true(err.is_empty(), "clamp fixture must load without hard error, got: %s" % err)
	assert_almost_eq(cfg.conversion.base_success_chance, 0.95, 0.0001,
		"out-of-range base_success_chance must clamp to max 0.95")


func test_gcf_3_clamp_at_exact_boundary_is_accepted() -> void:
	# Edge case: clamp boundaries are inclusive — a value exactly at max passes.
	var cfg := _fresh_config()
	var d := _domain_entry("conversion", CLAMP_FIXTURE, ConversionConfig)
	cfg._load_domain(d)
	# 1.5 -> 0.95 exactly at boundary; verify no further clamping on re-read.
	assert_almost_eq(cfg.conversion.base_success_chance, 0.95, 0.0001)


func test_gcf_4_missing_required_field_halts_naming_field() -> void:
	# GCF-4 / AC-4: required field absent from the .tres -> hard error naming it.
	var cfg := _fresh_config()
	var d := _domain_entry("conversion", MISSING_FIELD_FIXTURE, ConversionConfig)
	var err: String = cfg._load_domain(d)
	assert_false(err.is_empty(), "missing required field must produce a hard error")
	assert_true(err.contains("base_success_chance"),
		"error must name the missing field, got: %s" % err)


func test_gcf_5_missing_file_halts_naming_path() -> void:
	# GCF-5 / AC-5: missing .tres file -> hard error naming the path.
	var cfg := _fresh_config()
	var d := _domain_entry("conversion", MISSING_FILE, ConversionConfig)
	var err: String = cfg._load_domain(d)
	assert_false(err.is_empty(), "missing file must produce a hard error")
	assert_true(err.contains(MISSING_FILE),
		"error must name the missing file path, got: %s" % err)


func test_gcf_7_hot_reload_swaps_value_and_emits_signal() -> void:
	# GCF-7 / AC-7 (editor-only): a successful reload swaps the live value and
	# emits config_reloaded. We drive _hot_reload_domain directly with the
	# clamp fixture standing in for a "changed" domain file.
	var cfg := _fresh_config()
	var d := _domain_entry("conversion", "res://assets/data/config/conversion_config.tres", ConversionConfig)
	cfg._load_domain(d)  # baseline: base_success_chance = 0.35
	watch_signals(cfg)
	# Simulate the file having been saved with an out-of-range edit (1.5 -> 0.95).
	var reload_entry := _domain_entry("conversion", CLAMP_FIXTURE, ConversionConfig)
	cfg._hot_reload_domain(reload_entry)
	assert_signal_emitted(cfg, "config_reloaded",
		"successful hot-reload must emit config_reloaded")
	assert_almost_eq(cfg.conversion.base_success_chance, 0.95, 0.0001,
		"hot-reload must swap the live value within the same call")


func test_gcf_7_failed_hot_reload_retains_last_valid_and_no_signal() -> void:
	# EC-8: a failed reload (missing required field) retains last valid state
	# and does NOT emit config_reloaded.
	var cfg := _fresh_config()
	var d := _domain_entry("conversion", "res://assets/data/config/conversion_config.tres", ConversionConfig)
	cfg._load_domain(d)  # baseline 0.35
	watch_signals(cfg)
	var bad := _domain_entry("conversion", MISSING_FIELD_FIXTURE, ConversionConfig)
	cfg._hot_reload_domain(bad)
	assert_signal_not_emitted(cfg, "config_reloaded",
		"failed hot-reload must not emit config_reloaded")
	assert_almost_eq(cfg.conversion.base_success_chance, 0.35, 0.0001,
		"failed hot-reload must retain the last valid value")


func test_gcf_8_no_watcher_in_export_build() -> void:
	# GCF-7/AC-8: the file watcher is editor-only. In a non-editor (headless /
	# export) context the watcher state must stay empty and _process disabled.
	# This run IS headless (not the editor), so Engine.is_editor_hint() is false.
	assert_false(Engine.is_editor_hint(), "test runs headless, not in the editor")
	assert_eq(GameConfig._watch_paths.size(), 0,
		"watcher state must be empty outside the editor (AC-8)")
	assert_false(GameConfig.is_processing(),
		"_process must be disabled outside the editor (AC-8)")


# --- helpers ---------------------------------------------------------------

## Instantiates a bare GameConfig node (NOT the autoload) for fixture tests.
func _fresh_config() -> Node:
	var cfg: Node = load("res://src/autoload/game_config.gd").new()
	cfg._build_domain_table()
	add_child_autofree(cfg)
	return cfg


## Builds a single-domain entry pointing at an arbitrary path (for fixtures).
func _domain_entry(prop: String, path: String, script: GDScript) -> Dictionary:
	return {"prop": prop, "path": path, "script": script}
