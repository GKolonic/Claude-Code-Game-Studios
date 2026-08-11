extends Node
## DialogueDatabase — Autoload stub, ADR-0001 slot 3.
## Foundation: loads res://assets/data/dialogue/dialogue_database.tres
## (100 scaffold strings). Real logic lands in Sprint 1 task 1-12. Boot-order
## shell: asserts slots 1-2 are already booted (ADR-0001 — foundation chain).

func _ready() -> void:
	assert(is_instance_valid(GameConfig),
		"DialogueDatabase (slot 3): GameConfig (slot 1) must boot first (ADR-0001)")
	assert(is_instance_valid(TraitDatabase),
		"DialogueDatabase (slot 3): TraitDatabase (slot 2) must boot first (ADR-0001)")
