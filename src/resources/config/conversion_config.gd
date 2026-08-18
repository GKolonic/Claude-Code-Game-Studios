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
# CLE fields (Sprint 2 task 2-2 / approved decision #6; game-config.md authoritative)
@export var trait_modifier_cap: float = 0.50
@export var min_success_chance: float = 0.05
@export var max_success_chance: float = 0.80
@export var belief_modifier_open: float = 0.10
@export var belief_modifier_wavering: float = 0.20
@export var softened_band_fraction: float = 0.545
@export var resisted_band_fraction: float = 0.455
@export var repeat_penalty_per_use: float = 0.05
@export var max_repeat_penalty: float = 0.15

## Validation schema — design/gdd/game-config.md range table. Field name →
## {min, max, required}. Non-numeric fields (Color) carry only `required`.
static func get_validation_schema() -> Dictionary:
	return {
		"base_success_chance": {"min": 0.05, "max": 0.95, "required": true},
		"trait_modifier_weight": {"min": 0.0, "max": 1.0, "required": true},
		"approach_cooldown_turns": {"min": 1, "max": 10, "required": true},
		"hard_mode_base_modifier": {"min": 0.5, "max": 1.0, "required": false},
		"max_approaches_per_npc": {"min": 1, "max": 20, "required": true},
		"trait_modifier_cap": {"min": 0.25, "max": 0.75, "required": true},
		"min_success_chance": {"min": 0.01, "max": 0.20, "required": true},
		"max_success_chance": {"min": 0.50, "max": 1.00, "required": true},
		"belief_modifier_open": {"min": 0.0, "max": 0.25, "required": true},
		"belief_modifier_wavering": {"min": 0.05, "max": 0.35, "required": true},
		"softened_band_fraction": {"min": 0.20, "max": 0.70, "required": true},
		"resisted_band_fraction": {"min": 0.20, "max": 0.60, "required": true},
		"repeat_penalty_per_use": {"min": 0.0, "max": 0.15, "required": true},
		"max_repeat_penalty": {"min": 0.0, "max": 0.30, "required": true},
	}
