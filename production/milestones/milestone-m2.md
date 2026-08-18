# Milestone M2 — Core data & math
**Status**: ✅ **REACHED** (evidence 2026-08-18)
**Engine**: Godot 4.6.stable.official.89cea1439 (headless, local WSL — QA plan OQ-B primary evidence)
**Milestone gated by**: ADR-0007 (Determinism & RNG strategy) — Accepted
**Built by**: Sprint 2 stories 2-1 (ADR-0007), 2-2 (ConversionConfig reconciliation), 2-3 (NPC resource classes), 2-4 (VillageDefinition + village_01.tres), 2-5 (RNG helpers), 2-6 (NPCRegistry), 2-7 (CLE), verified by 2-8 (integration + coverage audit) — this record from 2-9
**Scope (architecture §6)**: Resource classes (NpcRecord, connections, gates, archetypes, VillageDefinition); NPCRegistry (generation, transitions, approachability, reveal); CLE | Core | Testable outcome: NPC CS AC-1…21 (seeded determinism); CLE AC-1…8 (pure, seeded).

---

## Acceptance-criteria coverage (full matrix: `production/qa/evidence/sprint2-ac-coverage-matrix-2026-08-18.md`)

| System | ACs | Mapped → passing test | Unmapped (gap) | Suite green 2026-08-18 |
|--------|-----|----------------------|----------------|------------------------|
| NPC Character System | AC-1..21 (21) + E1..E14 (14) | 35 | 0 | ✅ 42/42 unit + 7/7 village-lifecycle integration |
| Conversion Logic Engine | AC-1.1..8.4 (42) | 42 | 0 | ✅ 43/43 |
| **Total** | **77** | **77** | **0** | **204/204, 22711 asserts, exit 0** |

**Deferred ACs (recorded, carried forward — do not block this milestone):**
- **CLE EC-9…EC-13 real-caller linkage** (actual DCS/RFS systems) → **M3**; the edge *handling* itself is COVERED now — synthetic callers in the CLE unit suite (AC-7.x sentinels, EC-11 pair contract, EC-13 max-approach boundary) + the M2 integration suite playing the caller role (M2-INT-1, CLE AC-8.3 "here you ARE the caller").
- **NPC CS ACs requiring UI/presentation** (portrait expression mapping, inspect-flow presentation) → **M5**; NPC-side logic (reveal selection, no-ops) is fully covered.
- **Android export spot-check** (MTF AC-14-style manual pass) → **M7** (OQ-C); automated asserts green now.
- **GameConfig AC-9** (save/load never re-saves config) — carried from M1 → **M4** when SaveLoad exists; listed for continuity only (not an M2 AC).

**QA-plan reconciliation:** the Sprint 2 QA plan §OUT listed CLE EC-9…EC-13 call-path edge cases as
only M3-exercised (real DCS/RFS linkage); at execution these were covered directly via synthetic
callers + the integration suite playing the caller role (see deferral note above). **CLE GDD/CONFIG
contradiction (flagged at 2-7, surfaced here for the milestone):** shipped band fractions
0.545+0.455=1.0 mathematically EMPTY the HARDENED zone at every P_final, while the GDD drama-space
table + AC-6.4/AC-6.7 assume a sum < 1.0; AC-6.4/AC-6.7 run with **adjusted effective bands
documented per test** (mirror of how Sprint 1 reconciled TraitDB AC-4/5/6). The formula is
implemented exactly per GDD Formula 5 — the finding stays open for the Creative Director as a
balance/tuning item, **NOT silently changed**. CONVERTED no-op (CLE EC-4 → apply no-op) is covered
at BOTH unit (AC-3.4, NPC AC-7) and integration (test_m2_int_1_converted_npc_resolve_valid_and_apply_noop) level.

## TR IDs (story references — M2-native families register at story 2-10)

Stable requirement IDs from `docs/architecture/tr-registry.yaml` (append-only, populated
2026-08-18). Families registered to date are the M1 set (below). The M2-native families — NPC
Character System (`TR-NPC-*`) and Conversion Logic Engine (`TR-CLE-*`), sourced from NPC CS AC-1…21
and CLE AC-1…8 requirement text — are **registered at task 2-10** (M2-scoped architecture review,
scheduled); no `TR-NPC-*`/`TR-CLE-*` IDs exist in the registry yet, so this milestone does not
invent them. Control manifest version: `manifest-2026.1`.

| System | TR IDs (family, count) | Registering ADRs | Verifying tests |
|--------|------------------------|------------------|-----------------|
| GameConfig | TR-GCF-001…012 (12) | ADR-0005, ADR-0002, ADR-0001 | tests/unit/game_config/game_config_test.gd (10) + tests/integration/game_config/game_config_order_test.gd (2) |
| TraitDatabase | TR-TDB-001…014 (14) | ADR-0002, ADR-0005, ADR-0007 | tests/unit/trait_database/trait_database_test.gd (11) |
| DialogueDatabase | TR-DCD-001…014 (14) | ADR-0002, ADR-0005 (+ Addendum 1) | tests/unit/dialogue_database/dialogue_database_test.gd (15) |
| MobileTouchFramework | TR-MOV-001…017 (17) | ADR-0006, ADR-0003 | tests/unit/mobile_touch_framework/mtf_gesture_test.gd (24) |
| NPC Character System | TR-NPC-* (registered at 2-10) | ADR-0007 (gates M2) | tests/unit/npc_registry/npc_registry_test.gd (42) + tests/integration/npc_registry/village_lifecycle_test.gd (7) + tests/integration/m2/m2_integration_chain_test.gd (4) |
| Conversion Logic Engine | TR-CLE-* (registered at 2-10) | ADR-0007 (gates M2) | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd (43) |

Full per-ID requirement text + coverage status: `docs/architecture/architecture-review-2026-08-18.md`
(M1-scoped); the M2-scoped review at 2-10 registers the new families and flips the partial-TR
statuses below.
⚠️ Partial TRs (scheduled, not blocking M2): **TR-TDB-006 and TR-TDB-010 are resolved-by-design via ADR-0007**
(Decision 7 — implementation landed in `rng_helpers.gd` at 2-5: weighted draw without replacement +
no-duplicate guarantee; NPCRegistry at 2-6: AC-1/AC-4/AC-5 determinism proof; formal registry status
flip from `active` happens at 2-10's M2-scoped review). Remaining partial/scheduled: TR-GCF-010 (M4
by design), TR-TDB-008 (ADR-0009 at M4), TR-DCD-012 (ADR-0008 at M3), TR-DCD-013/014 (M5 content
pipeline — ADR-0005 Addendum 1, story 1-20).

## Verification evidence (2026-08-18, story 2-8)
| Check | Command / file | Result |
|-------|----------------|--------|
| Full GUT suite headless | `godot --headless --script tests/gdunit4_runner.gd` → `production/qa/evidence/sprint2-full-suite-2026-08-18.log` | ✅ 204/204, 22711 asserts, **exit 0** (wall-clock 1.901s; boot 229ms recorded) |
| Headless boot | `godot --headless --quit --path .` | ✅ exit 0, zero errors |
| M2 integration chain + determinism probe (M2-INT-1 generate→resolve→apply on village_01; M2-INT-2 same-seed full-chain determinism) | `production/qa/evidence/sprint2-chain-and-determinism-2026-08-18.log` | ✅ PASS — CHAIN_PROBE_RESULT: PASS, PROBE_EXIT=0 |
| REG-3 static scan (no hardcoded balance values; RNG confined to `rng_helpers.gd` — sole direct RNG user per ADR-0007 Decision 2 guardrail) | `production/qa/evidence/reg3-static-scan-sprint2-2026-08-18.md` | ✅ PASS |
| Coverage matrix | `production/qa/evidence/sprint2-ac-coverage-matrix-2026-08-18.md` | ✅ 77/77 mapped, 0 gaps |
| Sprint 1 continuity (prior evidence referenced by this milestone) | `production/qa/evidence/sprint1-full-suite-2026-08-18.log` (74/74 baseline), `sprint1-ac-coverage-matrix-2026-08-18.md` (47/48), `chain-probe-2026-08-18.log`, `reg3-static-scan-ac6-2026-08-18.md` | ✅ retained |

## Test files (per system)
- **RNG helpers**: tests/unit/npc_rng/rng_helpers_test.gd (15)
- **NPC resources**: tests/unit/npc_resources/npc_resources_test.gd (14) + tests/unit/npc_resources/village_definition_test.gd (5) — data: assets/data/npcs/archetypes.tres, assets/data/villages/village_01.tres
- **NPCRegistry**: tests/unit/npc_registry/npc_registry_test.gd (42) + tests/integration/npc_registry/village_lifecycle_test.gd (7)
- **CLE**: tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd (43) — caller stubs tests/unit/conversion_logic_engine/stub_dcs_shaped.gd + stub_rfs_shaped.gd (AC-8.3)
- **M2 integration**: tests/integration/m2/m2_integration_chain_test.gd (4) — M2-INT-1 full chain + R9 pair contract + Rule 5 belief table + CONVERTED no-op; M2-INT-2 full-chain determinism
- **Reused M1 regression**: tests/unit/core/game_enums_test.gd (5), tests/unit/m0_scaffold_test.gd (3), tests/integration/m0_boot_test.gd (4), plus the M1 unit suites above

## Dates
- 2026-08-18 — ADR-0007 Accepted (2-1, commit 39d8458)
- 2026-08-18 — ConversionConfig reconciliation (2-2, commit d865161)
- 2026-08-18 — NPC resource classes + archetypes.tres (2-3, commit 39bf145); village_01.tres (2-4, commit b3e669a); RNG helpers (2-5, commit 889009f); NPCRegistry (2-6, commit e37169a)
- 2026-08-18 — CLE landed (2-7, commit b1218f5)
- 2026-08-18 — M2 integration + regression + coverage audit (2-8, commit 819010f)
- 2026-08-18 — Milestone record M2 (2-9, this commit)

## Phase-1 read source
This file is the read source for `/sprint-plan update` per story 2-9 AC (`milestone-m0.md` /
`milestone-m1.md` retained for continuity). Sprint DoD item 10 satisfied.