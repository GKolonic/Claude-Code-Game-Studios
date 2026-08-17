# REG-3 Static Scan — GameConfig AC-6 (no hardcoded balance values)
**Date**: 2026-08-18
**Run by**: qa-lead (story 1-14)
**Engine**: Godot 4.6.stable.official.89cea1439 — headless, local WSL (QA plan OQ-B primary evidence)
**Method**: numeric-literal sweep of `src/gameplay/` + `src/core/` per QA plan OQ-E + control-manifest Forbidden rule (1-16)

## Scan scope
| Path | Exists | .gd files | Numeric-literal assignments (balance values) |
|------|--------|-----------|----------------------------------------------|
| `src/gameplay/` | **NO** — directory does not exist (architecture §7 has no `src/gameplay`; logic classes live in `src/systems/`) | 0 | n/a — nothing to scan |
| `src/core/` | YES | 1 (`game_enums.gd`) | **0** — no numeric assignments; enums use implicit 0..n values (not balance literals) |
| `src/systems/` (informational — logic-class dir per architecture §7) | YES | 0 (empty; no M1 code) | n/a |

Sweep pattern: `=\s*-?\d+(\.\d+)?\b` over every `.gd` in scope. Result: **0 findings**.

## Notes
- All M1 gameplay values are data-driven: GameConfig loads all 9 domains from `.tres` (GCF-2 field sweep asserts 50+ fields within declared min/max; GCF-8 asserts non-null typed domains). TraitDB/DialogueDB read catalogues only.
- MTF timing/layout constants (350ms tap, 600ms long press, 8dp slop, 40dp swipe, 44dp min target, etc.) live in `mobile_touch_framework.gd` as GDD Rule 15 constants — these are **input-framework tuning, not gameplay balance values**, and are pinned by the MTF GDD + ADR-0006. Recorded for the control-manifest (1-16) Forbidden-rule review so the exemption is explicit.
- Deferred by design: full sweep of `src/systems/` + `src/scenes/` becomes meaningful at M2/M5 when logic/UI code lands; control-manifest (1-16) carries the standing Forbidden rule.

## Verdict
GameConfig AC-6 covered by static scan → PASS (no violations). Evidence: this file + `sprint1-full-suite-2026-08-18.log` (GCF-2/GCF-8 green).