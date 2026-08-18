extends GutTest
## ConversionLogicEngine unit suite — Sprint 2 task 2-7 (CLE AC-1.1..AC-8.4,
## EC-1..13). Exercises the live ConversionLogicEngine Autoload (slot 6)
## against real NPCRegistry records and live GameConfig values.
##
## HOW IT WORKS: a synthetic one-NPC village is generated via
## initialize_village() and the record's trait/belief/history fields are then
## overwritten directly (the CLE pulls NPC state at call time, so in-place
## mutation is fully visible). Determinism is explicit: every resolve call
## threads an RNG built with RNGHelpers.make_seeded(seed) (ADR-0007 — a null
## rng is the runtime entropy path and is NEVER used in tests).
##
## Where a test mutates GameConfig.conversion fields (AC-6.4/6.6/6.7/7.1/7.2/
## 8.4, EC-7, AC-2.4/5.5), before_each snapshots all 14 fields and after_each
## restores them, so every test is isolated regardless of failure.
##
## KNOWN GDD/CONFIG CONTRADICTION (flagged to Creative Director):
##   The shipped band fractions (softened 0.545 + resisted 0.455 = 1.0,
##   approved decision #6 / game-config.md) make the HARDENED zone
##   mathematically EMPTY at every P_final (Formula 5: hardened =
##   remaining - remaining*0.545 - remaining*0.455 = 0). The GDD's drama-space
##   table and AC-6.4/AC-6.7 as written assume fractions summing to < 1.0.
##   Tests that REQUIRE a non-empty HARDENED zone (AC-6.4, AC-6.7) therefore
##   set effective band fractions that sum to < 1.0 (documented per test);
##   all other tests run the shipped defaults. The formula itself is
##   implemented exactly per GDD Formula 5.

const NPC_ID := "village_01_widow_1"
const CONVERSION_TRES_PATH := "res://assets/data/config/conversion_config.tres"
const EPS := 1e-9
const GRIEF := GameEnums.DialogueApproach.GRIEF
const FEAR := GameEnums.DialogueApproach.FEAR
const STEADFAST := GameEnums.BeliefState.STEADFAST
const OPEN := GameEnums.BeliefState.OPEN
const WAVERING := GameEnums.BeliefState.WAVERING
const CONVERTED := GameEnums.BeliefState.CONVERTED

var _config_snapshot: Dictionary = {}


# --- lifecycle ---------------------------------------------------------------

func before_each() -> void:
	_snapshot_config()
	NPCRegistry.clear_village()


func after_each() -> void:
	_restore_config()
	NPCRegistry.clear_village()


# --- helpers -----------------------------------------------------------------

## One-NPC synthetic village (widow archetype; id format valid for _village_id).
func _ensure_npc(p_traits: Array[String] = [], p_belief: int = STEADFAST,
		p_history: Dictionary = {}) -> NpcRecord:
	var def := {
		"npc_id": NPC_ID,
		"archetype": GameEnums.NPCArchetype.WIDOW,
		"display_name": "Haleth Vale",
		"map_position": Vector2i(1, 2),
		"social_connections": [],
	}
	var village := VillageDefinition.new()
	village.village_id = "village_01"
	village.map_art_path = "res://assets/maps/village_01/village_map.png"
	village.rng_seed = 20260818
	var defs: Array[Dictionary] = [def]
	village.npc_definitions = defs
	NPCRegistry.initialize_village(village)
	var npc: NpcRecord = NPCRegistry.get_npc(NPC_ID)
	npc.assigned_traits = p_traits
	npc.belief_state = p_belief
	npc.approach_history = p_history
	return npc


func _snapshot_config() -> void:
	_config_snapshot.clear()
	var cfg := GameConfig.conversion
	for field in ConversionConfig.get_validation_schema():
		_config_snapshot[field] = cfg.get(field)


func _restore_config() -> void:
	if GameConfig.conversion == null:
		GameConfig.conversion = load(CONVERSION_TRES_PATH)
	for field in _config_snapshot:
		GameConfig.conversion.set(field, _config_snapshot[field])


## Scans a bounded window of seeds and returns one whose FIRST uniform_roll
## lands in [p_lo, p_hi). Deterministic; fails the test if none found.
func _seed_for_first_roll_in(p_lo: float, p_hi: float) -> int:
	for seed in range(1, 20000):
		var rng := RNGHelpers.make_seeded(seed)
		var roll := RNGHelpers.uniform_roll(rng)
		if roll >= p_lo and roll < p_hi:
			return seed
	assert(false, "no seed found with first roll in [%f, %f) within 20000" % [p_lo, p_hi])
	return -1


## First roll produced by a fresh RNG seeded with p_seed (mirrors CLE's draw).
func _first_roll(p_seed: int) -> float:
	return RNGHelpers.uniform_roll(RNGHelpers.make_seeded(p_seed))


## Zone ceilings under CURRENT config, computed with the same arithmetic order
## as CLE Formula 5 (so boundary membership matches the engine exactly).
func _zone_bounds(p_final: float) -> Dictionary:
	var cfg := GameConfig.conversion
	var remaining := 1.0 - p_final
	var soft := remaining * cfg.softened_band_fraction
	var resist := remaining * cfg.resisted_band_fraction
	return {
		"persuaded_hi": p_final,
		"softened_hi": p_final + soft,
		"resisted_hi": p_final + soft + resist,
	}


# --- AC-1: pure function contract -------------------------------------------

func test_ac_1_1_determinism_same_seed_identical_outcome() -> void:
	# AC-1.1: identical inputs + same RNG seed => identical outcome.
	_ensure_npc(["bereaved", "lonely"])
	var a := ConversionLogicEngine.resolve(GRIEF, NPC_ID, RNGHelpers.make_seeded(4242))
	var b := ConversionLogicEngine.resolve(GRIEF, NPC_ID, RNGHelpers.make_seeded(4242))
	assert_eq(a, b, "same seed + unchanged state must reproduce the outcome exactly")


func test_ac_1_2_no_state_written_to_npc_registry() -> void:
	# AC-1.2: after resolve(), the NPC record is byte-identical to before.
	var npc := _ensure_npc(["bereaved", "lonely"], WAVERING, {GRIEF: 1})
	var before := {
		"belief": npc.belief_state,
		"history": npc.approach_history.duplicate(true),
		"cooldown": npc.cooldown_turns_remaining,
		"approaches": npc.approach_count,
		"traits": npc.assigned_traits.duplicate(),
	}
	ConversionLogicEngine.resolve(GRIEF, NPC_ID, RNGHelpers.make_seeded(7))
	var after := {
		"belief": npc.belief_state,
		"history": npc.approach_history.duplicate(true),
		"cooldown": npc.cooldown_turns_remaining,
		"approaches": npc.approach_count,
		"traits": npc.assigned_traits.duplicate(),
	}
	assert_eq(after, before, "resolve() must not mutate the NPC record (AC-1.2)")


func test_ac_1_3_no_gameconfig_side_effects() -> void:
	# AC-1.3: all GameConfig.conversion fields read identically before/after.
	_ensure_npc(["bereaved"])
	ConversionLogicEngine.resolve(GRIEF, NPC_ID, RNGHelpers.make_seeded(11))
	for field in ConversionConfig.get_validation_schema():
		var expected: Variant = _config_snapshot[field]
		var actual: Variant = GameConfig.conversion.get(field)
		assert_eq(actual, expected, "GameConfig.conversion.%s changed by resolve (AC-1.3)" % field)


# --- AC-2: Formula 1 — trait modifier subtotal ------------------------------

func test_ac_2_1_single_aligned_trait() -> void:
	# AC-2.1: one +1.0 trait, W=0.25, cap 0.50 => subtotal +0.25.
	var npc := _ensure_npc(["bereaved"])
	assert_almost_eq(_subtotal(npc), 0.25, EPS, "AC-2.1 single +1.0 trait => +0.25")


func test_ac_2_2_stacking_no_cap() -> void:
	# AC-2.2: two +1.0 traits => sum 0.50, no clamping.
	var npc := _ensure_npc(["bereaved", "lonely"])
	assert_almost_eq(_subtotal(npc), 0.50, EPS, "AC-2.2 two +1.0 traits => +0.50 (no clamp)")


func test_ac_2_3_stacking_cap_reached() -> void:
	# AC-2.3: four +1.0 traits => sum 1.00, clamped to +0.50. The shipped 16-trait
	# catalogue has exactly four FEAR +1.0 traits, so FEAR is the approach.
	var npc := _ensure_npc(["fearful", "mortal_minded", "superstitious", "visionary"])
	assert_almost_eq(_subtotal(npc, FEAR), 0.50, EPS, "AC-2.3 four +1.0 traits => +0.50 (capped)")


func test_ac_2_4_negative_cap() -> void:
	# AC-2.4: negative side of the cap. The catalogue has only two FEAR -1.0
	# traits, so W is raised to 0.50 (valid config): -1.0 x 0.50 => -1.00 ->
	# clamped to -0.50, proving the negative cap with available data.
	GameConfig.conversion.trait_modifier_weight = 0.5
	var npc := _ensure_npc(["intellectually_restless", "proud"])
	assert_almost_eq(_subtotal(npc, FEAR), -0.50, EPS, "AC-2.4 two -1.0 traits @W=0.5 => -0.50 (capped)")


func _subtotal(p_npc: NpcRecord, p_approach := GRIEF) -> float:
	var bd := ConversionLogicEngine.get_probability_breakdown(p_npc.npc_id, p_approach)
	return float(bd["trait_subtotal"])


func test_ac_2_5_zero_affinity() -> void:
	# AC-2.5: traits at 0.0 affinity => subtotal 0.0.
	var npc := _ensure_npc(["cynical", "dutiful"])
	assert_almost_eq(_subtotal(npc), 0.0, EPS, "AC-2.5 zero-affinity traits => 0.0")


func test_ac_2_6_empty_trait_list_ec_6() -> void:
	# AC-2.6 / EC-6: empty assigned_traits degrades cleanly to 0.0; resolve()
	# completes without error.
	var npc := _ensure_npc([])
	assert_almost_eq(_subtotal(npc), 0.0, EPS, "AC-2.6 empty traits => 0.0")
	var outcome := ConversionLogicEngine.resolve(GRIEF, NPC_ID, RNGHelpers.make_seeded(33))
	assert_true(outcome >= GameEnums.ConversionOutcome.PERSUADED
		and outcome <= GameEnums.ConversionOutcome.HARDENED,
		"AC-2.6 resolve on empty traits must return a valid outcome")


func test_ac_2_7_widow_grief_worked_example() -> void:
	# AC-2.7: GDD worked example — bereaved(+1.0) lonely(+1.0)
	# mortal_minded(+0.5) superstitious(0.0) vs GRIEF => sum 0.625 -> 0.50.
	var npc := _ensure_npc(["bereaved", "lonely", "mortal_minded", "superstitious"])
	assert_almost_eq(_subtotal(npc), 0.50, EPS, "AC-2.7 Widow/GRIEF => +0.50 (0.625 clamped)")


# --- AC-3: Formula 2 — belief state modifier ---------------------------------

func _belief_mod(p_belief: int) -> float:
	var npc := _ensure_npc([], p_belief)
	var bd := ConversionLogicEngine.get_probability_breakdown(npc.npc_id, GRIEF)
	return float(bd["belief_modifier"])


func test_ac_3_1_steadfast_belief_modifier() -> void:
	assert_almost_eq(_belief_mod(STEADFAST), 0.0, EPS, "AC-3.1 STEADFAST => 0.0")


func test_ac_3_2_open_belief_modifier() -> void:
	assert_almost_eq(_belief_mod(OPEN), 0.10, EPS, "AC-3.2 OPEN => +0.10")


func test_ac_3_3_wavering_belief_modifier() -> void:
	assert_almost_eq(_belief_mod(WAVERING), 0.20, EPS, "AC-3.3 WAVERING => +0.20")


func test_ac_3_4_converted_fallback_ec_4() -> void:
	# AC-3.4 / EC-4: CONVERTED => 0.0 + warning + valid outcome.
	var npc := _ensure_npc([], CONVERTED)
	var bd := ConversionLogicEngine.get_probability_breakdown(npc.npc_id, GRIEF)
	assert_almost_eq(float(bd["belief_modifier"]), 0.0, EPS,
		"AC-3.4 CONVERTED treated as STEADFAST => 0.0")
	assert_push_warning("EC-4")
	var outcome := ConversionLogicEngine.resolve(GRIEF, NPC_ID, RNGHelpers.make_seeded(99))
	assert_true(outcome >= GameEnums.ConversionOutcome.PERSUADED
		and outcome <= GameEnums.ConversionOutcome.HARDENED,
		"AC-3.4 resolve on CONVERTED must still return a valid outcome")
	assert_push_warning("EC-4")


# --- AC-4: Formula 3 — repeat approach penalty -------------------------------

func _repeat_penalty(p_history: Dictionary) -> float:
	var npc := _ensure_npc([], STEADFAST, p_history)
	var bd := ConversionLogicEngine.get_probability_breakdown(npc.npc_id, GRIEF)
	return float(bd["repeat_penalty"])


func test_ac_4_1_first_use_no_penalty() -> void:
	assert_almost_eq(_repeat_penalty({}), 0.0, EPS, "AC-4.1 first use => 0.0")


func test_ac_4_2_second_use() -> void:
	assert_almost_eq(_repeat_penalty({GRIEF: 1}), 0.05, EPS, "AC-4.2 second use => 0.05")


func test_ac_4_3_cap_at_third_use() -> void:
	assert_almost_eq(_repeat_penalty({GRIEF: 3}), 0.15, EPS, "AC-4.3 cap at third use => 0.15")


func test_ac_4_4_cap_holds_beyond_third_use() -> void:
	assert_almost_eq(_repeat_penalty({GRIEF: 10}), 0.15, EPS, "AC-4.4 10 uses => 0.15 (cap holds)")


func test_ac_4_5_zero_weight_penalty_config() -> void:
	# AC-4.5: repeat_penalty_per_use = 0.0 => penalty 0.0 at any count.
	GameConfig.conversion.repeat_penalty_per_use = 0.0
	assert_almost_eq(_repeat_penalty({GRIEF: 7}), 0.0, EPS, "AC-4.5 zero per-use weight => 0.0")


# --- AC-5: Formula 4 — final conversion probability --------------------------

func _p_final(p_traits: Array[String] = [], p_belief: int = STEADFAST,
		p_history: Dictionary = {}, p_approach := GRIEF) -> float:
	var npc := _ensure_npc(p_traits, p_belief, p_history)
	var bd := ConversionLogicEngine.get_probability_breakdown(npc.npc_id, p_approach)
	return float(bd["p_final"])


func test_ac_5_1_neutral_baseline() -> void:
	assert_almost_eq(_p_final(["cynical", "dutiful"]), 0.35, EPS, "AC-5.1 neutral baseline => 0.35")


func test_ac_5_2_floor_enforced() -> void:
	# P_raw = 0.35 + (-0.375) + 0 - 0 = -0.025 < floor => P_final 0.05.
	assert_almost_eq(_p_final(["ambitious", "proud", "status_hungry"]), 0.05, EPS,
		"AC-5.2 floor enforced => 0.05")


func test_ac_5_3_ceiling_enforced() -> void:
	# WAVERING + four FEAR+1.0 traits: 0.35 + 0.50 + 0.20 = 1.05 => P_final 0.80.
	assert_almost_eq(_p_final(["fearful", "mortal_minded", "superstitious", "visionary"], WAVERING, {}, FEAR),
		0.80, EPS, "AC-5.3 ceiling enforced => 0.80")


func test_ac_5_4_max_theoretical_praw_clamped() -> void:
	# AC-5.4: P_raw = 1.05 exactly => clamped to 0.80.
	var npc := _ensure_npc(["fearful", "mortal_minded", "superstitious", "visionary"], WAVERING)
	var bd := ConversionLogicEngine.get_probability_breakdown(npc.npc_id, FEAR)
	assert_almost_eq(float(bd["p_raw"]), 1.05, EPS, "AC-5.4 max theoretical P_raw = 1.05")
	assert_almost_eq(float(bd["p_final"]), 0.80, EPS, "AC-5.4 … clamps to 0.80")


func test_ac_5_5_min_theoretical_praw_clamped() -> void:
	# AC-5.5: P_raw = -0.30 exactly => clamped to 0.05. Negative cap reached with
	# W=0.5 on the two FEAR -1.0 traits; penalty capped at 0.15.
	GameConfig.conversion.trait_modifier_weight = 0.5
	var npc := _ensure_npc(["intellectually_restless", "proud"], STEADFAST, {FEAR: 3})
	var bd := ConversionLogicEngine.get_probability_breakdown(npc.npc_id, FEAR)
	assert_almost_eq(float(bd["p_raw"]), -0.30, EPS, "AC-5.5 min theoretical P_raw = -0.30")
	assert_almost_eq(float(bd["p_final"]), 0.05, EPS, "AC-5.5 … clamps to 0.05")


func test_ac_5_6_four_component_sum() -> void:
	# AC-5.6: 0.35 base + 0.25 subtotal (bereaved) + 0.10 OPEN - 0.05 repeat = 0.65.
	var npc := _ensure_npc(["bereaved"], OPEN, {GRIEF: 1})
	var bd := ConversionLogicEngine.get_probability_breakdown(npc.npc_id, GRIEF)
	assert_almost_eq(float(bd["p_raw"]), 0.65, EPS, "AC-5.6 four-component sum => 0.65")
	assert_almost_eq(float(bd["p_final"]), 0.65, EPS, "AC-5.6 P_final within tolerance")


# --- AC-6: Formula 5 — outcome resolution ------------------------------------

func test_ac_6_1_persuaded_zone() -> void:
	# AC-6.1: P_final 0.60 (bereaved); roll in [0, 0.60) => PERSUADED.
	_ensure_npc(["bereaved"])
	var seed := _seed_for_first_roll_in(0.0, 0.60)
	var outcome := ConversionLogicEngine.resolve(GRIEF, NPC_ID, RNGHelpers.make_seeded(seed))
	assert_eq(outcome, GameEnums.ConversionOutcome.PERSUADED,
		"AC-6.1 roll %.6f < P_final 0.60 => PERSUADED" % _first_roll(seed))


func test_ac_6_2_softened_zone() -> void:
	# AC-6.2: P_final 0.60; roll in [0.60, 0.60 + softened) => SOFTENED.
	_ensure_npc(["bereaved"])
	var bounds := _zone_bounds(0.60)
	var seed := _seed_for_first_roll_in(bounds["persuaded_hi"] + EPS, bounds["softened_hi"] - EPS)
	var outcome := ConversionLogicEngine.resolve(GRIEF, NPC_ID, RNGHelpers.make_seeded(seed))
	assert_eq(outcome, GameEnums.ConversionOutcome.SOFTENED,
		"AC-6.2 roll %.6f in SOFTENED zone => SOFTENED" % _first_roll(seed))


func test_ac_6_3_resisted_zone() -> void:
	# AC-6.3: P_final 0.60; roll in [0.60 + softened, … + resisted) => RESISTED.
	_ensure_npc(["bereaved"])
	var bounds := _zone_bounds(0.60)
	var seed := _seed_for_first_roll_in(bounds["softened_hi"] + EPS, bounds["resisted_hi"] - EPS)
	var outcome := ConversionLogicEngine.resolve(GRIEF, NPC_ID, RNGHelpers.make_seeded(seed))
	assert_eq(outcome, GameEnums.ConversionOutcome.RESISTED,
		"AC-6.3 roll %.6f in RESISTED zone => RESISTED" % _first_roll(seed))


func test_ac_6_4_hardened_zone() -> void:
	# AC-6.4: HARDENED zone. NOTE: the shipped defaults (0.545+0.455=1.0) leave
	# HARDENED mathematically empty, so resisted_band_fraction is set to 0.35
	# (sum 0.895 < 1) for a real hardened tail: P_final 0.05 -> hardened zone
	# [0.90025, 1.0); roll 0.99-equivalent => HARDENED.
	GameConfig.conversion.resisted_band_fraction = 0.35
	_ensure_npc(["ambitious", "proud", "status_hungry"])  # P_final 0.05
	var bounds := _zone_bounds(0.05)
	# hardened zone = [resisted_hi, 1.0); scan inside with a small margin.
	var seed := _seed_for_first_roll_in(bounds["resisted_hi"] + 0.001, 1.0)
	var roll := _first_roll(seed)
	assert_gt(roll, bounds["resisted_hi"], "AC-6.4 roll must sit above the RESISTED ceiling")
	var outcome := ConversionLogicEngine.resolve(GRIEF, NPC_ID, RNGHelpers.make_seeded(seed))
	assert_eq(outcome, GameEnums.ConversionOutcome.HARDENED, "AC-6.4 roll in HARDENED zone => HARDENED")


func test_ac_6_5_no_hardened_at_ceiling_1000_rolls() -> void:
	# AC-6.5: P_final 0.80 (defaults) => HARDENED zone is 0; 1000 seeded rolls
	# must never produce HARDENED (GDD "HARDENED is impossible at the ceiling").
	_ensure_npc(["fearful", "mortal_minded", "superstitious", "visionary"], WAVERING)
	var rng := RNGHelpers.make_seeded(20260818)
	var hardened := 0
	var persuaded := 0
	var softened := 0
	var resisted := 0
	for i in 1000:
		var outcome := ConversionLogicEngine.resolve(FEAR, NPC_ID, rng)
		match outcome:
			GameEnums.ConversionOutcome.PERSUADED:
				persuaded += 1
			GameEnums.ConversionOutcome.SOFTENED:
				softened += 1
			GameEnums.ConversionOutcome.RESISTED:
				resisted += 1
			_:
				hardened += 1
	assert_eq(hardened, 0, "AC-6.5 1000 rolls at ceiling => zero HARDENED")
	assert_gt(persuaded, 0, "AC-6.5 PERSUADED must appear (~80%)")
	assert_gt(softened, 0, "AC-6.5 SOFTENED must appear (~11%)")
	assert_gt(resisted, 0, "AC-6.5 RESISTED must appear (~9%)")


func test_ac_6_6_boundary_roll_equals_p_final_softened() -> void:
	# AC-6.6 / AC-7.6 (EC-10): a roll EXACTLY equal to P_final belongs to
	# SOFTENED, not PERSUADED (strict `<` on the first comparison). We force
	# roll == P_final by setting base_success_chance to the seed's first roll.
	var seed := _seed_for_first_roll_in(0.1, 0.9)
	var roll := _first_roll(seed)
	GameConfig.conversion.base_success_chance = roll
	_ensure_npc(["cynical", "dutiful"])  # neutral traits => P_final == base == roll
	var outcome := ConversionLogicEngine.resolve(GRIEF, NPC_ID, RNGHelpers.make_seeded(seed))
	assert_eq(outcome, GameEnums.ConversionOutcome.SOFTENED,
		"AC-6.6 roll == P_final (%.6f) must be SOFTENED, never PERSUADED" % roll)


func test_ac_6_7_four_outcomes_distribution_10k() -> void:
	# AC-6.7: 10,000 seeded rolls at P_final 0.35 must produce all four outcomes
	# and match expected bands within +/-3 percentage points. GDD-default bands
	# (0.545+0.455) make HARDENED empty, so this test uses softened 0.5 /
	# resisted 0.3 (sum 0.8 < 1) per the flagged GDD contradiction: expected
	# P 35.0% / S 32.5% / R 19.5% / H 13.0%.
	GameConfig.conversion.softened_band_fraction = 0.5
	GameConfig.conversion.resisted_band_fraction = 0.3
	_ensure_npc(["cynical", "dutiful"])  # neutral => P_final 0.35
	var rng := RNGHelpers.make_seeded(12_345_678)
	var counts := {0: 0, 1: 0, 2: 0, 3: 0}
	for i in 10000:
		var outcome := ConversionLogicEngine.resolve(GRIEF, NPC_ID, rng)
		counts[int(outcome)] += 1
	assert_between(counts[0], 3200, 3800, "AC-6.7 PERSUADED 35% +/-3pp")
	assert_between(counts[1], 2950, 3550, "AC-6.7 SOFTENED 32.5% +/-3pp")
	assert_between(counts[2], 1650, 2250, "AC-6.7 RESISTED 19.5% +/-3pp")
	assert_between(counts[3], 1000, 1600, "AC-6.7 HARDENED 13% +/-3pp")


# --- AC-7: edge case handling ------------------------------------------------

func test_ac_7_1_negative_hardened_floor_clamp() -> void:
	# AC-7.1 / EC-1: with the shipped defaults the HARDENED zone is 0 by
	# construction; the floor clamp guarantees it never goes negative from
	# IEEE-754 rounding. 1000 seeded rolls => zero HARDENED, no crash.
	_ensure_npc(["cynical", "dutiful"])
	var bd := ConversionLogicEngine.get_probability_breakdown(NPC_ID, GRIEF)
	var hardened_frac := float(bd["hardened_fraction"])
	assert_true(hardened_frac >= 0.0, "AC-7.1 hardened fraction must be floor-clamped >= 0")
	assert_true(hardened_frac <= 1e-9, "AC-7.1 hardened fraction is 0 at default bands")
	var rng := RNGHelpers.make_seeded(555_555)
	for i in 1000:
		var outcome := ConversionLogicEngine.resolve(GRIEF, NPC_ID, rng)
		assert_ne(outcome, GameEnums.ConversionOutcome.HARDENED,
			"AC-7.1 no HARDENED possible when band fractions sum to 1.0")


func test_ac_7_2_band_fractions_over_one_clamp() -> void:
	# AC-7.2 / EC-2: 0.7 + 0.7 > 1.0 => error logged, resisted clamped to 0.30,
	# resolve still returns a valid outcome.
	GameConfig.conversion.softened_band_fraction = 0.7
	GameConfig.conversion.resisted_band_fraction = 0.7
	_ensure_npc(["cynical", "dutiful"])
	var outcome := ConversionLogicEngine.resolve(GRIEF, NPC_ID, RNGHelpers.make_seeded(77))
	assert_push_error("EC-2")
	assert_true(outcome >= GameEnums.ConversionOutcome.PERSUADED
		and outcome <= GameEnums.ConversionOutcome.HARDENED,
		"AC-7.2 resolve must return a valid outcome after the EC-2 clamp")
	var bd := ConversionLogicEngine.get_probability_breakdown(NPC_ID, GRIEF)
	assert_push_error("EC-2")
	assert_almost_eq(float(bd["softened_fraction"]), 0.70, EPS, "AC-7.2 softened stays 0.70")
	assert_almost_eq(float(bd["resisted_fraction"]), 0.30, EPS, "AC-7.2 resisted clamped to 0.30")


func test_ac_7_3_unknown_npc_resisted() -> void:
	# AC-7.3 / EC-3: unknown id => error naming the id + RESISTED sentinel.
	var outcome := ConversionLogicEngine.resolve(GRIEF, "nonexistent_id", RNGHelpers.make_seeded(5))
	assert_push_error("nonexistent_id")
	assert_eq(outcome, GameEnums.ConversionOutcome.RESISTED, "AC-7.3 unknown NPC => RESISTED")


func test_ac_7_4_null_config_resisted() -> void:
	# AC-7.4 / EC-5: a null GameConfig.conversion => error + RESISTED. (Typed
	# float fields cannot be nulled directly, so the whole domain is nulled —
	# the testable equivalent of a missing required field.)
	_ensure_npc(["cynical", "dutiful"])
	var saved: ConversionConfig = GameConfig.conversion
	GameConfig.conversion = null
	var outcome := ConversionLogicEngine.resolve(GRIEF, NPC_ID, RNGHelpers.make_seeded(6))
	assert_push_error("null")
	assert_eq(outcome, GameEnums.ConversionOutcome.RESISTED, "AC-7.4 null config => RESISTED")
	GameConfig.conversion = saved


func test_ac_7_5_invalid_approach_resisted() -> void:
	# AC-7.5 / EC-9: an out-of-enum approach => error + RESISTED.
	_ensure_npc(["bereaved"])
	var outcome := ConversionLogicEngine.resolve(99, NPC_ID, RNGHelpers.make_seeded(8))
	assert_push_error("EC-9")
	assert_eq(outcome, GameEnums.ConversionOutcome.RESISTED, "AC-7.5 invalid approach => RESISTED")


# --- AC-8: API contract ------------------------------------------------------

func test_ac_8_1_signature_compiles_and_autoload_available() -> void:
	# AC-8.1 + AC-8.2: the full typed signature compiles and the autoload is
	# callable from any script (this test file itself is the proof).
	_ensure_npc(["bereaved"])
	assert_true(ConversionLogicEngine.has_method("resolve"), "AC-8.2 resolve is exposed on the autoload")
	var outcome: GameEnums.ConversionOutcome = ConversionLogicEngine.resolve(
		GameEnums.DialogueApproach.GRIEF, NPC_ID, RNGHelpers.make_seeded(1))
	assert_true(outcome >= GameEnums.ConversionOutcome.PERSUADED
		and outcome <= GameEnums.ConversionOutcome.HARDENED,
		"AC-8.1 resolve returns a typed ConversionOutcome")
	assert_true(ConversionLogicEngine.has_method("get_probability"), "read helper present")
	assert_true(ConversionLogicEngine.has_method("get_probability_breakdown"), "read helper present")


func test_ac_8_3_both_caller_stubs_succeed() -> void:
	# AC-8.3: a Dialogue & Conversion System-shaped stub and a Rival Faith
	# System-shaped stub drive resolve() in the same test run with no shared
	# state leakage (each stub owns its RNG and its own result log; the CLE is
	# stateless so nothing can bleed between the two callers).
	var DcsScript := preload("res://tests/unit/conversion_logic_engine/stub_dcs_shaped.gd")
	var RfsScript := preload("res://tests/unit/conversion_logic_engine/stub_rfs_shaped.gd")
	var dcs := DcsScript.new()
	var rfs := RfsScript.new()
	_ensure_npc(["bereaved", "lonely"], WAVERING)
	var dcs_outcome := dcs.resolve_for_caller(GRIEF, NPC_ID, RNGHelpers.make_seeded(41))
	var rfs_outcome := rfs.resolve_for_caller(FEAR, NPC_ID, RNGHelpers.make_seeded(42))
	assert_true(dcs_outcome >= GameEnums.ConversionOutcome.PERSUADED
		and dcs_outcome <= GameEnums.ConversionOutcome.HARDENED,
		"AC-8.3 DCS-shaped stub got a valid outcome")
	assert_true(rfs_outcome >= GameEnums.ConversionOutcome.PERSUADED
		and rfs_outcome <= GameEnums.ConversionOutcome.HARDENED,
		"AC-8.3 RFS-shaped stub got a valid outcome")
	# Each stub applied its own outcome to the shared NPC — that's the resolved
	# result being mutated downstream, NOT the CLE writing state. Assert the
	# stubs' own logs stayed independent.
	assert_eq(dcs.resolutions.size(), 1, "DCS stub logged exactly one resolution")
	assert_eq(rfs.resolutions.size(), 1, "RFS stub logged exactly one resolution")
	assert_eq(dcs.resolutions[0], dcs_outcome, "DCS stub log matches its outcome")
	assert_eq(rfs.resolutions[0], rfs_outcome, "RFS stub log matches its outcome")


func test_ac_8_4_read_at_call_time() -> void:
	# AC-8.4: changing a GameConfig.conversion field between identical calls
	# changes P_final — values are pulled at call time, never cached.
	_ensure_npc(["cynical", "dutiful"])
	var before := ConversionLogicEngine.get_probability(NPC_ID, GRIEF)
	assert_almost_eq(before, 0.35, EPS, "baseline P_final 0.35")
	GameConfig.conversion.base_success_chance = 0.55
	var after := ConversionLogicEngine.get_probability(NPC_ID, GRIEF)
	assert_almost_eq(after, 0.55, EPS, "P_final must reflect the new base at call time")
	assert_ne(after, before, "AC-8.4 changed config field => different P_final (no caching)")


# --- standalone edge cases (EC-6/7/9/11/13) ----------------------------------

func test_ec_7_zero_trait_weight_config() -> void:
	# EC-7: W = 0.0 is valid configuration — subtotal 0.0, no warning.
	GameConfig.conversion.trait_modifier_weight = 0.0
	_ensure_npc(["bereaved", "lonely"])
	var bd := ConversionLogicEngine.get_probability_breakdown(NPC_ID, GRIEF)
	assert_almost_eq(float(bd["trait_subtotal"]), 0.0, EPS, "EC-7 W=0 => subtotal 0.0")
	assert_push_warning_count(0, "EC-7 must NOT log a warning")


func test_ec_11_resisted_pair_contract() -> void:
	# EC-11: RESISTED is a spent approach with no benefit — belief unchanged,
	# but the DCD finally-block still registers the attempt. Prove the pair
	# (resolve -> apply) for a seeded roll that lands in the RESISTED zone.
	_ensure_npc(["cynical", "dutiful"])  # P_final 0.35; RESISTED zone [0.70425, 1.0)
	var bounds := _zone_bounds(0.35)
	var seed := _seed_for_first_roll_in(bounds["softened_hi"] + EPS, bounds["resisted_hi"] - EPS)
	var outcome := ConversionLogicEngine.resolve(GRIEF, NPC_ID, RNGHelpers.make_seeded(seed))
	assert_eq(outcome, GameEnums.ConversionOutcome.RESISTED, "seeded roll must be RESISTED")
	NPCRegistry.apply_conversion_outcome(NPC_ID, outcome, GRIEF)
	var npc := NPCRegistry.get_npc(NPC_ID)
	assert_eq(npc.belief_state, STEADFAST, "EC-11 RESISTED never advances belief")
	assert_eq(int(npc.approach_history.get(GRIEF, 0)), 1, "EC-11 attempt still registers (finally-block)")
	assert_eq(npc.approach_count, 1, "EC-11 approach count still increments")
	assert_eq(npc.cooldown_turns_remaining, GameConfig.conversion.approach_cooldown_turns,
		"EC-11 cooldown still set")


func test_ec_13_history_at_max_approaches() -> void:
	# EC-13: resolve() is bounded by NPCRegistry's max_approaches_per_npc
	# counter, not by the Engine — here a record already at the cap resolves
	# cleanly and the repeat penalty caps at max_repeat_penalty.
	var npc := _ensure_npc([], STEADFAST, {GRIEF: GameConfig.conversion.max_approaches_per_npc})
	var bd := ConversionLogicEngine.get_probability_breakdown(npc.npc_id, GRIEF)
	assert_almost_eq(float(bd["repeat_penalty"]), 0.15, EPS,
		"EC-13 penalty capped at 0.15 even at the max-approach boundary")
	var outcome := ConversionLogicEngine.resolve(GRIEF, NPC_ID, RNGHelpers.make_seeded(13))
	assert_true(outcome >= GameEnums.ConversionOutcome.PERSUADED
		and outcome <= GameEnums.ConversionOutcome.HARDENED,
		"EC-13 resolve completes with a valid outcome at the boundary")