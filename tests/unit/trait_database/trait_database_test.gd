extends GutTest
## TraitDatabase unit suite — Sprint 1 task 1-11 (NPC Trait Database GDD
## AC-1…AC-11). Uses the live TraitDatabase autoload (slot 2, booted before
## the test runner's scene) for the happy-path ACs, and drives the GDD
## Trait Assignment Formula locally for the statistical ACs (AC-4..6 —
## the formula's owner is the NPC Character System, M2; here the formula
## itself is verified against the shipped catalogue + GameConfig weights).

const EXPECTED_IDS := [
	"bereaved", "ambitious", "superstitious", "proud", "dutiful", "lonely",
	"fearful", "grievously_wronged", "cynical", "status_hungry",
	"mortal_minded", "intellectually_restless", "loyal_to_community",
	"seeker", "broken_by_loss", "visionary",
]

const BANDS := [-1.0, -0.5, 0.0, 0.5, 1.0]


func test_ac_1_database_loads_at_startup() -> void:
	# AC-1: _ready() loaded the catalogue without error; is_loaded() true.
	assert_true(TraitDatabase.is_loaded(),
		"TraitDatabase must be loaded after boot (AC-1)")


func test_ac_2_trait_lookup_by_id_returns_correct_data() -> void:
	# AC-2: get_trait("bereaved") returns the full record per the GDD entry.
	var t: TraitData = TraitDatabase.get_trait("bereaved")
	assert_not_null(t, "bereaved must resolve")
	assert_eq(t.id, "bereaved")
	assert_eq(t.display_name, "Bereaved")
	assert_eq(t.rarity, GameEnums.TraitRarity.COMMON)
	assert_almost_eq(float(t.approach_affinity[GameEnums.DialogueApproach.GRIEF]),
		1.0, 0.0001, "bereaved GRIEF affinity must be +1.0")


func test_ac_3_affinity_times_weight_matches_gdd_example() -> void:
	# AC-3: get_affinity(bereaved, GRIEF) × trait_modifier_weight (0.25) = 0.25.
	var w: float = GameConfig.conversion.trait_modifier_weight
	assert_almost_eq(w, 0.25, 0.0001, "default trait_modifier_weight is 0.25")
	var a: float = TraitDatabase.get_affinity("bereaved", GameEnums.DialogueApproach.GRIEF)
	assert_almost_eq(a * w, 0.25, 0.001,
		"affinity × weight must equal the GDD worked example (+0.25)")


func test_ac_7_unknown_trait_id_returns_null_without_crash() -> void:
	# AC-7: unknown ID -> null, no error.
	assert_null(TraitDatabase.get_trait("nonexistent_trait_id"),
		"unknown trait ID must return null (AC-7)")


func test_ac_8_all_traits_have_four_valid_affinities() -> void:
	# AC-8: every trait carries all four approach keys, each in [-1.0, 1.0].
	# Also asserts the GDD Rule 5 five-band constraint (MVP learnability).
	for t in TraitDatabase.get_all_traits():
		for approach in GameEnums.DialogueApproach.values():
			assert_true(t.approach_affinity.has(approach),
				"trait '%s' must have affinity for approach %d" % [t.id, approach])
			var v: float = float(t.approach_affinity[approach])
			assert_true(v >= -1.0 and v <= 1.0,
				"trait '%s' approach %d affinity %s must be in [-1.0, 1.0]" % [t.id, approach, str(v)])
			assert_has(BANDS, v,
				"trait '%s' approach %d affinity %s must use a 5-band value" % [t.id, approach, str(v)])


func test_ac_9_get_affinity_returns_zero_for_unknown_trait() -> void:
	# AC-9: unknown trait ID -> 0.0, no error.
	assert_eq(TraitDatabase.get_affinity("nonexistent_id", GameEnums.DialogueApproach.GRIEF),
		0.0, "unknown trait affinity must be 0.0 (AC-9)")


func test_ac_10_all_sixteen_mvp_traits_present() -> void:
	# AC-10: catalogue size is exactly 16 and every designed ID resolves.
	assert_eq(TraitDatabase.get_all_traits().size(), 16,
		"catalogue must contain exactly 16 traits (AC-10)")
	for id in EXPECTED_IDS:
		assert_not_null(TraitDatabase.get_trait(id),
			"designed trait '%s' must be present" % id)


func test_ac_11_rarity_distribution_matches_design() -> void:
	# AC-11: 7 COMMON / 6 UNCOMMON / 3 RARE.
	assert_eq(TraitDatabase.get_traits_by_rarity(GameEnums.TraitRarity.COMMON).size(), 7,
		"COMMON count must be 7 (AC-11)")
	assert_eq(TraitDatabase.get_traits_by_rarity(GameEnums.TraitRarity.UNCOMMON).size(), 6,
		"UNCOMMON count must be 6 (AC-11)")
	assert_eq(TraitDatabase.get_traits_by_rarity(GameEnums.TraitRarity.RARE).size(), 3,
		"RARE count must be 3 (AC-11)")


func test_rule_7_get_traits_for_archetype_unions_agnostic() -> void:
	# Rule 7: archetype query returns tagged traits union archetype-agnostic
	# traits; every returned trait is tagged or agnostic.
	var widow: Array[TraitData] = TraitDatabase.get_traits_for_archetype("widow")
	assert_gt(widow.size(), 0, "widow pool must be non-empty")
	for t in widow:
		assert_true(t.archetype_tags.is_empty() or t.archetype_tags.has("widow"),
			"trait '%s' in widow pool must be tagged or agnostic" % t.id)
	# Every MVP trait is tagged, so the widow pool is a strict subset (< 16)
	# and contains at least the widow-tagged commons.
	assert_lt(widow.size(), 16, "widow pool must exclude non-tagged traits")
	assert_true(TraitDatabase.get_traits_for_archetype("nonexistent_archetype").is_empty(),
		"unknown archetype must return an empty pool")


func test_ac_4_trait_assignment_respects_rarity_weights() -> void:
	# AC-4: 10,000 draws from a pool of 8C/8U/8R synthetic traits (equal
	# counts per tier) using the GDD formula + GameConfig default weights
	# (60/30/10): COMMON 57–63%, UNCOMMON 27–33%, RARE 8–12%.
	var pool: Array[TraitData] = []
	for i in 8:
		pool.append(_make_trait("c%d" % i, GameEnums.TraitRarity.COMMON))
		pool.append(_make_trait("u%d" % i, GameEnums.TraitRarity.UNCOMMON))
		pool.append(_make_trait("r%d" % i, GameEnums.TraitRarity.RARE))
	var counts := {GameEnums.TraitRarity.COMMON: 0, GameEnums.TraitRarity.UNCOMMON: 0,
		GameEnums.TraitRarity.RARE: 0}
	var rng := RandomNumberGenerator.new()
	rng.seed = 1_234_567  # deterministic seed — no flakiness
	for i in 10_000:
		var picked := _weighted_pick(pool, rng)
		counts[picked.rarity] += 1
	var total := 10_000.0
	var common_pct: float = counts[GameEnums.TraitRarity.COMMON] / total * 100.0
	var uncommon_pct: float = counts[GameEnums.TraitRarity.UNCOMMON] / total * 100.0
	var rare_pct: float = counts[GameEnums.TraitRarity.RARE] / total * 100.0
	assert_between(common_pct, 57.0, 63.0, "COMMON share must be 57–63%% (AC-4), got %.2f" % common_pct)
	assert_between(uncommon_pct, 27.0, 33.0, "UNCOMMON share must be 27–33%% (AC-4), got %.2f" % uncommon_pct)
	assert_between(rare_pct, 8.0, 12.0, "RARE share must be 8–12%% (AC-4), got %.2f" % rare_pct)


func test_ac_5_and_6_assignment_never_duplicates_and_respects_count() -> void:
	# AC-5/AC-6: run the full GDD Trait Assignment Formula 1,000 times
	# against the live catalogue — no duplicate IDs per NPC and every NPC
	# receives between traits_per_npc_min and traits_per_npc_max traits.
	var min_count: int = GameConfig.traits.traits_per_npc_min
	var max_count: int = GameConfig.traits.traits_per_npc_max
	assert_eq([min_count, max_count], [2, 4], "default trait counts are 2..4")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7_654_321  # deterministic seed — no flakiness
	for npc in 1_000:
		var trait_count: int = rng.randi_range(min_count, max_count)
		var pool: Array[TraitData] = TraitDatabase.get_all_traits().duplicate()
		var assigned: Array[String] = []
		for slot in trait_count:
			var picked := _weighted_pick(pool, rng)
			assigned.append(picked.id)
			pool.erase(picked)  # draw without replacement (EC-1)
		assert_between(assigned.size(), min_count, max_count,
			"NPC must receive %d–%d traits (AC-6)" % [min_count, max_count])
		var seen := {}
		for id in assigned:
			assert_false(seen.has(id), "NPC must never receive duplicate trait '%s' (AC-5)" % id)
			seen[id] = true


# --- helpers ---------------------------------------------------------------

## Builds an in-memory TraitData for the synthetic AC-4 pool.
func _make_trait(p_id: String, p_rarity: GameEnums.TraitRarity) -> TraitData:
	var t := TraitData.new()
	t.id = p_id
	t.display_name = p_id.capitalize()
	t.rarity = p_rarity
	return t


## GDD Trait Assignment Formula Step 2/3: rarity-weighted random choice
## (weights from GameConfig.traits: 60/30/10 by default).
func _weighted_pick(pool: Array[TraitData], rng: RandomNumberGenerator) -> TraitData:
	var total := 0.0
	for t in pool:
		total += _rarity_weight(t.rarity)
	var roll: float = rng.randf() * total
	for t in pool:
		roll -= _rarity_weight(t.rarity)
		if roll < 0.0:
			return t
	return pool.back()


func _rarity_weight(rarity: GameEnums.TraitRarity) -> int:
	match rarity:
		GameEnums.TraitRarity.COMMON:
			return GameConfig.traits.common_trait_weight
		GameEnums.TraitRarity.UNCOMMON:
			return GameConfig.traits.uncommon_trait_weight
		_:
			return GameConfig.traits.rare_trait_weight
