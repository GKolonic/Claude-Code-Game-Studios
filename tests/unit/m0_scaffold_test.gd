extends GutTest
## M0 scaffold structural checks — Sprint 1 task 1-3 (QA plan SCAF-1..3).
## Runs without engine scene load: reads project.godot and checks the tree.

const EXPECTED_AUTOLOADS: Array[String] = [
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

const EXPECTED_DIRS: Array[String] = [
	"src/autoload",
	"src/core",
	"src/resources",
	"src/resources/config",
	"src/systems",
	"src/scenes/map",
	"src/scenes/conversation",
	"src/scenes/hud",
	"assets/data/config",
	"assets/data/traits",
	"assets/data/dialogue",
	"assets/data/npcs",
	"assets/data/villages",
	"tests/unit",
	"tests/integration",
]

func test_scaf_1_project_godot_autoload_list_matches_adr_0001() -> void:
	# SCAF-1: project.godot parses; Autoload list matches ADR-0001 slots 1-10
	# verbatim (order-sensitive).
	var text := FileAccess.get_file_as_string("res://project.godot")
	assert_false(text.is_empty(), "project.godot must be readable")
	assert_eq(_parse_autoloads(text), EXPECTED_AUTOLOADS,
		"Autoload list must match ADR-0001 slots 1-10 verbatim (order-sensitive)")

func test_scaf_2_directory_tree_matches_architecture_s7() -> void:
	# SCAF-2: directory tree matches architecture.md §7.
	for dir in EXPECTED_DIRS:
		assert_true(DirAccess.dir_exists_absolute("res://" + dir), "missing directory: " + dir)

func test_scaf_3_gitignore_ignores_godot_cache() -> void:
	# SCAF-3: .gitignore contains `.godot/` (prevents engine-cache commits).
	var text := FileAccess.get_file_as_string("res://.gitignore")
	assert_true(text.contains(".godot/"), ".gitignore must contain .godot/")

func _parse_autoloads(project_text: String) -> Array[String]:
	var result: Array[String] = []
	var in_autoload := false
	for line in project_text.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.begins_with("["):
			in_autoload = trimmed == "[autoload]"
			continue
		if in_autoload and trimmed != "" and not trimmed.begins_with(";"):
			result.append(trimmed.split("=")[0])
	return result
