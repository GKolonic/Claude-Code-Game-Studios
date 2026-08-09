# HUD & Progress System

> **Status**: Designed
> **Author**: ux-designer + game-designer agents
> **Last Updated**: 2026-08-09
> **Implements Pillar**: Pillar 1 — Every Soul Has a Story; Pillar 3 — The Arc Must Feel Earned; Pillar 4 — History Writes Itself

## Overview

The HUD & Progress System is the persistent presentation layer of The Faithful: the quiet top strip the player lives under between conversations, and the voice that closes each village. It owns exactly two surfaces. First, the reserved top strip — a fixed band across the top of the safe area holding the faith power meter (the run-wide accumulator that gates the Missionary / Court / Crusade paths), the turn counter, and the rival-presence indicator. Second, the win/loss resolution presentation: per the Village Map View OQ-4 resolution, this system owns the chronicle card (parchment for a converted village, sober card for a turned-away one), the audio-cue contract, and the terminal transition to the next village (post-MVP) or title (MVP). The system is a scene, not an Autoload — one instance per playthrough, created at boot and kept alive across village transitions. It holds no game logic and no content: every value it shows is read from the Game State Manager, NPCRegistry, or a subscribed signal, and every string renders via `tr()`. Its only interactive element is the faith meter (tap to expand a milestone detail); the bottom-center strip is deliberately empty — End Turn belongs to the Village Map View.

The system exists because progress that cannot be read is not progress, and because a village that ends without a chronicle ends without meaning. The Game State Manager evaluates win and loss but never presents them; the Village Map View locks the map but does not speak. Someone must hold the run-wide numbers the player has earned, tell them what the thresholds promise, and say the words when a village resolves. That owner is this system — the scribe, not the judge.

## Player Fantasy

The HUD is the prophet's ledger, not their dashboard. It is working when the player glances up between conversations and feels the shape of the run: faith power climbing toward the Court at 250, the turn count as a quiet metronome, and — occasionally — the other prophet's crescent darkening on the right, a reminder that the world was attended while they were away. The numbers are permitted here because they are *earned things*, recorded in ink like a chronicle margin — but they must never feel like a scoreboard. The strip should feel like the page header of the story being written: what you have gathered, how far you have come, and whose shadow you feel.

The chronicle card is the fantasy's punctuation. When the last soul turns and the village is won, the card is not a victory screen — it is the historian's page closing: the village's name, the words *the village has turned to the faith*, the names of the converted written out one by one, the turn it took, the faith it yielded. The player should feel that the village existed because of the specific people on that list. When the village turns away, the card is sober — no shimmer, no fanfare — because loss in this game is not failure but a door that closed. The system fails if the strip ever reads like an RPG stat bar or the card like a modal dialog: it must read as a record, kept by someone who was there.

## Detailed Design

### Core Rules

**1. Screen ownership — the reserved strip.** The HUD owns the top strip of the safe area and nothing below it. Ownership is a hard layout contract with the Village Map View:

| Element | Owner | Location | Notes |
|---|---|---|---|
| Faith power meter | HUD | Top strip, left | Icon + numeral + micro progress line; tap expands detail |
| Turn counter | HUD | Top strip, center | "Turn N" via `tr()`; no interaction |
| Rival indicator | HUD | Top strip, right | Ash-grey crescent + QUIET/ACTIVE gauge; no numerals |
| Map surface + NPC markers | Village Map View | Map rect (below the strip) | No numbers anywhere on the map (VMV UI Req) |
| End Turn button | Village Map View | Bottom-center strip | The game's only primary action; HUD never places anything there |
| Conversation screen | Conversion UI | Full safe viewport, its own CanvasLayer above | Covers the HUD during a session |
| Win/loss chronicle card | HUD | Centered overlay on the HUD layer | Snapshot-driven; non-interactive |

- The strip's effective height is `HUD.get_top_strip_height_dp()` — base `GameConfig.hud.top_strip_height_dp` (default 56dp) × font-scale growth, plus the top safe-area inset. The Village Map View consumes this value as the top inset of its map rect (VMV F1; see Cross-System Updates item 2).
- The HUD registers **no** element in the bottom-center strip or anywhere below the strip. End Turn is VMV's (GSM turn gate's only player-facing surface — VMV Rule 9).
- Numerals are permitted **only** in the strip and the chronicle card. The map surface keeps its no-numbers discipline; this split is the HUD/VMV screen-sharing contract in spirit.

**2. Scene lifecycle.** The HUD is a scene (`hud_progress.tscn`), one instance per playthrough, created by the game boot / load sequence and **not freed on `village_cleared`** (unlike the Village Map View). It starts `HIDDEN`, renders on `village_ready` / `load_completed`, stays alive across villages (faith power is read from the GSM, which persists it), and returns to `HIDDEN` at resolution completion. On `load_completed(village_id)` it re-renders from the current GSM/NPCRegistry state: meter numeral, turn counter, gauge reset to QUIET (rival stamps are runtime-only — Rule 7).

**3. Signal contract — subscribed.** The HUD is observer-only: it calls no gameplay commands.

| Signal | Owner | Used for |
|---|---|---|
| `village_ready(village_id)` | GSM | Store village_id; render strip; `HIDDEN → ACTIVE` |
| `faith_power_changed(new_total)` | GSM | Meter value + micro line + threshold cue (Rule 4–5) |
| `turn_advancing(turn_number)` | GSM | `TURN_PROCESSING`; counter shows the advancing turn statically; detail panel auto-closes |
| `turn_advanced(turn_number)` | GSM | Counter swap; rival stamp prune + gauge recompute (Rule 7) |
| `village_won(turn_number)` | GSM | Snapshot-before-clear; `RESOLUTION_WON` card (Rule 9–10) |
| `village_lost(turn_number)` | GSM | Snapshot-before-clear; `RESOLUTION_LOST` card (Rule 9, 11) |
| `village_cleared()` | GSM | Clear transient state; `HIDDEN` (unless already in a RESOLUTION state — the card is snapshot-driven and unaffected) |
| `session_begun(npc_id)` / `session_complete()` | DCS | `SESSION_ACTIVE` in/out; observer only, never calls DCS |
| `rival_acted(target_npc_id, approach, outcome)` | Rival Faith System | Stamp + emphasis (Rule 7) — emitted on every rival action, including non-state-changing (RFS AC-07) |
| `load_completed(village_id)` | Save & Load | Re-render (Rule 2) |
| `tapped(target, position)` | MTF | Faith meter detail toggle; tap-away close (Rule 8) |

**4. Faith power meter.** The meter shows the run-wide accumulator (GSM Rule 4: `faith_power_per_conversion` = 10 per unique CONVERTED; never reset on `clear_village()`; persists across the playthrough). Display: a lit-flame icon + the current numeral + a thin progress line to the next `ProgressionConfig` unlock threshold (Missionary 100 / Court 250 / Crusade 500). Animation rules (studio restraint — minimal motion):
- On `faith_power_changed`: the numeral swaps **instantly** (no count-up, no tween). The only animated property is the micro progress line — a single 150ms linear tween to the new fraction.
- If `faith_power_changed` arrives while the HUD is covered by a session (`SESSION_ACTIVE`), the value updates silently with **no animation** — the strip is re-rendered instantly on reveal, never with a catch-up animation.
- All three thresholds are read from `ProgressionConfig` at display time (pull pattern — never cached).

**5. Milestone threshold cue.** When `faith_power` crosses a `ProgressionConfig` unlock threshold (100 / 250 / 500), the meter plays a single one-beat cue: the flame icon's halo flashes once (300ms, fixed authored) and the numeral's ink shifts to the milestone register (persistent after the crossing). No count-up, no particles, no repeat until the next threshold. The cue fires regardless of turn state (it is visible during `TURN_PROCESSING`); it is suppressed only while covered by a session. Reduced motion: the cue is a static ink-colour shift only — no flash.

**6. Turn counter.** The counter shows `Turn N` (`tr("HUD_TURN", [n])`), center of the strip, no interaction.
- On `turn_advancing(n)`: the counter displays the in-progress turn value **statically** (no animation) — the world on the map is the feedback.
- On `turn_advanced(n)`: the numeral swaps instantly with one optional 150ms ink-fade of the new value (fixed authored; reduced motion: instant swap, no fade).
- The HUD renders **no End Turn button and no turn-advance action anywhere** — that is VMV's bottom-center strip.

**7. Rival indicator.** The indicator makes the rival's presence legible without becoming an alarm.
- **Data:** a runtime deque of `(turn, …)` stamps. On each `rival_acted`, the HUD stamps `GameStateManager.get_turn_number()` at receipt (the pre-increment turn value, since the GSM increments at Step 8). On `turn_advanced(n)`, it prunes stamps with `turn <= n - W` where `W = GameConfig.rival.aggression_interval_turns`, then recomputes the rate (F2).
- **Form:** an ash-grey crescent glyph (visual language shared with the VMV rival marker — same glyph family) whose ink strength encodes state: `QUIET` (40% alpha) when no rival action in the window, `ACTIVE` (100% alpha) when the window contains at least one. No percentage, no count — the game's "you feel watched" language.
- On `rival_acted` the glyph darkens with a 300ms emphasis (fixed authored; reduced motion: static state change, no emphasis animation).
- Stamps are runtime-only and **not serialized**; after a load the gauge starts `QUIET` and rebuilds over the next window.

**8. Faith meter detail panel.** Tapping the faith meter (MTF `tapped`; meter registered always, lowest priority tier — MTF consuming table) expands a detail panel, per the MTF UI contract ("faith meter expansion animation on tapped").
- Panel: anchored just below the strip, HUD CanvasLayer, parchment card, fades in 200ms (fixed authored; reduced motion: instant). Content: current faith power numeral, next milestone name + threshold (e.g., `tr("HUD_MILESTONE_COURT")` — "Court — 250"), and the progress fraction `current / threshold` (numerals are the panel's purpose).
- **Non-blocking**: it is not registered and pushes no MTF blocking layer — map taps beneath it still work (opening a conversation covers the panel). It closes on: a second tap on the meter, any other MTF `tapped` target (HUD listens for `tapped(target)` and closes when `target != meter`), `session_begun`, `turn_advancing`, `village_won`/`village_lost`, or `village_cleared`.
- If all three paths are unlocked (faith_power ≥ 500), the panel shows `tr("HUD_ALL_PATHS_UNLOCKED")` and no threshold line.

**9. Resolution presentation — ownership and snapshot-before-clear.** Per VMV OQ-4, the HUD owns the win/loss presentation; VMV only locks the map (`RESOLVED`). The card is **snapshot-driven, never live**:
- In the `village_won(turn_number)` handler, **synchronously** capture a snapshot Dictionary: `{ village_id, village_name_key, turn_number, faith_power, converted_npc_ids: Array[String], converted_npc_names: Array[String], converted_count, total_npc_count }`, reading `NPCRegistry.get_npcs_by_belief(CONVERTED)` and `NPCRegistry.get_all_npcs()` at that instant (the registry is still fully populated — the clear sequence is deferred to `scene_changed` per GSM Rule 7).
- The card renders exclusively from the snapshot. A later `village_cleared` resets the registry; the card is unaffected. If the card must render after the registry has already cleared (pathological), it still works — it holds everything it needs.
- `village_lost(turn_number)` captures the same snapshot shape (converted list may be short or empty; `converted_count` and `total_npc_count` still read live) and presents the LOST card.
- No NPCRegistry or GSM mutation is ever made by the HUD.

**10. WON chronicle card.** On `village_won`: enter `RESOLUTION_WON`; render the card centered on the HUD layer above the dimmed map (VMV is already `RESOLVED`):
- Parchment card (Art Bible parchment register; see Visual/Audio).
- Village name (from `village_name_key` = `tr("VILLAGE_" + village_id)`).
- Headline: `tr("CHRONICLE_WON_HEADLINE")` — "The village has turned to the faith".
- The converts' names, written one per line (from `converted_npc_names`).
- A chronicle line: turn count and faith power (e.g., `tr("CHRONICLE_WON_SUMMARY", [turn_number, faith_power])`) and the souls line from F1 (`tr("CHRONICLE_SOULS", [converted_count, total_npc_count])` — "9 of 12 souls turned").
- Envelope per F3: fade-in 250ms, hold `chronicle_card_hold_sec` (4.0s), fade 400ms. Non-interactive — no tap-to-dismiss at MVP (OQ-6).
- After the fade completes: emit `resolution_complete(WON, snapshot)` and enter `GAME_OVER` — at MVP this routes to return-to-title (single-village MVP); the next-village transition is the post-MVP branch of the same state (Rule 13).

**11. LOST sober card.** On `village_lost`: enter `RESOLUTION_LOST`; render the sober card (no shimmer, cooler parchment register):
- Village name, headline `tr("CHRONICLE_LOST_HEADLINE")` — "The village has turned away".
- A restrained chronicle line: souls turned + turn count (e.g., `tr("CHRONICLE_LOST_SUMMARY", [converted_count, turn_number])`).
- Same F3 envelope (shared hold/fade defaults). Non-interactive.
- After the fade: `resolution_complete(LOST, snapshot)` → `GAME_OVER` → the MVP game-over presentation (OQ-5): a brief final-tally frame (run faith power, villages won 0/1) for 2.0s (fixed authored), then the router returns to title.

**12. Audio cue contract.** The HUD plays **no audio**. Cue intent (consumed by the Audio System, system #16, which subscribes to the GSM signals directly per the GSM interactions table):
- `village_won` → a warm win chime (`music_village_won`) at card appearance (same frame as the signal).
- `village_lost` → a low, sober tone (`music_village_lost`).
- The MTF tap chime on the faith meter is framework-level (MTF V/A). The conversion chime fade timing against `ink_bleed_duration_ms` is the VMV/Audio contract (VMV appendix item 9), not the HUD's.

**13. `GAME_OVER` / RETURNING (terminal).** A single terminal state covering both resolutions:
- MVP: after the card (and the LOST tally frame), emit `resolution_complete(outcome, snapshot)`; the boot/router returns to title (or a new run). Faith power persistence on a new run is the GSM's domain, not the HUD's.
- Post-MVP (macro layer): the same signal is the seam the Region & World Map flow consumes to transition to the next village. The HUD's contract ends at `resolution_complete`.

**14. MTF registration hygiene.** The faith meter is the HUD's only registered target: registered at strip render, unregistered on `village_won`/`village_lost` (resolution is locked), `village_cleared`, and teardown — mirroring VMV/Conversion UI hygiene. While a session is open, the meter remains registered but is suppressed by the Conversion UI's blocking layer (and visually covered) — no unregister/re-register churn per session. The HUD never pushes or pops a blocking layer (MTF EC-7 hygiene; the Conversion UI owns the modal stack).

**15. No content ownership.** Every string renders via `tr()` (engine best practice: autowrap enabled, `TextServer.AUTOWRAP_WORD_SMART`). The HUD contains no authored copy and no gameplay numbers of its own — faith power and thresholds come from the GSM / `ProgressionConfig`; the rival window comes from `RivalFaithConfig`.

**Exposed API:**
```gdscript
# HudProgress (scene root — not Autoload)

# Queries (consumed by Village Map View F1)
func get_top_strip_height_dp() -> float
# Effective strip height: (base hud.top_strip_height_dp x font-scale growth) + top safe inset.

# Signals
signal resolution_complete(outcome: String, snapshot: Dictionary)
# outcome ∈ {"WON", "LOST"}; emitted after the chronicle card fade.
# MVP: router returns to title. Post-MVP: macro-layer next-village transition seam.
```

### States and Transitions

| State | Description | GSM mapping |
|---|---|---|
| `HIDDEN` | No strip rendered. Before first `village_ready`, between resolution completion and the next load, or after `village_cleared` with no presentation. | `UNINITIALIZED` / pre-boot |
| `ACTIVE` | Strip visible; map interactive. Meter registered. | `IDLE` |
| `SESSION_ACTIVE` | Conversation scene alive above the HUD; strip covered. Values update silently (Rule 4). | `IN_SESSION` |
| `TURN_PROCESSING` | Turn sequence running; strip visible; counter static; panel closed; meter still registered (harmless informational taps). | `TURN_ADVANCING` |
| `RESOLUTION_WON` | WON card shown from snapshot; strip dimmed behind it; meter unregistered. | `VILLAGE_WON` |
| `RESOLUTION_LOST` | LOST card shown from snapshot; strip dimmed; meter unregistered. | `VILLAGE_LOST` |
| `GAME_OVER` | Terminal — run complete. Emits `resolution_complete`; MVP routes to title; post-MVP RETURNING (next-village) branch. | post-clear |

| From | To | Trigger |
|---|---|---|
| `HIDDEN` | `ACTIVE` | `village_ready` or `load_completed` |
| `ACTIVE` | `SESSION_ACTIVE` | `session_begun` (covered by conversation scene) |
| `SESSION_ACTIVE` | `ACTIVE` | `session_complete` (strip re-renders instantly — no catch-up animation) |
| `ACTIVE` | `TURN_PROCESSING` | `turn_advancing` |
| `TURN_PROCESSING` | `ACTIVE` | `turn_advanced` (counter swap, stamp prune, gauge recompute) |
| `ACTIVE` | `RESOLUTION_WON` | `village_won` (defensive — normal path is via `TURN_PROCESSING`) |
| `TURN_PROCESSING` | `RESOLUTION_WON` | `village_won` |
| `ACTIVE` | `RESOLUTION_LOST` | `village_lost` (defensive) |
| `TURN_PROCESSING` | `RESOLUTION_LOST` | `village_lost` |
| `RESOLUTION_WON` | `GAME_OVER` | F3 envelope completes → `resolution_complete(WON, snapshot)` |
| `RESOLUTION_LOST` | `GAME_OVER` | F3 envelope completes (+ MVP tally frame) → `resolution_complete(LOST, snapshot)` |
| `GAME_OVER` | `HIDDEN` | Router returns to title / next-run boot |
| any | `HIDDEN` (defensive) | `village_cleared` with no active RESOLUTION state (unreachable in normal play — the clear follows the resolution) |

*Invariant:* `SESSION_ACTIVE` never transitions directly to a RESOLUTION state — win/loss resolve only during turn processing, never mid-session (Conversion UI EC-8 precedent).

### Interactions with Other Systems

| System | Relationship | Interface |
|---|---|---|
| Game State Manager | Upstream — data + lifecycle | Subscribes: `village_ready`, `faith_power_changed`, `turn_advancing`, `turn_advanced`, `village_won`, `village_lost`, `village_cleared`. Queries: `get_faith_power()`, `get_turn_number()`, `get_gsm_state()`. Never calls commands. |
| Mobile Touch Framework | Upstream — input | `register()`/`unregister()` (faith meter only); `tapped`; suppressed by the Conversion UI's blocking layer during sessions; never pushes a blocking layer. |
| NPC Character System | Upstream — snapshot reads | `get_npcs_by_belief(CONVERTED)`, `get_all_npcs()`, `get_npc(id)` for display names — **only** inside the `village_won`/`village_lost` handlers (snapshot). Never subscribes to `npc_state_changed`. |
| Game Config | Upstream — tuning | `ProgressionConfig` (unlock thresholds, milestone cue targets), `RivalFaithConfig.aggression_interval_turns` (F2 window), `HUDConfig` (9th domain — see Cross-System Updates item 1). Pull pattern, read at call time. |
| Rival Faith System | Upstream — signal | Subscribes `rival_acted` (Rule 7). Its downstream deferral ("if a rival activity indicator is shown") resolves: shown. |
| Dialogue & Conversion System | Peer — observer only | Subscribes `session_begun` / `session_complete` for state. Never calls DCS (GSM precedent: signal-only). |
| Village Map View | Peer — screen share + resolution handoff | VMV consumes `get_top_strip_height_dp()` (F1 top inset) and hands off at `village_won`/`village_lost` (already `RESOLVED`). No other interface. |
| Conversion UI | Peer — covered | The conversation scene's CanvasLayer renders above the HUD layer; no direct interface. |
| Save & Load System | Peer — persistence | Subscribes `load_completed` to re-render (Rule 2). HUD state (rival stamps, panel visibility) is **not serialized**; a WIN/LOST save restores per GSM EC-10 (clear re-trigger) without replaying the card. |
| Audio System | Downstream (system #16, not authored) | Consumes the cue contract (Rule 12); subscribes to GSM signals directly. No HUD-owned audio. |
| Multi-path Expansion System | Prospective (Alpha) | The HUD displays this system's unlock thresholds from `ProgressionConfig`; no interface at MVP. |
| Accessibility System | Upstream (provisional, Alpha) | `reduced_motion_enabled` (default `false` if absent — P&E Rule 12 precedent); system font-scale factor for strip growth (Rule 1, EC-5). |
| Godot Engine | Hard | `Control`, `Label`, `ColorRect`, `Tween`, `CanvasLayer`, `ScrollContainer` (card list), `DisplayServer.get_display_safe_area()` (verify at implementation — OQ-7), `tr()`, `TextServer.AUTOWRAP_WORD_SMART`. 4.6 dual-focus note: touch-driven; keyboard focus out of scope at MVP but must not be broken by `mouse_filter` misuse. |

## Formulas

### Formula 1 — Conversion Fraction (chronicle display)

The conversion fraction formula is defined as:

```
conversion_fraction = converted_count / total_npc_count
```

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `converted_count` | Converted NPC count | int | [0, `total_npc_count`] | `NPCRegistry.get_npcs_by_belief(CONVERTED).size()`, read once in the `village_won`/`village_lost` snapshot handler — the same live value the GSM evaluated at Step 6 |
| `total_npc_count` | Village NPC count | int | [1, ~20] | `NPCRegistry.get_all_npcs().size()` at snapshot time; matches the GSM's cached value (the registry is static between `initialize_village()` and `clear_village()`) |
| `conversion_fraction` | Display fraction | float | [0.0, 1.0] | Rendered as the chronicle phrase `"N of M souls"` — **never** as a percentage numeral |

**Output range:** [0.0, 1.0]. The GSM owns win/loss evaluation (its Formula 1, `>=` inclusive); this formula is a read-only re-derivation for the card's souls line. **Edge case — `total_npc_count = 0`:** unreachable — zero-NPC villages are rejected at `initialize_village()` (GSM EC-1).

**Worked example — 9 of 12:** `9 / 12 = 0.75` → card line: "9 of 12 souls turned". The fraction is displayed as a chronicle phrase, not a dashboard percentage.

---

### Formula 2 — Rival Activity Rate

The rival activity rate formula is defined as:

```
W      = GameConfig.rival.aggression_interval_turns          # rolling window, in turns
stamp: on rival_acted: append (turn_i)  where turn_i = GameStateManager.get_turn_number() at receipt
prune: on turn_advanced(n): drop stamps where turn_i <= n - W
count  = clamp(stamps.size(), 0, W)
rate   = count / W
gauge  = QUIET  if count == 0
         ACTIVE if count >= 1
```

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `W` | Window length | int | [2, 20] | `RivalFaithConfig.aggression_interval_turns`. Default **6** per game-config.md (RFS GDD lists 3 — discrepancy flagged for `/consistency-check`; the HUD reads the field at call time). |
| `turn_i` | Rival action turn | int | [1, n] | Pre-increment turn value stamped at `rival_acted` receipt (GSM increments at Step 8, after Step 5) |
| `n` | Advanced turn | int | [1, ∞) | Post-increment value from `turn_advanced(n)` |
| `count` | Actions in window | int | [0, W] | Clamped defensively; at MVP ≤ 1 (one rival, at most one target per action turn, interval ≥ 2) |
| `rate` | Activity rate | float | [0.0, 1.0] | `count / W` — general form; a fine-grained pressure gauge becomes meaningful post-MVP (multi-rival, RFS OQ-01, or interval tuning) |
| `gauge` | Indicator state | enum | {QUIET, ACTIVE} | QUIET = no rival action in the window; ACTIVE = ≥ 1 |

**Output range:** gauge ∈ {QUIET, ACTIVE}. **Design note:** with the MVP single-rival config the rate is intentionally near-binary — the indicator is a *presence* gauge ("the other prophet was here"), not a pressure percentage, matching the Rival Faith GDD's "pressure gauge, not an enemy" language. The formula is defined generally so post-MVP config changes produce a finer gauge without code change.

**Worked example — default W = 6:** rival acts during turn 6 and turn 12 processing (stamps 6, 12). At `turn_advanced(13)`: prune `turn_i <= 13 - 6 = 7` → drop 6, keep 12 → `count = 1`, `rate = 1/6` → **ACTIVE**. If no `rival_acted` fires for six consecutive processed turns, `count = 0` → **QUIET**.

---

### Formula 3 — Chronicle Card Alpha Envelope

The chronicle card alpha envelope formula is defined as:

```
D_in    = 0.25s                                     # authored fade-in
D_hold  = GameConfig.hud.chronicle_card_hold_sec    # 4.0s default
D_fade  = GameConfig.hud.chronicle_card_fade_ms / 1000.0   # 0.4s default
D_total = D_in + D_hold + D_fade

a(t) = t / D_in                                for 0 <= t < D_in
       1                                      for D_in <= t < D_in + D_hold
       1 - (t - D_in - D_hold) / D_fade        for D_in + D_hold <= t <= D_total
       0                                      for t > D_total
```

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `t` | Elapsed since card show | float | ≥ 0 | Seconds since the card began rendering |
| `D_in` | Fade-in duration | float | [0.1, 0.4] | Authored 250ms — the card *appears*, it does not slide |
| `D_hold` | Hold duration | float | [3.0, 6.0] | `HUDConfig.chronicle_card_hold_sec`, default **4.0s** |
| `D_fade` | Fade-out duration | float | [0.2, 0.8] | `HUDConfig.chronicle_card_fade_ms`, default **400ms** |
| `D_total` | Card lifetime | float | > 0 | 4.65s at defaults |
| `a(t)` | Card alpha | float | [0.0, 1.0] | Applied as `modulate.a`; linear ramps only |

**Output range:** [0.0, 1.0]. Applied identically to the WON and LOST cards (shared hold/fade defaults). **Reduced-motion override:** skip `D_in` (card appears at `a = 1.0` statically), hold, then fade over `HUDConfig.reduced_motion_card_fade_ms` (default 100ms); the parchment shimmer is disabled. The card is non-interactive in all cases — no tap-to-dismiss at MVP (OQ-6).

## Edge Cases

**EC-1. Notch / safe-area change (split-screen, focus-in, inset change).** The strip re-lays out against the current `DisplayServer.get_display_safe_area()` and the meter re-registers (MTF re-registration is idempotent — Conversion UI EC-13 precedent). `get_top_strip_height_dp()` returns the new effective height; the VMV re-runs its F1 inset on its own focus-in path, so markers never slip under the strip.

**EC-2. Reduced motion enabled.** Faith-power numeral swaps instantly (no progress-line tween — the line snaps); milestone cue is a static ink-colour shift only; turn-counter ink-fade skipped; rival emphasis is a static state change; detail panel appears instantly; chronicle card snaps in, holds, fades over `reduced_motion_card_fade_ms`, and the parchment shimmer is disabled (no shimmer, per the Accessibility precedent — colour is never the sole signal; audio gives a second channel).

**EC-3. Rapid turn transitions (exhaustion auto-advance chain).** `turn_advancing` can follow `conversation_closed` on the same frame, and turns can chain. The HUD sequences `TURN_PROCESSING → ACTIVE` without rendering an intermediate animated frame; the counter swaps once per `turn_advanced`; the detail panel (already auto-closed on `turn_advancing`) does not reopen. No flicker, no double swap.

**EC-4. App backgrounded mid-turn or mid-resolution.** On focus-out, card hold timers suspend; on focus-in they resume from the current state and the layout recomputes against the current safe area (Conversion UI EC-9 precedent). If killed: Save & Load restores `TURN_ADVANCING → IDLE` (GSM EC-9) or re-triggers the WIN/LOST clear (GSM EC-10); the HUD re-inits from `load_completed` and **does not replay the chronicle card** — the resolution presentation is one-shot and not serialized (Cross-System Updates item 7).

**EC-5. Font scaling (Accessibility System, Alpha).** Labels use autowrap off for short numerals ("Turn 12", "90") and smart-wrap for phrases. The strip's effective height grows with the system font-scale factor (`get_top_strip_height_dp()`), so content never clips and the VMV inset stays correct. Defensive max: if scaled content exceeds the strip's growth budget, the meter icon shrinks first (icon ≥ 24dp floor), never the numeral.

**EC-6. Long localized strings.** Card text (village name, headline, milestone names, chronicle lines) autowraps (`AUTOWRAP_WORD_SMART`) and the card sizes to its content up to the safe-area margins. Strip phrases are minimal ("Turn N" via `tr` placeholders); milestone names in the detail panel wrap. No string is ever scaled down or clipped — the card scrolls if needed (EC-7).

**EC-7. 12-NPC convert list overflow on the WON card.** The converts' name list sits in a `ScrollContainer` with a max height; the scrollbar appears only when the list overflows. All 12 names remain reachable. User-driven scrolling is unaffected by reduced motion.

**EC-8. `faith_power_changed` arrives while covered (`SESSION_ACTIVE`).** Faith power awards fire mid-session (GSM awards on the CONVERTED transition during `apply_conversion_outcome`). The HUD updates the stored value silently — no animation, no cue — and re-renders the strip instantly on reveal (Rule 4).

**EC-9. `village_won`/`village_lost` while HUD is `ACTIVE` (not `TURN_PROCESSING`).** Unreachable in normal play (win/loss evaluate only at GSM Steps 6–7). Defensive: the resolution handler accepts either source state, snapshots, and presents normally — the snapshot is state-independent.

**EC-10. `rival_acted` fires on the same turn the village resolves.** The rival acts at Step 5, win/loss at Steps 6–7. The stamp is recorded, then the HUD transitions to the RESOLUTION state; the indicator is covered by the card and the stamp is discarded at `village_cleared` / next run. Harmless — no special handling beyond honoring state guards.

**EC-11. Milestone cue collides with resolution.** A faith-power award can cross a threshold at Step 4 of the resolving turn (spread conversions). The cue fires during `TURN_PROCESSING` (visible), then the card covers it. No queue, no replay after resolution.

**EC-12. Stray taps during resolution.** The card is non-interactive and no HUD target is registered during `RESOLUTION_WON`/`RESOLUTION_LOST`/`GAME_OVER`; MTF reports a clean miss (silence + no haptic — MTF V/A). VMV is already `RESOLVED` and locked.

## Dependencies

### Systems This System Depends On

| System | GDD | Type | Interface |
|---|---|---|---|
| Game State Manager | `game-state-manager.md` | **Hard** | Signals `village_ready`, `faith_power_changed`, `turn_advancing`, `turn_advanced`, `village_won`, `village_lost`, `village_cleared`; queries `get_faith_power()`, `get_turn_number()`, `get_gsm_state()`. |
| Mobile Touch Framework | `mobile-touch-framework.md` | **Hard** | `register()`/`unregister()` (meter only), `tapped`; blocking-layer suppression during sessions. |
| NPC Character System | `npc-character-system.md` | **Hard** (snapshot only) | `get_npcs_by_belief(CONVERTED)`, `get_all_npcs()`, `get_npc(id)` — read exclusively inside the resolution handlers. |
| Game Config | `game-config.md` | **Hard** | `ProgressionConfig` thresholds; `RivalFaithConfig.aggression_interval_turns`; **`HUDConfig` (9th domain — Cross-System Updates item 1)**. |
| Rival Faith System | `rival-faith-system.md` | **Hard** (signal) | `rival_acted(npc_id, approach, outcome)` — the indicator contract (Rule 7). |
| Village Map View | `village-map-view.md` | **Hard** (layout + handoff) | Consumes `get_top_strip_height_dp()` (F1 inset); hands off resolution at `village_won`/`village_lost`. |
| Save & Load System | `save-load-system.md` | **Hard** (re-init) | `load_completed(village_id)` to re-render (Rule 2). |
| Dialogue & Conversion System | `dialogue-conversion-system.md` | **Soft** (observer) | `session_begun` / `session_complete` for state. If absent, HUD state degrades to polling `get_gsm_state()` on GSM signals only. |
| Accessibility System | *(GDD pending — Alpha)* | **Soft (provisional)** | `reduced_motion_enabled` (default `false` if absent — P&E Rule 12 precedent); font-scale factor. |
| Godot Engine | `docs/engine-reference/godot/` | **Hard** | `Control`, `Label`, `ColorRect`, `Tween`, `CanvasLayer`, `ScrollContainer`, `DisplayServer.get_display_safe_area()` (verify at implementation — OQ-7), `tr()`. Verified against the pinned 4.6 reference; no post-cutoff APIs used. |

### Systems That Depend On This System

| System | GDD | What It Uses |
|---|---|---|
| Village Map View | `village-map-view.md` | Its top-strip inset resolves to `HUD.get_top_strip_height_dp()`; its OQ-4 resolution presentation handoff lands here (chronicle card, next-village transition, audio cue — VMV only locks the map). |
| Audio System | *(GDD pending — #16)* | Cue contract (Rule 12): win chime on `village_won`, low tone on `village_lost` — subscribed from GSM directly. |
| Save & Load System | `save-load-system.md` | Confirms HUD state is not serialized and the resolution presentation is not replayed on load (Cross-System Updates item 7). |
| Tutorial & Onboarding | *(GDD pending)* | May observe `resolution_complete` as a non-blocking progression hook (post-MVP). |
| Multi-path Expansion System | *(GDD pending — Alpha)* | The HUD renders its unlock thresholds from `ProgressionConfig`; no interface at MVP. |

### Architectural Notes

- The HUD is a **scene, not an Autoload** — one instance per playthrough, mirroring the VMV/Conversion UI ownership model, but kept alive across village clears (faith power is run-wide).
- **No persistent state.** Everything renders from GSM/NPCRegistry reads + signals; the only local runtime state is the rival stamp deque, the current gauge, the panel visibility, and the (transient) resolution snapshot — all cleared or rebuilt on the appropriate lifecycle signal.
- **Observer-only toward gameplay.** The HUD calls zero gameplay commands — the only framework call it makes is `register()`/`unregister()` for the meter.
- **Snapshot-driven card.** The resolution card never touches live NPCRegistry after the capture — it renders from the snapshot Dictionary and survives the clear sequence by construction.

## Tuning Knobs

### New domain — `GameConfig.hud` (`HUDConfig`, 9th config domain — added by this GDD)

| Knob | Field | Default | Safe Range | Effect | What Breaks at Extremes |
|---|---|---|---|---|---|
| Top strip height | `top_strip_height_dp` | 56 | 44–64 | Effective strip height base (before font-scale growth); VMV F1's top inset. | Below 44: meter/turn/rival collide and targets drop under the 44dp floor. Above 64: shrinks the map rect; 12 thumbnails crowd on min devices. |
| Card hold | `chronicle_card_hold_sec` | 4.0 | 3.0–6.0 | Plateau of the chronicle card envelope (F3). | Below 3.0: the names list can't be read. Above 6.0: holds the locked map hostage. |
| Card fade-out | `chronicle_card_fade_ms` | 400 | 200–800 | Fade-out duration (F3). | Below 200: pops out. Above 800: feels like a slow curtain, not a page closing. |
| Card fade-in | `chronicle_card_fade_in_ms` | 250 | 100–400 | Fade-in duration (F3 `D_in`). | Below 100: blink. Above 400: delays the headline read. |
| Reduced-motion card fade | `reduced_motion_card_fade_ms` | 100 | 0–500 | Card fade when reduced motion is enabled (F3 override). | 0 = instant clear (colour/ink only). Above 500 reintroduces motion. |

### Consumed from existing config (owned by Game Config GDD)

| Knob | Field | Default | Effect |
|---|---|---|---|
| Unlock thresholds | `ProgressionConfig.missionary_unlock_threshold` / `court_unlock_threshold` / `crusade_unlock_threshold` | 100 / 250 / 500 | Meter milestone line + cue targets (Rules 4–5). |
| Rival window | `RivalFaithConfig.aggression_interval_turns` | 6 | F2 window `W`. |

### Fixed authored values (not config at MVP — sourced from this GDD / Art Bible)

| Value | Value | Source |
|---|---|---|
| Strip scrim alpha | ≈0.10 dark parchment scrim over the map | This GDD |
| Milestone cue flash | 300ms halo flash (static under reduced motion) | This GDD |
| Rival emphasis | 300ms crescent emphasis on `rival_acted` | This GDD |
| Turn-counter ink-fade | 150ms on the new numeral | This GDD |
| Detail panel fade | 200ms cross-dissolve | This GDD |
| LOST tally frame | 2.0s final-tally hold before title return | This GDD (OQ-5) |

**Promotion candidates:** if playtest needs live pacing control, promote the milestone cue, rival emphasis, and panel/tally timings into `HUDConfig` — mirrors the Conversion UI lighting-promotion precedent (Conversion UI OQ-2).

### Interaction warning

`top_strip_height_dp` × `map_grid_rows/columns` (VMV): a taller strip shrinks the VMV map rect (F1 inset). At 64dp + large font scale on the minimum 360×640dp logical size, verify the 4×6 grid still gives ≥ ~88dp cells for the 80dp thumbnails before raising the strip height. The HUD's dynamic `get_top_strip_height_dp()` keeps the two systems consistent by construction — never hardcode the inset in VMV.

## Visual/Audio Requirements

| Element | Requirement |
|---|---|
| Top strip | A reserved band across the safe-area top at `get_top_strip_height_dp()`. Quiet dark-parchment scrim at ≈0.10 alpha for legibility over the map — a page header, not a chrome bar. All elements placed, no entrance animation (Art Bible Principle 1 — Weight Before Flash). |
| Faith meter | Lit-flame icon + ink numeral + micro progress line to the next threshold. The progress line is the strip's only animated property (150ms linear tween; reduced motion: snap). Milestone crossing: 300ms halo flash + persistent ink-colour shift. |
| Turn counter | Ink numeral "Turn N", center. Instant swap + optional 150ms ink-fade of the new value. |
| Rival indicator | Ash-grey crescent glyph (16×16dp, same glyph family as the VMV rival marker) whose ink strength encodes QUIET (40%) / ACTIVE (100%); 300ms emphasis on `rival_acted`. No numerals, no badge shape — reads as "the other prophet was here", not an alarm (RFS OQ-02: anonymous at MVP is intentional). |
| Faith detail panel | Small parchment card under the strip, 200ms fade; milestone name + threshold + progress fraction. |
| WON chronicle card | Parchment card (Art Bible parchment register — same family as the map). Ink typography: village name (small caps), headline "The village has turned to the faith" (display face), converts' names (one per line, body face), chronicle line (turn + faith power + "N of M souls"). Subtle parchment shimmer; **disabled under reduced motion** (no shimmer). F3 envelope. |
| LOST sober card | Sober card: cooler parchment register, no shimmer, no ornament. Headline "The village has turned away". Restrained chronicle line. F3 envelope. |
| Audio | **The HUD plays no audio.** Cue contract for the Audio System (#16): `village_won` → warm win chime (`music_village_won`) at card appearance; `village_lost` → low, sober tone (`music_village_lost`). MTF tap chime on the meter is framework-level. |

> 📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:hud-progress-system` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

> 📌 **UX Flag — HUD & Progress System**: This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for `design/ux/hud.md` **before** writing epics. Stories that reference UI should cite `design/ux/hud.md`, not the GDD directly.

## UI Requirements

| Element | Constraint |
|---|---|
| Strip | Top safe-area band at `get_top_strip_height_dp()`; full safe-area width; nothing below the strip; **nothing in the bottom-center strip** (End Turn zone is VMV's, MTF `SAFE_ZONE_BOTTOM_FRACTION`). |
| Faith meter | Left; ≥ 44×44dp tap target (MTF floor; inflated by F-2 if smaller); registered always at lowest priority tier; unregistered at resolution/HIDDEN. |
| Turn counter | Center; non-interactive; `tr("HUD_TURN", [n])`. |
| Rival indicator | Right; non-interactive; no numerals. |
| Detail panel | Anchored below the strip; non-blocking (no MTF layer, no registration); closes per Rule 8. |
| Chronicle card | Centered overlay; non-interactive; snapshot-driven; autowrap on; converts' list in a defensive `ScrollContainer`. |
| Localisation | All strings via `tr()`; placeholders for numerals; autowrap `AUTOWRAP_WORD_SMART`; no hardcoded copy. |
| Safe areas | `DisplayServer.get_display_safe_area()` for the strip rect (verify at implementation — OQ-7; fallback Viewport insets / notch table, VMV OQ-1 precedent); strip height includes the top safe inset. |
| Reduced motion | All overrides per EC-2: instant value swaps, static card appearance (100ms fade), no shimmer, no flash animations. |
| Font scaling | Strip grows with system font scale via `get_top_strip_height_dp()`; numerals never clip; icon shrinks first (≥ 24dp floor). |
| Numbers discipline | Numerals permitted only in the strip, the detail panel, and the chronicle card. The map surface never shows numbers (VMV contract). |

## Acceptance Criteria

**AC-01 — Reserved strip layout.** GIVEN a village on the minimum logical size 360×640dp, WHEN `village_ready` fires, THEN the strip occupies the safe-area top at `get_top_strip_height_dp()`, no HUD element renders below the strip, no HUD element renders in the bottom-center strip, and no VMV marker overlaps the strip (verified by screenshot comparison against VMV AC-01).

**AC-02 — Faith meter correctness.** GIVEN GSM emits `faith_power_changed(90)`, WHEN the HUD receives it, THEN the meter numeral reads 90 within one frame and the progress line tweens to the 90/100 fraction in 150ms ± 16ms. GIVEN the same signal while covered by a session, THEN the numeral updates with no tween and the strip re-renders correctly on `session_complete`.

**AC-03 — Milestone cue.** GIVEN faith power at 90 and threshold `missionary_unlock_threshold = 100`, WHEN one more conversion raises it to 100, THEN exactly one 300ms halo cue fires, the numeral ink shifts, and no further cue fires until the next threshold (250).

**AC-04 — Turn counter.** GIVEN `turn_advanced(4)`, THEN the counter displays "Turn 4" (instant swap, optional 150ms ink-fade). GIVEN `turn_advancing`, THEN the counter is static (no animation) for the duration of turn processing.

**AC-05 — End Turn not owned.** GIVEN any HUD state, THEN the HUD scene contains no End Turn element and no registered target in the bottom-center strip (verified by MTF registry inspection and screenshot review).

**AC-06 — Rival indicator math.** GIVEN `aggression_interval_turns = 6` and rival stamps at turns 6 and 12, WHEN `turn_advanced(13)` fires, THEN the stamp at 6 is pruned, `count = 1`, and the gauge reads ACTIVE. GIVEN no `rival_acted` in the last 6 processed turns, THEN the gauge reads QUIET. No numeral is ever rendered for either state.

**AC-07 — Rival emphasis on non-state-changing actions.** GIVEN `rival_acted(npc_id, approach, RESISTED)` (no belief change — RFS AC-07), THEN the HUD stamps the action, the crescent emphasizes (300ms), and the gauge recomputes — the indicator is not suppressed.

**AC-08 — Faith meter detail panel.** GIVEN `ACTIVE` and a tap on the meter, THEN the panel fades in (200ms) showing current faith power, the next milestone (name + threshold), and the progress fraction. The panel closes on a second meter tap, on any other MTF `tapped`, on `session_begun`, on `turn_advancing`, and on resolution. No blocking layer is pushed or popped.

**AC-09 — WON card content.** GIVEN `village_won(7)` with 9 of 12 NPCs converted, THEN the card shows the village name, the headline "The village has turned to the faith", the 9 converts' names (one per line), the turn count 7, the faith power total, and the souls line "9 of 12 souls turned".

**AC-10 — Snapshot-before-clear.** GIVEN `village_won` fires and the clear sequence runs (`village_clearing` → `village_cleared`, NPCRegistry reset), THEN the card still renders the full captured snapshot (names, turn, faith power) — verified by a synthetic test that fires `village_cleared` immediately after `village_won`. The HUD never reads NPCRegistry after the capture.

**AC-11 — WON timing.** GIVEN defaults, WHEN the card appears, THEN it fades in 250ms ± 16ms, holds at `a = 1.0` for 4.0s ± 100ms, fades out over 400ms ± 32ms, and emits `resolution_complete(WON, snapshot)` exactly once.

**AC-12 — LOST card.** GIVEN `village_lost(9)` with 6 of 12 converted, THEN the sober card shows the village name, the headline "The village has turned away", and a chronicle line with 6 souls and turn 9; it holds/fades per F3, then the MVP tally frame holds 2.0s, then `resolution_complete(LOST, snapshot)` fires exactly once.

**AC-13 — Audio hooks.** GIVEN `village_won` fires, THEN the Audio System receives it and plays the win chime at card appearance (integration test). GIVEN `village_lost`, THEN the low tone plays. The HUD scene itself plays no audio (verified by instrumentation — zero AudioStreamPlayer nodes owned by the HUD).

**AC-14 — Reduced motion.** GIVEN `AccessibilitySystem.reduced_motion_enabled = true`, THEN the faith numeral and micro line swap instantly, the milestone cue is a static ink shift, the turn counter swaps instantly, the rival emphasis is static, the panel appears instantly, the card snaps in and fades over `reduced_motion_card_fade_ms`, and no shimmer renders.

**AC-15 — Safe-area recompute.** GIVEN a focus-in with a changed safe area (split-screen), THEN the strip re-lays out against the new inset, `get_top_strip_height_dp()` returns the new value, and the meter remains registered (idempotent).

**AC-16 — Long strings.** GIVEN the longest supported localized strings (village name, headline, milestone names), THEN no label clips, the card sizes within safe-area margins, and the strip numerals remain fully visible.

**AC-17 — Convert list overflow.** GIVEN a 12-NPC village fully converted, WHEN the WON card renders, THEN a scrollbar appears only if the names exceed the card's content area and all 12 names are reachable by scrolling.

**AC-18 — Backgrounding.** GIVEN the card is mid-hold when the app is backgrounded, THEN the hold timer suspends and resumes from the same state on focus-in. GIVEN a process kill during resolution, THEN a fresh launch restores per Save & Load (no card replay; `load_completed` re-inits the strip).

**AC-19 — Font scaling.** GIVEN system font scale ×1.3, THEN the strip grows to `56 × 1.3` (plus top inset), the VMV inset query returns the grown value, and no numeral clips.

**AC-20 — Registration hygiene.** GIVEN the strip rendered, THEN exactly one target (the faith meter) is registered. GIVEN `village_won`, THEN the meter is unregistered; GIVEN `village_cleared` / teardown, THEN no HUD registration remains (verified by registry count).

**AC-21 — Terminal state.** GIVEN the WON or LOST card fade completes, THEN the HUD enters `GAME_OVER` and emits `resolution_complete`; the router returns to title at MVP (no second village exists). The HUD holds no state after `resolution_complete` beyond the snapshot (which the router may consume).

**AC-22 — Covered during sessions.** GIVEN `SESSION_ACTIVE`, THEN no HUD element renders above the conversation scene's CanvasLayer (verified by layer inspection), and the meter receives no `tapped` signals while the Conversion UI blocking layer is active.

## Open Questions — Resolved

**OQ-1. Faith power numeral vs. icon-only.** The game's UI discipline forbids numbers on the map surface, and the strip is the designated numeral zone — but the CD should confirm: show the numeral (recommended — faith power is a currency gating unlocks; the "earned things, recorded in ink" framing) vs. glyph + micro-line only (purer restraint, weaker legibility). **RESOLVED (2026-08-09):** **show the numeral** — the strip is the designated numeral zone; the map keeps its no-numbers discipline.

**OQ-2. Rival indicator form.** Crescent + QUIET/ACTIVE gauge (recommended — honest at MVP, matches the anonymous-pressure fantasy) vs. a percentage or 3+ segment meter (finer-looking but mathematically near-binary at MVP — would read as noise). RFS OQ-02 confirms the rival is intentionally anonymous at MVP; this indicator preserves that. **RESOLVED (2026-08-09):** **ash-grey crescent + QUIET/ACTIVE two-state gauge, no %** — honest at MVP (one rival, at most one action per interval); fine-grained pressure is post-MVP (multi-rival).

**OQ-3. `HUDConfig` 9th domain vs. reuse.** New domain (recommended — strip height is a cross-system layout contract that must be named and tunable; mirrors the VillageMapConfig precedent) vs. reuse `UITimingConfig` for card timings + fixed strip height (saves the game-config update but buries the layout contract in code). **RESOLVED (2026-08-09):** **new `HUDConfig` 9th config domain** (strip height + card timings) — applied to game-config.md (Cross-System Updates item 1).

**OQ-4. Next-village transition at MVP.** The MVP ships one village, so the WON flow ends in `GAME_OVER` → return to title; `resolution_complete` is the defined seam for the macro layer. Confirm this MVP resolution (the alternative — a placeholder "continue" that loops the same village — is not recommended). **RESOLVED (2026-08-09):** **WON flow ends in `GAME_OVER` → return to title at MVP**; `resolution_complete` = macro-layer seam for the next-village transition (post-MVP).

**OQ-5. LOST game-over form at MVP.** Sober card → 2.0s final-tally frame → title (recommended) vs. card → title directly (leaner, less closure). **RESOLVED (2026-08-09):** **sober card → 2.0s final-tally frame → title** — the tally gives closure without a victory screen.

**OQ-6. Chronic card skippable?** Non-interactive at MVP (recommended — a 4s beat, consistent with DCS holds; tap-to-dismiss would undercut the chronicle moment) vs. tap-to-dismiss (player agency; revisit after first playtest). **RESOLVED (2026-08-09):** **non-interactive at MVP** — a beat, not a blocker; revisit after first playtest.

**OQ-7. Safe-area API verification.** Same as VMV OQ-1 / Conversion UI OQ-3: `DisplayServer.get_display_safe_area()` is the standard Godot 4.x call but is not documented in the pinned 4.6 reference. **RESOLVED (2026-08-09):** verify at implementation; fall back to Viewport insets or a per-device notch table (by precedent).

**OQ-8. Village display name source.** The card's village name comes from `tr("VILLAGE_" + village_id)` (content-owned key per village). Confirm the Content Director owns these keys; the HUD holds no village-name data. **RESOLVED (2026-08-09):** **village name via `tr("VILLAGE_" + village_id)` content keys** — the Content Director owns the keys; the HUD holds no village-name data.

## Cross-System Updates Required

(Full list in the appendix below — the HUD consumes or resolves existing contracts. Applied in this changeset: the `HUDConfig` 9th domain (item 1), the VMV F1 inset (item 2), the systems-index/session-state updates (items 9–10), and the entities.yaml entries (item 11).)

## Appendix — Cross-System Updates

1. **Game Config GDD** — add the `HUDConfig` 9th domain (field table in Tuning Knobs above): Rule 2 "eight config domains" → nine; field-ranges table; AC-1 and AC-10 domain enumerations; Interactions row for HUD & Progress (adds `HUDConfig` alongside `ProgressionConfig`); high-priority Tuning Knobs note. New file `res://assets/data/config/hud_config.tres`. **APPLIED 2026-08-09.**
2. **Village Map View GDD** — F1 top inset: replace the conceptual "top HUD strip" with `HUD.get_top_strip_height_dp()` (dynamic; font-scale safe); UI Req row updated. VMV cross-system item 7 remains the authority — this makes it concrete. **APPLIED 2026-08-09.**
3. **Game State Manager GDD** — no change. Confirm its HUD row already lists the exact signals/queries this GDD consumes; `get_save_data()`'s `village_id` is not needed (HUD captures `village_id` from `village_ready`).
4. **Rival Faith System GDD** — no change. Its downstream row ("HUD subscribes to `rival_acted` if an indicator is shown") resolves: shown, via this GDD. **Flag for `/consistency-check`:** `RivalFaithConfig.aggression_interval_turns` default is **6** in game-config.md vs **3** in rival-faith-system.md — pre-existing; HUD reads the field at call time so this GDD is unaffected, but the two GDDs must agree before implementation.
5. **Conversion UI GDD** — no change. The HUD sits beneath its CanvasLayer; `conversation_closed` is not consumed by the HUD (VMV's resume signal).
6. **Mobile Touch Framework GDD** — no change. Its consuming-table rows for the HUD (faith meter detail `tapped`, always registered, lowest priority tier) are confirmed and implemented here; no new MTF API needed.
7. **Save & Load GDD** — confirm: HUD state (rival stamps, panel, snapshot) is not serialized; a `VILLAGE_WON`/`VILLAGE_LOST` save restores per GSM EC-10 (clear re-trigger) without replaying the chronicle card; `load_completed` re-inits the strip.
8. **Audio System GDD** (system #16, not yet authored) — record the cue contract (win chime on `village_won`, low tone on `village_lost`, subscribed from GSM directly); the conversion-chime/ink-bleed fade contract remains VMV's item 9.
9. **systems-index.md** — row 14: status `Not Started → Designed`, design doc `design/gdd/hud-progress-system.md`; Progress Tracker: MVP systems designed 13 → **14/14**; design docs started 13 → 14. **APPLIED 2026-08-09.**
10. **production/session-state/active.md** — STATUS task → HUD & Progress System GDD — Designed; Current Task list adds ✅ HUD & Progress System; Next → Architecture plan / `/gate-check pre-production`. **APPLIED 2026-08-09.**
11. **design/registry/entities.yaml** — new: `HUDConfig` (constant), `conversion_fraction` / `rival_activity_rate` / `chronicle_card_alpha` (formulas F1/F2/F3 with variables + output ranges); `referenced_by` updates: `ProgressionConfig` ← HUD, `GSMState` ← HUD, `RivalFaithConfig` ← HUD. **APPLIED 2026-08-09.**
