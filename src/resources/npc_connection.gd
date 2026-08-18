class_name NPCConnection
extends Resource
## NPCConnection — one social edge from an NPC to a target NPC (NPC Character
## System GDD Rule 4). Authored per-village in the village definition and
## materialized onto NpcRecord.social_connections by NPCRegistry (Rule 8).
## Determinism note: edges are hand-authored data, never generated.

## Target NPC id — must resolve to a valid npc_id in NPCRegistry (E3).
@export var target_npc_id: String = ""
## Relationship type (Rule 4 — MVP: SPOUSE..EMPLOYER).
@export var relationship_type: GameEnums.RelationshipType = GameEnums.RelationshipType.NEIGHBOR
## Base social spread strength [0.0, 1.0]; 1.0 = baseline (Rule 4 / Tuning).
@export var influence_weight: float = 1.0