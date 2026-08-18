class_name VillageDefinition
extends Resource
## VillageDefinition — one authorised village's content definition
## (ADR-0002, Decision 3 — schema CONFIRMED by Creative Director ruling
## 2026-08-18: village_id, npc_definitions, map_art_path, rng_seed only).
## Hand-authored .tres per village at res://assets/data/villages/; consumed
## by NPCRegistry.initialize_village() (NPC CS Rule 8) which builds one
## NpcRecord per npc_definitions entry.
##
## npc_definitions entries are Dictionaries (hand-authored, per the approved
## schema): npc_id, archetype (GameEnums.NPCArchetype int), display_name,
## map_position (Vector2i), social_connections (Array[Dictionary] with
## target_npc_id/relationship_type/influence_weight), optional access_gate
## (Dictionary with required_belief_state/required_npc_ids).

## Village id (e.g. "village_01") — feeds NPC id prefixes and tr() keys.
@export var village_id: String = ""
## One dictionary per NPC slot, in generation order (NPC CS Rule 8).
@export var npc_definitions: Array[Dictionary] = []
## Village map art, res://assets/maps/{village_id}/village_map.png (VMV Rule 2).
@export var map_art_path: String = ""
## Fixed seed for deterministic generation (ADR-0007 Decision 1).
@export var rng_seed: int = 0