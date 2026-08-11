class_name ProgressionConfig
extends Resource
## ProgressionConfig — config domain (ADR-0005, slot progression).
## Field ranges/defaults from design/gdd/game-config.md (authoritative range
## table). GameConfig (Autoload slot 1) is the ONLY reader of this .tres.

@export var faith_power_per_conversion: int = 10
@export var missionary_unlock_threshold: int = 100
@export var court_unlock_threshold: int = 250
@export var crusade_unlock_threshold: int = 500
@export var village_win_conversion_pct: float = 0.75

## Validation schema — design/gdd/game-config.md range table.
static func get_validation_schema() -> Dictionary:
	return {
		"faith_power_per_conversion": {"min": 1, "max": 100, "required": true},
		"missionary_unlock_threshold": {"min": 10, "max": 1000, "required": true},
		"court_unlock_threshold": {"min": 10, "max": 1000, "required": true},
		"crusade_unlock_threshold": {"min": 10, "max": 1000, "required": true},
		"village_win_conversion_pct": {"min": 0.5, "max": 1.0, "required": true},
	}
