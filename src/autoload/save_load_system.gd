extends Node
## SaveLoadSystem — Autoload stub, ADR-0001 slot 10.
## Feature: JSON v1 persistence; boot calls load_game() once. Boots after
## NPCRegistry + GSM because its load_game() touches both (architecture §1.1;
## Save&Load GDD note corrected to NPCRegistry -> DCS -> GSM -> SaveLoad).
## Real logic lands at M4. Boot-order shell: asserts slots 1-8 are booted.
##
## Sprint 1 story 1-22 adds the load-game call-site scaffold: signal contract
## (Save&Load GDD Exposed API) + an idempotent load_game() stub. At MVP no save
## file can exist (nothing writes saves), so per GDD AC-01 the stub emits
## load_not_found and returns — the boot scene shows its title placeholder.
## File checks, deserialization, GSM/NPCRegistry restore and migrations are M4
## (Save&Load GDD Rules 5-7 / AC-02..13).

signal load_completed(village_id: String)  # load succeeded — downstream rebuild
signal load_not_found()                    # no save file — proceed as new game
signal load_failed()                       # file corrupt/unreadable — new game
signal save_completed()                    # write succeeded
signal save_failed()                       # write failed — log only

const SAVE_VERSION_CURRENT: int = 1
const SAVE_FILE_PATH: String = "user://faithful_save.json"

var _is_loaded: bool = false  # EC-8: load_game() runs once; warn on re-entry.


func _ready() -> void:
	assert(is_instance_valid(GameConfig),
		"SaveLoadSystem (slot 10): GameConfig (slot 1) must boot first (ADR-0001)")
	assert(is_instance_valid(NPCRegistry),
		"SaveLoadSystem (slot 10): NPCRegistry (slot 5) must boot first (ADR-0001)")
	assert(is_instance_valid(DialogueConversionSystem),
		"SaveLoadSystem (slot 10): DialogueConversionSystem (slot 7) must boot first (ADR-0001)")
	assert(is_instance_valid(GameStateManager),
		"SaveLoadSystem (slot 10): GameStateManager (slot 8) must boot first (ADR-0001)")


func load_game() -> void:
	## Called once at boot by the game boot sequence (ADR-0004: Main._ready()).
	## Scaffold: idempotent guard (GDD EC-8); no save file can exist at MVP, so
	## always emit load_not_found (GDD AC-01 new-game path). M4 replaces the
	## body with the full Rule 5 sequence (FileAccess check, JSON parse,
	## NPCRegistry.deserialize, GameStateManager.restore_from_save).
	if _is_loaded:
		push_warning("SaveLoadSystem.load_game() called more than once — "
			+ "idempotent guard (Save&Load GDD EC-8); ignoring second call")
		return
	_is_loaded = true
	load_not_found.emit()