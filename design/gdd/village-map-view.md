# Village Map View

> **Status**: Designed
> **Author**: ux-designer + game-designer agents
> **Last Updated**: 2026-08-09
> **Implements Pillar**: Pillar 1 — Every Soul Has a Story; Pillar 4 — History Writes Itself

## Overview

The Village Map View is the between-conversation layer of The Faithful: the single screen the player returns to after every conversion attempt and the surface on which the entire village reads. It renders the village as a static, hand-authored parchment map (portrait-mobile, no scroll or zoom at MVP) with every NPC placed as a tappable thumbnail marker at the grid position authored on `NpcRecord.map_position`. The map is a read-state surface: each thumbnail displays the NPC's current belief-state expression per the Portrait & Expression System's F5 mapping, updated as instant single-frame swaps when `npc_state_changed` fires — never animated. The system owns the four-state approachability vocabulary required by the NPC Character System (active / cooldown / locked / converted), the MTF-registered tap targets for approachable NPCs, the End Turn button (the GSM turn gate's only player-facing surface), and the two map-return effects that the DCS Visual/Audio contract assigns to it: the CONVERTED faith-spread ink-bleed that initiates from the converted NPC's position, and the `rival_acted` marker that makes the other prophet's work visible. When the player taps an approachable NPC, this system acts as the scene router: it instantiates the Conversion UI scene (`conversation_screen.tscn`), calls `begin_conversation(npc_id)`, blocks map interaction for the session's duration (via the Conversion UI's MTF blocking layer), and resumes interaction exactly when `conversation_closed` fires. It holds no game logic and no content — every state it renders is read from NPCRegistry or arrives as a signal.

## Player Fantasy

The map is the village's face between conversations — the place where the player feels the slow accumulation of the arc. It is a parchment chronicle, not a menu: thumbnails sit where people live, warming with a soft halo as souls turn, dimming into rest after an approach, cooling the moment the other prophet has been there. The fantasy is that the player can read the whole village at a glance and feel history being written: a convert who was luminous yesterday now wavers, and the player feels the small weight of absence — the turns they were not there. The ink-bleed after a conversion is the game's quietest miracle: the faith visibly soaking into the parchment from one person's place, a stain that earns its motion because it happens so rarely. The map must never feel like a status board; it must feel like a place the player returns to between conversations with specific people.

The system fails if the map ever reads as a spreadsheet — if thumbnails sit in a tidy grid with numbers, if cooldowns are countdown timers, if rival activity is a warning icon. The four states must read as states of a person (resting, closed off, changed), not states of a resource. The map succeeds when the player pauses before tapping End Turn and looks at the village one more time — because the faces on it tell them who they still owe a visit.

## Detailed Design

### Core Rules

**1. Scene ownership and lifecycle.** The Village Map View is a scene (`village_map.tscn`) owned by the game boot / load sequence. It is instantiated when a village is ready (`GSM.village_ready` or `SaveLoadSystem.load_completed`) and freed on `village_cleared` / resolution transition. It is the root of the map layer (CanvasLayer 0); the Conversion UI scene brings its own CanvasLayer above it (Conversion UI Rule 17). One instance per village.

**2. Map surface and layout grid.** The map is a static full-rect surface (no scroll, no zoom, no pan at MVP):
- Background: hand-authored parchment village art (`res://assets/maps/village_01/`), static — no ambient animation (DCS V/A: the map does not animate; the ink-bleed is the only animation it ever produces).
- A marker layout grid is defined by `GameConfig.map.map_grid_columns` (default 4) × `GameConfig.map.map_grid_rows` (default 6). Each NPC's `map_position: Vector2i` (col, row) indexes this grid; the grid cell center is the thumbnail anchor (Formula F1).
- The grid overlays the safe-area map rect; authoring validation guarantees markers do not fall inside the End Turn button zone (bottom-center strip) or the top HUD strip (owned by HUD & Progress System, system #14).
- MVP villages are authored for 8–12 NPCs; 24 cells comfortably hold 12 with no overlap. Off-grid positions are clamped into the nearest valid cell with a debug warning (EC-12); duplicate positions resolve deterministically (Formula F2).

**3. NPC markers.** For each NPC in `NPCRegistry.get_all_npcs()`, the map builds one `NpcMarker` (Control, 80×80dp logical / 160×160px @2x — the P&E thumbnail format hard contract) containing:
```
NpcMarker (Control, 80×80dp at grid anchor)
├─ ConvertedHalo (ColorRect/TextureRect behind thumbnail — visible iff CONVERTED)
├─ Thumbnail (TextureRect 80×80dp — P&E texture, single-frame swaps only)
├─ CooldownOverlay (dim ColorRect + sandglass glyph — visible iff cooldown > 0)
├─ LockedOverlay (desaturation + lock glyph — visible iff access gate unsatisfied)
├─ GateCaption (Label — visible iff locked; e.g. "Locked: convert the Elder first")
├─ RivalMarker (small glyph — visible during the rival_acted dwell window)
└─ SelectionRing (ring — shown on tapped, cleared on touch_cancelled per MTF UI contract)
```
Thumbnail textures are loaded via the P&E cache contract (`{archetype_id}/{expression_key}` keys) — the map caches only the four belief-key textures per archetype, never all six (P&E Rule 8).

**4. Thumbnail expression mapping (P&E F5 — hard contract, not renegotiated).** Initial state at build (`village_ready` / `load_completed`): each thumbnail displays `B2E(npc.belief_state)` — STEADFAST→`closed_resistant`, OPEN→`neutral_listening`, WAVERING→`open_receptive`, CONVERTED→`moved_convinced`. The map subscribes directly to `NPCRegistry.npc_state_changed(npc_id, old_state, new_state)` and applies `B2E(new_state)` as a **single-frame texture swap** — no tween, no dissolve, no hold window, no `dissolve_*` signals (P&E EC-4/F5). A rival regression (`CONVERTED → WAVERING`) cools the thumbnail to `open_receptive` within one frame. The map never animates a thumbnail.

**5. Four-state approachability vocabulary (NPC CS UI Req — owned by this system).** Every marker renders exactly one of four visually distinct states:

| State | Condition | Visual |
|---|---|---|
| Active | In `get_approachable_npcs()` | Thumbnail normal; **registered** tap target. |
| Cooldown | `cooldown_turns_remaining > 0` | Thumbnail dimmed (≈50% modulate) + sandglass glyph overlay. **Not registered.** No numeral — cooldown length is abstract at MVP (NPC CS leaves the form to this system; the "no numbers" discipline of the game's UI applies). |
| Locked | `access_gate != null` and gate unsatisfied | Thumbnail desaturated + lock glyph; GateCaption beneath the marker reading the gate requirement from `access_gate` (e.g., "Locked: convert the Elder first") via `tr()`. **Not registered.** |
| Converted | `belief_state == CONVERTED` | Thumbnail `moved_convinced` + persistent luminous warm halo (DCS V/A Phase 2). **Not registered** — CONVERTED NPCs are never approachable (NPC CS E6). |

Non-approachable markers are **not registered** with MTF, so taps on them are clean misses: no signal, no haptic — silence on a miss is intentional (MTF V/A). The player never sees `approach_count` as a number anywhere on the map (DCS Rule 7 / AC-12 spirit; NPC CS V/A leaves approach-count visuals to the UI — the map renders none).

**6. Tap interaction and approachability gate.** The map registers exactly the markers currently in `NPCRegistry.get_approachable_npcs()` (plus the End Turn button — Rule 9). Registration happens at build and is re-evaluated after any state-changing event via `_refresh_markers()` (Rule 10). On `tapped(target)`:
1. Guard: state must be `ACTIVE` and `_conversation_screen == null` (one session at a time — Rule 7).
2. Defense in depth: re-verify `target`'s NPC is still in `get_approachable_npcs()` (DCS Step 1 performs the same check at `begin_session`; this is belt-and-braces, and covers a rival/spread state change landing between refresh and tap).
3. Show the SelectionRing on the tapped marker (cleared on `touch_cancelled` per MTF UI contract).
4. Instantiate `conversation_screen.tscn`, store the NPC id in `_session_npc_id`, call `ConversationScreen.begin_conversation(npc_id)` (which calls `DCS.begin_session(npc_id)`).
5. Transition to `SESSION_ACTIVE`.

**7. Conversation handoff and blocking.** While the Conversion UI scene is alive, the map's registered areas receive no `tapped` signals — the Conversion UI pushes its MTF blocking layer at open and pops it at close (Conversion UI Rule 1; VMV AC-03 analog: map taps are suppressed for the session's duration). The map additionally refuses any synthetic tap while `_conversation_screen != null` (defense in depth, not a primary gate — MTF is the primary gate). Control returns to the map exactly on `conversation_closed` (Conversion UI API contract — emitted after teardown on **every** teardown path: session-complete, back/cancel, and defensive village-clear — see Cross-System Updates, item 2). On that signal the map:
1. Clears `_conversation_screen` and `_session_npc_id` after processing (see Rule 8).
2. Runs the map-return effect (Rule 8).
3. Calls `_refresh_markers()` (cooldown overlay from the outcome, approachability re-registration, thumbnail already swapped by `npc_state_changed` during the session).
4. Returns to `ACTIVE`. The GSM may immediately auto-advance the turn (exhaustion trigger) — the map sequences through `TURN_PROCESSING` without a visible flicker.

**8. Map-return effects (owned by this system per Conversion UI cross-system item 5 / DCS V/A).** On `conversation_closed`, with `npc = get_npc(_session_npc_id)`:
- **CONVERTED — ink-bleed (DCS V/A Phase 2):** iff `npc.belief_state == CONVERTED`, the map runs the faith-spread ink-bleed: Scripture Gold (`GameConfig.map.ink_bleed_color`) at `ink_bleed_opacity` (30–40%), bleeding outward irregularly from the converted NPC's map anchor over `ink_bleed_duration_ms` (1500–2000ms), organic and asymmetric (Formula F3). Implementation is **shader-driven** — radial expansion with an authored noise mask (OQ-2 resolved). **This is the only animation the map ever produces** (DCS V/A: "Only animation active during this transition"). The converted thumbnail shows its persistent luminous warm halo. Under reduced motion: instant full-coverage cast at `ink_bleed_opacity`, faded over `reduced_motion_ink_fade_ms` (no motion).
- **Non-CONVERTED — no animation (DCS V/A: "Map does not animate on non-CONVERTED return"):** the ambient map halo temperature updates **instantly** (static state change, no tween): warmer for advancement (OPEN/WAVERING from a PERSUADED/SOFTENED outcome), cooler for HARDENED regression. The halo is a subtle persistent map-level tint that holds until the next return; colors and max alpha from `VillageMapConfig`.
- Cancelled sessions (back/cancel) change no belief state → no ink-bleed, no halo shift (EC-16).

**9. End Turn button.** The map owns the End Turn button (GSM UI Req: "The Village Map UI disables the End Turn tap target based on GSM state"). It is a compact parchment button, ≥44×44dp, placed in the bottom-center strip within the MTF `SAFE_ZONE_BOTTOM_FRACTION` (0.55), labelled via `tr()`. It registers with MTF at build; on `tapped` it calls `GameStateManager.request_end_turn()`. It is enabled **only** while `get_gsm_state() == IDLE`; in `IN_SESSION`, `TURN_ADVANCING`, `VILLAGE_WON`, `VILLAGE_LOST`, `UNINITIALIZED` it renders disabled and is **not registered** (a stray tap is swallowed by the GSM turn gate anyway — Rule 8; belt-and-braces at the input layer).

**10. Turn processing visibility.** The map subscribes to GSM's turn lifecycle and is non-interactive during turn processing:
- `turn_advancing(turn_number)` → state `TURN_PROCESSING`; End Turn unregistered; map refuses taps.
- During Steps 3–5 the world mutates NPC state: `npc_state_changed` fires (spread conversions, rival regressions) and thumbnails swap **live, single-frame** — the player watches the rival's work land on the map. `rival_acted` markers appear during this window (Rule 11). This is the "History Writes Itself" moment made visible; no animation, no interruption.
- `turn_advanced(turn_number)` → `_refresh_markers()` (cooldowns decremented by `advance_turn()`, approachability changed) → `ACTIVE`.
- `village_won` / `village_lost` → state `RESOLVED` (Rule 12).

**11. Rival activity marker.** The map subscribes to `RivalFaithSystem.rival_acted(target_npc_id, approach, outcome)`. On each emission, the target NPC's `RivalMarker` appears: a small, quiet **ash-grey crescent** glyph (16×16dp, in the thumbnail's corner — form resolved, OQ-6). It appears **regardless of whether the outcome changed belief state** — a RESISTED rival action is still visible (Rival Faith AC-07: suppressing it would break "you feel watched"). It holds for `GameConfig.map.rival_marker_dwell_sec` (default 4.0s), then fades over `rival_marker_fade_ms` (default 300ms). It is cleared immediately on session open (the map is covered anyway) and on `village_cleared`. Reduced motion: marker appears without fade animation (fade duration applies only to the non-reduced path; under reduced motion it appears and disappears statically). If `rival_acted` fires during `TURN_PROCESSING`, the dwell runs into the `ACTIVE` state so the player sees it after interaction resumes.

**12. Village resolution.** On `village_won` / `village_lost` the map enters `RESOLVED`: all markers remain visible but the map is non-interactive (no targets registered), End Turn unregistered, and the surface dims slightly. The win/loss presentation (modal, chronicle card, transition to the next village) is **not** this system's — per the OQ-4 resolution the HUD & Progress System (system #14) owns the resolution presentation: the chronicle card, the next-village transition, and the audio cue. VMV only locks the map (`RESOLVED`); it hands off to the HUD presentation on `village_won` / `village_lost` and clears on `village_cleared`. On `village_cleared` the map clears all markers, transient effects, and session state and returns to `HIDDEN`, awaiting the next `village_ready`.

**13. Rebuild on load.** On `SaveLoadSystem.load_completed(village_id)`, the map rebuilds every marker from the deserialized NPCRegistry: initial thumbnails per `B2E(belief_state)` (Rule 4), overlays per current cooldown/gate/convert state, approachability registration per `get_approachable_npcs()`. All transient state is cleared: `_session_npc_id`, rival markers, selection rings, ink-bleed, halo tint reset to baseline. The map starts `ACTIVE` — a mid-session kill restores `IN_SESSION → IDLE` (Save & Load Rule 6), so no conversation scene exists and no `conversation_closed` will arrive; the map must not wait on one.

**14. Signal contract — consumed.** The map subscribes to:

| Signal | Owner | Used for |
|---|---|---|
| `npc_state_changed(npc_id, old, new)` | NPCRegistry | Single-frame thumbnail swap (Rule 4); refresh marker state |
| `npc_cooldown_expired(npc_id)` | NPCRegistry | Remove cooldown overlay; re-register if approachable |
| `village_initialized` / `village_ready` | NPCRegistry / GSM | Build markers |
| `rival_acted(npc_id, approach, outcome)` | Rival Faith System | Rival marker (Rule 11) |
| `turn_advancing` / `turn_advanced` | GSM | TURN_PROCESSING in/out (Rule 10) |
| `village_won` / `village_lost` | GSM | RESOLVED (Rule 12) |
| `village_cleared` | GSM | Clear everything → HIDDEN |
| `session_begun` / `session_complete` | DCS | End Turn visual state (Rule 9) — observer only, never calls DCS |
| `conversation_closed` | Conversion UI | Resume interaction + map-return effects (Rules 7–8) |
| `load_completed(village_id)` | Save & Load | Rebuild (Rule 13) |

**15. No content ownership.** Every string renders via `tr()`; every state derives from NPCRegistry reads or signals. The map contains no authored copy, no numbers of its own, and no game logic (approachability is computed by NPCRegistry; the map only registers/renders).

**Exposed API:**
```gdscript
# VillageMap (scene root — not Autoload)

# Scene-router entry (called by the map's own MTF tap handler)
func _on_marker_tapped(marker: NpcMarker) -> void
# Instantiates conversation_screen.tscn, calls begin_conversation(npc_id).

# Internal refresh — re-reads NPCRegistry for all markers
func _refresh_markers() -> void
# Re-evaluates approachability (get_approachable_npcs()), re-registers tap targets,
# refreshes cooldown/locked/converted overlays. Called after: village_ready,
# load_completed, npc_state_changed, npc_cooldown_expired, conversation_closed,
# turn_advanced.

# No public queries — all map state derives from NPCRegistry / GSM reads.
```

### States and Transitions

| State | Description |
|---|---|
| `HIDDEN` | No map. Between `village_cleared` and next `village_ready`, or pre-load. |
| `ACTIVE` | Map interactive. GSM `IDLE`. Approachable markers + End Turn registered. |
| `SESSION_ACTIVE` | Conversation scene alive (`_conversation_screen != null`). Map blocked (MTF). |
| `TURN_PROCESSING` | GSM `TURN_ADVANCING`. Map non-interactive; thumbnails update live. |
| `RESOLVED` | `VILLAGE_WON` / `VILLAGE_LOST`. Map locked; awaiting clear sequence. |

| From | To | Trigger |
|---|---|---|
| `HIDDEN` | `ACTIVE` | `village_ready` or `load_completed` (build markers) |
| `ACTIVE` | `SESSION_ACTIVE` | Tap approachable marker → instantiate conversation scene |
| `ACTIVE` | `TURN_PROCESSING` | `turn_advancing` (End Turn or exhaustion) |
| `SESSION_ACTIVE` | `ACTIVE` | `conversation_closed` (effects + refresh, Rules 7–8) |
| `TURN_PROCESSING` | `ACTIVE` | `turn_advanced` (refresh) |
| `TURN_PROCESSING` | `RESOLVED` | `village_won` / `village_lost` |
| `ACTIVE` | `RESOLVED` | `village_won` / `village_lost` |
| `RESOLVED` | `HIDDEN` | `village_cleared` (clear markers, reset state) |
| `SESSION_ACTIVE` | `HIDDEN` (defensive) | `village_cleared` while a session scene is alive (Conversion UI EC-8) |
| `TURN_PROCESSING` | `HIDDEN` (defensive) | `village_cleared` mid-turn (unreachable in normal play) |

### Interactions with Other Systems

| System | Relationship | Interface |
|---|---|---|
| NPC Character System | Upstream — data store | `get_all_npcs()`, `get_npc()`, `get_approachable_npcs()`, `get_archetype_definition()`. Subscribes: `npc_state_changed`, `npc_cooldown_expired`, `village_initialized`. |
| Mobile Touch Framework | Upstream — input | `register()`/`unregister()` per approachable marker + End Turn; `tapped`, `touch_cancelled`. Relies on the Conversion UI's blocking layer for session suppression (never pushes its own). |
| Game State Manager | Upstream — lifecycle + turn gate | Subscribes: `village_ready`, `turn_advancing`, `turn_advanced`, `village_won`, `village_lost`, `village_cleared`. Calls: `request_end_turn()`. Reads: `get_gsm_state()`. |
| Portrait & Expression System | Upstream — thumbnail contract | Consumes P&E Rule 7/F5 mapping + texture paths; hosts the thumbnail TextureRects. P&E supplies base expression only; all overlays are this system's (P&E UI Req). |
| Conversion UI | Peer — scene handoff | Instantiates `conversation_screen.tscn`; calls `begin_conversation(npc_id)`; receives control at `conversation_closed`. Owns its blocking layer. |
| Rival Faith System | Peer — world state | Subscribes to `rival_acted` for the marker (Rule 11). |
| Dialogue & Conversion System | Peer — observer only | Subscribes `session_begun`/`session_complete` for End Turn visual state. Never calls DCS methods (GSM precedent: signal-only). |
| Save & Load System | Peer — persistence | Subscribes `load_completed` to rebuild (Rule 13). |
| Game Config | Upstream — tuning | `GameConfig.map.*` (`VillageMapConfig`, **8th domain — see Cross-System Updates item 1**). Read at call time, never cached. Also `GameConfig.ui_timing` where referenced. |
| Accessibility System | Upstream (provisional) | Reads `AccessibilitySystem.reduced_motion_enabled` (default `false` if absent — P&E Rule 12 precedent). |
| HUD & Progress System | Peer — screen sharing + resolution handoff | HUD owns the top progress bar (faith power, turn counter, rival indicator) and the win/loss resolution presentation (chronicle card, next-village transition, audio cue — OQ-4 resolution); VMV owns the map + End Turn. Layout must not overlap (Cross-System Updates, item 7). |
| Audio System | Downstream — chime fade | No VMV audio signals; the Phase 2 chime fade times against `VillageMapConfig.ink_bleed_duration_ms` (Cross-System Updates, item 9). |
| Faith Spread System | Prospective (VS) | The map is the planned visualization surface for passive spread (systems-index note); no interface at MVP. |

## Formulas

### F1 — Grid Position to Screen Anchor

```
map_rect   = safe_area_rect inset by HUD.get_top_strip_height_dp() and bottom control strip
cell_w_dp  = map_rect.width  / map_grid_columns
cell_h_dp  = map_rect.height / map_grid_rows
anchor_dp(col, row) = map_rect.position + ((col + 0.5) * cell_w_dp, (row + 0.5) * cell_h_dp)
```

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `col, row` | grid position | int | col ∈ [0, cols), row ∈ [0, rows) | `NpcRecord.map_position` (x=col, y=row) |
| `map_grid_columns` | grid width | int | [3, 6] | `GameConfig.map.map_grid_columns`. Default 4 |
| `map_grid_rows` | grid height | int | [5, 8] | `GameConfig.map.map_grid_rows`. Default 6 |
| `cell_w_dp` / `cell_h_dp` | cell size | float | ≥ 88dp each at defaults | 4×6 over a ~360×600dp map rect → ~90×100dp cells; an 80dp thumbnail fits with margin |
| `anchor_dp` | marker center | Vector2 | inside `map_rect` | Marker Control centered here; clamped so the full 80×80dp rect stays inside `map_rect` |

**Output range:** every anchor lies inside the map rect. Authoring validation at `village_ready` rejects (debug warning + clamp) any `map_position` whose anchor would overlap the End Turn zone or the top HUD strip (height = `HUD.get_top_strip_height_dp()` — dynamic, font-scale safe).

### F2 — Duplicate Grid Position Resolution

```
dup_index[n] = count of NPCs registered at the same (col, row) before NPC n
offset_dp(n) = (dup_index[n] * 28) mod max(1, cell_w_dp − 80)   # horizontal shift
               row-wrap by 28dp per overflow of the cell width
```

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `dup_index[n]` | duplicate ordinal | int | [0, …] | Order among same-cell NPCs (registration order in `get_all_npcs()`) |
| `offset_dp(n)` | displacement | Vector2 | within one cell | Deterministic 28dp step per duplicate, wrapping inside the cell |

**Output range:** duplicates never overlap and never leave their cell. This is a defensive runtime fallback; correct authoring never triggers it. A debug warning is logged per duplicate at `village_ready`. Post-MVP, authoring tooling should reject duplicates outright.

### F3 — CONVERTED Ink-Bleed Envelope

```
D      = GameConfig.map.ink_bleed_duration_ms / 1000.0        # 1.75s default
T_fade = 0.2s
R_max  = GameConfig.map.ink_bleed_max_radius_dp               # 260dp default
A_max  = GameConfig.map.ink_bleed_opacity                     # 0.35 default

r(t) = R_max × ease_out_cubic(t / D)                          # radius growth
a(t) = A_max                          for t ∈ [0, D − T_fade)
       A_max × (1 − (t − (D − T_fade)) / T_fade)   for t ∈ [D − T_fade, D]
```

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `t` | elapsed time | float | [0, D] | Seconds since `conversation_closed` with CONVERTED |
| `r(t)` | bleed radius | float | [0, R_max] | Radial extent from the converted NPC's anchor; ease-out cubic — fast start, organic slow landing |
| `a(t)` | bleed opacity | float | [0, A_max] | Held at A_max during expansion; fades over the final 200ms |
| `A_max` | peak opacity | float | [0.30, 0.40] | DCS V/A Phase 2 band ("Scripture Gold at 30–40% opacity") |
| `D` | duration | float | [1.5, 2.0] | DCS V/A Phase 2 band (1500–2000ms) |

**Output range:** the bleed is irregular/asymmetric per the authored noise mask (Art Bible §4.3 — organic, noise-driven). Implementation is **shader-driven radial expansion with an authored noise mask** (OQ-2 resolved — tunable at runtime, no extra animated-texture art pipeline). It is the only animation active during the transition. **Reduced-motion override:** skip the expansion; apply full-coverage cast at `A_max`, fade over `reduced_motion_ink_fade_ms` (default 100ms).

## Edge Cases

**EC-1. Rapid double-tap on an approachable NPC.** MTF's 100ms debounce discards the bounce tap (F-5). The `SESSION_ACTIVE` guard additionally ignores any tap while `_conversation_screen != null`. Result: exactly one session (AC-15).

**EC-2. Tap lands during `SESSION_ACTIVE` / `TURN_PROCESSING` / `RESOLVED`.** MTF's blocking layer suppresses map targets during the session; the map unregisters all targets during turn processing and resolution. A synthetic tap (unit-test) in any non-`ACTIVE` state is ignored by the guard. No signal leaks through, no haptic on a miss.

**EC-3. NPC state changes while the map is visible.** `npc_state_changed` fires (rival regression, spread conversion, cooldown expiration): the thumbnail swaps single-frame per F5; `_refresh_markers()` updates overlays and approachability registration. A marker that just became approachable (cooldown expired) registers within the same refresh; one that just became non-approachable unregisters. No animation, no queue (P&E EC-4).

**EC-4. State change for the NPC currently in a session.** Unreachable in normal play (the rival acts only between sessions; spread runs during turn processing — never mid-session, P&E EC-3). Deterministic rule: the map swaps the thumbnail anyway; it never drives the portrait — the Conversion UI is the sole expression driver (P&E EC-3).

**EC-5. Missing thumbnail texture.** P&E EC-6/7 fallback conventions apply: if `{archetype_path}{expression_key}.png` fails to load, log one error per `(archetype_id, expression_key)` pair and display `closed_resistant` as the fallback. If even the fallback is missing, render a solid `ColorRect` placeholder and log a hard error. A missing face must never crash the map (P&E EC-7: gameplay continues).

**EC-6. Missing archetype definition.** `get_archetype_definition()` returns null → render a neutral silhouette placeholder for the thumbnail, log a hard error naming the NPC id, and continue. Mirrors P&E EC-7's "missing face must never crash" rule at the map layer.

**EC-7. `village_cleared` while the map is visible.** Clear all markers, transient effects (rival markers, rings, ink-bleed), `_session_npc_id`, and the halo tint; transition `HIDDEN`. No stale references survive (AC-14).

**EC-8. `village_won`/`village_lost` while a session scene is alive.** Unreachable in normal play (win/loss resolve during turn processing, never mid-session — Conversion UI EC-8). Defensive: the Conversion UI frees its scene on `village_cleared`; the map clears state and enters `HIDDEN`. No NPCRegistry mutation from the map, ever.

**EC-9. Reduced motion enabled.** Ink-bleed becomes an instant static cast + 100ms fade (F3 override); the rival marker appears/disappears statically (no fade animation); the selection ring renders without pulse. All color cues remain — color is never the sole signal (P&E EC-9 precedent: audio + state give second channels).

**EC-10. App backgrounded mid-session / mid-turn.** If killed: Save & Load restores `IN_SESSION → IDLE` or `TURN_ADVANCING → IDLE` (Save & Load Rule 6 / GSM EC-9); on `load_completed` the map rebuilds `ACTIVE` and waits for nothing — no `conversation_closed` will arrive for a dead scene (Rule 13). If merely backgrounded (not killed): the map holds its state; MTF's gesture timeout handles any in-flight gesture; on focus-in the map re-reads `get_gsm_state()` and re-registers targets (registration is idempotent).

**EC-11. `conversation_closed` arrives with a stale/cleared `_session_npc_id`.** If the map is in `HIDDEN` (defensive clear) or the id was reset, treat the signal as a no-op (no ink-bleed, no halo shift) and clear `_conversation_screen`. No crash; the Conversion UI's own teardown already popped its blocking layer.

**EC-12. Out-of-range or duplicate `map_position`.** Clamp into the nearest valid cell (F1) / resolve deterministically (F2), log a debug warning, continue. Authoring validation at `village_ready` flags both. MVP villages are hand-authored; this is a safety net, not a supported path.

**EC-13. Village with all NPCs non-approachable.** All markers render with overlays; only End Turn is registered. The player ends the turn; the exhaustion auto-advance covers the no-session path (GSM Rule 2b). The map needs no special case beyond `_refresh_markers()` correctly registering zero targets.

**EC-14. `rival_acted` fires while a session is open.** Unreachable in normal play (the rival acts only during turn processing). Deterministic rule: the marker appears on the target thumbnail; it is covered by the conversation scene and will be visible on return if its dwell window is still open (dwell is wall-clock). No special handling.

**EC-15. Marker dwell overlaps session open.** The rival marker is cleared immediately when a session opens (Rule 11) — the map is covered and the marker must not linger into the next return.

**EC-16. Cancelled session (back button).** `cancel_session()` ends the DCS session from `APPROACH_SELECTION`; `conversation_closed` fires on teardown (contract — see Cross-System Updates, item 2). Belief state is unchanged (inspect reveals persist but are not belief changes) → no ink-bleed, no halo shift; `_refresh_markers()` re-reads revealed-trait-independent state (map shows no traits, so no visual change is expected — cooldown unchanged because no approach occurred).

**EC-17. Exhaustion auto-advance immediately after `conversation_closed`.** GSM fires `turn_advancing` on the same frame the map returns to `ACTIVE`. The map sequences `ACTIVE → TURN_PROCESSING` without rendering an interactive frame in between; no tap can slip through because MTF processes events per-frame and the state transition happens before the next input poll. No special handling beyond honoring state guards.

**EC-18. MTF blocking-layer hygiene.** The map never pushes/pops blocking layers — the Conversion UI owns that (MTF EC-7 contract: pop must match push). The map's reliance on the Conversion UI's layer means a leaked layer (push without pop) would freeze the map; the framework's `clear_blocking_layers()` on focus-out is the recovery path, and the Conversion UI GDD already requires pop on every teardown path.

## Dependencies

### Systems This System Depends On

| System | GDD | Type | Interface |
|---|---|---|---|
| NPC Character System | `npc-character-system.md` | **Hard** | `get_all_npcs()`, `get_npc()`, `get_approachable_npcs()`, `get_archetype_definition()`; signals `npc_state_changed`, `npc_cooldown_expired`, `village_initialized`. Without NPCRegistry no marker can exist. |
| Mobile Touch Framework | `mobile-touch-framework.md` | **Hard** | `register()`/`unregister()` (44dp floor, F-2 inflation), `tapped`, `touch_cancelled`; blocking-layer suppression while the Conversion UI is open. |
| Game State Manager | `game-state-manager.md` | **Hard** | Signals `village_ready`, `turn_advancing`, `turn_advanced`, `village_won`, `village_lost`, `village_cleared`; command `request_end_turn()`; query `get_gsm_state()`. |
| Portrait & Expression System | `portrait-expression-system.md` | **Hard** (contract) | Rule 7/F5 thumbnail mapping + `{archetype_id}/{expression_key}` texture paths; 80×80dp format; single-frame swap discipline; overlay ownership split (P&E UI Req). |
| Conversion UI | `conversion-ui.md` | **Hard** (scene handoff) | `begin_conversation(npc_id)`; `conversation_closed` signal (emitted on every teardown path); owns its own blocking layer. |
| Rival Faith System | `rival-faith-system.md` | **Hard** (signal) | `rival_acted(npc_id, approach, outcome)` — the marker contract (Rival UI Req defers the marker's form to this GDD). |
| Game Config | `game-config.md` | **Hard** | `GameConfig.map.*` — **`VillageMapConfig`, 8th domain (see Cross-System Updates item 1)**. Pull pattern, read at call time. |
| Save & Load System | `save-load-system.md` | **Hard** (rebuild) | `load_completed(village_id)` to rebuild markers (Rule 13). |
| Dialogue & Conversion System | `dialogue-conversion-system.md` | **Soft** (observer) | `session_begun` / `session_complete` for End Turn visual state. If absent, End Turn state degrades to polling `get_gsm_state()` on turn signals only. |
| Accessibility System | *(GDD pending — Alpha)* | **Soft (provisional)** | `AccessibilitySystem.reduced_motion_enabled` (default `false` if absent — P&E Rule 12 precedent). |
| Godot Engine | `docs/engine-reference/godot/` | **Hard** | `Control`, `TextureRect`, `ColorRect`, `Label`, `Tween`, `ShaderMaterial` (ink-bleed — OQ-2 resolved), `DisplayServer.get_display_safe_area()` (verify at implementation — OQ-1: fallback Viewport insets or per-device notch table), `tr()`. Verified against the pinned 4.6 reference; no post-cutoff APIs used. |

### Systems That Depend On This System

| System | GDD | What It Uses |
|---|---|---|
| Conversion UI | `conversion-ui.md` | Receives control at `CLOSING`; relies on the map to instantiate its scene and call `begin_conversation` (Conversion UI API note: "Called by the scene router (Village Map View tap handler)"). |
| Rival Faith System | `rival-faith-system.md` | Its `rival_acted` marker contract is implemented here (Rival UI Req defers the form to this GDD). |
| HUD & Progress System | *(GDD pending — #14)* | Shares the screen: HUD top bar + map + End Turn must not overlap (Cross-System Updates, item 7). **Owns the win/loss resolution presentation** (chronicle card, next-village transition, audio cue) per the OQ-4 resolution — VMV only locks the map (`RESOLVED`) and hands off. |
| Tutorial & Onboarding | *(GDD pending)* | Map-surface guidance ("tap a face to speak"); must observe, never block (DCS OQ-5 pattern). |
| Audio System | *(GDD pending — #16)* | Times the Phase 2 chime fade against `VillageMapConfig.ink_bleed_duration_ms`; plays village ambient on map return (DCS V/A). |
| Faith Spread System | *(GDD pending — VS)* | The map is the planned visualization surface for passive spread (systems-index Dependency Map). |
| Save & Load System | `save-load-system.md` | Its downstream table lists VMV as a `load_completed` consumer — resolved by this GDD. |
| Game State Manager | `game-state-manager.md` | Its "Village Map UI" references (`request_end_turn()`, End Turn disable) resolve to this system. |

### Architectural Notes

- The map is a **scene, not an Autoload** — one instance per village, mirroring the Conversion UI ownership model (P&E Rule 10).
- **No persistent state.** Everything renders from NPCRegistry reads + signals; `_session_npc_id` and transient markers are the only local state and are cleared on every rebuild/clear path.
- **No blocking-layer ownership.** The Conversion UI pushes/pops; the map is suppressed by MTF. This keeps a single owner of the modal stack (MTF EC-7 hygiene).
- **Observer-only relationship with DCS/GSM logic** — the map calls exactly one command in the whole architecture: `request_end_turn()`.

## Tuning Knobs

### New domain — `GameConfig.map` (`VillageMapConfig`, 8th config domain — proposed by this GDD)

| Knob | Field | Default | Safe Range | Effect | What Breaks at Extremes |
|---|---|---|---|---|---|
| Grid columns | `map_grid_columns` | 4 | 3–6 | Marker layout grid width. | Below 3: cells ≥ ~120dp wide, map looks empty. Above 6: cells < 60dp — 80dp thumbnails overlap. |
| Grid rows | `map_grid_rows` | 6 | 5–8 | Marker layout grid height. | Below 5: 12 NPCs crowd. Above 8: cells < 60dp tall on small devices. |
| Ink-bleed duration | `ink_bleed_duration_ms` | 1750 | 1500–2000 | Faith-spread bleed duration (DCS V/A Phase 2 band). | Below 1500ms: reads as a blink. Above 2000ms: holds the map hostage after conversion; DCS V/A pins the band. |
| Ink-bleed opacity | `ink_bleed_opacity` | 0.35 | 0.30–0.40 | Peak bleed opacity. | Below 0.30: imperceptible stain. Above 0.40: obscures the map (DCS V/A band). |
| Ink-bleed colour | `ink_bleed_color` | `Color8(230, 190, 100)` (#E6BE64 Scripture Gold) | any Color | Bleed tint. | Over-saturated hues fight the parchment; grey reads as failure. Ships as-is at `#E6BE64`; Art-Director-confirmable but non-blocking (OQ-5 resolved). |
| Ink-bleed radius | `ink_bleed_max_radius_dp` | 260 | 160–400 | Final bleed extent from the converted NPC's anchor. | Below 160dp: doesn't reach the village. Above 400dp: bleeds off-screen on small devices. |
| Rival marker dwell | `rival_marker_dwell_sec` | 4.0 | 1.0–8.0 | How long the rival's mark is visible. | Below 1s: unreadable. Above 8s: feels like a badge, not a whisper. |
| Rival marker fade | `rival_marker_fade_ms` | 300 | 100–600 | Fade-out of the rival mark. | Below 100ms: pops out. Above 600ms: lingers into the next session feel. |
| Halo — advance tint | `return_halo_advance_color` | warm gold `Color8(242, 193, 78)` | any Color | Instant ambient warm cast after advancement. | Over-bright: the map glows. Alpha is capped by `return_halo_max_alpha`. |
| Halo — regress tint | `return_halo_regress_color` | cool blue-grey `Color8(90, 122, 154)` | any Color | Instant ambient cool cast after HARDENED. | Over-saturated: reads as an alarm (DCS: dignified, not alarming). |
| Halo max alpha | `return_halo_max_alpha` | 0.12 | 0.05–0.25 | Peak ambient tint strength. | Above 0.25: tints the map into a mood ring. |
| Reduced-motion ink fade | `reduced_motion_ink_fade_ms` | 100 | 0–500 | Ink-bleed fade when reduced motion is enabled (F3 override). | 0 = instant cast + instant clear (colour flash only). Above 500ms reintroduces motion. |

### Consumed from existing config (owned by Game Config GDD)

| Knob | Field | Default | Effect |
|---|---|---|---|
| Scene transition | `UITimingConfig.scene_transition_duration_sec` | 0.5 | The map's page-turn handoff duration is owned by the Conversion UI (CLOSING); the map is covered during it — no VMV change. |

### Interaction warnings

- `ink_bleed_duration_ms` × `outcome_display_hold_sec`/conversion surge: the DCS V/A surge (3.05s) already overlaps the map-return page-turn; the bleed starts after `conversation_closed` (page-turn done). If `ink_bleed_duration_ms` is ever raised above ~2.0s, verify the chime fade (Audio System) and the next-tap availability feel — the map should accept a tap as soon as the bleed fades, not before (see AC-06 note: interaction resumes at `conversation_closed`; the bleed is purely visual and never blocks input).

## Visual/Audio Requirements

| Element | Requirement |
|---|---|
| Map background | Static hand-authored parchment village art (per-village asset, `res://assets/maps/{village_id}/`). No ambient animation (DCS V/A: the map does not animate). Neighborhoods authored per NPC groupings (market quarter, square, etc. — Art Bible register). |
| Thumbnails | 80×80dp logical (160×160px @2x), P&E-authored belief-key textures (28 at MVP across 7 archetypes). Single-frame swaps only — never animated (P&E Rule 9 / F5). |
| Converted halo | Persistent warm luminous halo behind CONVERTED thumbnails (DCS V/A Phase 2). Static glow, no pulse. |
| Cooldown overlay | Dim (≈50% modulate) + sandglass glyph. No numeral. Placed with the thumbnail — "placed, not animated" (DCS V/A discipline). |
| Locked overlay | Desaturation + lock glyph + GateCaption beneath the marker (e.g., "Locked: convert the Elder first") via `tr()`. |
| Selection ring | Shown on `tapped`, cleared on `touch_cancelled` (MTF UI contract). Brief static ring — no pulse at MVP; pulse is a reduced-motion casualty. |
| Rival marker | Small **ash-grey crescent** glyph (16×16dp) in the thumbnail corner — reads as "the other prophet was here" without alarm or UI-badge connotations (OQ-6 resolved). Appears on `rival_acted`, dwells, fades (Rule 11). |
| Ink-bleed | F3 envelope; Scripture Gold at 30–40%, organic/asymmetric via shader-driven radial expansion + authored noise mask, 1500–2000ms, only animation during the transition (DCS V/A Phase 2 / §4.3; OQ-2 resolved). |
| Ambient halo tint | Instant (non-animated) warm/cool cast after non-CONVERTED returns (DCS V/A: "Color temperature halo updates… Map does not animate on non-CONVERTED return"). |
| End Turn button | Compact parchment button, placed not animated; disabled visual outside `IDLE`. |
| Audio | **The map plays no audio.** MTF tap chime (framework-level), village ambient, and the conversion chime fade (timed against `ink_bleed_duration_ms`) are Audio System / framework responsibilities (DCS V/A). |

> 📌 **Asset Spec flag** — map surface, thumbnails (with P&E), overlays, and the rival marker glyph are defined here. After the Art Bible is approved, run `/asset-spec system:village-map-view` to produce per-asset descriptions and generation prompts.

## UI Requirements

| Element | Constraint |
|---|---|
| Screen | Full safe-area portrait view; top strip reserved for HUD & Progress System (#14) at `HUD.get_top_strip_height_dp()` (F1 top inset — dynamic, font-scale safe); bottom-center strip for End Turn. No scroll/pan/zoom at MVP. |
| Tap targets | All registered targets ≥ 44×44dp (thumbnails 80×80dp; End Turn ≥44×44dp). Approachable markers + End Turn registered in `_ready()`/build; unregistered on teardown/state change (MTF consuming-system contract). |
| Approachability | Four distinct states (active / cooldown / locked / converted) — never conflated; non-approachable markers not registered (miss = silence + no haptic). |
| Numbers | No `approach_count` anywhere; no cooldown numerals; no conversion percentages. The map is a face-surface, not a scoreboard. |
| Localisation | All strings via `tr()` (End Turn label, gate captions). Autowrap enabled. |
| Reduced motion | Ink-bleed instant cast + fade; rival marker static; ring static; halo cast is already non-animated. |
| Safe areas | `DisplayServer.get_display_safe_area()` for the map rect (verify at implementation — OQ-1 resolved: fallback to Viewport insets or per-device notch table); markers clamped inside; End Turn within `SAFE_ZONE_BOTTOM_FRACTION` (0.55). |

## Acceptance Criteria

**AC-01 — Marker build.** Given a village with N NPCs (8 ≤ N ≤ 12) and authored `map_position` values, when `village_ready` fires, then exactly N `NpcMarker` nodes exist, each centered at its F1 anchor, and all anchors lie inside the map rect with no marker overlapping the End Turn zone or the top HUD strip.

**AC-02 — Initial thumbnails.** Given a village after build, when markers are inspected, then every thumbnail displays `B2E(belief_state)` per P&E F5 (STEADFAST→`closed_resistant`, OPEN→`neutral_listening`, WAVERING→`open_receptive`, CONVERTED→`moved_convinced`).

**AC-03 — Approachable-only registration.** Given a village with a mix of approachable, cooldown, locked, and converted NPCs, when MTF registration is inspected, then exactly the approachable NPCs (matching `get_approachable_npcs()`) plus the End Turn button are registered. Taps on non-approachable markers produce no `tapped` signal and no haptic.

**AC-04 — Tap opens conversation.** Given an approachable marker in `ACTIVE`, when the player taps it, then exactly one `ConversationScreen` is instantiated, `begin_conversation(npc_id)` is called with the tapped NPC's id, `_session_npc_id` is set, and the map enters `SESSION_ACTIVE`.

**AC-05 — Session blocking.** Given `SESSION_ACTIVE` (conversation scene alive), when a tap lands on any map target (or a synthetic tap is delivered), then no `tapped` signal reaches the map and no session is opened; after `conversation_closed`, map taps resume.

**AC-06 — Conversation close handoff.** Given `conversation_closed`, when the map processes it, then `_conversation_screen` is cleared, the map returns to `ACTIVE`, `_refresh_markers()` runs, and interaction resumes. Given the closed session's NPC is CONVERTED, exactly one ink-bleed runs from that NPC's anchor. Given a cancelled or non-CONVERTED session, no ink-bleed runs.

**AC-07 — Ink-bleed parameters.** Given a CONVERTED return at defaults (`ink_bleed_duration_ms = 1750`, `ink_bleed_opacity = 0.35`), when the bleed runs, then it originates at the converted NPC's anchor, its opacity peaks at `0.35 ± 0.02`, its radius reaches `ink_bleed_max_radius_dp` at `1750ms ± 32ms`, and it is the only animation active during the transition (no other map property changes across sampled frames).

**AC-08 — Single-frame thumbnail swap.** Given a map with an OPEN NPC (thumbnail `neutral_listening`), when `npc_state_changed(npc_id, OPEN, WAVERING)` fires, then within one rendered frame the thumbnail displays `open_receptive`; no tween runs and no `dissolve_*` signal is emitted. Given `npc_state_changed(npc_id, CONVERTED, WAVERING)` (rival regression), the thumbnail cools to `open_receptive` within one frame.

**AC-09 — Cooldown overlay lifecycle.** Given an NPC whose session just resolved (cooldown set), when the map refreshes on `conversation_closed`, then the cooldown overlay is visible within one frame and the marker is unregistered. Given `npc_cooldown_expired`, the overlay is removed and the marker re-registers (if still approachable). After `turn_advanced`, all markers' registration matches `get_approachable_npcs()`.

**AC-10 — Rival marker.** Given `rival_acted(npc_id, approach, RESISTED)` (no belief change), when the signal fires, then the target NPC's `RivalMarker` appears, dwells `rival_marker_dwell_sec` (4.0s default), and fades over `rival_marker_fade_ms`. The marker is cleared immediately when a session opens or `village_cleared` fires.

**AC-11 — End Turn gating.** Given GSM `IDLE`, the End Turn button is registered and tappable; on tap, `request_end_turn()` is called exactly once. Given any other GSM state (`IN_SESSION`, `TURN_ADVANCING`, `VILLAGE_WON`, `VILLAGE_LOST`, `UNINITIALIZED`), the button is unregistered and rendered disabled; a synthetic tap changes nothing.

**AC-12 — Turn processing.** Given `turn_advancing`, the map enters `TURN_PROCESSING`: no tap opens a session and End Turn is disabled. If `npc_state_changed` / `rival_acted` fire during processing, thumbnails swap and markers appear live. Given `turn_advanced`, the map returns to `ACTIVE` with all markers refreshed.

**AC-13 — Village resolution.** Given `village_won` or `village_lost`, the map enters `RESOLVED`: no marker or End Turn target is registered (taps produce nothing) and the surface dims. No further session can begin until `village_cleared`.

**AC-14 — Village clear.** Given `village_cleared`, then all markers, transient effects, `_session_npc_id`, and the halo tint are cleared, and the map is `HIDDEN` with no stale references (verified by node count and a repeated build/clear cycle).

**AC-15 — Double-tap defense.** Given an approachable NPC, when two taps land on the same marker within 100ms, then exactly one session opens (`begin_conversation` called once, one `ConversationScreen` alive).

**AC-16 — Missing-texture fallback.** Given an archetype whose set lacks a needed belief-key texture, then exactly one error is logged for that `(archetype_id, expression_key)` pair, the thumbnail displays `closed_resistant` (or a solid placeholder if the fallback is also missing), and the map continues without interruption.

**AC-17 — Reduced motion.** Given `AccessibilitySystem.reduced_motion_enabled = true`, then the ink-bleed appears as an instant full-coverage cast at `ink_bleed_opacity` and fades over `reduced_motion_ink_fade_ms` (no expansion motion), the rival marker appears/disappears without fade animation, and the selection ring renders without pulse.

**AC-18 — Load rebuild.** Given `load_completed(village_id)`, then all markers are rebuilt from NPCRegistry state (thumbnails per `B2E`, overlays per current state, registration per `get_approachable_npcs()`), all transient state is cleared, and the map is `ACTIVE`. No `conversation_closed` is awaited.

**AC-19 — Tap target minimums.** Given a build on the minimum supported logical size 360×640dp, then every registered target is ≥ 44×44dp and the End Turn button sits within `SAFE_ZONE_BOTTOM_FRACTION` (0.55) and above the bottom safe inset.

**AC-20 — Gate caption + no numbers.** Given a locked NPC with `access_gate`, then the marker shows the lock glyph and a GateCaption derived from `access_gate` (e.g., "Locked: convert the Elder first"). At no point does any `approach_count`, cooldown numeral, or conversion percentage appear on the map (verified by screenshot review across all states).

## Open Questions — Resolved

**OQ-1. Safe-area API verification.** Like Conversion UI OQ-3: `DisplayServer.get_display_safe_area()` is the standard Godot 4.x call but is not documented in the pinned 4.6 reference. **RESOLVED (2026-08-09):** accepted — verify at implementation; fall back to `Viewport` insets or a per-device notch table.

**OQ-2. Ink-bleed implementation.** Shader-driven radial expansion with an authored noise mask (organic, asymmetric — matches Art Bible §4.3) vs. a pre-authored animated texture sequence. **RESOLVED (2026-08-09):** **shader-driven** radial expansion + authored noise mask. Rationale: tunable at runtime (`ink_bleed_color`/`opacity`/`radius` via config), no extra animated-texture art pipeline, matches Art Bible §4.3.

**OQ-3. Scroll/zoom post-MVP.** Single-screen at MVP (fixed grid, all NPCs visible). A scrollable or pinch-zoomable map (for larger Vertical Slice villages, 30 NPCs) will require re-anchoring the ink-bleed and turn-processing visibility. **RESOLVED (2026-08-09):** accepted — scroll/zoom deferred post-MVP to the Faith Spread System / Region & World Map System work.

**OQ-4. Win/loss presentation ownership.** This system locks the map (`RESOLVED`) but the actual "village won/lost" flow — chronicle card, next-village transition, audio cue — is unspecified. **RESOLVED (2026-08-09):** **HUD & Progress System (#14) owns the win/loss presentation** — chronicle card, next-village transition, audio cue. Village Map View only locks the map. Recorded as a handoff contract in Dependencies and for the HUD GDD draft (Cross-System Updates, items 7–8).

**OQ-5. Scripture Gold exact colour.** `#E6BE64` is a placeholder consistent with the warm gold register; confirm with the Art Director against Art Bible §4.3. **RESOLVED (2026-08-09):** keep `#E6BE64` as the config default; Art-Director-confirmable but ships as-is.

**OQ-6. Rival marker form.** Ash-grey crescent vs. second-footprint glyph vs. subtle dark-smudge. It must read as "the other prophet was here" without reading as an alarm or a UI badge. **RESOLVED (2026-08-09):** **ash-grey crescent** (config-driven dwell/fade). Rationale: reads as "the other prophet was here" without alarm/UI-badge connotations.

## Cross-System Updates Required

(Full list in the appendix below — the map consumes or resolves existing contracts. Applied in this changeset: the config domain (item 1), the Conversion UI teardown confirmation (item 2), the DCS wording correction (item 3), and the systems-index/session-state updates (items 10–11).)

## Appendix — Cross-System Updates

1. **Game Config GDD** — add the `VillageMapConfig` 8th domain (field table above) to the domain list, the "Seven config domains" statement (→ eight), and AC-10's domain enumeration. New file `res://assets/data/config/village_map_config.tres`. **APPLIED 2026-08-09.**
2. **Conversion UI GDD** — confirm `conversation_closed` is emitted on **every** teardown path (session-complete AND back/cancel AND defensive village-clear). The current API doc ("emitted after teardown — map resumes interaction") implies this; the VMV depends on it as its single resume signal (AC-06). **APPLIED 2026-08-09** (API doc + Rule 11/back-cancel row + EC-8).
3. **Dialogue & Conversion System GDD** — EC-1 wording: "Tap targets for non-approachable NPCs should be disabled by the Conversion UI" → should read **"disabled by the Village Map View"** (VMV owns map tap targets; the Conversion UI never touches the map layer). **APPLIED 2026-08-09.**
4. **NPC Character System GDD** — optional note: village scene definition authoring must guarantee unique, in-grid `map_position` values; VMV validates/clamps at runtime (F1/F2, EC-12). No API change.
5. **Rival Faith System GDD** — resolved: the `rival_acted` marker's form and lifecycle are defined here (Rule 11, OQ-6 — ash-grey crescent). No RFS change needed; its UI Req deferral now has a home.
6. **Portrait & Expression System GDD** — resolved: its "Village Map View (GDD pending — system #13)" references now point here; Rule 7/F5 and overlay ownership are implemented verbatim. No P&E change.
7. **HUD & Progress System GDD** (system #14, not yet authored) — screen-sharing contract: HUD owns the top progress bar (faith power, turn counter, rival indicator); VMV owns the map + End Turn. HUD must reserve the top strip and must not place primary actions in the bottom-center strip. **OQ-4 handoff contract: HUD also owns the win/loss resolution presentation** (chronicle card, next-village transition, audio cue) — VMV only locks the map (`RESOLVED`). Carried into the HUD GDD draft.
8. **Win/loss flow** — OQ-4: **RESOLVED — HUD & Progress System (#14) owns the resolution presentation**; VMV only locks (`RESOLVED`) and hands off. No Region & World Map System dependency at MVP.
9. **Audio System GDD** (system #16, not yet authored) — the Phase 2 conversion chime fade should read `GameConfig.map.ink_bleed_duration_ms` (DCS V/A: chime "fades as ink-bleed completes"); village ambient resumes on map return.
10. **systems-index.md** — row 13: status `Not Started → Designed`, design doc `design/gdd/village-map-view.md`; Progress Tracker counts updated (MVP systems designed 12 → 13 of 14; design docs started 12 → 13). **APPLIED 2026-08-09.**
11. **production/session-state/active.md** — STATUS task → Village Map View System GDD — Designed; Current Task list adds ✅ Village Map View; Next → HUD & Progress System (#14); OQ-4 win/loss ownership decision recorded. **APPLIED 2026-08-09.**
