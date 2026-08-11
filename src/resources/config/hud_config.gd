class_name HUDConfig
extends Resource
## HUDConfig — config domain (ADR-0005, slot hud; 9th domain per the HUD &
## Progress System GDD — system #14).
## Field ranges/defaults from design/gdd/game-config.md (authoritative range
## table). top_strip_height_dp is a cross-system layout contract consumed by
## the Village Map View (F1 top inset).
## GameConfig (Autoload slot 1) is the ONLY reader of this .tres.

@export var top_strip_height_dp: int = 56
@export var chronicle_card_hold_sec: float = 4.0
@export var chronicle_card_fade_ms: int = 400
@export var chronicle_card_fade_in_ms: int = 250
@export var reduced_motion_card_fade_ms: int = 100

## Validation schema — design/gdd/game-config.md range table.
static func get_validation_schema() -> Dictionary:
	return {
		"top_strip_height_dp": {"min": 44, "max": 64, "required": true},
		"chronicle_card_hold_sec": {"min": 3.0, "max": 6.0, "required": true},
		"chronicle_card_fade_ms": {"min": 200, "max": 800, "required": true},
		"chronicle_card_fade_in_ms": {"min": 100, "max": 400, "required": true},
		"reduced_motion_card_fade_ms": {"min": 0, "max": 500, "required": true},
	}
