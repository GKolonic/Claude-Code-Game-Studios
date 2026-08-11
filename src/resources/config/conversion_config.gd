class_name ConversionConfig
extends Resource
## ConversionConfig — config domain (ADR-0005, slot conversion).
## Field ranges/defaults from design/gdd/game-config.md (authoritative range
## table). GameConfig (Autoload slot 1) is the ONLY reader of this .tres.

@export var base_success_chance: float = 0.35
@export var trait_modifier_weight: float = 0.25
@export var approach_cooldown_turns: int = 3
@export var hard_mode_base_modifier: float = 0.8
@export var max_approaches_per_npc: int = 5

## Validation schema — design/gdd/game-config.md range table. Field name →
## {min, max, required}. Non-numeric fields (Color) carry only `required`.
static func get_validation_schema() -> Dictionary:
	return {
		"base_success_chance": {"min": 0.05, "max": 0.95, "required": true},
		"trait_modifier_weight": {"min": 0.0, "max": 1.0, "required": true},
		"approach_cooldown_turns": {"min": 1, "max": 10, "required": true},
		"hard_mode_base_modifier": {"min": 0.5, "max": 1.0, "required": false},
		"max_approaches_per_npc": {"min": 1, "max": 20, "required": true},
	}
