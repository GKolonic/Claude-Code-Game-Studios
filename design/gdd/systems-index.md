# Systems Index: The Faithful

> **Status**: Draft
> **Created**: 2026-04-20
> **Last Updated**: 2026-04-20
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

The game operates at two interlocking scales: **The Faithful** (NPC micro layer — individual conversion conversations) and **Divine Dominion** (regional macro layer — civilisational faith spread). NPC conversions feed upward into the regional follower economy; regional pressure flows down to shape NPC availability and resistance.

The system architecture has two tiers. The NPC layer (19 systems) is built around a central NPC Character System that every gameplay and UI system reads from. The macro layer (8 systems) aggregates NPC outcomes into regional follower economies, a Policy & Doctrine Tree, building infrastructure, rival AI, and a turn-based region-capture loop. The four game pillars — Every Soul Has a Story, Many Roads to the Divine, The Arc Must Feel Earned, History Writes Itself — constrain every system toward character-driven emergent narrative over scripted or mechanical outcomes.

**Total systems: 27** (19 NPC layer + 8 macro layer). 14 are required for MVP (first playable village). The macro layer begins at Vertical Slice milestone.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Game Config | Core | MVP | Designed | design/gdd/game-config.md | — |
| 2 | NPC Trait Database | Core | MVP | Designed | design/gdd/npc-trait-database.md | — |
| 3 | Dialogue Content Database | Narrative | MVP | Designed | design/gdd/dialogue-content-database.md | — |
| 4 | Mobile Touch Framework | Core | MVP | Designed | design/gdd/mobile-touch-framework.md | — |
| 5 | NPC Character System | Core | MVP | Designed | design/gdd/npc-character-system.md | NPC Trait Database |
| 6 | Conversion Logic Engine | Gameplay | MVP | Designed | design/gdd/conversion-logic-engine.md | NPC Trait Database, Dialogue Content Database, Game Config |
| 7 | Game State Manager | Core | MVP | Designed | design/gdd/game-state-manager.md | NPC Character System |
| 8 | Dialogue & Conversion System | Gameplay | MVP | Designed | design/gdd/dialogue-conversion-system.md | NPC Character System, Conversion Logic Engine, Dialogue Content Database |
| 9 | Rival Faith System | Gameplay | MVP | Designed | design/gdd/rival-faith-system.md | NPC Character System, Dialogue & Conversion System |
| 10 | Save & Load System (inferred) | Persistence | MVP | Designed | design/gdd/save-load-system.md | Game State Manager, NPC Character System |
| 11 | Portrait & Expression System (inferred) | UI | MVP | Not Started | — | NPC Character System |
| 12 | Conversion UI | UI | MVP | Not Started | — | Dialogue & Conversion System, Portrait & Expression System, Mobile Touch Framework |
| 13 | Village Map View | UI | MVP | Not Started | — | NPC Character System, Mobile Touch Framework |
| 14 | HUD & Progress System (inferred) | UI | MVP | Not Started | — | Game State Manager, Mobile Touch Framework |
| 15 | Faith Spread System | Gameplay | Vertical Slice | Not Started | — | NPC Character System, Game State Manager |
| 16 | Audio System (inferred) | Audio | Vertical Slice | Not Started | — | Game State Manager, Dialogue & Conversion System |
| 17 | Tutorial & Onboarding (inferred) | Meta | Vertical Slice | Not Started | — | Dialogue & Conversion System, Village Map View, Game State Manager |
| 18 | Multi-path Expansion System | Progression | Alpha | Not Started | — | Dialogue & Conversion System, Game State Manager |
| 19 | Accessibility System (inferred) | Meta | Alpha | Not Started | — | Mobile Touch Framework |

### Macro Layer Systems (Divine Dominion)

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 20 | Region & World Map System | Macro-Core | Vertical Slice | Not Started | — | NPC Character System, Game State Manager |
| 21 | Follower Economy System | Macro-Core | Vertical Slice | Not Started | — | Region & World Map System, NPC Character System |
| 22 | Resource System (XP / Gold) | Macro-Core | Vertical Slice | Not Started | — | Follower Economy System, Game Config |
| 23 | Policy & Doctrine Tree | Macro-Feature | Alpha | Not Started | — | Resource System, Game Config |
| 24 | Building Window | Macro-Feature | Alpha | Not Started | — | Region & World Map System, Resource System |
| 25 | Rival AI System (Regional) | Macro-Feature | Alpha | Not Started | — | Region & World Map System, Follower Economy System |
| 26 | Events System | Macro-Feature | Alpha | Not Started | — | Game State Manager, Region & World Map System |
| 27 | Progression & Difficulty | Macro-Meta | Alpha | Not Started | — | Region & World Map System, Follower Economy System, Rival AI System (Regional) |

> **Note on System 25**: The macro-layer Rival AI System governs region-level rival religion behavior (mission deployment, region spread, counter-player strategy). It is distinct from System 9 (Rival Faith System), which governs NPC-level rival behavior in individual conversations.

> **Balance flags for macro systems (from design review):** (1) Wealthy Follower drain mechanic (building upkeep) required before any balance pass — without it, Gold scarcity is structurally impossible. (2) Multiplier stacking for buildings must use multiplicative model with diminishing returns cap, not additive. (3) Opposition Score formula must be sigmoid with 5% minimum success floor. (4) Bad Works must include a mandatory fixed cost alongside probabilistic scandal risk.

---

## Categories

| Category | Description | Systems in This Game |
|----------|-------------|----------------------|
| **Core** | Foundation systems everything depends on | Game Config, NPC Trait Database, Mobile Touch Framework, NPC Character System, Game State Manager |
| **Gameplay** | The systems that make the game fun | Conversion Logic Engine, Dialogue & Conversion System, Rival Faith System, Faith Spread System |
| **Progression** | How the player grows over time | Multi-path Expansion System |
| **Persistence** | Save state and continuity | Save & Load System |
| **UI** | Player-facing information displays | Portrait & Expression System, Conversion UI, Village Map View, HUD & Progress System |
| **Audio** | Sound and music systems | Audio System |
| **Narrative** | Story and dialogue delivery | Dialogue Content Database |
| **Meta** | Systems outside the core game loop | Tutorial & Onboarding, Accessibility System |

---

## Priority Tiers

| Tier | Definition | Target Milestone | Design Urgency |
|------|------------|------------------|----------------|
| **MVP** | Required for the core loop to function. Without these, you can't test "is this fun?" | First playable prototype (1 village, 8–12 NPCs) | Design FIRST |
| **Vertical Slice** | Required for one complete, polished area — faith spread, audio, guided onboarding | Vertical slice (1 full region, 30 NPCs) | Design SECOND |
| **Alpha** | All features present in rough form — multi-path strategies, full accessibility | Alpha milestone (3 regions, 60+ NPCs) | Design THIRD |
| **Full Vision** | Polish, procedural NPC generation, async leaderboards | Beta / Release | Design as needed |

---

## Dependency Map

### Foundation Layer (no dependencies)

1. **Game Config** — external data file for all tuning values; nothing is hardcoded; everything reads from here
2. **NPC Trait Database** — defines all trait types, archetypes, and trait metadata; the vocabulary every other NPC system uses
3. **Dialogue Content Database** — all dialogue text, approach names, and outcome descriptions as data; logic systems never contain copy
4. **Mobile Touch Framework** — platform input abstraction for touch; UI systems depend on this for consistent 44dp tap targets and gesture handling

### Core Layer (depends on Foundation)

1. **NPC Character System** — depends on: NPC Trait Database — the central bottleneck; stores belief state, assigned traits, social connections, and cooldown state for every NPC in the scene
2. **Conversion Logic Engine** — depends on: NPC Trait Database, Dialogue Content Database, Game Config — pure logic, no UI; computes approach × trait → probability → outcome; testable in isolation
3. **Game State Manager** — depends on: NPC Character System — tracks win/loss conditions, active village conversion %, scene transitions, and the current dialogue session state

### Feature Layer (depends on Core)

1. **Dialogue & Conversion System** — depends on: NPC Character System, Conversion Logic Engine, Dialogue Content Database — orchestrates the full conversation flow from NPC selection to outcome resolution
2. **Rival Faith System** — depends on: NPC Character System, Dialogue & Conversion System — rival NPC behavior: when to approach the player's converts, which counter-approach to use, how to re-harden recently converted NPCs
3. **Save & Load System** — depends on: Game State Manager, NPC Character System — mobile-appropriate persistence; auto-saves after each conversation; serializes full village state
4. **Faith Spread System** — depends on: NPC Character System, Game State Manager — social pressure propagation; converts shift their neighbors' openness, creating the "ink soaking into parchment" spread effect
5. **Multi-path Expansion System** — depends on: Dialogue & Conversion System, Game State Manager — unlock logic for the Missionary / Court / Crusade expansion paths; gates content behind faith power milestones

### Presentation Layer (depends on Features)

1. **Portrait & Expression System** — depends on: NPC Character System — renders character portrait art with correct emotional expression based on belief state and current dialogue beat
2. **Conversion UI** — depends on: Dialogue & Conversion System, Portrait & Expression System, Mobile Touch Framework — the primary player-facing screen: approach buttons, trait indicators, NPC portrait, outcome display
3. **Village Map View** — depends on: NPC Character System, Mobile Touch Framework — the between-conversation layer; shows NPC positions and belief-state color coding; player selects the next NPC to approach here
4. **HUD & Progress System** — depends on: Game State Manager, Mobile Touch Framework — ambient session progress: village conversion %, faith power level, active rival faith threat indicator
5. **Audio System** — depends on: Game State Manager, Dialogue & Conversion System — ambient music per region, UI feedback sounds, conversion-moment audio cues; reacts to game state changes

### Polish Layer (depends on everything)

1. **Tutorial & Onboarding** — depends on: Dialogue & Conversion System, Village Map View, Game State Manager — guided first-village experience; tutorial-in-disguise as per design intent; never breaks the fiction
2. **Accessibility System** — depends on: Mobile Touch Framework, all UI systems — text scaling, colorblind modes, screen reader support via Godot 4.5+ AccessKit integration

---

## Recommended Design Order

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | Game Config | MVP | Foundation | game-designer | S |
| 2 | NPC Trait Database | MVP | Foundation | game-designer, systems-designer | M |
| 3 | Dialogue Content Database | MVP | Foundation | game-designer, narrative-director | M |
| 4 | Mobile Touch Framework | MVP | Foundation | ux-designer | S |
| 5 | NPC Character System | MVP | Core | game-designer, systems-designer | L |
| 6 | Conversion Logic Engine | MVP | Core | systems-designer | M |
| 7 | Game State Manager | MVP | Core | game-designer | S |
| 8 | Dialogue & Conversion System | MVP | Feature | game-designer, systems-designer | L |
| 9 | Rival Faith System | MVP | Feature | game-designer, ai-programmer | M |
| 10 | Save & Load System | MVP | Feature | game-designer | S |
| 11 | Portrait & Expression System | MVP | Presentation | art-director, game-designer | S |
| 12 | Conversion UI | MVP | Presentation | ux-designer, game-designer | M |
| 13 | Village Map View | MVP | Presentation | ux-designer, game-designer | M |
| 14 | HUD & Progress System | MVP | Presentation | ux-designer, game-designer | S |
| 15 | Faith Spread System | Vertical Slice | Feature | systems-designer, game-designer | M |
| 16 | Audio System | Vertical Slice | Presentation | audio-director | S |
| 17 | Tutorial & Onboarding | Vertical Slice | Polish | ux-designer, game-designer | M |
| 18 | Multi-path Expansion System | Alpha | Feature | game-designer, systems-designer | L |
| 19 | Accessibility System | Alpha | Polish | accessibility-specialist | M |

*Effort: S = 1 session, M = 2–3 sessions, L = 4+ sessions*

---

## Circular Dependencies

- None found. The dependency graph is a strict DAG (directed acyclic graph).

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| NPC Character System | Design + Scope | 8 systems depend on it. Wrong trait schema = cascading redesign across everything | Design first, prototype trait assignment early with `/prototype npc-traits` |
| Conversion Logic Engine | Design | Balance is invisible until playtested — conversion rates that feel right are hard to calibrate on paper | Build the formula with explicit tuning knobs; `/balance-check` after first playtest |
| Dialogue & Conversion System | Scope | Writing enough dialogue variation to avoid repetition is the game's largest content risk | Design the system to be data-driven from Dialogue Content Database; content volume is separate from system design |
| Rival Faith System | Technical | Rival AI that feels reactive without being frustrating is an open design question | Prototype the simplest possible behavior (cooldown + mirror approach) before designing the full system |
| Faith Spread System | Design | Social pressure propagation math could feel opaque or arbitrary | Visualize spread on Village Map View; playtest before tuning |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 27 (19 NPC layer + 8 macro layer) |
| Design docs started | 10 (Game Config, NPC Trait Database, Dialogue Content Database, Mobile Touch Framework, NPC Character System, Conversion Logic Engine, Game State Manager, Dialogue & Conversion System, Rival Faith System, Save & Load System) |
| Design docs reviewed | 0 |
| Design docs approved | 0 |
| MVP systems designed | 10 / 14 (NPC layer) |
| Vertical Slice systems designed | 0 / 5 (3 NPC layer + 2 macro layer) |
| Alpha systems designed | 0 / 6 (2 NPC layer + 4 macro layer) |

---

## Next Steps

- [ ] Design MVP-tier systems in design order above (use `/design-system [system-name]`)
- [ ] Prototype NPC Character System early — it is the highest-risk dependency bottleneck
- [ ] Run `/design-review` on each completed GDD
- [ ] Run `/gate-check pre-production` when all 14 MVP GDDs are complete
