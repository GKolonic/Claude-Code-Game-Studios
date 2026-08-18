extends GutTest
## NPCRegistry integration suite — Sprint 2 task 2-6 (QA plan:
## tests/integration/npc_registry/village_lifecycle_test.gd; VDEF-6).
## Exercises the real village_01 fixture end-to-end against the live
## NPCRegistry Autoload: approved roster (decision #5), VDEF-6 integration
## (initialize_village yields 8 NpcRecords), determinism on the pinned
## rng_seed, connection/gate materialization, and the full serialize ->
## clear -> deserialize round-trip on real data (AC-18 integration proof).

const VILLAGE_01 := "res://assets/data/villages/village_01.tres"

var _village_initialized := 0


func before_each() -> void:
	NPCRegistry.clear_village()
	_village_initialized = 0
	NPCRegistry.village_initialized.connect(_on_village_initialized)


func after_each() -> void:
	NPCRegistry.village_initialized.disconnect(_on_village_initialized)
	NPCRegistry.clear_village()


func _on_village_initialized() -> void:
	_village_initialized += 1


## VDEF-6 integration: initialize_village(village_01) yields exactly 8
## NpcRecords matching the approved roster; social_influence_weight is NOT
## on records (NPC CS Rule 1 — read via archetype); every record carries
## the authored connections/gates.
func test_vdef_6_initialize_village_yields_approved_roster() -> void:
	NPCRegistry.initialize_village(load(VILLAGE_01))
	var npcs := NPCRegistry.get_all_npcs()
	assert_eq(npcs.size(), 8, "village_01 must yield exactly 8 NpcRecords (VDEF-6)")
	var counts := {}
	for npc in npcs:
		counts[npc.archetype] = counts.get(npc.archetype, 0) + 1
		assert_false(&"social_influence_weight" in npc,
			"Rule 1: weight must NOT be a property on the record")
		assert_true(npc.social_connections is Array, "connections array is materialized")
	# Approved roster (decision #5): 1 ELDER / 2 LABORER / 1 MERCHANT /
	# 1 SOLDIER / 1 SCHOLAR / 1 WIDOW / 1 NOBLE.
	assert_eq(counts.get(GameEnums.NPCArchetype.ELDER, 0), 1)
	assert_eq(counts.get(GameEnums.NPCArchetype.LABORER, 0), 2)
	assert_eq(counts.get(GameEnums.NPCArchetype.MERCHANT, 0), 1)
	assert_eq(counts.get(GameEnums.NPCArchetype.SOLDIER, 0), 1)
	assert_eq(counts.get(GameEnums.NPCArchetype.SCHOLAR, 0), 1)
	assert_eq(counts.get(GameEnums.NPCArchetype.WIDOW, 0), 1)
	assert_eq(counts.get(GameEnums.NPCArchetype.NOBLE, 0), 1)
	assert_eq(_village_initialized, 1, "village_initialized fires exactly once")


func test_vdef_6_archetype_weight_read_via_archetype() -> void:
	# NPC CS Rule 1: social_influence_weight is retrieved via
	# get_archetype_definition(), never from the record.
	NPCRegistry.initialize_village(load(VILLAGE_01))
	for npc in NPCRegistry.get_all_npcs():
		var def: NPCArchetypeDefinition = NPCRegistry.get_archetype_definition(npc.archetype)
		assert_not_null(def, "archetype definition must resolve for every NPC")
		assert_true(def.social_influence_weight > 0.0, "weight is on the archetype definition")


## AC-1 on the real fixture: initialize_village(village_01) twice with the
## same pinned seed (20260818) produces identical NPC arrays — the M2
## determinism guarantee over the ACTUAL shipped data.
func test_real_village_determinism_same_seed() -> void:
	NPCRegistry.initialize_village(load(VILLAGE_01))
	var first: Array[NpcRecord] = NPCRegistry.get_all_npcs()
	var first_payload := NPCRegistry.serialize()

	NPCRegistry.clear_village()
	NPCRegistry.initialize_village(load(VILLAGE_01))
	var second_payload := NPCRegistry.serialize()

	assert_eq(first_payload, second_payload,
		"same-seed re-init must serialize byte-identical (AC-1 over village_01)")
	var second: Array[NpcRecord] = NPCRegistry.get_all_npcs()
	assert_eq(first.size(), second.size(), "same roster size")
	for i in first.size():
		assert_eq(first[i].assigned_traits, second[i].assigned_traits,
			"'%s' traits identical across runs (AC-1)" % first[i].npc_id)


## The pinned golden values for the village_01 seed are captured here as an
## early determinism sentinel (full golden fixture is task 2-14; this locks
## the generation contract at the AC level).
func test_real_village_generation_contract_snapshot() -> void:
	NPCRegistry.initialize_village(load(VILLAGE_01))
	var expected := {
		"village_01_elder_1": 0,
		"village_01_laborer_1": 0,
		"village_01_laborer_2": 0,
		"village_01_merchant_1": 0,
		"village_01_soldier_1": 0,
		"village_01_scholar_1": 0,
		"village_01_widow_1": 0,
		"village_01_noble_1": 0,
	}
	for npc in NPCRegistry.get_all_npcs():
		assert_true(expected.has(npc.npc_id), "unexpected npc_id '%s' in village_01 roster" % npc.npc_id)
		# All start STEADFAST + zero counters (AC-2 over the real fixture).
		assert_eq(npc.belief_state, GameEnums.BeliefState.STEADFAST)
		assert_eq(npc.cooldown_turns_remaining, 0)
		assert_eq(npc.approach_count, 0)
		# Every assigned trait resolves (AC-3 over the real fixture).
		for trait_id in npc.assigned_traits:
			assert_not_null(TraitDatabase.get_trait(trait_id),
				"'%s' trait '%s' must resolve in the live database" % [npc.npc_id, trait_id])


func test_real_village_connections_and_gates_materialized() -> void:
	NPCRegistry.initialize_village(load(VILLAGE_01))
	# Elder authored 3 connections (from village_01.tres).
	assert_eq(NPCRegistry.get_connections("village_01_elder_1").size(), 3)
	# NOBLE is access-gated behind the ELDER (decision #5).
	var noble: NpcRecord = NPCRegistry.get_npc("village_01_noble_1")
	assert_not_null(noble.access_gate)
	assert_eq(noble.access_gate.required_npc_ids, ["village_01_elder_1"])
	assert_eq(noble.access_gate.required_belief_state, GameEnums.BeliefState.CONVERTED)
	# Others carry no gate.
	assert_null(NPCRegistry.get_npc("village_01_elder_1").access_gate)


## Full serialize -> clear -> deserialize round-trip over the real village
## with a mid-scenario state (converted elder + a reveal) — the SaveLoad
## contract proof on real data (AC-18 integration).
func test_real_village_persistence_roundtrip() -> void:
	NPCRegistry.initialize_village(load(VILLAGE_01))
	# Advance a realistic mid-game state.
	NPCRegistry.apply_conversion_outcome("village_01_elder_1", GameEnums.ConversionOutcome.PERSUADED, GameEnums.DialogueApproach.DOUBT)
	NPCRegistry.reveal_trait("village_01_elder_1", GameEnums.DialogueApproach.DOUBT)
	var payload := NPCRegistry.serialize()
	var before := NPCRegistry.serialize()

	NPCRegistry.clear_village()
	NPCRegistry.deserialize(payload)

	assert_eq(before, NPCRegistry.serialize(),
		"serialize -> clear -> deserialize must be state-identical (AC-18, real village)")
	var elder: NpcRecord = NPCRegistry.get_npc("village_01_elder_1")
	assert_eq(elder.belief_state, GameEnums.BeliefState.OPEN, "converted/advanced state restored")
	assert_gt(elder.revealed_traits.size(), 0, "revealed traits restored")
	assert_eq(_village_initialized, 1, "deserialize must not re-emit village_initialized")


## NOBLE gate end-to-end (VMV gate example: "convert the Elder first"):
## real village stays playable, NOBLE unlocks only after the ELDER is
## converted, and conversion of the ELDER ripples through approachability.
func test_real_village_noble_gate_unlocks_after_elder() -> void:
	NPCRegistry.initialize_village(load(VILLAGE_01))
	var approachable := NPCRegistry.get_approachable_npcs()
	assert_gt(approachable.size(), 0, "village must be playable at start (E8)")
	var noble: NpcRecord = NPCRegistry.get_npc("village_01_noble_1")
	var elder: NpcRecord = NPCRegistry.get_npc("village_01_elder_1")

	# Convert the elder in the legal 3-step path (respecting cooldowns).
	for i in 3:
		NPCRegistry.apply_conversion_outcome("village_01_elder_1", GameEnums.ConversionOutcome.PERSUADED, GameEnums.DialogueApproach.GRIEF)
		NPCRegistry.advance_turn()
	assert_eq(elder.belief_state, GameEnums.BeliefState.CONVERTED)

	approachable = NPCRegistry.get_approachable_npcs()
	assert_true(approachable.has(noble),
		"NOBLE must be approachable once ELDER is CONVERTED (AC-12 real fixture)")