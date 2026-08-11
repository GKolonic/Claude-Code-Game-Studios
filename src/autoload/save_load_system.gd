extends Node
## SaveLoadSystem — Autoload stub, ADR-0001 slot 10.
## Feature: JSON v1 persistence; boot calls load_game() once. Boots after
## NPCRegistry + GSM because its load_game() touches both (architecture §1.1;
## Save&Load GDD note corrected to NPCRegistry -> DCS -> GSM -> SaveLoad).
## Real logic lands at M4. Boot-order shell: asserts slots 1-8 are booted.

func _ready() -> void:
	assert(is_instance_valid(GameConfig),
		"SaveLoadSystem (slot 10): GameConfig (slot 1) must boot first (ADR-0001)")
	assert(is_instance_valid(NPCRegistry),
		"SaveLoadSystem (slot 10): NPCRegistry (slot 5) must boot first (ADR-0001)")
	assert(is_instance_valid(DialogueConversionSystem),
		"SaveLoadSystem (slot 10): DialogueConversionSystem (slot 7) must boot first (ADR-0001)")
	assert(is_instance_valid(GameStateManager),
		"SaveLoadSystem (slot 10): GameStateManager (slot 8) must boot first (ADR-0001)")
