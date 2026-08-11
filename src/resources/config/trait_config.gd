class_name TraitConfig
extends Resource
## TraitConfig — config domain (ADR-0005, slot traits).
## Field ranges/defaults from design/gdd/game-config.md (authoritative range
## table). GameConfig (Autoload slot 1) is the ONLY reader of this .tres.

@export var common_trait_weight: int = 60
@export var uncommon_trait_weight: int = 30
@export var rare_trait_weight: int = 10
@export var traits_per_npc_min: int = 2
@export var traits_per_npc_max: int = 4

## Validation schema — design/gdd/game-config.md range table.
static func get_validation_schema() -> Dictionary:
	return {
		"common_trait_weight": {"min": 1, "max": 100, "required": true},
		"uncommon_trait_weight": {"min": 1, "max": 100, "required": true},
		"rare_trait_weight": {"min": 1, "max": 100, "required": true},
		"traits_per_npc_min": {"min": 1, "max": 5, "required": true},
		"traits_per_npc_max": {"min": 1, "max": 8, "required": true},
	}
