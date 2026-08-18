class_name NpcRecord
extends Resource
## NpcRecord — one NPC's full per-character state (NPC Character System GDD
## Rule 1). Canonical object every downstream system reads from. Fields map
## 1:1 to the GDD schema (ADR-0002 Decision 1).
##
## Hand-authored fields (npc_id, archetype, display_name, social_connections,
## map_position, access_gate) arrive from the village definition dictionary
## via NPCRegistry.generate_npc(); the rest are produced by generation
## (belief, cooldowns, traits, counters). NOTE: social_influence_weight is
## NOT stored here — it lives on NPCArchetypeDefinition and is retrieved via
## NPCRegistry.get_archetype_definition(npc.archetype) (Rule 1 / ADR-0002).

## Unique id, format [village_id]_[archetype_slug]_[index] (Rule 1).
@export var npc_id: String = ""
## Archetype enum (Rule 3) — drives portrait paths + social influence lookups.
@export var archetype: GameEnums.NPCArchetype = GameEnums.NPCArchetype.LABORER
## Player-visible name; hand-authored at MVP (NPC CS OQ-4).
@export var display_name: String = ""
## Full list of trait IDs from TraitDatabase, hidden until revealed (Rule 7).
@export var assigned_traits: Array[String] = []
## Subset of assigned_traits visible to the player (Rule 7).
@export var revealed_traits: Array[String] = []
## Current belief state (Rule 2). Default STEADFAST at generation.
@export var belief_state: GameEnums.BeliefState = GameEnums.BeliefState.STEADFAST
## Turns until approachable; 0 = approachable (Rule 5).
@export var cooldown_turns_remaining: int = 0
## Rival grace-window turns remaining; 0 = window closed (Rule 5).
@export var recently_converted_turns_remaining: int = 0
## Total approaches made (gate: GameConfig.conversion.max_approaches_per_npc).
@export var approach_count: int = 0
## DialogueApproach -> int attempt count per approach (Rule 5).
@export var approach_history: Dictionary = {}
## Social graph edges to neighbouring NPCs (Rule 4).
@export var social_connections: Array[NPCConnection] = []
## Grid position (col, row) on the village map (VMV F1; 4x6 grid at MVP).
@export var map_position: Vector2i = Vector2i.ZERO
## Nullable — if set, NPC is locked until the gate condition is met (Rule 6).
@export var access_gate: NPCAccessGate = null