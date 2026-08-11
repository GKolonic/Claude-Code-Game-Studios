class_name UITimingConfig
extends Resource
## UITimingConfig — config domain (ADR-0005, slot ui_timing).
## Field ranges/defaults from design/gdd/game-config.md (authoritative range
## table). GameConfig (Autoload slot 1) is the ONLY reader of this .tres.

@export var approach_confirm_hold_sec: float = 0.6
@export var hardened_reveal_hold_sec: float = 1.0
@export var dialogue_line_hold_sec: float = 2.0
@export var outcome_display_hold_sec: float = 2.5
@export var scene_transition_duration_sec: float = 0.5
@export var portrait_expression_hold_frames: int = 30
@export var trait_card_reveal_ms: int = 350

## Validation schema — design/gdd/game-config.md range table.
static func get_validation_schema() -> Dictionary:
	return {
		"approach_confirm_hold_sec": {"min": 0.3, "max": 1.2, "required": true},
		"hardened_reveal_hold_sec": {"min": 0.5, "max": 1.5, "required": true},
		"dialogue_line_hold_sec": {"min": 0.5, "max": 5.0, "required": true},
		"outcome_display_hold_sec": {"min": 0.5, "max": 5.0, "required": true},
		"scene_transition_duration_sec": {"min": 0.1, "max": 2.0, "required": true},
		"portrait_expression_hold_frames": {"min": 1, "max": 120, "required": true},
		"trait_card_reveal_ms": {"min": 200, "max": 600, "required": true},
	}
