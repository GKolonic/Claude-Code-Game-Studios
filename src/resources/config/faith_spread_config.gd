class_name FaithSpreadConfig
extends Resource
## FaithSpreadConfig — config domain (ADR-0005, slot faith_spread).
## Field ranges/defaults from design/gdd/game-config.md (authoritative range
## table). Ships at MVP with no consumer (GameConfig AC-1 / OQ-10 — the
## nine-domain contract is satisfied by the file existing).
## GameConfig (Autoload slot 1) is the ONLY reader of this .tres.

@export var passive_spread_radius: int = 2
@export var spread_rate_per_tick: float = 0.05
@export var attrition_rate_per_tick: float = 0.02
@export var spread_tick_interval_sec: float = 30.0

## Validation schema — design/gdd/game-config.md range table.
static func get_validation_schema() -> Dictionary:
	return {
		"passive_spread_radius": {"min": 1, "max": 5, "required": true},
		"spread_rate_per_tick": {"min": 0.01, "max": 0.5, "required": true},
		"attrition_rate_per_tick": {"min": 0.0, "max": 0.3, "required": true},
		"spread_tick_interval_sec": {"min": 5.0, "max": 120.0, "required": true},
	}
