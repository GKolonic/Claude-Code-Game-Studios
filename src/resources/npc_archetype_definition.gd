class_name NPCArchetypeDefinition
extends Resource
## NPCArchetypeDefinition — one of the seven archetypes' static definition
## (NPC Character System GDD Rule 3). Data carrier authored in
## assets/data/npcs/archetypes.tres, read by NPCRegistry
## (get_archetype_definition) and the Faith Spread System
## (social_influence_weight, per Rule 1 — NOT on NpcRecord).

## Archetype enum id (Rule 3 seven MVP archetypes).
@export var archetype_id: GameEnums.NPCArchetype = GameEnums.NPCArchetype.LABORER
## Archetype display name (e.g. "Elder") shown in UI.
@export var display_name: String = ""
## One-sentence internal description (Rule 3).
@export var role_description: String = ""
## Faith Spread multiplier [0.1, 5.0]; 1.0 = baseline (Rule 3 table).
@export var social_influence_weight: float = 1.0
## Per-trait percentage bonuses applied by the Archetype Trait Weight
## Formula during generation (Rule 3 / NPC CS Formulas).
@export var trait_weight_bonuses: Array[NPCArchetypeTraitBonus] = []
## Directory path to the portrait asset set, res://assets/portraits/{slug}/
## (Rule 3 portrait path contract — exactly six expression PNGs).
@export var portrait_asset_path: String = ""