# Session State — The Faithful / Divine Dominion

<!-- STATUS -->
Epic: Pre-Production
Feature: Design Documentation
Task: Sprint plan + QA plan accepted (Sprint 1: Scaffold & Foundation, 2026-08-17 → 2026-09-04)
Note: Task 1-1 engine install spike ✅ — Godot 4.6.x installed at ~/.local/bin/godot (local install primary; CI 1-21 as clean-room fallback)
Note: Tasks 1-3..1-6 ✅ — M0 scaffold, GameEnums, GUT (v9.6.1), boot test; 1-7..1-10 ✅ — gate-check PASS, ADR-0005/0006 Accepted, GameConfig + 9 domains; 1-11 draft complete (awaiting commit approval) — see Sprint 1 Execution Records below
<!-- /STATUS -->

## Current Task
Completing full pre-production phase:
1. ✅ Engine configured — Godot 4.6 / GDScript / Mobile / Turn-based
2. ✅ Systems index written — 27 systems total (19 NPC layer + 8 macro layer)
3. ✅ Art Bible — complete (design/art/art-bible.md, all 9 sections)
4. ✅ System GDDs — 14/14 MVP done:
   - ✅ Game Config (design/gdd/game-config.md)
   - ✅ NPC Trait Database (design/gdd/npc-trait-database.md)
   - ✅ Dialogue Content Database (design/gdd/dialogue-content-database.md)
   - ✅ Mobile Touch Framework (design/gdd/mobile-touch-framework.md)
   - ✅ NPC Character System (design/gdd/npc-character-system.md)
   - ✅ Conversion Logic Engine (design/gdd/conversion-logic-engine.md)
   - ✅ Dialogue & Conversion System (design/gdd/dialogue-conversion-system.md)
   - ✅ Game State Manager (design/gdd/game-state-manager.md) — COMPLETE
   - ✅ Rival Faith System (design/gdd/rival-faith-system.md)
   - ✅ Save & Load System (design/gdd/save-load-system.md)
   - ✅ Portrait & Expression System (design/gdd/portrait-expression-system.md)
   - ✅ Conversion UI (design/gdd/conversion-ui.md)
   - ✅ Village Map View (design/gdd/village-map-view.md)
   - ✅ HUD & Progress System (design/gdd/hud-progress-system.md) — FINAL MVP GDD
5. ✅ Architecture plan — accepted (docs/architecture/architecture.md, 2026-08-09)
6. ✅ Sprint plan — accepted (Sprint 1: Scaffold & Foundation, 2026-08-17 → 2026-09-04)

## Key Decisions Made (this session)
- Divine Dominion GDD reviewed — MAJOR REVISION NEEDED verdict
- Divine Dominion integrated as macro-layer on The Faithful (two-scale game)
- Gameplay model: Turn-based (locked)
- Win condition: 50%+ of all world regions simultaneously (locked)
- Lose condition: All regions below 10% conversion (locked)
- Orientation: Portrait primary (confirmed)
- 8 new macro-layer systems added to systems-index.md (systems 20-27)
- Balance flags recorded in systems-index for macro layer economy design
- Village Map View OQs resolved (2026-08-09): OQ-1 safe-area verify-at-implementation w/ Viewport/notch fallback; OQ-2 shader-driven ink-bleed; OQ-3 scroll/zoom deferred; OQ-4 **win/loss presentation owned by HUD & Progress System (#14)** — VMV only locks the map; OQ-5 `#E6BE64` ships as-is; OQ-6 ash-grey crescent rival marker
- `VillageMapConfig` added as 8th config domain (game-config.md)
- HUD & Progress System OQs resolved (2026-08-09): OQ-1 faith-power **numeral shown** (strip = designated numeral zone); OQ-2 rival indicator = ash-grey crescent + QUIET/ACTIVE gauge, **no %**; OQ-3 **`HUDConfig` 9th config domain**; OQ-4 WON ends `GAME_OVER` → title at MVP, `resolution_complete` = macro-layer seam; OQ-5 LOST = sober card → 2.0s final-tally → title; OQ-6 chronicle card **non-interactive** at MVP; OQ-7 safe-area verify-at-implementation (Viewport/notch fallback); OQ-8 village name via `tr("VILLAGE_" + village_id)` content keys
- `HUDConfig` added as 9th config domain (game-config.md)
- **MVP Architecture Plan ACCEPTED** (2026-08-09) — 10 Autoloads + 4 scenes + signal-driven orchestration. Key decisions (D1–D10): 10-Autoload order (GameConfig first, DCS before GSM), 4 scenes (`conversation_screen`, `village_map`, `hud_progress`, `main`), PortraitController as scene node, DCS owns conversation flow, Conversion UI sole expression driver, GSM exclusive NPC-lifecycle caller, MTF sole input boundary + Conversion UI only blocking-layer owner, **FaithSpread no-op stub at GSM Step 4 (MVP)**, GameEnums shared class, VillageDefinition Resource (proposed)
- **Autoload-order conflict resolved: DCS before GSM** (GSM Rule 10 authority; Save&Load GDD architectural note corrected to `NPCRegistry → DCS → GSM → SaveLoad`)
- **ADR-0001…0004 ACCEPTED** (M0 foundation, 2026-08-09): ADR-0001 Autoload architecture & init order; ADR-0002 data resource model (GameEnums, VillageDefinition); ADR-0003 signal architecture & communication discipline; ADR-0004 scene ownership & CanvasLayer stack. ADR-0005…0011 milestone-gated (M1–M6).
- **Sprint plan ACCEPTED** (2026-08-11) — Sprint 1: Scaffold & Foundation (M0+M1), 2026-08-17 → 2026-09-04; `production/sprints/sprint-1.md` + `production/sprint-status.yaml` committed. 9 OQ resolutions (recommended rulings accepted): OQ-1 **7 sprints** (S1 = M0+M1, S2–S6 = M2–M6, S7 = M7); OQ-2 **solo full-time, 3-week sprint = 15 total / 3 buffer / 12 available**; OQ-3 **engine install = Day-1 spike task 1-1** (local 4.6 binary via /mnt/c or Linux headless; CI 1-21 as fallback); OQ-4 **safe-area spike = task 1-2** (0.5d runtime probe); OQ-5 **QA plan [A] — `production/qa/qa-plan-sprint-1.md` created before implementation**; OQ-6 **ADR-0005/0006 at Sprint 1 start (tasks 1-8/1-9)**, Accepted before 1-10/1-13; OQ-7 **`/scope-check` baseline before implementation** + standing guardrail (untraceable stories need Creative Director approval); OQ-8 **control manifest (1-16) + TR registry/architecture review (1-17) + gate-check (1-7) in-sprint**; OQ-9 **keep 3-week cadence** — Sprint 7 may shift to 2027-01-04 (winter-holiday overlap)
- **QA plan ACCEPTED** (2026-08-11) — `production/qa/qa-plan-sprint-1.md` approved before implementation (sprint DoD item 3). 8 OQ resolutions (draft recommendations accepted): OQ-A **no device-emulator layer at MVP** — Godot `Input.parse_input_event` with constructed InputEventScreenTouch/Drag; thin test helper only if suites prove flaky; revisit at M5/M6; OQ-B **local WSL headless = primary evidence** for Sprint 1 (Godot version + WSL env recorded in every evidence path); CI evidence mandatory from Sprint 2; OQ-C **automated assert + ONE manual export spot-check** for MTF AC-14 (no golden-screenshot infra until M5); OQ-D **two test-only dialogue fixtures** — `tests/fixtures/dialogue/underfilled.tres` + `empty_descriptor.tres`, created during story 1-12 (production DB stays pristine); OQ-E **GameConfig AC-6 as static scan** — numeric-literal sweep of src/gameplay/ + src/core/ in 1-14 REG-3 + control-manifest Forbidden rule (1-16); OQ-F **automate V_total == 100 audit** — GUT/script in DCD-2 (doubles as the R8 audit); OQ-G **process stories (1-7/1-8/1-9/1-15/1-16/1-17/1-18/1-19/1-20) classified Config/Data** — manual evidence = produced artifact + checklist sign-off, no unit-test files demanded; OQ-H **fixed filename `production/qa/qa-plan-sprint-1.md`** (matches DoD + OQ-5 [A]; date lives in the header)
- **Safe-area API spike (Task 1-2) RESOLVED (2026-08-11)** — runtime-probed against installed Godot 4.6.stable (official 89cea1439). Exact 4.6 call signature **verified**: `DisplayServer.get_display_safe_area() -> Rect2i` (const, **no parameters**); official 4.6 docs: "Returns the unobscured area of the display where interactive controls should be rendered." Headless probe output: `[P: (0, 0), S: (0, 0)]` — empty rect expected in headless (no real display; real values on device). Bonus verified: `DisplayServer.get_display_cutouts() -> Array[Rect2]` (Android-only, per-cutout bounding rects). **No fallback needed — no open question remains for R1 at M6**; Viewport-inset / per-device notch table stays as device-evidence backup only. Probe: `/tmp/safe-area-probe/probe.gd` + minimal `project.godot` (temp, outside repo); finding feeds ADR-0011 at M6. VMV OQ-1 / Conversion UI OQ-3 / HUD OQ-7 all resolved by this probe.
- ⚠️ **Pre-existing inconsistency flagged for `/consistency-check`** (NOT edited): `RivalFaithConfig.aggression_interval_turns` default is **6** in game-config.md vs **3** in rival-faith-system.md — the two GDDs must agree before implementation; game-config.md is the authoritative config owner (scheduled for Creative Director ruling via task 1-18)

## Sprint 1 Execution Records (2026-08-11)

- **Task 1-3 M0 scaffold ✅** (commit f61bc47): project.godot with the 10 Autoloads in EXACT ADR-0001 order + portrait/mobile settings (720×1280, orientation=1, canvas_items, Compatibility renderer); full §7 directory tree; main.tscn; SCAF test. Verified: `godot --headless --quit --path .` exit 0, zero errors. NOTE: 1-3 ships minimal autoload placeholder shells so the project boots per AC — the ADR-0001 dependency assertions + boot test land with 1-6.
- **Task 1-4 GameEnums ✅** (commit 4805a59): src/core/game_enums.gd — 10 enums per architecture §4.2/ADR-0002, ConversionOutcome.PERSUADED (no CONVERTED). Probe verified: compiles; all members/order match; ENUM-1..5 green in GUT.
- **Task 1-5 GUT setup ✅** (commit f565469): vendored **GUT v9.6.1** at addons/gut/ (decision recorded in tests/README.md: v9.7.1 REJECTED — stub_params.gd typed getter returns null for StringName-inferred property → parse error on 4.6, would break double()/stub()); tests/gdunit4_runner.gd (subclass of GUT's official CLI entry) + .gutconfig.json; `godot --headless --script tests/gdunit4_runner.gd` green (12/12 at final state), exit 0.
- **Task 1-6 M0 boot test ✅**: all 10 stub Autoloads upgraded with `_ready()` dependency assertions per ADR-0001; GSM connects DCS signals via `call_deferred("_connect_signals")` (never misses session_begun); tests/integration/m0_boot_test.gd (BOOT-1..4). Verified: headless boot exit 0, zero errors; full GUT suite 12/12 green. One test-fix during execution: BOOT-3 initially queried `GameStateManager.is_connected` (wrong object — the emitter is DCS); corrected to `DialogueConversionSystem.is_connected(...)`.
- **Task 1-7 Pre-production gate-check ✅** (PASS, R2 flagged): report at `production/gate-checks/pre-production-2026-08-11.md` — 14/14 GDDs complete (8/8 sections each, verified by header scan), systems-index tracker current (14/14), 9 config domains consistent across game-config.md / entities.yaml / ADR-0005, session state current, sprint plan + QA plan present. **R2 surfaced as Creative Director decision item** (aggression_interval_turns 6 authoritative in game-config.md vs 3 in rival-faith-system.md) — NOT edited here; ruling scheduled as task 1-18. Verdict: PASS, no blockers.
- **Task 1-8 ADR-0005 Config system ✅** (Status **Accepted** 2026-08-11): docs/architecture/adr-0005.md — nine config domains (Conversion/Traits/FaithSpread/RivalFaith/Progression/UITiming/Portraits/VillageMap/HUD) with pinned `.tres` paths; pull pattern (GameConfig ONLY reader of config `.tres` — entities.yaml rule); per-field validation/clamp + warning (AC-3); hard-halt on missing file/required field (AC-4/5); editor-only hot-reload with `config_reloaded` (AC-7/8); AC-9 (no config in saves) deferred to M4 by design. Field authority = game-config.md range tables (architecture §4.3 representative; ConversionConfig field-set drift flagged for next balance review). Verified: Status line, 8/8 required template sections, no placeholders. Milestone gate OQ-6: Accepted before 1-10 → unblocked.
- **Task 1-9 ADR-0006 Input architecture ✅** (Status **Accepted** 2026-08-11): docs/architecture/adr-0006.md — MTF sole input boundary (no UI reads Input; control-manifest Forbidden rule); dp conversion (`pixels_per_dp`, 160-DPI fallback); 44dp floor with center-anchored inflation; blocking-layer ownership = Conversion UI only; haptic on tap only; **R3 recorded + resolved**: Godot `_input()` propagates in **reverse scene order** (last autoload first) → MTF slot 4 does NOT get "listed first" priority; mitigation = registry-based hit-testing + no `set_input_as_handled()` unless a registered target consumed + `process_priority` backstop; MTF GDD Rule 1 wording flagged for one-line consistency update. References task 1-2 safe-area finding (layout only, not hit-test geometry). Verified: Status line, 8/8 required template sections, no placeholders, R3 finding present. Milestone gate OQ-6: Accepted before 1-13 → unblocked.
- **Task 1-10 GameConfig + 9 config domains ✅** (ADR-0005): `src/autoload/game_config.gd` — slot-1 Autoload loads the nine `.tres` in ADR-0005 fixed table order into typed domain properties; per-field validation/clamp + `push_warning` (AC-3); required-field detection scans raw `.tres` text (Godot fills absent fields with the @export default, so null-checks alone can't detect an un-authored required field) → hard-halt naming field (AC-4) / path (AC-5); editor-only hot-reload polls modified-times in `_process()` gated by `Engine.is_editor_hint()`, swaps + emits `config_reloaded` on success, retains last-valid + no signal on failure (EC-8); watcher state empty + `_process` disabled in non-editor (AC-8). The 9 pre-existing `src/resources/config/*.gd` classes were complete (full GDD field tables + validation schemas) — wired in, not regenerated. 9 `.tres` authored from GDD defaults (format 3, script_class headers), incl. `faith_spread_config.tres` (OQ-10). Tests: `tests/unit/game_config/game_config_test.gd` (10) + `tests/integration/game_config/game_config_order_test.gd` (2) — GCF-1..8 + AC-10 green. AC-9 (no config in saves) deferred to M4 by design (documented, not implemented). Full suite 24/24 green; headless boot exit 0, zero errors. One test-authoring fix during execution: GDScript class names are not constant expressions → DOMAINS table stores script paths, load()ed at runtime.
- **Task 1-11 TraitDatabase + 16 traits ✅** (NPC Trait Database GDD, ADR-0002/0005): `src/autoload/trait_database.gd` (slot 2) completed from stub — loads `res://assets/data/traits/trait_database.tres` at `_ready()`, indexes by id, exposes the full Rule 7 typed API (`is_loaded`, `get_trait`, `get_affinity`, `get_all_traits`, `get_traits_by_rarity`, `get_traits_for_archetype` — tagged ∪ archetype-agnostic); EC-3 normalisation fills any missing approach key with 0.0 + warning naming trait/approach; stateless (no NPC ownership/reveal state). NEW resources: `src/resources/trait_data.gd` (`TraitData` — id/display_name/description/rarity/approach_affinity/archetype_tags per GDD Rule 1) + `src/resources/trait_database_catalogue.gd` (`TraitDatabaseCatalogue` — serialised container, ADR-0002). Data: 16 trait `.tres` files authored verbatim from the GDD catalogue (7 COMMON / 6 UNCOMMON / 3 RARE, enum-int affinity keys 0=GRIEF/1=AMBITION/2=DOUBT/3=FEAR, 5-band values only) + `trait_database.tres` catalogue (format 3, script_class headers, sub-resource refs in GDD order). Tests: `tests/unit/trait_database/trait_database_test.gd` (11 tests) — AC-1..3, AC-7..11 against the live autoload; AC-4 (10,000-draw rarity simulation, 60/30/10 vs equal-count pool, deterministic seed) and AC-5/AC-6 (1,000 full assignment-formula runs: no duplicates, 2–4 traits) drive the GDD formula locally against the shipped catalogue + GameConfig weights (formula owner = NPC Character System at M2). Full suite 35/35 green; headless boot exit 0, zero errors. One fix during execution: `trait` is a reserved keyword in GDScript 4.6 (trait types) → loop locals renamed `entry` after a parse error.

## Files Modified This Session

- src/autoload/trait_database.gd — completed from stub (task 1-11): full Rule 7 API + EC-3 normalisation; `trait` → `entry` rename (reserved keyword in GDScript 4.6)
- src/resources/trait_data.gd — NEW TraitData Resource (GDD Rule 1 fields)
- src/resources/trait_database_catalogue.gd — NEW TraitDatabaseCatalogue Resource (ADR-0002 data carrier)
- assets/data/traits/*.tres — NEW 16 trait definitions + trait_database.tres catalogue (7C/6U/3R, verbatim from GDD)
- tests/unit/trait_database/trait_database_test.gd — NEW 11 tests covering TraitDB AC-1..11
- production/sprint-status.yaml — stories 1-1..1-10 marked completed with dates
- production/session-state/active.md — this file (task 1-11 execution record)
- production/sprints/sprint-1.md — NEW Sprint 1 plan (Scaffold & Foundation, M0+M1, 2026-08-17 → 2026-09-04); OQ-5 resolved [A]; DoD requires QA plan
- docs/architecture/adr-0001.md — NEW Autoload architecture & initialization order (Accepted)
- docs/architecture/adr-0002.md — NEW data resource model: GameEnums, VillageDefinition (Accepted)
- docs/architecture/adr-0003.md — NEW signal architecture & communication discipline (Accepted)
- docs/architecture/adr-0004.md — NEW scene ownership & CanvasLayer stack (Accepted)
- design/registry/entities.yaml — Appendix D: PortraitConfig, VillageMapConfig, GameEnums, BeliefState, DialogueApproach, NPCArchetype, NpcRecord, NPCArchetypeDefinition, VillageDefinition constants; ConversionOutcome + RivalFaithConfig notes updated
- design/gdd/save-load-system.md — architectural note order corrected: `NPCRegistry → DCS → GSM → SaveLoad` (reconciles GSM Rule 10)
- design/gdd/dialogue-conversion-system.md — §Formulas recency lifetime: GSM emits `village_cleared` signal (DCS subscribes)
- production/session-state/active.md — this file
- production/sprints/sprint-1.md — NEW Sprint 1 plan (Scaffold & Foundation, M0+M1, 2026-08-17 → 2026-09-04); OQ-5 resolved [A]; DoD requires QA plan
- production/sprint-status.yaml — NEW machine-readable story status (23 stories; Must → ready-for-dev, Should/Nice → backlog)
- design/gdd/hud-progress-system.md — NEW GDD (system #14), 8 sections + V/A + UI Req + OQs resolved + appendix
- design/gdd/game-config.md — HUDConfig 9th domain (Rule 2 nine domains, field ranges table, Interactions row, AC-1/AC-10, Tuning Knobs note)
- design/gdd/village-map-view.md — F1 top inset → `HUD.get_top_strip_height_dp()` (formula + output range + UI Req row)
- design/gdd/systems-index.md — row 14 → Designed; tracker 13/14 → 14/14; design docs started 13 → 14
- design/registry/entities.yaml — HUDConfig constant + F1/F2/F3 formulas + referenced_by updates (earlier)
- production/session-state/active.md — this file (earlier)
- production/session-state/active.md — Task 1-1 engine install spike record: Godot 4.6-stable (official build 89cea1439) downloaded from official GitHub releases (`Godot_v4.6-stable_linux.x86_64.zip`, SHA512 verified against release `SHA512-SUMS.txt`), installed to `~/.local/bin/godot` (bare name, ~/.local/bin already on PATH); `godot --version` → `4.6.stable.official.89cea1439` exit 0; `godot --headless --quit` exit 0 — R12 resolved
- production/session-state/active.md — Task 1-2 safe-area spike record: `DisplayServer.get_display_safe_area()` signature verified on 4.6 (`Rect2i`, no params) via headless probe (`/tmp/safe-area-probe/probe.gd`, temp, not in repo); bonus `get_display_cutouts()` verified; R1 closed for M6

## Cross-System Updates Pending
- ✅ design/gdd/dialogue-conversion-system.md — §Formulas recency state lifetime: "When GSM calls NPCRegistry.clear_village()" → "When GSM emits village_cleared signal (DCS subscribes)" — applied 2026-08-09
- ✅ design/gdd/save-load-system.md — Architectural Note autoload order corrected to `NPCRegistry → DCS → GameStateManager → SaveLoad` (reconciles GSM Rule 10, architecture plan D1/ADR-0001) — applied 2026-08-09
- ✅ design/gdd/game-config.md — PortraitConfig domain added (7th domain: Rule 2 "six domains"→seven, field ranges table, AC-10 "6 domains"→7, Interactions row) — applied 2026-08-09
- ✅ design/gdd/npc-character-system.md — `portrait_asset_path` format contract added under Rule 3 (directory path, six expression files, debug validation) — applied 2026-08-09
- ✅ design/gdd/npc-trait-database.md — archetypes note (`portrait_asset_path` + `social_influence_weight` owned by NPC Character System GDD) + P&E consumer row marked prospective — applied 2026-08-09
- ✅ design/gdd/game-config.md — UITimingConfig: `approach_confirm_hold_sec`, `hardened_reveal_hold_sec`, `trait_card_reveal_ms` added — applied 2026-08-09
- ✅ design/gdd/mobile-touch-framework.md — Conversion UI consuming-table row corrected (portrait NOT registered; P&E UI Req) — applied 2026-08-09
- ✅ design/gdd/dialogue-conversion-system.md — Timer Ownership wording fixed (tap calls `select_approach()` immediately); OQ-1 resolved (Conversion UI GDD Rule 12, −150K lighting cue) — applied 2026-08-09
- ✅ design/gdd/systems-index.md — row 12 → Designed; tracker 11/14 → 12/14 — applied 2026-08-09
- ✅ design/gdd/game-config.md — VillageMapConfig 8th domain added (Rule 2 "seven domains"→eight, field ranges table, Interactions row, AC-1/AC-10 "7 domains"→8, Tuning Knobs) — applied 2026-08-09
- ✅ design/gdd/conversion-ui.md — `conversation_closed` teardown guarantee confirmed on EVERY path (session-complete + back/cancel + defensive village-clear) — applied 2026-08-09
- ✅ design/gdd/dialogue-conversion-system.md — EC-1 wording fixed ("disabled by the Village Map View") — applied 2026-08-09
- ✅ design/gdd/systems-index.md — row 13 → Designed; tracker 12/14 → 13/14; design docs started 12 → 13 — applied 2026-08-09
- ✅ design/gdd/hud-progress-system.md — NEW GDD (system #14); OQ-1..OQ-8 resolved — applied 2026-08-09
- ✅ design/gdd/game-config.md — HUDConfig 9th domain added (Rule 2 "eight domains"→nine, field ranges table, Interactions row, AC-1/AC-10 "8 domains"→9, Tuning Knobs note) — applied 2026-08-09
- ✅ design/gdd/village-map-view.md — F1 top inset → `HUD.get_top_strip_height_dp()` (formula, output range, UI Req row) — applied 2026-08-09
- ✅ design/gdd/systems-index.md — row 14 → Designed; tracker 13/14 → 14/14; design docs started 13 → 14 — applied 2026-08-09
- ✅ design/registry/entities.yaml — HUDConfig constant + conversion_fraction/rival_activity_rate/chronicle_card_alpha formulas + referenced_by updates — applied 2026-08-09
- ✅ Open Questions from architecture plan §9 — now scheduled as Sprint 1 tasks per the accepted plan (engine install 1-1; safe-area spike 1-2; FaithSpreadConfig ships with 1-10 per OQ-10; VillageDefinition sign-off 1-19; dialogue authoring format 1-20; boot/title flow 1-22); RNG persistence (architecture §9 OQ-7) remains open, deferred to M4 save/load — applied 2026-08-11
- ⬜ **Flagged for `/consistency-check`** (NOT edited): `RivalFaithConfig.aggression_interval_turns` default 6 (game-config.md, authoritative) vs 3 (rival-faith-system.md) — ruling scheduled as task 1-18

## Next
Pre-production design documentation is COMPLETE — all 14/14 MVP GDDs designed; MVP Architecture Plan accepted (ADR-0001…0004 Accepted); Sprint 1 plan + QA plan accepted (2026-08-11).
Remaining pre-production items:
1. ✅ **Architecture plan** — docs/architecture/architecture.md Accepted; ADR-0001…0004 Accepted (M0 foundation)
2. ✅ **Sprint plan** — 7-sprint roadmap accepted 2026-08-11; Sprint 1: Scaffold & Foundation (M0+M1, 2026-08-17 → 2026-09-04); `production/sprints/sprint-1.md` + `production/sprint-status.yaml` committed
3. ✅ **QA plan for Sprint 1** — `production/qa/qa-plan-sprint-1.md` approved 2026-08-11; OQ-A…OQ-H resolved per draft recommendations (no emulator layer, local WSL headless evidence, automated assert + export spot-check, two test-only fixtures, AC-6 static scan, V_total=100 automation, process stories as Config/Data, fixed filename); sprint DoD item 3 satisfied
4. **Sprint 1 execution (2026-08-17 → 2026-09-04)** — IN PROGRESS. In-sprint tasks 1-1…1-23 (15 Must / 5 Should / 3 Nice): ✅ engine install spike 1-1; ✅ safe-area spike 1-2; ✅ M0 scaffold 1-3; ✅ GameEnums 1-4; ✅ GUT setup 1-5; ✅ M0 boot test 1-6; ✅ pre-production gate-check 1-7 (PASS, R2 flagged); ✅ ADR-0005 1-8 (Accepted); ✅ ADR-0006 1-9 (Accepted, R3 resolved); ✅ GameConfig + 9 domains 1-10; ✅ TraitDatabase + 16 traits 1-11 (draft complete, awaiting Creative Director review/commit approval). NEXT: DCD 1-12, MTF 1-13, regression + milestone records (1-14/1-15); Should: control manifest 1-16, TR registry 1-17, R2 ruling 1-18, VillageDefinition sign-off 1-19, dialogue authoring format 1-20; Nice: CI 1-21, boot/title sketch 1-22, placeholder art 1-23
5. **UX spec** — `/ux-design` for `design/ux/hud.md` (HUD UI requirements — flagged in the HUD GDD; needed before M6)
6. **Asset specs** — `/asset-spec` per system once the Art Bible is approved (HUD flagged: system:hud-progress-system; needed before M5/M6)
MVP systems remaining: none — design phase complete.
