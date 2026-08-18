class_name RNGHelpers
extends RefCounted
## RNGHelpers — the single determinism-critical RNG abstraction (ADR-0007
## Decision 2; architecture §7 ownership: src/systems/npc/rng_helpers.gd).
##
## All determinism-critical randomness in the codebase flows through this
## class. Helpers are STATIC and take the RandomNumberGenerator instance as
## the first parameter — there is NO global/shared mutable RNG state
## anywhere (ADR-0007 guardrail; REG-3 static scan enforces that no
## RandomNumberGenerator / randf / randi usage exists outside this file in
## src/). Each caller owns or threads its instance:
##   - NPCRegistry: one generation RNG per initialize_village() call, seeded
##     from VillageDefinition.rng_seed, dropped at end of generation.
##   - CLE: a per-resolve() RNG passed by the caller (or a fresh
##     entropy-seeded RNG on the nullable default path — never in tests).
##   - Tests: always explicit seeds.
##
## Determinism is a SAME-ENGINE-VERSION contract (ADR-0007 Decision 6,
## R16): streams are pinned to 4.6.stable.official.89cea1439. Do NOT use
## randomize(). Do NOT store RNG instances on Autoloads.


## Sole creation point for seeded RNG. Returns a fresh RandomNumberGenerator
## seeded with seed_value. The caller owns the instance and is responsible
## for dropping it when done (nothing is retained here).
static func make_seeded(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Inclusive integer bounds [min_value, max_value] (Trait Assignment Formula
## Step 1; AC-2/AC-6 trait-count draw). Requires min_value <= max_value —
## an out-of-order call logs a warning and swaps the bounds instead of
## crashing, so a data/config slip cannot break generation determinism.
static func random_int_inclusive(rng: RandomNumberGenerator, min_value: int, max_value: int) -> int:
	assert(rng != null, "RNGHelpers.random_int_inclusive: rng must not be null (ADR-0007 — caller threads its instance)")
	if min_value > max_value:
		push_warning("RNGHelpers: random_int_inclusive got min %d > max %d — swapping bounds (ADR-0007 warns, does not crash)" % [min_value, max_value])
		var tmp := min_value
		min_value = max_value
		max_value = tmp
	return rng.randi_range(min_value, max_value)


## Weighted choice WITHOUT replacement (Trait Assignment Formula Step 3;
## TR-TDB-006): picks one entry from weighted_options by normalized weight,
## then ERASES it from the passed pool so the same entry can never be picked
## again (structural no-duplicate guarantee — TR-TDB-010).
##
## Entries are Dictionaries: { "id": String, "weight": float } per ADR-0007
## Key Interfaces. Weights are normalized against their sum.
##  - Empty pool: programmer error — logs a warning and returns {}.
##  - Zero-sum pool (all weights <= 0): logs a warning and falls back to a
##    uniform pick among remaining entries (ADR-0007 Implementation
##    Guidelines: warn + uniform fallback).
##  - Negative weights are clamped to 0.0 for the sum, so a single bad entry
##    cannot corrupt the draw.
static func weighted_random_choice(rng: RandomNumberGenerator, weighted_options: Array) -> Dictionary:
	assert(rng != null, "RNGHelpers.weighted_random_choice: rng must not be null (ADR-0007 — caller threads its instance)")
	if weighted_options.is_empty():
		push_warning("RNGHelpers.weighted_random_choice: empty pool is a programmer error — returning {}")
		return {}
	var total := 0.0
	for entry in weighted_options:
		var weight := maxf(0.0, float(entry.get("weight", 0.0)))
		total += weight
	if total <= 0.0:
		push_warning("RNGHelpers.weighted_random_choice: zero-sum pool — falling back to uniform pick (ADR-0007)")
		var idx := rng.randi_range(0, weighted_options.size() - 1)
		var picked: Dictionary = weighted_options[idx]
		weighted_options.remove_at(idx)
		return picked
	var roll: float = rng.randf() * total
	for i in weighted_options.size():
		var entry: Dictionary = weighted_options[i]
		roll -= maxf(0.0, float(entry.get("weight", 0.0)))
		if roll < 0.0:
			weighted_options.remove_at(i)
			return entry
	# Floating-point guard: if roll lands exactly on the final boundary,
	# pick the last entry (still removes it — no duplicates possible).
	var last: Dictionary = weighted_options.back()
	weighted_options.pop_back()
	return last


## Draw-without-replacement shortcut over a weighted pool (Trait Assignment
## Formula Step 3 batch form): calls weighted_random_choice `count` times
## against the same pool, erasing each pick. Returns the picked entries as
## an Array of { "id", "weight" } Dictionaries. count is clamped to the pool
## size with a warning when the caller over-asks (trait-db EC-2 equivalent:
## prefer a short NPC over an infinite loop or null assignment).
static func draw_without_replacement(rng: RandomNumberGenerator, weighted_options: Array, count: int) -> Array:
	assert(rng != null, "RNGHelpers.draw_without_replacement: rng must not be null (ADR-0007 — caller threads its instance)")
	var n: int = mini(count, weighted_options.size())
	if n < count:
		push_warning("RNGHelpers.draw_without_replacement: asked for %d but pool has %d — clamping (trait-db EC-2 pattern)" % [count, weighted_options.size()])
	var out: Array = []
	for i in n:
		out.append(weighted_random_choice(rng, weighted_options))
	return out


## CLE uniform roll source: returns a float in [0.0, 1.0) (Godot randf
## semantics). This is the ONLY randomness in a CLE resolve() call (ADR-0007
## Decision 3); everything else in resolve() derives deterministically from
## GameConfig pulls and NPCRegistry state at call time.
static func uniform_roll(rng: RandomNumberGenerator) -> float:
	assert(rng != null, "RNGHelpers.uniform_roll: rng must not be null (ADR-0007 — caller threads its instance; CLE may create a fresh entropy RNG on its null path, never in tests)")
	return rng.randf()