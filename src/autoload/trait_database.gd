extends Node
## TraitDatabase — Autoload stub, ADR-0001 slot 2.
## Foundation: loads res://assets/data/traits/trait_database.tres (16 traits).
## Real logic lands in Sprint 1 task 1-11. Boot-order shell: asserts GameConfig
## (slot 1) is already booted (ADR-0001 — foundation boot chain).

func _ready() -> void:
	assert(is_instance_valid(GameConfig),
		"TraitDatabase (slot 2): GameConfig (slot 1) must boot first (ADR-0001)")
