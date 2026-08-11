class_name PortraitConfig
extends Resource
## PortraitConfig — config domain (ADR-0005, slot portraits).
## Field ranges/defaults from design/gdd/game-config.md (authoritative range
## table). Color fields carry no min/max (only `required`) — EC-9 precedent:
## per-field validation only; P&E F4 clamps the total overlay lifetime.
## GameConfig (Autoload slot 1) is the ONLY reader of this .tres.

@export var dissolve_duration_ms: int = 350
@export var conversion_dissolve_duration_ms: int = 400
@export var conversion_overlay_color: Color = Color8(242, 163, 60)  # #F2A33C warm amber
@export var conversion_overlay_surge_alpha: float = 0.55
@export var conversion_overlay_surge_ms: int = 150
@export var conversion_overlay_hold_ms: int = 50
@export var conversion_overlay_fade_ms: int = 500
@export var reduced_motion_dissolve_ms: int = 0
@export var reduced_motion_overlay_fade_ms: int = 100

## Validation schema — design/gdd/game-config.md range table.
static func get_validation_schema() -> Dictionary:
	return {
		"dissolve_duration_ms": {"min": 150, "max": 800, "required": true},
		"conversion_dissolve_duration_ms": {"min": 200, "max": 1000, "required": true},
		"conversion_overlay_color": {"required": true},
		"conversion_overlay_surge_alpha": {"min": 0.20, "max": 0.80, "required": true},
		"conversion_overlay_surge_ms": {"min": 50, "max": 500, "required": true},
		"conversion_overlay_hold_ms": {"min": 0, "max": 300, "required": true},
		"conversion_overlay_fade_ms": {"min": 100, "max": 1500, "required": true},
		"reduced_motion_dissolve_ms": {"min": 0, "max": 200, "required": true},
		"reduced_motion_overlay_fade_ms": {"min": 0, "max": 500, "required": true},
	}
