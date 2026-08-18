extends GutTest
## NPCRegistry unit suite — Sprint 2 task 2-6 (QA plan NPC-AC-1..21 + E1-E14).
## Exercises the full NPC Character System GDD API surface against the live
## NPCRegistry Autoload (slot 5), using synthetic VillageDefinitions for
## deterministic control plus the real village_01.tres where the AC needs
## the approved roster (decisions #5).
##
## HOW IT WORKS: the registry is a live Autoload; tests drive it through
## initialize_village()/deserialize() and read records via the typed API.
## Determinism is explicit: every synthetic VillageDefinition pins rng_seed.
## AC-4's statistical separation uses 100 seeded village runs (bounded cost,
## deterministic seeds — QA plan OQ-QA1).
##
## NOTE on AC-10/11/12 gate wording: Rule 6 defines exactly three gates
## (cooldown, max approaches, access gate). There is NO "fully revealed" gate
## in the GDD, despite the QA-plan shorthand; tests follow the GDD.

const VILLAGE_01 := "res://assets/data/villages/village_01.tres"

var _state_changed: Array = []
var _cooldown_expired: Array = []
var _trait_revealed: Array = []
var _village_initialized := 0


func before_each() -> void:
	# Fresh registry state per test (deterministic isolation).
	NPCRegistry.clear_village()
	_state_changed.clear()
	_cooldown_expired.clear()
	_trait_revealed.clear()
	_village_initialized = 0
	NPCRegistry.npc_state_changed.connect(_on_state_changed)
	NPCRegistry.npc_cooldown_expired.connect(_on_cooldown_expired)
	NPCRegistry.trait_revealed.connect(_on_trait_revealed)
	NPCRegistry.village_initialized.connect(_on_village_initialized)


func after_each() -> void:
	NPCRegistry.npc_state_changed.disconnect(_on_state_changed)
	NPCRegistry.npc_cooldown_expired.disconnect(_on_cooldown_expired)
	NPCRegistry.trait_revealed.disconnect(_on_trait_revealed)
	NPCRegistry.village_initialized.disconnect(_on_village_initialized)
	NPCRegistry.clear_village()


func _on_state_changed(npc_id: String, old_state, new_state) -> void:
	_state_changed.append([npc_id, old_state, new_state])


func _on_cooldown_expired(npc_id: String) -> void:
	_cooldown_expired.append(npc_id)


func _on_trait_revealed(npc_id: String, trait_id: String) -> void:
	_trait_revealed.append([npc_id, trait_id])


func _on_village_initialized() -> void:
	_village_initialized += 1


# --- definitions builder helpers ---------------------------------------------

## Minimal definition for a single NPC with the given archetype enum value.
func _npc_def(p_npc_id: String, p_archetype: int, p_display := "Test NPC") -> Dictionary:
	return {
		"npc_id": p_npc_id,
		"archetype": p_archetype,
		"display_name": p_display,
		"map_position": Vector2i(1, 2),
		"social_connections": [],
	}


## Builds a synthetic VillageDefinition from a list of npc_definitions.
func _village(p_defs: Array, p_seed := 20260818) -> VillageDefinition:
	var village := VillageDefinition.new()
	village.village_id = "village_01"
	village.map_art_path = "res://assets/maps/village_01/village_map.png"
	village.rng_seed = p_seed
	var defs: Array[Dictionary] = []
	for d in p_defs:
		defs.append(d)
	village.npc_definitions = defs
	return village


## Loads the real village_01 fixture.
func _real_village() -> VillageDefinition:
	return load(VILLAGE_01)


func _elder() -> Dictionary:
	return _npc_def("village_01_elder_1", GameEnums.NPCArchetype.ELDER, "Marun Blackvale")


func _widow() -> Dictionary:
	return _npc_def("village_01_widow_1", GameEnums.NPCArchetype.WIDOW, "Haleth Vale")


func _soldier() -> Dictionary:
	return _npc_def("village_01_soldier_1", GameEnums.NPCArchetype.SOLDIER, "Aldric Galeward")


# --- AC-1: determinism -------------------------------------------------------

func test_ac_1_same_seed_identical_two_calls() -> void:
	# AC-1: two initialize_village() calls on the same definition (same
	# seed) produce identical NpcRecord arrays — traits, belief states,
	# connections (VRF-1 determinism).
	var defs: Array = [_elder(), _widow(), _soldier()]
	NPCRegistry.initialize_village(_village(defs, 20260818))
	var first: Array[NpcRecord] = NPCRegistry.get_all_npcs()

	NPCRegistry.clear_village()
	NPCRegistry.initialize_village(_village(defs, 20260818))
	var second: Array[NpcRecord] = NPCRegistry.get_all_npcs()

	assert_eq(first.size(), second.size(), "both runs must register the same NPC count")
	for i in first.size():
		var a: NpcRecord = first[i]
		var b: NpcRecord = second[i]
		assert_eq(a.npc_id, b.npc_id)
		assert_eq(a.assigned_traits, b.assigned_traits,
			"AC-1: '%s' assigned_traits must match across runs" % a.npc_id)
		assert_eq(a.belief_state, b.belief_state)
		assert_eq(a.social_connections.size(), b.social_connections.size())
		for j in a.social_connections.size():
			assert_eq(a.social_connections[j].target_npc_id, b.social_connections[j].target_npc_id)


func test_ac_1_different_seed_generates_different_traits() -> void:
	# AC-1 (companion): different seeds diverge — the guarantee is
	# same-seed determinism, and distinct seeds must be able to differ
	# (protects against a bug where generation ignores the seed).
	var defs: Array = [_widow(), _soldier()]
	NPCRegistry.initialize_village(_village(defs, 111))
	var run_a: Array[NpcRecord] = NPCRegistry.get_all_npcs()
	NPCRegistry.clear_village()
	NPCRegistry.initialize_village(_village(defs, 999))
	var run_b: Array[NpcRecord] = NPCRegistry.get_all_npcs()
	# Over 2 NPCs x 2-4 traits each the chance of identical full assignments
	# across two different seeds is negligible; assert at least one record
	# differs so the seed demonstrably enters the stream.
	var all_identical := true
	for i in run_a.size():
		if run_a[i].assigned_traits != run_b[i].assigned_traits:
			all_identical = false
	assert_false(all_identical,
		"different seeds must produce different assignments at least somewhere (AC-1 companion)")


# --- AC-2: clean initial state ----------------------------------------------

func test_ac_2_initial_state_is_clean() -> void:
	# AC-2: fresh init -> STEADFAST, cooldown 0, approach_count 0,
	# revealed_traits empty for every NPC.
	NPCRegistry.initialize_village(_village([_elder(), _widow(), _soldier(), _npc_def("village_01_laborer_1", GameEnums.NPCArchetype.LABORER)], 77))
	for npc in NPCRegistry.get_all_npcs():
		assert_eq(npc.belief_state, GameEnums.BeliefState.STEADFAST,
			"'%s' must start STEADFAST (AC-2)" % npc.npc_id)
		assert_eq(npc.cooldown_turns_remaining, 0, "'%s' cooldown must start 0 (AC-2)" % npc.npc_id)
		assert_eq(npc.approach_count, 0, "'%s' approach_count must start 0 (AC-2)" % npc.npc_id)
		assert_true(npc.revealed_traits.is_empty(), "'%s' revealed_traits must start empty (AC-2)" % npc.npc_id)
		assert_eq(npc.recently_converted_turns_remaining, 0,
			"'%s' rival grace window must start 0 (Rule 5)" % npc.npc_id)


# --- AC-3: trait schema integrity --------------------------------------------

func test_ac_3_assigned_traits_are_valid_for_archetype() -> void:
	# AC-3: every assigned trait exists in TraitDatabase and is either tagged
	# for the NPC's archetype or archetype-agnostic. No invalid IDs.
	for seed in [100, 200, 300]:
		NPCRegistry.clear_village()
		NPCRegistry.initialize_village(_village([_elder(), _widow(), _soldier(),
			_npc_def("village_01_merchant_1", GameEnums.NPCArchetype.MERCHANT),
			_npc_def("village_01_scholar_1", GameEnums.NPCArchetype.SCHOLAR),
			_npc_def("village_01_noble_1", GameEnums.NPCArchetype.NOBLE)], seed))
		for npc in NPCRegistry.get_all_npcs():
			for trait_id in npc.assigned_traits:
				var trait_data: TraitData = TraitDatabase.get_trait(trait_id)
				assert_not_null(trait_data, "'%s' trait '%s' must resolve in TraitDatabase (AC-3)" % [npc.npc_id, trait_id])
				if trait_data == null:
					continue
				var slug: String = NPCRegistry.ARCHETYPE_SLUGS[npc.archetype]
				var eligible := trait_data.archetype_tags.is_empty() or trait_data.archetype_tags.has(slug)
				assert_true(eligible,
					"'%s' trait '%s' must be tagged for %s or agnostic (AC-3)" % [npc.npc_id, trait_id, slug])


# --- AC-4: statistical archetype bias ----------------------------------------

func test_ac_4_widow_bereaved_rate_beats_soldier() -> void:
	# AC-4: across 100 seeded villages (1 widow + 1 soldier each), the Widow
	# gets `bereaved` at a statistically higher rate than the Soldier.
	# Widow carries +40% bonus on bereaved (Rule 3); Soldier +0%.
	var widow_hits := 0
	var soldier_hits := 0
	for seed in 100:
		NPCRegistry.clear_village()
		var defs := [_widow(), _soldier()]
		NPCRegistry.initialize_village(_village(defs, seed + 1))
		for npc in NPCRegistry.get_all_npcs():
			if npc.npc_id == "village_01_widow_1" and npc.assigned_traits.has("bereaved"):
				widow_hits += 1
			if npc.npc_id == "village_01_soldier_1" and npc.assigned_traits.has("bereaved"):
				soldier_hits += 1
	# Statistical separation: widow rate must clearly exceed soldier rate.
	# With a +40% weight bonus the widow should land bereaved well over 20%
	# of the time; the soldier's bonus for bereaved is 0 (Rule 3 table).
	assert_gt(widow_hits, soldier_hits,
		"AC-4: Widow bereaved rate (%d/100) must exceed Soldier rate (%d/100)" % [widow_hits, soldier_hits])
	assert_gt(widow_hits, 20,
		"AC-4: Widow bereaved rate must be meaningfully above zero, got %d/100" % widow_hits)


# --- AC-5/6/7: transition table ----------------------------------------------

func test_ac_5_three_persuaded_linear_progression() -> void:
	# AC-5: PERSUADED on STEADFAST -> OPEN -> WAVERING -> CONVERTED.
	NPCRegistry.initialize_village(_village([_elder()], 42))
	var npc: NpcRecord = NPCRegistry.get_npc("village_01_elder_1")
	assert_eq(npc.belief_state, GameEnums.BeliefState.STEADFAST)

	NPCRegistry.apply_conversion_outcome("village_01_elder_1", GameEnums.ConversionOutcome.PERSUADED, GameEnums.DialogueApproach.GRIEF)
	assert_eq(npc.belief_state, GameEnums.BeliefState.OPEN, "first PERSUADED -> OPEN (AC-5)")

	NPCRegistry.apply_conversion_outcome("village_01_elder_1", GameEnums.ConversionOutcome.PERSUADED, GameEnums.DialogueApproach.GRIEF)
	assert_eq(npc.belief_state, GameEnums.BeliefState.WAVERING, "second PERSUADED -> WAVERING (AC-5)")

	NPCRegistry.apply_conversion_outcome("village_01_elder_1", GameEnums.ConversionOutcome.PERSUADED, GameEnums.DialogueApproach.GRIEF)
	assert_eq(npc.belief_state, GameEnums.BeliefState.CONVERTED, "third PERSUADED -> CONVERTED (AC-5)")
	# dagger: WAVERING->CONVERTED sets the rival grace window (Rule 5).
	assert_eq(npc.recently_converted_turns_remaining, GameConfig.rival_faith.grace_window_turns,
		"WAVERING->CONVERTED must set the rival grace window (Rule 5 dagger)")


func test_ac_6_hardened_on_steadfast_stays_floor() -> void:
	# AC-6: HARDENED on STEADFAST leaves belief STEADFAST (floor holds).
	NPCRegistry.initialize_village(_village([_soldier()], 6))
	var npc: NpcRecord = NPCRegistry.get_npc("village_01_soldier_1")
	NPCRegistry.apply_conversion_outcome("village_01_soldier_1", GameEnums.ConversionOutcome.HARDENED, GameEnums.DialogueApproach.FEAR)
	assert_eq(npc.belief_state, GameEnums.BeliefState.STEADFAST, "HARDENED on STEADFAST stays STEADFAST (AC-6)")
	# E5: cooldown + counters still update normally (the approach registered).
	assert_eq(npc.cooldown_turns_remaining, GameConfig.conversion.approach_cooldown_turns,
		"E5: cooldown must still update on a floor-no-op")
	assert_eq(npc.approach_count, 1, "E5: approach_count must still increment")
	assert_eq(_state_changed.size(), 0, "no npc_state_changed on a floor no-op (AC-16)")


func test_ac_7_persuaded_on_converted_is_terminal() -> void:
	# AC-7: PERSUADED on a CONVERTED NPC (PLAYER caller) leaves CONVERTED and
	# emits NO npc_state_changed.
	NPCRegistry.initialize_village(_village([_elder()], 42))
	var npc: NpcRecord = NPCRegistry.get_npc("village_01_elder_1")
	for i in 3:
		NPCRegistry.apply_conversion_outcome("village_01_elder_1", GameEnums.ConversionOutcome.PERSUADED, GameEnums.DialogueApproach.GRIEF)
	assert_eq(npc.belief_state, GameEnums.BeliefState.CONVERTED)

	_state_changed.clear()
	NPCRegistry.apply_conversion_outcome("village_01_elder_1", GameEnums.ConversionOutcome.PERSUADED, GameEnums.DialogueApproach.GRIEF)
	assert_eq(npc.belief_state, GameEnums.BeliefState.CONVERTED, "CONVERTED stays CONVERTED (AC-7)")
	assert_eq(_state_changed.size(), 0, "no npc_state_changed on a terminal no-op (AC-7/AC-16)")
	# e6: cooldown/counters still update on the call (approach registered),
	# but belief is untouched.
	assert_eq(npc.approach_count, 4, "approach_count increments on the call (E6)")


func test_ac_8_cooldown_and_counter_update() -> void:
	# AC-8: after any non-no-op outcome, cooldown == approach_cooldown_turns
	# and approach_count incremented by 1.
	NPCRegistry.initialize_village(_village([_widow()], 8))
	var npc: NpcRecord = NPCRegistry.get_npc("village_01_widow_1")
	assert_eq(npc.cooldown_turns_remaining, 0)
	NPCRegistry.apply_conversion_outcome("village_01_widow_1", GameEnums.ConversionOutcome.PERSUADED, GameEnums.DialogueApproach.GRIEF)
	assert_eq(npc.cooldown_turns_remaining, GameConfig.conversion.approach_cooldown_turns,
		"AC-8: cooldown must equal approach_cooldown_turns after outcome")
	assert_eq(npc.approach_count, 1, "AC-8: approach_count must increment by 1")
	# RESISTED also registers the approach (CLE Formula 3 repeat penalty needs
	# approach_history to count failed attempts).
	NPCRegistry.apply_conversion_outcome("village_01_widow_1", GameEnums.ConversionOutcome.RESISTED, GameEnums.DialogueApproach.DOUBT)
	assert_eq(npc.approach_count, 2, "RESISTED registers the approach")
	assert_eq(npc.approach_history.get(GameEnums.DialogueApproach.DOUBT, 0), 1,
		"approach_history must track RESISTED attempts (Rule 5/CLE Formula 3)")


# --- AC-9: turn ticks --------------------------------------------------------

func test_ac_9_advance_turn_decrements_cooldown_floor_zero() -> void:
	# AC-9: advance_turn() N times decrements cooldown by N (floor 0).
	NPCRegistry.initialize_village(_village([_elder()], 9))
	var npc: NpcRecord = NPCRegistry.get_npc("village_01_elder_1")
	# Force cooldown to 5 (any non-no-op outcome sets it to 3; set directly
	# to prove the tick arithmetic over a longer window).
	npc.cooldown_turns_remaining = 5
	for i in 7:  # 5 ticks clear it, 2 more must floor at 0
		NPCRegistry.advance_turn()
	assert_eq(npc.cooldown_turns_remaining, 0, "AC-9: cooldown must hit 0 after 5 ticks and stay there")
	# AC-17: exactly one cooldown-expired emission per cycle, on the tick
	# that brings it to 0.
	assert_eq(_cooldown_expired.size(), 1, "AC-17: exactly one cooldown-expired per cycle")
	assert_eq(_cooldown_expired[0], "village_01_elder_1")


func test_ac_9_grace_window_ticks_down() -> void:
	# RFS Rule 9: advance_turn also decrements the rival grace window (floor 0)
	# alongside cooldowns.
	NPCRegistry.initialize_village(_village([_elder()], 10))
	var npc: NpcRecord = NPCRegistry.get_npc("village_01_elder_1")
	# Convert to set the window.
	for i in 3:
		NPCRegistry.apply_conversion_outcome("village_01_elder_1", GameEnums.ConversionOutcome.PERSUADED, GameEnums.DialogueApproach.GRIEF)
	assert_eq(npc.recently_converted_turns_remaining, GameConfig.rival_faith.grace_window_turns)
	for i in GameConfig.rival_faith.grace_window_turns + 2:
		NPCRegistry.advance_turn()
	assert_eq(npc.recently_converted_turns_remaining, 0,
		"grace window must tick down to 0 (RFS Rule 9)")


# --- AC-10/11/12: approachability gates --------------------------------------

func test_ac_10_cooldown_gate() -> void:
	# AC-10: an NPC with cooldown > 0 does not appear in approachable list.
	NPCRegistry.initialize_village(_village([_widow()], 11))
	NPCRegistry.apply_conversion_outcome("village_01_widow_1", GameEnums.ConversionOutcome.PERSUADED, GameEnums.DialogueApproach.GRIEF)
	var npc: NpcRecord = NPCRegistry.get_npc("village_01_widow_1")
	assert_gt(npc.cooldown_turns_remaining, 0)
	var approachable := NPCRegistry.get_approachable_npcs()
	assert_eq(approachable.size(), 0, "AC-10: cooldown-gated NPC must not be approachable")
	# After the cooldown ticks off, it appears again.
	for i in GameConfig.conversion.approach_cooldown_turns:
		NPCRegistry.advance_turn()
	approachable = NPCRegistry.get_approachable_npcs()
	assert_eq(approachable.size(), 1, "AC-10: NPC must reappear once cooldown expires")
	assert_eq(approachable[0].npc_id, "village_01_widow_1")


func test_ac_11_max_approaches_gate() -> void:
	# AC-11: an NPC at max_approaches_per_npc is not approachable.
	NPCRegistry.initialize_village(_village([_soldier()], 12))
	var npc: NpcRecord = NPCRegistry.get_npc("village_01_soldier_1")
	npc.approach_count = GameConfig.conversion.max_approaches_per_npc  # direct: gate boundary
	var approachable := NPCRegistry.get_approachable_npcs()
	assert_eq(approachable.size(), 0, "AC-11: at-max-approaches NPC must not be approachable")
	# One below max IS approachable.
	npc.approach_count = GameConfig.conversion.max_approaches_per_npc - 1
	approachable = NPCRegistry.get_approachable_npcs()
	assert_eq(approachable.size(), 1, "AC-11: one-below-max NPC must be approachable")


func test_ac_12_access_gate() -> void:
	# AC-12: an NPC gated behind another not-yet-at-state NPC is not
	# approachable; once the required NPC reaches the required state it is.
	# Uses the real village_01: NOBLE gated behind ELDER at CONVERTED.
	NPCRegistry.initialize_village(_real_village())
	var approachable := NPCRegistry.get_approachable_npcs()
	for npc in approachable:
		assert_ne(npc.npc_id, "village_01_noble_1",
			"AC-12: NOBLE must NOT be approachable while ELDER isn't CONVERTED")
	# Convert the Elder (3 PERSUADED, stepping past cooldowns between).
	var elder := NPCRegistry.get_npc("village_01_elder_1")
	for i in 3:
		NPCRegistry.apply_conversion_outcome("village_01_elder_1", GameEnums.ConversionOutcome.PERSUADED, GameEnums.DialogueApproach.GRIEF)
		NPCRegistry.advance_turn()  # clear the cooldown so the next apply is legal flow
		assert_eq(elder.belief_state, GameEnums.BeliefState.CONVERTED if i == 2 else (GameEnums.BeliefState.WAVERING if i == 1 else GameEnums.BeliefState.OPEN))
	approachable = NPCRegistry.get_approachable_npcs()
	var noble_found := false
	for npc in approachable:
		if npc.npc_id == "village_01_noble_1":
			noble_found = true
	assert_true(noble_found,
		"AC-12: NOBLE must become approachable once ELDER is CONVERTED")


# --- AC-13/14/15: trait reveal ------------------------------------------------

func test_ac_13_inspect_reveals_highest_affinity_trait() -> void:
	# AC-13: trigger_inspect_reveal reveals the hidden trait with the
	# highest absolute affinity magnitude across all four approaches.
	NPCRegistry.initialize_village(_village([_widow()], 13))
	var npc: NpcRecord = NPCRegistry.get_npc("village_01_widow_1")
	# Deterministically inject a known trait set (the generation seed gives
	# us a real set; replace with a controllable one for the assertion).
	_set_assigned(npc, ["bereaved", "seeker", "proud"])
	_set_revealed(npc, [])
	var revealed: TraitData = NPCRegistry.trigger_inspect_reveal("village_01_widow_1")
	# bereaved: GRIEF +1.0, seeker: DOUBT +1.0, proud: FEAR -1.0 / AMBITION
	# +0.5 — all have abs 1.0; tie resolves by index in assigned_traits ->
	# bereaved (index 0).
	assert_not_null(revealed, "AC-13: inspect must reveal a trait")
	assert_eq(revealed.id, "bereaved", "AC-13: highest-abs trait (or first on tie) must be revealed")
	assert_eq(npc.revealed_traits, ["bereaved"], "AC-13: exactly one trait must move to revealed")
	assert_eq(_trait_revealed.size(), 1, "AC-13: trait_revealed emitted once")
	assert_eq(_trait_revealed[0], ["village_01_widow_1", "bereaved"])


func test_ac_14_dialogue_outcome_reveals_approach_trait() -> void:
	# AC-14: reveal_trait(npc_id, approach) reveals the hidden trait with the
	# highest affinity magnitude for that approach.
	NPCRegistry.initialize_village(_village([_widow()], 13))
	var npc: NpcRecord = NPCRegistry.get_npc("village_01_widow_1")
	_set_assigned(npc, ["bereaved", "seeker", "proud"])
	_set_revealed(npc, [])
	# FEAR approach: proud has FEAR -1.0 (abs 1.0) > bereaved 0.0 >
	# seeker 0.0 -> proud.
	var revealed: TraitData = NPCRegistry.reveal_trait("village_01_widow_1", GameEnums.DialogueApproach.FEAR)
	assert_not_null(revealed, "AC-14: FEAR dialogue must reveal a trait")
	assert_eq(revealed.id, "proud", "AC-14: highest FEAR-magnitude hidden trait must be revealed")
	assert_eq(npc.revealed_traits, ["proud"])


func test_ac_15_full_reveal_is_noop_no_signal() -> void:
	# AC-15: when all traits are revealed, trigger_inspect_reveal changes
	# nothing and emits NO trait_revealed signal.
	NPCRegistry.initialize_village(_village([_widow()], 13))
	var npc: NpcRecord = NPCRegistry.get_npc("village_01_widow_1")
	_set_assigned(npc, ["bereaved", "seeker"])
	_set_revealed(npc, ["bereaved", "seeker"])
	var revealed: TraitData = NPCRegistry.trigger_inspect_reveal("village_01_widow_1")
	assert_null(revealed, "AC-15: full reveal must return null (no-op)")
	assert_eq(npc.revealed_traits, ["bereaved", "seeker"], "AC-15: revealed_traits unchanged")
	assert_eq(_trait_revealed.size(), 0, "AC-15: NO trait_revealed signal on no-op (OQ-8)")


# --- AC-16/17: signals -------------------------------------------------------

func test_ac_16_npc_state_changed_exact_once_per_transition() -> void:
	# AC-16: npc_state_changed emitted exactly once per transition with the
	# correct payload; not emitted on no-op outcomes.
	NPCRegistry.initialize_village(_village([_elder()], 15))
	_state_changed.clear()
	NPCRegistry.apply_conversion_outcome("village_01_elder_1", GameEnums.ConversionOutcome.PERSUADED, GameEnums.DialogueApproach.GRIEF)
	NPCRegistry.apply_conversion_outcome("village_01_elder_1", GameEnums.ConversionOutcome.RESISTED, GameEnums.DialogueApproach.DOUBT)
	NPCRegistry.apply_conversion_outcome("village_01_elder_1", GameEnums.ConversionOutcome.PERSUADED, GameEnums.DialogueApproach.GRIEF)
	assert_eq(_state_changed.size(), 2, "AC-16: exactly 2 transitions across 3 calls (RESISTED is no-op)")
	assert_eq(_state_changed[0], ["village_01_elder_1", GameEnums.BeliefState.STEADFAST, GameEnums.BeliefState.OPEN])
	assert_eq(_state_changed[1], ["village_01_elder_1", GameEnums.BeliefState.OPEN, GameEnums.BeliefState.WAVERING])


func test_ac_17_cooldown_expired_exactly_once() -> void:
	# AC-17: npc_cooldown_expired emitted exactly once per NPC per cooldown
	# cycle, on the advance_turn() that brings cooldown to 0.
	NPCRegistry.initialize_village(_village([_widow(), _soldier()], 16))
	# Put both NPCs on cooldown.
	NPCRegistry.apply_conversion_outcome("village_01_widow_1", GameEnums.ConversionOutcome.PERSUADED, GameEnums.DialogueApproach.GRIEF)
	NPCRegistry.apply_conversion_outcome("village_01_soldier_1", GameEnums.ConversionOutcome.SOFTENED, GameEnums.DialogueApproach.DOUBT)
	_cooldown_expired.clear()
	# FIRST tick (cooldown 3 -> 2): no emission.
	NPCRegistry.advance_turn()
	assert_eq(_cooldown_expired.size(), 0, "no emission while remaining cooldown > 0")
	# SECOND tick (2 -> 1): no emission.
	NPCRegistry.advance_turn()
	assert_eq(_cooldown_expired.size(), 0, "no emission while remaining cooldown > 0")
	# THIRD tick (1 -> 0): BOTH emit.
	NPCRegistry.advance_turn()
	assert_eq(_cooldown_expired.size(), 2, "AC-17: exactly one emission per NPC on the expiry tick")
	assert_has(_cooldown_expired, "village_01_widow_1")
	assert_has(_cooldown_expired, "village_01_soldier_1")
	# FOURTH tick: cooldown already 0 — no further emission.
	NPCRegistry.advance_turn()
	assert_eq(_cooldown_expired.size(), 2, "AC-17: no re-emission once expired")


func test_ac_16_17_village_initialized_exactly_once() -> void:
	# village_initialized: exactly once per initialize_village() call.
	NPCRegistry.initialize_village(_village([_elder()], 18))
	assert_eq(_village_initialized, 1, "village_initialized must fire exactly once")
	NPCRegistry.clear_village()
	NPCRegistry.initialize_village(_village([_elder()], 18))
	assert_eq(_village_initialized, 2, "village_initialized must fire exactly once per call")


# --- AC-18/19: persistence ---------------------------------------------------

func test_ac_18_serialize_clear_deserialize_roundtrip() -> void:
	# AC-18: serialize -> clear_village -> deserialize produces an identical
	# NPCRegistry state (traits, belief, approach_count, cooldown, revealed).
	NPCRegistry.initialize_village(_real_village())
	# Advance some state so the round-trip is non-trivial.
	var elder := NPCRegistry.get_npc("village_01_elder_1")
	NPCRegistry.apply_conversion_outcome("village_01_elder_1", GameEnums.ConversionOutcome.PERSUADED, GameEnums.DialogueApproach.DOUBT)
	NPCRegistry.reveal_trait("village_01_elder_1", GameEnums.DialogueApproach.DOUBT)
	var payload := NPCRegistry.serialize()
	var snapshot_before: Array = _snapshot_records()

	NPCRegistry.clear_village()
	assert_eq(NPCRegistry.get_all_npcs().size(), 0, "clear must empty the registry")
	NPCRegistry.deserialize(payload)

	var snapshot_after: Array = _snapshot_records()
	assert_eq(snapshot_before.size(), snapshot_after.size(), "AC-18: record count identical after round-trip")
	for i in snapshot_before.size():
		assert_eq(snapshot_before[i], snapshot_after[i],
			"AC-18: record %d must be identical after round-trip" % i)
	# Signals: deserialize does not re-emit village_initialized (that's an
	# init-time event; SaveLoad uses the signal at load-notify, not here).
	assert_eq(_village_initialized, 1, "deserialize must not re-emit village_initialized")


func test_ac_19_unknown_belief_state_loads_steadfast() -> void:
	# AC-19: a payload with an unknown BeliefState value must not crash; the
	# affected NPC loads with STEADFAST (graceful schema migration).
	var payload := {
		"version": 1,
		"village_id": "village_01",
		"npcs": [{
			"npc_id": "village_01_elder_1",
			"archetype": GameEnums.NPCArchetype.ELDER,
			"display_name": "Marun",
			"assigned_traits": ["bereaved"],
			"revealed_traits": [],
			"belief_state": 99,  # unknown enum value
			"cooldown_turns_remaining": 1,
			"approach_count": 2,
			"approach_history": {},
			"map_position": Vector2i(1, 1),
			"social_connections": [],
			"access_gate": null,
		}],
	}
	NPCRegistry.deserialize(payload)
	var npc: NpcRecord = NPCRegistry.get_npc("village_01_elder_1")
	assert_not_null(npc, "AC-19: NPC must load despite unknown belief")
	assert_eq(npc.belief_state, GameEnums.BeliefState.STEADFAST,
		"AC-19: unknown BeliefState must default to STEADFAST")
	assert_push_error("unknown BeliefState 99",
		"AC-19: the unknown belief must be logged as an error")
	# Unknown RelationshipType also handled gracefully (E4): the connection
	# is dropped, never crashed on.
	payload["npcs"][0]["social_connections"] = [{
		"target_npc_id": "village_01_widow_1",
		"relationship_type": 999,
		"influence_weight": 0.5,
	}]
	NPCRegistry.clear_village()
	NPCRegistry.deserialize(payload)
	npc = NPCRegistry.get_npc("village_01_elder_1")
	assert_eq(npc.social_connections.size(), 0,
		"E4: unknown RelationshipType must drop the connection")
	assert_push_error("unknown BeliefState 99",
		"the second load's unknown belief must also be logged")
	assert_push_error("unknown RelationshipType 999",
		"E4: the unknown relationship must be logged as an error")


# --- AC-20/21: edge-case defenses --------------------------------------------

func test_ac_20_duplicate_id_guard() -> void:
	# AC-20: a definition with a duplicate npc_id produces exactly one
	# registered record and a warning is logged.
	NPCRegistry.initialize_village(_village([_elder(), _elder()], 20))
	var all := NPCRegistry.get_all_npcs()
	var elder_count := 0
	for npc in all:
		if npc.npc_id == "village_01_elder_1":
			elder_count += 1
	assert_eq(elder_count, 1, "AC-20: exactly one record for the duplicate id")
	assert_eq(all.size(), 1, "AC-20: duplicate must not inflate the registry")
	var warnings := NPCRegistry.get_warnings()
	var found_warning := false
	for w in warnings:
		if "duplicate" in w and "village_01_elder_1" in w:
			found_warning = true
	assert_true(found_warning, "AC-20: a warning naming the duplicate id must be logged")


func test_ac_21_unplayable_village_guard() -> void:
	# AC-21: a definition where ALL NPCs have gates results in exactly one
	# NPC having its access gate cleared at init, and an error log is
	# written (E8).
	var elder_locked := _elder()
	elder_locked["access_gate"] = {"required_belief_state": GameEnums.BeliefState.OPEN, "required_npc_ids": ["village_01_widow_1"]}
	var widow_locked := _widow()
	widow_locked["access_gate"] = {"required_belief_state": GameEnums.BeliefState.OPEN, "required_npc_ids": ["village_01_elder_1"]}
	NPCRegistry.initialize_village(_village([elder_locked, widow_locked], 21))
	var gated_count := 0
	for npc in NPCRegistry.get_all_npcs():
		if npc.access_gate != null:
			gated_count += 1
	assert_eq(gated_count, 1, "AC-21: exactly one gate must remain (one cleared, tie -> first)")
	# The survivor is the NPC with FEWEST required ids (E8); on a tie of
	# size 1 each, the FIRST registered NPC is the one cleared (documented
	# deterministic tie-break — registration order).
	var npcs := NPCRegistry.get_all_npcs()
	assert_null(npcs[0].access_gate, "the first NPC (fewest required ids, tie) gets its gate cleared")
	assert_not_null(npcs[1].access_gate, "the second NPC keeps its gate (AC-21)")
	# Village must still be playable: at least one NPC is approachable.
	assert_gt(NPCRegistry.get_approachable_npcs().size(), 0, "AC-21: village must remain playable")
	assert_push_error("unplayable village",
		"AC-21: the unplayable-village guard must log an error")


# --- E1-E14 edge cases -------------------------------------------------------

func test_e1_duplicate_npc_id_returns_existing() -> void:
	# E1: logged warning + existing record kept, no duplicate entry.
	NPCRegistry.initialize_village(_village([_elder(), _elder()], 30))
	assert_eq(NPCRegistry.get_all_npcs().size(), 1, "E1: only one record for the duplicated slot")


func test_e2_dead_gate_ref_clears_gate() -> void:
	# E2: access_gate.required_npc_ids references a non-existent npc_id ->
	# error + gate set to null (treated as no gate).
	var elder := _elder()
	elder["access_gate"] = {"required_belief_state": GameEnums.BeliefState.OPEN, "required_npc_ids": ["village_01_ghost_1"]}
	NPCRegistry.initialize_village(_village([elder], 31))
	var npc: NpcRecord = NPCRegistry.get_npc("village_01_elder_1")
	assert_null(npc.access_gate, "E2: dead gate ref must null the gate")
	assert_gt(NPCRegistry.get_approachable_npcs().size(), 0, "E2: NPC must become immediately approachable")
	assert_push_error("access gate references unknown id",
		"E2: the dead gate ref must be logged as an error")


func test_e3_dead_connection_ref_dropped() -> void:
	# E3: social_connections referencing a non-existent target -> error +
	# connection dropped; other connections intact.
	var soldier := _soldier()
	soldier["social_connections"] = [
		{"target_npc_id": "village_01_ghost_1", "relationship_type": GameEnums.RelationshipType.NEIGHBOR, "influence_weight": 0.5},
		{"target_npc_id": "village_01_widow_1", "relationship_type": GameEnums.RelationshipType.KIN, "influence_weight": 0.7},
	]
	NPCRegistry.initialize_village(_village([soldier, _widow()], 32))
	var npc: NpcRecord = NPCRegistry.get_npc("village_01_soldier_1")
	assert_eq(npc.social_connections.size(), 1, "E3: dead connection must be dropped")
	assert_eq(npc.social_connections[0].target_npc_id, "village_01_widow_1", "E3: valid connection survives")
	assert_push_error("connection targets unknown id",
		"E3: the dead connection must be logged as an error")


func test_e4_unknown_relationship_dropped_gracefully() -> void:
	# E4 (deserialization): unknown RelationshipType drops the connection,
	# never crashes.
	var payload := {
		"version": 1,
		"village_id": "village_01",
		"npcs": [{
			"npc_id": "village_01_soldier_1",
			"archetype": GameEnums.NPCArchetype.SOLDIER,
			"display_name": "Aldric",
			"assigned_traits": ["dutiful"],
			"revealed_traits": [],
			"belief_state": GameEnums.BeliefState.OPEN,
			"cooldown_turns_remaining": 0,
			"approach_count": 0,
			"approach_history": {},
			"map_position": Vector2i(1, 1),
			"social_connections": [{"target_npc_id": "village_01_widow_1", "relationship_type": 77, "influence_weight": 0.5}],
			"access_gate": null,
		}],
	}
	NPCRegistry.deserialize(payload)
	var npc: NpcRecord = NPCRegistry.get_npc("village_01_soldier_1")
	assert_eq(npc.social_connections.size(), 0, "E4: invalid relationship must drop the connection")
	assert_push_error("unknown RelationshipType 77",
		"E4: the invalid relationship must be logged as an error")


func test_e5_hardened_on_steadfast_updates_counters() -> void:
	# E5: belief floor holds but the approach registered (cooldown/counters).
	NPCRegistry.initialize_village(_village([_soldier()], 33))
	var npc: NpcRecord = NPCRegistry.get_npc("village_01_soldier_1")
	NPCRegistry.apply_conversion_outcome("village_01_soldier_1", GameEnums.ConversionOutcome.HARDENED, GameEnums.DialogueApproach.FEAR)
	assert_eq(npc.belief_state, GameEnums.BeliefState.STEADFAST)
	assert_eq(npc.approach_count, 1, "E5: counter updates on the registered approach")
	assert_eq(npc.cooldown_turns_remaining, GameConfig.conversion.approach_cooldown_turns)


func test_e6_rival_grace_window_regression_and_after_close() -> void:
	# E6: RIVAL caller can regress a CONVERTED NPC while the grace window is
	# open; after the window closes, conversion is permanent for all callers.
	NPCRegistry.initialize_village(_village([_elder()], 34))
	var npc: NpcRecord = NPCRegistry.get_npc("village_01_elder_1")
	for i in 3:
		NPCRegistry.apply_conversion_outcome("village_01_elder_1", GameEnums.ConversionOutcome.PERSUADED, GameEnums.DialogueApproach.GRIEF)
	assert_eq(npc.belief_state, GameEnums.BeliefState.CONVERTED)
	# Grace window open -> RIVAL PERSUADED regresses to WAVERING.
	_state_changed.clear()
	NPCRegistry.apply_conversion_outcome("village_01_elder_1", GameEnums.ConversionOutcome.PERSUADED, GameEnums.DialogueApproach.FEAR, GameEnums.OutcomeCaller.RIVAL)
	assert_eq(npc.belief_state, GameEnums.BeliefState.WAVERING, "E6: RIVAL + open window regresses CONVERTED -> WAVERING")
	assert_eq(_state_changed.size(), 1, "E6: regression emits one npc_state_changed (CONVERTED -> WAVERING)")
	assert_eq(_state_changed[0], ["village_01_elder_1", GameEnums.BeliefState.CONVERTED, GameEnums.BeliefState.WAVERING])
	# Re-convert, close the window, then RIVAL PERSUADED must NOT regress.
	for i in 3:
		NPCRegistry.apply_conversion_outcome("village_01_elder_1", GameEnums.ConversionOutcome.PERSUADED, GameEnums.DialogueApproach.GRIEF)
		NPCRegistry.advance_turn()
	assert_eq(npc.belief_state, GameEnums.BeliefState.CONVERTED)
	for i in GameConfig.rival_faith.grace_window_turns + 2:
		NPCRegistry.advance_turn()
	assert_eq(npc.recently_converted_turns_remaining, 0, "grace window fully closed")
	_state_changed.clear()
	NPCRegistry.apply_conversion_outcome("village_01_elder_1", GameEnums.ConversionOutcome.PERSUADED, GameEnums.DialogueApproach.FEAR, GameEnums.OutcomeCaller.RIVAL)
	assert_eq(npc.belief_state, GameEnums.BeliefState.CONVERTED, "E6: after window closes, RIVAL PERSUADED is a no-op")
	assert_eq(_state_changed.size(), 0, "E6: no signal when no regression")


func test_e7_all_at_max_approaches_list_empty() -> void:
	# E7: with all NPCs at max approaches, get_approachable_npcs() is empty
	# (GSM detects the exhausted village; this system emits no signal).
	NPCRegistry.initialize_village(_village([_widow(), _soldier()], 35))
	for npc in NPCRegistry.get_all_npcs():
		npc.approach_count = GameConfig.conversion.max_approaches_per_npc
	assert_eq(NPCRegistry.get_approachable_npcs().size(), 0,
		"E7: all-at-max village must have no approachable NPCs")


func test_e8_unplayable_village_guard_clears_one_gate() -> void:
	# E8: an all-gated village is an authoring error — at init, clear the
	# gate on the NPC with the FEWEST required_npc_ids (error + no crash);
	# here the elder has 2 requirements vs the widow's 1, so the widow's
	# gate must be cleared (fewest), not the elder's.
	var elder := _elder()
	elder["access_gate"] = {"required_belief_state": GameEnums.BeliefState.OPEN,
		"required_npc_ids": ["village_01_widow_1", "village_01_soldier_1"]}
	var widow := _widow()
	widow["access_gate"] = {"required_belief_state": GameEnums.BeliefState.OPEN,
		"required_npc_ids": ["village_01_elder_1"]}
	var soldier := _soldier()
	soldier["access_gate"] = {"required_belief_state": GameEnums.BeliefState.OPEN,
		"required_npc_ids": ["village_01_widow_1", "village_01_elder_1"]}
	# All three NPCs are gated (E8 fires): elder 2 reqs, soldier 2 reqs,
	# widow 1 req — the widow has the FEWEST and must be the one un-gated.
	NPCRegistry.initialize_village(_village([elder, widow, soldier], 35))
	var elder_rec: NpcRecord = NPCRegistry.get_npc("village_01_elder_1")
	var widow_rec: NpcRecord = NPCRegistry.get_npc("village_01_widow_1")
	assert_not_null(elder_rec.access_gate, "E8: NPC with 2 requirements keeps its gate")
	assert_null(widow_rec.access_gate, "E8: NPC with the FEWEST requirements gets its gate cleared")
	# Village must remain playable.
	assert_gt(NPCRegistry.get_approachable_npcs().size(), 0, "E8: village must remain playable after guard")
	assert_push_error("unplayable village",
		"E8: the unplayable-village guard must log an error")


func test_e9_mutation_allowed_on_gated_npc() -> void:
	# E9: apply_conversion_outcome on a cooldown-gated or access-gated NPC is
	# VALID — the mutation API does not enforce approachability (RFS may act
	# on NPCs the player can't reach).
	NPCRegistry.initialize_village(_real_village())
	var noble := NPCRegistry.get_npc("village_01_noble_1")
	assert_not_null(noble.access_gate, "NOBLE starts gated")
	var approachable_before := NPCRegistry.get_approachable_npcs()
	assert_false(approachable_before.has(noble), "NOBLE is not approachable")
	# The Rival Faith System CAN still mutate it (E9).
	NPCRegistry.apply_conversion_outcome("village_01_noble_1", GameEnums.ConversionOutcome.SOFTENED, GameEnums.DialogueApproach.AMBITION, GameEnums.OutcomeCaller.RIVAL)
	assert_eq(noble.belief_state, GameEnums.BeliefState.OPEN, "E9: gated NPC can still be mutated by RFS")
	var approachable := NPCRegistry.get_approachable_npcs()
	assert_false(approachable.has(noble), "E9: gate still blocks the player's approach")


func test_e10_full_reveal_noop() -> void:
	# E10: when all traits are already revealed, reveal calls are no-ops.
	NPCRegistry.initialize_village(_village([_widow()], 36))
	var npc: NpcRecord = NPCRegistry.get_npc("village_01_widow_1")
	_set_assigned(npc, ["bereaved"])
	_set_revealed(npc, ["bereaved"])
	assert_null(NPCRegistry.reveal_trait("village_01_widow_1", GameEnums.DialogueApproach.GRIEF), "E10: reveal_trait no-op")
	assert_null(NPCRegistry.trigger_inspect_reveal("village_01_widow_1"), "E10: inspect no-op")
	assert_eq(_trait_revealed.size(), 0, "E10: no signal on no-op")
	assert_eq(npc.revealed_traits, ["bereaved"])


func test_e11_inspect_on_empty_traits_logs_error() -> void:
	# E11: impossible in a correctly generated record; a data error must log
	# an error and return without mutation.
	NPCRegistry.initialize_village(_village([_widow()], 37))
	var npc: NpcRecord = NPCRegistry.get_npc("village_01_widow_1")
	_set_assigned(npc, [])  # inject the data error
	assert_null(NPCRegistry.trigger_inspect_reveal("village_01_widow_1"), "E11: empty traits -> null")
	assert_eq(_trait_revealed.size(), 0, "E11: no signal on data-error no-op")
	assert_push_error("empty assigned_traits",
		"E11: the data error must be logged as an error (GDD wording)")


func test_e12_rival_pair_both_convert_same_turn_valid() -> void:
	# E12: two RIVAL-connected NPCs converted sequentially both end CONVERTED
	# (no cross-NPC regression — RIVAL resistance applies only during the
	# approach window of each individual conversion).
	var soldier := _soldier()
	soldier["social_connections"] = [{"target_npc_id": "village_01_widow_1", "relationship_type": GameEnums.RelationshipType.RIVAL, "influence_weight": 1.0}]
	var widow := _widow()
	widow["social_connections"] = [{"target_npc_id": "village_01_soldier_1", "relationship_type": GameEnums.RelationshipType.RIVAL, "influence_weight": 1.0}]
	NPCRegistry.initialize_village(_village([soldier, widow], 38))
	for i in 3:
		NPCRegistry.apply_conversion_outcome("village_01_soldier_1", GameEnums.ConversionOutcome.PERSUADED, GameEnums.DialogueApproach.GRIEF)
		NPCRegistry.advance_turn()
	for i in 3:
		NPCRegistry.apply_conversion_outcome("village_01_widow_1", GameEnums.ConversionOutcome.PERSUADED, GameEnums.DialogueApproach.GRIEF)
		NPCRegistry.advance_turn()
	assert_eq(NPCRegistry.get_npc("village_01_soldier_1").belief_state, GameEnums.BeliefState.CONVERTED, "E12: rival 1 converts")
	assert_eq(NPCRegistry.get_npc("village_01_widow_1").belief_state, GameEnums.BeliefState.CONVERTED, "E12: rival 2 converts")


func test_e13_clear_village_with_active_cooldowns() -> void:
	# E13: clear_village() while NPCs have active cooldowns removes all
	# records and discards cooldown state — no crash, no retained refs.
	NPCRegistry.initialize_village(_real_village())
	for npc in NPCRegistry.get_all_npcs():
		npc.cooldown_turns_remaining = 5
	NPCRegistry.clear_village()
	assert_eq(NPCRegistry.get_all_npcs().size(), 0, "E13: registry emptied")
	assert_null(NPCRegistry.get_npc("village_01_elder_1"), "E13: records gone")
	# A subsequent initialize works cleanly (no stale state).
	NPCRegistry.initialize_village(_real_village())
	assert_eq(NPCRegistry.get_all_npcs().size(), 8, "E13: re-init works after clear")


func test_e14_get_npc_unknown_returns_null() -> void:
	# E14: get_npc() with an unregistered id returns null.
	NPCRegistry.initialize_village(_real_village())
	assert_null(NPCRegistry.get_npc("village_01_nonexistent_9"), "E14: unknown id -> null")
	assert_null(NPCRegistry.get_npc(""), "E14: empty id -> null")


# --- API surface sanity ------------------------------------------------------

func test_api_hidden_trait_count() -> void:
	NPCRegistry.initialize_village(_village([_widow()], 40))
	var npc: NpcRecord = NPCRegistry.get_npc("village_01_widow_1")
	assert_eq(NPCRegistry.get_hidden_trait_count("village_01_widow_1"), npc.assigned_traits.size(),
		"hidden count = assigned before any reveal")
	NPCRegistry.trigger_inspect_reveal("village_01_widow_1")
	assert_eq(NPCRegistry.get_hidden_trait_count("village_01_widow_1"), npc.assigned_traits.size() - 1,
		"hidden count drops after one reveal")
	assert_eq(NPCRegistry.get_hidden_trait_count("unknown"), 0, "unknown id -> 0")


func test_api_get_npcs_by_belief() -> void:
	NPCRegistry.initialize_village(_real_village())
	assert_eq(NPCRegistry.get_npcs_by_belief(GameEnums.BeliefState.STEADFAST).size(), 8, "all start STEADFAST")
	NPCRegistry.apply_conversion_outcome("village_01_elder_1", GameEnums.ConversionOutcome.PERSUADED, GameEnums.DialogueApproach.GRIEF)
	assert_eq(NPCRegistry.get_npcs_by_belief(GameEnums.BeliefState.OPEN).size(), 1, "exactly one OPEN after one persuade")


func test_api_get_connections_and_archetype() -> void:
	NPCRegistry.initialize_village(_real_village())
	var elder_conns := NPCRegistry.get_connections("village_01_elder_1")
	assert_eq(elder_conns.size(), 3, "elder has 3 authored connections (village_01.tres)")
	var noble_def: NPCArchetypeDefinition = NPCRegistry.get_archetype_definition(GameEnums.NPCArchetype.NOBLE)
	assert_not_null(noble_def, "NOBLE archetype must resolve")
	assert_eq(noble_def.social_influence_weight, 2.5, "NOBLE social_influence_weight per Rule 3")
	assert_null(NPCRegistry.get_archetype_definition(-1), "invalid archetype -> null")


func test_api_approach_history_tracks_approaches() -> void:
	NPCRegistry.initialize_village(_village([_widow()], 41))
	var npc: NpcRecord = NPCRegistry.get_npc("village_01_widow_1")
	NPCRegistry.apply_conversion_outcome("village_01_widow_1", GameEnums.ConversionOutcome.SOFTENED, GameEnums.DialogueApproach.GRIEF)
	NPCRegistry.apply_conversion_outcome("village_01_widow_1", GameEnums.ConversionOutcome.RESISTED, GameEnums.DialogueApproach.DOUBT)
	NPCRegistry.apply_conversion_outcome("village_01_widow_1", GameEnums.ConversionOutcome.HARDENED, GameEnums.DialogueApproach.FEAR)
	assert_eq(npc.approach_history.get(GameEnums.DialogueApproach.GRIEF, 0), 1)
	assert_eq(npc.approach_history.get(GameEnums.DialogueApproach.DOUBT, 0), 1)
	assert_eq(npc.approach_history.get(GameEnums.DialogueApproach.FEAR, 0), 1)
	assert_eq(npc.approach_count, 3)


# --- helpers ---------------------------------------------------------------

## Typed-array assign helpers: NpcRecord.assigned_traits / revealed_traits
## are Array[String]; assigning an untyped Array literal is a runtime type
## error on 4.6, so route through .assign().
func _set_assigned(p_npc: NpcRecord, p_ids: Array) -> void:
	p_npc.assigned_traits.assign(p_ids)


func _set_revealed(p_npc: NpcRecord, p_ids: Array) -> void:
	p_npc.revealed_traits.assign(p_ids)


## Captures every NPC record into a comparable Array of Dictionaries for
## round-trip equality (AC-18).
func _snapshot_records() -> Array:
	var out: Array = []
	for npc in NPCRegistry.get_all_npcs():
		out.append({
			"npc_id": npc.npc_id,
			"archetype": int(npc.archetype),
			"assigned_traits": npc.assigned_traits.duplicate(),
			"revealed_traits": npc.revealed_traits.duplicate(),
			"belief_state": int(npc.belief_state),
			"cooldown_turns_remaining": npc.cooldown_turns_remaining,
			"recently_converted_turns_remaining": npc.recently_converted_turns_remaining,
			"approach_count": npc.approach_count,
			"approach_history": npc.approach_history.duplicate(true),
			"map_position": npc.map_position,
			"connections": npc.social_connections.size(),
		})
	return out