---
name: Archetype naming reconciliation — art bible vs GDD
description: Art bible and NPC Character System GDD use different archetype names; mapping is needed for any portrait/expression work
type: project
---

The art bible (Section 5) defines 5 visual portrait archetypes: Believer, Skeptic, Noble, Rival Faith Figure, Prophet.

The NPC Character System GDD (`design/gdd/npc-character-system.md`) defines 7 gameplay archetypes as an enum: LABORER, ELDER, MERCHANT, SOLDIER, SCHOLAR, WIDOW, NOBLE.

These are not the same lists. Resolution: art bible archetypes are portrait style groupings; gameplay archetypes are data-layer categories. Mapping:

| NPC Archetype (GDD enum) | Art Bible Portrait Group |
|---|---|
| LABORER | Believer (working-class variation) |
| WIDOW | Believer (grief variation) |
| ELDER | Believer (elder variation) |
| MERCHANT | Skeptic |
| SOLDIER | Skeptic (military variation) |
| SCHOLAR | Skeptic (scholarly variation) |
| NOBLE | Noble |

Rival Faith Figure and Prophet are not NPC gameplay archetypes — they are player-character and special narrative roles.

**Why:** Any portrait system work that maps expression states to archetypes must reconcile both lists or will produce inconsistent asset specs.

**How to apply:** When a brief or user message refers to "Skeptic" or "Believer" archetypes, map to the GDD enum before writing implementation specs. When referring to GDD archetypes in art direction copy, use the art bible label in parentheses for readability.
