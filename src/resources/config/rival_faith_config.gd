class_name RivalFaithConfig
extends Resource
## RivalFaithConfig — config domain (ADR-0005, slot rival_faith).
## Field ranges/defaults from design/gdd/game-config.md (authoritative range
## table). NOTE: aggression_interval_turns default 6 is authoritative per
## game-config.md (R2: rival-faith-system.md lists 3 — ruling deferred to
## Sprint 1 task 1-18; no code impact — consumers read at call time).
## GameConfig (Autoload slot 1) is the ONLY reader of this .tres.

@export var aggression_interval_turns: int = 6
@export var reharden_strength: float = 0.4
@export var counter_approach_random_weight: float = 0.3

## Validation schema — design/gdd/game-config.md range table.
static func get_validation_schema() -> Dictionary:
	return {
		"aggression_interval_turns": {"min": 2, "max": 20, "required": true},
		"reharden_strength": {"min": 0.1, "max": 1.0, "required": true},
		"counter_approach_random_weight": {"min": 0.0, "max": 1.0, "required": true},
	}
