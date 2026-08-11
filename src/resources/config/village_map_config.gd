class_name VillageMapConfig
extends Resource
## VillageMapConfig — config domain (ADR-0005, slot map).
## Field ranges/defaults from design/gdd/game-config.md (authoritative range
## table). Color fields carry no min/max (only `required`).
## ink_bleed_color ships as #E6BE64 per OQ-5 resolution.
## GameConfig (Autoload slot 1) is the ONLY reader of this .tres.

@export var map_grid_columns: int = 4
@export var map_grid_rows: int = 6
@export var ink_bleed_duration_ms: int = 1750
@export var ink_bleed_opacity: float = 0.35
@export var ink_bleed_color: Color = Color8(230, 190, 100)  # #E6BE64 Scripture Gold
@export var ink_bleed_max_radius_dp: int = 260
@export var rival_marker_dwell_sec: float = 4.0
@export var rival_marker_fade_ms: int = 300
@export var return_halo_advance_color: Color = Color8(242, 193, 78)  # warm gold
@export var return_halo_regress_color: Color = Color8(90, 122, 154)  # cool blue-grey
@export var return_halo_max_alpha: float = 0.12
@export var reduced_motion_ink_fade_ms: int = 100

## Validation schema — design/gdd/game-config.md range table.
static func get_validation_schema() -> Dictionary:
	return {
		"map_grid_columns": {"min": 3, "max": 6, "required": true},
		"map_grid_rows": {"min": 5, "max": 8, "required": true},
		"ink_bleed_duration_ms": {"min": 1500, "max": 2000, "required": true},
		"ink_bleed_opacity": {"min": 0.30, "max": 0.40, "required": true},
		"ink_bleed_color": {"required": true},
		"ink_bleed_max_radius_dp": {"min": 160, "max": 400, "required": true},
		"rival_marker_dwell_sec": {"min": 1.0, "max": 8.0, "required": true},
		"rival_marker_fade_ms": {"min": 100, "max": 600, "required": true},
		"return_halo_advance_color": {"required": true},
		"return_halo_regress_color": {"required": true},
		"return_halo_max_alpha": {"min": 0.05, "max": 0.25, "required": true},
		"reduced_motion_ink_fade_ms": {"min": 0, "max": 500, "required": true},
	}
