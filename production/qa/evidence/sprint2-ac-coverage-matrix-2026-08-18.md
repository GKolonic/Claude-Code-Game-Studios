# Sprint 2 — M2 Acceptance-Criteria Coverage Matrix (story 2-8, REG-2/REG-5)
**Date**: 2026-08-18
**Prepared by**: qa-lead (story 2-8 M2 integration + regression + coverage audit)
**Engine**: Godot 4.6.stable.official.89cea1439 — headless, local WSL (QA plan OQ-B)
**Suite evidence**: `production/qa/evidence/sprint2-full-suite-2026-08-18.log` — 15 scripts, **204/204 tests passing, 22711 asserts, exit 0** (wall-clock 1.901s)
**Boot evidence**: `godot --headless --quit --path .` → exit 0, zero errors (229ms, separate run)
**Integration sanity**: `production/qa/evidence/sprint2-chain-and-determinism-2026-08-18.log` — PASS (exit 0)
**Static scan (REG-3)**: `production/qa/evidence/reg3-static-scan-sprint2-2026-08-18.md` — PASS

> **Evidence-log exception**: `.gitignore` has a global `*.log` rule; the two run-output
> logs below are **deliberately force-added** (git add -f) because milestone records
> (2-9) reference them as evidence pointers. Do not remove them from tracking.

## Coverage summary
| System | ACs | Mapped → passing test | Explicitly unmapped (gap) |
|--------|-----|----------------------|---------------------------|
| NPC Character System (`npc-character-system.md`) | 21 (AC-1..21) + 14 edge cases (E1..E14) | 35 | 0 |
| Conversion Logic Engine (`conversion-logic-engine.md`) | 42 (AC-1.1..AC-8.4) | 42 | 0 |
| **Total** | **77** | **77** | **0** (by-design deferrals are not in-scope AC rows — listed at the bottom) |

**QA-plan reconciliation**: the Sprint 2 QA plan §OUT listed CLE EC-9…EC-13 call-path edge cases as
only M3-exercised (real DCS/RFS linkage). At execution (2-7) these were **covered directly in the CLE unit
suite via synthetic callers** (AC-7.x sentinels, EC-11 pair contract, EC-13 max-approach boundary) and the
M2 integration suite plays the caller role itself (M2-INT-1, CLE AC-8.3 "here you ARE the caller") — so the
edge **handling** is in scope and COVERED; only the real M3 caller wiring is deferred. Second reconciliation:
the **CLE GDD/CONFIG contradiction flagged at 2-7** (shipped band fractions 0.545+0.455=1.0 make the HARDENED
zone empty at every P_final, while the GDD drama-space table + AC-6.4/AC-6.7 assume a sum < 1.0) — AC-6.4 and
AC-6.7 run with **adjusted effective bands documented per test** (mirror how Sprint 1 reconciled TraitDB AC-4/5/6).
The formula is implemented exactly per GDD Formula 5; the finding stays open for Creative Director as a balance
tuning item, not silently changed. **CONVERTED no-op** (CLE EC-4 → apply no-op) is covered at BOTH unit level
(AC-3.4, NPC AC-7) and integration level (new `test_m2_int_1_converted_npc_resolve_valid_and_apply_noop`).

---

## NPC Character System (design/gdd/npc-character-system.md) — AC-1..21
| AC | Test file | Test | Result |
|----|-----------|------|--------|
| AC-1 Same-seed determinism (generation) | tests/unit/npc_registry/npc_registry_test.gd | test_ac_1_same_seed_identical_two_calls (+ test_ac_1_different_seed_generates_different_traits companion) | **PASS** |
| AC-1 over the real fixture | tests/integration/npc_registry/village_lifecycle_test.gd | test_real_village_determinism_same_seed | **PASS** |
| AC-1 full-chain extension (generation + CLE rolls) | tests/integration/m2/m2_integration_chain_test.gd | test_m2_int_2_full_chain_determinism_same_seed | **PASS** |
| AC-2 Clean initial state | tests/unit/npc_registry/npc_registry_test.gd | test_ac_2_initial_state_is_clean (+ village_lifecycle test_real_village_generation_contract_snapshot) | **PASS** |
| AC-3 Trait schema integrity | tests/unit/npc_registry/npc_registry_test.gd | test_ac_3_assigned_traits_are_valid_for_archetype (+ village_lifecycle test_real_village_generation_contract_snapshot) | **PASS** |
| AC-4 Statistical archetype bias (Widow > Soldier bereaved) | tests/unit/npc_registry/npc_registry_test.gd | test_ac_4_widow_bereaved_rate_beats_soldier (100 seeded villages, deterministic seeds) | **PASS** |
| AC-5 Linear progression STEADFAST→OPEN→WAVERING→CONVERTED | tests/unit/npc_registry/npc_registry_test.gd | test_ac_5_three_persuaded_linear_progression | **PASS** |
| AC-5 via full-chain/CLE path | tests/integration/m2/m2_integration_chain_test.gd | test_m2_int_1_belief_transitions_per_rule_5_non_rival | **PASS** |
| AC-6 Floor holds (HARDENED on STEADFAST) | tests/unit/npc_registry/npc_registry_test.gd | test_ac_6_hardened_on_steadfast_stays_floor (+ test_e5_hardened_on_steadfast_updates_counters) | **PASS** |
| AC-7 Terminal state (CONVERTED no-op, no signal) | tests/unit/npc_registry/npc_registry_test.gd | test_ac_7_persuaded_on_converted_is_terminal | **PASS** |
| AC-7 via resolve→apply integration | tests/integration/m2/m2_integration_chain_test.gd | test_m2_int_1_converted_npc_resolve_valid_and_apply_noop (all 8 converted; CLE EC-4 warning asserted) | **PASS** |
| AC-8 Cooldown + counter update | tests/unit/npc_registry/npc_registry_test.gd | test_ac_8_cooldown_and_counter_update | **PASS** |
| AC-8 R9 pair-contract (every non-no-op outcome) | tests/integration/m2/m2_integration_chain_test.gd | test_m2_int_1_full_chain_pair_contract_all_npcs_all_approaches (+ test_m2_int_1_belief_transitions_per_rule_5_non_rival) | **PASS** |
| AC-9 Turn ticks (cooldown decrement, floor 0) | tests/unit/npc_registry/npc_registry_test.gd | test_ac_9_advance_turn_decrements_cooldown_floor_zero (+ test_ac_9_grace_window_ticks_down) | **PASS** |
| AC-10 Cooldown gate | tests/unit/npc_registry/npc_registry_test.gd | test_ac_10_cooldown_gate | **PASS** |
| AC-11 Max-approaches gate | tests/unit/npc_registry/npc_registry_test.gd | test_ac_11_max_approaches_gate | **PASS** |
| AC-12 Access gate (NOBLE behind ELDER) | tests/unit/npc_registry/npc_registry_test.gd | test_ac_12_access_gate | **PASS** |
| AC-12 real-fixture unlock end-to-end | tests/integration/npc_registry/village_lifecycle_test.gd | test_real_village_noble_gate_unlocks_after_elder | **PASS** |
| AC-13 Inspect reveals highest-affinity trait | tests/unit/npc_registry/npc_registry_test.gd | test_ac_13_inspect_reveals_highest_affinity_trait | **PASS** |
| AC-14 Dialogue reveal (approach-relevant trait) | tests/unit/npc_registry/npc_registry_test.gd | test_ac_14_dialogue_outcome_reveals_approach_trait | **PASS** |
| AC-15 No-op on full reveal (no signal) | tests/unit/npc_registry/npc_registry_test.gd | test_ac_15_full_reveal_is_noop_no_signal (+ test_e10_full_reveal_noop) | **PASS** |
| AC-16 Signal accuracy (npc_state_changed exactly once) | tests/unit/npc_registry/npc_registry_test.gd | test_ac_16_npc_state_changed_exact_once_per_transition (+ test_ac_16_17_village_initialized_exactly_once; in-chain check in test_m2_int_1_full_chain_pair_contract_all_npcs_all_approaches) | **PASS** |
| AC-17 Cooldown-expiry signal exactly once | tests/unit/npc_registry/npc_registry_test.gd | test_ac_17_cooldown_expired_exactly_once | **PASS** |
| AC-18 serialize→clear→deserialize round-trip | tests/unit/npc_registry/npc_registry_test.gd | test_ac_18_serialize_clear_deserialize_roundtrip | **PASS** |
| AC-18 real-village round-trip | tests/integration/npc_registry/village_lifecycle_test.gd | test_real_village_persistence_roundtrip | **PASS** |
| AC-19 Unknown BeliefState loads STEADFAST | tests/unit/npc_registry/npc_registry_test.gd | test_ac_19_unknown_belief_state_loads_steadfast | **PASS** |
| AC-20 Duplicate-id guard | tests/unit/npc_registry/npc_registry_test.gd | test_ac_20_duplicate_id_guard (+ test_e1_duplicate_npc_id_returns_existing) | **PASS** |
| AC-21 Unplayable-village guard | tests/unit/npc_registry/npc_registry_test.gd | test_ac_21_unplayable_village_guard (+ test_e8_unplayable_village_guard_clears_one_gate) | **PASS** |

## NPC Character System — edge cases E1..E14
| EC | Test file | Test | Result |
|----|-----------|------|--------|
| E1 Duplicate npc_id keeps existing | tests/unit/npc_registry/npc_registry_test.gd | test_e1_duplicate_npc_id_returns_existing | **PASS** |
| E2 Dead gate ref → gate cleared | tests/unit/npc_registry/npc_registry_test.gd | test_e2_dead_gate_ref_clears_gate | **PASS** |
| E3 Dead connection ref → dropped | tests/unit/npc_registry/npc_registry_test.gd | test_e3_dead_connection_ref_dropped | **PASS** |
| E4 Unknown RelationshipType → connection dropped | tests/unit/npc_registry/npc_registry_test.gd | test_e4_unknown_relationship_dropped_gracefully (+ AC-19 payload path) | **PASS** |
| E5 HARDENED on STEADFAST floor + counters | tests/unit/npc_registry/npc_registry_test.gd | test_e5_hardened_on_steadfast_updates_counters | **PASS** |
| E6 CONVERTED terminal + RIVAL grace-window regression | tests/unit/npc_registry/npc_registry_test.gd | test_e6_rival_grace_window_regression_and_after_close | **PASS** |
| E7 All-at-max approaches → empty list | tests/unit/npc_registry/npc_registry_test.gd | test_e7_all_at_max_approaches_list_empty | **PASS** |
| E8 Unplayable village guard (fewest-ids cleared) | tests/unit/npc_registry/npc_registry_test.gd | test_e8_unplayable_village_guard_clears_one_gate | **PASS** |
| E9 Mutation allowed on gated NPC (RFS) | tests/unit/npc_registry/npc_registry_test.gd | test_e9_mutation_allowed_on_gated_npc | **PASS** |
| E10 Full-reveal no-op (both reveal paths) | tests/unit/npc_registry/npc_registry_test.gd | test_e10_full_reveal_noop | **PASS** |
| E11 Inspect on empty traits logs error | tests/unit/npc_registry/npc_registry_test.gd | test_e11_inspect_on_empty_traits_logs_error | **PASS** |
| E12 RIVAL pair both convert same turn | tests/unit/npc_registry/npc_registry_test.gd | test_e12_rival_pair_both_convert_same_turn_valid | **PASS** |
| E13 clear_village with active cooldowns | tests/unit/npc_registry/npc_registry_test.gd | test_e13_clear_village_with_active_cooldowns | **PASS** |
| E14 get_npc unknown id → null | tests/unit/npc_registry/npc_registry_test.gd | test_e14_get_npc_unknown_returns_null | **PASS** |

## Conversion Logic Engine (design/gdd/conversion-logic-engine.md) — AC-1.1..AC-8.4
| AC | Test file | Test | Result |
|----|-----------|------|--------|
| AC-1.1 Determinism (same seed + same inputs → identical outcome) | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_1_1_determinism_same_seed_identical_outcome (+ integration determinism: m2_integration_chain_test.gd test_m2_int_2_full_chain_determinism_same_seed) | **PASS** |
| AC-1.2 No state written to NPCRegistry | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_1_2_no_state_written_to_npc_registry | **PASS** |
| AC-1.3 No GameConfig side effects | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_1_3_no_gameconfig_side_effects | **PASS** |
| AC-2.1 Single aligned trait → +0.25 | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_2_1_single_aligned_trait | **PASS** |
| AC-2.2 Stacking, no cap → +0.50 | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_2_2_stacking_no_cap | **PASS** |
| AC-2.3 Stacking, cap reached → +0.50 | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_2_3_stacking_cap_reached | **PASS** |
| AC-2.4 Negative cap → −0.50 | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_2_4_negative_cap | **PASS** |
| AC-2.5 Zero affinity → 0.0 | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_2_5_zero_affinity | **PASS** |
| AC-2.6 Empty trait list (EC-6) → 0.0, completes | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_2_6_empty_trait_list_ec_6 | **PASS** |
| AC-2.7 Widow/GRIEF worked example → +0.50 | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_2_7_widow_grief_worked_example | **PASS** |
| AC-3.1 STEADFAST → 0.0 | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_3_1_steadfast_belief_modifier | **PASS** |
| AC-3.2 OPEN → +0.10 | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_3_2_open_belief_modifier | **PASS** |
| AC-3.3 WAVERING → +0.20 | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_3_3_wavering_belief_modifier | **PASS** |
| AC-3.4 CONVERTED fallback (EC-4) → 0.0 + warning + valid outcome | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_3_4_converted_fallback_ec_4 (+ integration: m2_integration_chain_test.gd test_m2_int_1_converted_npc_resolve_valid_and_apply_noop) | **PASS** |
| AC-4.1 First use → 0.0 | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_4_1_first_use_no_penalty | **PASS** |
| AC-4.2 Second use → 0.05 | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_4_2_second_use | **PASS** |
| AC-4.3 Cap at third use → 0.15 | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_4_3_cap_at_third_use | **PASS** |
| AC-4.4 Cap holds beyond third use | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_4_4_cap_holds_beyond_third_use | **PASS** |
| AC-4.5 Zero per-use weight → 0.0 at any count | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_4_5_zero_weight_penalty_config | **PASS** |
| AC-5.1 Neutral baseline → 0.35 | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_5_1_neutral_baseline | **PASS** |
| AC-5.2 Floor enforced → 0.05 | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_5_2_floor_enforced | **PASS** |
| AC-5.3 Ceiling enforced → 0.80 | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_5_3_ceiling_enforced | **PASS** |
| AC-5.4 Max theoretical P_raw 1.05 → clamped 0.80 | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_5_4_max_theoretical_praw_clamped | **PASS** |
| AC-5.5 Min theoretical P_raw −0.30 → clamped 0.05 | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_5_5_min_theoretical_praw_clamped | **PASS** |
| AC-5.6 Four-component sum (0.35+0.25+0.10−0.05=0.65) | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_5_6_four_component_sum | **PASS** |
| AC-6.1 PERSUADED zone | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_6_1_persuaded_zone | **PASS** |
| AC-6.2 SOFTENED zone | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_6_2_softened_zone | **PASS** |
| AC-6.3 RESISTED zone | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_6_3_resisted_zone | **PASS** |
| AC-6.4 HARDENED zone (adjusted bands, GDD contradiction note) | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_6_4_hardened_zone | **PASS** |
| AC-6.5 No HARDENED at ceiling — 1000 seeded rolls | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_6_5_no_hardened_at_ceiling_1000_rolls | **PASS** |
| AC-6.6 Boundary roll == P_final → SOFTENED (strict `<`) | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_6_6_boundary_roll_equals_p_final_softened | **PASS** |
| AC-6.7 Four outcomes cover full range — 10,000 rolls ±3% (adjusted bands) | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_6_7_four_outcomes_distribution_10k | **PASS** |
| AC-7.1 EC-1 negative HARDENED zone floor-clamp | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_7_1_negative_hardened_floor_clamp | **PASS** |
| AC-7.2 EC-2 band fractions > 1.0 clamp | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_7_2_band_fractions_over_one_clamp | **PASS** |
| AC-7.3 EC-3 unknown NPC → RESISTED sentinel | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_7_3_unknown_npc_resisted | **PASS** |
| AC-7.4 EC-5 null config field → RESISTED | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_7_4_null_config_resisted | **PASS** |
| AC-7.5 EC-9 invalid approach → RESISTED | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_7_5_invalid_approach_resisted | **PASS** |
| AC-7.6 EC-10 boundary ownership (strict `<`) | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_6_6_boundary_roll_equals_p_final_softened (same test covers AC-6.6/AC-7.6) | **PASS** |
| AC-8.1 Signature compiles + typed outcome | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_8_1_signature_compiles_and_autoload_available | **PASS** |
| AC-8.2 Autoload callable from any script | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_8_1_signature_compiles_and_autoload_available | **PASS** |
| AC-8.3 Both caller stubs succeed (DCS + RFS) | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_8_3_both_caller_stubs_succeed (stub_dcs_shaped.gd + stub_rfs_shaped.gd; also M2-INT-1 chain plays the caller role directly) | **PASS** |
| AC-8.4 GameConfig read-at-call-time (no caching) | tests/unit/conversion_logic_engine/conversion_logic_engine_test.gd | test_ac_8_4_read_at_call_time | **PASS** |

## M2 integration (story 2-8, QA plan M2-INT-1 / M2-INT-2)
| Check | Test file | Test | Result |
|-------|----------|------|--------|
| M2-INT-1 full generate→resolve→apply chain on village_01 (8 NPCs × 4 approaches) | tests/integration/m2/m2_integration_chain_test.gd | test_m2_int_1_full_chain_pair_contract_all_npcs_all_approaches | **PASS** |
| M2-INT-1 R9 pair contract (approach_count +1, approach_history +1, cooldown == approach_cooldown_turns after EVERY apply) | tests/integration/m2/m2_integration_chain_test.gd | test_m2_int_1_full_chain_pair_contract_all_npcs_all_approaches (+ test_m2_int_1_belief_transitions_per_rule_5_non_rival) | **PASS** |
| M2-INT-1 belief-transition validity per Rule 5 (PERSUADED linear; HARDENED OPEN→STEADFAST non-RIVAL; RESISTED unchanged + counters) | tests/integration/m2/m2_integration_chain_test.gd | test_m2_int_1_belief_transitions_per_rule_5_non_rival | **PASS** |
| M2-INT-1 CONVERTED NPC: resolve valid (EC-4) + apply no-op (AC-7/E6) | tests/integration/m2/m2_integration_chain_test.gd | test_m2_int_1_converted_npc_resolve_valid_and_apply_noop | **PASS** |
| M2-INT-2 same-seed determinism across the FULL chain (generation + CLE rolls), distinct from generation-only | tests/integration/m2/m2_integration_chain_test.gd | test_m2_int_2_full_chain_determinism_same_seed (also asserts chain ≠ generation-only snapshot) | **PASS** |

## Integration sanity (story 2-8, REG-2 supplement)
| Check | Evidence | Result |
|-------|----------|--------|
| Full suite green headless incl. new M2 integration suite | production/qa/evidence/sprint2-full-suite-2026-08-18.log (204/204, exit 0, wall-clock 1.901s) | **PASS** |
| Headless boot exit 0, zero errors | `godot --headless --quit --path .` → exit 0, 0 errors (229ms; recorded in suite log footer) | **PASS** |
| Chain + determinism probe (M2-INT-1/M2-INT-2 run as a standalone SceneTree probe) | production/qa/evidence/sprint2-chain-and-determinism-2026-08-18.log — PASS, exit 0 | **PASS** |
| REG-3 static scan refresh (RNG ownership + no hardcoded balance values) | production/qa/evidence/reg3-static-scan-sprint2-2026-08-18.md — PASS | **PASS** |
| R9 (resolve→apply atomicity) — pair contract proven end-to-end at chain level | tests/integration/m2/m2_integration_chain_test.gd; R9 recorded **open-until-M3** (sprint risk table R9 — DCS finally-block discipline is enforced at M3) | **PASS** (contract); R9 carried |
| Zero S1/S2 bugs | 204/204 suite green; headless boot exit 0 zero errors; chain probe PASS; static scans clean | **No S1/S2 findings** |

## Gaps / flagged items (explicit, not silently skipped)
1. **By-design deferrals from the QA plan §OUT / sprint plan (NOT in-scope AC rows, zero matrix gaps):**
   - CLE EC-9…EC-13 **real-caller** linkage (actual DCS/RFS systems) → **M3**; edge handling itself is covered now (unit AC-7.x + integration M2-INT-1 where this suite plays the caller per CLE AC-8.3).
   - NPC CS ACs requiring **UI/presentation** (portrait expression mapping, inspect-flow presentation) → **M5**; NPC-side logic (reveal selection, no-ops) is fully covered.
   - **Android export** spot-check (MTF AC-14-style manual pass) → **M7** (OQ-C); automated asserts green now.
   - GameConfig AC-9 (save/load round-trip does not re-save config) — carried from M1, no SaveLoad system until **M4**; listed for continuity only (not an M2 AC).
2. **CLE GDD/CONFIG contradiction (flagged 2-7, surfaced here for the 2-9 milestone):** shipped band fractions 0.545+0.455=1.0 empty the HARDENED zone; AC-6.4/AC-6.7 use adjusted effective bands documented per test; formula implemented exactly per GDD Formula 5. Balance/tuning finding for Creative Director — recorded, not silently changed.
3. **None other.** All 77 in-scope M2 AC rows (NPC AC-1..21, E1..E14, CLE AC-1.1..AC-8.4) map to ≥1 passing test.