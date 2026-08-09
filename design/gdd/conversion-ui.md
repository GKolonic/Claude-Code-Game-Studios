# Conversion UI

> **Status**: Designed
> **Author**: ux-designer + game-designer agents
> **Last Updated**: 2026-08-09
> **Implements Pillar**: Pillar 1 — Every Soul Has a Story; Pillar 2 — Many Roads to the Divine; Pillar 3 — The Arc Must Feel Earned

## Overview

The Conversion UI is the presentation layer of every conversion attempt. It owns the conversation screen scene: instantiating and freeing the `PortraitController`, computing the two-zone layout (portrait zone occupying the upper 60–65% of the safe viewport, choice zone below), and rendering every interactive element the player touches — the four approach buttons, the Inspect button, the trait panel, the dialogue zone, the back/cancel affordance, and the background mood-lighting layer that carries the Art Bible's Conversation register. It is the single driver of the portrait during a session: it decides, per dialogue beat and outcome, exactly when `PortraitController.set_expression()` is called (P&E EC-3: the Conversion UI is the sole expression driver). It translates the Dialogue & Conversion System's session sequence into screen states, owns all presentation hold timers, registers all touch targets with the Mobile Touch Framework, and tears the whole scene down on `session_complete`. It is a scene, not an Autoload: one instance exists per conversation, created when the player taps an approachable NPC and destroyed when control returns to the village map.

The system exists because the session contract is split across three upstream systems — DCS defines *what happens*, P&E defines *how the face reacts*, MTF defines *how input lands* — and none of them may render UI. Someone must own the screen itself: the layout, the timing of what appears when, the touch registration, the safe-area math, and the scene lifecycle. That owner is this system. It holds no game logic and no content; every word displayed arrives via DCS signals or is read from the NPC Character System and Trait Database.

## Player Fantasy

The player's entire relationship with a soul is this screen. The Conversation UI is working when a player pauses at the approach grid and reads the face above it — not the buttons below it — before deciding what to say. The screen must disappear as a mechanism: the 2×2 grid should feel like four things a prophet could offer a stranger, the Inspect tap like opening a small page of a life, the held breath after choosing GRIEF like the moment before speaking aloud. Nothing should ever feel like a form.

The fantasy is carried by what the screen *withholds*. No approach-count numbers. No probability. No affinity values. A greyed button that is still tappable, because de-emphasis is a hint and the player remains the decider. A trait card that appears in silence, a page turning. A background that cools when the NPC is nearly beyond reach, so the player feels the stakes before they are told them. The screen succeeds when the player remembers the face and the words and the pause — and cannot describe the layout that delivered them.

## Detailed Design

### Core Rules

**1. Scene ownership and lifecycle.** The Conversion UI is a scene (`conversation_screen.tscn`) instantiated on top of the Village Map when the player taps an approachable NPC. It is created on `session_begun(npc_id)`, freed on `session_complete()`. The scene owns: the portrait zone container (which instantiates one `PortraitController`), the choice zone (dialogue zone, trait panel, action area), all presentation hold timers, the background mood layer, and the page-turn close transition. It pushes an MTF blocking layer at open and pops it at close.

**2. Sole expression driver.** Per P&E EC-3, the UI is the only caller of `set_expression()` during a session. It derives the opening expression from a **single read** of `NPCRegistry.get_npc(npc_id).belief_state` at session open; it does **not** subscribe to `npc_state_changed` (a read at open, never a live subscription — a rival-caused change must never auto-correct the portrait mid-session). Expression selection is belief/outcome-driven only (P&E Rule 6); traits never influence expressions at MVP.

**3. Expression call timeline.** Exactly four call sites:

| # | Beat | Trigger | `set_expression()` call |
|---|---|---|---|
| E1 | Session open | `session_begun(npc_id)`; scene `_ready()` | `B2E(belief_state)` — **instant show, no dissolve** (P&E IDLE→SHOWING). CONVERTED NPCs are never approachable, so only `closed_resistant` (STEADFAST), `neutral_listening` (OPEN), `open_receptive` (WAVERING) occur. |
| E2 | Approach land | Player taps an approach button → `select_approach()` | `set_expression("considering_uncertain")` (DCS Step 5) |
| E3 | Outcome | `outcome_resolved(outcome, summary_line, revealed_trait_id)` — UI then reads `get_npc(npc_id).belief_state` (apply already committed, DCS AC-9.5) | PERSUADED or SOFTENED → `open_receptive`; **except** PERSUADED with new state CONVERTED → `moved_convinced` (conversion moment). RESISTED or HARDENED → `withdrawn_resistant`. |
| E4 | Inspect | `trait_inspected(trait_id)` | **No call** — the portrait does not change while the player reads (P&E: "reading, not provoking") |

Same-key no-op: a SOFTENED outcome on a WAVERING NPC lands on `open_receptive` while `open_receptive` is already displayed → P&E Rule 13 no-op, no dissolve, no signals. The beat is carried by the +100K lighting shift and the outcome line only (see Edge Case EC-11).

**4. Screen layout — two zones, three choice-zone regions.** The portrait zone occupies the upper 60–65% of the safe viewport; the choice zone is the remainder (F1). The choice zone contains three stacked regions whose presence changes by state:

- **Region A — Dialogue zone.** Fixed-height text area at the top of the choice zone. Holds exactly one piece of content at a time: approach category label (APPROACH_CONFIRMED, italic), approach line (LINE_DISPLAYING), outcome summary line (OUTCOME_DISPLAY). No typewriter; full text on placement; 16–17pt body face, left-aligned, word-wrapped. In APPROACH_SELECTION the zone is reserved thin and empty; from LINE_DISPLAYING onward it expands into the space freed by the removed approach grid (max 3 lines at 17pt).
- **Region B — Trait panel.** Present throughout the session. Header row: `display_name` · archetype display name · belief-state label (muted caps), with the `[N traits hidden]` count and the Inspect button on the right. Body: horizontally scrollable row of revealed trait cards (swipe gesture per MTF). Each card shows trait `display_name` + one-line description; **affinity values are never shown**. New cards cross-dissolve in over `trait_card_reveal_ms` (F3).
- **Region C — Action area.** Back button (top-left) + 2×2 approach grid. Visible in APPROACH_SELECTION and APPROACH_CONFIRMED only; the grid is removed at LINE_DISPLAYING (DCS UI Req) and the space reflows to Region A.

**5. Safe-area handling.** The UI reads `DisplayServer.get_display_safe_area()` at scene open and on resize/focus-in. Portrait zone rect = safe-area top through 60–65% of safe-area height (F1); the choice zone occupies the remainder and pads its bottom by the bottom safe inset (home indicator). All primary action buttons sit within the MTF `SAFE_ZONE_BOTTOM_FRACTION` (0.55) region. Orientation is locked portrait (MTF). *(API to be verified against the pinned engine reference at implementation — the reference does not currently document a safe-area API; `get_display_safe_area()` is the standard Godot 4.x call.)*

**6. Input registration.** All interactive targets are registered with the Mobile Touch Framework in `_ready()` and unregistered on `tree_exiting`:

| Target | MTF signal | Registration notes |
|---|---|---|
| 4 approach buttons | `tapped` | ≥ 44×44dp, 48dp preferred; gap ≥ 8dp (16dp recommended) |
| Inspect button | `tapped` | ≥ 44×44dp |
| Back button | `tapped` | ≥ 44×44dp, visually compact |
| Trait card row | `swiped` | horizontal scroll container (no per-card registration) |
| Portrait | — | **NOT registered** (P&E UI Req; MTF consuming-table corrected — see appendix) |

Framework-level protections apply without UI code: 100ms debounce (MTF F-5), 44dp hit-rect inflation, haptic pulse on tap hit. The UI adds one defense of its own: approach buttons become non-interactive within one frame of a tap (DCS EC-9), and `select_approach()`/`trigger_inspect()` are no-ops in invalid states (DCS guards).

**7. Flow states.** The UI mirrors the DCS session state machine as presentation states, with one derived sub-state:

| UI state | DCS state | What the screen shows |
|---|---|---|
| `HIDDEN` | `IDLE` | No scene. Map visible. |
| `OPENING` | (transient, inside `APPROACH_SELECTION`) | Scene instantiates; portrait shows instantly (E1); six textures preload in `_ready()` (P&E Rule 8) — no loading indicator, never blocks on a texture. |
| `APPROACH_SELECTION` | `APPROACH_SELECTION` | Portrait at opening expression. Region A thin/empty. Region B full (header, revealed cards, hidden count, Inspect). Region C: back + 2×2 grid with alignment states. |
| `APPROACH_CONFIRMED` | `APPROACH_CONFIRMED` | E2 (`considering_uncertain`). Region A: italic category label. Buttons non-interactive but still visible. Back/Inspect hidden. Hold `approach_confirm_hold_sec`. |
| `LINE_DISPLAYING` | `LINE_DISPLAYING` | Region A: approach line (from `approach_line_ready`). Region C removed; Region A expands. Hold `dialogue_line_hold_sec`. |
| `RESOLVING` | `RESOLVING` | No visible change. Portrait holds. Non-cancellable. |
| `OUTCOME_DISPLAY` | `OUTCOME_DISPLAY` | E3 expression + lighting shift. Region A: outcome line. Trait card sequencing per DCS Step 9 (normal vs HARDENED). Hold `outcome_display_hold_sec` (HARDENED: `hardened_reveal_hold_sec` + `outcome_display_hold_sec`). |
| `CONVERSION_MOMENT` | (derived, sub-phase of `OUTCOME_DISPLAY`) | Entered when E3 outcome is PERSUADED and `belief_state == CONVERTED`. `set_expression("moved_convinced")`; P&E fires the amber overlay + conversion dissolve; Audio fires the chime on `dissolve_started("moved_convinced")`; the UI starts the background lighting surge (F4). Outcome line sits beneath the portrait. The UI does **not** render its own overlay — P&E owns it. |
| `CLOSING` | `SESSION_COMPLETE` → `IDLE` | On `session_complete`: page-turn dissolve (`scene_transition_duration_sec`), scene freed, texture cache cleared, blocking layer popped, control returns to map. |

**8. Timer ownership (presentation).** The UI owns the presentation hold timers that pace *what the player sees*: `approach_confirm_hold_sec` (label dwell), `dialogue_line_hold_sec` (line dwell before outcome), `outcome_display_hold_sec` / `hardened_reveal_hold_sec` (outcome pacing). Values are read from `GameConfig.ui_timing` at the moment each timer starts (DCS AC-7.11). The UI treats incoming DCS signals as events, not as clock sources: `approach_line_ready` may arrive before the confirm hold expires and is queued until the hold boundary. DCS's own state transitions run on its internal sequencing; the UI contract is signal-driven. *(DCS "Timer Ownership" wording — see Cross-System Updates, item 3.)*

**9. Approach buttons.** All four always shown in APPROACH_SELECTION. At open, and after **every** Inspect reveal, the UI calls `get_approach_alignment(npc_id, approach)` for each of the four and re-renders: `POSITIVE`/`NEUTRAL` → normal; `NEGATIVE` → greyed/de-emphasised but fully tappable (DCS Formula 1 recompute rule). On tap: `select_approach(approach)`; buttons non-interactive immediately (no visual change); removed from layout at LINE_DISPLAYING.

**10. Inspect.** Visible only while hidden traits remain (`revealed_traits.size() < assigned_traits.size()`, or `get_hidden_trait_count(npc_id) > 0`); when all are revealed the button is **fully absent** (not greyed). Available in APPROACH_SELECTION only. Each tap calls `trigger_inspect()`; on `trait_inspected(trait_id)` the UI fetches `TraitDatabase.get_trait(trait_id)` for display fields, animates the card in (F3), decrements the hidden count, and re-runs the alignment recompute (Rule 9). Reveals are permanent — cancelling the session does not revert them (DCS EC-3).

**11. Back / cancel.** A back button is visible in APPROACH_SELECTION only; tapping it calls `cancel_session()` (DCS AC-1.9). No cancel affordance in any later state (DCS UI Req). Android system back (`NOTIFICATION_WM_GO_BACK_REQUEST`) maps to `cancel_session()` in APPROACH_SELECTION only and is ignored elsewhere.

**12. Approach-count cue.** The UI never shows `approach_count` as a number (DCS Rule 7 / AC-12). When `approach_count == max_approaches_per_npc - 1` at session open, the background mood layer cools by **−150K from the session baseline** (F5) — a quiet, dignified "this may be your last word to her" cue. No text, no counter. Form is fixed at MVP; subject to `/ux-design` per DCS OQ-1.

**13. Mood-lighting layer.** The UI owns the conversation background (Art Bible §2.2: 50–60% of portrait value/saturation; portrait as sole lit object). Per-outcome temperature offsets are authored in the DCS Visual/Audio table and applied by this layer; they are presentation constants sourced from that contract, not re-tunable config at MVP:

| Event | Temperature offset from session baseline | Source |
|---|---|---|
| Session open (baseline) | candlelight ≈ 2800K; background value 50–60% | DCS V/A — session opens |
| Last-approach cue (Rule 12) | −150K | This GDD (DCS Rule 7 / OQ-1) |
| PERSUADED (non-conversion) | +200K warmer | DCS V/A |
| SOFTENED | +100K warmer | DCS V/A |
| RESISTED | −300K cooler | DCS V/A |
| HARDENED (Beats 1–2) | −350K cooler (−300..−400K band) | DCS V/A |
| CONVERTED (conversion moment) | +500K warmer (+400..+600K band), surge envelope F4 | DCS V/A |

The temperature→colour mapping is an authored ramp (≈3 stops) in the scene, derived from the Art Bible lighting register.

**14. Rival interference — deliberately no session-screen UI.** The rival acts only during turn processing (Rival Faith System Rule 1); a session never overlaps a rival action. Per the Rival Faith GDD, rival activity is "not a UI interrupt but a world that pushes back": it reaches the player through (a) NPC state — a regressed NPC opens with `open_receptive` (WAVERING) and a "Wavering" belief label; (b) the map — the `rival_acted` marker is Village Map View's (system #13). The Conversion UI renders no rival element. If a future design wants an in-session "rival interference" toast, it would require a new RivalFaithSystem signal — post-MVP option (Open Questions OQ-4).

**15. Signal contract — consumed.** The UI subscribes to:

| Signal | Owner | Used for |
|---|---|---|
| `session_begun(npc_id)` | DCS | Open scene, read NPC, opening expression (E1) |
| `approach_line_ready(line)` | DCS | Place approach line (queued to hold boundary) |
| `outcome_resolved(outcome, summary_line, revealed_trait_id)` | DCS | E3, lighting, trait-card sequencing, conversion-moment entry |
| `trait_inspected(trait_id)` | DCS | Card reveal + alignment recompute (E4) |
| `session_complete()` | DCS | CLOSING → teardown (note: emitted by DCS; the GSM consumes it, the UI does too) |
| `dissolve_started(key)` / `dissolve_completed(key)` | P&E | Optional sync; default: lighting surge starts with the UI's own E3 call for `moved_convinced`; `dissolve_started("moved_convinced")` is the audio hook (Audio System) — the UI does not block text on dissolve |
| `npc_state_changed` | NPCRegistry | **Not subscribed.** Read once at open only (Rule 2) |
| `village_cleared()` | GSM | Defensive: if a session scene is alive when the village clears, free it immediately with no commit (unreachable in normal play — see EC-8) |

The UI also consumes MTF signals (`tapped` per target, `swiped` for the card row, `long_press_started`/`long_press_released`/`touch_cancelled` for the approach tooltip) and OS notifications (`NOTIFICATION_WM_WINDOW_FOCUS_OUT`/`NOTIFICATION_APPLICATION_PAUSED` for timer suspension, `NOTIFICATION_WM_GO_BACK_REQUEST` for Android back).

**16. Long-press tooltip.** Per MTF UI contract: `long_press_started` on an approach button shows a small overlay with the approach's canonical one-line description ("GRIEF — speak to their sorrow"); dismissed on `long_press_released` or `touch_cancelled` (MTF EC-8). Copy is content-owned, localised via `tr()`.

**17. Scene tree skeleton (reference).**
```
ConversationScreen (Control, full rect, CanvasLayer above map)
├─ MoodLayer (ColorRect — background value/temperature)     [UI-owned]
├─ PortraitContainer (Control — portrait zone rect)
│   └─ PortraitController (instantiated; P&E-owned rig)
└─ ChoiceZone (Control — safe-area remainder)
    ├─ DialogueZone (Region A — label/line area)
    ├─ TraitPanel (Region B — header + scroll card row + Inspect)
    └─ ActionArea (Region C — BackButton + ApproachGrid 2×2)
```

### States and Transitions

| UI state | Valid transitions | Trigger |
|---|---|---|
| `HIDDEN` | → `OPENING` | `session_begun(npc_id)` |
| `OPENING` | → `APPROACH_SELECTION` | Scene `_ready()` completes; portrait shown (E1) |
| `OPENING` | → `HIDDEN` (abort) | `get_npc(npc_id)` returns null (EC-6) — `cancel_session()`, scene freed |
| `APPROACH_SELECTION` | → `APPROACH_CONFIRMED` | Player taps an approach button → `select_approach()` (E2) |
| `APPROACH_SELECTION` | → `HIDDEN` | Back → `cancel_session()`; scene freed (inspect reveals persist); `conversation_closed` emitted |
| `APPROACH_SELECTION` | (stays) | Inspect reveal — card animates, alignment recomputed |
| `APPROACH_CONFIRMED` | → `LINE_DISPLAYING` | Confirm hold elapses; approach line displayed |
| `LINE_DISPLAYING` | → `RESOLVING` | Dialogue-line hold elapses; outcome resolution in progress |
| `RESOLVING` | → `OUTCOME_DISPLAY` | `outcome_resolved` received |
| `OUTCOME_DISPLAY` | (→ `CONVERSION_MOMENT` sub-phase) | PERSUADED + `belief_state == CONVERTED` |
| `OUTCOME_DISPLAY` | → `CLOSING` | Outcome hold(s) elapse → `session_complete` |
| `CLOSING` | → `HIDDEN` | Page-turn completes; scene freed; blocking layer popped; `conversation_closed` emitted |
| any | → `HIDDEN` (defensive) | `village_cleared()` while scene alive (EC-8) |

### Interactions with Other Systems

| System | Relationship | Interface |
|---|---|---|
| Dialogue & Conversion System | Upstream — session contract | Calls: `begin_session(npc_id)` (on map tap), `select_approach(approach)`, `trigger_inspect()`, `cancel_session()`, `get_approach_alignment(npc_id, approach)`. Subscribes: all five signals (Rule 15). |
| Portrait & Expression System | Upstream — expression rig + scene lifecycle | Instantiates `PortraitController`; calls `set_expression()` (Rule 3); subscribes `dissolve_started`/`dissolve_completed` (optional). Sole expression driver per P&E EC-3. |
| Mobile Touch Framework | Upstream — input | Registers/unregisters targets (Rule 6); `push_blocking_layer`/`pop_blocking_layer` on open/close; consumes `tapped`/`swiped`/`long_press_*`/`touch_cancelled`. |
| NPC Character System | Upstream — read-only data | `get_npc(npc_id)` (belief_state, display_name, revealed_traits, assigned_traits, approach_count), `get_hidden_trait_count()`, `get_archetype_definition()`. Never calls mutation APIs. |
| NPC Trait Database | Upstream — read-only display data | `get_trait(trait_id)` for card display fields only (never affinity). |
| Game Config | Upstream — timing values | `GameConfig.ui_timing` (dialogue_line_hold_sec, outcome_display_hold_sec, approach_confirm_hold_sec, hardened_reveal_hold_sec, scene_transition_duration_sec, trait_card_reveal_ms [new], portrait_expression_hold_frames). Read at timer start. |
| Game State Manager | Peer — lifecycle signal only | Subscribes `village_cleared` (defensive teardown). GSM consumes `session_complete` independently. No GSM method calls. |
| Village Map View | Peer — handoff | Receives control at `CLOSING`; CONVERTED map-return ink-bleed (DCS V/A Phase 2) and `rival_acted` marker are VMV-owned (system #13). |
| Save & Load System | Peer — persistence | No direct interface. Save triggers fire on `session_complete` and OS background; mid-session kills restore `IN_SESSION → IDLE` (conversation not restored). Pending-session sentinel (DCS Rule 9) covers `RESOLVING` kills. |
| Audio System | Downstream — reaction | Subscribes to `dissolve_started("moved_convinced")` for the conversion chime; outcome cues per DCS V/A. |

**Exposed API (scene node — not Autoload):**
```gdscript
# ConversationScreen (scene root)

# Called by the scene router (Village Map View tap handler)
func begin_conversation(npc_id: String) -> void   # calls DCS.begin_session(npc_id)

# Presentation signals
signal conversation_closed()   # emitted after teardown on EVERY teardown path — session-complete,
                               # back/cancel, AND defensive village-clear (VMV depends on it as its
                               # single resume signal — Village Map View GDD AC-06)
```

## Formulas

### F1 — Portrait / Choice Zone Split

```
safe_height      = DisplayServer.get_display_safe_area().size.y
portrait_height  = round(safe_height × PZF)
choice_height    = safe_height − portrait_height
```

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `safe_height` | Safe viewport height | float | device-dependent | Height of the display safe area (notch/home indicator excluded) |
| `PZF` | Portrait zone fraction | float | [0.60, 0.65] | Portrait share of safe height. Default **0.625** (DCS UI Req: upper 60–65%). |
| `portrait_height` | Portrait zone height | float | ≥ 0 | Rect height handed to `PortraitContainer`; P&E fills whatever rect it is given |
| `choice_height` | Choice zone height | float | ≥ 0 | Remaining safe height for Regions A–C |

**Output range:** `portrait_height ∈ [0.60, 0.65] × safe_height`. `PZF` is a constant at MVP (Art Bible §7.4 and DCS pin the band); promotion to `PortraitConfig`-style config is possible post-MVP.

### F2 — Approach Grid Sizing

```
zone_w_dp   = choice_width_px / pixels_per_dp
cell_w_dp   = (zone_w_dp − 3 × GAP_DP) / 2
cell_h_dp   = clamp((action_h_dp − GAP_DP) / 2, 44, 64)
```

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `choice_width_px` | Choice zone width | float | device-dependent | Physical pixels, from layout |
| `pixels_per_dp` | dp scale | float | ≥ 1.0 | MTF read-only property (F-1) |
| `zone_w_dp` | Choice zone width | float | ≥ 0 | In dp |
| `GAP_DP` | Grid gap | float | [8, 16] | `TAP_TARGET_MIN_GAP_DP` = 8 minimum; 16 recommended |
| `action_h_dp` | Region C height | float | ≥ 0 | Available height for the action area |
| `cell_w_dp` / `cell_h_dp` | Cell size | float | ≥ 44 dp | Each approach button's layout size; never below `TAP_TARGET_MIN_SIZE_DP` (MTF inflates if violated, and logs a debug warning) |

**Output range:** each cell ≥ 44×44dp. Layout must fit the minimum supported logical size 360×640dp with all targets ≥ 44dp (AC-01).

### F3 — Trait Card Reveal Alpha

```
a(t) = t / D_t        for t ∈ [0, D_t]
D_t = GameConfig.ui_timing.trait_card_reveal_ms / 1000.0
```

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `t` | elapsed time | float | [0, D_t] | Seconds since the card reveal began |
| `D_t` | Reveal duration | float | [0.2, 0.6] | `trait_card_reveal_ms` (default **350ms** — Art Bible §7.4 band 300–400ms) |
| `a(t)` | Card alpha | float | [0.0, 1.0] | Applied as `modulate.a`; linear cross-dissolve |

**Reduced-motion override:** when `AccessibilitySystem.reduced_motion_enabled` is true, the card appears at `a = 1.0` instantly (no tween).

### F4 — Conversion Lighting Surge (background temperature)

```
T(t) = T_base + ΔT_converted × env(t)

env(t) =
  (t / T_in)²                        if 0 ≤ t < T_in
  1                                  if T_in ≤ t < T_in + T_hold
  (1 − (t − T_in − T_hold) / T_out)² if T_in + T_hold ≤ t ≤ T_total
  0                                  if t > T_total
```

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `t` | time since surge start | float | ≥ 0 | Seconds since the UI entered `CONVERSION_MOMENT` |
| `T_base` | Session baseline | float | ≈2800K | Candlelight baseline (DCS V/A) |
| `ΔT_converted` | Conversion offset | float | [400, 600]K | **+500K** default (DCS V/A band) |
| `T_in` | Rise duration | float | [0.4, 0.6] | **0.5s** default (DCS V/A) |
| `T_hold` | Hold duration | float | [1.5, 2.0] | **1.75s** default (DCS V/A) |
| `T_out` | Fade duration | float | 0.8 | **0.8s** default (DCS V/A) |
| `T_total` | Surge lifetime | float | > 0 | `T_in + T_hold + T_out` = 3.05s at defaults |
| `env(t)` | Envelope | float | [0.0, 1.0] | Quadratic ease-in, flat hold, quadratic ease-out |
| `T(t)` | Mood layer temperature | float | [T_base, T_base + ΔT] | Mapped to colour via the authored temperature ramp |

The surge may overlap the map-return page-turn (DCS V/A: the chime carries through the dissolve) — the UI starts it at `CONVERSION_MOMENT` entry and does not cut it early. **Reduced-motion override:** skip the rise; apply `T(T_total)`-equivalent static warm cast, fade over 100ms (mirrors P&E F4 reduced-motion envelope).

### F5 — Approach-Count Cue Condition

```
cue_active = (approach_count == max_approaches_per_npc − 1)

T_open(t) = T_base − 150K   if cue_active
            T_base          otherwise
```

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `approach_count` | Approaches used | int | [0, max] | `NPCRegistry.get_npc(npc_id).approach_count`, read once at session open |
| `max_approaches_per_npc` | Cap | int | [1, 20] | `GameConfig.conversion.max_approaches_per_npc` (default 5) |
| `cue_active` | Cue flag | bool | {true, false} | True exactly when one approach remains (DCS Rule 7) |
| `T_open` | Opening mood temperature | float | ≈2650K when active | −150K is a fixed authored value at MVP; candidate for config if playtest needs it |

## Edge Cases

**EC-1. Rapid double-tap on an approach button.** MTF's 100ms debounce (F-5) discards a bounce tap at the same position; the UI additionally makes all four buttons non-interactive within one frame of the first tap (DCS EC-9); `select_approach()` is a no-op after `APPROACH_CONFIRMED` (DCS AC-1.11). Triple protection — no double fire, no state corruption.

**EC-2. Tap during hold states (APPROACH_CONFIRMED … RESOLVING).** The blocking layer is still active and the approach grid is either non-interactive or removed. A tap on empty choice-zone space is an MTF miss — no signal, no haptic (MTF V/A: silence on a miss is intentional).

**EC-3. Inspect tapped when all traits are already revealed.** The button is fully absent in that case (Rule 10); if a stale UI state still offers it, `trigger_inspect()` is a safe no-op (NPC CS E10, DCS AC-4.6).

**EC-4. Alignment recompute after Inspect.** The UI must call `get_approach_alignment()` for all four approaches after **every** `trait_inspected` (DCS Formula 1 recompute rule). Failing to do so leaves stale grey states for the remainder of the session.

**EC-5. `get_npc(npc_id)` returns null at session open.** Data error (should be unreachable — DCS gated approachability). The UI logs an error, calls `cancel_session()` to back the DCS state machine out of `APPROACH_SELECTION`, frees the scene, and returns to the map. No crash; no further DCS calls (EC-6 below is the abort path from `OPENING`).

**EC-6. Scene aborted during `OPENING` (missing NPC / failed portrait instantiation).** P&E's missing-texture fallbacks (P&E EC-6/7) keep the session alive; only a null NPC record aborts. The abort path frees the scene; the DCS session is cancelled via `cancel_session()` (valid in `APPROACH_SELECTION`).

**EC-7. Reduced motion enabled.** P&E snaps expressions and trims the overlay (P&E Rule 12); the UI snaps trait-card reveals (F3 override), shortens the conversion lighting surge to a static-warm fade (F4 override), and skips the page-turn's motion component (instant transition). All colour cues remain — colour is never the sole signal (P&E EC-9: audio + lighting give a second channel).

**EC-8. `village_cleared()` while a session scene is alive.** Unreachable in normal play (clear runs only after win/loss, and win/loss run during turn processing, never mid-session). Defensive: the UI frees the scene immediately, pops the blocking layer, makes no NPCRegistry calls, and **emits `conversation_closed`** so the map never waits on a signal that will not arrive (Village Map View GDD AC-06/EC-11 — the map treats a stale-id close as a no-op). DCS resets its recency state on the same signal (GSM Rule 7); any partially-won session is discarded (NPC state unchanged — `apply_conversion_outcome` never ran).

**EC-9. App backgrounded mid-session.** On focus-out, the UI cancels the active presentation hold timer; on focus-in, it restarts the same hold from its current state and recomputes the layout against the current safe area. If the process is killed: Save & Load restores `IN_SESSION → IDLE` (Save & Load Rule 6) — the conversation is not restored, the player returns to the map, and no dialogue is shown; a kill inside `RESOLVING` is covered by the DCS pending-session sentinel (RESISTED, no benefit). Timers cannot fire while suspended.

**EC-10. Orphaned `session_complete` with no active scene.** Ignored (no scene to tear down). The GSM independently discards orphaned signals (GSM EC-5). No double teardown.

**EC-11. Same-key outcome expression (SOFTENED on a WAVERING NPC).** E3 requests `open_receptive` while `open_receptive` is already displayed → P&E Rule 13 no-op: no dissolve, no `dissolve_*` signals. The beat is carried by the +100K lighting shift, the outcome line, and (SOFTENED) audio. Correct per P&E — do not "fix" by forcing a redundant dissolve.

**EC-12. Long dialogue lines.** Region A word-wraps to max 3 lines at 17pt; the dialogue-content pools are authored to fit (DCD line-length guideline). If content violates the limit, the text is clipped at the zone bounds — never scaled down, never pushed into Region B. No typewriter, no scrolling (DCS AC-13).

**EC-13. Safe-area change mid-session.** Portrait-locked (MTF), so rotation is excluded; split-screen/inset changes on focus-in recompute the layout via F1 and re-run the MTF registration (targets move — re-registration is idempotent).

**EC-14. Multi-finger input.** MTF discards all `finger_index != 0` events (Rule 2) — the active gesture continues; the UI needs no handling.

**EC-15. Missing archetype definition / portrait path.** P&E EC-6/7 fall back to `closed_resistant` (or a solid placeholder) and the session continues. The UI renders whatever the rig displays — no crash, no blocker (a missing face must never crash a conversion).

**EC-16. HARDENED on a STEADFAST NPC.** Belief state does not regress (NPC CS E5), but the HARDENED display path still plays: trait card first (Beat 1), `hardened_reveal_hold_sec`, then the outcome line (DCS EC-8). Expression = `withdrawn_resistant` (P&E outcome mapping) even though state stayed STEADFAST — the face shows the wall rebuilt, which is the emotional truth.

**EC-17. `approach_count` unreadable (null NPC).** Cannot occur — a null NPC aborts at `OPENING` (EC-6). If the read itself fails defensively, `cue_active = false` (no cue) rather than crashing.

**EC-18. Alignment signal leaks hidden information.** The UI only renders `get_approach_alignment()` output; it never queries `get_affinity()`, `assigned_traits`, or `ConversionLogicEngine` (DCS Formula 1 constraint; AC-5.8 analog). Hidden traits never affect button visuals.

**EC-19. Approach tooltip cancelled mid-hold.** MTF EC-8: if a long press transitions to a swipe, `long_press_released` is not emitted — the UI must dismiss the tooltip on `swiped` or `touch_cancelled` as well as `long_press_released` (MTF consuming-system contract).

## Dependencies

### Systems This System Depends On

| System | GDD | Type | Interface |
|---|---|---|---|
| Dialogue & Conversion System | `dialogue-conversion-system.md` | **Hard** | Session state machine, all command calls (`begin_session`, `select_approach`, `trigger_inspect`, `cancel_session`, `get_approach_alignment`), all five signals. Without it no session begins or resolves. |
| Portrait & Expression System | `portrait-expression-system.md` | **Hard** (lifecycle) | P&E is instantiated by this scene; `set_expression()` calls per Rule 3; `dissolve_started`/`dissolve_completed` signals; P&E EC-3 sole-driver contract. |
| Mobile Touch Framework | `mobile-touch-framework.md` | **Hard** | `register()`/`unregister()`, `push_blocking_layer()`/`pop_blocking_layer()`, `pixels_per_dp`, gesture signals. |
| NPC Character System | `npc-character-system.md` | **Hard** | `get_npc()`, `get_hidden_trait_count()`, `get_archetype_definition()` — read-only. |
| NPC Trait Database | `npc-trait-database.md` | **Soft** | `get_trait(trait_id)` for card display fields. If unavailable, trait cards render placeholder text and Inspect still works (reveal count updates). |
| Game Config | `game-config.md` | **Hard** | `GameConfig.ui_timing.*` values (Rule 8). One new field proposed: `trait_card_reveal_ms` (appendix A). |
| Accessibility System | *(GDD pending — Alpha)* | **Soft (provisional)** | `AccessibilitySystem.reduced_motion_enabled: bool` (default `false` if absent — P&E Rule 12 precedent). |
| Godot Engine | `docs/engine-reference/godot/` | **Hard** | `Control`, `TextureRect`, `ColorRect`, `Tween`, `CanvasLayer`, `DisplayServer.get_display_safe_area()` (verify at implementation), `tr()` localisation. Godot 4.6 dual-focus note: all interactive targets are touch-driven; keyboard focus is out of scope at MVP but must not be broken by `mouse_filter` misuse. |

### Systems That Depend On This System

| System | GDD | What It Uses |
|---|---|---|
| Village Map View | *(GDD pending — system #13)* | Receives control at `conversation_closed`; renders the CONVERTED ink-bleed (DCS V/A Phase 2) and `rival_acted` marker on the map layer. |
| Audio System | *(GDD pending — system #16)* | Subscribes to `dissolve_started("moved_convinced")` for the conversion chime; outcome cues per DCS V/A. |
| Tutorial & Onboarding | *(GDD pending)* | Observes DCS signals (via the same stream the UI uses) as non-blocking hooks; must not intercept the session sequence. |
| Save & Load System | `save-load-system.md` | Triggered by `session_complete` (its own subscription); no dependency on this scene. |

### Architectural Notes

- The UI is a **scene**, not an Autoload — one instance per conversation (P&E Rule 10 ownership model). No shared conversation-screen singleton.
- **No persistent state.** Everything the screen shows derives from NPCRegistry reads + DCS signals; nothing is serialized. On teardown all tweens are killed and the P&E texture cache is cleared (P&E EC-13).
- **No content ownership.** All strings come from DCS signals, TraitDatabase, or NPC records — the UI contains no authored dialogue copy (DCD Rule: logic systems never contain copy).

## Tuning Knobs

### New field — `GameConfig.ui_timing` (owned by Game Config GDD; proposed by this GDD)

| Knob | Field | Default | Safe Range | Effect | What Breaks at Extremes |
|---|---|---|---|---|---|
| Trait card reveal | `trait_card_reveal_ms` | 350 | 200–600 | Cross-dissolve duration for trait cards appearing via Inspect and outcome reveals (F3). | Below 200ms: reads as a blink. Above 600ms: stalls the approach screen on mobile. Design target 300–400ms (Art Bible §7.4). |

### Existing fields consumed (owned by Game Config GDD)

| Knob | Field | Default | Safe Range | Effect |
|---|---|---|---|---|
| Approach confirm hold | `approach_confirm_hold_sec` | 0.6 | 0.3–1.2 | Dwell of the "held breath" beat (DCS-proposed new field — must land in UITimingConfig before implementation) |
| HARDENED reveal hold | `hardened_reveal_hold_sec` | 1.0 | 0.5–1.5 | Gap between HARDENED Beat 1 (trait card) and Beat 2 (outcome line) (DCS-proposed new field) |
| Dialogue line hold | `dialogue_line_hold_sec` | 2.0 | 0.5–5.0 | Dwell of the approach line |
| Outcome display hold | `outcome_display_hold_sec` | 2.5 | 0.5–5.0 | Dwell of the outcome line; also the conversion-moment window |
| Scene transition | `scene_transition_duration_sec` | 0.5 | 0.1–2.0 | Page-turn close duration |
| Expression hold | `portrait_expression_hold_frames` | 30 | 1–120 | P&E dwell (consumed by P&E, not read by this scene directly) |

### Fixed authored values (not config at MVP — sourced from DCS V/A / Art Bible)

| Value | Value | Source |
|---|---|---|
| Portrait zone fraction | 0.60–0.65 (default 0.625) | DCS UI Req |
| Background value at session open | 50–60% of portrait value | Art Bible §2.2 |
| Baseline temperature | ≈2800K candlelight | Art Bible §2.2 |
| Outcome temperature offsets | ±100K … ±500K table (Rule 13) | DCS V/A |
| Last-approach cue offset | −150K | This GDD (Rule 12) |

**Promotion candidates:** if playtest needs live lighting tuning, promote the temperature offsets to a `ConversionUIConfig` domain (8th) — see Open Questions OQ-2.

### Interaction warnings

- `outcome_display_hold_sec` vs conversion surge: at defaults the surge lifetime is 3.05s vs a 2.5s outcome hold — the fade intentionally overlaps the map-return page-turn (DCS V/A). If `outcome_display_hold_sec` is ever lowered below ≈2.0s, shorten `T_hold`/`T_out` (F4) or the conversion warmth will be cut.
- `approach_confirm_hold_sec` + `dialogue_line_hold_sec`: tuning both to their minimums collapses the approach-to-outcome rhythm (DCS interaction warning) — the UI GDD inherits it.
- `trait_card_reveal_ms` interacts with `portrait_expression_hold_frames` only in the visual sense that two tweens (card + portrait) never run concurrently in the same element — no mechanical coupling.

## Visual/Audio Requirements

The screen operates in the Art Bible §2.2 Conversation register. All visual event requirements are **owned by DCS V/A** (portrait cross-dissolves, the considering beat, outcome lighting, the conversion surge, the CONVERTED chime) or **P&E** (overlay, dissolve rig). This system's Visual/Audio responsibilities are limited to:

| Element | Requirement |
|---|---|
| Background mood layer | Applies the Rule 13 temperature table + 50–60% value drop. The only animated background property is the conversion surge (F4). |
| Approach buttons | Placed without entrance animation ("a scribe setting them down" — DCS V/A). Pressed-state visual on `tapped`; NEGATIVE grey state; long-press tooltip overlay. No ripple (MTF: visual feedback is consuming-system's, art-directed). |
| Trait cards | Cross-dissolve at `trait_card_reveal_ms`; grisaille marginalia treatment per DCS V/A (Iron Ink outline, 40–60% mid-value fill, semantic colour per trait category). |
| Back button | Compact chevron, placed — not animated. |
| Close transition | Page-turn dissolve at `scene_transition_duration_sec` (Art Bible §7.7). Motion component skipped under reduced motion (EC-7). |
| Audio | The UI plays no audio. Chime (P&E `dissolve_started("moved_convinced")`), trait reveal cues, and outcome tones are Audio System's, per DCS V/A. |

## UI Requirements

(Consolidated component spec — the full per-component detail is in Detailed Rules Rules 4–17; this section records the binding constraints.)

| Component | Constraint |
|---|---|
| Portrait zone | Upper 60–65% of safe height; **non-interactive**; no chrome over the portrait (P&E UI Req); aspect-preserving fill; top safe inset respected. |
| Choice zone | Safe-area remainder; bottom safe inset padded; primary actions within MTF `SAFE_ZONE_BOTTOM_FRACTION` (0.55). |
| Approach buttons | 4, 2×2 grid, ≥44×44dp (48 preferred), gap ≥8dp (16 recommended), all four always shown in APPROACH_SELECTION/CONFIRMED, NEGATIVE greyed-but-tappable, removed at LINE_DISPLAYING. |
| Inspect button | Visible iff hidden traits remain; **absent** (not greyed) when none; ≥44×44dp; APPROACH_SELECTION only. |
| Trait panel | Header: display_name · archetype · belief-state label · `[N traits hidden]` · Inspect. Body: horizontal scroll row of cards (name + description; **never affinity numbers**). |
| Dialogue zone | One content piece at a time; no typewriter; no history/scroll; 16–17pt, left-aligned, word-wrap ≤ 3 lines; approach label italic. |
| Back | APPROACH_SELECTION only; ≥44×44dp. |
| Localisation | All visible strings via `tr()`; autowrap enabled (engine-ref best practice). |
| Accessibility | 44dp minimum targets; contrast per Art Bible register (portrait-zone luminance floor per P&E EC-9); reduced-motion honored end-to-end; text scale (Accessibility System, Alpha) deferred. |

## Acceptance Criteria

**AC-01 — Layout and safe areas.** Given minimum supported logical size 360×640dp, when the session opens, then the portrait zone occupies 60–65% of safe height, the choice zone occupies the remainder, the portrait is aspect-correct, all interactive targets are ≥44dp, and no primary action button extends below the bottom safe inset or above the top safe inset.

**AC-02 — Portrait is not a touch target.** Given an active session, when a tap lands on the portrait zone, then no MTF signal fires for the portrait (miss — no haptic, no effect).

**AC-03 — Blocking layer.** Given the session open, then the Village Map's registered areas receive no `tapped` signals while the session scene is alive. After `conversation_closed`, map taps resume.

**AC-04 — Registration hygiene.** Given the scene open, then back, Inspect, and the four approach buttons are registered with MTF at `_ready()` and unregistered on `tree_exiting`; no registration remains after teardown (verified by registry count).

**AC-05 — Opening expression.** Given a STEADFAST NPC, when `session_begun` fires and the scene is ready, then the portrait displays `closed_resistant` instantly and no `dissolve_started` is emitted. Given an OPEN NPC → `neutral_listening`; WAVERING → `open_receptive`.

**AC-06 — Approach land.** Given APPROACH_SELECTION, when the player taps GRIEF, then `select_approach(GRIEF)` is called, the portrait receives `set_expression("considering_uncertain")` within one frame, the italic category label appears in Region A, and all four buttons are non-interactive within one frame.

**AC-07 — Double-tap defense.** Given APPROACH_SELECTION, when two taps land on the same approach button within 100ms, then exactly one `select_approach()` call is made and the session proceeds once.

**AC-08 — Alignment rendering and recompute.** Given an NPC with one revealed trait, when the approach screen opens, then each button's visual state matches `get_approach_alignment(npc_id, approach)` (NEGATIVE greyed, others normal), and after each `trait_inspected` the four buttons are re-rendered from fresh alignment calls — a signal that changes (e.g., NEGATIVE→NEUTRAL) is reflected.

**AC-09 — Inspect flow.** Given an NPC with 2 of 4 traits revealed, then the Inspect button is visible and the hidden count reads `[2 traits hidden]`. After one Inspect tap: exactly one card cross-dissolves in over `trait_card_reveal_ms ± 16ms`, the count reads `[1 trait hidden]`, and the alignment recompute fires. After the second: the count label and the Inspect button are both removed from the layout.

**AC-10 — Inspect state gating.** Given any state other than APPROACH_SELECTION, then no Inspect affordance is present or tappable; a synthetic `trigger_inspect()` call changes nothing.

**AC-11 — Dialogue zone sequencing.** Given a session reaching LINE_DISPLAYING, then the approach line replaces the label (no typewriter, no accumulation), the action area is removed, and at OUTCOME_DISPLAY the outcome line replaces the approach line. At no point does more than one piece of dialogue content occupy Region A; no text from a prior session persists on a new session open.

**AC-12 — Outcome expressions.** Given `outcome_resolved`, then `set_expression` receives: `open_receptive` for PERSUADED (non-conversion) and SOFTENED; `withdrawn_resistant` for RESISTED and HARDENED. Each call is made in the same frame as the signal handler, and no additional `set_expression` call occurs between the outcome and teardown.

**AC-13 — Conversion moment.** Given `outcome_resolved(PERSUADED, …)` and post-apply `belief_state == CONVERTED`, then `set_expression("moved_convinced")` is called, the P&E amber overlay fires (UI renders none), the mood layer begins the F4 surge (+500K, 0.5s rise), and the outcome line is placed beneath the portrait. `dissolve_started("moved_convinced")` is emitted by P&E for the audio hook.

**AC-14 — Trait card sequencing.** Given a PERSUADED/SOFTENED outcome with `revealed_trait_id` non-empty, then the trait card animates in **after** `outcome_display_hold_sec` elapses. Given HARDENED, the trait card appears **first**, holds `hardened_reveal_hold_sec`, then the outcome line appears. Given RESISTED, no trait card appears.

**AC-15 — RESISTED presentation.** Given RESISTED, then no trait card is shown, the mood layer cools −300K, and the portrait holds `withdrawn_resistant` for the remainder of the session.

**AC-16 — Teardown.** Given `session_complete`, then the UI plays the page-turn (`scene_transition_duration_sec`), frees the scene, clears the P&E texture cache, pops the blocking layer, and emits `conversation_closed` exactly once; `PortraitController` reports no orphan tweens (P&E EC-13 check).

**AC-17 — Defensive village clear.** Given an active session scene when `village_cleared()` fires (synthetic test), then the scene frees immediately, no NPCRegistry mutation occurs, and no `select_approach`/`trigger_inspect` call follows.

**AC-18 — Missing NPC data.** Given `get_npc(npc_id)` returns null at session open, then the UI logs an error, calls `cancel_session()`, frees the scene, and returns to the map without crashing and without any further DCS command calls.

**AC-19 — Reduced motion.** Given `AccessibilitySystem.reduced_motion_enabled = true`, then trait cards appear instantly (no tween), the conversion lighting applies a static warm cast fading over 100ms (no surge motion), the page-turn skips its motion component, and expressions snap per P&E AC-10/AC-11.

**AC-20 — Backgrounding.** Given a session in APPROACH_CONFIRMED and a focus-out, then the active hold timer is cancelled; on focus-in the same hold restarts from the current state and the layout recomputes against the current safe area. Given a process kill during a session, a fresh launch restores to the map (IN_SESSION → IDLE), with no dialogue screen and no committed outcome.

**AC-21 — Approach-count cue.** Given `approach_count == max_approaches_per_npc − 1` at session open, then the mood layer opens at −150K from baseline and no numeric approach-count text appears anywhere in the scene. Given any other count, the cue is absent.

**AC-22 — No hidden-information leak.** Given any session, when the approach buttons are rendered, then their visual states derive exclusively from `get_approach_alignment()` output; the UI never calls `get_affinity()`, reads `assigned_traits`, or calls `ConversionLogicEngine` (verified by code review + debug instrumentation).

**AC-23 — Same-key outcome no-op.** Given a WAVERING NPC (opening `open_receptive`) that resolves SOFTENED, then no `dissolve_started`/`dissolve_completed` is emitted for the outcome expression, the +100K lighting shift applies, and the outcome line displays normally.

**AC-24 — Long-press tooltip.** Given a long press on an approach button, then the approach-description tooltip appears at the 600ms threshold and is dismissed on `long_press_released`, `swiped`, or `touch_cancelled`; it never persists into APPROACH_CONFIRMED.

## Open Questions

**OQ-1. Belief-state label wording.** NPC Character System UI Req requires a belief-state label in the inspection panel. Canonical MVP English: "Stalwart" / "Open" / "Wavering" / "Converted" (via `tr()`). Confirm with the Content Director — wording is content-owned.

**OQ-2. Promotion of lighting values to config.** Rule 13 temperatures are fixed authored values from DCS V/A at MVP. If first playtest needs live lighting tuning, promote the offsets (and the −150K cue) to a new `ConversionUIConfig` 8th domain — mirrors the PortraitConfig precedent. Decision deferred to after playtest.

**OQ-3. `DisplayServer.get_display_safe_area()` verification.** The pinned engine reference does not document a safe-area API. Verify the exact Godot 4.6 call signature at implementation; if unavailable, fall back to `Viewport` insets or a per-device notch table.

**OQ-4. In-session rival feedback (post-MVP).** By design the session screen carries no rival element (Rule 14). If a later build wants the rival's presence inside conversations (e.g., a faint second-shadow cue when the rival targeted this NPC last turn), it needs a new `RivalFaithSystem` signal or a `rival_acted` read — defer; the map marker satisfies the "you feel watched" fantasy at MVP.

**OQ-5. Tutorial overlays.** Tutorial & Onboarding must present guidance without blocking the session (DCS OQ-5). This GDD assumes non-blocking overlays layered above the conversation scene; the Tutorial GDD must confirm it will not mutate this scene's state machine or register its own blocking layer during a session.
