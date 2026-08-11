> Review mode: `lean` (no `production/review-mode.txt` → skill Phase 0 default) → **PR-SPRINT skipped — Lean mode.** Producer feasibility assessment is therefore provided inline in the Capacity section instead of via the gate spawn.

# Sprint 1 -- 2026-08-17 to 2026-09-04

## Sprint Goal
Deliver the M0+M1 foundation: a bootable Godot 4.6 project skeleton (10-Autoload order, GameEnums, GUT), the full Foundation layer (GameConfig with 9 `.tres` domains, TraitDatabase with 16 traits, DialogueDatabase with 100 scaffold strings, MTF gesture engine), and Accepted ADR-0005/0006 — proven by a green headless GUT suite and milestone records.

## Capacity
- Total days: 15 (assumption: **solo developer, FULL-TIME, 3-week sprint** — 5 working days/week; see Open Question OQ-2)
- Buffer (20%): 3 days reserved for unplanned work
- Available: 12 days
- Planned: Must Have = 11.75 days (98% of available, 0.25 slack); Should Have = 1.5 days; Nice to Have = 2.5 days. Should/Nice (4.0 days total) are stretch goals absorbed only from buffer headroom or early finishes; if Must slips, Should tasks are deferred to Sprint 2 first. (Inline producer check: Must ≤ Available ✓; stretch 4.0 exceeds Available by design and is explicitly risk-managed — this is a realistic solo-dev foundation sprint.)

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| 1-1 | Engine install spike — R12 (architecture §8): install Godot 4.6 (Windows binary runnable from WSL via /mnt/c, or Linux headless binary), verify `godot --version` = 4.6.x and headless invocation works; record local-vs-CI decision in session state | devops-engineer | 1.0 | — | `godot --version` reports 4.6.x in PATH (or CI runner executes headless commands); `godot --headless --quit` exits 0; decision (local install vs CI-first) recorded in `production/session-state/active.md` |
| 1-2 | Safe-area API spike — R1 (architecture §9 OQ-1): runtime-probe `DisplayServer.get_display_safe_area()` against pinned 4.6 reference (docs/engine-reference/godot/); if absent, select fallback (Viewport insets / per-device notch table); finding feeds ADR-0011 at M6 | godot-gdscript-specialist | 0.5 | 1-1 | Spike note in session state records the exact 4.6 call signature verified OR the chosen fallback; no open question remains for R1 at M6 |
| 1-3 | M0 project scaffold (architecture §7): `project.godot` (main_scene `res://src/scenes/main.tscn`, 10 Autoloads in ADR-0001 order, portrait/mobile project settings), full directory tree (src/autoload, src/core, src/resources, src/resources/config, src/systems, src/scenes/{map,conversation,hud}, assets/data/{config,traits,dialogue,npcs,villages}, tests/), `.gitignore` for `.godot/` | engine-programmer | 1.0 | 1-1 | Project opens in Godot 4.6 editor with zero errors; directory layout matches architecture §7 exactly; `project.godot` Autoload list matches ADR-0001 slots 1–10 verbatim |
| 1-4 | GameEnums class (architecture §4.2, ADR-0002): `src/core/game_enums.gd` with all 10 enums — BeliefState, DialogueApproach, ConversionOutcome (**PERSUADED** rename), TraitRarity, RelationshipType, NPCArchetype, OutcomeCaller, AlignmentSignal, GSMState, SwipeDirection | godot-gdscript-specialist | 0.5 | 1-3 | Compiles headless; GUT test asserts every enum value matches §4.2 table; `GameEnums.ConversionOutcome.PERSUADED` present; no `CONVERTED` collision |
| 1-5 | GUT test framework setup: addon install, `tests/gdunit4_runner.gd` headless runner, placeholder `tests/unit/{game_config,trait_database,dialogue_database,mobile_touch_framework,...}/` and `tests/integration/` dirs | tools-programmer | 1.0 | 1-3, 1-1 | `godot --headless --script tests/gdunit4_runner.gd` executes and reports; empty suite is green; per-system test dirs exist per architecture §7 |
| 1-6 | M0 boot test (architecture §6 M0 testable outcome, ADR-0001): 10 stub Autoload scripts each with `_ready()` dependency assertions, registered in ADR-0001 order; minimal empty `main.tscn` | engine-programmer | 0.5 | 1-3, 1-4, 1-5 | Headless launch boots with no null-refs; every Autoload asserts its dependencies resolve; GSM deferred `_connect_signals` fires after DCS exists (ADR-0001 verification) |
| 1-7 | Pre-production gate-check (`/gate-check pre-production`): validate 14/14 GDDs complete, systems-index tracker current, 9 config domains consistent, session state current; surface R2 (`aggression_interval_turns` 6 vs 3) as a decision item | qa-lead | 0.25 | — | Gate-check report produced; verdict PASS or explicit blocker list; R2 flagged for Creative Director (resolved via 1-18) |
| 1-8 | ADR-0005 — Config system (9 domains, pull pattern, validation/clamp, hard-halt on missing, editor-only hot-reload): write + review, reach **Accepted** before 1-10 starts (milestone-gated per architecture §6) | technical-director | 0.5 | 1-4 | ADR-0005 Status = Accepted in `docs/architecture/adr-0005.md` (lifecycle Proposed → Accepted completed); template sections complete; 1-10 unblocked (no story references a Proposed ADR) |
| 1-9 | ADR-0006 — Input architecture (MTF sole input boundary, dp conversion, 44dp floor, blocking-layer ownership, R3 input-priority decision): write + review, reach **Accepted** before 1-13 starts | technical-director | 0.5 | 1-4 | ADR-0006 Status = Accepted; resolves/records R3 (Godot `_input()` reverse-scene-order finding) with chosen mitigation; 1-13 unblocked |
| 1-10 | GameConfig Autoload + 9 config Resource classes + 9 `.tres` (architecture §4.3; GameConfig GDD AC-1…10): `src/autoload/game_config.gd`, `src/resources/config/*.gd` ×9, `assets/data/config/*_config.tres` ×9 **including faith_spread_config.tres** (OQ-10 recommendation — ship all 9 per GameConfig AC-1); validation/clamp, hard-halt, pull pattern, editor-only hot-reload | godot-gdscript-specialist | 1.5 | 1-3, 1-4, 1-8 | GameConfig AC-1…8, AC-10 pass (GUT): LOADED before other Autoloads; typed access; out-of-range clamps with warning (AC-3); missing field/file halts with named error (AC-4/5); hot-reload swaps values + emits `config_reloaded` in editor (AC-7); no watcher in export build (AC-8); AC-9 (no config in saves) deferred to M4 by design |
| 1-11 | TraitDatabase Autoload + `assets/data/traits/trait_database.tres` with 16 traits (NPC Trait Database GDD): rarity bands, `approach_affinity` 5-band values keyed by GameEnums.DialogueApproach, `archetype_tags`; full API — get_trait, get_affinity, get_all_traits, get_traits_by_rarity, get_traits_for_archetype, is_loaded | godot-gdscript-specialist | 1.0 | 1-3, 1-4 | TraitDB AC-1…11 pass (GUT): 16 traits load; all accessors return correct data; unknown trait → `get_affinity` returns 0.0; `is_loaded() == true` after `_ready()` |
| 1-12 | DialogueDatabase Autoload + `assets/data/dialogue/dialogue_database.tres` with 100 scaffold strings (Dialogue Content Database GDD): 4-approach lines, outcome summaries, NPC flavour (3 inspect lines each), rival lines; under-filled-slot rule respected; `V_total = 100` audit (R8) | narrative-director (content) + godot-gdscript-specialist (system) | 1.0 | 1-3, 1-4 | DCD AC-1…13 pass (GUT): 100-string total verified (R8 audit); approach/outcome/rival accessors return lines; `get_npc_flavour()` returns a **duplicate** (EC-6); `is_loaded()` true; no slot below the 3-per-min invariant |
| 1-13 | MTF gesture engine (Mobile Touch Framework GDD AC-1…14): `src/autoload/mobile_touch_framework.gd` — register/unregister with priority, push/pop/clear blocking layers, `pixels_per_dp`, tap/long-press/swipe/touch-cancelled detection via `_input()`, haptic on tap only, no `set_input_as_handled()` unless a registered target consumed (R3, ADR-0006) | ui-programmer | 1.5 | 1-9, 1-4 | MTF AC-1…14 pass (GUT) using **synthetic InputEvents** (architecture §6 M1 testable outcome); sole input boundary verified (no UI reads `Input` directly); blocking-layer stack works; dp conversion correct |
| 1-14 | Foundation regression pass: full GUT suite (GameEnums, GameConfig, TraitDB, DCD, MTF, boot) run headless; integration sanity (Autoload order + signals); coverage audit vs M1 ACs | qa-lead | 0.75 | 1-5, 1-10, 1-11, 1-12, 1-13 | Full suite green headless (local or CI); every M1 AC mapped to ≥1 passing test; zero S1/S2 bugs; results recorded for milestone evidence |
| 1-15 | Milestone records M0 + M1: create `production/milestones/milestone-m0.md` + `milestone-m1.md` capturing the architecture §6 testable outcomes (M0: boots headless, enums compile, Autoload order null-ref-free; M1: GameConfig AC-1…10, TraitDB AC-1…11, DCD AC-1…13, MTF AC-1…14) with evidence pointers | qa-lead + engine-programmer | 0.25 | 1-6, 1-14 | Both milestone files exist with status, evidence (test run output paths, AC checklist), and date; they become the Phase 1 read source for `/sprint-plan update` |

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| 1-16 | Control manifest via `/create-control-manifest`: `docs/architecture/control-manifest.md` with date-stamped `Manifest Version:`, Required/Forbidden/Guardrails per layer (architecture Appendix C) | technical-director | 0.25 | ADR-0001…0004 (already Accepted) | Manifest exists with `Manifest Version:` dated 2026; Required (signal-only GSM↔DCS, etc.), Forbidden (hardcoded gameplay values, non-MTF input reads, second blocking-layer owner), Guardrails (Autoload order, exclusive callers) all present; version embeddable in stories |
| 1-17 | TR registry + architecture review: `/architecture-review` Phase 8 populates `docs/architecture/tr-registry.yaml` with M1 IDs (`TR-GCF-*`, `TR-TDB-*`, `TR-DCD-*`, `TR-MOV-*`); append-only — no renumbering of existing IDs; review report written | technical-director | 0.5 | 1-8, 1-9, 1-10, 1-11, 1-12, 1-13 | `tr-registry.yaml` populated with M1 TR IDs (append-only verified via git diff); architecture-review report file written; M1 stories reference TR IDs |
| 1-18 | R2 consistency decision: `/consistency-check` + Creative Director ruling on `aggression_interval_turns` (6 in game-config.md authoritative vs 3 in rival-faith-system.md); apply one-line RFS GDD default fix 3 → 6 | systems-designer + creative-director | 0.25 | 1-7 (flag), — | RFS GDD `aggression_interval_turns` default = 6 matching game-config.md; decision recorded in session state; no code impact (HUD reads field at call time) |
| 1-19 | VillageDefinition schema sign-off (architecture §9 OQ-4): Creative Director confirms proposed Resource shape (`village_id`, `npc_definitions`, `map_art_path`, `rng_seed`) + first village content authorship timing (pre-M2 or pre-M5) | technical-director + creative-director | 0.25 | — | Schema confirmed and recorded in session state; ADR-0002's "proposed" note resolved; M2 `village_01.tres` authorship scheduled |
| 1-20 | Dialogue authoring format decision (architecture §9 OQ-5 / DCD OQ-3): YAML/CSV → `.tres` pipeline chosen; recorded as addendum to ADR-0005; content pipeline documented for full authoring before M5 | tools-programmer + narrative-director | 0.25 | — | Format decision documented in ADR-0005 addendum; conversion pipeline (if any) sketched; authoring workflow ready for M5 content volume |

### Nice to Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| 1-21 | CI pipeline (GitHub Actions): headless GUT run on push to `main` (per CI rules, `godot --headless --script tests/gdunit4_runner.gd`); only if 1-1 chose local install as primary | devops-engineer | 1.0 | 1-1, 1-5 | Push triggers headless test job; results reported in PR checks; green on `main`; cached engine artifact documented |
| 1-22 | Boot/title flow sketch (architecture §9 OQ-6): `main.tscn` title placeholder + `SaveLoadSystem.load_game()` call site scaffold (behavior deferred to M4/M6; title return per HUD OQ-4) | engine-programmer | 0.5 | 1-6 | `main.tscn` instantiates; calls `load_game()` safely once after Autoloads ready (ADR-0001/0004); `load_not_found` → title placeholder shown; no crash |
| 1-23 | Placeholder art generation (R7 mitigation): 7 archetypes × 6 expression placeholder portraits + village map placeholder at `res://assets/portraits/` and `res://assets/maps/` meeting the NPC CS portrait path contract (debug validation passes) | technical-artist | 1.0 | — | Placeholder assets exist in GDD-pinned paths; 6 files per archetype; NPC CS debug validation (portrait_asset_path contract) passes; placeholders unblock M5/M6 scene work |

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| None — first sprint plan | No previous sprint exists (`production/sprints/` absent); no velocity baseline. Velocity established this sprint; carryover table populated from Sprint 2 onward | — |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| R12 — Godot 4.6 not installed in PATH; cannot run GUT locally (architecture §8) | High | High | Task 1-1 spike on Day 1 (Windows binary via WSL or Linux headless); fallback CI runner (1-21); decision recorded before any testable task starts |
| R1 — Safe-area API unverified in pinned 4.6 reference (Conversion UI OQ-3, VMV OQ-1, HUD OQ-7) | Med | High | Task 1-2 spike this sprint (0.5d); fallback Viewport insets / notch table; decision recorded for ADR-0011 at M6 |
| R3 — MTF "listed first" input-priority claim may be wrong (reverse scene order) | Med | Med | ADR-0006 (1-9) records the engine finding; MTF registry hit-testing + no `set_input_as_handled()` unless consumed; `process_priority` if needed; verified at 1-13 |
| R4 — Autoload-order conflict (GSM Rule 10 vs Save&Load note) | High | Med | Already resolved by ADR-0001 (DCS before GSM); 1-6 boot test asserts the order; Save&Load GDD note already corrected 2026-08-09 |
| R2 — `aggression_interval_turns` 6 vs 3 (game-config vs RFS GDD) | High | Med | 1-7 gate-check flags; 1-18 Creative Director decision; game-config.md authoritative; HUD reads field at call time — no crash either way |
| R8 — Dialogue content volume: 3-per-slot minimum is a hard invariant (recency needs L>W) | Med-High | Med | 1-12 enforces `V_total = 100` audit + under-filled-slot rule in AC; authoring format decided at 1-20 before M5 content authoring |
| R11 — Zero-ADR state blocks stories (coding standards auto-block on Proposed ADRs) | High | Med | M0 ADRs done; 1-8/1-9 written at sprint start and reach Accepted before 1-10/1-13; control manifest (1-16) follows |
| R7 — Missing art/content fallbacks (42 portraits + 28 thumbnails + map art not authored) | High | Med | 1-23 placeholders this sprint (Nice); GDD fallbacks (P&E EC-6/7, VMV EC-5/6, DCD under-filled-slot) implemented at M5/M6; asset specs scheduled pre-M5/M6 |
| SPR-1 (new) — Solo full-time dev is the single point of failure for all 11.75 Must days | Med | High | 20% buffer (3d) reserved; Must capped at 98% of available; Should/Nice are the first deferral tier; milestones are the checkpoints (directors review at milestones only, lean mode) |
| SPR-2 (new) — WSL/Godot headless quirks (GUI editor vs headless CI; file paths across /mnt/c) | Med | Low | Covered by 1-1 spike; headless invocation is the primary verification path; CI (1-21) provides a clean-room runner if WSL path issues block |

## Dependencies on External Factors
- **Godot 4.6 binary download** (network access) — blocks 1-1 and everything downstream; flagged in OQ-3.
- **Creative Director sign-offs during Sprint 1:** ADR-0005/0006 acceptance (OQ-6), capacity confirmation (OQ-2), R2 interval ruling (1-18), VillageDefinition schema (1-19), dialogue format (1-20), QA-plan call (OQ-5).
- **QA plan for Sprint 1** (`production/qa/qa-plan-sprint-1.md`) — does not exist; see section D and OQ-5. DoD below cannot be fully met without it.
- **Design deliverables deferred to later sprints (not Sprint 1 blockers):** UX spec `design/ux/hud.md` (before M6, per HUD GDD), asset specs per system (before M5/M6, per Art Bible).
- **Godot 4.6 export templates for Android** — not needed until M7 device pass; no action this sprint.

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-1.md`) — OQ-5 resolved [A]: QA plan WILL be created before implementation
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
- [ ] Milestone records `production/milestones/milestone-m0.md` and `milestone-m1.md` exist with architecture §6 testable outcomes evidenced (task 1-15)
