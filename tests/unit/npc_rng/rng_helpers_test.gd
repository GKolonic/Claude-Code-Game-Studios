extends GutTest
## RNGHelpers unit suite — Sprint 2 task 2-5 (QA plan RG-1..6 + edge cases).
## Verifies ADR-0007's determinism contract for the single RNG abstraction
## at src/systems/npc/rng_helpers.gd:
##   RG-1  same seed -> identical 100-call draw sequence
##   RG-2  different seeds diverge within 100 calls
##   RG-3  weighted draw respects 60/30/10 rarity bands within +/-3%
##         (equal-count synthetic pool, mirroring trait-db AC-4) + real
##         16-catalogue share sanity
##   RG-4  draw_without_replacement never duplicates (TR-TDB-010)
##   RG-5  random_int_inclusive bounds inclusive; out-of-order swap
##   RG-6  no global/shared mutable RNG state (functional isolation proof;
##         static REG-3 grep runs in verification)
##   Edge  max==min, empty pool, pool smaller than draw count, zero-sum pool
## All draws use explicit seeds — no global RNG anywhere (ADR-0007).


# --- RG-1 / RG-2: seed determinism ------------------------------------------

func test_rg_1_same_seed_identical_100_call_sequence() -> void:
	# RG-1: two RNGs with the same seed must produce byte-identical output
	# for a 100-call mixed draw sequence (per ADR-0007 same-engine-version
	# contract, pinned to 4.6.stable.official.89cea1439).
	var seq_a: Array = []
	var seq_b: Array = []
	var rng_a := RNGHelpers.make_seeded(424_242)
	var rng_b := RNGHelpers.make_seeded(424_242)
	for i in 50:
		seq_a.append(RNGHelpers.random_int_inclusive(rng_a, 0, 100))
		seq_b.append(RNGHelpers.random_int_inclusive(rng_b, 0, 100))
	for i in 25:
		var pool_a := [{"id": "x", "weight": 1.0}, {"id": "y", "weight": 2.0}]
		var pool_b := [{"id": "x", "weight": 1.0}, {"id": "y", "weight": 2.0}]
		seq_a.append(RNGHelpers.weighted_random_choice(rng_a, pool_a))
		seq_b.append(RNGHelpers.weighted_random_choice(rng_b, pool_b))
	for i in 25:
		seq_a.append(RNGHelpers.uniform_roll(rng_a))
		seq_b.append(RNGHelpers.uniform_roll(rng_b))
	assert_eq(seq_a.size(), 100, "sequence must contain exactly 100 draws")
	assert_eq(seq_b.size(), 100, "sequence must contain exactly 100 draws")
	for i in 100:
		assert_eq(seq_a[i], seq_b[i],
			"draw %d must be identical across same-seed RNGs" % i)


func test_rg_2_different_seeds_diverge() -> void:
	# RG-2: two RNGs with different seeds produce different streams; the
	# first differing value must occur within 100 draws (independent PCG32
	# streams seeded differently can theoretically collide on a single value
	# but not on the whole sequence).
	var rng_a := RNGHelpers.make_seeded(1)
	var rng_b := RNGHelpers.make_seeded(2)
	var first_diff := -1
	for i in 100:
		if RNGHelpers.uniform_roll(rng_a) != RNGHelpers.uniform_roll(rng_b):
			first_diff = i
			break
	assert_ne(first_diff, -1, "different seeds must diverge within 100 draws")
	assert_lt(first_diff, 100, "divergence must occur within the draw window")


# --- RG-3: weighted rarity bands ---------------------------------------------

func _rarity_weight(p_rarity: GameEnums.TraitRarity) -> int:
	match p_rarity:
		GameEnums.TraitRarity.COMMON:
			return GameConfig.traits.common_trait_weight
		GameEnums.TraitRarity.UNCOMMON:
			return GameConfig.traits.uncommon_trait_weight
		_:
			return GameConfig.traits.rare_trait_weight


## Builds an equal-count synthetic weighted pool (8C/8U/8R) with the
## GameConfig rarity weights — the trait-db AC-4 band-test shape.
func _make_equal_pool() -> Array:
	var pool: Array = []
	for i in 8:
		pool.append({"id": "c%d" % i, "weight": float(_rarity_weight(GameEnums.TraitRarity.COMMON)),
			"rarity": GameEnums.TraitRarity.COMMON})
		pool.append({"id": "u%d" % i, "weight": float(_rarity_weight(GameEnums.TraitRarity.UNCOMMON)),
			"rarity": GameEnums.TraitRarity.UNCOMMON})
		pool.append({"id": "r%d" % i, "weight": float(_rarity_weight(GameEnums.TraitRarity.RARE)),
			"rarity": GameEnums.TraitRarity.RARE})
	return pool


func test_rg_3_weighted_draw_respects_603010_bands() -> void:
	# RG-3: 10,000 seeded single draws from an equal-count 8C/8U/8R pool
	# with 60/30/10 weights: COMMON 57-63%, UNCOMMON 27-33%, RARE 8-12%
	# (mirrors trait-db AC-4 band bounds, QA plan RG-3).
	assert_eq([GameConfig.traits.common_trait_weight,
		GameConfig.traits.uncommon_trait_weight,
		GameConfig.traits.rare_trait_weight], [60, 30, 10],
		"default rarity weights must be 60/30/10 for this band test")
	var rng := RNGHelpers.make_seeded(12_345_678)
	var counts := {GameEnums.TraitRarity.COMMON: 0, GameEnums.TraitRarity.UNCOMMON: 0,
		GameEnums.TraitRarity.RARE: 0}
	for i in 10_000:
		var pool := _make_equal_pool()
		var picked: Dictionary = RNGHelpers.weighted_random_choice(rng, pool)
		counts[picked["rarity"]] += 1
	var common_pct: float = float(counts[GameEnums.TraitRarity.COMMON]) / 10_000.0 * 100.0
	var uncommon_pct: float = float(counts[GameEnums.TraitRarity.UNCOMMON]) / 10_000.0 * 100.0
	var rare_pct: float = float(counts[GameEnums.TraitRarity.RARE]) / 10_000.0 * 100.0
	assert_between(common_pct, 57.0, 63.0,
		"COMMON share must be 57-63%% (RG-3), got %.2f" % common_pct)
	assert_between(uncommon_pct, 27.0, 33.0,
		"UNCOMMON share must be 27-33%% (RG-3), got %.2f" % uncommon_pct)
	assert_between(rare_pct, 8.0, 12.0,
		"RARE share must be 8-12%% (RG-3), got %.2f" % rare_pct)


func test_rg_3_real_16_pool_share_sanity() -> void:
	# RG-3 supplemental: the REAL 16-trait catalogue pool (base rarity
	# weights only, no archetype bonuses) must pick each trait with a
	# share proportional to its weight. Theoretical weighted share for a
	# single pick: weight(t) / sum(all weights). Assert observed share
	# within +/-3 percentage points over 10,000 picks (deterministic seed).
	var traits: Array = TraitDatabase.get_all_traits()
	assert_eq(traits.size(), 16, "catalogue must be the 16-trait MVP set")
	var total_weight := 0.0
	for t in traits:
		total_weight += float(_rarity_weight(t.rarity))
	var rng := RNGHelpers.make_seeded(98_765)
	var observed := {}
	for i in 10_000:
		var pool: Array = []
		for t in traits:
			pool.append({"id": t.id, "weight": float(_rarity_weight(t.rarity))})
		var picked: Dictionary = RNGHelpers.weighted_random_choice(rng, pool)
		observed[picked["id"]] = observed.get(picked["id"], 0) + 1
	for t in traits:
		var expected_share: float = float(_rarity_weight(t.rarity)) / total_weight
		var observed_share: float = float(observed.get(t.id, 0)) / 10_000.0
		assert_between(observed_share, expected_share - 0.03, expected_share + 0.03,
			"trait '%s' observed share %.3f must be within +/-3pp of expected %.3f" %
			[t.id, observed_share, expected_share])


# --- RG-4: draw without replacement never duplicates -------------------------

func test_rg_4_draw_without_replacement_never_duplicates() -> void:
	# RG-4: drawing N from a pool of size M >= N yields N unique ids.
	# Multiple draws per seed; every id appears at most once per draw.
	var rng := RNGHelpers.make_seeded(55_555)
	for trial in 30:
		var pool := _make_equal_pool()
		var picked: Array = RNGHelpers.draw_without_replacement(rng, pool, 6)
		assert_eq(picked.size(), 6, "draw must return exactly 6 entries")
		var seen := {}
		for entry in picked:
			var id: String = entry["id"]
			assert_false(seen.has(id), "duplicate id '%s' in draw %d (TR-TDB-010)" % [id, trial])
			seen[id] = true
		assert_eq(pool.size(), 24 - 6, "pool must shrink by exactly the draw count")


func test_rg_4_full_pool_drain_no_duplicates() -> void:
	# RG-4: drawing the ENTIRE pool must consume every entry exactly once.
	var rng := RNGHelpers.make_seeded(77_777)
	var pool := _make_equal_pool()
	var picked: Array = RNGHelpers.draw_without_replacement(rng, pool, 24)
	assert_eq(picked.size(), 24, "full drain must return every entry")
	assert_true(pool.is_empty(), "full drain must empty the pool")
	var seen := {}
	for entry in picked:
		assert_false(seen.has(entry["id"]), "full drain must never duplicate")
		seen[entry["id"]] = true
	assert_eq(seen.size(), 24, "full drain must cover 24 unique ids")


# --- RG-5: random_int_inclusive bounds ---------------------------------------

func test_rg_5_random_int_inclusive_bounds_reachable() -> void:
	# RG-5: over 10,000 calls on [0, 10] both 0 and 10 must be reached.
	# randi_range(from, to) is documented inclusive on the pinned engine;
	# this proves the helper preserves that contract (AC-2 inclusiveness).
	var rng := RNGHelpers.make_seeded(31_337)
	var seen := {}
	var min_seen := false
	var max_seen := false
	for i in 10_000:
		var value := RNGHelpers.random_int_inclusive(rng, 0, 10)
		assert_between(value, 0, 10, "value must stay within inclusive bounds")
		if value == 0:
			min_seen = true
		if value == 10:
			max_seen = true
	assert_true(min_seen, "min bound 0 must be reachable (RG-5)")
	assert_true(max_seen, "max bound 10 must be reachable (RG-5)")


func test_rg_5_random_int_inclusive_max_equals_min() -> void:
	# Edge: max == min always returns that value (dead-range is a constant).
	var rng := RNGHelpers.make_seeded(2)
	for i in 10:
		assert_eq(RNGHelpers.random_int_inclusive(rng, 7, 7), 7,
			"max==min must return the fixed value")


func test_rg_5_random_int_inclusive_out_of_order_swaps() -> void:
	# Edge: min > max is swapped with a warning (ADR-0007: warns, does not
	# crash) — a config/slip input cannot break generation determinism.
	var rng := RNGHelpers.make_seeded(9)
	var value := RNGHelpers.random_int_inclusive(rng, 20, 5)
	assert_between(value, 5, 20, "out-of-order bounds must be swapped and stay inclusive")


# --- RG-6: no shared/global mutable RNG state -------------------------------

func test_rg_6_rng_instances_are_functionally_isolated() -> void:
	# RG-6: two RNGs created separately never interfere — advancing one
	# cannot change the other's stream (proves instances are owned by the
	# caller, not a shared global; the REG-3 static grep in verification
	# covers the code-level guarantee).
	var rng_a := RNGHelpers.make_seeded(1_000)
	var rng_b := RNGHelpers.make_seeded(2_000)
	# Burn 100 draws from A.
	for i in 100:
		RNGHelpers.uniform_roll(rng_a)
	# A fresh same-seed-as-B RNG must match B's FIRST draw — if state were
	# shared/global, the burn on A would have moved it too.
	var rng_b_control := RNGHelpers.make_seeded(2_000)
	assert_eq(RNGHelpers.uniform_roll(rng_b), RNGHelpers.uniform_roll(rng_b_control),
		"RNG instances must be isolated (no shared global state)")


# --- Pool edge cases ---------------------------------------------------------

func test_edge_empty_pool_returns_empty_dict() -> void:
	# Edge: empty pool is a programmer error — warn + return {} (no crash).
	var rng := RNGHelpers.make_seeded(1)
	var picked := RNGHelpers.weighted_random_choice(rng, [])
	assert_eq(picked, {}, "empty pool must return {}")
	assert_eq(RNGHelpers.draw_without_replacement(rng, [], 3), [],
		"empty pool draw must return []")


func test_edge_pool_smaller_than_draw_count_clamps() -> void:
	# Edge: asking for more than the pool size clamps to pool size with a
	# warning (trait-db EC-2 pattern) — never loops forever, never returns
	# null entries.
	var rng := RNGHelpers.make_seeded(3)
	var pool := [{"id": "a", "weight": 1.0}, {"id": "b", "weight": 1.0}]
	var picked: Array = RNGHelpers.draw_without_replacement(rng, pool, 5)
	assert_eq(picked.size(), 2, "oversized draw must clamp to pool size")
	assert_true(pool.is_empty(), "pool must be drained after clamp")


func test_edge_zero_sum_pool_falls_back_uniform() -> void:
	# Edge: all weights zero -> warning + uniform fallback; every entry is
	# still possible and the pool still shrinks (no NaN, no hang).
	var rng := RNGHelpers.make_seeded(4)
	var pool: Array = []
	for i in 4:
		pool.append({"id": "z%d" % i, "weight": 0.0})
	var picked: Dictionary = RNGHelpers.weighted_random_choice(rng, pool)
	assert_true(picked.has("id"), "zero-sum fallback must still return an entry")
	assert_eq(pool.size(), 3, "zero-sum fallback must still erase the picked entry")


func test_edge_negative_weights_clamped() -> void:
	# Edge: a negative weight cannot corrupt the draw — it contributes 0 to
	# the sum and is only reachable via the uniform fallback if ALL weights
	# are non-positive. With a positive sibling, negatives are effectively
	# unpickable.
	var rng := RNGHelpers.make_seeded(5)
	var pool := [{"id": "bad", "weight": -5.0}, {"id": "good", "weight": 1.0}]
	for i in 50:
		var p := RNGHelpers.weighted_random_choice(rng, pool.duplicate())
		assert_eq(p["id"], "good",
			"with a positive-weight sibling, negative-weight entry must never be picked")


func test_edge_uniform_roll_in_expected_range() -> void:
	# uniform_roll must be in [0.0, 1.0) over 5,000 draws (CLE zone
	# resolution depends on strict-< boundaries at 1.0).
	var rng := RNGHelpers.make_seeded(6)
	for i in 5_000:
		var roll := RNGHelpers.uniform_roll(rng)
		assert_true(roll >= 0.0 and roll < 1.0,
			"uniform_roll must be in [0.0, 1.0), got %s" % str(roll))