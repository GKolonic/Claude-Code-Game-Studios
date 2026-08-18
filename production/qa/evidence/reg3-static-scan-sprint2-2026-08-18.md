# REG-3 Static Scan — Sprint 2 refresh (QA plan REG-3; AC-6 no-hardcoded-balance-values)
**Date**: 2026-08-18
**Run by**: qa-lead (story 2-8)
**Engine**: Godot 4.6.stable.official.89cea1439 — headless, local WSL (QA plan OQ-B primary evidence)
**Method**: numeric-literal sweep of `src/gameplay/` + `src/core/` (Sprint 1 pattern, QA plan OQ-E) + M2 RNG-usage scan per ADR-0007 Decision 2 guardrail + new scan of `src/systems/` and `src/autoload/` (M2 logic lands)

## Scan scope
| Path | Exists | .gd files | Numeric-literal assignments (gameplay balance values) | RNG usage (randf/randi/RandomNumberGenerator) |
|------|--------|-----------|----------------------------------------------|------------------------------------------------|
| `src/gameplay/` | **NO** — directory does not exist (architecture §7 has no `src/gameplay`; logic classes live in `src/systems/`) | 0 | n/a — nothing to scan | n/a |
| `src/core/` | YES | 1 (`game_enums.gd`) | **0** — no numeric assignments; enums use implicit 0..n values | 0 |
| `src/systems/` (logic-class dir, architecture §7) | YES | 1 (`npc_rng/rng_helpers.gd` — NEW at 2-5) | **0 gameplay values** — only math guards (0.0/1.0 clamps, normalization) | **SOLE direct RNG user** — `make_seeded`, `randi_range`, `randf` live here and ONLY here (ADR-0007 Decision 2) |
| `src/autoload/` (M2: npc_registry.gd, conversion_logic_engine.gd + existing) | YES | 9 + 1 autoload stub (`faith_spread_system.gd` no-op) | **0 gameplay balance values** — see categorized hits below | **0 direct calls** — the 3 `RandomNumberGenerator` tokens are typed signature annotations only (ADR-0007 caller-threaded RNG: `NPCRegistry._generate_npc`/`_assign_traits`, `ConversionLogicEngine.resolve`) |

## RNG usage scan (ADR-0007 guardrail / control-manifest Forbidden rule)
`grep -rn "\.randf(\|\.randi(\|\.randi_range(\|RandomNumberGenerator\.new()" src --include="*.gd" | grep -v rng_helpers.gd` → **0 matches outside `src/systems/npc/rng_helpers.gd`** (grep exit 1 = clean). The three `RandomNumberGenerator` identifiers found elsewhere are function-parameter type annotations threading a caller-owned instance (NPCRegistry generation RNG per `initialize_village()`, CLE per-`resolve()` RNG) — no construction, no calls, no state stored on Autoloads (ADR-0007 purity). **PASS.**

## Numeric-literal sweep — categorized hits (all sanctioned or non-balance)
Sweep pattern: `=\s*-?\d+(\.\d+)?` over every `.gd` in scope. **0 gameplay balance values.** Every hit falls into one of four sanctioned/non-balance classes:

1. **Framework/tuning constants (sanctioned Sprint 1, ADR-0006)**: `mobile_touch_framework.gd` — gesture timing/dimension constants (TAP_MAX_DURATION_MS 350, LONG_PRESS 600, SWIPE 40dp/150dp/s, 44dp floor, debounce 100ms, timeout 800ms, state enum 0..4, pixels_per_dp 1.0). These are **input-framework tuning, not gameplay balance values** (recorded in the Sprint 1 control-manifest exemption).
2. **Content/structure rules from GDDs (not balance)**: `dialogue_database.gd` `MIN_LINES_PER_SLOT := 3` (DCD R8 content-audit threshold), `npc_registry.gd` `SERIALIZE_VERSION := 1`, `save_load_system.gd` `SAVE_VERSION_CURRENT := 1` (schema versions, not tuning).
3. **Counters / zero-init / sentinels**: accumulator `+= 1`, `total := 0.0`, `best_abs := -1.0` reveal-scoring seeds, `best_count := 1 << 30` fewest-gate sentinel, `p_remaining := 1.0 - p_final` formula math.
4. **Validation comparisons**: `>= 0 and < GameEnums.X.size()` enum-range guards; `parts.size() != 3` id-format shape check (NPC CS Rule 1).

**Schema defaults in `src/resources/config/`** (conversion_config.gd + 8 siblings): min/max/default values for every GameConfig field — **sanctioned GDD defaults** (ADR-0005 Decision 4: config schema is the data authority, not gameplay hardcode). The CLE and NPCRegistry read ALL tuning from `GameConfig.*` at call time (ADR-0005 pull pattern; CLE AC-8.4 proves no caching) — no duplicate literals in logic.

## Notes
- New since Sprint 1: `src/systems/` is no longer empty — `npc_rng/rng_helpers.gd` (2-5) is the single owned RNG abstraction per ADR-0007 Decision 2. Confirmed as the ONLY direct RNG user; the `RandomNumberGenerator` token appears in `npc_registry.gd` + `conversion_logic_engine.gd` exclusively as the mandated AC-8.1/ADR-0007 signature annotation (same precedent as the 2-7 record).
- `src/autoload/faith_spread_system.gd` remains the M3 no-op stub (decision #10 / OQ-3) — no numeric literals.
- Deferred by design: full sweep of `src/scenes/` becomes meaningful at M5 when UI code lands; control-manifest (1-16) carries the standing Forbidden rule.

## Verdict
REG-3 → **PASS** (no violations).
- src/gameplay absent (architecture §7) ✓
- src/core clean (0 numeric assignments) ✓
- src/systems rng_helpers.gd is the ONLY direct RNG user (no randf/randi/RandomNumberGenerator.new outside it) ✓
- Sweep flags only sanctioned schema defaults (src/resources/config) and framework constants ✓
Evidence: this file + `sprint2-full-suite-2026-08-18.log` (204/204 green; GCF-2/GCF-8 field sweep green in-suite).