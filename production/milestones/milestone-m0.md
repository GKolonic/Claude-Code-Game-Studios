# Milestone M0 — ADR + Scaffold
**Status**: ✅ **REACHED** (evidence 2026-08-18; foundation built 2026-08-11)
**Engine**: Godot 4.6.stable.official.89cea1439 (headless, local WSL — QA plan OQ-B primary evidence)
**Milestone gated by**: ADR-0001…0004 (all **Accepted**)
**Built by**: Sprint 1 stories 1-3 (scaffold), 1-4 (GameEnums), 1-5 (GUT), 1-6 (boot test); re-verified by 1-14 (foundation regression)
**Scope (architecture §6)**: All foundational ADRs accepted; project skeleton (project.godot, autoload list, dirs, GUT setup, GameEnums) | Testable outcome: *Empty-project boots headless; enums compile; autoload order loads without null-refs.*

---

## Testable outcomes (architecture §6 M0)

### 1. Empty-project boots headless
| Check | Command | Evidence | Result |
|-------|---------|----------|--------|
| Headless boot, exit 0, zero errors | `godot --headless --quit --path .` | 1-14 re-run 2026-08-18 (run output captured in regression record; boot exit 0, no errors/warnings) | ✅ PASS |
| Editor boots | open project in Godot 4.6 | story 1-3 manual check | ✅ PASS (recorded 1-3) |

### 2. Enums compile
| Check | Test file | Test | Result |
|-------|-----------|------|--------|
| 10 enums present, values match architecture §4.2 | tests/unit/core/game_enums_test.gd | test_enum_1..3 | ✅ PASS (5/5) |
| ConversionOutcome.PERSUADED rename, no CONVERTED collision | tests/unit/core/game_enums_test.gd | test_enum_4, test_enum_5 | ✅ PASS |

### 3. Autoload order loads without null-refs
| Check | Test file / evidence | Result |
|-------|----------------------|--------|
| project.godot Autoload list matches ADR-0001 slots 1–10 verbatim | tests/unit/m0_scaffold_test.gd test_scaf_1 (+ SCAF-2 dirs, SCAF-3 .gitignore) | ✅ PASS (3/3) |
| All 10 Autoloads instantiate on /root in order; dependency edges resolve | tests/integration/m0_boot_test.gd test_boot_1, test_boot_2 | ✅ PASS |
| GSM deferred `_connect_signals` fires only after DCS exists | tests/integration/m0_boot_test.gd test_boot_3 | ✅ PASS |
| main.tscn instantiates | tests/integration/m0_boot_test.gd test_boot_4 | ✅ PASS |
| Foundation chain integration sanity (GameConfig→TraitDB→DCD→MTF + DCS↔GSM signals + sole input boundary) | production/qa/evidence/chain-probe-2026-08-18.log | ✅ PASS (exit 0) |
| Full suite green (regression) | production/qa/evidence/sprint1-full-suite-2026-08-18.log — **74/74 tests, 4810 asserts, exit 0** | ✅ PASS |

---

## Evidence pointers (files that prove this milestone)
- `production/qa/evidence/sprint1-full-suite-2026-08-18.log` — full GUT suite run 2026-08-18 (74/74, 4810 asserts, exit 0)
- `production/qa/evidence/chain-probe-2026-08-18.log` — integration sanity probe (PASS, exit 0)
- `tests/unit/m0_scaffold_test.gd` — SCAF-1..3 (structure)
- `tests/integration/m0_boot_test.gd` — BOOT-1..4 (boot chain)
- `tests/unit/core/game_enums_test.gd` — ENUM-1..5 (enums)
- `docs/architecture/adr-0001.md` … `adr-0004.md` — Accepted M0 foundation ADRs
- `src/autoload/*.gd` ×10 — ADR-0001 order in `project.godot [autoload]`

## Dates
- 2026-08-11 — foundation built (stories 1-3..1-6; commits f61bc47, 4805a59, f565469, + boot test)
- 2026-08-18 — regression re-verified (story 1-14; full suite + boot + probe)