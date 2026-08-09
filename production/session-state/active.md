# Session State — The Faithful / Divine Dominion

<!-- STATUS -->
Epic: Pre-Production
Feature: Design Documentation
Task: Architecture plan — accepted; ADR-0001…0004 accepted
<!-- /STATUS -->

## Current Task
Completing full pre-production phase:
1. ✅ Engine configured — Godot 4.6 / GDScript / Mobile / Turn-based
2. ✅ Systems index written — 27 systems total (19 NPC layer + 8 macro layer)
3. ✅ Art Bible — complete (design/art/art-bible.md, all 9 sections)
4. ✅ System GDDs — 14/14 MVP done:
   - ✅ Game Config (design/gdd/game-config.md)
   - ✅ NPC Trait Database (design/gdd/npc-trait-database.md)
   - ✅ Dialogue Content Database (design/gdd/dialogue-content-database.md)
   - ✅ Mobile Touch Framework (design/gdd/mobile-touch-framework.md)
   - ✅ NPC Character System (design/gdd/npc-character-system.md)
   - ✅ Conversion Logic Engine (design/gdd/conversion-logic-engine.md)
   - ✅ Dialogue & Conversion System (design/gdd/dialogue-conversion-system.md)
   - ✅ Game State Manager (design/gdd/game-state-manager.md) — COMPLETE
   - ✅ Rival Faith System (design/gdd/rival-faith-system.md)
   - ✅ Save & Load System (design/gdd/save-load-system.md)
   - ✅ Portrait & Expression System (design/gdd/portrait-expression-system.md)
   - ✅ Conversion UI (design/gdd/conversion-ui.md)
   - ✅ Village Map View (design/gdd/village-map-view.md)
   - ✅ HUD & Progress System (design/gdd/hud-progress-system.md) — FINAL MVP GDD
5. ✅ Architecture plan — accepted (docs/architecture/architecture.md, 2026-08-09)
6. ⬜ Sprint plan

## Key Decisions Made (this session)
- Divine Dominion GDD reviewed — MAJOR REVISION NEEDED verdict
- Divine Dominion integrated as macro-layer on The Faithful (two-scale game)
- Gameplay model: Turn-based (locked)
- Win condition: 50%+ of all world regions simultaneously (locked)
- Lose condition: All regions below 10% conversion (locked)
- Orientation: Portrait primary (confirmed)
- 8 new macro-layer systems added to systems-index.md (systems 20-27)
- Balance flags recorded in systems-index for macro layer economy design
- Village Map View OQs resolved (2026-08-09): OQ-1 safe-area verify-at-implementation w/ Viewport/notch fallback; OQ-2 shader-driven ink-bleed; OQ-3 scroll/zoom deferred; OQ-4 **win/loss presentation owned by HUD & Progress System (#14)** — VMV only locks the map; OQ-5 `#E6BE64` ships as-is; OQ-6 ash-grey crescent rival marker
- `VillageMapConfig` added as 8th config domain (game-config.md)
- HUD & Progress System OQs resolved (2026-08-09): OQ-1 faith-power **numeral shown** (strip = designated numeral zone); OQ-2 rival indicator = ash-grey crescent + QUIET/ACTIVE gauge, **no %**; OQ-3 **`HUDConfig` 9th config domain**; OQ-4 WON ends `GAME_OVER` → title at MVP, `resolution_complete` = macro-layer seam; OQ-5 LOST = sober card → 2.0s final-tally → title; OQ-6 chronicle card **non-interactive** at MVP; OQ-7 safe-area verify-at-implementation (Viewport/notch fallback); OQ-8 village name via `tr("VILLAGE_" + village_id)` content keys
- `HUDConfig` added as 9th config domain (game-config.md)
- **MVP Architecture Plan ACCEPTED** (2026-08-09) — 10 Autoloads + 4 scenes + signal-driven orchestration. Key decisions (D1–D10): 10-Autoload order (GameConfig first, DCS before GSM), 4 scenes (`conversation_screen`, `village_map`, `hud_progress`, `main`), PortraitController as scene node, DCS owns conversation flow, Conversion UI sole expression driver, GSM exclusive NPC-lifecycle caller, MTF sole input boundary + Conversion UI only blocking-layer owner, **FaithSpread no-op stub at GSM Step 4 (MVP)**, GameEnums shared class, VillageDefinition Resource (proposed)
- **Autoload-order conflict resolved: DCS before GSM** (GSM Rule 10 authority; Save&Load GDD architectural note corrected to `NPCRegistry → DCS → GSM → SaveLoad`)
- **ADR-0001…0004 ACCEPTED** (M0 foundation, 2026-08-09): ADR-0001 Autoload architecture & init order; ADR-0002 data resource model (GameEnums, VillageDefinition); ADR-0003 signal architecture & communication discipline; ADR-0004 scene ownership & CanvasLayer stack. ADR-0005…0011 milestone-gated (M1–M6).
- ⚠️ **Pre-existing inconsistency flagged for `/consistency-check`** (NOT edited): `RivalFaithConfig.aggression_interval_turns` default is **6** in game-config.md vs **3** in rival-faith-system.md — the two GDDs must agree before implementation; game-config.md is the authoritative config owner

## Files Modified This Session
- docs/architecture/architecture.md — NEW master architecture document (Accepted, version 1, 2026-08-09)
- docs/architecture/adr-0001.md — NEW Autoload architecture & initialization order (Accepted)
- docs/architecture/adr-0002.md — NEW data resource model: GameEnums, VillageDefinition (Accepted)
- docs/architecture/adr-0003.md — NEW signal architecture & communication discipline (Accepted)
- docs/architecture/adr-0004.md — NEW scene ownership & CanvasLayer stack (Accepted)
- design/registry/entities.yaml — Appendix D: PortraitConfig, VillageMapConfig, GameEnums, BeliefState, DialogueApproach, NPCArchetype, NpcRecord, NPCArchetypeDefinition, VillageDefinition constants; ConversionOutcome + RivalFaithConfig notes updated
- design/gdd/save-load-system.md — architectural note order corrected: `NPCRegistry → DCS → GSM → SaveLoad` (reconciles GSM Rule 10)
- design/gdd/dialogue-conversion-system.md — §Formulas recency lifetime: GSM emits `village_cleared` signal (DCS subscribes)
- production/session-state/active.md — this file
- design/gdd/hud-progress-system.md — NEW GDD (system #14), 8 sections + V/A + UI Req + OQs resolved + appendix
- design/gdd/game-config.md — HUDConfig 9th domain (Rule 2 nine domains, field ranges table, Interactions row, AC-1/AC-10, Tuning Knobs note)
- design/gdd/village-map-view.md — F1 top inset → `HUD.get_top_strip_height_dp()` (formula + output range + UI Req row)
- design/gdd/systems-index.md — row 14 → Designed; tracker 13/14 → 14/14; design docs started 13 → 14
- design/registry/entities.yaml — HUDConfig constant + F1/F2/F3 formulas + referenced_by updates (earlier)
- production/session-state/active.md — this file (earlier)

## Cross-System Updates Pending
- ✅ design/gdd/dialogue-conversion-system.md — §Formulas recency state lifetime: "When GSM calls NPCRegistry.clear_village()" → "When GSM emits village_cleared signal (DCS subscribes)" — applied 2026-08-09
- ✅ design/gdd/save-load-system.md — Architectural Note autoload order corrected to `NPCRegistry → DCS → GameStateManager → SaveLoad` (reconciles GSM Rule 10, architecture plan D1/ADR-0001) — applied 2026-08-09
- ✅ design/gdd/game-config.md — PortraitConfig domain added (7th domain: Rule 2 "six domains"→seven, field ranges table, AC-10 "6 domains"→7, Interactions row) — applied 2026-08-09
- ✅ design/gdd/npc-character-system.md — `portrait_asset_path` format contract added under Rule 3 (directory path, six expression files, debug validation) — applied 2026-08-09
- ✅ design/gdd/npc-trait-database.md — archetypes note (`portrait_asset_path` + `social_influence_weight` owned by NPC Character System GDD) + P&E consumer row marked prospective — applied 2026-08-09
- ✅ design/gdd/game-config.md — UITimingConfig: `approach_confirm_hold_sec`, `hardened_reveal_hold_sec`, `trait_card_reveal_ms` added — applied 2026-08-09
- ✅ design/gdd/mobile-touch-framework.md — Conversion UI consuming-table row corrected (portrait NOT registered; P&E UI Req) — applied 2026-08-09
- ✅ design/gdd/dialogue-conversion-system.md — Timer Ownership wording fixed (tap calls `select_approach()` immediately); OQ-1 resolved (Conversion UI GDD Rule 12, −150K lighting cue) — applied 2026-08-09
- ✅ design/gdd/systems-index.md — row 12 → Designed; tracker 11/14 → 12/14 — applied 2026-08-09
- ✅ design/gdd/game-config.md — VillageMapConfig 8th domain added (Rule 2 "seven domains"→eight, field ranges table, Interactions row, AC-1/AC-10 "7 domains"→8, Tuning Knobs) — applied 2026-08-09
- ✅ design/gdd/conversion-ui.md — `conversation_closed` teardown guarantee confirmed on EVERY path (session-complete + back/cancel + defensive village-clear) — applied 2026-08-09
- ✅ design/gdd/dialogue-conversion-system.md — EC-1 wording fixed ("disabled by the Village Map View") — applied 2026-08-09
- ✅ design/gdd/systems-index.md — row 13 → Designed; tracker 12/14 → 13/14; design docs started 12 → 13 — applied 2026-08-09
- ✅ design/gdd/hud-progress-system.md — NEW GDD (system #14); OQ-1..OQ-8 resolved — applied 2026-08-09
- ✅ design/gdd/game-config.md — HUDConfig 9th domain added (Rule 2 "eight domains"→nine, field ranges table, Interactions row, AC-1/AC-10 "8 domains"→9, Tuning Knobs note) — applied 2026-08-09
- ✅ design/gdd/village-map-view.md — F1 top inset → `HUD.get_top_strip_height_dp()` (formula, output range, UI Req row) — applied 2026-08-09
- ✅ design/gdd/systems-index.md — row 14 → Designed; tracker 13/14 → 14/14; design docs started 13 → 14 — applied 2026-08-09
- ✅ design/registry/entities.yaml — HUDConfig constant + conversion_fraction/rival_activity_rate/chronicle_card_alpha formulas + referenced_by updates — applied 2026-08-09
- ⬜ **Flagged for `/consistency-check`** (NOT edited): `RivalFaithConfig.aggression_interval_turns` default 6 (game-config.md, authoritative) vs 3 (rival-faith-system.md)
- ⬜ **Open Questions from architecture plan §9** (noted for resolution): safe-area API spike (M0), VillageDefinition schema confirmation (OQ-4), dialogue authoring format (OQ-5), boot/title flow (OQ-6), RNG persistence (OQ-7), FaithSpreadConfig shipping (OQ-10), engine install/CI (OQ-9, R12)

## Next
Pre-production design documentation is COMPLETE — all 14/14 MVP GDDs designed; MVP Architecture Plan accepted (ADR-0001…0004 Accepted).
Remaining pre-production items:
1. ✅ **Architecture plan** — docs/architecture/architecture.md Accepted; ADR-0001…0004 Accepted (M0 foundation)
2. **Sprint plan** — break MVP into implementation sprints (foundation → core → feature → presentation); ADR-0005…0011 are milestone-gated (M1–M6) and should be written as their milestones approach
3. **Control manifest** — run `/create-control-manifest` (after foundational ADRs; date-stamped `Manifest Version:`)
4. **TR registry + architecture review** — run `/architecture-review` (Phase 8 populates tr-registry.yaml; writes architecture-review report)
5. **Gate-check** — run `/gate-check pre-production` (validates GDDs complete, systems index updated, config domains consistent, session state current)
6. **UX spec** — `/ux-design` for `design/ux/hud.md` (HUD UI requirements — flagged in the HUD GDD)
7. **Asset specs** — `/asset-spec` per system once the Art Bible is approved (HUD flagged: system:hud-progress-system)
MVP systems remaining: none — design phase complete.
