extends Node
## NPCRegistry — Autoload, ADR-0001 slot 5. NPC truth + controlled mutation
## (NPC Character System GDD). Completed at Sprint 2 task 2-6 (was M0 stub).
##
## Owns NPC lifecycle for the current village:
##   - initialize_village(village_def) generates one NpcRecord per definition
##     slot deterministically from VillageDefinition.rng_seed (ADR-0007
##     Decision 1): fixed draw order per NPC = trait_count roll first, then
##     `trait_count` weighted draws from the archetype's deduped weighted
##     pool (Trait Assignment Formula Step 1-3 + Archetype Trait Weight
##     Formula); belief/connections/map data are hand-authored per Rule 8.
##   - apply_conversion_outcome() applies the Rule 5 outcome table; every
##     call registers the approach (cooldown + approach_count +
##     approach_history[approach]) — DCD finally-block contract (Rule 8
##     Step 8) and CLE repeat-penalty dependency (Formula 3 reads
##     approach_history, which must count RESISTED attempts to accrue).
##   - reveal_trait() / trigger_inspect_reveal() per Rule 7 (highest
##     affinity magnitude; ties by index in assigned_traits).
##   - advance_turn() decrements cooldowns + rival grace windows (floor 0),
##     emitting npc_cooldown_expired exactly once per NPC per cycle.
##   - serialize()/deserialize() for SaveLoad (AC-18/19; unknown enums
##     load gracefully: STEADFAST / connection dropped).
##
## RNG ownership (ADR-0007): ALL randomness flows through RNGHelpers; a
## generation RNG is created from village_def.rng_seed inside
## initialize_village() and dropped at the end — nothing is retained.
## This Autoload holds NO mutable RNG state.

const ARCHETYPES_PATH := "res://assets/data/npcs/archetypes.tres"

## Serialized payload version (bumped on breaking schema change at M4).
const SERIALIZE_VERSION := 1

## Archetype enum index -> trait-db slug (NPCArchetype order = SLUGS order).
const ARCHETYPE_SLUGS := [
	"laborer", "elder", "merchant", "soldier", "scholar", "widow", "noble",
]

## Emitted on any belief-state change, exactly once per transition (AC-16);
## never emitted on no-op outcomes (AC-7).
signal npc_state_changed(npc_id: String, old_state: GameEnums.BeliefState, new_state: GameEnums.BeliefState)
## Emitted exactly once per NPC per cooldown cycle — on the advance_turn() call
## that brings cooldown_turns_remaining to 0 (AC-17).
signal npc_cooldown_expired(npc_id: String)
## Emitted on a successful trait reveal (npc_id, trait_id). Ships with zero
## MVP subscribers (ADR-0007 OQ-8); never emitted on a no-op reveal (AC-15).
signal trait_revealed(npc_id: String, trait_id: String)
## Emitted exactly once per successful initialize_village() call.
signal village_initialized()

var _npcs_by_id: Dictionary = {}          # npc_id -> NpcRecord
var _order: Array[NpcRecord] = []         # registration order (deterministic)
var _archetypes_by_id: Dictionary = {}    # NPCArchetype -> NPCArchetypeDefinition
var _village_id := ""
var _archetypes_loaded := false
var _warnings: PackedStringArray = []     # DCD precedent (get_warnings())


func _ready() -> void:
	assert(is_instance_valid(GameConfig),
		"NPCRegistry (slot 5): GameConfig (slot 1) must boot first (ADR-0001)")
	assert(is_instance_valid(TraitDatabase),
		"NPCRegistry (slot 5): TraitDatabase (slot 2) must boot first (ADR-0001)")
	assert(is_instance_valid(DialogueDatabase),
		"NPCRegistry (slot 5): DialogueDatabase (slot 3) must boot first (ADR-0001)")
	assert(is_instance_valid(MobileTouchFramework),
		"NPCRegistry (slot 5): MobileTouchFramework (slot 4) must boot first (ADR-0001)")
	_load_archetypes()


## Loads + indexes the 7 archetype definitions (NPC CS Rule 3 catalogue).
## Production always reads the pinned path; tests inject fixtures via
## _load_archetypes_from(). Hard error on a missing file: the registry
## cannot generate NPCs without archetype definitions.
func _load_archetypes() -> void:
	_load_archetypes_from(ARCHETYPES_PATH)


## Test hook mirroring DialogueDatabase._load_from(): loads an alternate
## archetypes catalogue (fixtures under tests/fixtures/).
func _load_archetypes_from(p_path: String) -> void:
	_archetypes_loaded = false
	_archetypes_by_id.clear()
	_warnings.clear()
	if not FileAccess.file_exists(p_path):
		push_error("NPCRegistry: Required file %s not found." % p_path)
		return
	var catalogue: NPCArchetypeDatabaseCatalogue = load(p_path)
	if catalogue == null:
		push_error("NPCRegistry: Failed to parse %s." % p_path)
		return
	for def in catalogue.archetypes:
		if def == null:
			continue
		_archetypes_by_id[def.archetype_id] = def
	_archetypes_loaded = true


## True after the archetypes catalogue loads without error.
func is_loaded() -> bool:
	return _archetypes_loaded


## Warnings recorded during loads and runtime edge-case handling — exposed for
## tests to assert e.g. AC-20/AC-21 log behavior (DCD precedent).
func get_warnings() -> PackedStringArray:
	return _warnings.duplicate()


# --- Queries ----------------------------------------------------------------

## Returns the NPC record for npc_id, or null if unregistered (AC-2-style
## lookup; E14 — callers must null-check).
func get_npc(npc_id: String) -> NpcRecord:
	return _npcs_by_id.get(npc_id, null)


## All registered NpcRecords in registration order (deterministic; RFS GDD
## tie-break relies on this order).
func get_all_npcs() -> Array[NpcRecord]:
	var out: Array[NpcRecord] = []
	for npc in _order:
		out.append(npc)
	return out


## NpcRecords currently in the given belief state (VMV, GSM win check).
func get_npcs_by_belief(state: GameEnums.BeliefState) -> Array[NpcRecord]:
	var out: Array[NpcRecord] = []
	for npc in _order:
		if npc.belief_state == state:
			out.append(npc)
	return out


## Returns every approachable NPC per Rule 6 — ALL three gates must hold:
##   1. cooldown_turns_remaining == 0
##   2. approach_count < GameConfig.conversion.max_approaches_per_npc
##   3. access_gate == null OR every required_npc_id has reached
##      required_belief_state
## Plus Rule 2/E6: CONVERTED NPCs are terminal and never returned here.
## Config is pulled at call time (ADR-0005 pull pattern — no caching).
func get_approachable_npcs() -> Array[NpcRecord]:
	var max_approaches: int = GameConfig.conversion.max_approaches_per_npc
	var out: Array[NpcRecord] = []
	for npc in _order:
		if npc.belief_state == GameEnums.BeliefState.CONVERTED:
			continue  # E6 — terminal NPCs are not player-approachable
		if npc.cooldown_turns_remaining > 0:
			continue
		if npc.approach_count >= max_approaches:
			continue
		if not _gate_satisfied(npc):
			continue
		out.append(npc)
	return out


## Social connections of npc_id (E3-validated at init; empty for unknown ids).
func get_connections(npc_id: String) -> Array[NPCConnection]:
	var npc: NpcRecord = _npcs_by_id.get(npc_id, null)
	if npc == null:
		return []
	var out: Array[NPCConnection] = []
	for conn in npc.social_connections:
		out.append(conn)
	return out


## Archetype definition for the archetype enum (Rule 3 data; also the source
## of social_influence_weight — NOT stored on NpcRecord, per Rule 1).
func get_archetype_definition(archetype: GameEnums.NPCArchetype) -> NPCArchetypeDefinition:
	return _archetypes_by_id.get(archetype, null)


## Number of hidden (unrevealed) traits: assigned_traits.size() minus
## revealed_traits.size() (Rule 7 / UI "[N traits hidden]").
func get_hidden_trait_count(npc_id: String) -> int:
	var npc: NpcRecord = _npcs_by_id.get(npc_id, null)
	if npc == null:
		return 0
	return npc.assigned_traits.size() - npc.revealed_traits.size()


# --- Mutation: conversion outcomes ------------------------------------------

## Applies an already-resolved conversion outcome (Rule 5 table). The CLE
## (2-7) computes the outcome; this is the state-mutation half of the
## resolve->apply pair. The approach ALWAYS registers (DCD finally block,
## Rule 8 Step 8): cooldown_turns_remaining = approach_cooldown_turns,
## approach_count += 1, approach_history[approach] += 1 — for every outcome,
## including RESISTED (CLE Formula 3 repeat penalty reads approach_history
## and must accrue on failed attempts). Belief mutation follows the table:
##
##   PERSUADED: STEADFAST->OPEN, OPEN->WAVERING, WAVERING->CONVERTED,
##              CONVERTED -> (RIVAL + grace window ? WAVERING : no-op)
##   SOFTENED:  STEADFAST->OPEN, OPEN->WAVERING, WAVERING no change,
##              CONVERTED -> (RIVAL + grace window ? WAVERING : no-op)
##   RESISTED:  no change
##   HARDENED:  STEADFAST no change (floor, E5), OPEN->STEADFAST,
##              WAVERING->OPEN, CONVERTED no-op
##
## RIVAL grace window (Rule 5 dagger / RFS GDD Rule 9): any WAVERING->
## CONVERTED transition (any caller) sets recently_converted_turns_remaining
## = GameConfig.rival_faith.grace_window_turns; CONVERTED->WAVERING regression
## only applies when caller == RIVAL and the window is still open. After the
## window closes, CONVERTED is permanent for every caller. RESISTED/HARDENED
## never regress a CONVERTED NPC (E6).
## Unknown npc_id or invalid enum -> error log + no-op (E14 defensive).
func apply_conversion_outcome(npc_id: String, outcome: GameEnums.ConversionOutcome,
		approach: GameEnums.DialogueApproach,
		caller: GameEnums.OutcomeCaller = GameEnums.OutcomeCaller.PLAYER) -> void:
	var npc: NpcRecord = _npcs_by_id.get(npc_id, null)
	if npc == null:
		_warn("NPCRegistry: apply_conversion_outcome on unknown npc_id '%s' — no-op (E14)" % npc_id)
		return
	if not _is_valid_outcome(outcome):
		_warn("NPCRegistry: invalid ConversionOutcome %s for '%s' — no-op" % [str(outcome), npc_id])
		return
	if not _is_valid_approach(approach):
		_warn("NPCRegistry: invalid DialogueApproach %s for '%s' — no-op" % [str(approach), npc_id])
		return
	if not _is_valid_caller(caller):
		_warn("NPCRegistry: invalid OutcomeCaller %s for '%s' — no-op" % [str(caller), npc_id])
		return

	var old_state := npc.belief_state
	var new_state := old_state
	match outcome:
		GameEnums.ConversionOutcome.PERSUADED:
			new_state = _persuaded_transition(npc, caller)
		GameEnums.ConversionOutcome.SOFTENED:
			new_state = _softened_transition(npc, caller)
		GameEnums.ConversionOutcome.RESISTED:
			new_state = old_state
		GameEnums.ConversionOutcome.HARDENED:
			new_state = _hardened_transition(npc)

	# The approach registered regardless of outcome (DCD finally block).
	npc.cooldown_turns_remaining = GameConfig.conversion.approach_cooldown_turns
	npc.approach_count += 1
	npc.approach_history[approach] = int(npc.approach_history.get(approach, 0)) + 1

	if new_state != old_state:
		npc.belief_state = new_state
		npc_state_changed.emit(npc_id, old_state, new_state)


func _persuaded_transition(npc: NpcRecord, caller: GameEnums.OutcomeCaller) -> GameEnums.BeliefState:
	match npc.belief_state:
		GameEnums.BeliefState.STEADFAST:
			return GameEnums.BeliefState.OPEN
		GameEnums.BeliefState.OPEN:
			return GameEnums.BeliefState.WAVERING
		GameEnums.BeliefState.WAVERING:
			# dagger: any WAVERING->CONVERTED sets the rival grace window.
			npc.recently_converted_turns_remaining = GameConfig.rival_faith.grace_window_turns
			return GameEnums.BeliefState.CONVERTED
		_:
			# CONVERTED: only RIVAL regression while the grace window is open.
			if caller == GameEnums.OutcomeCaller.RIVAL and npc.recently_converted_turns_remaining > 0:
				return GameEnums.BeliefState.WAVERING
			return npc.belief_state


func _softened_transition(npc: NpcRecord, caller: GameEnums.OutcomeCaller) -> GameEnums.BeliefState:
	match npc.belief_state:
		GameEnums.BeliefState.STEADFAST:
			return GameEnums.BeliefState.OPEN
		GameEnums.BeliefState.OPEN:
			return GameEnums.BeliefState.WAVERING
		GameEnums.BeliefState.WAVERING:
			return npc.belief_state  # SOFTENED cannot seal the conversion
		_:
			if caller == GameEnums.OutcomeCaller.RIVAL and npc.recently_converted_turns_remaining > 0:
				return GameEnums.BeliefState.WAVERING
			return npc.belief_state


func _hardened_transition(npc: NpcRecord) -> GameEnums.BeliefState:
	match npc.belief_state:
		GameEnums.BeliefState.STEADFAST:
			return npc.belief_state  # floor — E5, cannot go below
		GameEnums.BeliefState.OPEN:
			return GameEnums.BeliefState.STEADFAST
		GameEnums.BeliefState.WAVERING:
			return GameEnums.BeliefState.OPEN
		_:
			return npc.belief_state  # CONVERTED — never regresses via HARDENED


# --- Trait revelation (Rule 7) ----------------------------------------------

## Reveals the hidden trait with the HIGHEST absolute affinity magnitude for
## the given approach (dialogue-outcome reveal, AC-14). Ties resolved by
## index in assigned_traits (earliest index wins). Returns the revealed
## TraitData, or null when there is nothing to reveal (E10 full reveal —
## NO signal emitted; AC-15) or the npc is unknown (E14).
func reveal_trait(npc_id: String, approach: GameEnums.DialogueApproach) -> TraitData:
	var npc: NpcRecord = _npcs_by_id.get(npc_id, null)
	if npc == null:
		_warn("NPCRegistry: reveal_trait on unknown npc_id '%s' (E14)" % npc_id)
		return null
	if npc.revealed_traits.size() >= npc.assigned_traits.size():
		return null  # E10 — no-op, no signal
	var best_id := ""
	var best_abs := -1.0
	for trait_id in npc.assigned_traits:
		if npc.revealed_traits.has(trait_id):
			continue
		var affinity := absf(TraitDatabase.get_affinity(trait_id, approach))
		if affinity > best_abs or (affinity == best_abs and best_id.is_empty()):
			best_abs = affinity
			best_id = trait_id
	if best_id.is_empty():
		return null
	npc.revealed_traits.append(best_id)
	trait_revealed.emit(npc_id, best_id)
	return TraitDatabase.get_trait(best_id)


## Reveals the hidden trait with the HIGHEST absolute affinity magnitude
## across ALL FOUR approaches (inspect action, AC-13). Ties resolved by
## index in assigned_traits (earliest index wins). Returns the revealed
## TraitData, or null when there is nothing to reveal (E10 — NO signal,
## AC-15). E11: an empty assigned_traits is a data error — logs an error and
## returns null without mutation.
func trigger_inspect_reveal(npc_id: String) -> TraitData:
	var npc: NpcRecord = _npcs_by_id.get(npc_id, null)
	if npc == null:
		_warn("NPCRegistry: trigger_inspect_reveal on unknown npc_id '%s' (E14)" % npc_id)
		return null
	if npc.assigned_traits.is_empty():
		push_error("NPCRegistry: trigger_inspect_reveal on '%s' with empty assigned_traits — data error (E11)" % npc_id)
		return null
	if npc.revealed_traits.size() >= npc.assigned_traits.size():
		return null  # E10 — no-op, no signal
	var best_id := ""
	var best_abs := -1.0
	for trait_id in npc.assigned_traits:
		if npc.revealed_traits.has(trait_id):
			continue
		var max_abs := 0.0
		for approach in GameEnums.DialogueApproach.values():
			max_abs = maxf(max_abs, absf(TraitDatabase.get_affinity(trait_id, approach)))
		if max_abs > best_abs or (max_abs == best_abs and best_id.is_empty()):
			best_abs = max_abs
			best_id = trait_id
	if best_id.is_empty():
		return null
	npc.revealed_traits.append(best_id)
	trait_revealed.emit(npc_id, best_id)
	return TraitDatabase.get_trait(best_id)


# --- Turn lifecycle ---------------------------------------------------------

## Decrements cooldown_turns_remaining and recently_converted_turns_remaining
## for every NPC by 1 (floor 0) — AC-9. Emits npc_cooldown_expired for each
## NPC whose cooldown REACHES 0 on this tick, exactly once per cooldown cycle
## (AC-17). Rival grace windows tick down alongside cooldowns (RFS Rule 9).
func advance_turn() -> void:
	for npc in _order:
		var was_cooldown_active := npc.cooldown_turns_remaining > 0
		npc.cooldown_turns_remaining = maxi(0, npc.cooldown_turns_remaining - 1)
		npc.recently_converted_turns_remaining = maxi(0, npc.recently_converted_turns_remaining - 1)
		if was_cooldown_active and npc.cooldown_turns_remaining == 0:
			npc_cooldown_expired.emit(npc.npc_id)


# --- Village lifecycle ------------------------------------------------------

## Generates the village from a VillageDefinition (Rule 8 + ADR-0007 Decision
## 1). Deterministic: one generation RNG created from village_def.rng_seed,
## consumed in a FIXED order — per NPC definition (authored order): trait
## count roll, then trait_count weighted draws. Same seed + same data + same
## engine version => identical village (AC-1).
##
## Validates per Rule 8: id format + duplicate guard (E1/AC-20), trait
## assignment (Trait Assignment Formula + Archetype Trait Weight Formula +
## dedup pool — trait-db EC-1), E2/E3 malformed cross-refs, E8/AC-21
## unplayable-village guard. Emits village_initialized once on success.
func initialize_village(village_def: VillageDefinition) -> void:
	_warnings.clear()
	if village_def == null:
		_warn("NPCRegistry: initialize_village(null) — rejected")
		return
	if not _archetypes_loaded:
		_warn("NPCRegistry: initialize_village called before archetypes loaded — rejected")
		return
	if village_def.npc_definitions.is_empty():
		_warn("NPCRegistry: initialize_village with an empty roster — rejected")
		return

	clear_village()
	_village_id = village_def.village_id
	var rng := RNGHelpers.make_seeded(village_def.rng_seed)
	var defined_ids: Array[String] = []
	for entry in village_def.npc_definitions:
		if typeof(entry) != TYPE_DICTIONARY:
			_warn("NPCRegistry: invalid definition entry (not a Dictionary) — skipped")
			continue
		var npc_id: String = str(entry.get("npc_id", ""))
		defined_ids.append(npc_id)

	for entry in village_def.npc_definitions:
		_generate_npc(entry, rng, defined_ids)

	# E8 / AC-21: if every NPC is access-gated, the village is unplayable.
	# Clear the gate on the NPC with the FEWEST required_npc_ids (exactly
	# one — tie broken by registration order for determinism) + error log.
	if _all_npcs_gated():
		var victim_id := _fewest_required_ids_npc_id()
		if not victim_id.is_empty():
			var victim: NpcRecord = _npcs_by_id[victim_id]
			victim.access_gate = null
			push_error("NPCRegistry: unplayable village — every NPC has an access gate (E8/AC-21); cleared gate on '%s'" % victim_id)
	village_initialized.emit()


## Generates one NpcRecord from a definition dictionary plus the generation
## RNG (Rule 8 step order). Not public API — initialize_village drives it.
func _generate_npc(entry: Dictionary, rng: RandomNumberGenerator, defined_ids: Array[String]) -> void:
	var npc_id: String = str(entry.get("npc_id", ""))
	if npc_id.is_empty():
		_warn("NPCRegistry: definition missing npc_id — skipped")
		return
	if not _valid_id_format(npc_id):
		_warn("NPCRegistry: npc_id '%s' does not match [village_id]_[archetype_slug]_[index] — skipped" % npc_id)
		return
	if _npcs_by_id.has(npc_id):
		_warn("NPCRegistry: duplicate npc_id '%s' — keeping the existing record (E1/AC-20)" % npc_id)
		return

	var archetype_raw: int = int(entry.get("archetype", -1))
	if not _is_valid_archetype(archetype_raw):
		_warn("NPCRegistry: npc '%s' has invalid archetype %s — skipped" % [npc_id, str(archetype_raw)])
		return
	var archetype: GameEnums.NPCArchetype = archetype_raw

	var npc := NpcRecord.new()
	npc.npc_id = npc_id
	npc.archetype = archetype
	npc.display_name = str(entry.get("display_name", npc_id))
	npc.belief_state = GameEnums.BeliefState.STEADFAST         # Rule 8 step 2
	npc.cooldown_turns_remaining = 0                            # Rule 8 step 3
	npc.approach_count = 0
	npc.approach_history = {}
	npc.revealed_traits = []
	npc.map_position = entry.get("map_position", Vector2i.ZERO)

	# Rule 8 step 4: trait assignment (Trait Assignment Formula).
	_assign_traits(npc, rng)

	# Rule 8 step 5: social_connections + access_gate (hand-authored).
	npc.social_connections = _materialize_connections(entry, npc_id, defined_ids)
	npc.access_gate = _materialize_gate(entry, npc_id, defined_ids)

	_npcs_by_id[npc_id] = npc
	_order.append(npc)

	# Rule 3 portrait-path debug validation (log warning, do not crash).
	_validate_portrait_path(archetype)


## Assigns traits per the Trait Assignment Formula (NPC trait-db GDD
## §Formulas + NPC CS Archetype Trait Weight Formula):
##   Step 1: trait_count = random_int_inclusive(traits_per_npc_min, max)
##   Step 2: weighted pool = for each eligible trait (archetype-tagged UNION
##           archetype-agnostic, deduped — EC-1):
##             effective_weight = rarity_base_weight x (1 + bonus_pct)
##   Step 3: draw WITHOUT replacement trait_count times, erasing each draw.
## EC-2: if the pool is smaller than trait_count, clamp + warn (never loop).
## Pool construction order is irrelevant (weights are normalized); the draw
## order is fixed by the RNG stream (determinism contract).
func _assign_traits(npc: NpcRecord, rng: RandomNumberGenerator) -> void:
	var archetype_def: NPCArchetypeDefinition = _archetypes_by_id.get(npc.archetype, null)
	if archetype_def == null:
		_warn("NPCRegistry: no archetype definition for %s — no traits assigned" % GameEnums.NPCArchetype.keys()[npc.archetype])
		return
	var slug: String = ARCHETYPE_SLUGS[npc.archetype]
	var eligible: Array[TraitData] = TraitDatabase.get_traits_for_archetype(slug)

	# Step 1 — trait count (inclusive bounds from GameConfig.traits).
	var min_count: int = GameConfig.traits.traits_per_npc_min
	var max_count: int = GameConfig.traits.traits_per_npc_max
	var trait_count := RNGHelpers.random_int_inclusive(rng, min_count, max_count)

	# Step 2 — weighted pool with dedup (trait-db EC-1) + archetype bonuses.
	var pool: Array = []
	var seen := {}
	var bonus_by_trait := {}
	if archetype_def.trait_weight_bonuses.size() > 0:
		for bonus in archetype_def.trait_weight_bonuses:
			bonus_by_trait[bonus.trait_id] = bonus.bonus_pct
	for entry in eligible:
		if seen.has(entry.id):
			continue
		seen[entry.id] = true
		var base_weight := _rarity_weight(entry.rarity)
		var bonus: float = float(bonus_by_trait.get(entry.id, 0.0))
		pool.append({"id": entry.id, "weight": float(base_weight) * (1.0 + bonus)})

	# EC-2: clamp when the pool is smaller than the requested count.
	if trait_count > pool.size():
		_warn("NPCRegistry: archetype %s pool (%d) smaller than trait_count %d — clamping" %
			[slug, pool.size(), trait_count])
		trait_count = pool.size()

	# Step 3 — draw without replacement.
	var picked: Array = RNGHelpers.draw_without_replacement(rng, pool, trait_count)
	for entry in picked:
		npc.assigned_traits.append(str(entry["id"]))


func _rarity_weight(rarity: GameEnums.TraitRarity) -> int:
	match rarity:
		GameEnums.TraitRarity.COMMON:
			return GameConfig.traits.common_trait_weight
		GameEnums.TraitRarity.UNCOMMON:
			return GameConfig.traits.uncommon_trait_weight
		_:
			return GameConfig.traits.rare_trait_weight


## Builds NPCConnection resources from the definition; E3: a connection whose
## target_npc_id is not in the village is dropped with an error log (no crash).
func _materialize_connections(entry: Dictionary, npc_id: String, defined_ids: Array[String]) -> Array[NPCConnection]:
	var out: Array[NPCConnection] = []
	for conn_dict in entry.get("social_connections", []):
		if typeof(conn_dict) != TYPE_DICTIONARY:
			_warn("NPCRegistry: '%s' has an invalid connection entry — skipped" % npc_id)
			continue
		var target: String = str(conn_dict.get("target_npc_id", ""))
		if not defined_ids.has(target):
			push_error("NPCRegistry: '%s' connection targets unknown id '%s' — dropped (E3)" % [npc_id, target])
			continue
		var conn := NPCConnection.new()
		conn.target_npc_id = target
		conn.relationship_type = int(conn_dict.get("relationship_type", GameEnums.RelationshipType.NEIGHBOR))
		conn.influence_weight = float(conn_dict.get("influence_weight", 1.0))
		out.append(conn)
	return out


## Builds the access gate from the definition; E2: a gate referencing an
## unknown npc_id is cleared (gate = null) with an error log (no crash) —
## the NPC becomes immediately approachable.
func _materialize_gate(entry: Dictionary, npc_id: String, defined_ids: Array[String]) -> NPCAccessGate:
	if not entry.has("access_gate"):
		return null
	var gate_dict: Dictionary = entry["access_gate"]
	if typeof(gate_dict) != TYPE_DICTIONARY:
		return null
	var required_ids: Array = gate_dict.get("required_npc_ids", [])
	var all_resolve := true
	for required in required_ids:
		if not defined_ids.has(str(required)):
			all_resolve = false
			break
	if not all_resolve:
		push_error("NPCRegistry: '%s' access gate references unknown id — gate cleared (E2)" % npc_id)
		return null
	var gate := NPCAccessGate.new()
	gate.required_belief_state = int(gate_dict.get("required_belief_state", GameEnums.BeliefState.OPEN))
	var ids: Array[String] = []
	for required in required_ids:
		ids.append(str(required))
	gate.required_npc_ids = ids
	return gate


## Clears the registry: drops every NpcRecord, resets village metadata.
## Cooldowns/counters are discarded (E13) — callers must finish iterating
## before clearing (no timers/callbacks are held by this registry).
func clear_village() -> void:
	_npcs_by_id.clear()
	_order.clear()
	_village_id = ""


func _all_npcs_gated() -> bool:
	if _order.is_empty():
		return false
	for npc in _order:
		if npc.access_gate == null:
			return false
	return true


## E8 helper: the id of the gated NPC with the fewest required_npc_ids;
## tie broken by registration order (deterministic).
func _fewest_required_ids_npc_id() -> String:
	var best_id := ""
	var best_count := 1 << 30
	for npc in _order:
		if npc.access_gate == null:
			continue
		var count: int = npc.access_gate.required_npc_ids.size()
		if count < best_count:
			best_count = count
			best_id = npc.npc_id
	return best_id


func _gate_satisfied(npc: NpcRecord) -> bool:
	if npc.access_gate == null:
		return true
	for required_id in npc.access_gate.required_npc_ids:
		var required: NpcRecord = _npcs_by_id.get(required_id, null)
		if required == null:
			return false  # dead ref would have been cleared at init (E2)
		if required.belief_state < npc.access_gate.required_belief_state:
			return false
	return true


## Debug-only portrait path validation (Rule 3): log a warning if the
## archetype's portrait dir is missing; the Portrait system's fallback
## covers runtime. Does not crash.
func _validate_portrait_path(archetype: GameEnums.NPCArchetype) -> void:
	var def: NPCArchetypeDefinition = _archetypes_by_id.get(archetype, null)
	if def == null or def.portrait_asset_path.is_empty():
		return
	if not DirAccess.dir_exists_absolute(def.portrait_asset_path):
		_warn("NPCRegistry: archetype %s portrait dir missing: %s (Rule 3 debug validation)" %
			[GameEnums.NPCArchetype.keys()[archetype], def.portrait_asset_path])


# --- Persistence ------------------------------------------------------------

## Serializes the full registry state (AC-18): village id + one record per
## NPC in registration order, all fields incl. revealed/belief/counters/
## history/connections/gates. Pure read — returns a fresh Dictionary; the
## registry's records are untouched.
func serialize() -> Dictionary:
	var payload := {
		"version": SERIALIZE_VERSION,
		"village_id": _village_id,
		"npcs": [],
	}
	for npc in _order:
		var record := {
			"npc_id": npc.npc_id,
			"archetype": int(npc.archetype),
			"display_name": npc.display_name,
			"assigned_traits": npc.assigned_traits.duplicate(),
			"revealed_traits": npc.revealed_traits.duplicate(),
			"belief_state": int(npc.belief_state),
			"cooldown_turns_remaining": npc.cooldown_turns_remaining,
			"recently_converted_turns_remaining": npc.recently_converted_turns_remaining,
			"approach_count": npc.approach_count,
			"approach_history": npc.approach_history.duplicate(true),
			"map_position": npc.map_position,
			"social_connections": [],
			"access_gate": null,
		}
		for conn in npc.social_connections:
			record["social_connections"].append({
				"target_npc_id": conn.target_npc_id,
				"relationship_type": int(conn.relationship_type),
				"influence_weight": conn.influence_weight,
			})
		if npc.access_gate != null:
			record["access_gate"] = {
				"required_belief_state": int(npc.access_gate.required_belief_state),
				"required_npc_ids": npc.access_gate.required_npc_ids.duplicate(),
			}
		payload["npcs"].append(record)
	return payload


## Restores registry state from a serialize() payload (AC-18). No trait
## redraw — records are rebuilt exactly as saved (Rule 8). Graceful schema
## migration (AC-19/E4): an unknown BeliefState loads as STEADFAST; an
## unknown RelationshipType drops the connection — never crashes. Unknown
## npc_id/key shapes log an error and skip (defensive). Clears current
## state first (GSM/SaveLoad call clear_village() before deserialize).
func deserialize(payload: Dictionary) -> void:
	_npcs_by_id.clear()
	_order.clear()
	_village_id = str(payload.get("village_id", ""))
	_warnings.clear()
	for record in payload.get("npcs", []):
		if typeof(record) != TYPE_DICTIONARY:
			_warn("NPCRegistry: deserialize found a non-Dictionary record — skipped")
			continue
		_restore_npc(record)
	# Re-run the unplayable-village guard on restored data (defensive:
	# a malformed save could contain an all-gated village).
	if _all_npcs_gated():
		var victim_id := _fewest_required_ids_npc_id()
		if not victim_id.is_empty():
			var victim: NpcRecord = _npcs_by_id[victim_id]
			victim.access_gate = null
			push_error("NPCRegistry: deserialize produced an unplayable village — cleared gate on '%s'" % victim_id)


func _restore_npc(record: Dictionary) -> void:
	var npc := NpcRecord.new()
	npc.npc_id = str(record.get("npc_id", ""))
	if npc.npc_id.is_empty() or _npcs_by_id.has(npc.npc_id):
		_warn("NPCRegistry: deserialize skipped empty/duplicate npc_id '%s'" % npc.npc_id)
		return
	var archetype_raw: int = int(record.get("archetype", -1))
	npc.archetype = archetype_raw if _is_valid_archetype(archetype_raw) else GameEnums.NPCArchetype.LABORER
	npc.display_name = str(record.get("display_name", npc.npc_id))
	npc.belief_state = _restore_belief(int(record.get("belief_state", GameEnums.BeliefState.STEADFAST)))
	npc.cooldown_turns_remaining = int(record.get("cooldown_turns_remaining", 0))
	npc.recently_converted_turns_remaining = int(record.get("recently_converted_turns_remaining", 0))
	npc.approach_count = int(record.get("approach_count", 0))
	npc.approach_history = record.get("approach_history", {}).duplicate(true)
	npc.map_position = record.get("map_position", Vector2i.ZERO)
	var assigned: Array = record.get("assigned_traits", [])
	for trait_id in assigned:
		npc.assigned_traits.append(str(trait_id))
	var revealed: Array = record.get("revealed_traits", [])
	for trait_id in revealed:
		npc.revealed_traits.append(str(trait_id))
	for conn_dict in record.get("social_connections", []):
		if typeof(conn_dict) != TYPE_DICTIONARY:
			continue
		var rel_raw: int = int(conn_dict.get("relationship_type", -1))
		if not _is_valid_relationship(rel_raw):
			push_error("NPCRegistry: '%s' connection unknown RelationshipType %s — dropped (E4)" % [npc.npc_id, str(rel_raw)])
			continue
		var conn := NPCConnection.new()
		conn.target_npc_id = str(conn_dict.get("target_npc_id", ""))
		conn.relationship_type = rel_raw
		conn.influence_weight = float(conn_dict.get("influence_weight", 1.0))
		npc.social_connections.append(conn)
	if record.has("access_gate") and typeof(record["access_gate"]) == TYPE_DICTIONARY:
		var gate_dict: Dictionary = record["access_gate"]
		var gate := NPCAccessGate.new()
		gate.required_belief_state = _restore_belief(int(gate_dict.get("required_belief_state", GameEnums.BeliefState.OPEN)))
		var ids: Array[String] = []
		for required in gate_dict.get("required_npc_ids", []):
			ids.append(str(required))
		gate.required_npc_ids = ids
		npc.access_gate = gate
	_npcs_by_id[npc.npc_id] = npc
	_order.append(npc)


## AC-19 / E4: unknown BeliefState ints load as STEADFAST with an error log.
func _restore_belief(raw: int) -> GameEnums.BeliefState:
	if _is_valid_belief(raw):
		return raw
	push_error("NPCRegistry: unknown BeliefState %s in save — defaulting to STEADFAST (AC-19/E4)" % str(raw))
	return GameEnums.BeliefState.STEADFAST


# --- Validation helpers -----------------------------------------------------

func _is_valid_belief(value: int) -> bool:
	return value >= 0 and value < GameEnums.BeliefState.size()

func _is_valid_archetype(value: int) -> bool:
	return value >= 0 and value < GameEnums.NPCArchetype.size()

func _is_valid_relationship(value: int) -> bool:
	return value >= 0 and value < GameEnums.RelationshipType.size()

func _is_valid_approach(value: int) -> bool:
	return value >= 0 and value < GameEnums.DialogueApproach.size()

func _is_valid_outcome(value: int) -> bool:
	return value >= 0 and value < GameEnums.ConversionOutcome.size()

func _is_valid_caller(value: int) -> bool:
	return value >= 0 and value < GameEnums.OutcomeCaller.size()


## npc_id contract: [village_id]_[archetype_slug]_[index] (Rule 1). The
## village prefix is taken from the current _village_id; slug must match the
## NPC's archetype (checked by the caller before id validation in generation
## order — here we validate shape + prefix + digit index).
func _valid_id_format(npc_id: String) -> bool:
	var parts := npc_id.rsplit("_", true, 2)
	if parts.size() != 3:
		return false
	var prefix: String = parts[0]
	var slug: String = parts[1]
	var index_part: String = parts[2]
	if prefix != _village_id:
		return false
	if not slug in ARCHETYPE_SLUGS:
		return false
	if not index_part.is_valid_int():
		return false
	return index_part.to_int() >= 1


func _warn(msg: String) -> void:
	_warnings.append(msg)
	push_warning(msg)