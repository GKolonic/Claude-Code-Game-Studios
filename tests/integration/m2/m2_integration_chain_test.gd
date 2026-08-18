extends GutTest
## M2 integration chain suite — Sprint 2 task 2-8 (QA plan M2-INT-1 / M2-INT-2).
## Exercises the FULL generate -> resolve -> apply chain on the real
## village_01 fixture: NPCRegistry.initialize_village() (generation), then
## ConversionLogicEngine.resolve(approach, npc_id, seeded_rng) paired with
## NPCRegistry.apply_conversion_outcome(npc_id, outcome, approach) for every
## NPC x every valid approach (CLE AC-8.3 caller-stub contract — THIS suite
## plays the DCS/RFS caller), then same-seed FULL-CHAIN determinism.
##
## Scope guardrails (consolidated with the unit suites — statistical
## heavy-lifting stays OUT of this suite; this is the chain proof):
##   - All randomness is explicit: generation uses village_01's pinned
##     rng_seed (20260818); each resolve threads a fresh RNG seeded by a
##     fixed deterministic function of (npc index, approach) so the resolve
##     sequence is reproducible (ADR-0007 — never a null rng in tests).
##   - The R9 pair-contract assertion is the critical one: after every
##     resolve -> apply pair, an NPC can NEVER be left with an updated
##     approach_history but a stale cooldown. We assert approach_count +1,
##     approach_history[approach] +1 AND
##     cooldown_turns_remaining == GameConfig.conversion.approach_cooldown_turns
##     after EVERY pair — this is the test that proves the DCD finally-block
##     contract (resolve ALWAYS paired with apply).
##   - Belief transitions are validated against the Rule 5 table (PLAYER
##     caller) after every apply: STEADFAST->OPEN->WAVERING->CONVERTED for
##     PERSUADED; OPEN->STEADFAST for HARDENED on non-RIVAL caller; RESISTED
##     leaves belief unchanged but still increments counters.
##   - Per CLE EC-4: resolving a CONVERTED NPC logs a warning (GUT 9.6.1 —
##     warnings under test must be asserted) and returns a valid outcome;
##     apply is a no-op on belief (NPC CS AC-7 / E6) but registers the
##     approach.
##
## Known GDD/CONFIG note (carried from 2-7): shipped band fractions
## (0.545+0.455=1.0) make the HARDENED zone mathematically empty; the chain
## here still proves every outcome path through the pair contract and the
## belief table regardless of which outcomes the seeded rolls produce.

const VILLAGE_01 := "res://assets/data/villages/village_01.tres"

var _state_changed: Array = []


func before_each() -> void:
	NPCRegistry.clear_village()
	_state_changed.clear()
	NPCRegistry.npc_state_changed.connect(_on_state_changed)


func after_each() -> void:
	NPCRegistry.npc_state_changed.disconnect(_on_state_changed)
	NPCRegistry.clear_village()


func _on_state_changed(npc_id: String, old_state, new_state) -> void:
	_state_changed.append([npc_id, old_state, new_state])


## Fixed deterministic resolve-seed for pair (npc_index, approach).
## The resolve sequence is part of the full-chain determinism contract —
## identical across both M2-INT-2 runs by construction.
func _pair_seed(p_npc_index: int, p_approach: int) -> int:
	return 20260818 + p_npc_index * 1000 + p_approach * 137


## Rule 5 expected belief after an apply with the PLAYER caller (non-RIVAL).
func _rule5_expected(p_old_belief: int, p_outcome: int) -> int:
	match p_outcome:
		GameEnums.ConversionOutcome.PERSUADED:
			match p_old_belief:
				GameEnums.BeliefState.STEADFAST:
					return GameEnums.BeliefState.OPEN
				GameEnums.BeliefState.OPEN:
					return GameEnums.BeliefState.WAVERING
				GameEnums.BeliefState.WAVERING:
					return GameEnums.BeliefState.CONVERTED
				_:
					return p_old_belief  # CONVERTED terminal for PLAYER
		GameEnums.ConversionOutcome.SOFTENED:
			match p_old_belief:
				GameEnums.BeliefState.STEADFAST:
					return GameEnums.BeliefState.OPEN
				GameEnums.BeliefState.OPEN:
					return GameEnums.BeliefState.WAVERING
				_:
					return p_old_belief  # WAVERING: no change; CONVERTED: no-op
		GameEnums.ConversionOutcome.RESISTED:
			return p_old_belief
		GameEnums.ConversionOutcome.HARDENED:
			match p_old_belief:
				GameEnums.BeliefState.OPEN:
					return GameEnums.BeliefState.STEADFAST
				GameEnums.BeliefState.WAVERING:
					return GameEnums.BeliefState.OPEN
				_:
					return p_old_belief  # STEADFAST floor (E5); CONVERTED no-op
	return p_old_belief


## One full chain run: initialize_village(village_01) then the complete
## resolve -> apply sequence over the 8 NPCs x 4 approaches with fixed pair
## seeds. Asserts the R9 pair contract + Rule 5 belief-table validity after
## EVERY pair; returns the serialized snapshot (M2-INT-2 compares two runs).
func _run_full_chain() -> Dictionary:
	NPCRegistry.initialize_village(load(VILLAGE_01))
	var npcs: Array[NpcRecord] = NPCRegistry.get_all_npcs()
	assert_eq(npcs.size(), 8, "M2-INT-1: initialize_village(village_01) must yield 8 NPCs")
	for i in npcs.size():
		var npc: NpcRecord = npcs[i]
		for approach in GameEnums.DialogueApproach.values():
			var npc_id := npc.npc_id
			var already_converted := npc.belief_state == GameEnums.BeliefState.CONVERTED
			var before_count := npc.approach_count
			var before_history := int(npc.approach_history.get(approach, 0))
			var before_belief := npc.belief_state

			# resolve (pure, CLE AC-1) -> apply: the DCS/RFS pair contract.
			var outcome := ConversionLogicEngine.resolve(
				approach, npc_id, RNGHelpers.make_seeded(_pair_seed(i, approach)))
			if already_converted:
				# CLE EC-4: resolve on CONVERTED treats as STEADFAST + warning.
				assert_push_warning("EC-4")
			var before_apply: Array = _state_changed.duplicate()
			NPCRegistry.apply_conversion_outcome(npc_id, outcome, approach)

			# R9 pair contract — the DCD finally-block proof (M2-INT-1).
			assert_eq(npc.approach_count, before_count + 1,
				"R9: approach_count must increment by exactly 1 after apply on '%s' (approach %s)" % [npc_id, str(approach)])
			assert_eq(int(npc.approach_history.get(approach, 0)), before_history + 1,
				"R9: approach_history[%s] must increment by exactly 1 after apply on '%s'" % [str(approach), npc_id])
			assert_eq(npc.cooldown_turns_remaining, GameConfig.conversion.approach_cooldown_turns,
				"R9: cooldown_turns_remaining must equal approach_cooldown_turns (%d) after apply — never stale (R9)" % GameConfig.conversion.approach_cooldown_turns)

			# Belief-table validity (Rule 5, PLAYER caller).
			var expected := _rule5_expected(before_belief, outcome)
			assert_eq(npc.belief_state, expected,
				"Rule 5: '%s' belief %s after outcome %s must follow the table (got %s)" % [
					npc_id, str(before_belief), str(outcome), str(npc.belief_state)])
			if before_belief == GameEnums.BeliefState.WAVERING and outcome == GameEnums.ConversionOutcome.PERSUADED:
				assert_eq(npc.recently_converted_turns_remaining, GameConfig.rival_faith.grace_window_turns,
					"Rule 5 dagger: WAVERING->CONVERTED must set the rival grace window (any caller)")
			# Exactly one npc_state_changed when the belief moved, none otherwise.
			if expected != before_belief:
				assert_eq(_state_changed.size(), before_apply.size() + 1,
					"AC-16: exactly one npc_state_changed per transition on '%s'" % npc_id)
			else:
				assert_eq(_state_changed.size(), before_apply.size(),
					"AC-16: no npc_state_changed on a no-op outcome on '%s'" % npc_id)
	return NPCRegistry.serialize()


# --- M2-INT-1: full generate -> resolve -> apply chain on village_01 --------

func test_m2_int_1_full_chain_pair_contract_all_npcs_all_approaches() -> void:
	# 8 NPCs x 4 approaches = 32 resolve -> apply pairs; every pair must
	# leave the NPC with the approach registered (cooldown + counters) and
	# a Rule-5-valid belief — the chain-level R9 pair-contract proof.
	var payload := _run_full_chain()
	assert_eq(payload["npcs"].size(), 8, "M2-INT-1: full chain keeps the 8-NPC roster")
	for record in payload["npcs"]:
		# Every NPC was approached 4 times (one per approach) and every
		# approach registered: approach_count == 4 and cooldown set.
		assert_eq(int(record["approach_count"]), 4,
			"chain covers each approach exactly once per NPC (approach_count == 4 on '%s')" % record["npc_id"])
		assert_eq(int(record["cooldown_turns_remaining"]), GameConfig.conversion.approach_cooldown_turns)


func test_m2_int_1_belief_transitions_per_rule_5_non_rival() -> void:
	# Focused Rule 5 validity on a synthetic 3-NPC village:
	#  - PERSUADED path: STEADFAST -> OPEN -> WAVERING -> CONVERTED (AC-5)
	#  - HARDENED on OPEN (non-RIVAL caller): OPEN -> STEADFAST regression
	#  - RESISTED: belief unchanged, counters/cooldown still update (E5/EC-11)
	var defs: Array = [
		_npc_def("village_01_soldier_1", GameEnums.NPCArchetype.SOLDIER, "Aldric Galeward"),
		_npc_def("village_01_widow_1", GameEnums.NPCArchetype.WIDOW, "Haleth Vale"),
	]
	NPCRegistry.initialize_village(_village(defs, 777))

	# PERSUADED linear progression with the pair contract at each step.
	var soldier: NpcRecord = NPCRegistry.get_npc("village_01_soldier_1")
	for step in 3:
		var before_count := soldier.approach_count
		_state_changed.clear()
		NPCRegistry.apply_conversion_outcome(soldier.npc_id,
			GameEnums.ConversionOutcome.PERSUADED, GameEnums.DialogueApproach.GRIEF)
		var expected_states := [GameEnums.BeliefState.OPEN, GameEnums.BeliefState.WAVERING, GameEnums.BeliefState.CONVERTED]
		assert_eq(soldier.belief_state, expected_states[step],
			"PERSUADED step %d must reach %s (AC-5 linear progression)" % [step + 1, str(expected_states[step])])
		assert_eq(soldier.approach_count, before_count + 1, "pair contract: approach_count +1 per apply")
		assert_eq(soldier.approach_history.get(GameEnums.DialogueApproach.GRIEF, 0), step + 1,
			"pair contract: approach_history[GRIEF] == %d" % (step + 1))
		assert_eq(soldier.cooldown_turns_remaining, GameConfig.conversion.approach_cooldown_turns,
			"pair contract: cooldown must equal approach_cooldown_turns after apply")
		assert_eq(_state_changed.size(), 1, "AC-16: each PERSUADED transition emits exactly one signal")
		if step == 2:
			# Rule 5 dagger: WAVERING->CONVERTED sets the rival grace window
			# (assert BEFORE the cooldown-clearing advance_turn below, which
			# ticks the window down by 1).
			assert_eq(soldier.recently_converted_turns_remaining, GameConfig.rival_faith.grace_window_turns,
				"Rule 5 dagger: WAVERING->CONVERTED sets the rival grace window")
		NPCRegistry.advance_turn()  # clear cooldown so the next apply is legal gameplay flow
	assert_eq(soldier.belief_state, GameEnums.BeliefState.CONVERTED)

	# HARDENED on OPEN (non-RIVAL caller): OPEN -> STEADFAST.
	var widow: NpcRecord = NPCRegistry.get_npc("village_01_widow_1")
	NPCRegistry.apply_conversion_outcome(widow.npc_id,
		GameEnums.ConversionOutcome.PERSUADED, GameEnums.DialogueApproach.AMBITION)  # -> OPEN
	assert_eq(widow.belief_state, GameEnums.BeliefState.OPEN)
	_state_changed.clear()
	NPCRegistry.apply_conversion_outcome(widow.npc_id,
		GameEnums.ConversionOutcome.HARDENED, GameEnums.DialogueApproach.FEAR)  # non-RIVAL
	assert_eq(widow.belief_state, GameEnums.BeliefState.STEADFAST,
		"HARDENED on OPEN (non-RIVAL caller) must regress to STEADFAST (Rule 5)")
	assert_eq(_state_changed.size(), 1, "OPEN->STEADFAST regression emits exactly one signal")
	assert_eq(widow.approach_count, 2, "counters update even on a regression (approach registered)")
	assert_eq(widow.cooldown_turns_remaining, GameConfig.conversion.approach_cooldown_turns)

	# RESISTED: belief unchanged but counters/cooldown still update (EC-11).
	_state_changed.clear()
	NPCRegistry.apply_conversion_outcome(widow.npc_id,
		GameEnums.ConversionOutcome.RESISTED, GameEnums.DialogueApproach.DOUBT)
	assert_eq(widow.belief_state, GameEnums.BeliefState.STEADFAST,
		"RESISTED leaves belief unchanged (Rule 5)")
	assert_eq(_state_changed.size(), 0, "RESISTED emits no npc_state_changed (AC-16)")
	assert_eq(widow.approach_count, 3, "RESISTED still increments approach_count (EC-11 spent approach)")
	assert_eq(int(widow.approach_history.get(GameEnums.DialogueApproach.DOUBT, 0)), 1,
		"RESISTED still increments approach_history (CLE Formula 3 repeat penalty accrues)")
	assert_eq(widow.cooldown_turns_remaining, GameConfig.conversion.approach_cooldown_turns,
		"RESISTED still sets the cooldown (EC-11)")


# --- M2-INT-2: same-seed determinism across the FULL chain ------------------

func test_m2_int_2_full_chain_determinism_same_seed() -> void:
	# Run the entire chain (village generation + 32 reseeded CLE rolls +
	# state mutation) twice with identical fixed seeds — the two runs must
	# produce byte-identical final state. This is the ADR-0007 FULL-CHAIN
	# determinism proof, distinct from 2-6's generation-only determinism.
	var first := _run_full_chain()

	NPCRegistry.clear_village()
	var second := _run_full_chain()

	assert_eq(first, second,
		"M2-INT-2: full chain (generation + CLE rolls) must be byte-identical across two same-seed runs (ADR-0007)")

	# The full chain must DIFFER from a generation-only snapshot — proving
	# the resolve/apply sequence actually consumed the CLE roll stream and
	# mutated state (the determinism proof is over a real chain, not a no-op).
	NPCRegistry.clear_village()
	NPCRegistry.initialize_village(load(VILLAGE_01))
	var generation_only := NPCRegistry.serialize()
	assert_ne(first, generation_only,
		"M2-INT-2: the full-chain snapshot must differ from a generation-only snapshot (CLE rolls entered the chain)")


# --- CLE EC-4 / NPC CS AC-7, E6: CONVERTED NPC resolve + apply no-op ---------

func test_m2_int_1_converted_npc_resolve_valid_and_apply_noop() -> void:
	# After converting ALL 8 village_01 NPCs, resolve() on a CONVERTED NPC
	# must return a valid outcome (EC-4 treats it as STEADFAST + warning)
	# and apply must be a no-op on belief (NPC CS AC-7 / E6 — terminal for
	# PLAYER) while still registering the approach.
	NPCRegistry.initialize_village(load(VILLAGE_01))
	for npc in NPCRegistry.get_all_npcs():
		for i in 3:
			NPCRegistry.apply_conversion_outcome(npc.npc_id,
				GameEnums.ConversionOutcome.PERSUADED, GameEnums.DialogueApproach.DOUBT)
	for npc in NPCRegistry.get_all_npcs():
		assert_eq(npc.belief_state, GameEnums.BeliefState.CONVERTED,
			"setup: all 8 NPCs must be CONVERTED")

	var widow: NpcRecord = NPCRegistry.get_npc("village_01_widow_1")
	var before_count := widow.approach_count
	var outcome := ConversionLogicEngine.resolve(
		GameEnums.DialogueApproach.GRIEF, widow.npc_id, RNGHelpers.make_seeded(90210))
	assert_push_warning("EC-4")  # CLE EC-4: resolve on CONVERTED logs a warning
	assert_true(outcome >= GameEnums.ConversionOutcome.PERSUADED
		and outcome <= GameEnums.ConversionOutcome.HARDENED,
		"EC-4: resolve on CONVERTED must still return a valid ConversionOutcome")

	_state_changed.clear()
	NPCRegistry.apply_conversion_outcome(widow.npc_id, outcome, GameEnums.DialogueApproach.GRIEF)
	assert_eq(widow.belief_state, GameEnums.BeliefState.CONVERTED,
		"AC-7/E6: apply on CONVERTED (PLAYER caller) must be a no-op on belief")
	assert_eq(_state_changed.size(), 0,
		"AC-7: no npc_state_changed on a terminal no-op")
	assert_eq(widow.approach_count, before_count + 1,
		"E6: the approach still registers (counters update) on a CONVERTED apply")
	assert_eq(int(widow.approach_history.get(GameEnums.DialogueApproach.GRIEF, 0)), 1,
		"E6: approach_history[GRIEF] increments on a CONVERTED apply")
	assert_eq(widow.cooldown_turns_remaining, GameConfig.conversion.approach_cooldown_turns,
		"E6: cooldown still set on a CONVERTED apply")


# --- helpers ----------------------------------------------------------------

## Minimal definition for a single NPC (mirrors the unit-suite builder).
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