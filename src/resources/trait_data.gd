class_name TraitData
extends Resource
## TraitData — one NPC trait definition (NPC Trait Database GDD Rule 1).
## A structured data record: id, display_name, description, rarity,
## approach_affinity (keyed by GameEnums.DialogueApproach, 5-band values),
## archetype_tags. Static definition only — no hidden/revealed runtime state
## (that is the NPC Character System's concern, Rule §States).

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var rarity: GameEnums.TraitRarity = GameEnums.TraitRarity.COMMON
## Keyed by GameEnums.DialogueApproach int -> float in [-1.0, 1.0]. All four
## approaches must be present (0.0 = neutral). 5-band values only at MVP.
@export var approach_affinity: Dictionary = {}
## NPC archetype IDs (e.g. ["widow", "elder"]) that may carry this trait.
## Empty array = archetype-agnostic (eligible for any archetype).
@export var archetype_tags: Array[String] = []
