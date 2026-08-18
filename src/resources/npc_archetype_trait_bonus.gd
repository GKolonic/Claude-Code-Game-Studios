class_name NPCArchetypeTraitBonus
extends Resource
## NPCArchetypeTraitBonus — one trait's selection-weight bonus for an
## archetype (NPC Character System GDD Rule 3 / Archetype Trait Weight
## Formula). Authoring guardrail: trait_id must resolve in TraitDatabase
## (16 MVP ids); bonus_pct in [0.0, 1.0] (0.0 = trait at rarity base weight).

## TraitDatabase id the bonus applies to (Rule 3 — must match catalogue).
@export var trait_id: String = ""
## Additive % on the rarity base weight (e.g. 0.20 = +20%) [0.0, 1.0].
@export var bonus_pct: float = 0.0