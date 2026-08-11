extends GutTest
## GameEnums verification — Sprint 1 task 1-4 (QA plan ENUM-1..5).
## Architecture §4.2 is the canonical table; this test pins names, member
## order, and the PERSUADED rename.

## §4.2 table — member order is significant (catches reordering).
const EXPECTED_ENUMS := {
	"BeliefState": ["STEADFAST", "OPEN", "WAVERING", "CONVERTED"],
	"DialogueApproach": ["GRIEF", "AMBITION", "DOUBT", "FEAR"],
	"ConversionOutcome": ["PERSUADED", "SOFTENED", "RESISTED", "HARDENED"],
	"TraitRarity": ["COMMON", "UNCOMMON", "RARE"],
	"RelationshipType": ["SPOUSE", "MENTOR", "CLOSE_FRIEND", "NEIGHBOR", "KIN", "RIVAL", "EMPLOYER"],
	"NPCArchetype": ["LABORER", "ELDER", "MERCHANT", "SOLDIER", "SCHOLAR", "WIDOW", "NOBLE"],
	"OutcomeCaller": ["PLAYER", "RIVAL", "FAITH_SPREAD"],
	"AlignmentSignal": ["POSITIVE", "NEUTRAL", "NEGATIVE"],
	"GSMState": ["UNINITIALIZED", "IDLE", "IN_SESSION", "TURN_ADVANCING", "VILLAGE_WON", "VILLAGE_LOST"],
	"SwipeDirection": ["RIGHT", "UP", "LEFT", "DOWN"],
}

func test_enum_1_script_compiles_headless() -> void:
	# ENUM-1: script compiles headless (load check).
	var script := load("res://src/core/game_enums.gd")
	assert_not_null(script, "game_enums.gd must load")
	assert_true(script is GDScript, "game_enums.gd must be a GDScript")

func test_enum_2_all_ten_enum_names_present() -> void:
	# ENUM-2: all 10 enum names present.
	var enums := _all_enums()
	assert_eq(enums.size(), 10, "exactly 10 enums")
	for enum_name in EXPECTED_ENUMS:
		assert_true(enums.has(enum_name), "missing enum: " + enum_name)

func test_enum_3_values_match_architecture_s4_2() -> void:
	# ENUM-3: every enum VALUE matches the §4.2 table (parameterized per enum;
	# catches reordering).
	var enums := _all_enums()
	for enum_name in EXPECTED_ENUMS:
		var dict: Dictionary = enums[enum_name]
		assert_eq(dict.keys(), EXPECTED_ENUMS[enum_name],
			enum_name + " members/order must match §4.2")
		var values: Array = dict.values()
		for i in values.size():
			assert_eq(values[i], i,
				enum_name + "." + str(dict.keys()[i]) + " value must be " + str(i))

func test_enum_4_persuaded_present() -> void:
	# ENUM-4: GameEnums.ConversionOutcome.PERSUADED exists (PERSUADED rename).
	var dict: Dictionary = GameEnums.ConversionOutcome
	assert_true(dict.has("PERSUADED"), "ConversionOutcome must contain PERSUADED")
	assert_eq(dict["PERSUADED"], 0, "PERSUADED is the first outcome")

func test_enum_5_no_converted_collision() -> void:
	# ENUM-5: ConversionOutcome contains NO `CONVERTED` member (no-collision
	# rule, NPC CS Rule 9 / ADR-0002).
	var dict: Dictionary = GameEnums.ConversionOutcome
	assert_false(dict.has("CONVERTED"),
		"ConversionOutcome must NOT contain CONVERTED (collides with BeliefState.CONVERTED)")

func _all_enums() -> Dictionary:
	return {
		"BeliefState": GameEnums.BeliefState,
		"DialogueApproach": GameEnums.DialogueApproach,
		"ConversionOutcome": GameEnums.ConversionOutcome,
		"TraitRarity": GameEnums.TraitRarity,
		"RelationshipType": GameEnums.RelationshipType,
		"NPCArchetype": GameEnums.NPCArchetype,
		"OutcomeCaller": GameEnums.OutcomeCaller,
		"AlignmentSignal": GameEnums.AlignmentSignal,
		"GSMState": GameEnums.GSMState,
		"SwipeDirection": GameEnums.SwipeDirection,
	}
