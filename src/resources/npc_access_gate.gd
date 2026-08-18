class_name NPCAccessGate
extends Resource
## NPCAccessGate — access lock on an NPC (NPC Character System GDD Rule 1/6).
## If set on an NpcRecord, that NPC is locked until every id in
## required_npc_ids reaches at least required_belief_state.
## Nullable on NpcRecord — absent gate means always approachable (when
## cooldown/counter gates pass). Authored per-village; validated at
## initialize_village() (E2: dead required_npc_ids -> gate cleared).

## Belief state the gating NPCs must reach (Rule 6: belief_state >= this).
@export var required_belief_state: GameEnums.BeliefState = GameEnums.BeliefState.OPEN
## All listed NPCs must reach required_belief_state (Rule 6). Empty array is
## an authoring error (would lock the NPC permanently) — flagged, not silent.
@export var required_npc_ids: Array[String] = []