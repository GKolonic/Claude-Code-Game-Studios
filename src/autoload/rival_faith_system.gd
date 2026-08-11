extends Node
## RivalFaithSystem — Autoload stub, ADR-0001 slot 9.
## Feature: rival faith pressure (interval, targeting, grace window).
## Boots AFTER GameStateManager — subscribes turn_advancing (architecture
## §1.1: depends on GSM, NPCRegistry, CLE, TraitDB, GameConfig). Real logic
## lands at M3. Boot-order shell: asserts slots 1-8 are booted.

func _ready() -> void:
	assert(is_instance_valid(GameConfig),
		"RFS (slot 9): GameConfig (slot 1) must boot first (ADR-0001)")
	assert(is_instance_valid(TraitDatabase),
		"RFS (slot 9): TraitDatabase (slot 2) must boot first (ADR-0001)")
	assert(is_instance_valid(DialogueDatabase),
		"RFS (slot 9): DialogueDatabase (slot 3) must boot first (ADR-0001)")
	assert(is_instance_valid(NPCRegistry),
		"RFS (slot 9): NPCRegistry (slot 5) must boot first (ADR-0001)")
	assert(is_instance_valid(ConversionLogicEngine),
		"RFS (slot 9): ConversionLogicEngine (slot 6) must boot first (ADR-0001)")
	assert(is_instance_valid(DialogueConversionSystem),
		"RFS (slot 9): DialogueConversionSystem (slot 7) must boot first (ADR-0001)")
	assert(is_instance_valid(GameStateManager),
		"RFS (slot 9): GameStateManager (slot 8) must boot first (ADR-0001)")
