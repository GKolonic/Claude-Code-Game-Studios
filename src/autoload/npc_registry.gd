extends Node
## NPCRegistry — Autoload stub, ADR-0001 slot 5.
## Core: NPC truth + controlled mutation. Real logic lands at M2 (Sprint 2).
## Boot-order shell: asserts the four foundation Autoloads (slots 1-4) are
## booted (architecture §1.1 — depends on TraitDB, GameConfig, DCD enums).

func _ready() -> void:
	assert(is_instance_valid(GameConfig),
		"NPCRegistry (slot 5): GameConfig (slot 1) must boot first (ADR-0001)")
	assert(is_instance_valid(TraitDatabase),
		"NPCRegistry (slot 5): TraitDatabase (slot 2) must boot first (ADR-0001)")
	assert(is_instance_valid(DialogueDatabase),
		"NPCRegistry (slot 5): DialogueDatabase (slot 3) must boot first (ADR-0001)")
	assert(is_instance_valid(MobileTouchFramework),
		"NPCRegistry (slot 5): MobileTouchFramework (slot 4) must boot first (ADR-0001)")
