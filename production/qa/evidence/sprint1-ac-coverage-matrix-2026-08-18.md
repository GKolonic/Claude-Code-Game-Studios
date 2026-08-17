# Sprint 1 — M1 Acceptance-Criteria Coverage Matrix (story 1-14, REG-5)
**Date**: 2026-08-18
**Prepared by**: qa-lead (story 1-14 foundation regression pass)
**Engine**: Godot 4.6.stable.official.89cea1439 — headless, local WSL (QA plan OQ-B)
**Suite evidence**: `production/qa/evidence/sprint1-full-suite-2026-08-18.log` — 8 scripts, **74/74 tests passing, 4810 asserts, exit 0**
**Boot evidence**: `godot --headless --quit --path .` → exit 0, zero errors (same run)
**Integration sanity**: `production/qa/evidence/chain-probe-2026-08-18.log` — PASS (exit 0)
**Static scan (AC-6)**: `production/qa/evidence/reg3-static-scan-ac6-2026-08-18.md` — PASS

> **Evidence-log exception**: `.gitignore` has a global `*.log` rule; the two run-output
> logs below are **deliberately force-added** (git add -f) because milestone records
> (1-15) reference them as evidence pointers. Do not remove them from tracking.

## Coverage summary
| System | ACs | Mapped → passing test | Explicitly unmapped (gap) |
|--------|-----|----------------------|---------------------------|
| GameConfig | 10 (AC-1..10) | 9 | 1 — **AC-9 deferred by design to M4** (QA plan GCF-DEF; story 1-10 AC) |
| TraitDatabase | 11 (AC-1..11) | 11 | 0 |
| DialogueDatabase | 13 (AC-1..13) | 13 | 0 |
| MobileTouchFramework | 14 (AC-1..14) | 14 | 0 (AC-14 automated assert per OQ-C; manual Android export spot-check at M7) |
| **Total** | **48** | **47** | **1 (by design)** |

**QA-plan reconciliation**: the Sprint 1 QA plan §OUT listed TraitDB AC-4/5/6 as "deferred to Sprint 2" because they were expected to need the NPC Character System. At execution (story 1-11) these were instead implemented as **local simulations driving the GDD Trait Assignment Formula against the shipped catalogue + GameConfig weights** (1,000–10,000 runs, deterministic seeds). They are therefore **COVERED** here (formula owner remains NPC Character System at M2; SAMPLING verified now, production harness in M2). GameConfig AC-9 remains the single deferred AC (no save/load system exists at M1 — deferred by design to M4 per architecture §6).

---

## GameConfig (design/gdd/game-config.md) — AC-1..10
| AC | Test file | Test | Result |
|----|-----------|------|--------|
| AC-1 Load on startup (before other Autoloads) | tests/integration/game_config/game_config_order_test.gd | test_gcf_1_gameconfig_loaded_before_other_autoloads_ready | **PASS** |
| AC-1 (mechanism: slot-1 registration) | tests/integration/game_config/game_config_order_test.gd | test_gcf_1_gameconfig_is_first_autoload_in_project_settings | **PASS** |
| AC-1 (autoload reached LOADED) | tests/unit/game_config/game_config_test.gd | test_gcf_1_gameconfig_autoload_is_loaded | **PASS** |
| AC-2 Typed accessor access | tests/unit/game_config/game_config_test.gd | test_gcf_2_typed_access_field_sweep (50+ fields across all 9 domains) | **PASS** |
| AC-3 Out-of-range clamping | tests/unit/game_config/game_config_test.gd | test_gcf_3_out_of_range_clamps_with_warning (+ test_gcf_3_clamp_at_exact_boundary_is_accepted) | **PASS** |
| AC-4 Missing required field halts naming field | tests/unit/game_config/game_config_test.gd | test_gcf_4_missing_required_field_halts_naming_field | **PASS** |
| AC-5 Missing file halts naming path | tests/unit/game_config/game_config_test.gd | test_gcf_5_missing_file_halts_naming_path | **PASS** |
| AC-6 No hardcoded values in gameplay systems | evidence/reg3-static-scan-ac6-2026-08-18.md (REG-3, QA plan OQ-E — static scan, not GUT) | numeric-literal sweep of src/gameplay/ (absent) + src/core/ (clean) | **PASS** |
| AC-7 Hot-reload updates live values (editor only) | tests/unit/game_config/game_config_test.gd | test_gcf_7_hot_reload_swaps_value_and_emits_signal (+ test_gcf_7_failed_hot_reload_retains_last_valid_and_no_signal, EC-8) | **PASS** |
| AC-8 Hot-reload not present in export build | tests/unit/game_config/game_config_test.gd | test_gcf_8_no_watcher_in_export_build (headless: watcher empty, _process disabled) | **PASS** |
| **AC-9 Save/Load round-trip does not re-save config** | — | **no test** — **deferred by design to M4** (no SaveLoad system at M1; QA plan GCF-DEF; story 1-10 AC) | **GAP (documented, intentional)** |
| AC-10 All 9 domains accessible | tests/unit/game_config/game_config_test.gd | test_gcf_8_all_nine_domains_accessible_and_typed | **PASS** |

## TraitDatabase (design/gdd/npc-trait-database.md) — AC-1..11
| AC | Test file | Test | Result |
|----|-----------|------|--------|
| AC-1 Loads at startup without error | tests/unit/trait_database/trait_database_test.gd | test_ac_1_database_loads_at_startup | **PASS** |
| AC-2 Trait lookup by ID returns correct data | tests/unit/trait_database/trait_database_test.gd | test_ac_2_trait_lookup_by_id_returns_correct_data | **PASS** |
| AC-3 Approach-trait affinity returns correct modifier | tests/unit/trait_database/trait_database_test.gd | test_ac_3_affinity_times_weight_matches_gdd_example | **PASS** |
| AC-4 Trait assignment respects rarity weights | tests/unit/trait_database/trait_database_test.gd | test_ac_4_trait_assignment_respects_rarity_weights (10,000 draws, 60/30/10, deterministic seed; 57–63/27–33/8–12%) | **PASS** |
| AC-5 No NPC receives duplicate traits | tests/unit/trait_database/trait_database_test.gd | test_ac_5_and_6_assignment_never_duplicates_and_respects_count (1,000 NPCs, draw-without-replacement) | **PASS** |
| AC-6 traits_per_npc constraint | tests/unit/trait_database/trait_database_test.gd | test_ac_5_and_6_assignment_never_duplicates_and_respects_count (2–4 per NPC asserted) | **PASS** |
| AC-7 Unknown trait ID returns null | tests/unit/trait_database/trait_database_test.gd | test_ac_7_unknown_trait_id_returns_null_without_crash | **PASS** |
| AC-8 All traits have 4 valid affinities | tests/unit/trait_database/trait_database_test.gd | test_ac_8_all_traits_have_four_valid_affinities (also 5-band constraint, Rule 5) | **PASS** |
| AC-9 get_affinity returns 0.0 for unknown ID | tests/unit/trait_database/trait_database_test.gd | test_ac_9_get_affinity_returns_zero_for_unknown_trait | **PASS** |
| AC-10 All 16 MVP traits present | tests/unit/trait_database/trait_database_test.gd | test_ac_10_all_sixteen_mvp_traits_present | **PASS** |
| AC-11 Rarity distribution matches design | tests/unit/trait_database/trait_database_test.gd | test_ac_11_rarity_distribution_matches_design (7/6/3) | **PASS** |

## DialogueDatabase (design/gdd/dialogue-content-database.md) — AC-1..13
| AC | Test file | Test | Result |
|----|-----------|------|--------|
| AC-1 Loads at startup without error | tests/unit/dialogue_database/dialogue_database_test.gd | test_dcd_1_loads_at_startup_no_errors (zero warnings on production DB) | **PASS** |
| AC-2 Total string count = 100 (advisory → automated, OQ-F) | tests/unit/dialogue_database/dialogue_database_test.gd | test_dcd_2_content_audit_v_total_is_100 (+ test_r8_no_slot_below_three_per_min_across_production_db) | **PASS** |
| AC-3 Approach line pool correct (4 approaches) | tests/unit/dialogue_database/dialogue_database_test.gd | test_dcd_3_approach_pools_correct_for_all_four | **PASS** |
| AC-4 Outcome pool correct (16 pairs) | tests/unit/dialogue_database/dialogue_database_test.gd | test_dcd_4_outcome_pools_correct_for_all_sixteen | **PASS** |
| AC-5 NPC flavour valid (7 archetypes) | tests/unit/dialogue_database/dialogue_database_test.gd | test_dcd_5_flavour_valid_for_all_seven_archetypes | **PASS** |
| AC-6 Rival line pool correct (4 approaches) | tests/unit/dialogue_database/dialogue_database_test.gd | test_dcd_6_rival_pools_correct_for_all_four | **PASS** |
| AC-7 Invalid approach → empty array, no crash | tests/unit/dialogue_database/dialogue_database_test.gd | test_dcd_7_invalid_approach_returns_empty_without_crash (−1, 99) | **PASS** |
| AC-8 Invalid outcome combo → empty array, no crash | tests/unit/dialogue_database/dialogue_database_test.gd | test_dcd_8_invalid_outcome_combination_returns_empty_without_crash | **PASS** |
| AC-9 Invalid archetype → null, no crash | tests/unit/dialogue_database/dialogue_database_test.gd | test_dcd_9_invalid_archetype_returns_null_without_crash | **PASS** |
| AC-10 Under-filled slot sets is_loaded() false | tests/unit/dialogue_database/dialogue_database_test.gd | test_dcd_10_underfilled_slot_sets_unloaded_and_warns (fixture underfilled.tres, OQ-D) | **PASS** |
| AC-11 get_* safe when is_loaded() false | tests/unit/dialogue_database/dialogue_database_test.gd | test_dcd_11_getters_safe_when_unloaded | **PASS** |
| AC-12 Empty short_descriptor warns but returns struct | tests/unit/dialogue_database/dialogue_database_test.gd | test_dcd_12_empty_descriptor_warns_but_returns_struct (fixture empty_descriptor.tres, OQ-D) | **PASS** |
| AC-13 get_npc_flavour() returns a copy | tests/unit/dialogue_database/dialogue_database_test.gd | test_dcd_13_get_npc_flavour_returns_copy_not_shared_ref (EC-6) | **PASS** |

## MobileTouchFramework (design/gdd/mobile-touch-framework.md) — AC-1..14
| AC | Test file | Test | Result |
|----|-----------|------|--------|
| AC-1 Tap classification — correct hit | tests/unit/mobile_touch_framework/mtf_gesture_test.gd | test_ac_1_tap_hit_emits_once_with_target_and_haptic | **PASS** |
| AC-2 Tap classification — miss | tests/unit/mobile_touch_framework/mtf_gesture_test.gd | test_ac_2_tap_miss_emits_nothing | **PASS** |
| AC-3 Tap target inflation | tests/unit/mobile_touch_framework/mtf_gesture_test.gd | test_ac_3_tap_target_inflation_44dp_floor (44×44 inflated, warning names node+size) | **PASS** |
| AC-4 Long press — starts and releases | tests/unit/mobile_touch_framework/mtf_gesture_test.gd | test_ac_4_long_press_starts_at_600ms_and_releases (threshold exactly 600ms) | **PASS** |
| AC-5 Dead band — no signal | tests/unit/mobile_touch_framework/mtf_gesture_test.gd | test_ac_5_dead_band_emits_nothing (+ test_tap_boundary_at_350ms, test_dead_band_at_351ms) | **PASS** |
| AC-6 Swipe classification — 4 directions | tests/unit/mobile_touch_framework/mtf_gesture_test.gd | test_ac_6_swipe_classification_four_directions (+ test_swipe_sector_boundaries F-4) | **PASS** |
| AC-7 Swipe velocity gate | tests/unit/mobile_touch_framework/mtf_gesture_test.gd | test_ac_7_swipe_velocity_gate_rejects_slow_drag | **PASS** |
| AC-8 Multi-finger discard | tests/unit/mobile_touch_framework/mtf_gesture_test.gd | test_ac_8_second_finger_discarded_gesture_continues (EC-2 release also ignored) | **PASS** |
| AC-9 Blocking layer suppression | tests/unit/mobile_touch_framework/mtf_gesture_test.gd | test_ac_9_blocking_layer_suppresses_lower_priority (+ test_ac_9_unregister_resumes_immediately_after_pop, test_blocking_layer_subtree_controls_disabled_and_restored, test_blocking_layer_stack_ordering_and_clear) | **PASS** |
| AC-10 Gesture timeout | tests/unit/mobile_touch_framework/mtf_gesture_test.gd | test_ac_10_gesture_timeout_emits_touch_cancelled | **PASS** |
| AC-11 Debounce | tests/unit/mobile_touch_framework/mtf_gesture_test.gd | test_ac_11_debounce_discards_bounce_tap_within_100ms (window + post-window accepted) | **PASS** |
| AC-12 DPI fallback | tests/unit/mobile_touch_framework/mtf_gesture_test.gd | test_ac_12_dpi_fallback_for_zero_or_implausible (0/−5/641 → 1.0 + warning; 72/640 edges) | **PASS** |
| AC-13 dp conversion accuracy | tests/unit/mobile_touch_framework/mtf_gesture_test.gd | test_ac_13_dp_conversion_accuracy_at_390_dpi (44dp → 107.25px, center-anchored inflation) | **PASS** |
| AC-14 No visual output in release builds | tests/unit/mobile_touch_framework/mtf_gesture_test.gd | test_ac_14_no_visual_output_in_release_builds (automated assert per OQ-C: overlay off, zero child nodes after gestures). Manual Android export spot-check deferred to M7 (no export templates this sprint) | **PASS** (automated portion; manual spot-check M7) |

## Integration sanity (story 1-14, REG-2 supplement)
| Check | Evidence | Result |
|-------|----------|--------|
| Autoload order + signals — GameEnums → GameConfig → TraitDatabase → DialogueDatabase → MTF load null-ref-free | tests/integration/m0_boot_test.gd (BOOT-1..4) + tests/integration/game_config/game_config_order_test.gd + evidence/chain-probe-2026-08-18.log | **PASS** |
| GSM deferred signal connect after DCS exists (ADR-0001) | tests/integration/m0_boot_test.gd test_boot_3_gsm_deferred_connect_fires_after_dcs + chain probe | **PASS** |
| MTF is the sole input boundary (no UI reads Input directly) | tests/unit/mobile_touch_framework/mtf_gesture_test.gd test_mtf_15_no_src_code_reads_input_outside_mtf (scans all src/) | **PASS** |
| set_input_as_handled only inside MTF (R3/ADR-0006) | tests/unit/mobile_touch_framework/mtf_gesture_test.gd test_mtf_16_set_input_as_handled_lives_only_in_mtf | **PASS** |
| Zero S1/S2 bugs | 74/74 suite green; headless boot exit 0 zero errors; chain probe PASS; static scans clean | **No S1/S2 findings** |

## Gaps / flagged items (explicit, not silently skipped)
1. **GameConfig AC-9** — no test. Deferred by design to M4 (save/load system does not exist at M1; architecture §6; QA plan GCF-DEF; story 1-10 AC). Carry to Sprint 2 QA; re-verify at M4 milestones.
2. **MTF AC-14 manual export spot-check** — automated assert green now (OQ-C); the one Android export + screenshot pass is prescribed at M7 when export tooling exists (session-state 1-13 record).
3. **None other.** All remaining 47/48 M1 ACs map to at least one passing test.