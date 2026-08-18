# Control Manifest

> **Engine**: Godot 4.6 / GDScript (Compatibility renderer, mobile portrait)
> **Last Updated**: 2026-08-18
> **Manifest Version**: manifest-2026.1 (generated 2026-08-18)
> **ADRs Covered**: ADR-0001 (Autoload order) · ADR-0002 (data resource model) · ADR-0003 (signal architecture) · ADR-0004 (scene ownership) · ADR-0005 (config system) · ADR-0006 (input architecture)
> **Status**: Active — regenerate with `/create-control-manifest update` when ADRs change

Stories embed `manifest-2026.1`; `/story-readiness` compares a story's embedded
version to this field to detect stories written against stale rules.

This manifest is the programmer's quick-reference extracted from all Accepted
ADRs, technical preferences, and the version-pinned engine reference. For the
reasoning behind each rule, see the cited ADR/GDD.

---

## Foundation Layer Rules

*Applies to: boot/init, autoload registration, data registries (config, traits,
dialogue), save/load, and the MTF input boundary — architecture.md §1.1 layer
"Foundation" + ADR-0001/0002/0005/0006 boot-visible systems.*

### Required Patterns
- **Autoload order is authoritative.** Register the ten Autoloads in `project.godot` in exactly ADR-0001 order: GameConfig(1) → TraitDatabase(2) → DialogueDatabase(3) → MobileTouchFramework(4) → NPCRegistry(5) → ConversionLogicEngine(6) → DialogueConversionSystem(7) → GameStateManager(8) → RivalFaithSystem(9) → SaveLoadSystem(10). Never reorder; insert new Autoloads only at positions that preserve the dependency chain. — source: ADR-0001
- **GameConfig first.** `GameConfig` must be slot 1 so every other Autoload's `_ready()` sees LOADED config (GameConfig Rule 2/EC-5). — source: ADR-0001, ADR-0005
- **Deferred signal connects.** GSM connects DCS signal subscriptions via `call_deferred("_connect_signals")` and asserts NPCRegistry + DCS exist before connecting. — source: ADR-0001
- **Ten Autoloads only (MVP).** FaithSpreadSystem is NOT registered at M0 (not MVP); GSM Step 4 calls a no-op stub (ADR-0008 at M3). — source: ADR-0001
- **Instance-testable methods.** Each Autoload script keeps its logic in instance-testable methods so GUT can instantiate the script directly; the Autoload node is the runtime access pattern, not the only test surface. — source: ADR-0001
- **Data lives at `res://assets/data/` as format-3 `.tres`** with `script_class` headers; every Resource has `class_name`; every authored `.tres` is read ONLY through its owning Autoload (GameConfig for config domains; TraitDatabase for traits; DialogueDatabase for dialogue). — source: ADR-0002
- **Flavour data returns copies.** `DialogueDatabase.get_npc_flavour()` and any other getter over mutable Resources MUST return a `duplicate()` copy, never a shared reference (DCD EC-6/AC-13). — source: ADR-0002
- **Pull pattern.** Read `GameConfig.[domain].[field]` at call time; never cache config values locally (GameConfig Rule 3). — source: ADR-0005
- **`pixels_per_dp` computed once** at startup from `DisplayServer.screen_get_dpi()` with the 160-DPI fallback; never re-queried per frame (MTF Rule 10/11, F-1). — source: ADR-0006

### Forbidden Approaches
- **Never hardcode gameplay values in GDScript.** Every balance number, timing constant, probability modifier, and threshold must come from a GameConfig domain. Exceptions: pure math constants (PI, array indices, loop bounds, string keys) and MTF Rule-15 gesture constants (explicitly compile-time framework tuning at MVP, not balance values — ADR-0006 Decision 3; REG-3 static scan enforces). — source: ADR-0005, GameConfig Rule 1/AC-6
- **Never read `.tres` outside the owning Autoload.** No `load("res://assets/data/config/...")` anywhere except `GameConfig`; same for traits/dialogue via their owners (entities.yaml rule). — source: ADR-0002, ADR-0005
- **Never call `set_input_as_handled()` unless a registered target consumed the event.** Only MTF may call it, and only when it produced a gesture to a registered area (R3 mitigation). — source: ADR-0006
- **No UI reads `Input` directly.** No `Input`/`InputEventScreenTouch`/`InputEventScreenDrag` reads and no `set_input_as_handled()` outside MTF `_input()`. — source: ADR-0006 (see also Core for the broadest form)
- **No file watcher in export builds.** Hot-reload polling and the `config_reloaded` handler are editor-only (`Engine.is_editor_hint()` gated) and stripped from exports (GameConfig AC-8). — source: ADR-0005
- **No deprecated godot APIs** flagged in `docs/engine-reference/godot/deprecated-apis.md` (e.g. `TileMap` → `TileMapLayer`, `yield` → `await`, string-based `connect()`, `instance()` → `instantiate()`, `duplicate()` for nested resources → `duplicate_deep()`). — source: engine reference

### Guardrails
- **Boot determinism:** Autoload `_ready()` order is a correctness constraint; headless boot must stay `godot --headless --quit --path .` exit 0, zero errors (M0 test + each milestone). — source: ADR-0001
- **Append-only registries:** TR-registry IDs (`TR-*-NNN`) and entities.yaml constants are PERMANENT — never renumber/delete; only append. — source: docs/CLAUDE.md, registry header
- **Config authority:** field ranges/defaults are owned by `design/gdd/game-config.md`; `architecture.md` §4.3 is representative only. If code needs a field absent from the GDD table, flag to the designer — never invent. — source: ADR-0005
- **Hard-halt semantics:** missing config `.tres` or missing required field = fatal error naming path/field; never boot in an unknown tuning state. — source: ADR-0005

---

## Core Layer Rules

*Applies to: NPCRegistry (5), ConversionLogicEngine (6), GameStateManager (7) — core gameplay loop, turn authority, data mutation.*

### Required Patterns
- **Signal-only orchestration boundaries.** GSM↔DCS: GSM subscribes `session_begun`/`session_complete` and NEVER calls DCS methods (GSM Rule 9). HUD→gameplay: snapshot reads only inside `village_won`/`village_lost` handlers; HUD never subscribes `npc_state_changed` (P&E EC-3 discipline). — source: ADR-0003
- **Enumerated command edges only.** The complete command-edge list: VMV→`request_end_turn()`; VMV→`begin_conversation()`; Conversion UI→DCS commands (`begin_session`, `select_approach`, `trigger_inspect`, `cancel_session`, `get_approach_alignment`); GSM→`RivalFaithSystem.process_turn()` (Step 5); GSM→`FaithSpreadSystem.process_turn()` (Step 4 stub); SaveLoad→GSM/NPCRegistry persistence calls. Any new cross-boundary call must be added to ADR-0003 + architecture.md §5 first. — source: ADR-0003
- **Exclusive callers.** NPC lifecycle mutations are GSM-only (`advance_turn()`, `initialize_village()`, `clear_village()`); mutation `apply_conversion_outcome()` is DCS/RFS/FaithSpread-only; reveal is DCS-only; persistence is SaveLoad-only. — source: ADR-0003, architecture.md §1.3
- **resolve→apply atomicity.** Any call to `ConversionLogicEngine.resolve()` MUST be followed by `apply_conversion_outcome()` (finally-block, DCS EC-8) — never a bare roll. — source: ADR-0003
- **Config reads at call time.** CLE reads `GameConfig.conversion.*` at resolve time — never caches (pull pattern). — source: ADR-0005, architecture.md §1.3

### Forbidden Approaches
- **Never call across the GSM↔DCS boundary by method.** GSM calling DCS methods, or DCS calling GSM methods for control flow, is a review failure. Signals only, plus the enumerated command edges above. — source: ADR-0003
- **Never introduce a second blocking-layer owner.** The Conversion UI is the ONLY caller of `push_blocking_layer()`/`pop_blocking_layer()` while a conversation is open; any second owner is a review failure. — source: ADR-0003/0006 (feature ADR-0006; guardrail enforced at 1-13 MTF-9)
- **No hardcoded tuples of gameplay values** in turn logic, win/loss thresholds, or faith-power math — all from GameConfig domains (ProgressionConfig etc.). — source: ADR-0005
- **Never add a signal ad hoc.** Signals are added to the architecture.md §5 inventory (and entities.yaml) first, never invented on the spot in code. — source: ADR-0003

### Guardrails
- **Exclusive-caller audit** at code review: every single call to NPCRegistry mutation/reveal/turn/persistence APIs is checked against the caller table above. — source: ADR-0003
- **DCS before GSM** is a hard ordering rule; Save&Load note `NPCRegistry → DCS → GSM → SaveLoad` matches ADR-0001. — source: ADR-0001
- **Turn sequencing:** GSM runs Steps 1–10 per ADR-0008 (M3); while M3 is not built, stub calls must preserve Step 4/5 ordering so FaithSpread/RFS slot in without changing the sequence. — source: ADR-0001/architecture.md §6

---

## Feature Layer Rules

*Applies to: DialogueConversionSystem (8 — session orchestrator) and RivalFaithSystem (9).*

### Required Patterns
- **DCS owns the session state machine** (IDLE → APPROACH_SELECTION → APPROACH_CONFIRMED → LINE_DISPLAYING → RESOLVING → OUTCOME_DISPLAY → SESSION_COMPLETE → IDLE); state transitions are the only way sessions advance. — source: ADR-0003, architecture.md §3.2
- **Recency selection is DCS-owned** (W=2, L=3): line selection excludes the last-2-shown lines; read pools from DialogueDatabase, never store line state in the database. — source: ADR-0003, DCD GDD Cross-system constraint
- **DCS emits `session_begun`/`approach_line_ready`/`outcome_resolved`/`session_complete`/`trait_inspected`** with payloads per architecture.md §5 — never changed ad hoc. — source: ADR-0003
- **RFS is a Step-5 responder:** GSM calls `RivalFaithSystem.process_turn()`; RFS subscribes `turn_advancing` and queries `get_turn_number()`; interval check `turn % aggression_interval_turns == 0`. — source: ADR-0003, architecture.md §1.3
- **RFS uses `OutcomeCaller.RIVAL`** on CLE/NPCRegistry mutations; grace-window regression applies only to the RIVAL caller; `rival_acted` feeds VMV marker + HUD stamp/gauge. — source: ADR-0003, architecture.md §1.3

### Forbidden Approaches
- **Never let DCS touch NPC lifecycle turn commands** (GSM-only) — DCS works through CLE + NPCRegistry mutation APIs, never `advance_turn()`/`clear_village()`. — source: ADR-0003
- **No direct DCS ↔ GSM method calls** (see Core Forbidden). — source: ADR-0003
- **No reading `Input` for feature systems** — VMV/HUD gestures all arrive as MTF signals; feature logic never registers on raw input. — source: ADR-0003/0006

### Guardrails
- **Signal payload freeze:** payload signatures in architecture.md §5 are the contract; changing one requires an ADR update, not a code edit. — source: ADR-0003
- **`outcome_resolved` carries (outcome, summary_line, revealed_trait_id)** — the Conversion UI's E3 expression + trait-card sequencing depend on it. — source: ADR-0003

---

## Presentation Layer Rules

*Applies to: PortraitController (11), Conversion UI (12), Village Map View (13), HUD (14) — scenes, CanvasLayer stack, UI.*

### Required Patterns
- **Four scenes, no presentation Autoloads.** `main.tscn` (boot/router) · `village_map.tscn` (per village) · `hud_progress.tscn` (per playthrough, survives clears) · `conversation_screen.tscn` (per session). PortraitController is a scene node inside `conversation_screen.tscn`, NOT an Autoload (P&E Rule 10). — source: ADR-0004
- **CanvasLayer stack (rendering only):** 0 = VillageMap, 1 = HudProgress, 2 = ConversationScreen (transient, covers HUD during sessions). Layer values are NEVER input-priority discriminators — MTF input priority is independent. — source: ADR-0004
- **Scene teardown/resume contract:** ConversationScreen emits `conversation_closed` on EVERY teardown path (session complete, back/cancel, defensive village-clear); VMV resumes on it. — source: ADR-0004
- **Scenes are presentation-only:** they read Autoloads and subscribe to signals; gameplay logic stays in Autoloads/plain classes. — source: ADR-0004
- **UI registers with MTF:** consumers call `register()` in `_ready()`, `unregister()` on `tree_exiting`; only Conversion UI may push/pop blocking layers while a session is open. — source: ADR-0006
- **44dp floor:** all interactive targets ≥44×44dp (hit rects inflate center-anchored; debug warning names the node). — source: ADR-0006
- **Conversion UI is the sole expression driver** for PortraitController (`set_expression`); nobody else drives P&E. — source: ADR-0003
- **HUD is a sibling of VillageMap** under Main (survives `village_cleared`); VillageMap frees on `village_cleared`. — source: ADR-0004

### Forbidden Approaches
- **Never register a presentation scene as an Autoload** (four explicit GDD rules). — source: ADR-0004
- **Never read `Input` in UI code.** All touch arrives via MTF signals (`tapped`, `long_press_*`, `swiped`, `touch_cancelled`); raw input reads in scenes are a Forbidden-rule violation (static scan MTF-15). — source: ADR-0006
- **No framework visual feedback from MTF.** MTF renders nothing in production; all visual response is consumer-owned; haptic is tap-only 80ms. — source: ADR-0006 (MTF Rule 12/14)
- **No reliance on CanvasLayer order for input.** Hit priority comes from MTF's registry (geometry + priority tier); never gate input on layer values. — source: ADR-0004/0006

### Guardrails
- **Safe-area for layout only:** use `DisplayServer.get_display_safe_area()` (verified 4.6: `Rect2i`, no params) to place interactive zones; hit-test rects are the registered Controls' rects — the safe area does not alter hit-test geometry. — source: ADR-0006, task 1-2 probe
- **`HUD.get_top_strip_height_dp()`** is the single source for the VMV map-rect top inset (dynamic, font-scale-safe); no duplicated strip-height constants. — source: ADR-0003, VMV F1
- **GDD-pinned scene names** (`conversation_screen.tscn`, `village_map.tscn`, `hud_progress.tscn`) preserved verbatim (minor PascalCase deviation, flagged not blocked). — source: ADR-0004

---

## Global Rules (All Layers)

### Naming Conventions — source: technical-preferences.md
| Element | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase | `PlayerController`, `NpcCharacter` |
| Variables/Functions | snake_case | `move_speed`, `take_damage()` |
| Signals | snake_case past tense | `health_changed`, `conversion_completed` |
| Files | snake_case matching class | `npc_character.gd` |
| Scenes | PascalCase matching root node | `NpcCharacter.tscn` *(exception: GDD-pinned scene names above)* |
| Constants | UPPER_SNAKE_CASE | `MAX_HEALTH`, `BASE_CONVERSION_CHANCE` |

### Performance Budgets — source: technical-preferences.md
| Target | Value |
|--------|-------|
| Framerate | 60fps |
| Frame budget | 16.6ms |
| Draw calls | ≤100 (mid-range mobile 2D) |
| Memory ceiling | 512MB (mid-range mobile) |

### Approved Libraries / Addons
- **GUT v9.6.1** (bitwes/Gut) — unit test framework. v9.7.1 REJECTED (stub_params.gd regression breaks double()/stub() on 4.6, 2026-08-11 record). — source: tests/README.md, session state task 1-5
- No other third-party addons approved at MVP.

### Forbidden APIs (Godot 4.6) — source: `docs/engine-reference/godot/deprecated-apis.md`
- `TileMap` → `TileMapLayer` (since 4.3)
- `yield()` → `await signal` (since 4.0)
- String-based `connect("signal", obj, "method")` → callable connects
- `instance()` / `PackedScene.instance()` → `instantiate()`
- `OS.get_ticks_msec()` → `Time.get_ticks_msec()`
- `duplicate()` for nested resource trees → `duplicate_deep()` (since 4.5)
- GodotPhysics3D for new 3D physics → Jolt (default 4.6); 2D physics unchanged

### Verified Engine Facts (post-cutoff, 4.6) — source: ADR-0006, session state tasks 1-2/1-13
- `DisplayServer.get_display_safe_area() -> Rect2i` — verified 4.6, **no parameters**; bonus `get_display_cutouts() -> Array[Rect2]` (Android).
- `InputEventScreenTouch`/`InputEventScreenDrag` expose `index`, **NOT** `finger_index` (probe-verified 1-13; training-data assumption is wrong).
- `_input()` propagates in **reverse scene order** (last Autoload first) — slot 4 does NOT guarantee raw input priority; MTF's registry hit-test + consume-only handled-mark is the mitigation (R3).
- Recursive Control disable (Godot 4.5+) verified available on 4.6; used by blocking layers to stop `_gui_input()`.
- Tooling: `rg --type gdscript` is a hard error (GDScript registered as `gap`) — use `--glob "*.gd"`.

### Cross-Cutting Constraints
- **Signal inventory is the contract:** `docs/architecture/architecture.md` §5 — new signals, or payload changes, go through ADR-0003 + §5 first; never ad hoc. — source: ADR-0003
- **TR-stable IDs:** stories reference `TR-[slug]-NNN` from `docs/architecture/tr-registry.yaml` (append-only). — source: docs/CLAUDE.md
- **Collaborative protocol:** no commits without user instruction; ask before writing files; design/architecture changes need Creative Director/Technical Director approval. — source: CLAUDE.md, collaborative-design-principle.md
- **GDDs are the source of truth for ranges/defaults** (game-config.md authoritative for config); ADRs exist to make GDD intent implementable — both must be updated on deviation, never code silently. — source: ADR-0005