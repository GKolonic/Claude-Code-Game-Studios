extends GutTest
## M0 boot test — Sprint 1 task 1-6 (QA plan BOOT-1..4).
## Verifies the ADR-0001 autoload chain boots headless with no null-refs and
## that GSM's deferred _connect_signals fires only after DCS exists.
##
## Note on harness: when GUT runs, the project's Autoloads are registered on
## the SceneTree root in project.godot order, so each stub's _ready() asserts
## already ran (and would have aborted boot on failure) before these tests
## execute. These tests re-verify presence/connections explicitly.

const AUTOLOAD_NAMES: Array[String] = [
	"GameConfig",
	"TraitDatabase",
	"DialogueDatabase",
	"MobileTouchFramework",
	"NPCRegistry",
	"ConversionLogicEngine",
	"DialogueConversionSystem",
	"GameStateManager",
	"RivalFaithSystem",
	"SaveLoadSystem",
]

func test_boot_1_all_autoloads_instantiate() -> void:
	# BOOT-1: headless launch boots with no null-refs; all 10 stub Autoloads
	# instantiate on the root in ADR-0001 order.
	for name in AUTOLOAD_NAMES:
		assert_not_null(get_node_or_null("/root/" + name),
			name + " must be an Autoload at /root/" + name)

func test_boot_2_autoload_dependencies_resolve() -> void:
	# BOOT-2: every Autoload asserts its dependencies resolve. Each stub's
	# _ready() assert is the primary check (a failure aborts boot); re-verify
	# the explicit dependency edges from architecture §3.1 as a secondary check.
	for name in AUTOLOAD_NAMES:
		assert_not_null(get_node_or_null("/root/" + name),
			name + " must exist for dependency resolution")

	# Slot 2 (TraitDatabase) -> GameConfig.
	assert_not_null(get_node_or_null("/root/GameConfig"),
		"TraitDatabase depends on GameConfig (slot 1)")
	# Slot 3 (DialogueDatabase) -> GameConfig, TraitDatabase.
	assert_not_null(get_node_or_null("/root/TraitDatabase"),
		"DialogueDatabase depends on TraitDatabase (slot 2)")
	# Slot 5 (NPCRegistry) -> TraitDB, GameConfig, DCD enums.
	assert_not_null(get_node_or_null("/root/TraitDatabase"))
	assert_not_null(get_node_or_null("/root/DialogueDatabase"))
	# Slot 6 (CLE) -> TraitDB, NPCRegistry, GameConfig, DCD enums.
	assert_not_null(get_node_or_null("/root/NPCRegistry"))
	# Slot 7 (DCS) -> NPCRegistry, CLE, DialogueDB, TraitDB, GameConfig.
	assert_not_null(get_node_or_null("/root/ConversionLogicEngine"))
	# Slot 8 (GSM) -> NPCRegistry, GameConfig; DCS (signal-only).
	assert_not_null(get_node_or_null("/root/DialogueConversionSystem"))
	# Slot 9 (RFS) -> GSM, NPCRegistry, CLE, TraitDB, GameConfig.
	assert_not_null(get_node_or_null("/root/GameStateManager"))
	# Slot 10 (SaveLoad) -> GSM, NPCRegistry, DCS (trigger).
	assert_not_null(get_node_or_null("/root/RivalFaithSystem"))

func test_boot_3_gsm_deferred_connect_fires_after_dcs() -> void:
	# BOOT-3: GSM's deferred _connect_signals fires only after DCS exists
	# (ADR-0001). The connection existing after boot proves _connect_signals
	# ran with DCS available (a missing DCS would have asserted/errored).
	# is_connected is queried on the EMITTER (DCS); the callable is GSM's.
	assert_true(DialogueConversionSystem.is_connected("session_begun",
		GameStateManager._on_dcs_session_begun),
		"GSM must be connected to DCS.session_begun")
	assert_true(DialogueConversionSystem.is_connected("session_complete",
		GameStateManager._on_dcs_session_complete),
		"GSM must be connected to DCS.session_complete")

func test_boot_4_main_scene_instantiates() -> void:
	# BOOT-4: minimal empty main.tscn instantiates without error.
	var scene: PackedScene = load("res://src/scenes/main.tscn")
	assert_not_null(scene, "main.tscn must load")
	var instance := scene.instantiate()
	assert_not_null(instance, "main.tscn must instantiate")
	assert_eq(instance.name, "Main", "main.tscn root must be named Main")
	instance.free()
