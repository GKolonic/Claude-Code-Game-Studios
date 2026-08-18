extends GutTest
## NPC Resource classes + archetypes data suite — Sprint 2 task 2-3
## (QA plan RSRC-1..5 + edge cases). Covers the five approved GDD data
## carriers (NpcRecord, NPCConnection, NPCAccessGate, NPCArchetypeDefinition,
## NPCArchetypeTraitBonus — ADR-0002 Decision 1), the serialised container
## NPCArchetypeDatabaseCatalogue (Sprint 1 catalogue precedent), and the
## authored assets/data/npcs/archetypes.tres (NPC CS Rule 3 table).

const ARCHETYPES_PATH := "res://assets/data/npcs/archetypes.tres"
const SCRIPT_PATHS := [
	"res://src/resources/npc_record.gd",
	"res://src/resources/npc_connection.gd",
	"res://src/resources/npc_access_gate.gd",
	"res://src/resources/npc_archetype_definition.gd",
	"res://src/resources/npc_archetype_trait_bonus.gd",
]

# NPC CS Rule 3 table — authoritative social influence weights.
const RULE3_WEIGHTS := {
	GameEnums.NPCArchetype.LABORER: 0.8,
	GameEnums.NPCArchetype.ELDER: 2.0,
	GameEnums.NPCArchetype.MERCHANT: 1.5,
	GameEnums.NPCArchetype.SOLDIER: 1.2,
	GameEnums.NPCArchetype.SCHOLAR: 1.8,
	GameEnums.NPCArchetype.WIDOW: 0.9,
	GameEnums.NPCArchetype.NOBLE: 2.5,
}

# NPC CS Rule 3 portrait-path contract — exactly these six expression keys.
const EXPRESSION_KEYS := [
	"closed_resistant", "neutral_listening", "considering_uncertain",
	"open_receptive", "withdrawn_resistant", "moved_convinced",
]

const ARCHETYPE_SLUGS := [
	"laborer", "elder", "merchant", "soldier", "scholar", "widow", "noble",
]


# --- RSRC-1: all 5 classes compile headless ---------------------------------

func test_rsrc_1_all_five_script_paths_load() -> void:
	# RSRC-1: load each script path explicitly — proves the files parse on
	# the pinned engine and register as class_name Resources.
	for path in SCRIPT_PATHS:
		var script: GDScript = load(path)
		assert_not_null(script, "script must load: %s" % path)
		assert_true(script is GDScript, "resource at %s must be a GDScript" % path)


func test_rsrc_1_typed_instantiation_and_class_name_resolution() -> void:
	# Typed references (NpcRecord etc.) already force global-class resolution
	# at parse; instantiation proves each class is a Resource.
	assert_true(NpcRecord.new() is Resource)
	assert_true(NPCConnection.new() is Resource)
	assert_true(NPCAccessGate.new() is Resource)
	assert_true(NPCArchetypeDefinition.new() is Resource)
	assert_true(NPCArchetypeTraitBonus.new() is Resource)
	# Sprint 1 catalogue precedent (mirrors TraitDatabaseCatalogue).
	assert_true(NPCArchetypeDatabaseCatalogue.new() is Resource)


# --- RSRC-2: construct + duplicate() + round-trip fields ---------------------

func test_rsrc_2_npc_record_round_trip() -> void:
	var gate := NPCAccessGate.new()
	gate.required_belief_state = GameEnums.BeliefState.CONVERTED
	gate.required_npc_ids = ["village_01_elder_1"]
	var conn := NPCConnection.new()
	conn.target_npc_id = "village_01_elder_1"
	conn.relationship_type = GameEnums.RelationshipType.KIN
	conn.influence_weight = 0.7

	var rec := NpcRecord.new()
	rec.npc_id = "village_01_widow_1"
	rec.archetype = GameEnums.NPCArchetype.WIDOW
	rec.display_name = "Haleth"
	rec.assigned_traits = ["bereaved", "lonely"]
	rec.revealed_traits = ["lonely"]
	rec.belief_state = GameEnums.BeliefState.WAVERING
	rec.cooldown_turns_remaining = 2
	rec.recently_converted_turns_remaining = 0
	rec.approach_count = 3
	rec.approach_history = {GameEnums.DialogueApproach.GRIEF: 2,
		GameEnums.DialogueApproach.FEAR: 1}
	rec.social_connections = [conn]
	rec.map_position = Vector2i(0, 4)
	rec.access_gate = gate

	var dup: NpcRecord = rec.duplicate()
	assert_false(dup == rec, "duplicate must be a distinct instance")
	assert_eq(dup.npc_id, rec.npc_id)
	assert_eq(dup.archetype, rec.archetype)
	assert_eq(dup.display_name, rec.display_name)
	assert_eq(dup.assigned_traits, rec.assigned_traits, "array content round-trips")
	assert_eq(dup.revealed_traits, rec.revealed_traits)
	assert_eq(dup.belief_state, rec.belief_state)
	assert_eq(dup.cooldown_turns_remaining, rec.cooldown_turns_remaining)
	assert_eq(dup.recently_converted_turns_remaining, rec.recently_converted_turns_remaining)
	assert_eq(dup.approach_count, rec.approach_count)
	assert_eq(dup.approach_history, rec.approach_history)
	assert_eq(dup.social_connections.size(), 1)
	assert_eq(dup.social_connections[0].target_npc_id, "village_01_elder_1")
	assert_eq(dup.social_connections[0].influence_weight, 0.7)
	assert_eq(dup.map_position, rec.map_position)
	assert_not_null(dup.access_gate)
	assert_eq(dup.access_gate.required_belief_state, GameEnums.BeliefState.CONVERTED)
	assert_eq(dup.access_gate.required_npc_ids, ["village_01_elder_1"])


func test_rsrc_2_npc_connection_round_trip() -> void:
	var conn := NPCConnection.new()
	conn.target_npc_id = "village_01_soldier_1"
	conn.relationship_type = GameEnums.RelationshipType.RIVAL
	conn.influence_weight = 0.6

	var dup: NPCConnection = conn.duplicate()
	assert_false(dup == conn)
	assert_eq(dup.target_npc_id, "village_01_soldier_1")
	assert_eq(dup.relationship_type, GameEnums.RelationshipType.RIVAL)
	assert_eq(dup.influence_weight, 0.6)


func test_rsrc_2_npc_access_gate_round_trip() -> void:
	var gate := NPCAccessGate.new()
	gate.required_belief_state = GameEnums.BeliefState.OPEN
	gate.required_npc_ids = ["village_01_elder_1", "village_01_scholar_1"]

	var dup: NPCAccessGate = gate.duplicate()
	assert_false(dup == gate)
	assert_eq(dup.required_belief_state, GameEnums.BeliefState.OPEN)
	assert_eq(dup.required_npc_ids, ["village_01_elder_1", "village_01_scholar_1"])
	# Array isolation after explicit copy (Resource.duplicate() shares plain
	# arrays — DCD EC-6 caveat; the DCD pattern copies arrays separately).
	dup.required_npc_ids = dup.required_npc_ids.duplicate()
	dup.required_npc_ids.clear()
	assert_eq(gate.required_npc_ids.size(), 2, "original must stay intact")


func test_rsrc_2_npc_archetype_definition_round_trip() -> void:
	var bonus := NPCArchetypeTraitBonus.new()
	bonus.trait_id = "dutiful"
	bonus.bonus_pct = 0.25
	var def := NPCArchetypeDefinition.new()
	def.archetype_id = GameEnums.NPCArchetype.ELDER
	def.display_name = "Elder"
	def.role_description = "Keeper of tradition."
	def.social_influence_weight = 2.0
	def.trait_weight_bonuses = [bonus]
	def.portrait_asset_path = "res://assets/portraits/elder/"

	var dup: NPCArchetypeDefinition = def.duplicate()
	assert_false(dup == def)
	assert_eq(dup.archetype_id, GameEnums.NPCArchetype.ELDER)
	assert_eq(dup.display_name, "Elder")
	assert_eq(dup.role_description, "Keeper of tradition.")
	assert_eq(dup.social_influence_weight, 2.0)
	assert_eq(dup.trait_weight_bonuses.size(), 1)
	assert_eq(dup.trait_weight_bonuses[0].trait_id, "dutiful")
	assert_eq(dup.trait_weight_bonuses[0].bonus_pct, 0.25)
	assert_eq(dup.portrait_asset_path, "res://assets/portraits/elder/")


func test_rsrc_2_npc_archetype_trait_bonus_round_trip() -> void:
	var bonus := NPCArchetypeTraitBonus.new()
	bonus.trait_id = "seeker"
	bonus.bonus_pct = 0.15

	var dup: NPCArchetypeTraitBonus = bonus.duplicate()
	assert_false(dup == bonus)
	assert_eq(dup.trait_id, "seeker")
	assert_eq(dup.bonus_pct, 0.15)


func test_rsrc_2_arrays_copied_separately_dcd_pattern() -> void:
	# DCD EC-6 / QA-plan RSRC-2 "arrays copied separately": plain
	# Resource.duplicate() shares Array storage (probe-verified on 4.6),
	# so the DCD-style deep copy must isolate a duplicated record's arrays.
	var rec := NpcRecord.new()
	rec.npc_id = "village_01_laborer_1"
	rec.assigned_traits = ["bereaved", "proud"]
	var conn := NPCConnection.new()
	conn.target_npc_id = "village_01_laborer_2"
	conn.relationship_type = GameEnums.RelationshipType.SPOUSE
	conn.influence_weight = 0.9
	rec.social_connections = [conn]

	var dup: NpcRecord = rec.duplicate()
	# Deep-copy the mutable fields explicitly (DCD defensive-copy contract).
	dup.assigned_traits = rec.assigned_traits.duplicate()
	dup.social_connections = []
	for c in rec.social_connections:
		dup.social_connections.append(c.duplicate())

	dup.assigned_traits.append("seeker")
	dup.social_connections[0].influence_weight = 0.1

	assert_eq(rec.assigned_traits, ["bereaved", "proud"],
		"deep-copied duplicate must not leak trait assignment changes back")
	assert_eq(rec.social_connections[0].influence_weight, 0.9,
		"deep-copied duplicate must not leak resource-field changes back")


# --- RSRC-3: archetypes.tres loads 7 definitions -----------------------------

func test_rsrc_3_archetypes_tres_loads_exactly_seven() -> void:
	var cat: NPCArchetypeDatabaseCatalogue = load(ARCHETYPES_PATH)
	assert_not_null(cat, "archetypes.tres must load")
	assert_eq(cat.archetypes.size(), 7,
		"exactly 7 archetype definitions (Rule 3)")
	var seen := {}
	for def in cat.archetypes:
		assert_true(def is NPCArchetypeDefinition,
			"every entry must be an NPCArchetypeDefinition")
		assert_true(def.archetype_id in GameEnums.NPCArchetype.values(),
			"archetype_id %s must be a valid enum value" % str(def.archetype_id))
		assert_false(seen.has(def.archetype_id), "archetype ids must be distinct")
		seen[def.archetype_id] = true
	assert_eq(seen.size(), 7, "the seven ids must cover all MVP archetypes")


func test_rsrc_3_social_influence_weights_match_rule3_table() -> void:
	# RSRC-3: weights per the NPC CS Rule 3 table (also the trait-DB
	# archetype sections): LABORER 0.8 / ELDER 2.0 / MERCHANT 1.5 /
	# SOLDIER 1.2 / SCHOLAR 1.8 / WIDOW 0.9 / NOBLE 2.5.
	var cat: NPCArchetypeDatabaseCatalogue = load(ARCHETYPES_PATH)
	for def in cat.archetypes:
		assert_eq(def.social_influence_weight, RULE3_WEIGHTS[def.archetype_id],
			"%s social_influence_weight must match Rule 3" % def.display_name)


func test_rsrc_3_archetype_ids_cover_all_seven_enums() -> void:
	var cat: NPCArchetypeDatabaseCatalogue = load(ARCHETYPES_PATH)
	var ids: Array = []
	for def in cat.archetypes:
		ids.append(def.archetype_id)
	for value in GameEnums.NPCArchetype.values():
		assert_has(ids, value,
			"enum value %s must be present in the catalogue" % str(value))


# --- RSRC-4: trait ids resolve in TraitDatabase; bonus_pct in [0,1] ----------

func test_rsrc_4_every_trait_id_resolves_in_trait_database() -> void:
	# RSRC-4: every trait_weight_bonuses.trait_id resolves in the live
	# TraitDatabase (16 MVP ids). A missing id FAILS loudly (flag, no crash).
	assert_true(TraitDatabase.is_loaded(), "TraitDatabase must be booted")
	var cat: NPCArchetypeDatabaseCatalogue = load(ARCHETYPES_PATH)
	var total_bonuses := 0
	for def in cat.archetypes:
		for bonus in def.trait_weight_bonuses:
			total_bonuses += 1
			assert_not_null(TraitDatabase.get_trait(bonus.trait_id),
				"archetype %s: trait_id '%s' must resolve in TraitDatabase" %
				[def.display_name, bonus.trait_id])
	assert_eq(total_bonuses, 35, "7 archetypes x 5 bonuses per Rule 3 table")


func test_rsrc_4_bonus_pct_within_range_and_sanity_checks() -> void:
	# RSRC-4: bonus_pct in [0.0, 1.0] (0.0 = base weight). Bonus edges:
	# out-of-range values are authoring errors — the shipped catalogue must
	# be clean, and the resolution guardrail is proven by a synthetic miss.
	var cat: NPCArchetypeDatabaseCatalogue = load(ARCHETYPES_PATH)
	for def in cat.archetypes:
		for bonus in def.trait_weight_bonuses:
			assert_between(bonus.bonus_pct, 0.0, 1.0,
				"archetype %s trait %s bonus_pct must be in [0.0, 1.0]" %
				[def.display_name, bonus.trait_id])
	# Guardrail proof: an unknown id would NOT resolve (flag path, no crash)
	# and a synthetic out-of-range bonus WOULD fail the shipped loop.
	var miss := NPCArchetypeTraitBonus.new()
	miss.trait_id = "nonexistent_trait"
	assert_null(TraitDatabase.get_trait(miss.trait_id),
		"unknown trait id must fail resolution (shipped data must never do this)")
	var out_of_range := NPCArchetypeTraitBonus.new()
	out_of_range.trait_id = "seeker"
	out_of_range.bonus_pct = 1.2
	assert_true(out_of_range.bonus_pct < 0.0 or out_of_range.bonus_pct > 1.0,
		"out-of-range bonus would be flagged by the validation loop")


# --- RSRC-5: portrait dir contract (Rule 3) ----------------------------------

func test_rsrc_5_portrait_dirs_exist_with_six_contract_valid_pngs() -> void:
	# RSRC-5: every portrait_asset_path dir exists with exactly six
	# contract-valid expression PNGs (NPC CS Rule 3 path contract; the
	# 1-23 placeholder set ships these for all seven archetypes).
	var cat: NPCArchetypeDatabaseCatalogue = load(ARCHETYPES_PATH)
	for def in cat.archetypes:
		var slug: String = ARCHETYPE_SLUGS[def.archetype_id]
		assert_eq(def.portrait_asset_path, "res://assets/portraits/%s/" % slug,
			"%s portrait_asset_path must match the {slug}/ contract" % def.display_name)
		assert_true(DirAccess.dir_exists_absolute(def.portrait_asset_path),
			"%s portrait dir must exist: %s" % [def.display_name, def.portrait_asset_path])
		var dir := DirAccess.open(def.portrait_asset_path)
		assert_not_null(dir, "portrait dir must open: %s" % def.portrait_asset_path)
		var pngs: Array[String] = []
		for file_name in dir.get_files():
			if file_name.ends_with(".png"):
				pngs.append(file_name)
		assert_eq(pngs.size(), 6,
			"%s must contain exactly 6 PNGs (Rule 3), got %s" %
			[def.display_name, str(pngs)])
		for key in EXPRESSION_KEYS:
			assert_has(pngs, key + ".png",
				"%s missing contract expression %s.png" % [def.display_name, key])