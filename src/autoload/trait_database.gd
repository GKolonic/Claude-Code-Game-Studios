extends Node
## TraitDatabase — Autoload, ADR-0001 slot 2. Read-only trait registry.
##
## Loads res://assets/data/traits/trait_database.tres (16 traits) once at
## _ready() and exposes a typed read-only API (NPC Trait Database GDD Rule 7).
## Stateless: holds no runtime state (no NPC ownership, no reveal state, no
## assignment history — those are NPC Character System concerns). EC-3: any
## missing approach key in a trait's affinity dictionary is filled with 0.0
## and a warning is logged naming the trait and approach.

const TRAIT_DB_PATH := "res://assets/data/traits/trait_database.tres"

var _traits_by_id: Dictionary = {}
var _loaded := false


func _ready() -> void:
	assert(is_instance_valid(GameConfig),
		"TraitDatabase (slot 2): GameConfig (slot 1) must boot first (ADR-0001)")
	_load()


## Loads + indexes the catalogue. Logs a hard error and stays unloaded on a
## missing file (the game cannot generate NPCs without trait definitions).
func _load() -> void:
	if not FileAccess.file_exists(TRAIT_DB_PATH):
		push_error("TraitDatabase: Required file %s not found." % TRAIT_DB_PATH)
		_loaded = false
		return
	var catalogue: TraitDatabaseCatalogue = load(TRAIT_DB_PATH)
	if catalogue == null:
		push_error("TraitDatabase: Failed to parse %s." % TRAIT_DB_PATH)
		_loaded = false
		return
	_traits_by_id.clear()
	for entry in catalogue.traits:
		if entry == null:
			continue
		_normalise_affinities(entry)
		_traits_by_id[entry.id] = entry
	_loaded = true


## EC-3: ensure every trait's approach_affinity has all four DialogueApproach
## keys; a missing key is filled with 0.0 and a warning names trait + approach.
func _normalise_affinities(p_trait: TraitData) -> void:
	for approach in GameEnums.DialogueApproach.values():
		if not p_trait.approach_affinity.has(approach):
			push_warning("TraitDatabase: trait '%s' missing affinity for approach %s — defaulting to 0.0" % [
				p_trait.id, GameEnums.DialogueApproach.keys()[approach]])
			p_trait.approach_affinity[approach] = 0.0


## True after startup load completes without error (AC-1).
func is_loaded() -> bool:
	return _loaded


## Returns the full trait record, or null if not found (AC-2/AC-7).
func get_trait(id: String) -> TraitData:
	return _traits_by_id.get(id, null)


## Returns the affinity value for a trait/approach pair, or 0.0 for
## missing/unknown inputs (AC-3/AC-9).
func get_affinity(trait_id: String, approach: GameEnums.DialogueApproach) -> float:
	var entry: TraitData = _traits_by_id.get(trait_id, null)
	if entry == null:
		return 0.0
	return float(entry.approach_affinity.get(approach, 0.0))


## Returns the full catalogue (used during NPC generation) (AC-10).
func get_all_traits() -> Array[TraitData]:
	var out: Array[TraitData] = []
	for id in _traits_by_id:
		out.append(_traits_by_id[id])
	return out


## Returns all traits of a given rarity tier (AC-11).
func get_traits_by_rarity(rarity: GameEnums.TraitRarity) -> Array[TraitData]:
	var out: Array[TraitData] = []
	for id in _traits_by_id:
		var entry: TraitData = _traits_by_id[id]
		if entry.rarity == rarity:
			out.append(entry)
	return out


## Returns all traits whose archetype_tags include the given archetype ID,
## union with all archetype-agnostic traits (empty tags) (Rule 7).
func get_traits_for_archetype(archetype_id: String) -> Array[TraitData]:
	var out: Array[TraitData] = []
	for id in _traits_by_id:
		var entry: TraitData = _traits_by_id[id]
		if entry.archetype_tags.is_empty() or entry.archetype_tags.has(archetype_id):
			out.append(entry)
	return out
