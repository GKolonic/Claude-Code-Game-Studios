# Session State — The Faithful / Divine Dominion

<!-- STATUS -->
Epic: Pre-Production
Feature: Design Documentation
Task: Village Map View System GDD — Designed
<!-- /STATUS -->

## Current Task
Completing full pre-production phase:
1. ✅ Engine configured — Godot 4.6 / GDScript / Mobile / Turn-based
2. ✅ Systems index written — 27 systems total (19 NPC layer + 8 macro layer)
3. ✅ Art Bible — complete (design/art/art-bible.md, all 9 sections)
4. 🔄 System GDDs — 13/14 MVP done:
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
5. ⬜ Architecture plan
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

## Files Modified This Session
- design/gdd/village-map-view.md — NEW GDD (system #13), 8 sections + V/A + UI Req + appendix
- design/gdd/game-config.md — VillageMapConfig 8th domain (Rule 2 eight domains, field ranges table, Interactions row, AC-1/AC-10, Tuning Knobs)
- design/gdd/conversion-ui.md — `conversation_closed` emitted on EVERY teardown path (API doc, back/cancel row, CLOSING row, EC-8)
- design/gdd/dialogue-conversion-system.md — EC-1 wording fix (Conversion UI → Village Map View)
- design/gdd/systems-index.md — row 13 → Designed; tracker 13/14; design docs started 13
- production/session-state/active.md — this file

## Cross-System Updates Pending
- design/gdd/dialogue-conversion-system.md — §Formulas recency state lifetime: update "When GSM calls NPCRegistry.clear_village()" to "When GSM emits village_cleared signal (DCS subscribes)"
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

## Next
Design HUD & Progress System GDD (system #14 — the LAST MVP GDD) — use /design-system hud-progress
Deps complete: Game State Manager ✅, Mobile Touch Framework ✅, Village Map View ✅ (screen-sharing + win/loss handoff contracts)
OQ-4 handoff: HUD & Progress System owns win/loss presentation (chronicle card, next-village transition, audio cue)
MVP systems remaining: HUD & Progress
