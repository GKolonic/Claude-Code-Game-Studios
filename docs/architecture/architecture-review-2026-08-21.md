# Architecture Review Report — 2026-08-21 (M2 Scoped)

## Architecture Review Report

**Date**: 2026-08-21
**Engine**: Godot 4.6.stable.official.89cea1439 (headless, local WSL — QA plan OQ-B evidence)
**Mode**: `full` scoped to M2 systems (Core data & math milestone REACHED 2026-08-18 per milestone-m2.md)
**GDDs Reviewed**: 2 (npc-character-system, conversion-logic-engine)
**ADRs Reviewed**: 7 (ADR-0001 … ADR-0007, all Accepted)
**Registry**: `docs/architecture/tr-registry.yaml` — **132→133 total IDs; 77 NEW M2 IDs appended** (TR-NPC-001…031 = 31, TR-CLE-001…046 = 46; append-only — see git diff verification; version kept 1)
**Control manifest**: `docs/architecture/control-manifest.md` (manifest-2026.1) — cross-referenced for Forbidden-rule enforcement

> **Scope note**: Story 2-10 (mirrors 1-17) requires the M2 registry append + this review. The remaining MVP GDDs
> (GSM, DCS, RFS, Save&Load, P&E, Conversion UI, VMV, HUD) are registered by the next `/architecture-review` run
> at the M3 gate per architecture.md §E ("append-only"). The 1-17 review's six M1 partials are dispositioned under
> "Partial-TR Status Changes" below — two now resolved (by M2), the rest remain scheduled at their milestone gates.

---

## Traceability Summary (M2 Scope)

| System | TR IDs | Total | ✅ Covered | ⚠️ Partial | ❌ Gaps |
|--------|--------|-------|-----------|------------|--------|
| NPC Character System | TR-NPC-001…031 | 31 | 31 | 0 | 0 |
| Conversion Logic Engine | TR-CLE-001…046 | 46 | 46 | 0 | 0 |
| **Total (M2)** | | **77** | **77** | **0** | **0** |

**Verdict: PASS (M2 scope)** — 77/77 registered M2 requirements are covered by passing tests
(full suite 204/204, 22711 asserts, exit 0 — 2-8 REG-1). Zero ❌ gaps, zero cross-ADR conflicts within M2 scope.
Two documented findings are balance/handling findings tracked for the Creative Director, not architecture gaps — see
"Cross-ADR Conflicts" and milestone-m2.md reconciliation.

> **Registry totals (all families, cross-milestone)**: GCF 12 · TDB 13 · DCD 14 · MOV 17 · NPC 31 · CLE 46 = **133**.
> Pre-2-10 registry was 56 (55 M1 + TR-DCD-014 registered at story 1-20). This run added exactly +77, all at the
> end of the new families' lists, no renumbering — verified via `git diff HEAD~2 HEAD -- docs/architecture/tr-registry.yaml`
> showing `grep -c "^-" == 0` (additions only).

---

## Traceability Matrix

### NPC Character System — `design/gdd/npc-character-system.md` (TR-NPC-*)

| Req ID | Requirement (summary) | ADR(s) | Status |
|--------|-----------------------|--------|--------|
| TR-NPC-001 | `initialize_village()` same-`rng_seed` → byte-identical NpcRecord arrays (AC-1) | ADR-0007, ADR-0002 | ✅ |
| TR-NPC-002 | Fresh-init clean state (STEADFAST, cooldown 0, count 0, hidden traits) (AC-2) | — | ✅ |
| TR-NPC-003 | `assigned_traits` all resolve in TraitDatabase + archetype-tag valid (AC-3) | ADR-0002 | ✅ |
| TR-NPC-004 | Archetype trait bias: Widow `bereaved` > Soldier across 100 seeds (AC-4) | ADR-0007 | ✅ |
| TR-NPC-005 | PERSUADED linear progression STEADFAST→OPEN→WAVERING→CONVERTED (AC-5) | — | ✅ |
| TR-NPC-006 | HARDENED on STEADFAST is a belief no-op — floor holds (AC-6) | — | ✅ |
| TR-NPC-007 | Outcome on CONVERTED is terminal; no `npc_state_changed` (AC-7) | — | ✅ |
| TR-NPC-008 | Non-no-op → cooldown + approach_count update (AC-8) | ADR-0005 | ✅ |
| TR-NPC-009 | `advance_turn()` ticks cooldown/grace floors (AC-9) | — | ✅ |
| TR-NPC-010 | Cooldown gate excludes from `get_approachable_npcs()` (AC-10) | ADR-0003 | ✅ |
| TR-NPC-011 | max-approaches gate excludes (AC-11) | ADR-0005 | ✅ |
| TR-NPC-012 | Access gate until required NPCs reach state (AC-12) | — | ✅ |
| TR-NPC-013 | Inspect reveals highest-absolute-affinity hidden trait (AC-13) | — | ✅ |
| TR-NPC-014 | Dialogue reveals approach-X highest-affinity trait (AC-14) | — | ✅ |
| TR-NPC-015 | Reveal on full reveal is no-op; no signal (AC-15; OQ-8) | ADR-0007 | ✅ |
| TR-NPC-016 | `npc_state_changed` exactly-once semantics (AC-16) | ADR-0003 | ✅ |
| TR-NPC-017 | `npc_cooldown_expired` exactly-once on the tick reaching 0 (AC-17) | ADR-0003 | ✅ |
| TR-NPC-018 | serialize→clear→deserialize round-trip identical (AC-18) | ADR-0002 | ✅ |
| TR-NPC-019 | Unknown BeliefState loads STEADFAST, no crash (AC-19) | ADR-0002 | ✅ |
| TR-NPC-020 | Duplicate `npc_id` → exactly one record + warning (AC-20) | — | ✅ |
| TR-NPC-021 | All-gated village → exactly one gate cleared + error (AC-21) | — | ✅ |
| TR-NPC-022 | Invalid gate ref cleared to null; immediate approachable (E2) | — | ✅ |
| TR-NPC-023 | Invalid connection ref dropped; others intact (E3) | — | ✅ |
| TR-NPC-024 | Unknown RelationshipType dropped on load (E4) | — | ✅ |
| TR-NPC-025 | RIVAL grace-window regression CONVERTED→WAVERING (E6, Rule 5) | ADR-0007 | ✅ |
| TR-NPC-026 | Village exhaustion → empty approachable list (E7) | — | ✅ |
| TR-NPC-027 | Mutation API does not enforce gates (E9) | — | ✅ |
| TR-NPC-028 | `trigger_inspect_reveal` on empty traits → error no-op (E11) | — | ✅ |
| TR-NPC-029 | Simultaneous RIVAL conversion both CONVERTED (E12) | — | ✅ |
| TR-NPC-030 | `clear_village` discards cooldowns, no retained refs (E13) | — | ✅ |
| TR-NPC-031 | `get_npc` unregistered → null (E14) | — | ✅ |

**Verifying tests**: `tests/unit/npc_registry/npc_registry_test.gd` (42 tests, AC-1..21 + E1-E14), `tests/integration/npc_registry/village_lifecycle_test.gd` (7 tests, real village_01), `tests/integration/m2/m2_integration_chain_test.gd` (resolve→apply). Coverage per 2-8 REG-2 matrix: 35/35 NPC rows mapped.

### Conversion Logic Engine — `design/gdd/conversion-logic-engine.md` (TR-CLE-*)

| Req ID | Requirement (summary) | ADR(s) | Status |
|--------|-----------------------|--------|--------|
| TR-CLE-001 | `resolve()` deterministic under same seed/state (AC-1.1) | ADR-0007 | ✅ |
| TR-CLE-002 | `resolve()` writes no NPC state (pure) (AC-1.2) | ADR-0007 | ✅ |
| TR-CLE-003 | `resolve()` no GameConfig side effects (AC-1.3) | ADR-0005 | ✅ |
| TR-CLE-004 | F1 single +1.0 trait → +0.25 (AC-2.1) | — | ✅ |
| TR-CLE-005 | F1 two +1.0 traits → +0.50, no clamp (AC-2.2) | — | ✅ |
| TR-CLE-006 | F1 four +1.0 traits → +0.50 clamped (AC-2.3) | — | ✅ |
| TR-CLE-007 | F1 four −1.0 traits → −0.50 (AC-2.4) | — | ✅ |
| TR-CLE-008 | F1 zero affinities → 0.0 (AC-2.5) | — | ✅ |
| TR-CLE-009 | F1 empty trait list → 0.0, no error (EC-6; AC-2.6) | — | ✅ |
| TR-CLE-010 | F1 Widow/GRIEF worked example → +0.50 (AC-2.7) | — | ✅ |
| TR-CLE-011 | F2 STEADFAST → 0.0 (AC-3.1) | — | ✅ |
| TR-CLE-012 | F2 OPEN → +0.10 (AC-3.2) | ADR-0005 | ✅ |
| TR-CLE-013 | F2 WAVERING → +0.20 (AC-3.3) | ADR-0005 | ✅ |
| TR-CLE-014 | F2 CONVERTED → 0.0 + warning (EC-4; AC-3.4) | — | ✅ |
| TR-CLE-015 | F3 first use → 0.0 (AC-4.1) | — | ✅ |
| TR-CLE-016 | F3 second use → 0.05 (AC-4.2) | — | ✅ |
| TR-CLE-017 | F3 third use → 0.15 cap (AC-4.3) | — | ✅ |
| TR-CLE-018 | F3 cap holds beyond third use (AC-4.4) | — | ✅ |
| TR-CLE-019 | F3 weight 0.0 → 0.0 always (AC-4.5) | — | ✅ |
| TR-CLE-020 | F4 neutral baseline → P_final 0.35 (AC-5.1) | — | ✅ |
| TR-CLE-021 | F4 floor enforced 0.05 (AC-5.2) | ADR-0005 | ✅ |
| TR-CLE-022 | F4 ceiling enforced 0.80 (AC-5.3) | ADR-0005 | ✅ |
| TR-CLE-023 | F4 max theoretical P_raw 1.05 → 0.80 (AC-5.4; EC-12) | ADR-0005 | ✅ |
| TR-CLE-024 | F4 min theoretical P_raw −0.30 → 0.05 (AC-5.5) | ADR-0005 | ✅ |
| TR-CLE-025 | F4 four components sum within ±0.0001 (AC-5.6) | — | ✅ |
| TR-CLE-026 | F5 P_final 0.60, roll 0.50 → PERSUADED (AC-6.1) | ADR-0007 | ✅ |
| TR-CLE-027 | F5 SOFTENED zone (AC-6.2) | ADR-0007 | ✅ |
| TR-CLE-028 | F5 RESISTED zone (AC-6.3) | ADR-0007 | ✅ |
| TR-CLE-029 | F5 HARDENED reachable at floor (AC-6.4) | ADR-0007 | ✅ |
| TR-CLE-030 | F5 HARDENED impossible at ceiling, 1000 rolls (AC-6.5) | ADR-0007 | ✅ |
| TR-CLE-031 | F5 strict-`<` boundary, roll == P_final → SOFTENED (AC-6.6; EC-10) | ADR-0007 | ✅ |
| TR-CLE-032 | F5 all four outcomes, 10k-roll ±3% bands (AC-6.7) | ADR-0007 | ✅ |
| TR-CLE-033 | EC-1 negative HARDENED zone floored to 0.0 (AC-7.1) | — | ✅ |
| TR-CLE-034 | EC-2 bands >1.0 → clamp + valid outcome (AC-7.2) | ADR-0005 | ✅ |
| TR-CLE-035 | EC-3 unknown NPC → RESISTED sentinel (AC-7.3) | — | ✅ |
| TR-CLE-036 | EC-5 null config field → RESISTED (AC-7.4) | ADR-0005 | ✅ |
| TR-CLE-037 | EC-9 invalid approach → RESISTED (AC-7.5) | — | ✅ |
| TR-CLE-038 | EC-10 boundary ownership strict-`<` (AC-7.6) | ADR-0007 | ✅ |
| TR-CLE-039 | `resolve` signature compiles; threaded RNG arg (AC-8.1) | ADR-0007 | ✅ |
| TR-CLE-040 | Autoload availability, no imports (AC-8.2) | ADR-0001 | ✅ |
| TR-CLE-041 | Both DCS- and RFS-shaped stubs call it, no leakage (AC-8.3) | ADR-0001 | ✅ |
| TR-CLE-042 | Config read-at-call-time (mutation changes P_final) (AC-8.4) | ADR-0005 | ✅ |
| TR-CLE-043 | EC-7 `trait_modifier_weight`=0 valid, no warning | — | ✅ |
| TR-CLE-044 | EC-8 stateless; caller applies in finally-equivalent block (R9) | ADR-0007 | ✅ |
| TR-CLE-045 | EC-11 RESISTED sole no-benefit outcome | — | ✅ |
| TR-CLE-046 | EC-13 reset-to-farm bounded by max_approaches | — | ✅ |

**Verifying tests**: `tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd` (43 tests, AC-1.1..8.4 + EC-1..13), caller stubs `stub_dcs_shaped.gd` / `stub_rfs_shaped.gd` (AC-8.3), `tests/integration/m2/m2_integration_chain_test.gd` (M2-INT-1 resolve→apply pair contract for TR-CLE-044/EC-8). Coverage per 2-8 REG-2 matrix: 42/42 CLE rows mapped.

---

## Coverage Gaps & Partial-TR Status Changes

No ❌ GAP in M2 scope — 0 unmapped requirements (2-8 REG-2 confirmed 77/77; the only unmapped items are by-design deferrals, listed below, none of which are new TRs in this scope).

### M1 partials dispositioned this run

The six ⚠️ partial requirements from the 2026-08-18 (M1) review:

| M1 TR | 2026-08-18 status | Today |
|-------|-------------------|-------|
| **TR-TDB-006** (rarity-weighted draw-without-replacement assignment; AC-4/5/6) | ⚠️ Needs ADR-0007 at M2 | ✅ **RESOLVED** — ADR-0007 Decision 7; implemented in `src/systems/npc/rng_helpers.gd` (2-5 `weighted_random_choice` + pool erase) and `NPCRegistry.initialize_village()` (2-6 AC-1/AC-4/AC-5). Registry status stays `active`; closure is recorded here per the 2-10 contract. |
| **TR-TDB-010** (no duplicate trait IDs per NPC; AC-5) | ⚠️ ADR-0007 at M2 | ✅ **RESOLVED** — structural draw-without-replacement guarantee in `rng_helpers.gd` (2-5 RG-4 no-duplicates) + `NPCRegistry` (2-6 AC-5, AC-1 determinism). |
| **TR-GCF-010** (config never in saves; AC-9) | ⚠️ Deferred to M4 by design | Scheduled — **NOT resolved** (M4 by design, QA plan GCF-DEF; infrastructure absent until Save/Load) |
| **TR-TDB-008** (trait-ID immutability + unknown_trait save fallback; EC-5) | ⚠️ ADR-0009 at M4 | Scheduled — **NOT resolved** (ADR-0009 at M4) |
| **TR-DCD-012** (recency window L_* > W) | ⚠️ ADR-0008 at M3 | Scheduled — **NOT resolved** (ADR-0008 at M3) |
| **TR-DCD-013** (schema_version on database resource; OQ-1) | ⚠️ Pending story 1-20 | Resolved by **1-20** (ADR-0005 Addendum 1 — authoring pipeline emits `schema_version`); delivered in M1 batch, tracked here for completeness (not an M2 change) |

No registry status fields were flipped — `resolved` is not a registry STATUS value (registry: `active | deprecated | superseded-by`), and every ID remains `active` (permanent). TR-TDB-006/010 resolution is recorded in the review's partial-TR table + milestone-m2.md, matching ADR-0007 Decision 7's instruction that closure lands "at 2-10 (M2-scoped architecture review) once the acceptance tests pass."

### M2 by-design deferrals (not gaps; none are new TRs)

- **TR-CLE-044 / EC-8 real-caller wiring** — the DCS finally-block discipline (calling `apply_conversion_outcome()` after every `resolve()`) is enforced at M3 by the Dialogue & Conversion System (R9). M2 proves the pair contract via M2-INT-1 stubs; the real-caller guard lands at M3.
- **NPC UI/presentation** (portrait expression sets, cooldown/gate indicators, trait cards) — M5 (UI ACLs); the NPC CS exposes the required state (portrait_asset_path contract validated at 2-3/2-4).
- **Android export spot-check** — M7 (QA plan OQ-C).
- **GameConfig AC-9 / TR-GCF-010** — M4 (carried from M1).

## Cross-ADR Conflicts

**None among ADR-0001…0007** within M2 scope. No ADR-vs-ADR conflict detected. The engine/implementation findings below are documented balance/handling items (already flagged to the Creative Director at 2-7/2-9) — **not** architecture gaps and **not** silently changed:

| Finding | Type | Status |
|---------|------|--------|
| CLE HARDENED-zone imbalance: shipped defaults `softened_band_fraction 0.545 + resisted_band_fraction 0.455 = 1.0` make the HARDENED zone mathematically empty at every P_final; GDD drama-space table + AC-6.4/6.7 assume fractions summing < 1.0. Formula implemented exactly per GDD Formula 5 | Balance/tuning | Flagged to Creative Director at 2-7/2-9; tests requiring a non-empty HARDENED zone set documented adjusted effective bands. NOT changed here. |
| Config deviation #2-6-D1: `grace_window_turns` (2, 0–5) added to RivalFaithConfig schema + .tres + game-config.md authoritative table (existing NPC Rule 5 grace-window behaviour) | Config addition | Documented, kept + flagged at 2-6. |

## ADR Dependency Order

Accepted set (topologically sorted — confirms the implementation order used by M2):

```
1. ADR-0001  Autoload architecture & init order      (no deps)
2. ADR-0002  Data resource model                     (needs 0001)
3. ADR-0003  Signal architecture & communication     (needs 0001)
4. ADR-0004  Scene ownership & CanvasLayer stack      (needs 0001)
5. ADR-0005  Config system                           (needs 0001, 0002)
6. ADR-0006  Input architecture                       (needs 0001, 0003, 0004, 0005)
7. ADR-0007  Determinism & RNG strategy              (needs 0001, 0002, 0005)  [M2]
```

Unresolved dependencies: **none** — all seven are Accepted; M2 stories (2-5..2-7) that reference ADR-0007 were correctly unblocked.

Future milestone-gated ADRs (already planned in architecture.md Appendix B — register requirements now, satisfy later):
- **M3**: ADR-0008 (Turn sequence contract) — covers TR-DCD-012, GSM/RFS/DCS TRs, TR-CLE-044 real-caller discipline
- **M4**: ADR-0009 (Save format & restore) — covers TR-GCF-010, TR-TDB-008
- **M5/M6**: ADR-0010 (Portrait pipeline), ADR-0011 (Safe-area & mobile perf)

## GDD Revision Flags (Architecture → Design Feedback)

| GDD | Assumption | Reality (from ADR/engine-reference) | Action |
|-----|-----------|--------------------------------------|--------|
| conversion-logic-engine.md Formula 5 | Drama-space table + AC-6.4/6.7 assume SOFTENED+RESISTED fractions sum < 1.0 (non-empty HARDENED zone) | Shipped defaults 0.545+0.455 = 1.0 empty the HARDENED zone (milestone-m2.md flags it) | Flag to Creative Director as a balance/tuning item; GDD table may need a revision note at the next balance review — NOT edited here (out of 2-10 scope) |

All other M2 GDD assumptions are consistent with verified engine behaviour and the implementation.

## Engine Compatibility Issues

**Engine audit: PASS (7/7 ADRs have Engine Compatibility sections; no deprecated APIs referenced; no stale versions; M2 implementation matched the pinned 4.6 binary).**

| Check | Result |
|-------|--------|
| ADRs with Engine Compatibility section | 7 / 7 |
| Deprecated API references in ADRs | None |
| Stale engine-version references | None (all 4.6) |
| Post-cutoff API conflicts between ADRs / implementations | None |
| Verified post-cutoff behaviours (M1 + M2) | `DisplayServer.get_display_safe_area() -> Rect2i` no-params (task 1-2 probe); `InputEventScreenTouch/Drag.index` — no `finger_index` (found at 1-13); recursive Control disable on 4.6 (1-13/MTF-9); `_input()` reverse-scene-order (1-9/1-13); `RandomNumberGenerator` stream determinism pinned at 4.6.stable.official.89cea1439 (2-5 RG-1, 2-6 AC-1, 2-7 AC-6.x; ADR-0007 R16 same-engine-version contract) |

**Engine specialist consultation**: skipped — all M2 engine facts were verified by runtime probes/tests on the pinned 4.6 binary during M2 (determinism suites, REG-3 scan), stronger evidence than a consult; no open engine questions remain in M2 scope (ADR-0007 Knowledge Risk LOW, re-validation trigger only on major engine upgrade).

## Architecture Document Coverage (Phase 6)

- Both M2 systems appear in `docs/architecture/architecture.md` §1.1 (Core) with correct layer assignment and §3.2 interfaces; `rng_helpers.gd` ownership at §7 (single direct RNG user, REG-3 scan PASS 2-8).
- §5 signal inventory: NPCRegistry's four signals (`npc_state_changed`, `npc_cooldown_expired`, `trait_revealed`, `village_initialized`) all emitted + tested (AC-16/17/15); CLE is stateless (no signals — correct).
- No orphaned M2 architecture — every M2 design element traces to a GDD, an ADR, or a registered TR.
- Control manifest (manifest-2026.1) encodes the Programmer-rules surface (Required/Forbidden/Guardrails incl. "RNG via RNGHelpers only") consistent with this matrix.

## Story / Milestone Linkage (RTM note)

- Story FILES (`production/stories/sprint-1/`, and pending `production/stories/sprint-2/` via task 2-13) still do not exist for Sprint 1 — pre-existing gap recorded at 1-15/1-17, being addressed by 2-13. TR-ID references continue to be embedded in milestone records.
- M2 TR-ID traceability is embedded in **`production/milestones/milestone-m2.md`** (M1 families + note that `TR-NPC-*` / `TR-CLE-*` register at 2-10) and now fulfilled by this registry append + this review.
- Verifying tests: `tests/unit/npc_registry/*` (42), `tests/integration/npc_registry/*` (7), `tests/unit/conversion_logic_engine/*` (43), `tests/integration/m2/*` (4) — see milestone-m2.md + the matrices above.

---

## Verdict: PASS (M2 Scope)

No **blocking** issues for M2. Within scope: **77/77 requirements covered, 0 partial, 0 gaps**; zero cross-ADR conflicts; engine audit PASS; architecture doc coverage complete. The two findings (CLE HARDENED-zone band fractions; config deviation #2-6-D1) are documented balance/handling items flagged to the Creative Director — consistent with milestones 2-7/2-9 — not architecture defects.

PASS is scoped to M2. Full-project PASS requires the future gates to satisfy:
- **M3**: ADR-0008 (TR-DCD-012 + turn/session TRs + TR-CLE-044 real-caller discipline)
- **M4**: ADR-0009 (TR-GCF-010, TR-TDB-008)

### Required ADRs (prioritised, most foundational first)
1. ADR-0008 — Turn sequence contract (M3 gate; resolves TR-DCD-012; houses TR-CLE-044 final discipline) — `/architecture-decision`
2. ADR-0009 — Save format & restoration rules (M4 gate; resolves TR-GCF-010, TR-TDB-008) — `/architecture-decision`

## Handoff

1. **Immediate actions**: none blocking within Sprint 2. Next review-run trigger: **M3**, when ADR-0008 is written and GSM/DCS/RFS GDDs enter implementation (`/architecture-review` appends TR-GSM-*, TR-DCS-*, TR-RFS-* families). TR-CLE-044's real-caller wiring is verified at M3.
2. **Gate guidance**: re-run `/architecture-review` after each new ADR to verify coverage improves; `/gate-check pre-production` is independent and already passed (2026-08-11).
3. **Goran (Creative Director) decision items surfaced / carried by this review**:
   - **CLE HARDENED-zone band fractions** (0.545+0.455=1.0 empties the zone) — balance/tuning decision for the next balance review; GDD Formula-5 table may need a revision note. Carried from 2-7/2-9, still open for a ruling.
   - **Config deviation #2-6-D1** (`grace_window_turns` added) — recorded + accepted at 2-6; listed for awareness.
   - **Story files** for Sprint 1 still absent (2-13 addresses Sprint 2 story files); TR references live in milestone records meanwhile.
   - **First real CI run** (2-11) requires the next push to `origin/main` — GitHub Actions cannot run from WSL (1-21 limitation); push requires Creative Director instruction.


