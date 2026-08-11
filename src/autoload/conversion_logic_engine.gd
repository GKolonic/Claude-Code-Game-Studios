extends Node
## ConversionLogicEngine — Autoload stub, ADR-0001 slot 6.
## Core: pure stateless resolve(approach, npc_id) -> ConversionOutcome.
## Real logic lands at M2 (Sprint 2). Boot-order shell: asserts slots 1-5 are
## booted (architecture §1.1 — depends on TraitDB, NPCRegistry, GameConfig,
## DCD enums).

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
