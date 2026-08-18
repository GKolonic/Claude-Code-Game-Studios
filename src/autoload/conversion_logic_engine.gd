extends Node
## ConversionLogicEngine — Autoload, ADR-0001 slot 6. Stateless conversion
## resolution (Conversion Logic Engine GDD; ADR-0007 Decision 3).
##
## resolve() is a pure function: given an approach, an NPC id and (optionally)
## a caller-owned RNG instance, it reads the NPC's current state from
## NPCRegistry and trait affinities from TraitDatabase at call time, pulls
## every tuning value from GameConfig.conversion at call time (ADR-0005 pull
## pattern — nothing is cached, AC-8.4 proves it), computes Formulas 1-5,
## draws exactly one uniform roll through RNGHelpers.uniform_roll (ADR-0007
## Decision 3 — the ONLY randomness in a resolve) and returns one of four
## ConversionOutcome values.
##
## The Engine writes NOTHING (AC-1.2/1.3): it does not validate
## approachability (Core Rule 5 — callers gate before invoking) and does not
## apply the outcome (Core Rule 6 — callers pass the result to
## NPCRegistry.apply_conversion_outcome()). RESISTED is the safe sentinel for
## every caller-error path (EC-3/EC-5/EC-9): applying it downstream produces
## no state side-effects.
##
## RNG contract (ADR-0007): each resolve draws exactly one roll from the RNG
## instance the CALLER threads in. When rng is null the Engine creates a
## fresh entropy-seeded instance for this call only (runtime randomness —
## Time.get_ticks_usec() seeds it; acceptable at MVP, NEVER used in tests,
## which always pass explicit seeds) and drops it; nothing is retained.
##
## EC-8 note: if a caller exits early between resolve() and
## apply_conversion_outcome() the NPC's approach_history/cooldowns are stale —
## the Engine itself is stateless and cannot be inconsistent; the Dialogue &
## Conversion System must guarantee apply happens in a finally-equivalent
## block. EC-11: RESISTED is the only outcome with no benefit — a spent
## approach with no reveal and no belief advance. EC-13: the "reset to farm"
## exploit is bounded structurally by NPCRegistry's max_approaches_per_npc
## counter, not by this Engine.

## The 11 ConversionConfig fields this Engine reads at resolve time (EC-5
## validation set; the three remaining fields belong to other systems).
const _READ_FIELDS: Array[String] = [
	"base_success_chance", "trait_modifier_weight", "trait_modifier_cap",
	"min_success_chance", "max_success_chance",
	"belief_modifier_open", "belief_modifier_wavering",
	"softened_band_fraction", "resisted_band_fraction",
	"repeat_penalty_per_use", "max_repeat_penalty",
]


func _ready() -> void:
	assert(is_instance_valid(GameConfig),
		"ConversionLogicEngine (slot 6): GameConfig (slot 1) must boot first (ADR-0001)")
	assert(is_instance_valid(TraitDatabase),
		"ConversionLogicEngine (slot 6): TraitDatabase (slot 2) must boot first (ADR-0001)")
	assert(is_instance_valid(DialogueDatabase),
		"ConversionLogicEngine (slot 6): DialogueDatabase (slot 3) must boot first (ADR-0001)")
	assert(is_instance_valid(MobileTouchFramework),
		"ConversionLogicEngine (slot 6): MobileTouchFramework (slot 4) must boot first (ADR-0001)")
	assert(is_instance_valid(NPCRegistry),
		"ConversionLogicEngine (slot 6): NPCRegistry (slot 5) must boot first (ADR-0001)")


# --- Exposed API -------------------------------------------------------------

## Core Rule 1: pure resolve. Computes Formulas 1-5 from current NPC state
## and live GameConfig values, draws ONE uniform roll and maps it to an
## outcome with strict-`<` zone comparisons (Formula 5 / EC-10).
##
## AC-8.1 signature (rng defaults to null for the runtime path; tests always
## pass explicit seeds per ADR-0007). Never called with a null rng under
## test/CI conditions — a null rng means a fresh runtime entropy instance.
func resolve(approach: GameEnums.DialogueApproach, npc_id: String,
		rng: RandomNumberGenerator = null) -> GameEnums.ConversionOutcome:
	if not _is_valid_approach(approach):
		push_error("ConversionLogicEngine: invalid DialogueApproach %s (EC-9) — RESISTED" % str(approach))
		return GameEnums.ConversionOutcome.RESISTED
	var npc: NpcRecord = NPCRegistry.get_npc(npc_id)
	if npc == null:
		push_error("ConversionLogicEngine: npc_id '%s' not found in NPCRegistry (EC-3) — RESISTED" % npc_id)
		return GameEnums.ConversionOutcome.RESISTED
	var bd := _compute_breakdown(npc, approach)
	if not bd["ok"]:
		# EC-5: the validation error was already logged inside _compute_breakdown.
		return GameEnums.ConversionOutcome.RESISTED
	var roll_rng := rng
	if roll_rng == null:
		# Runtime-only entropy path (ADR-0007 Decision 4 / OQ-7): fresh RNG for
		# this call ONLY, seeded from the engine tick counter. Never in tests.
		roll_rng = RNGHelpers.make_seeded(int(Time.get_ticks_usec()))
	var roll := RNGHelpers.uniform_roll(roll_rng)
	return _resolve_zone(bd, roll)


## Read-only introspection: returns P_final (Formula 4 output) for the given
## NPC/approach under the CURRENT GameConfig values, without drawing a roll.
## Same validation path as resolve(). Returns -1.0 when the call would fail
## validation (unknown NPC, invalid approach, malformed config) so callers
## can distinguish an error from the 0.05 floor. Test/UI aid only — the game
## logic path is resolve() (AC-8.4 uses this to prove read-at-call-time).
func get_probability(npc_id: String, approach: GameEnums.DialogueApproach) -> float:
	var bd := _breakdown_for_public(npc_id, approach)
	if not bd["ok"]:
		return -1.0
	return float(bd["p_final"])


## Read-only introspection: full four-step breakdown for the given NPC/
## approach under CURRENT GameConfig values — { ok, error, trait_subtotal,
## belief_modifier, repeat_penalty, p_raw, p_final, p_remaining,
## softened_fraction, resisted_fraction, hardened_fraction }. The fraction
## keys report the EFFECTIVE values after the EC-2 relational clamp (if any),
## not the raw config values. Empty Dictionary on validation failure.
## Test/UI aid only — the game logic path is resolve().
func get_probability_breakdown(npc_id: String, approach: GameEnums.DialogueApproach) -> Dictionary:
	var bd := _breakdown_for_public(npc_id, approach)
	if not bd["ok"]:
		return {}
	bd.erase("ok")
	return bd


# --- Internals ---------------------------------------------------------------

## Public-facing wrapper: validates approach + NPC lookup, then delegates to
## the shared computation core (no roll).
func _breakdown_for_public(npc_id: String, approach: GameEnums.DialogueApproach) -> Dictionary:
	if not _is_valid_approach(approach):
		push_error("ConversionLogicEngine: invalid DialogueApproach %s (EC-9)" % str(approach))
		return {"ok": false, "error": "invalid approach"}
	var npc: NpcRecord = NPCRegistry.get_npc(npc_id)
	if npc == null:
		push_error("ConversionLogicEngine: npc_id '%s' not found in NPCRegistry (EC-3)" % npc_id)
		return {"ok": false, "error": "unknown npc"}
	return _compute_breakdown(npc, approach)


## EC-9 validation: approach must be a DialogueApproach enum member.
func _is_valid_approach(approach: GameEnums.DialogueApproach) -> bool:
	return int(approach) >= 0 and int(approach) < GameEnums.DialogueApproach.size()


## Shared computation core (Formulas 1-4 + Formula 5 zone sizing). One
## validation pass at entry (EC-5, EC-2); never loops back to validation
## inside the formula steps. Pure: reads NPC state + GameConfig only.
func _compute_breakdown(npc: NpcRecord, approach: GameEnums.DialogueApproach) -> Dictionary:
	var cfg: ConversionConfig = GameConfig.conversion
	if cfg == null:
		push_error("ConversionLogicEngine: GameConfig.conversion is null (EC-5) — RESISTED")
		return {"ok": false, "error": "null conversion config"}

	# EC-5 single validation pass: every read field must exist and be inside
	# its documented range (game-config.md tables via the config schema).
	# NOTE ordering: the EC-2 relational band check runs BEFORE the per-field
	# range check so a >1.0 band sum is clamped and repaired locally (EC-2:
	# "clamp … then proceed"), not rejected as a lone out-of-range field.
	var softened_fraction := float(cfg.softened_band_fraction)
	var resisted_fraction := float(cfg.resisted_band_fraction)
	var band_clamped := false
	if softened_fraction + resisted_fraction > 1.0:
		push_error("ConversionLogicEngine: softened_band_fraction + resisted_band_fraction = %f + %f > 1.0 (EC-2) — clamping resisted to %f" %
			[softened_fraction, resisted_fraction, 1.0 - softened_fraction])
		resisted_fraction = maxf(0.0, 1.0 - softened_fraction)
		band_clamped = true

	var schema: Dictionary = ConversionConfig.get_validation_schema()
	for field in _READ_FIELDS:
		if not cfg.get(field) is float:
			push_error("ConversionLogicEngine: GameConfig.conversion.%s is null (EC-5) — RESISTED" % field)
			return {"ok": false, "error": "null field: " + field}
		if band_clamped and (field == "softened_band_fraction" or field == "resisted_band_fraction"):
			continue  # EC-2: clamp then proceed — the clamped locals are effective
		var spec: Dictionary = schema[field]
		var value := float(cfg.get(field))
		if value < float(spec["min"]) or value > float(spec["max"]):
			push_error("ConversionLogicEngine: GameConfig.conversion.%s = %s out of documented range [%s, %s] (EC-5) — RESISTED" %
				[field, str(value), str(spec["min"]), str(spec["max"])])
			return {"ok": false, "error": "out of range: " + field}

	# Formula 1 — trait modifier subtotal (EC-6: empty list sums to 0.0;
	# EC-7: W = 0.0 yields 0.0 by construction, valid config, no warning).
	var trait_subtotal := 0.0
	for trait_id in npc.assigned_traits:
		trait_subtotal += TraitDatabase.get_affinity(trait_id, approach) * cfg.trait_modifier_weight
	trait_subtotal = clampf(trait_subtotal, -cfg.trait_modifier_cap, cfg.trait_modifier_cap)

	# Formula 2 — belief state modifier. CONVERTED is not a valid B_table key:
	# treat as STEADFAST (0.0) + warning (EC-4). Any other unexpected value
	# degrades to 0.0 silently (defensive; deserialize already normalises).
	var belief_modifier := 0.0
	match npc.belief_state:
		GameEnums.BeliefState.OPEN:
			belief_modifier = cfg.belief_modifier_open
		GameEnums.BeliefState.WAVERING:
			belief_modifier = cfg.belief_modifier_wavering
		GameEnums.BeliefState.CONVERTED:
			push_warning("ConversionLogicEngine: resolve on CONVERTED npc '%s' — treated as STEADFAST, modifier 0.0 (EC-4)" % npc.npc_id)
		_:
			pass  # STEADFAST and unknown: 0.0

	# Formula 3 — repeat approach penalty (capped at max_repeat_penalty).
	var repeat_count := int(npc.approach_history.get(int(approach), 0))
	var repeat_penalty := minf(float(repeat_count) * cfg.repeat_penalty_per_use, cfg.max_repeat_penalty)

	# Formula 4 — final probability, clamped to [min, max] (EC-12: ceiling is
	# structural; max theoretical P_raw 1.05 clamps to 0.80 at defaults).
	var p_raw := cfg.base_success_chance + trait_subtotal + belief_modifier - repeat_penalty
	var p_final := clampf(p_raw, cfg.min_success_chance, cfg.max_success_chance)

	# Formula 5 — outcome zone sizing. EC-1: P_hardened is floor-clamped to
	# 0.0 so IEEE-754 rounding can never create an impossible zone.
	var p_remaining := 1.0 - p_final
	var p_softened := p_remaining * softened_fraction
	var p_resisted := p_remaining * resisted_fraction
	var p_hardened := maxf(0.0, p_remaining - p_softened - p_resisted)

	return {
		"ok": true,
		"error": "",
		"trait_subtotal": trait_subtotal,
		"belief_modifier": belief_modifier,
		"repeat_penalty": repeat_penalty,
		"p_raw": p_raw,
		"p_final": p_final,
		"p_remaining": p_remaining,
		"softened_fraction": softened_fraction,
		"resisted_fraction": resisted_fraction,
		"hardened_fraction": p_hardened,
	}


## Formula 5 — outcome resolution. STRICT `<` comparisons only (EC-10): each
## zone boundary belongs to the zone ABOVE it, so a roll exactly equal to
## P_final is SOFTENED, never PERSUADED. Falls through to HARDENED.
func _resolve_zone(bd: Dictionary, roll: float) -> GameEnums.ConversionOutcome:
	var p_final := float(bd["p_final"])
	var p_softened := float(bd["softened_fraction"]) * float(bd["p_remaining"])
	var p_resisted := float(bd["resisted_fraction"]) * float(bd["p_remaining"])
	if roll < p_final:
		return GameEnums.ConversionOutcome.PERSUADED
	elif roll < p_final + p_softened:
		return GameEnums.ConversionOutcome.SOFTENED
	elif roll < p_final + p_softened + p_resisted:
		return GameEnums.ConversionOutcome.RESISTED
	return GameEnums.ConversionOutcome.HARDENED