extends GutTest
## DialogueDatabase unit suite — Sprint 1 task 1-12 (Dialogue Content
## Database GDD AC-1..AC-13 + R8 audit; QA plan DCD-1..DCD-13).
##
## Happy-path ACs (DCD-1..9, DCD-13, R8-audit) run against the LIVE
## DialogueDatabase autoload (slot 3, booted with the production
## assets/data/dialogue/dialogue_database.tres at _ready()).
## Failure-path ACs (DCD-10..12) instantiate a fresh DialogueDatabase from
## the script and load the TEST-ONLY fixtures (QA plan OQ-D) — the production
## database stays pristine.

const DCD_SCRIPT := preload("res://src/autoload/dialogue_database.gd")
const FIXTURE_UNDERFILLED := "res://tests/fixtures/dialogue/underfilled.tres"
const FIXTURE_EMPTY_DESCRIPTOR := "res://tests/fixtures/dialogue/empty_descriptor.tres"

const ALL_APPROACHES := [0, 1, 2, 3]
const ALL_OUTCOMES := [0, 1, 2, 3]
const ALL_ARCHETYPES := [0, 1, 2, 3, 4, 5, 6]


func test_dcd_1_loads_at_startup_no_errors() -> void:
	# AC-1: boot load completed; is_loaded() true; no load warnings recorded
	# (a valid production DB must not warn at load).
	assert_true(DialogueDatabase.is_loaded(),
		"DialogueDatabase must be loaded after boot (AC-1)")
	assert_eq(DialogueDatabase.get_warnings().size(), 0,
		"production DB must load with zero warnings (AC-1)")


func test_dcd_2_content_audit_v_total_is_100() -> void:
	# AC-2 (automated per QA plan OQ-F) + R8: the V_total formula must hold
	# (4×3 + 4×4×3 + 7×(1+3) + 4×3 = 100) and every line pool must keep the
	# 3-per-min invariant.
	assert_eq(DialogueDatabase.audit_total_strings(), 100,
		"V_total must equal 100 per the content volume formula (AC-2/R8)")
	assert_gte(DialogueDatabase.audit_min_slot_size(), 3,
		"no slot may sit below the 3-per-min invariant (R8)")


func test_dcd_3_approach_pools_correct_for_all_four() -> void:
	# AC-3: every approach returns exactly 3 non-empty strings.
	for approach in ALL_APPROACHES:
		var pool: Array[String] = DialogueDatabase.get_approach_lines(approach)
		assert_eq(pool.size(), 3,
			"approach %d must return exactly 3 lines (AC-3)" % approach)
		for line in pool:
			assert_false(line.is_empty(), "approach %d line must be non-empty" % approach)


func test_dcd_4_outcome_pools_correct_for_all_sixteen() -> void:
	# AC-4: every approach×outcome pair returns exactly 3 non-empty strings.
	for approach in ALL_APPROACHES:
		for outcome in ALL_OUTCOMES:
			var pool: Array[String] = DialogueDatabase.get_outcome_summary(approach, outcome)
			assert_eq(pool.size(), 3,
				"outcome %d/%d must return exactly 3 lines (AC-4)" % [approach, outcome])
			for line in pool:
				assert_false(line.is_empty(), "outcome %d/%d line must be non-empty" % [approach, outcome])


func test_dcd_5_flavour_valid_for_all_seven_archetypes() -> void:
	# AC-5: every archetype returns NPCFlavourData with non-empty descriptor
	# and exactly 3 non-empty inspect lines.
	for archetype in ALL_ARCHETYPES:
		var flavour := DialogueDatabase.get_npc_flavour(archetype)
		assert_not_null(flavour, "archetype %d must resolve (AC-5)" % archetype)
		assert_false(flavour.short_descriptor.is_empty(),
			"archetype %d short_descriptor must be non-empty (AC-5)" % archetype)
		assert_eq(flavour.inspect_lines.size(), 3,
			"archetype %d inspect_lines must be exactly 3 (AC-5)" % archetype)
		for line in flavour.inspect_lines:
			assert_false(line.is_empty(), "archetype %d inspect line must be non-empty" % archetype)


func test_dcd_6_rival_pools_correct_for_all_four() -> void:
	# AC-6: every rival approach returns exactly 3 non-empty strings.
	for approach in ALL_APPROACHES:
		var pool: Array[String] = DialogueDatabase.get_rival_lines(approach)
		assert_eq(pool.size(), 3,
			"rival approach %d must return exactly 3 lines (AC-6)" % approach)
		for line in pool:
			assert_false(line.is_empty(), "rival approach %d line must be non-empty" % approach)


func test_dcd_7_invalid_approach_returns_empty_without_crash() -> void:
	# AC-7: invalid/out-of-range DialogueApproach -> empty Array, no crash.
	# -1 and 99 straddle the enum range; both must be safe.
	assert_eq(DialogueDatabase.get_approach_lines(-1), [], "out-of-range low (AC-7)")
	assert_eq(DialogueDatabase.get_approach_lines(99), [], "out-of-range high (AC-7)")


func test_dcd_8_invalid_outcome_combination_returns_empty_without_crash() -> void:
	# AC-8: invalid approach OR invalid outcome -> empty Array, no crash.
	assert_eq(DialogueDatabase.get_outcome_summary(-1, 0), [])
	assert_eq(DialogueDatabase.get_outcome_summary(0, 99), [])
	assert_eq(DialogueDatabase.get_outcome_summary(99, 99), [])
	assert_eq(DialogueDatabase.get_outcome_summary(-5, -5), [])


func test_dcd_9_invalid_archetype_returns_null_without_crash() -> void:
	# AC-9: invalid NPCArchetype -> null, no crash.
	assert_null(DialogueDatabase.get_npc_flavour(-1), "out-of-range low (AC-9)")
	assert_null(DialogueDatabase.get_npc_flavour(99), "out-of-range high (AC-9)")


func test_dcd_10_underfilled_slot_sets_unloaded_and_warns() -> void:
	# AC-10 (fixture OQ-D): one slot with 2 lines -> is_loaded() false and a
	# warning identifies the under-filled slot (GRIEF) by name (EC-1).
	var db = DCD_SCRIPT.new()
	db._load_from(FIXTURE_UNDERFILLED)
	assert_false(db.is_loaded(), "under-filled DB must not load (AC-10)")
	var joined: String = " | ".join(db.get_warnings())
	assert_true(joined.contains("GRIEF"),
		"warning must identify the under-filled slot GRIEF (AC-10): %s" % joined)
	db.free()


func test_dcd_11_getters_safe_when_unloaded() -> void:
	# AC-11: with is_loaded() false, every get_* returns its empty/null
	# default without crashing (matching the invalid-input contracts).
	var db = DCD_SCRIPT.new()
	db._load_from(FIXTURE_UNDERFILLED)
	assert_false(db.is_loaded())
	assert_eq(db.get_approach_lines(GameEnums.DialogueApproach.GRIEF), [])
	assert_eq(db.get_outcome_summary(GameEnums.DialogueApproach.GRIEF,
		GameEnums.ConversionOutcome.PERSUADED), [])
	assert_null(db.get_npc_flavour(GameEnums.NPCArchetype.ELDER))
	assert_eq(db.get_rival_lines(GameEnums.DialogueApproach.FEAR), [])
	db.free()


func test_dcd_12_empty_descriptor_warns_but_returns_struct() -> void:
	# AC-12 (fixture OQ-D): empty short_descriptor is NOT an under-fill —
	# the DB stays loaded, get_npc_flavour() returns the struct (not null)
	# and a warning names the archetype (EC-2).
	var db = DCD_SCRIPT.new()
	db._load_from(FIXTURE_EMPTY_DESCRIPTOR)
	assert_true(db.is_loaded(), "empty descriptor must not unload the DB (AC-12)")
	var flavour := db.get_npc_flavour(GameEnums.NPCArchetype.ELDER)
	assert_not_null(flavour, "struct must be returned despite empty descriptor (AC-12)")
	assert_eq(flavour.short_descriptor, "", "fixture blanks ELDER's descriptor")
	var joined: String = " | ".join(db.get_warnings())
	assert_true(joined.contains("ELDER"),
		"warning must name the archetype (AC-12): %s" % joined)
	db.free()


func test_dcd_13_get_npc_flavour_returns_copy_not_shared_ref() -> void:
	# AC-13 (EC-6): mutating the first returned object must not affect a
	# second call — both short_descriptor and the inspect_lines array are
	# isolated copies.
	var first := DialogueDatabase.get_npc_flavour(GameEnums.NPCArchetype.ELDER)
	var original_descriptor := first.short_descriptor
	first.short_descriptor = "corrupted by consuming system"
	first.inspect_lines.append("injected by consuming system")
	var second := DialogueDatabase.get_npc_flavour(GameEnums.NPCArchetype.ELDER)
	assert_eq(second.short_descriptor, original_descriptor,
		"second call must return the original short_descriptor (AC-13)")
	assert_eq(second.inspect_lines.size(), 3,
		"second call must not see mutated/injected inspect lines (AC-13)")
	assert_false(second.inspect_lines.has("injected by consuming system"))


func test_dcd_api_accessors_return_lines_not_shared_arrays() -> void:
	# Defensive-copy contract: mutating a returned pool must not corrupt the
	# shared store (read-only registry, GDD Core Rule 1).
	var pool: Array[String] = DialogueDatabase.get_approach_lines(GameEnums.DialogueApproach.DOUBT)
	pool.clear()
	assert_eq(DialogueDatabase.get_approach_lines(GameEnums.DialogueApproach.DOUBT).size(), 3,
		"clearing a returned pool must not corrupt the database")


func test_r8_no_slot_below_three_per_min_across_production_db() -> void:
	# R8 audit via accessors: every pool served by the accessors is exactly 3
	# (the minimum at MVP) — no slot below the invariant anywhere.
	for approach in ALL_APPROACHES:
		assert_eq(DialogueDatabase.get_approach_lines(approach).size(), 3)
		assert_eq(DialogueDatabase.get_rival_lines(approach).size(), 3)
	for approach in ALL_APPROACHES:
		for outcome in ALL_OUTCOMES:
			assert_eq(DialogueDatabase.get_outcome_summary(approach, outcome).size(), 3)
	for archetype in ALL_ARCHETYPES:
		assert_eq(DialogueDatabase.get_npc_flavour(archetype).inspect_lines.size(), 3)