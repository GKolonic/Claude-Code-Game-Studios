extends Node
## GameConfig — Autoload, ADR-0001 slot 1. Sole config boundary (ADR-0005).
##
## Loads the nine config-domain .tres files once at _ready() in the fixed
## ADR-0005 table order, validates/clamps every field against its GDD range
## (game-config.md is authoritative), hard-halts on a missing file or missing
## required field, and hot-reloads .tres changes in the editor only (no file
## watcher in export builds — AC-8).
##
## Pull pattern: systems call GameConfig.[domain].[field] at call time and
## must not cache values locally (Rule 3). The ONLY sanctioned read path —
## no code outside this Autoload loads a config .tres (entities.yaml rule).
##
## Hot-reload (editor only): polls the nine paths once per _process() frame;
## on a changed modified-time it reloads + revalidates that domain, swaps the
## values, and emits config_reloaded(domain_name). Failed reloads (mid-edit
## invalid state) log a warning, discard, and retain the last valid state —
## config_reloaded is NOT emitted for failed reloads (EC-8).

## Emitted in the editor only after a domain hot-reload succeeds (AC-7/AC-8).
signal config_reloaded(domain_name: String)

# --- Domain accessors (typed; pull pattern — read at call time) ---
var conversion: ConversionConfig
var traits: TraitConfig
var faith_spread: FaithSpreadConfig
var rival_faith: RivalFaithConfig
var progression: ProgressionConfig
var ui_timing: UITimingConfig
var portraits: PortraitConfig
var map: VillageMapConfig
var hud: HUDConfig

## Load state (GameConfig GDD §States). LOADED before any other Autoload's
## _ready() (AC-1 — guaranteed by ADR-0001 slot 1 + this _ready() completing
## synchronously).
var _state: StringName = &"UNLOADED"

## Fixed domain table (ADR-0005 Decision 1): property name -> {path, class
## script}. Loaded in this exact order; first failure hard-halts.
var _domains: Array[Dictionary] = []

## Editor-only file watcher state: path -> last modified unix time.
var _watch_paths: Dictionary = {}


func _ready() -> void:
	_build_domain_table()
	var err := _load_all_domains()
	if not err.is_empty():
		# AC-4 / AC-5 / EC-1 / EC-4: missing file or missing required field is
		# a fatal startup error. The game must not run in an unknown tuning
		# state — push_error names the exact path/field, then halt.
		push_error(err)
		assert(false, err)
		return
	_state = &"LOADED"
	# Editor-only hot-reload watcher (AC-7); stripped from export builds (AC-8).
	if Engine.is_editor_hint():
		_prime_watcher()
		set_process(true)
	else:
		set_process(false)


## True when all nine domains are validated and accessible (AC-1/AC-10).
func is_loaded() -> bool:
	return _state == &"LOADED"


## Builds the fixed nine-domain load table (ADR-0005 pinned paths).
func _build_domain_table() -> void:
	_domains = [
		{"prop": "conversion", "path": "res://assets/data/config/conversion_config.tres", "script": ConversionConfig},
		{"prop": "traits", "path": "res://assets/data/config/trait_config.tres", "script": TraitConfig},
		{"prop": "faith_spread", "path": "res://assets/data/config/faith_spread_config.tres", "script": FaithSpreadConfig},
		{"prop": "rival_faith", "path": "res://assets/data/config/rival_faith_config.tres", "script": RivalFaithConfig},
		{"prop": "progression", "path": "res://assets/data/config/progression_config.tres", "script": ProgressionConfig},
		{"prop": "ui_timing", "path": "res://assets/data/config/ui_timing_config.tres", "script": UITimingConfig},
		{"prop": "portraits", "path": "res://assets/data/config/portrait_config.tres", "script": PortraitConfig},
		{"prop": "map", "path": "res://assets/data/config/village_map_config.tres", "script": VillageMapConfig},
		{"prop": "hud", "path": "res://assets/data/config/hud_config.tres", "script": HUDConfig},
	]


## Loads + validates all nine domains in order. Returns "" on success or a
## descriptive error string (naming path/field) on the first failure.
func _load_all_domains() -> String:
	for d in _domains:
		var err := _load_domain(d)
		if not err.is_empty():
			return err
	return ""


## Loads one domain .tres, assigns it to the typed property, and validates.
## Returns "" on success or a descriptive error string on failure.
func _load_domain(d: Dictionary) -> String:
	var path: String = d["path"]
	if not FileAccess.file_exists(path):
		return "GameConfig: Required file %s not found." % path  # AC-5 / EC-1
	var res: Resource = load(path)
	if res == null:
		return "GameConfig: Failed to parse %s." % path  # EC-2 surfaces Godot error
	set(d["prop"], res)
	return _validate_domain(d, path)


## Validates + clamps every field of a loaded domain against its GDD schema.
## Out-of-range values clamp with a warning (AC-3 / EC-3); a missing required
## field is a hard error naming the field (AC-4 / EC-4). Missing optional
## fields keep their @export default. Returns "" on success.
##
## Required-field detection: Godot fills absent .tres fields with the @export
## default, so a null check alone cannot detect an un-authored required field.
## We scan the raw .tres text for the field assignment line; a required field
## with no authored assignment line is a hard halt (AC-4).
func _validate_domain(d: Dictionary, path: String = "") -> String:
	var domain_name: String = d["prop"]
	var res: Resource = get(domain_name)
	var schema: Dictionary = d["script"].get_validation_schema()
	var file_text := ""
	if not path.is_empty() and FileAccess.file_exists(path):
		file_text = FileAccess.get_file_as_string(path)
	for field in schema:
		var spec: Dictionary = schema[field]
		var value: Variant = res.get(field)
		if spec.get("required", false):
			if value == null:
				return "GameConfig: Required field '%s' missing in %s." % [field, d["path"]]
			# A required field never authored in the .tres (falls back to the
			# @export default silently) is a hard halt — the GDD marks it
			# Required: Yes, so the file must declare it explicitly.
			if not file_text.is_empty() and not (field + " =") in file_text:
				return "GameConfig: Required field '%s' missing in %s." % [field, d["path"]]
		if value == null:
			continue
		if spec.has("min") and spec.has("max"):
			var clamped: Variant = clampf(float(value), float(spec["min"]), float(spec["max"]))
			if clamped != float(value):
				push_warning("GameConfig: %s.%s clamped from %s to %s" % [
					domain_name, field, str(value), str(clamped)])
				# Preserve the declared property type (int fields stay int).
				if value is int:
					res.set(field, int(clamped))
				else:
					res.set(field, clamped)
	return ""


# --- Editor-only hot-reload (AC-7 / AC-8) ---------------------------------

## Records the initial modified-time for each watched path (editor only).
func _prime_watcher() -> void:
	_watch_paths.clear()
	for d in _domains:
		var path: String = d["path"]
		if FileAccess.file_exists(path):
			_watch_paths[path] = FileAccess.get_modified_time(path)


## Editor-only: polls the nine config paths for changed modified-times and
## hot-reloads the affected domain. Never present in export builds (AC-8 —
## _process is disabled and the watcher state is empty when not editor).
func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	for d in _domains:
		var path: String = d["path"]
		if not FileAccess.file_exists(path):
			continue
		var mtime := int(FileAccess.get_modified_time(path))
		if _watch_paths.get(path, 0) == mtime:
			continue
		_watch_paths[path] = mtime
		_hot_reload_domain(d)


## Editor-only: reloads + revalidates one changed domain. On success swaps the
## property and emits config_reloaded; on failure logs a warning, retains the
## last valid state, and does NOT emit (EC-8).
func _hot_reload_domain(d: Dictionary) -> void:
	var previous: Resource = get(d["prop"])
	var fresh: Resource = load(d["path"])
	if fresh == null:
		push_warning("GameConfig: hot-reload of %s failed to parse — retaining last valid state." % d["path"])
		return
	set(d["prop"], fresh)
	var err := _validate_domain(d, d["path"])
	if not err.is_empty():
		push_warning("GameConfig: hot-reload of %s invalid (%s) — retaining last valid state." % [d["path"], err])
		set(d["prop"], previous)
		return
	config_reloaded.emit(d["prop"])
