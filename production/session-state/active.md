# Session State — The Faithful / Divine Dominion

<!-- STATUS -->
Epic: Pre-Production
Feature: Design Documentation
Task: Conversion UI System GDD — Designed (complete draft approved)
<!-- /STATUS -->

## Current Task
Completing full pre-production phase:
1. ✅ Engine configured — Godot 4.6 / GDScript / Mobile / Turn-based
2. ✅ Systems index written — 27 systems total (19 NPC layer + 8 macro layer)
3. ✅ Art Bible — complete (design/art/art-bible.md, all 9 sections)
4. 🔄 System GDDs — 12/14 MVP done:
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

## Files Modified This Session
- .claude/docs/technical-preferences.md — Gameplay Model: Turn-based added
- design/gdd/game-concept.md — Two-Scale Game Architecture section added
- design/gdd/systems-index.md — Updated to 27 systems; macro-layer systems 20-27 added
- design/gdd/mobile-touch-framework.md — All 8 sections complete
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

## Next
Design Village Map View GDD (system #13 in systems-index) — use /design-system village-map-view
Deps complete: NPC Character System ✅, Mobile Touch Framework ✅
MVP systems remaining: Village Map View, HUD & Progress
