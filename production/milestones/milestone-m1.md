# Milestone M1 — Foundation
**Status**: ✅ **REACHED** (evidence 2026-08-18)
**Engine**: Godot 4.6.stable.official.89cea1439 (headless, local WSL — QA plan OQ-B primary evidence)
**Milestone gated by**: ADR-0005 (Config system), ADR-0006 (Input architecture) — both **Accepted**
**Built by**: Sprint 1 stories 1-8 (ADR-0005), 1-9 (ADR-0006), 1-10 (GameConfig + 9 domains), 1-11 (TraitDatabase + 16 traits), 1-12 (DialogueDatabase + 100 strings), 1-13 (MTF gesture engine); verified by 1-14 (coverage audit) — this record from 1-15
**Scope (architecture §6)**: GameConfig + 9 `.tres`; TraitDatabase + 16 traits; DialogueDatabase + 100 strings (scaffold content); MTF gesture engine | Testable outcome: *GameConfig AC-1…10; TraitDB AC-1…11; DCD AC-1…13; MTF AC-1…14 (synthetic InputEvents).*

---

## Acceptance-criteria coverage (full matrix: `production/qa/evidence/sprint1-ac-coverage-matrix-2026-08-18.md`)

| System | ACs | Mapped → passing test | Unmapped (gap) | Suite green 2026-08-18 |
|--------|-----|----------------------|----------------|------------------------|
| GameConfig | AC-1..10 (10) | 9 | 1 — **AC-9 deferred by design to M4** | ✅ 10/10 unit + 2/2 order |
| TraitDatabase | AC-1..11 (11) | 11 | 0 | ✅ 11/11 |
| DialogueDatabase | AC-1..13 (13) | 13 | 0 | ✅ 15/15 (incl. R8 audit + defensive copies) |
| MobileTouchFramework | AC-1..14 (14) | 14 | 0 (AC-14 manual Android export spot-check at M7, OQ-C) | ✅ 24/24 |
| **Total** | **48** | **47** | **1 (by design)** | **74/74, 4810 asserts, exit 0** |

**Deferred ACs (recorded, carried forward — do not block this milestone):**
- **GameConfig AC-9** (save/load never re-saves config) → M4 when SaveLoad exists (QA plan GCF-DEF; architecture §6).
- **MTF AC-14 manual export spot-check** → M7 (no Android export templates this sprint; automated assert already green — QA plan OQ-C).

**QA-plan reconciliation:** §OUT of qa-plan-sprint-1.md deferred TraitDB AC-4/5/6 to Sprint 2; story 1-11 instead implemented them as local GDD-formula simulations (10,000-draw rarity bands AC-4; 1,000-NPC no-duplicates AC-5; 2–4 count AC-6). All three are COVERED here; the NPC Character System remains the production formula owner at M2.

## TR IDs (story references — registered by story 1-17)

Stable requirement IDs from `docs/architecture/tr-registry.yaml` (populated 2026-08-18, append-only).
Stories 1-8…1-15 implement these; story FILES do not exist (`production/stories/sprint-1/` — pre-existing gap,
flagged for Goran), so the references live here + in session state. Control manifest version: `manifest-2026.1`.

| System | TR IDs (family, count) | Registering ADRs | Verifying tests |
|--------|------------------------|------------------|-----------------|
| GameConfig | TR-GCF-001…012 (12) | ADR-0005, ADR-0002, ADR-0001 | tests/unit/game_config/game_config_test.gd (10) + tests/integration/game_config/game_config_order_test.gd (2) |
| TraitDatabase | TR-TDB-001…013 (13) | ADR-0002, ADR-0005 | tests/unit/trait_database/trait_database_test.gd (11) |
| DialogueDatabase | TR-DCD-001…013 (13) | ADR-0002 | tests/unit/dialogue_database/dialogue_database_test.gd (15) |
| MobileTouchFramework | TR-MOV-001…017 (17) | ADR-0006, ADR-0003 | tests/unit/mobile_touch_framework/mtf_gesture_test.gd (24) |
| **Total** | **55** | 6 Accepted ADRs | 74/74 suite, 4810 asserts, exit 0 |

Full per-ID requirement text + coverage status: `docs/architecture/architecture-review-2026-08-18.md`.
⚠️ Partial TRs (scheduled, not blocking M1): TR-GCF-010 (M4 by design), TR-TDB-006/010 (ADR-0007 at M2),
TR-TDB-008 (ADR-0009 at M4), TR-DCD-012 (ADR-0008 at M3), TR-DCD-013 (story 1-20).

## Verification evidence (2026-08-18, story 1-14)
| Check | Command / file | Result |
|-------|----------------|--------|
| Full GUT suite headless | `godot --headless --script tests/gdunit4_runner.gd` → `production/qa/evidence/sprint1-full-suite-2026-08-18.log` | ✅ 74/74, 4810 asserts, **exit 0** |
| Headless boot | `godot --headless --quit --path .` | ✅ exit 0, zero errors |
| Integration sanity (Autoload order + signals) | `production/qa/evidence/chain-probe-2026-08-18.log` (GameEnums→GameConfig→TraitDB→DCD→MTF; DCS↔GSM wiring; MTF sole input boundary) | ✅ PASS, exit 0 |
| AC-6 static scan (no hardcoded balance values) | `production/qa/evidence/reg3-static-scan-ac6-2026-08-18.md` (src/gameplay absent; src/core clean) | ✅ PASS |
| Coverage matrix | `production/qa/evidence/sprint1-ac-coverage-matrix-2026-08-18.md` | ✅ 47/48 mapped, 1 documented gap |

## Test files (per system)
- **GameConfig**: tests/unit/game_config/game_config_test.gd (10) + tests/integration/game_config/game_config_order_test.gd (2) — fixtures tests/fixtures/config/
- **TraitDatabase**: tests/unit/trait_database/trait_database_test.gd (11)
- **DialogueDatabase**: tests/unit/dialogue_database/dialogue_database_test.gd (15) — fixtures tests/fixtures/dialogue/ (OQ-D)
- **MTF**: tests/unit/mobile_touch_framework/mtf_gesture_test.gd (24)
- **Shared**: tests/unit/m0_scaffold_test.gd (3), tests/unit/core/game_enums_test.gd (5), tests/integration/m0_boot_test.gd (4)

## Dates
- 2026-08-11 — ADR-0005/0006 Accepted
- 2026-08-12 — GameConfig + TraitDatabase landed (1-10, 1-11)
- 2026-08-18 — DialogueDatabase + MTF landed (1-12 commit 33acb7a, 1-13 commit 04cce1a); regression + coverage audit (1-14) this date; milestone record (1-15) this date

## Phase-1 read source
This file + `milestone-m0.md` are the read sources for `/sprint-plan update` per story 1-15 AC. Sprint DoD item 10 satisfied.