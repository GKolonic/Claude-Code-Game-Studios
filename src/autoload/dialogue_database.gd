extends Node
## DialogueDatabase — Autoload, ADR-0001 slot 3. Read-only dialogue content
## registry (Dialogue Content Database GDD).
##
## Loads res://assets/data/dialogue/dialogue_database.tres (100 scaffold
## strings — V_total = 100 at MVP) once at _ready() and exposes the GDD
## Rule 9 typed read-only API. Stateless: no line-selection, no recency, no
## NPC state (those are the Dialogue & Conversion System's concerns).
##
## Edge-case contracts enforced here:
## - EC-1 / AC-10: any slot with fewer than MIN_LINES_PER_SLOT (3) non-empty
##   lines sets is_loaded() false; a warning names the slot.
## - EC-2 / AC-12: an empty short_descriptor still returns the struct, with a
##   warning naming the archetype (P&E supplies the fallback string).
## - EC-6 / AC-13: get_npc_flavour() returns a duplicate so a consuming
##   system can never corrupt the shared store.
## - AC-11: with is_loaded() false every get_* returns its empty/null default.
## - R8 (QA plan DCD-2): audit_total_strings()/audit_min_slot_size() expose
##   the V_total formula check and the 3-per-slot invariant.

const DIALOGUE_DB_PATH := "res://assets/data/dialogue/dialogue_database.tres"
const MIN_LINES_PER_SLOT := 3

var _approach_lines: Dictionary = {}
var _outcome_lines: Dictionary = {}
var _flavour_by_archetype: Dictionary = {}
var _rival_lines: Dictionary = {}
var _loaded := false
var _warnings: PackedStringArray = []


func _ready() -> void:
	assert(is_instance_valid(GameConfig),
		"DialogueDatabase (slot 3): GameConfig (slot 1) must boot first (ADR-0001)")
	assert(is_instance_valid(TraitDatabase),
		"DialogueDatabase (slot 3): TraitDatabase (slot 2) must boot first (ADR-0001)")
	_load()


## Loads the production resource. Tests inject alternate fixtures via
## _load_from(); production boot always reads the GDD-pinned path.
func _load() -> void:
	_load_from(DIALOGUE_DB_PATH)


## Loads + validates + indexes a DialogueDatabaseCatalogue resource.
## Test hook: fixtures may be passed here (QA plan OQ-D); the production
## Autoload never calls this with a non-pinned path.
func _load_from(p_path: String) -> void:
	_warnings.clear()
	_loaded = false
	_approach_lines.clear()
	_outcome_lines.clear()
	_flavour_by_archetype.clear()
	_rival_lines.clear()
	if not FileAccess.file_exists(p_path):
		push_error("DialogueDatabase: Required file %s not found." % p_path)
		_warnings.append("Required file %s not found" % p_path)
		return
	var catalogue: DialogueDatabaseCatalogue = load(p_path)
	if catalogue == null:
		push_error("DialogueDatabase: Failed to parse %s." % p_path)
		_warnings.append("Failed to parse %s" % p_path)
		return
	_approach_lines = catalogue.approach_lines.duplicate(true)
	_outcome_lines = catalogue.outcome_lines.duplicate(true)
	_rival_lines = catalogue.rival_lines.duplicate(true)
	for entry in catalogue.npc_flavour:
		if entry == null:
			continue
		_flavour_by_archetype[entry.archetype] = entry
	if not _validate_slots(catalogue):
		_loaded = true


## Validates the 3-per-slot invariant (R8) across every line pool and the
## presence of all 7 archetype entries (EC-1 / AC-10). Returns true when the
## catalogue is defective; every violation is logged with a warning naming
## the slot. Non-empty counting per EC-5: an empty string in a pool is a
## missing line, not content.
func _validate_slots(p_catalogue: DialogueDatabaseCatalogue) -> bool:
	var underfilled := false
	for approach in GameEnums.DialogueApproach.values():
		var pool: Array = p_catalogue.approach_lines.get(approach, [])
		if _count_non_empty(pool) < MIN_LINES_PER_SLOT:
			underfilled = true
			_warn_underfilled("approach slot %s" % _enum_name(GameEnums.DialogueApproach.keys(), approach),
				pool, _count_non_empty(pool))
	for approach in GameEnums.DialogueApproach.values():
		for outcome in GameEnums.ConversionOutcome.values():
			var pool: Array = p_catalogue.outcome_lines.get(_outcome_key(approach, outcome), [])
			if _count_non_empty(pool) < MIN_LINES_PER_SLOT:
				underfilled = true
				_warn_underfilled(
					"outcome slot %s/%s" % [
						_enum_name(GameEnums.DialogueApproach.keys(), approach),
						_enum_name(GameEnums.ConversionOutcome.keys(), outcome)],
					pool, _count_non_empty(pool))
	for entry in p_catalogue.npc_flavour:
		if entry == null:
			continue
		if _count_non_empty(entry.inspect_lines) < MIN_LINES_PER_SLOT:
			underfilled = true
			_warn_underfilled("inspect slot for archetype %s" % _enum_name(GameEnums.NPCArchetype.keys(), entry.archetype),
				entry.inspect_lines, _count_non_empty(entry.inspect_lines))
	for approach in GameEnums.DialogueApproach.values():
		var pool: Array = p_catalogue.rival_lines.get(approach, [])
		if _count_non_empty(pool) < MIN_LINES_PER_SLOT:
			underfilled = true
			_warn_underfilled("rival slot %s" % _enum_name(GameEnums.DialogueApproach.keys(), approach),
				pool, _count_non_empty(pool))
	for archetype in GameEnums.NPCArchetype.values():
		if not _flavour_by_archetype.has(archetype):
			underfilled = true
			var msg := "DialogueDatabase WARN: missing NPC flavour entry for archetype %s" % _enum_name(GameEnums.NPCArchetype.keys(), archetype)
			push_warning(msg)
			_warnings.append(msg)
	return underfilled


func _warn_underfilled(p_slot: String, p_pool: Array, p_count: int) -> void:
	var msg := "DialogueDatabase WARN: %s has %d lines — minimum is %d" % [
		p_slot, p_count, MIN_LINES_PER_SLOT]
	push_warning(msg)
	_warnings.append(msg)


func _count_non_empty(p_pool: Array) -> int:
	var count := 0
	for line in p_pool:
		if line is String and not line.is_empty():
			count += 1
	return count


func _outcome_key(p_approach: int, p_outcome: int) -> String:
	return "%d_%d" % [p_approach, p_outcome]


func _is_valid_approach(p_approach: int) -> bool:
	return p_approach >= 0 and p_approach < GameEnums.DialogueApproach.size()


func _is_valid_outcome(p_outcome: int) -> bool:
	return p_outcome >= 0 and p_outcome < GameEnums.ConversionOutcome.size()


func _is_valid_archetype(p_archetype: int) -> bool:
	return p_archetype >= 0 and p_archetype < GameEnums.NPCArchetype.size()


func _copy_pool(p_pool: Array) -> Array[String]:
	# Defensive copy: callers must not be able to mutate the shared store.
	var out: Array[String] = []
	for line in p_pool:
		out.append(str(line))
	return out


## True after startup load completes without error (AC-1). False when the
## file is missing, malformed, or any slot violates the 3-per-min invariant.
func is_loaded() -> bool:
	return _loaded


## Warnings recorded during the most recent load AND call-time content
## warnings (e.g. EC-2 empty descriptor). Used by tests to assert the
## exact slot/archetype named (AC-10/AC-12); debug-visible for QA audits.
func get_warnings() -> PackedStringArray:
	return _warnings.duplicate()


## Returns the full 3-line pool for the approach (GDD Rule 9, AC-3).
## Invalid or out-of-range values return an empty array (AC-7).
func get_approach_lines(approach: GameEnums.DialogueApproach) -> Array[String]:
	if not _loaded:
		return []
	if not _is_valid_approach(approach):
		_warn_invalid("approach", _safe_enum_name(GameEnums.DialogueApproach.keys(), approach))
		return []
	return _copy_pool(_approach_lines.get(approach, []))


## Returns the 3-line pool for the approach-outcome pair (AC-4). Invalid
## approach or outcome returns an empty array (AC-8).
func get_outcome_summary(approach: GameEnums.DialogueApproach, outcome: GameEnums.ConversionOutcome) -> Array[String]:
	if not _loaded:
		return []
	if not _is_valid_approach(approach):
		_warn_invalid("approach", _safe_enum_name(GameEnums.DialogueApproach.keys(), approach))
		return []
	if not _is_valid_outcome(outcome):
		_warn_invalid("outcome", _safe_enum_name(GameEnums.ConversionOutcome.keys(), outcome))
		return []
	return _copy_pool(_outcome_lines.get(_outcome_key(approach, outcome), []))


## Returns the archetype's NPCFlavourData as a COPY (EC-6/AC-13), or null
## for invalid/missing archetypes (AC-9). An empty short_descriptor still
## returns the struct with a warning naming the archetype (EC-2/AC-12).
func get_npc_flavour(archetype: GameEnums.NPCArchetype) -> NPCFlavourData:
	if not _loaded:
		return null
	if not _is_valid_archetype(archetype):
		_warn_invalid("archetype", _safe_enum_name(GameEnums.NPCArchetype.keys(), archetype))
		return null
	var entry: NPCFlavourData = _flavour_by_archetype.get(archetype, null)
	if entry == null:
		_warn_invalid("archetype", _safe_enum_name(GameEnums.NPCArchetype.keys(), archetype))
		return null
	if entry.short_descriptor.is_empty():
		var msg := "DialogueDatabase WARN: archetype %s has an empty short_descriptor — content error; consumer must use a fallback" % _enum_name(GameEnums.NPCArchetype.keys(), archetype)
		push_warning(msg)
		_warnings.append(msg)
	# EC-6: never hand out the shared Resource. Arrays are copied separately
	# because Resource.duplicate() shares plain Array properties.
	var copy: NPCFlavourData = entry.duplicate() as NPCFlavourData
	copy.inspect_lines = entry.inspect_lines.duplicate()
	return copy


## Returns the 3-line rival faith pool for the approach (AC-6).
func get_rival_lines(approach: GameEnums.DialogueApproach) -> Array[String]:
	if not _loaded:
		return []
	if not _is_valid_approach(approach):
		_warn_invalid("approach", _safe_enum_name(GameEnums.DialogueApproach.keys(), approach))
		return []
	return _copy_pool(_rival_lines.get(approach, []))


## R8 audit (QA plan DCD-2 / OQ-F): sums every non-empty string across all
## approach, outcome, flavour and rival slots. Production DB must equal 100
## (V_total = 4×3 + 4×4×3 + 7×(1+3) + 4×3).
func audit_total_strings() -> int:
	var total := 0
	for approach in GameEnums.DialogueApproach.values():
		total += _count_non_empty(_approach_lines.get(approach, []))
	for key in _outcome_lines:
		total += _count_non_empty(_outcome_lines[key])
	for archetype in _flavour_by_archetype:
		var entry: NPCFlavourData = _flavour_by_archetype[archetype]
		if not entry.short_descriptor.is_empty():
			total += 1
		total += _count_non_empty(entry.inspect_lines)
	for approach in GameEnums.DialogueApproach.values():
		total += _count_non_empty(_rival_lines.get(approach, []))
	return total


## R8 audit: the minimum non-empty line count across every line pool. Must
## stay >= MIN_LINES_PER_SLOT (the under-filled-slot invariant) — the DB
## refuses to load otherwise.
func audit_min_slot_size() -> int:
	var minimum := 1 << 30
	var seen_any := false
	for approach in GameEnums.DialogueApproach.values():
		minimum = mini(minimum, _count_non_empty(_approach_lines.get(approach, [])))
		seen_any = true
		minimum = mini(minimum, _count_non_empty(_rival_lines.get(approach, [])))
	for key in _outcome_lines:
		minimum = mini(minimum, _count_non_empty(_outcome_lines[key]))
		seen_any = true
	for archetype in _flavour_by_archetype:
		var entry: NPCFlavourData = _flavour_by_archetype[archetype]
		minimum = mini(minimum, _count_non_empty(entry.inspect_lines))
		seen_any = true
	if not seen_any:
		return 0
	return minimum


func _warn_invalid(p_kind: String, p_name: String) -> void:
	var msg := "DialogueDatabase WARN: invalid %s key %s — returning empty" % [p_kind, p_name]
	push_warning(msg)
	_warnings.append(msg)


func _safe_enum_name(p_keys: PackedStringArray, p_value: int) -> String:
	var idx := clampi(p_value, 0, p_keys.size() - 1)
	return p_keys[idx]


func _enum_name(p_keys: PackedStringArray, p_value: int) -> String:
	# Caller guarantees p_value is a valid member (validation loops iterate
	# enum values()); kept separate from _safe_enum_name to keep bounds-checks
	# in the hot (invalid-input) path explicit.
	return p_keys[p_value]