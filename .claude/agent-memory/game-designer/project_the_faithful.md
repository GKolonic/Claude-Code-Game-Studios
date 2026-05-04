---
name: Project — The Faithful
description: Core project context for The Faithful — game concept, systems status, and active design work
type: project
---

Mobile narrative strategy game where the player is a prophet spreading a new religion one conversation at a time. Godot 4.6, GDScript, mobile-first (iOS/Android), turn-based.

**Why:** Solo indie project, MVP scope is a single village with 8–12 NPCs.

**How to apply:** All design recommendations must be mobile-first (large tap targets, one-handed play, 10–20 min sessions). Turn-based means no real-time timers. Systems must be scoped to MVP realism.

## Current Design Status (as of 2026-04-24)

4 Foundation GDDs designed: Game Config, NPC Trait Database, Dialogue Content Database, Mobile Touch Framework.

NPC Character System GDD is in-progress — Sections A (Overview) and B (Player Fantasy) are written. Section C (Detailed Design / Core Rules) is being designed now.

## Key Design Decisions Made

- Belief states: 4-state enum PAGAN → OPEN → SYMPATHETIC → CONVERTED
- Conversion outcomes (from Dialogue & Conversion System): CONVERTED, SOFTENED, RESISTED, HARDENED
- Cooldown: Turn-count global cooldown (N turns from GameConfig.conversion.approach_cooldown_turns, default 2)
- Social connections: Array[NPCConnection] with {target_npc_id, relationship_type, influence_weight 0.0–1.0}
- 7 NPC archetypes: Laborer, Elder, Merchant, Soldier, Scholar, Widow/Bereaved, Noble
- 4 dialogue approaches: GRIEF, AMBITION, DOUBT, FEAR
- 16 MVP traits: 7 Common, 6 Uncommon, 3 Rare

## NPC Schema (current)

- npc_id: String
- archetype: NPCArchetype enum
- display_name: String
- assigned_traits: Array[String]
- revealed_traits: Array[String]
- belief_state: BeliefState enum
- cooldown_turns_remaining: int
- social_connections: Array[NPCConnection]
- social_influence_weight: float
