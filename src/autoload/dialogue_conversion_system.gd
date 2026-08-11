extends Node
## DialogueConversionSystem — Autoload stub, ADR-0001 slot 7.
## Feature: session orchestrator (resolve -> apply finally guarantee; owns the
## session state machine and recency pools). Boots BEFORE GameStateManager
## (GSM Rule 10 / ADR-0001) so GSM's deferred signal connect never misses a
## session signal. Real logic lands at M3. Boot-order shell: asserts slots 1-6
## are booted (architecture §1.1 — depends on NPCRegistry, CLE, DialogueDB,
## TraitDB, GameConfig). The stub declares the session signals GSM subscribes
## to — this is the DCS<->GSM contract surface.

signal session_begun(npc_id: String)
signal session_complete

func _ready() -> void:
	assert(is_instance_valid(GameConfig),
		"DCS (slot 7): GameConfig (slot 1) must boot first (ADR-0001)")
	assert(is_instance_valid(TraitDatabase),
		"DCS (slot 7): TraitDatabase (slot 2) must boot first (ADR-0001)")
	assert(is_instance_valid(DialogueDatabase),
		"DCS (slot 7): DialogueDatabase (slot 3) must boot first (ADR-0001)")
	assert(is_instance_valid(MobileTouchFramework),
		"DCS (slot 7): MobileTouchFramework (slot 4) must boot first (ADR-0001)")
	assert(is_instance_valid(NPCRegistry),
		"DCS (slot 7): NPCRegistry (slot 5) must boot first (ADR-0001)")
	assert(is_instance_valid(ConversionLogicEngine),
		"DCS (slot 7): ConversionLogicEngine (slot 6) must boot first (ADR-0001)")
