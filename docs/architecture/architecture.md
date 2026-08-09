# The Faithful / Divine Dominion — MVP Architecture Plan

> **Status**: Accepted · **Engine**: Godot 4.6 / GDScript / Compatibility renderer · **Scope**: 14 MVP systems · **Date**: 2026-08-09
> **Source**: All 14 GDDs in `design/gdd/` · `systems-index.md` · `technical-preferences.md` · `src/CLAUDE.md` · ADR template

## Document Status

- **Version**: 1
- **Last Updated**: 2026-08-09
- **Status**: Accepted (Creative Director approval 2026-08-09; drives ADR-0001…0004; ADR-0005…0011 milestone-gated)
- **Engine**: Godot 4.6 / GDScript / Compatibility renderer
- **GDDs Covered**: All 14 MVP systems (Game Config, NPC Trait Database, Dialogue Content Database, Mobile Touch Framework, NPC Character System, Conversion Logic Engine, Game State Manager, Dialogue & Conversion System, Rival Faith System, Save & Load System, Portrait & Expression System, Conversion UI, Village Map View, HUD & Progress System)
- **ADRs Referenced**: ADR-0001 (Autoload architecture & init order) · ADR-0002 (data resource model) · ADR-0003 (signal architecture) · ADR-0004 (scene ownership) — all Accepted

---



## 1. System Inventory & Dependency Graph

### 1.1 The 14 MVP systems, layer-assigned

| # | System | Layer | Runtime Form | Depends On |
|---|--------|-------|--------------|------------|
| 1 | Game Config | Foundation | Autoload `GameConfig` | — |
| 2 | NPC Trait Database | Foundation | Autoload `TraitDatabase` | — |
| 3 | Dialogue Content Database | Foundation | Autoload `DialogueDatabase` | — |
| 4 | Mobile Touch Framework | Foundation | Autoload `MobileTouchFramework` | GameConfig (optional future), engine input |
| 5 | NPC Character System | Core | Autoload `NPCRegistry` | TraitDB, GameConfig, DCD enums |
| 6 | Conversion Logic Engine | Core | Autoload `ConversionLogicEngine` | TraitDB, NPCRegistry, GameConfig, DCD enums |
| 7 | Game State Manager | Core | Autoload `GameStateManager` | NPCRegistry, GameConfig; DCS (signal-only) |
| 8 | Dialogue & Conversion System | Feature | Autoload `DialogueConversionSystem` | NPCRegistry, CLE, DialogueDB, TraitDB, GameConfig |
| 9 | Rival Faith System | Feature | Autoload `RivalFaithSystem` | GSM, NPCRegistry, CLE, TraitDB, GameConfig |
| 10 | Save & Load System | Feature | Autoload `SaveLoadSystem` | GSM, NPCRegistry, DCS (trigger) |
| 11 | Portrait & Expression System | Presentation | Scene node `PortraitController` | NPCRegistry, GameConfig; lifecycle: Conversion UI |
| 12 | Conversion UI | Presentation | Scene `conversation_screen.tscn` | DCS, P&E, MTF, NPCRegistry, TraitDB, GameConfig |
| 13 | Village Map View | Presentation | Scene `village_map.tscn` | NPCRegistry, MTF, GSM, P&E, Conversion UI, RFS, GameConfig, SaveLoad |
| 14 | HUD & Progress System | Presentation | Scene `hud_progress.tscn` | GSM, MTF, NPCRegistry, GameConfig, RFS, VMV, SaveLoad |

### 1.2 Directed dependency graph

```
┌────────────────────────────── FOUNDATION ──────────────────────────────┐
│  GameConfig  TraitDatabase  DialogueDatabase  MobileTouchFramework     │
└───────┬──────────────┬───────────────┬──────────────┬──────────────────┘
        │              │               │              │
        │        ┌─────┴──────┐   ┌────┴─────┐        │
        ▼        ▼            ▼   ▼          ▼        │
┌──────────────────────────────────────────────────────────────┐
│  NPCRegistry (5)     ConversionLogicEngine (6)   GameStateManager (7) │
│    NPC truth +         pure math, resolve()      turn authority;      │
│    controlled mutation   (deps: 1,2,5)           exclusive NPC-lifecycle│
└──────┬──────────────┬───────────────┬────────────────────────────────┘
       │              │               │ subscribes DCS signals
       │              ▼               ▼
       │     ┌──────────────────────────────────────┐
       │     │  DCS (8) — session orchestrator       │
       │     │  resolve→apply finally guarantee      │
       │     └───────┬──────────────┬────────────────┘
       │             │              │
       ▼             ▼              ▼
┌──────────────────────────────────────────────────────────────┐
│  RivalFaithSystem (9)   SaveLoadSystem (10)                   │
│  turn Step 5 responder;  JSON v1; calls GSM + NPCRegistry      │
│  same CLE, RIVAL caller                                       │
└──────┬──────────────┬───────────────┬─────────────────────────┘
       │              │               │
       ▼              ▼               ▼
┌──────────────────────────── PRESENTATION ─────────────────────────────┐
│  PortraitController (11)  ← owned by  ConversationScreen (12)          │
│  VillageMap (13)  ← instantiates ConversationScreen;  HUD (14) ← top   │
│        strip contract + resolution presentation                        │
└───────────────────────────────────────────────────────────────────────┘
```

### 1.3 Edge contracts carried by each edge

| Edge | Contract (signals / calls / config / scene ownership) |
|------|-------------------------------------------------------|
| GSM → NPCRegistry | Exclusive lifecycle: `advance_turn()`, `initialize_village()`, `clear_village()`; reads `get_npcs_by_belief(CONVERTED)`, `get_approachable_npcs()`; subscribes `village_initialized`, `npc_state_changed` |
| GSM → DCS | **Signal-only** — subscribes `session_begun`, `session_complete`; never calls DCS methods (GSM Rule 9) |
| DCS → CLE | `resolve(approach, npc_id) → ConversionOutcome`; **must** be followed by `apply_conversion_outcome()` (finally-block, DCS EC-8) |
| DCS → NPCRegistry | `get_approachable_npcs()`, `get_npc()`, `apply_conversion_outcome(npc_id, outcome, approach)`, `reveal_trait(npc_id, approach)` (updated signature), `trigger_inspect_reveal()` |
| DCS → DialogueDatabase | `get_approach_lines()`, `get_outcome_summary()`, `is_loaded()` — recency selection is DCS-owned (W=2, L=3) |
| DCS → TraitDatabase | `get_affinity()` over `revealed_traits` **only** (alignment signal — never hidden traits) |
| RFS → GSM | Subscribes `turn_advancing`; queries `get_turn_number()`; GSM calls `RivalFaithSystem.process_turn()` at Step 5 |
| RFS → CLE/NPCRegistry | Same `resolve()`; `apply_conversion_outcome(..., OutcomeCaller.RIVAL)` — grace-window regression only for RIVAL caller |
| RFS → HUD/VMV | `rival_acted(target_npc_id, approach, outcome)` — VMV marker + HUD stamp/QUIET-ACTIVE gauge |
| GSM → HUD | `faith_power_changed`, `turn_advancing/advanced`, `village_won/lost/cleared`, `village_ready`; queries `get_faith_power()`, `get_turn_number()`, `get_gsm_state()` |
| GSM → VMV | `village_ready`, `turn_*`, `village_*`; VMV calls **exactly one command** in the architecture: `request_end_turn()` |
| VMV ↔ Conversion UI | Scene handoff: VMV instantiates `conversation_screen.tscn`, calls `begin_conversation(npc_id)`; resumes on `conversation_closed` (emitted on **every** teardown path) |
| VMV → HUD | `HUD.get_top_strip_height_dp()` as the map-rect top inset (dynamic, font-scale safe) |
| HUD → NPCRegistry | Snapshot reads **only** inside `village_won`/`village_lost` handlers (`get_npcs_by_belief(CONVERTED)`, `get_all_npcs()`); never subscribes `npc_state_changed` |
| SaveLoad → GSM/NPCRegistry | `get_save_data()`/`restore_from_save()`; `serialize()`/`deserialize()`; subscribes `session_complete`, `village_won`, `village_lost` |
| MTF → all UI | `register()/unregister()/push_blocking_layer()/pop_blocking_layer()/pixels_per_dp`; signals `tapped/long_press_*/swiped/touch_cancelled`. Conversion UI is the **only** blocking-layer owner |
| Conversion UI → P&E | `set_expression(key)` — sole driver; subscribes `dissolve_started/dissolve_completed` (optional); owns P&E scene lifecycle |
| GameConfig → all | Pull pattern: `GameConfig.[domain].[field]` at call time, never cached; no signals except editor-only `config_reloaded` |

**DAG check:** Strict acyclic graph (systems-index: "None found"). The one near-cycle (GSM → RFS via `process_turn()` call, RFS → GSM via `turn_advancing` subscription) is **not** a dependency cycle — RFS subscribes to GSM's signal, GSM calls RFS's method at a defined step; both are one-directional at runtime and ordering is enforced by the Autoload list + turn-sequence steps.

---

## 2. Scene / Node Tree Architecture

### 2.1 Ownership model (scenes vs Autoloads vs plain classes)

| System | Form | Justification (GDD citation) |
|--------|------|------------------------------|
| GameConfig, TraitDatabase, DialogueDatabase, MTF, NPCRegistry, CLE, DCS, GSM, RFS, SaveLoad | **Autoload** | Explicit GDD mandates ("Autoload singleton" in each API block; entities.yaml registers GameConfig/DialogueDatabase/GSM as Autoloads). Global access without injected references; GSM/NPCRegistry "global to the village scene" (NPC CS architectural notes). |
| PortraitController | **Scene node** | P&E Rule 10: "PortraitController is a scene-level node instantiated by the Conversion UI scene — **not an Autoload**. One instance per conversation." |
| ConversationScreen | **Scene** | Conversion UI Rule 1: "a scene, not an Autoload: one instance per conversation" |
| VillageMap | **Scene** | VMV Rule 1: "a scene, not an Autoload — one instance per village" |
| HudProgress | **Scene** | HUD Rule 2: "a scene, not an Autoload — one instance per playthrough, kept alive across village transitions" |
| Resource classes (NpcRecord, configs, archetypes, VillageDefinition) | **Plain classes** | Data carriers; no lifecycle. Constructed by owners; serialized by SaveLoad/NPCRegistry. |
| `GameEnums` (shared enums) | **Plain class** (`class_name GameEnums`) | Cross-system enum coupling (DCD owns ConversionOutcome/DialogueApproach; NPC CS owns BeliefState) needs one resolvable home for `.tres` authoring and signal typing. |
| `RecencyTracker` (DCS helper) | **Plain class** | DCS-owned line-selection state; testable in isolation without the DCS Autoload. |

**Design tension resolved:** `src/CLAUDE.md` + coding standards say "prefer dependency injection over singletons for testability." The GDDs *mandate* Autoloads. Resolution: Autoloads are the **runtime access pattern** (registered in `project.godot`); each Autoload script is written so its logic lives in **instance-testable methods** (GUT can instantiate the script directly and drive it with synthetic inputs — CLE's pure `resolve()` is the exemplar). This satisfies both.

### 2.2 Node tree (text diagram)

```
res://src/scenes/main.tscn  (Main — boot/router; created first by project.godot main_scene)
│
├─ [CanvasLayer 0]  VillageMap            (res://src/scenes/map/village_map.tscn — per village)
│   ├─ MapBackground      (TextureRect — res://assets/maps/{village_id}/, static parchment)
│   ├─ MarkerContainer    (Control)
│   │   └─ NpcMarker      (Control, 80×80dp, one per NPC ×8–12)
│   │       ├─ ConvertedHalo   (ColorRect/TextureRect — iff CONVERTED)
│   │       ├─ Thumbnail       (TextureRect — P&E belief-key texture; single-frame swaps only)
│   │       ├─ CooldownOverlay (dim ColorRect + sandglass glyph)
│   │       ├─ LockedOverlay   (desaturation + lock glyph)
│   │       ├─ GateCaption     (Label — "Locked: convert the Elder first")
│   │       ├─ RivalMarker     (ash-grey crescent 16×16dp — dwell window)
│   │       └─ SelectionRing   (shown on tapped, cleared on touch_cancelled)
│   ├─ InkBleedLayer      (ColorRect + ShaderMaterial — shader-driven radial expansion + noise mask)
│   └─ EndTurnButton      (Button ≥44×44dp — bottom-center strip; GSM IDLE-gated)
│
├─ [CanvasLayer 1]  HudProgress          (res://src/scenes/hud/hud_progress.tscn — per playthrough)
│   ├─ TopStrip          (Control at get_top_strip_height_dp())
│   │   ├─ FaithMeter    (lit-flame icon + numeral + micro progress line — tap target)
│   │   ├─ TurnCounter   (Label "Turn N")
│   │   └─ RivalIndicator (ash-grey crescent + QUIET/ACTIVE ink strength)
│   ├─ DetailPanel       (parchment card — non-blocking, closes per Rule 8)
│   └─ ChronicleCard     (snapshot-driven WON/LOST card — ScrollContainer for convert list)
│
└─ [CanvasLayer 2, transient]  ConversationScreen   (res://src/scenes/conversation/conversation_screen.tscn — per session)
    ├─ MoodLayer           (ColorRect — background value/temperature; the −150K cue / outcome offsets)
    ├─ PortraitContainer   (Control — portrait zone 60–65% of safe height)
    │   └─ PortraitController  (res://src/scenes/conversation/portrait_controller.tscn — P&E rig)
    │       ├─ _front_rect (TextureRect)
    │       ├─ _back_rect  (TextureRect)
    │       └─ Overlay     (ColorRect — conversion warm-colour overlay)
    └─ ChoiceZone          (Control — safe-area remainder)
        ├─ DialogueZone    (Region A — label/line area, one content piece at a time)
        ├─ TraitPanel      (Region B — header + scroll card row + Inspect)
        └─ ActionArea      (Region C — BackButton + ApproachGrid 2×2)
```

**CanvasLayer stack (rendering only — MTF explicitly ignores layer values for input priority):**
0 = VillageMap · 1 = HUD · 2 = ConversationScreen (covers HUD during sessions; VMV AC-05/Conversion UI Rule 17).

**Lifecycle:** `Main` (boot) calls `SaveLoadSystem.load_game()` once; on `load_completed`/`village_ready` it instantiates VMV (per village) + HUD (once). VMV instantiates ConversationScreen per tap. On `village_cleared`, VMV frees; HUD stays. On `resolution_complete`, router returns to title (MVP).

---

## 3. Autoload Design

### 3.1 Autoload registration order (project.godot)

| Order | Name | Script | Why here |
|-------|------|--------|----------|
| 1 | `GameConfig` | `res://src/autoload/game_config.gd` | Hard GDD requirement — "Autoload order must list GameConfig first" (GameConfig Rule 2, EC-5); every other system reads it in `_ready()` |
| 2 | `TraitDatabase` | `res://src/autoload/trait_database.gd` | Foundation registry; NPCRegistry/CLE need it at init |
| 3 | `DialogueDatabase` | `res://src/autoload/dialogue_database.gd` | Foundation content registry; DCS/P&E/RFS need it |
| 4 | `MobileTouchFramework` | `res://src/autoload/mobile_touch_framework.gd` | Input boundary; must exist before any UI registers. **Verify** the GDD's "listed first" input-priority claim (see Risk R3) |
| 5 | `NPCRegistry` | `res://src/autoload/npc_registry.gd` | Core data store; GSM/DCS/RFS/SaveLoad depend on it |
| 6 | `ConversionLogicEngine` | `res://src/autoload/conversion_logic_engine.gd` | Stateless; both DCS and RFS call `resolve()` |
| 7 | `DialogueConversionSystem` | `res://src/autoload/dialogue_conversion_system.gd` | **Before GSM** (GSM Rule 10) so GSM's deferred signal connect never misses `session_begun` |
| 8 | `GameStateManager` | `res://src/autoload/game_state_manager.gd` | After NPCRegistry + DCS (GSM Rule 10); connects via `call_deferred("_connect_signals")` |
| 9 | `RivalFaithSystem` | `res://src/autoload/rival_faith_system.gd` | After GSM (subscribes `turn_advancing`) |
| 10 | `SaveLoadSystem` | `res://src/autoload/save_load_system.gd` | After NPCRegistry + GSM (load_game calls both); boot calls `load_game()` |

> ⚠️ **Known conflict:** Save&Load GDD's note lists `NPCRegistry → GSM → DCS → SaveLoad`. This contradicts GSM Rule 10 (DCS before GSM). **Plan decision: DCS before GSM** (per GSM's explicit rule; safer signal subscription). Propose a one-line GDD correction (see Appendix §A).

### 3.2 Public interfaces per Autoload (from GDD contracts)

**GameConfig** — signals: `config_reloaded(domain_name: String)` (editor only). API: nine typed domain accessors `conversion`, `traits`, `faith_spread`, `rival_faith`, `progression`, `ui_timing`, `portraits`, `map`, `hud` (each a Resource); validation/clamp on load; hard-halt on missing file/required field. **Never** read `.tres` directly outside this class (entities.yaml rule).

**TraitDatabase** — `get_trait(id) -> TraitData` · `get_affinity(trait_id, approach) -> float` (0.0 for unknown) · `get_all_traits() -> Array[TraitData]` · `get_traits_by_rarity(rarity)` · `get_traits_for_archetype(archetype_id)` · `is_loaded() -> bool`. Stateless, read-only, loaded from `res://assets/data/traits/trait_database.tres`.

**DialogueDatabase** — `get_approach_lines(approach) -> Array[String]` · `get_outcome_summary(approach, outcome) -> Array[String]` · `get_npc_flavour(archetype) -> NPCFlavourData` (**must return a copy** — DCD EC-6) · `get_rival_lines(approach)` · `is_loaded() -> bool`. Loaded from `res://assets/data/dialogue/dialogue_database.tres`; 100 strings at MVP.

**MobileTouchFramework** — `register(control, priority)` · `unregister(control)` · `push_blocking_layer(id)` / `pop_blocking_layer(id)` / `clear_blocking_layers()` · `pixels_per_dp: float`. Signals: `tapped(target, position)`, `long_press_started(target, position)`, `long_press_released(target, position)`, `swiped(direction, delta, velocity)`, `touch_cancelled()`. Constants per GDD Rule 15. Consumes `_input()` (not `_unhandled_input`), never renders UI in production, haptic on tap only.

**NPCRegistry** — Query: `get_npc`, `get_all_npcs`, `get_npcs_by_belief`, `get_approachable_npcs` (3-gate), `get_connections`, `get_archetype_definition`, `get_hidden_trait_count`. Enum: `OutcomeCaller { PLAYER, RIVAL, FAITH_SPREAD }`. Mutation (DCS/RFS/FaithSpread only): `apply_conversion_outcome(npc_id, outcome, approach, caller = PLAYER)`. Reveal (DCS only): `reveal_trait(npc_id, approach)` — **updated signature** (approach, not trait_id) · `trigger_inspect_reveal(npc_id)`. Turn (GSM only): `advance_turn()`. Init (GSM only): `initialize_village(npc_definitions)`, `clear_village()`. Persistence (SaveLoad only): `serialize() -> Dictionary`, `deserialize(data)`. Signals: `npc_state_changed(npc_id, old_state, new_state)`, `npc_cooldown_expired(npc_id)`, `trait_revealed(npc_id, trait_id)`, `village_initialized()`.

**ConversionLogicEngine** — single method: `resolve(approach: DialogueApproach, npc_id: String) -> ConversionOutcome`. Stateless; reads `GameConfig.conversion.*` at call time; never caches; `RESISTED` as safe sentinel on invalid input.

**DialogueConversionSystem** — Commands (Conversion UI only): `begin_session(npc_id)`, `select_approach(approach)`, `trigger_inspect()`, `cancel_session()`. Query: `get_approach_alignment(npc_id, approach) -> AlignmentSignal`. Signals: `session_begun(npc_id)`, `approach_line_ready(line)`, `outcome_resolved(outcome, summary_line, revealed_trait_id)`, `session_complete()`, `trait_inspected(trait_id)`. Owns the session state machine (IDLE → APPROACH_SELECTION → APPROACH_CONFIRMED → LINE_DISPLAYING → RESOLVING → OUTCOME_DISPLAY → SESSION_COMPLETE → IDLE) and the three recency pools (W=2).

**GameStateManager** — Commands: `request_end_turn()` (no-op unless IDLE). Queries: `get_turn_number()`, `get_faith_power()`, `get_gsm_state()`. Persistence: `get_save_data() -> Dictionary`, `restore_from_save(data)`. Signals: `village_ready(village_id)`, `turn_advancing(turn_number)`, `turn_advanced(turn_number)`, `village_won(turn_number)`, `village_lost(turn_number)`, `faith_power_changed(new_total)`, `village_clearing()`, `village_cleared()`. State machine: UNINITIALIZED → IDLE → IN_SESSION → TURN_ADVANCING → VILLAGE_WON/LOST. Exclusive NPC-lifecycle caller. Faith-power dedup via `converted_ids`; rival-regression re-arm.

**RivalFaithSystem** — Signal: `rival_acted(target_npc_id, approach, outcome)`. Method (GSM Step 5): `process_turn()`. Stateless between turns; interval check `turn % aggression_interval_turns == 0`; priority tiers CONVERTED(grace) → WAVERING → OPEN; omniscient approach scoring over `assigned_traits`; reharden bias (default 1.0 = no bias); `OutcomeCaller.RIVAL` mutation.

**SaveLoadSystem** — `load_game()` (boot, once). Signals: `load_completed(village_id)`, `load_not_found()`, `load_failed()`, `save_completed()`, `save_failed()`. Constants: `SAVE_VERSION_CURRENT = 1`, `SAVE_FILE_PATH = "user://faithful_save.json"`. Atomic write (temp + rename); triggers: `session_complete` (deferred), OS background (sync), `village_won/lost` (sync, priority).

---

## 4. Data Structures

### 4.1 Core types → GDScript mapping

| GDD Type | GDScript Form | Key fields | Notes |
|----------|---------------|-----------|-------|
| `NpcRecord` | `Resource` (`class_name NpcRecord`) | `npc_id`, `archetype`, `display_name`, `assigned_traits: Array[String]`, `revealed_traits`, `belief_state`, `cooldown_turns_remaining`, `recently_converted_turns_remaining`, `approach_count`, `approach_history: Dictionary`, `social_connections: Array[NPCConnection]`, `map_position: Vector2i`, `access_gate: NPCAccessGate` | `social_influence_weight` **not** on the record — read via `get_archetype_definition()` (NPC CS Rule 1) |
| `NPCConnection` | `Resource` | `target_npc_id`, `relationship_type`, `influence_weight` | 7 MVP relationship types |
| `NPCAccessGate` | `Resource` | `required_belief_state`, `required_npc_ids: Array[String]` | Nullable on record |
| `NPCArchetypeDefinition` | `Resource` | `archetype_id`, `display_name`, `role_description`, `social_influence_weight` (0.1–5.0), `trait_weight_bonuses: Array[NPCArchetypeTraitBonus]`, `portrait_asset_path` (dir contract: `res://assets/portraits/{archetype_id}/`, 6 files) | Authored as `res://assets/data/npcs/archetypes.tres` (Array of 7) |
| `NPCArchetypeTraitBonus` | `Resource` | `trait_id`, `bonus_pct` (0.0–1.0) | |
| `TraitData` | `Resource` | `id`, `display_name`, `description`, `rarity`, `approach_affinity: Dictionary` (keyed by `GameEnums.DialogueApproach`, 5-band values), `archetype_tags: Array[String]` | 16 traits in `trait_database.tres` |
| `NPCFlavourData` | `Resource` | `short_descriptor`, `inspect_lines: Array[String]` (3) | Must be returned as `.duplicate()` (DCD EC-6) |
| `VillageDefinition` (**proposed, new**) | `Resource` | `village_id`, `npc_definitions: Array[Dictionary]`, `map_art_path`, `rng_seed: int` | Hand-authored per village; feeds `initialize_village()`; file `res://assets/data/villages/village_01.tres` |
| `GameEnums` (**proposed, new**) | `class_name GameEnums` script | `BeliefState`, `DialogueApproach`, `ConversionOutcome` (**PERSUADED** — renamed), `TraitRarity`, `RelationshipType`, `NPCArchetype`, `OutcomeCaller`, `AlignmentSignal`, `GSMState`, `SwipeDirection` | Single resolvable home for `.tres` authoring + typed signals |

### 4.2 Enums (canonical values)

```
BeliefState      { STEADFAST, OPEN, WAVERING, CONVERTED }
DialogueApproach { GRIEF, AMBITION, DOUBT, FEAR }
ConversionOutcome{ PERSUADED, SOFTENED, RESISTED, HARDENED }   ← CONVERTED renamed (NPC CS Rule 9)
TraitRarity      { COMMON, UNCOMMON, RARE }
RelationshipType { SPOUSE, MENTOR, CLOSE_FRIEND, NEIGHBOR, KIN, RIVAL, EMPLOYER }  (+5 post-MVP)
NPCArchetype     { LABORER, ELDER, MERCHANT, SOLDIER, SCHOLAR, WIDOW, NOBLE }
OutcomeCaller    { PLAYER, RIVAL, FAITH_SPREAD }
AlignmentSignal  { POSITIVE, NEUTRAL, NEGATIVE }
GSMState         { UNINITIALIZED, IDLE, IN_SESSION, TURN_ADVANCING, VILLAGE_WON, VILLAGE_LOST }
SwipeDirection   { RIGHT, UP, LEFT, DOWN }
```

### 4.3 Config domains (.tres file structure)

Nine Resource subclasses in `src/resources/config/`, nine `.tres` files under `res://assets/data/config/` (paths pinned by entities.yaml):

| Domain class | .tres path | Representative fields (defaults) |
|--------------|-----------|----------------------------------|
| `ConversionConfig` | `conversion_config.tres` | `base_success_chance` 0.35, `trait_modifier_weight` 0.25, `trait_modifier_cap` 0.50, `min_success_chance` 0.05, `max_success_chance` 0.80, `belief_modifier_open` 0.10, `belief_modifier_wavering` 0.20, `softened_band_fraction` 0.545, `resisted_band_fraction` 0.455, `repeat_penalty_per_use` 0.05, `max_repeat_penalty` 0.15, `approach_cooldown_turns` 3, `max_approaches_per_npc` 5, `hard_mode_base_modifier` 0.8 |
| `TraitConfig` | `trait_config.tres` | `common_trait_weight` 60, `uncommon_trait_weight` 30, `rare_trait_weight` 10, `traits_per_npc_min` 2, `traits_per_npc_max` 4 |
| `FaithSpreadConfig` | `faith_spread_config.tres` | `passive_spread_radius` 2, `spread_rate_per_tick` 0.05, `attrition_rate_per_tick` 0.02, `spread_tick_interval_sec` 30.0 — **no MVP consumer; shipped to satisfy GameConfig AC-1** |
| `RivalFaithConfig` | `rival_faith_config.tres` | `aggression_interval_turns` **6** ⚠ (vs 3 in RFS GDD), `reharden_strength` 1.0, `counter_approach_random_weight` 0.0, `grace_window_turns` 2 |
| `ProgressionConfig` | `progression_config.tres` | `faith_power_per_conversion` 10, `missionary_unlock_threshold` 100, `court_unlock_threshold` 250, `crusade_unlock_threshold` 500, `village_win_conversion_pct` 0.75 |
| `UITimingConfig` | `ui_timing_config.tres` | `approach_confirm_hold_sec` 0.6, `hardened_reveal_hold_sec` 1.0, `dialogue_line_hold_sec` 2.0, `outcome_display_hold_sec` 2.5, `scene_transition_duration_sec` 0.5, `portrait_expression_hold_frames` 30, `trait_card_reveal_ms` 350 |
| `PortraitConfig` | `portrait_config.tres` | `dissolve_duration_ms` 350, `conversion_dissolve_duration_ms` 400, `conversion_overlay_color` #F2A33C, `conversion_overlay_surge_alpha` 0.55, surge/hold/fade 150/50/500ms, `reduced_motion_dissolve_ms` 0, `reduced_motion_overlay_fade_ms` 100 |
| `VillageMapConfig` | `village_map_config.tres` | `map_grid_columns` 4, `map_grid_rows` 6, `ink_bleed_duration_ms` 1750, `ink_bleed_opacity` 0.35, `ink_bleed_color` #E6BE64, `ink_bleed_max_radius_dp` 260, `rival_marker_dwell_sec` 4.0, `rival_marker_fade_ms` 300, `return_halo_*`, `reduced_motion_ink_fade_ms` 100 |
| `HUDConfig` | `hud_config.tres` | `top_strip_height_dp` 56, `chronicle_card_hold_sec` 4.0, `chronicle_card_fade_ms` 400, `chronicle_card_fade_in_ms` 250, `reduced_motion_card_fade_ms` 100 |

Example `.tres` (Godot 4.6, format 3):

```text
[gd_resource type="Resource" script_class="ConversionConfig" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/resources/config/conversion_config.gd" id="1"]

[resource]
script = ExtResource("1")
base_success_chance = 0.35
trait_modifier_weight = 0.25
trait_modifier_cap = 0.5
min_success_chance = 0.05
max_success_chance = 0.8
belief_modifier_open = 0.1
belief_modifier_wavering = 0.2
softened_band_fraction = 0.545
resisted_band_fraction = 0.455
repeat_penalty_per_use = 0.05
max_repeat_penalty = 0.15
approach_cooldown_turns = 3
max_approaches_per_npc = 5
hard_mode_base_modifier = 0.8
```

### 4.4 Save payload schema (v1)

```json
{
  "save_version": 1,
  "saved_at": "2026-08-09T00:00:00Z",
  "gsm": { "turn_number": 4, "faith_power": 30, "gsm_state": "IDLE",
           "converted_ids": ["village_01_elder_0", "village_01_merchant_1"], "village_id": "village_01" },
  "npc_registry": { "...": "opaque blob from NPCRegistry.serialize() — schema owned by NPC CS" }
}
```
(Includes `village_id` per Save&Load OQ-01 option (a) — resolves the `load_completed(village_id)` source question.)

---

## 5. Signal Inventory

| Signal | Emitter | Payload | Subscribers | Purpose |
|--------|---------|---------|-------------|---------|
| `npc_state_changed` | NPCRegistry | `(npc_id, old_state, new_state)` | GSM (faith power award + dedup), VMV (thumbnail swap), HUD (**no** — snapshot only) | Belief-state transition broadcast |
| `npc_cooldown_expired` | NPCRegistry | `(npc_id)` | VMV (overlay off, re-register) | Cooldown cycle end |
| `trait_revealed` | NPCRegistry | `(npc_id, trait_id)` | None at MVP (debug/audio prospective) | Trait reveal broadcast |
| `village_initialized` | NPCRegistry | — | GSM (→ IDLE), VMV | Village data ready |
| `config_reloaded` | GameConfig | `(domain_name)` | Any (discouraged — pull pattern) | Editor-only hot-reload |
| `tapped` / `long_press_started` / `long_press_released` / `swiped` / `touch_cancelled` | MTF | `(target, position)` / `(direction, delta, velocity)` | Conversion UI, VMV, HUD (meter), Accessibility (observer) | All touch input |
| `session_begun` | DCS | `(npc_id)` | GSM (→ IN_SESSION), Conversion UI (open scene), VMV (End Turn visual), HUD (→ SESSION_ACTIVE) | Session open |
| `approach_line_ready` | DCS | `(line)` | Conversion UI (place line) | Approach line delivered |
| `outcome_resolved` | DCS | `(outcome, summary_line, revealed_trait_id)` | Conversion UI (E3 expression, trait-card sequencing, conversion-moment entry); Audio (prospective) | Outcome committed |
| `session_complete` | DCS | — | GSM (→ IDLE + exhaustion check), Conversion UI (teardown), SaveLoad (deferred save), VMV (observer), HUD (observer) | Session end |
| `trait_inspected` | DCS | `(trait_id)` | Conversion UI (card reveal + alignment recompute) | Inspect reveal |
| `village_ready` | GSM | `(village_id)` | VMV (build), HUD (render), Tutorial (prospective) | Village loaded |
| `turn_advancing` | GSM | `(turn_number)` | VMV (TURN_PROCESSING), HUD (static counter), RFS (act at Step 5), Audio (prospective) | Turn sequence begins |
| `turn_advanced` | GSM | `(turn_number)` | VMV (refresh), HUD (counter swap + rival prune), Audio (prospective) | Turn sequence done |
| `village_won` / `village_lost` | GSM | `(turn_number)` | VMV (RESOLVED lock), HUD (snapshot + card), SaveLoad (terminal save), Audio (prospective) | Village resolved |
| `faith_power_changed` | GSM | `(new_total)` | HUD (meter + cue), Multi-path (prospective) | Faith power awarded |
| `village_clearing` | GSM | — | None explicit at MVP (ordering signal; reserved) | Clear sequence begins |
| `village_cleared` | GSM | — | VMV (→ HIDDEN), HUD (clear transient), DCS (**recency reset — pending GDD fix**), Conversion UI (defensive teardown) | Village torn down |
| `rival_acted` | RFS | `(target_npc_id, approach, outcome)` | VMV (marker), HUD (stamp + gauge) | Rival pressure visibility |
| `load_completed` / `load_not_found` / `load_failed` / `save_completed` / `save_failed` | SaveLoad | `(village_id)` / — | VMV (rebuild), HUD (re-render), Tutorial (prospective) | Persistence lifecycle |
| `dissolve_started` / `dissolve_completed` | P&E (PortraitController) | `(expression_key)` | Conversion UI (optional sync), Audio (chime on `moved_convinced`) | Portrait transitions |
| `conversation_closed` | Conversion UI | — | VMV (single resume signal — every teardown path) | Session scene torn down |
| `resolution_complete` | HUD | `(outcome, snapshot)` | Router (→ title at MVP; macro-layer seam post-MVP) | Village resolution finished |

**Discipline:** GSM→DCS and VMV→DCS/HUD→gameplay are **signal-only** (no method calls across the orchestration boundary, except the enumerated command edges: VMV→`request_end_turn()`, VMV→`begin_conversation()`, UI→DCS commands, GSM→`process_turn()` stubs).

---

## 6. Implementation Order / Milestones

Each milestone is independently testable (GUT unit tests per coding standards; screenshots for UI). ADRs are written *before* the milestone they gate.

| Milestone | Scope | Builds | Testable outcome (ACs) | ADRs |
|-----------|-------|--------|------------------------|------|
| **M0 — ADR + scaffold** | All foundational ADRs accepted; project skeleton (project.godot, autoload list, dirs, GUT setup, `GameEnums`) | — | Empty-project boots headless; enums compile; autoload order loads without null-refs | ADR-0001…0004 |
| **M1 — Foundation** | GameConfig + 9 `.tres`; TraitDatabase + 16 traits; DialogueDatabase + 100 strings (scaffold content); MTF gesture engine | Full foundation | GameConfig AC-1…10; TraitDB AC-1…11; DCD AC-1…13; MTF AC-1…14 (synthetic InputEvents) | ADR-0005, 0006 |
| **M2 — Core data & math** | Resource classes (NpcRecord, connections, gates, archetypes, VillageDefinition); NPCRegistry (generation, transitions, approachability, reveal); CLE | Core | NPC CS AC-1…21 (seeded determinism); CLE AC-1…8 (pure, seeded) | ADR-0007 |
| **M3 — Turn & session logic** | GSM (state machine, turn sequence with **FaithSpread no-op stub** + RFS stub, faith power, win/loss); DCS (session SM, recency, alignment); RFS (real: interval, targeting, bias, grace window) | Feature logic, no UI | GSM AC-1…9; DCS AC-1…13; RFS AC-01…17; integration: turn sequence ordering | ADR-0008 |
| **M4 — Persistence** | SaveLoad (JSON v1, atomic write, restore rules); GSM `get_save_data`/`restore_from_save`; NPC serialize/deserialize round-trip; pending-session sentinel | Persistence | Save&Load AC-01…13; GSM EC-9/10 restore paths; TURN_ADVANCING/WIN-LOST recovery | ADR-0009 |
| **M5 — Conversation presentation** | P&E PortraitController rig (dissolve, overlay, hold, fallbacks); Conversion UI scene (layout, timers, MTF registration, mood layer) | First playable conversation | P&E AC-01…17; Conversion UI AC-01…24 (screenshots) | ADR-0010 |
| **M6 — Map + HUD + router** | VMV scene (markers, ink-bleed shader, rival marker, End Turn); HUD scene (strip, meter, chronicle card); Main boot/title/game-over | Full MVP loop | VMV AC-01…20; HUD AC-01…22; end-to-end playthrough | ADR-0011 |
| **M7 — Integration & device pass** | Safe-area verification (spike), draw-call/memory budget audit, 120Hz hold check, reduced-motion pass, save/load mid-session, GUT full suite | MVP complete | Full-suite green; perf on mid-range target; screenshot evidence | — |

**Rationale:** Foundation-first because every downstream AC depends on config/registries/input existing. Core before feature because GSM/DCS/RFS all read NPCRegistry+CLE. DCS before GSM (D1) so turn lifecycle has a session source. Presentation last because it is the largest but lowest-risk surface, and its ACs (screenshots, timing) need the full logic stack to be meaningful. M4 placed after M3 so round-trip tests cover real turn/session state.

**Stub strategy (flagged):** GSM Step 4 calls `FaithSpreadSystem.process_turn()` — Faith Spread is **not** an MVP system (systems-index #15, Vertical Slice). At MVP this is a **no-op stub Autoload** (or an optional-chained call), preserving the Step 4/5 ordering contract so FaithSpread slots in later without changing the sequence. RFS is real at M3 (it is MVP #9).

---

## 7. File / Module Layout

`src/` is currently empty (CLAUDE.md + .gitkeep). Proposed (code in `src/`, **runtime data at `res://assets/`** — the GDDs pin `res://assets/data/...` paths; `src/data/` would break those contracts):

```
project.godot                     # main_scene = res://src/scenes/main.tscn; 10 autoloads in order
src/
├── autoload/                     # 10 singleton scripts (registered in project.godot)
│   ├── game_config.gd
│   ├── trait_database.gd
│   ├── dialogue_database.gd
│   ├── mobile_touch_framework.gd
│   ├── npc_registry.gd
│   ├── conversion_logic_engine.gd
│   ├── dialogue_conversion_system.gd
│   ├── game_state_manager.gd
│   ├── rival_faith_system.gd
│   └── save_load_system.gd
├── core/
│   └── game_enums.gd             # class_name GameEnums — all shared enums
├── resources/                    # Resource class definitions (script classes)
│   ├── npc_record.gd  npc_connection.gd  npc_access_gate.gd
│   ├── npc_archetype_definition.gd  npc_archetype_trait_bonus.gd
│   ├── trait_data.gd  npc_flavour_data.gd  village_definition.gd
│   └── config/                   # 9 domain Resource classes
│       ├── conversion_config.gd  trait_config.gd  faith_spread_config.gd
│       ├── rival_faith_config.gd progression_config.gd  ui_timing_config.gd
│       ├── portrait_config.gd    village_map_config.gd  hud_config.gd
├── systems/                      # plain, testable logic classes
│   ├── dialogue/recency_tracker.gd      # DCS line-selection state (W=2)
│   ├── npc/rng_helpers.gd               # seeded weighted draw (Trait Assignment)
│   └── ...
└── scenes/
    ├── main.gd / main.tscn              # boot/router (title → load_game → village → game_over)
    ├── map/village_map.gd / village_map.tscn
    ├── map/npc_marker.gd
    ├── conversation/conversation_screen.gd / conversation_screen.tscn
    ├── conversation/portrait_controller.gd / portrait_controller.tscn
    └── hud/hud_progress.gd / hud_progress.tscn

assets/                           # GDD-pinned runtime data (not code)
├── data/
│   ├── config/                   # 9 × .tres (see §4.3)
│   ├── traits/trait_database.tres        # 16 traits
│   ├── dialogue/dialogue_database.tres   # 100 strings
│   ├── npcs/archetypes.tres              # 7 NPCArchetypeDefinition (proposed)
│   └── villages/village_01.tres          # VillageDefinition (proposed)
├── portraits/{archetype_id}/    # 6 expression .png × 7 archetypes = 42 full + 28 thumbnails
└── maps/village_01/              # parchment map art

tests/                            # per src/CLAUDE.md — NOT in src/
├── unit/{game_config, trait_database, dialogue_database, mobile_touch_framework,
│         npc_registry, conversion_logic_engine, game_state_manager,
│         dialogue_conversion_system, rival_faith_system, save_load_system, portrait_expression}/
└── integration/                  # turn-sequence, save/load round-trip, village lifecycle
```

**File-routing note:** per `technical-preferences.md` File Extension Routing — `.gd` → godot-gdscript-specialist; `.tscn`/`.tres` → godot-specialist; shaders → godot-shader-specialist; general architecture → godot-specialist. Scene files keep the GDD-pinned snake_case names (`conversation_screen.tscn`, `village_map.tscn`, `hud_progress.tscn`) even though the naming convention prefers PascalCase scenes — the GDDs cross-reference these exact names (minor convention deviation to flag, not block).

---

## 8. Risk Register

| # | Risk | L | I | Mitigation |
|---|------|---|---|-----------|
| R1 | **Safe-area API unverified** — `DisplayServer.get_display_safe_area()` not documented in pinned 4.6 reference (Conversion UI OQ-3, VMV OQ-1, HUD OQ-7) | MED | HIGH | M0 spike to verify the exact 4.6 call; fallback `Viewport` insets / per-device notch table; decision recorded in ADR-0011; affects all three screen systems |
| R2 | **`RivalFaithConfig.aggression_interval_turns` 6 vs 3** (game-config vs RFS GDD) | HIGH | MED | Run `/consistency-check` before M3; game-config.md is the authoritative config owner; update RFS GDD default; HUD reads the field at call time so no crash either way |
| R3 | **MTF "listed first" input priority claim** — Godot `_input()` propagates in reverse scene order (last autoload first); "first" may be wrong | MED | MED | Verify engine input order at M1; MTF's registry-based hit-testing + not calling `set_input_as_handled()` unless consumed makes it robust; use `process_priority` if needed |
| R4 | **Autoload-order conflict** — GSM Rule 10 (DCS before GSM) vs Save&Load note (GSM before DCS) | HIGH | MED | Plan adopts DCS-before-GSM; one-line Save&Load GDD correction (Appendix §A); integration test Save&Load AC-13 |
| R5 | **Mobile rendering budget** — Compatibility renderer, ≤100 draw calls, 16.6ms; two full-screen TextureRects + overlay in conversation; 8–12 map markers | MED | MED-HIGH | Budget table below; per-archetype texture preload only (P&E Rule 8); single-frame swaps on map; `perf-profile` at M7 on a mid-range device |
| R6 | **Frame-based hold window at 120Hz** — `portrait_expression_hold_frames` 30 → 250ms at 120Hz vs 500ms at 60Hz (P&E EC-12) | HIGH | LOW-MED | Accepted as lower-bound dwell at MVP; promotion path (`portrait_expression_hold_ms` in PortraitConfig) ready if playtest flags flicker; additive config change |
| R7 | **Missing art/content fallbacks** — 42 full portraits + 28 thumbnails + map art + 100 dialogue strings not yet authored | HIGH | MED | GDD fallbacks implemented (P&E EC-6/7, VMV EC-5/6, DCD under-filled-slot rule); debug assertions; asset specs before M5/M6; placeholder generation for early milestones |
| R8 | **Dialogue content volume** — 3-per-slot minimum is a hard invariant (recency needs L>W) | MED-HIGH | MED | Build-time content validation tool (DCD OQ-2); author content before M5; `V_total = 100` audit |
| R9 | **resolve→apply atomicity** — skipped `apply_conversion_outcome()` corrupts approach_history/cooldowns (DCS EC-8) | LOW | HIGH | finally-block discipline; pending-session record; unit tests DCS AC-7.2/7.3, CLE AC-8 |
| R10 | **Save corruption / mid-state restore** — partial writes, TURN_ADVANCING / WIN-LOST saves | MED | MED-HIGH | Atomic write (temp+rename, Save&Load EC-4); restore rules per GSM EC-9/10; tests AC-05/06/09 |
| R11 | **Zero-ADR state** — no ADRs exist; coding standards require an ADR per system; stories referencing `Proposed` ADRs are auto-blocked | HIGH | MED | M0 writes foundational ADRs first (ADR-0001…0004); ADR acceptance is a milestone gate; control manifest follows |
| R12 | **Godot 4.6 not installed in PATH** — cannot run GUT locally | MED | HIGH | Propose engine install or CI runner at M0; headless `godot --headless --script tests/gdunit4_runner.gd` per CI rules |

**Rendering budget (R5) — draft allocation (draw-call estimate, mid-range target):**

| Surface | Estimated draw calls | Notes |
|---------|---------------------|-------|
| Village map (bg + ≤12 markers + overlays) | ~20–30 | Static; single-frame swaps; batch where possible |
| Conversation screen (mood + 2 portraits + overlay + UI) | ~15–25 | Two TextureRects only during dissolve; overlay is 1 |
| HUD strip + card | ~10 | Minimal |
| Total worst case | ≤ 60–75 | Under the 100 draw-call ceiling; verify on device at M7 |

---

## 9. Open Questions (cannot be resolved by this plan alone)

1. **Safe-area API** — does Godot 4.6 expose `DisplayServer.get_display_safe_area()` as documented? (→ M0 spike; fallback decided; affects R1.)
2. **Rival interval default** — which value is canonical: 6 (game-config) or 3 (RFS)? Needs `/consistency-check` + Creative Director decision. (R2.)
3. **FaithSpread stub at MVP** — confirm the no-op stub (or optional call) for GSM Step 4, since Faith Spread is not an MVP system.
4. **VillageDefinition schema** — confirm the proposed Resource shape (`village_id`, `npc_definitions`, `map_art_path`, `rng_seed`) and that village data is hand-authored `.tres` (not a scene). First village content authorship timing?
5. **Dialogue authoring format** — DCD OQ-3: YAML/CSV → `.tres` pipeline decision (becomes an ADR) before any content is written.
6. **Boot sequence / `load_game()` call site** — Save&Load OQ-02: dedicated `main.tscn` boot calls `load_game()` after scene setup (recommended). Confirm the title screen exists at MVP (HUD OQ-4 implies title return).
7. **RNG persistence** — CLE rolls and DCS recency use RNG; MVP does **not** persist RNG state across saves (restored sessions get fresh randomness). Accept, or persist a seed? (Proposed: accept at MVP; noted in ADR-0009.)
8. **`trait_revealed` consumers** — NPCRegistry emits it; nothing subscribes at MVP. Confirm it ships (debug/audio prospective) or is deferred.
9. **Engine installation / CI** — proceed with local Godot 4.6 install, or set up a CI runner first? (R12.)
10. **FaithSpreadConfig at MVP** — ship all 9 `.tres` (incl. faith_spread_config.tres with no consumer) per GameConfig AC-1, or defer that one domain? (Recommended: ship all 9 — the GDD is explicit.)

---

# 3. Cross-System Updates Appendix (what the plan would add/change on approval)

## A. GDD corrections (small, non-design edits)

| Doc | Change | Status |
|-----|--------|--------|
| `design/gdd/save-load-system.md` | §Architectural Note autoload order: correct `NPCRegistry → GameStateManager → DCS → SaveLoad` → `NPCRegistry → DCS → GameStateManager → SaveLoad` (reconcile with GSM Rule 10) | New |
| `design/gdd/dialogue-conversion-system.md` | §Formulas recency state lifetime: "When GSM calls `NPCRegistry.clear_village()`" → "When GSM emits `village_cleared` signal (DCS subscribes)" | Already pending in session state — apply with approval |
| `design/gdd/rival-faith-system.md` | `aggression_interval_turns` default 3 → match game-config (6) after `/consistency-check` | Via /consistency-check |
| `design/gdd/game-config.md` | (no change — authoritative config owner) | — |

## B. New ADRs (proposed set — M0 foundation first)

| ADR | Title | Covers |
|-----|-------|--------|
| ADR-0001 | Autoload architecture & initialization order | D1, §3.1; resolves R4 |
| ADR-0002 | Data resource model (Resource classes, GameEnums, VillageDefinition) | §4 |
| ADR-0003 | Signal architecture & communication discipline (signal-only boundaries, MTF blocking-layer ownership) | §5; D7 |
| ADR-0004 | Scene ownership & CanvasLayer stack (scenes vs Autoloads, lifecycle) | §2 |
| ADR-0005 | Config system (9 domains, pull pattern, validation, hot-reload editor-only) | GameConfig GDD |
| ADR-0006 | Input architecture (MTF sole boundary, dp conversion, 44dp floor) | MTF GDD; R3 |
| ADR-0007 | Determinism & RNG strategy (seeded village gen; CLE rolls; non-persisted runtime RNG) | NPC CS AC-1; CLE AC-1 |
| ADR-0008 | Turn sequence contract (Steps 1–10, FaithSpread stub, win-before-loss) | GSM GDD |
| ADR-0009 | Save format & restoration rules (JSON v1, atomic write, state-restore table) | Save&Load GDD; R10 |
| ADR-0010 | Portrait presentation pipeline (dissolve rig, hold window, fallbacks, reduced-motion) | P&E GDD; R6/R7 |
| ADR-0011 | Safe-area & mobile performance strategy (verify API, budgets, fallbacks) | R1/R5 |

## C. Control manifest

- `docs/architecture/control-manifest.md` — **does not exist**. Create via `/create-control-manifest` after foundational ADRs: date-stamped `Manifest Version:`, Required/Forbidden/Guardrails per layer (e.g. Required: signal-only GSM↔DCS; Forbidden: hardcoded gameplay values, non-MTF input reads, second blocking-layer owner; Guardrails: autoload order, exclusive-caller rules).

## D. entities.yaml updates

| Entry | Action |
|-------|--------|
| `PortraitConfig` | **Add** constant (path `res://assets/data/config/portrait_config.tres`, owner game-config.md, referenced_by P&E) — currently missing |
| `VillageMapConfig` | **Add** constant (path, owner game-config.md, referenced_by VMV + HUD) — currently missing |
| `BeliefState` / `DialogueApproach` / `ConversionOutcome` / `NPCArchetype` | Add enum constants (single source: game_enums.gd; ConversionOutcome already present — update value to `PERSUADED` form) |
| `NpcRecord` / `NPCArchetypeDefinition` / `VillageDefinition` | Add data-structure constants (new; cross-referenced by NPC CS, P&E, VMV, Save&Load) |
| `RivalFaithConfig` | Update note: interval default remains 6 (game-config authoritative); RFS GDD correction pending |
| `conversion_fraction` etc. | Already present (2026-08-09) — no change |

## E. TR registry

- `docs/architecture/tr-registry.yaml` is **empty** (template only). After ADRs are accepted, run `/architecture-review` (Phase 2/8) to extract technical requirements from all 14 GDDs and populate IDs. Proposed prefixes: `TR-GCF-*` (Game Config), `TR-TDB-*`, `TR-DCD-*`, `TR-MOV-*` (Mobile Touch — matches the systems-index's `TR-MOV-001` example), `TR-NPC-*`, `TR-CLE-*`, `TR-GSM-*`, `TR-DCS-*`, `TR-RFS-*`, `TR-SAV-*`, `TR-POR-*`, `TR-CUI-*`, `TR-VMV-*`, `TR-HUD-*`. Append-only; never renumber.

## F. Session state & systems index

- `production/session-state/active.md` — mark Architecture Plan complete (item 5 ✅); next → Sprint plan; record the two plan-decided resolutions (DCS-before-GSM; FaithSpread stub) and the R2/R4 flags.
- `design/gdd/systems-index.md` — no status change (all 14 Designed); optionally note "Architecture plan complete" in Next Steps. `docs/architecture/architecture-review-[date].md` written after the first `/architecture-review` run.

---

# 4. Files That Would Be Written on Approval

| # | File | Content | Gate |
|---|------|---------|------|
| 1 | `docs/architecture/architecture.md` | The master architecture document (this plan, formatted per the create-architecture skill) | After this draft is approved |
| 2 | `docs/architecture/adr-0001.md` … `adr-0011.md` | 11 ADRs per the template (Proposed → Accepted) | M0 |
| 3 | `docs/architecture/control-manifest.md` | Layer rules manifest (via `/create-control-manifest`) | After ADR-0001…0004 |
| 4 | `docs/architecture/tr-registry.yaml` | Populated TR IDs (via `/architecture-review` Phase 8) | After ADRs accepted |
| 5 | `docs/architecture/architecture-review-2026-08-09.md` | Review report + traceability matrix | Same run as (4) |
| 6 | `design/registry/entities.yaml` | Appendix D additions | With approval |
| 7 | GDD corrections (Appendix A: save-load order note; DCS `village_cleared` wording) | One-line edits | With approval |
| 8 | `production/session-state/active.md` | Architecture plan complete; next = sprint plan | With approval |

No `src/` files are written at this stage — code comes from the sprint plan against the accepted ADRs.

---

# 5. Approval Record

Approved by the Creative Director on 2026-08-09. Plan decisions confirmed:

1. **Architecture approach** — 10 Autoloads + 4 scenes + signal-driven orchestration, ownership model per §2.1.
2. **DCS-before-GSM autoload order** — adopted (GSM Rule 10); one-line Save&Load GDD correction applied (Appendix A).
3. **FaithSpread stub at MVP** — GSM Step 4 calls a no-op stub (system #15 out of MVP scope).
4. **ADR set** — ADR-0001…0004 accepted as the M0 foundation; ADR-0005…0011 milestone-gated.
5. **Open questions** — deferred per §9 (safe-area spike at M0, VillageDefinition schema, engine install/CI).

Writes on approval: ADR-0001…0004 (`docs/architecture/adr-0001.md` … `adr-0004.md`), entities.yaml
Appendix D additions, two GDD corrections (Appendix A), session-state update. Control manifest via
`/create-control-manifest`; TR registry via `/architecture-review` Phase 8.
