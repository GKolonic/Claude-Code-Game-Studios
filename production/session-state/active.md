# Session State — The Faithful / Divine Dominion

<!-- STATUS -->
Epic: Pre-Production
Feature: Design Documentation
Task: Portrait & Expression System GDD — In Design (skeleton created)
<!-- /STATUS -->

## Current Task
Completing full pre-production phase:
1. ✅ Engine configured — Godot 4.6 / GDScript / Mobile / Turn-based
2. ✅ Systems index written — 27 systems total (19 NPC layer + 8 macro layer)
3. ✅ Art Bible — complete (design/art/art-bible.md, all 9 sections)
4. 🔄 System GDDs — 8/14 MVP done:
   - ✅ Game Config (design/gdd/game-config.md)
   - ✅ NPC Trait Database (design/gdd/npc-trait-database.md)
   - ✅ Dialogue Content Database (design/gdd/dialogue-content-database.md)
   - ✅ Mobile Touch Framework (design/gdd/mobile-touch-framework.md)
   - ✅ NPC Character System (design/gdd/npc-character-system.md)
   - ✅ Conversion Logic Engine (design/gdd/conversion-logic-engine.md)
   - ✅ Dialogue & Conversion System (design/gdd/dialogue-conversion-system.md)
   - ✅ Game State Manager (design/gdd/game-state-manager.md) — COMPLETE
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

## Next
Design Rival Faith System GDD (system #9 in systems-index) — use /design-system rival-faith-system
Deps complete: NPC Character System ✅, Dialogue & Conversion System ✅
MVP systems remaining: Rival Faith System, Save & Load, Portrait & Expression, Conversion UI, Village Map View, HUD & Progress
