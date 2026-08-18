# Architecture Review Report — 2026-08-18 (M1 Scoped)

## Architecture Review Report

**Date**: 2026-08-18
**Engine**: Godot 4.6.stable.official.89cea1439 (headless, local WSL — QA plan OQ-B evidence)
**Mode**: `full` scoped to M1 systems (Foundation milestone completed 2026-08-18 per milestone-m1.md)
**GDDs Reviewed**: 4 (game-config, npc-trait-database, dialogue-content-database, mobile-touch-framework)
**ADRs Reviewed**: 6 (ADR-0001 … ADR-0006, all Accepted)
**Registry**: `docs/architecture/tr-registry.yaml` populated with **55 M1 TR IDs** (append-only — see git diff verification)
**Control manifest**: `docs/architecture/control-manifest.md` (manifest-2026.1) — cross-referenced for Forbidden-rule enforcement

> **Scope note**: Story 1-17 requires the M1 registry population + review. The remaining 10 MVP GDDs
> (NPC CS, CLE, GSM, DCS, RFS, Save&Load, P&E, Conversion UI, VMV, HUD) will be registered by the
> next `/architecture-review` run at M2/M3 gates per architecture.md §E ("append-only").

---

## Traceability Summary

| System | TR IDs | Total | ✅ Covered | ⚠️ Partial | ❌ Gaps |
|--------|--------|-------|-----------|------------|--------|
| Game Config | TR-GCF-001…012 | 12 | 11 | 1 | 0 |
| NPC Trait Database | TR-TDB-001…013 | 13 | 10 | 3 | 0 |
| Dialogue Content Database | TR-DCD-001…013 | 13 | 11 | 2 | 0 |
| Mobile Touch Framework | TR-MOV-001…017 | 17 | 17 | 0 | 0 |
| **Total** | | **55** | **49** | **6** | **0** |

**Verdict: CONCERNS** — no blocking gaps or conflicts for M1. All 6 ⚠️ items are
either deferred by design (M2/M4 milestone gates, already scheduled) or pending
decisions already on the sprint roadmap (1-18/1-20). See Coverage Gaps below.

---

## Traceability Matrix

### Game Config — `design/gdd/game-config.md` (TR-GCF-*)

| Req ID | Requirement (summary) | ADR(s) | Status |
|--------|-----------------------|--------|--------|
| TR-GCF-001 | Nine config domains, one `.tres` each (Rule 2/7; AC-1/10) | ADR-0002, ADR-0005 | ✅ |
| TR-GCF-002 | GameConfig LOADED before other Autoloads' `_ready()`; slot-1 order (EC-5; AC-1) | ADR-0001, ADR-0005 | ✅ |
| TR-GCF-003 | No hardcoded gameplay values in GDScript (Rule 1; AC-6) | ADR-0005 | ✅ |
| TR-GCF-004 | Pull pattern — call-time reads, never cache (Rule 3) | ADR-0005 | ✅ |
| TR-GCF-005 | Validate/clamp out-of-range with warning (Rule 6; AC-3) | ADR-0005 | ✅ |
| TR-GCF-006 | Missing file hard-halts naming path (EC-1; AC-5) | ADR-0005 | ✅ |
| TR-GCF-007 | Missing required field hard-halts naming field (EC-4; AC-4) | ADR-0005 | ✅ |
| TR-GCF-008 | Editor-only hot-reload + `config_reloaded`; no watcher in export (Rule 5; AC-7/8) | ADR-0005 | ✅ |
| TR-GCF-009 | Typed accessors return non-null in-range populated Resources (AC-2/10) | ADR-0005 | ✅ |
| TR-GCF-010 | Config never written to saves (AC-9) | ADR-0005 | ⚠️ Deferred to M4 by design (GC-9; QA plan GCF-DEF); registered active |
| TR-GCF-011 | Single-file authority; no override layers (Rule 7) | ADR-0005 | ✅ |
| TR-GCF-012 | GameConfig sole reader of config `.tres` (entities.yaml rule) | ADR-0002, ADR-0005 | ✅ |

### NPC Trait Database — `design/gdd/npc-trait-database.md` (TR-TDB-*)

| Req ID | Requirement (summary) | ADR(s) | Status |
|--------|-----------------------|--------|--------|
| TR-TDB-001 | Loads from `res://assets/data/traits/trait_database.tres`; `is_loaded()` (AC-1) | ADR-0002 | ✅ |
| TR-TDB-002 | Trait record structure incl. 4-key affinity + tags (Rule 1) | ADR-0002 | ✅ |
| TR-TDB-003 | `get_trait(id)` returns record or null (AC-2/7) | ADR-0002 | ✅ |
| TR-TDB-004 | `get_affinity` returns value or 0.0 for unknown (AC-9) | ADR-0002 | ✅ |
| TR-TDB-005 | Affinity modifier formula A(t,a) × W with config weight (Formulas) | ADR-0002, ADR-0005 | ✅ (formula owner CLE at M2) |
| TR-TDB-006 | Rarity-weighted draw-without-replacement assignment (Formulas; AC-4/5/6) | ADR-0005 (weights only) | ⚠️ **Needs ADR-0007 at M2** (determinism/RNG); verified locally at 1-11 as GDD-formula simulation |
| TR-TDB-007 | All 4 approach keys present; missing filled 0.0 + warning (EC-3) | ADR-0002 | ✅ (implemented 1-11 EC-3 normalisation) |
| TR-TDB-008 | Trait ID immutability + unknown_trait save fallback (EC-5) | — | ⚠️ **Needs ADR-0009 at M4** (save/load restore rules); catalogue-side deprecation documented in GDD |
| TR-TDB-009 | Rarity weight bands 60/30/10 simulation (AC-4) | ADR-0005 | ✅ (10,000-draw sim at 1-11) |
| TR-TDB-010 | No duplicate trait IDs per NPC (AC-5) | — | ⚠️ **Formula-level, ADR-0007 at M2**; verified by 1,000-NPC sim at 1-11 |
| TR-TDB-011 | Trait count ∈ [traits_per_npc_min, traits_per_npc_max] (AC-6) | ADR-0005 | ✅ (config-driven; verified 1-11; production owner NPC CS at M2) |
| TR-TDB-012 | All keys present with values ∈ [-1.0, 1.0] (AC-8) | ADR-0002 | ✅ |
| TR-TDB-013 | MVP catalogue 16 traits — 7/6/3 rarity split (Rule 2; AC-10/11) | ADR-0002 | ✅ |

### Dialogue Content Database — `design/gdd/dialogue-content-database.md` (TR-DCD-*)

| Req ID | Requirement (summary) | ADR(s) | Status |
|--------|-----------------------|--------|--------|
| TR-DCD-001 | Loads from `res://assets/data/dialogue/dialogue_database.tres`; `is_loaded()` (AC-1) | ADR-0002 | ✅ |
| TR-DCD-002 | V_total = 100 content-volume invariant (Formula; AC-2, R8) | ADR-0002 | ✅ (R8 audit helper at 1-12) |
| TR-DCD-003 | Approach pools: 3 lines × 4 approaches (AC-3) | ADR-0002 | ✅ |
| TR-DCD-004 | Outcome pools: 3 lines × 16 approach–outcome pairs (AC-4) | ADR-0002 | ✅ |
| TR-DCD-005 | NPC flavour: descriptor + 3 inspect lines × 7 archetypes (AC-5) | ADR-0002 | ✅ |
| TR-DCD-006 | Rival pools: 3 lines × 4 approaches (AC-6) | ADR-0002 | ✅ |
| TR-DCD-007 | Invalid enum inputs → empty/null, no crash (AC-7/8/9) | ADR-0002 | ✅ |
| TR-DCD-008 | Under-filled slot → warning + `is_loaded()` false (EC-1; AC-10) | ADR-0002 | ✅ (fixtures per QA plan OQ-D) |
| TR-DCD-009 | Safe returns when not loaded (AC-11) | ADR-0002 | ✅ |
| TR-DCD-010 | Empty short_descriptor → warning + struct returned (EC-2; AC-12) | ADR-0002 | ✅ |
| TR-DCD-011 | `get_npc_flavour()` returns copy, never shared ref (EC-6; AC-13) | ADR-0002 | ✅ (defensive copies) |
| TR-DCD-012 | All L_* > recency window W (W=2 ⇒ ≥3) (Cross-system constraint) | — | ⚠️ **Enforcement lands with DCS at M3 (ADR-0008)**; invariant documented + registered |
| TR-DCD-013 | `schema_version` field on database resource (OQ-1 recommended) | — | ⚠️ **Pending authoring-format decision (story 1-20)**; recommendation recorded |

### Mobile Touch Framework — `design/gdd/mobile-touch-framework.md` (TR-MOV-*)

| Req ID | Requirement (summary) | ADR(s) | Status |
|--------|-----------------------|--------|--------|
| TR-MOV-001 | Sole input boundary; `_input()` not `_unhandled_input()` (Rule 1) | ADR-0006 | ✅ (MTF-15 static scan) |
| TR-MOV-002 | No UI reads `Input`; MTF only caller of `set_input_as_handled()` | ADR-0003, ADR-0006 | ✅ |
| TR-MOV-003 | Single-finger only; non-zero finger index discarded (Rule 2; EC-1) | ADR-0006 | ✅ |
| TR-MOV-004 | Tap ≤350ms/≤8dp, hit-tested, haptic 80ms (Rule 3/12; AC-1/2) | ADR-0006 | ✅ |
| TR-MOV-005 | Long press ≥600ms fires on threshold (Rule 8; AC-4) | ADR-0006 | ✅ |
| TR-MOV-006 | Dead band 350–600ms silent (Rule 4; AC-5) | ADR-0006 | ✅ |
| TR-MOV-007 | Swipe ≥40dp + ≥150dp/s, 45° sectors (Rules 3/7; F-3/F-4; AC-6/7) | ADR-0006 | ✅ |
| TR-MOV-008 | 44×44dp floor, center-anchored inflation (Rule 5; F-2; AC-3) | ADR-0006 | ✅ |
| TR-MOV-009 | dp conversion owned by MTF; 160-DPI fallback (Rules 5/11; F-1; AC-12/13) | ADR-0006 | ✅ |
| TR-MOV-010 | Blocking-layer priority stack; Conversion UI only owner (Rule 9; AC-9) | ADR-0003, ADR-0006 | ✅ (MTF-9) |
| TR-MOV-011 | Gesture timeout 800ms → `touch_cancelled` (Rule 14; AC-10) | ADR-0006 | ✅ |
| TR-MOV-012 | Debounce 100ms ±10dp (Rule 13; F-5; AC-11) | ADR-0006 | ✅ |
| TR-MOV-013 | `set_input_as_handled()` only when consumed (Rule 1; R3) | ADR-0006 | ✅ (MTF-16) |
| TR-MOV-014 | No framework visual feedback in release builds (Rule 12/14; AC-14) | ADR-0006 | ✅ (automated assert; manual Android export spot-check OQ-C at M7) |
| TR-MOV-015 | Haptic tap-only 80ms (Rule 12) | ADR-0006 | ✅ |
| TR-MOV-016 | 15 Rule-15 constants compile-time, non-overridable (Rule 15) | ADR-0006 | ✅ |
| TR-MOV-017 | Event-driven hit-testing; ≤32 registered areas (Rule 10; EC-10) | ADR-0006 | ✅ |

---

## Coverage Gaps (no ADR exists / partial)

No ❌ GAP in M1 scope. Partial coverage (all scheduled):

1. **⚠️ TR-TDB-006 / TR-TDB-010** (trait assignment formula + no-duplicates) — ADR-0007 (Determinism & RNG strategy) is milestone-gated for **M2**. Verified at 1-11 only as local GDD-formula simulations (10,000/1,000 runs). Suggested ADR: `/architecture-decision "Determinism & RNG strategy"` at M2; production formula owner = NPC Character System.
2. **⚠️ TR-TDB-008** (unknown_trait save fallback) — save/load restore rules land with ADR-0009 at **M4**.
3. **⚠️ TR-DCD-012** (recency window L_* > W) — enforced by DCS recency selection at **M3** (ADR-0008).
4. **⚠️ TR-DCD-013** (schema_version) — pending Dialogue authoring-format decision (**story 1-20**); recommendation from DCD OQ-1.
5. **⚠️ TR-GCF-010** (config never in saves) — deferred to M4 **by design** (QA plan GCF-DEF; AC-9 tracked in coverage matrix).

## Cross-ADR Conflicts

**None detected** among ADR-0001…0006.

Document-level drifts surfaced (not ADR-vs-ADR conflicts — recorded for awareness):

| Finding | Type | Status |
|---------|------|--------|
| `architecture.md` §4.3 ConversionConfig field set differs from game-config.md range table (`trait_modifier_cap`, `min_success_chance`, belief modifiers, band fractions, repeat penalties appear only in §4.3) | Doc drift | ADR-0005 Decision 3 records GDD table as authoritative; **reconcile at next balance review** — flagged, not edited |
| MTF GDD Rule 1 wording: "listed first … to guarantee input processing priority" is inaccurate (engine: `_input()` reverse scene order) | GDD↔ADR | ADR-0006 amends; **one-line GDD wording update flagged** for the 1-18 consistency window |
| RivalFaithConfig `aggression_interval_turns` 6 (game-config, authoritative) vs 3 (RFS GDD) | GDD↔GDD | Known **R2** — scheduled for Creative Director ruling at **story 1-18** (not touched here) |

## ADR Dependency Order

Accepted set (topologically sorted — confirms implementation order used by M1):

```
1. ADR-0001  Autoload architecture & init order        (no deps)
2. ADR-0002  Data resource model                      (needs 0001)
3. ADR-0003  Signal architecture & communication      (needs 0001)
4. ADR-0004  Scene ownership & CanvasLayer stack       (needs 0001)
5. ADR-0005  Config system                            (needs 0001, 0002)
6. ADR-0006  Input architecture                       (needs 0001, 0003, 0004, 0005)
```

Unresolved dependencies: **none** — all six are Accepted; M1 stories that reference them were correctly unblocked.

Future milestone-gated ADRs (already planned in architecture.md Appendix B — register requirements now, satisfy later):
- **M2**: ADR-0007 (Determinism & RNG) — covers TR-TDB-006/010
- **M3**: ADR-0008 (Turn sequence contract) — covers TR-DCD-012, GSM/RFS/DCS TRs
- **M4**: ADR-0009 (Save format & restore) — covers TR-GCF-010 verification path, TR-TDB-008
- **M5/M6**: ADR-0010 (Portrait pipeline), ADR-0011 (Safe-area & mobile perf)

## GDD Revision Flags (Architecture → Design Feedback)

| GDD | Assumption | Reality (from ADR/engine-reference) | Action |
|-----|-----------|--------------------------------------|--------|
| mobile-touch-framework.md Rule 1 | "Listed first in Project Settings → Autoloads to guarantee input processing priority" | Godot `_input()` propagates in **reverse scene order** — slot 4 does not give raw priority; fixed by registry hit-test + consume-only handled-mark (ADR-0006 Decision 4) | One-line wording update in next consistency pass (1-18 window) |
| mobile-touch-framework.md Dependencies | "Godot 4.5's Recursive Control disable" | Verified available on 4.6 (used by blocking layers, MTF-9) | No change needed — wording only |

No other GDD revision flags — all remaining M1 GDD assumptions are consistent with verified engine behaviour.

## Engine Compatibility Issues

**Engine audit: PASS (6/6 ADRs have Engine Compatibility sections; no deprecated APIs referenced; no stale versions).**

| Check | Result |
|-------|--------|
| ADRs with Engine Compatibility section | 6 / 6 |
| Deprecated API references in ADRs | None |
| Stale engine-version references | None (all 4.6) |
| Post-cutoff API conflicts between ADRs | None |
| Verified post-cutoff behaviours | `DisplayServer.get_display_safe_area() -> Rect2i` (no params, task 1-2 probe); `InputEventScreenTouch/Drag.index` (no `finger_index` — found at 1-13); recursive Control disable on 4.6 (1-13); `_input()` reverse-scene-order (1-9/1-13) |

**Engine specialist consultation**: skipped. All M1 engine facts were verified by runtime probes during this sprint (tasks 1-2 and 1-13) — stronger evidence than a consult; no open engine questions remain in M1 scope.

## Architecture Document Coverage (Phase 6)

- All 4 M1 systems appear in `docs/architecture/architecture.md` §1.1 with correct layer assignment (Foundation) and §3.2 interfaces.
- §5 signal inventory covers all M1 signals (MTF, GameConfig `config_reloaded`); DCD has no signals (correct — stateless registry).
- No orphaned M1 architecture (every M1 design element traces to a GDD or ADR).
- Control manifest (story 1-16) now encodes the Programmer-rules surface (Required/Forbidden/Guardrails) extracted from the same ADRs → consistent with this matrix.

## Story / Milestone Linkage (RTM note)

- Story FILES (`production/stories/sprint-1/`) do not exist — pre-existing gap recorded at 1-15 (sprint-status.yaml references files `/dev-story` never created; flagged for Goran).
- TR-ID references for M1 are embedded in **`production/milestones/milestone-m1.md`** (this batch, story 1-17) — the surviving M1 record — covering stories 1-8…1-15.
- Verifying test files: `tests/unit/game_config/*` (12), `tests/unit/trait_database/*` (11), `tests/unit/dialogue_database/*` (15), `tests/unit/mobile_touch_framework/*` (24) + integration boot/chain probes — see milestone-m1.md.

---

## Verdict: CONCERNS

No **blocking** issues for M1: zero ❌ gaps, zero cross-ADR conflicts, engine audit PASS,
architecture doc coverage complete. CONCERNS reflects the six ⚠️ items — all already
scheduled on the roadmap (M2 ADR-0007, M3 ADR-0008, M4 ADR-0009, stories 1-18/1-20,
next balance review) or deferred by design (GCF-010).

### Blocking Issues (must resolve before PASS)
None for M1. For full-project PASS the future gates must satisfy: **M2** ADR-0007 (TR-TDB-006/010),
**M3** ADR-0008 (TR-DCD-012 + turn/session TRs), **M4** ADR-0009 (TR-GCF-010, TR-TDB-008).

### Required ADRs (prioritised, most foundational first)
1. ADR-0007 — Determinism & RNG strategy (M2 gate; resolves TR-TDB-006/010) — `/architecture-decision`
2. ADR-0008 — Turn sequence contract (M3 gate; resolves TR-DCD-012) — `/architecture-decision`
3. ADR-0009 — Save format & restoration rules (M4 gate; resolves TR-GCF-010, TR-TDB-008) — `/architecture-decision`

## Handoff

1. **Immediate actions**: none blocking within Sprint 1. Next review-run trigger: M2, when ADR-0007 is written and NPC CS/CLE GDDs enter implementation (`/architecture-review` appends TR-NPC-* / TR-CLE-* / TR-GSM-* families).
2. **Gate guidance**: re-run `/architecture-review` after each new ADR to verify coverage improves; `/gate-check pre-production` is independent and already passed (2026-08-11).
3. **Goran (Creative Director) decision items surfaced by this review**:
   - Story files for Sprint 1 still absent — TR references live in milestone-m1.md instead (pre-existing).
   - MTF GDD Rule 1 wording update (1-18 window).
   - R2 `aggression_interval_turns` ruling (story 1-18) — untouched here.
   - DCD schema_version + authoring-format decision (story 1-20) — TR-DCD-013 registered pending that ruling.