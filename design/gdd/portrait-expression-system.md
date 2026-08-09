# Portrait & Expression System

> **Status**: Designed
> **Author**: game-designer + art-director + ux-designer
> **Last Updated**: 2026-08-09
> **Implements Pillar**: Every Soul Has a Story

## Overview

The Portrait & Expression System renders each NPC as a living face rather than a dialogue box. It maps two inputs — NPC belief state and dialogue beat — to a portrait asset and expression state, then drives smooth cross-dissolves between expressions as the conversation unfolds. At the infrastructure level, the system loads archetype-specific portrait textures from `portrait_asset_path` (defined per `NPCArchetypeDefinition`), resolves the current expression key from game state, and manages the transition pipeline on a `TextureRect`-pair cross-dissolve rig. At the player-facing level, it is the primary source of non-verbal emotional signal in the game: a face that shifts from closed resistance to cautious consideration to genuine conviction, cross-dissolving through states in 300–400ms, with a warm-colour overlay surge when a soul finally turns. Two output formats serve two contexts: a full-screen portrait (780×1014px at 2x) occupying 60–65% of screen height during conversation, and a thumbnail (160×160px at 2x) used on the Village Map to show at-a-glance belief state. The system exposes a single `set_expression(expression_key: String)` interface; the Conversion UI drives it from dialogue beat events.

## Player Fantasy

The fantasy is not yours alone — it is mutual. Across every conversation, you are watching a soul, and the portrait makes it impossible to forget that they are also a person being watched. When their expression shifts from `closed_resistant` to `considering_uncertain`, you feel the small moral weight of having reached someone. When you fail and the portrait cools, you feel the small moral weight of having pushed too hard.

This is the system's core purpose: not to animate a face, but to make every approach choice feel like it is being received by a person. Conversion, when it comes, should feel earned — not because the numbers cleared, but because you watched the face across the table slowly open to you. Failure should leave a residue: the withdrawn warmth, the cooled expression, the reminder that you are doing something *to* another person.

Pillar served: **Every Soul Has a Story** — the portrait is the constant reminder that conversion is not a transaction.

## Detailed Design

### Core Rules

**1. Expression key contract.** An expression key is a String that maps to one portrait texture in an NPC's archetype portrait set. The Conversion UI calls `PortraitController.set_expression(expression_key)` — this is the only external write interface. The system loads the texture corresponding to the key, cross-dissolves to it, and holds it until the next `set_expression()` call or the conversation ends.

**2. Portrait asset location.** Textures are loaded from `portrait_asset_path` defined on `NPCArchetypeDefinition`. The path is a directory (`res://assets/portraits/{archetype_id}/`). The system appends `{expression_key}.png` to construct the full path: `{portrait_asset_path}{expression_key}.png`. All textures for an archetype share the same directory. Missing textures log an error and display `closed_resistant` as a fallback.

**3. Cross-dissolve rig.** The full portrait is a `Control` node containing two stacked `TextureRect` children: `_front_rect` (currently visible expression) and `_back_rect` (incoming expression, initially alpha 0). On `set_expression()`, the incoming texture loads into `_back_rect`; a `Tween` animates `_back_rect.modulate.a` 0.0→1.0 and `_front_rect.modulate.a` 1.0→0.0 simultaneously over the dissolve duration. On tween completion, front/back references are swapped and modulate values reset (front = 1.0, back = 0.0). The tween interpolation is `TRANS_LINEAR` except for the conversion expression (Rule 5).

**4. Dissolve interruption.** If `set_expression()` is called while a dissolve is in progress, the current tween is killed immediately. `_back_rect` becomes the new front at its current alpha (not snapped to 1.0), and a new tween begins toward the newly requested expression. Expression changes never queue — the most recent call always wins. The resume math is defined in §Formulas (F3). *Extension (Rule 11) adds a coalescing hold window; see Rule 11 for how interruption and the hold window compose.*

**5. Conversion warm-colour overlay.** When `set_expression("moved_convinced")` is called, a `ColorRect` overlay (`conversion_overlay_color` from `GameConfig.portraits`) animates above the dissolve rig:

| Phase | Timing | Modulate Alpha | Easing |
|---|---|---|---|
| Surge | 150ms | 0.0 → 0.55 | ease-in |
| Hold | 50ms | 0.55 | — |
| Fade | 500ms | 0.55 → 0.0 | ease-out |

The conversion dissolve uses `TRANS_SINE / EASE_IN_OUT` at `GameConfig.portraits.conversion_dissolve_duration_ms` (default 400ms vs. 350ms standard). The overlay fires once per call regardless of previous expression state. Exact envelope: §Formulas (F4). Under reduced motion, the surge and hold phases are skipped (Rule 12).

**6. Expression key set — MVP.** Six expression keys are defined. Every archetype portrait set must provide a texture for each:

| Expression Key | Emotional Register | Primary Trigger |
|---|---|---|
| `closed_resistant` | Closed, guarded, unreachable | Belief state: STEADFAST; conversation default at session start |
| `neutral_listening` | Present, non-committed, observing | Conversation baseline; belief state: OPEN |
| `considering_uncertain` | Interior conflict, something landed | Approach delivered — awaiting outcome |
| `open_receptive` | Warmth, openness, being reached | Belief state: WAVERING; SOFTENED/PERSUADED outcome |
| `withdrawn_resistant` | Withdrawal, defence, emotional wall rebuilt | RESISTED or HARDENED outcome |
| `moved_convinced` | Conviction, transformation, arrival | Conversion moment; belief state: CONVERTED |

*(Consistency correction: an earlier draft listed a `CLOSED` belief state here. Canonical belief states are `STEADFAST → OPEN → WAVERING → CONVERTED` per the NPC Character System GDD — `CLOSED` does not exist and is removed.)*

**7. Thumbnail format.** The thumbnail (160×160px at 2x) is a `TextureRect` owned and managed by the Village Map View — not part of the cross-dissolve rig. It displays a static belief-state expression and does NOT update during active conversations. It updates when `npc_state_changed` fires (Village Map View subscribes directly). Belief-state → thumbnail expression mapping:

| Belief State | Thumbnail Expression Key |
|---|---|
| STEADFAST | `closed_resistant` |
| OPEN | `neutral_listening` |
| WAVERING | `open_receptive` |
| CONVERTED | `moved_convinced` |

*(Consistency correction: the `CLOSED → closed_resistant` row from the earlier draft is removed — `CLOSED` is not a canonical belief state.)*

**8. Texture caching.** Textures are loaded via `ResourceLoader.load()` on first access and cached in a `Dictionary` keyed by `"{archetype_id}/{expression_key}"`. All six expression textures for the current NPC's archetype are pre-loaded in `_ready()` when the `PortraitController` node is instantiated (which occurs when the Conversion UI scene opens). The cache is cleared when `session_complete` fires and the Conversion UI scene is destroyed. Village Map thumbnails cache only the belief-state expression for each NPC, not all six.

**9. No ambient animation.** The portrait is static between expression changes — no idle breathing, no blink cycles, no ambient motion. The cross-dissolve is the only animation the system produces. Stillness between transitions makes each dissolve land.

**10. Ownership model.** `PortraitController` is a scene-level node instantiated by the Conversion UI scene — not an Autoload. One instance exists per active conversation; it is created and destroyed with the conversation scene. The Village Map View manages its own thumbnail `TextureRect` nodes independently. No singleton coordinates all portrait state.

**11. Expression hold window (minimum dwell).** After a dissolve completes, the newly shown expression is locked for `GameConfig.ui_timing.portrait_expression_hold_frames` (default 30 frames ≈ 500ms at 60Hz). `set_expression()` calls arriving during the lock do **not** start a tween immediately and are **not queued**: they are coalesced — if one or more calls arrive during the lock, only the most recent key is retained and applied when the lock expires (the dissolve then runs as a normal interrupt per Rule 4/F3). This prevents flicker from rapid-fire UI calls while preserving the "most recent call wins" invariant. Two exceptions: (a) a call whose key equals the currently displayed key is a no-op even during the lock (Rule 13); (b) the conversion overlay (Rule 5) fires immediately regardless of the lock — the emotional surge must not be delayed. The lock is measured in rendered frames, so its wall-clock duration is refresh-rate dependent (see Edge Case EC-12).

**12. Reduced-motion accessibility mode.** The system reads `AccessibilitySystem.reduced_motion_enabled` (bool, default `false`) at the moment an expression change is requested — not cached at `_ready()`. When enabled: (a) all expression transitions snap instantly (`reduced_motion_dissolve_ms` = 0 by default — no tween, no intermediate frames); (b) the conversion overlay skips the surge and hold phases and fades from `conversion_overlay_surge_alpha` to 0 over `reduced_motion_overlay_fade_ms` (default 100ms) — the final warm cast still lands as a static colour cue, but no motion is produced; (c) the expression hold window (Rule 11) is skipped — the snap is the only transition. The flag source is the Accessibility System (Alpha-tier, GDD pending) — this is a provisional contract: `AccessibilitySystem` Autoload exposes `reduced_motion_enabled: bool`. If the Autoload is absent in a build, the value defaults to `false`.

**13. Same-key no-op.** If `set_expression(key)` is called and the currently displayed expression is already `key` — and no dissolve toward a different key is in progress — the call returns immediately: no texture load, no tween, no `dissolve_started`/`dissolve_completed` emission. If a dissolve toward `key` is already in progress, the call is likewise a no-op (do not restart the tween). This prevents pointless flicker and redundant texture loads.

---

### States and Transitions

| State | Description |
|---|---|
| `IDLE` | No conversation active. Full portrait hidden or not instantiated. Village Map thumbnails visible. |
| `SHOWING` | Portrait visible, current expression stable. No tween running. Has two subphases: `settled` (hold window elapsed) and `hold_locked` (last dissolve completed fewer than `portrait_expression_hold_frames` frames ago). |
| `DISSOLVING` | Cross-dissolve tween in progress between two expressions. |

| Transition | Trigger | Action |
|---|---|---|
| `IDLE → SHOWING` | Conversion UI scene instantiated | Load belief-state expression for the NPC; display without dissolve (instant show). |
| `SHOWING → DISSOLVING` | `set_expression()` called and expression differs from current | Load incoming texture into `_back_rect`; start tween; emit `dissolve_started`. |
| `DISSOLVING → SHOWING` | Tween completes | Swap front/back refs; reset modulate; start hold window; emit `dissolve_completed`. |
| `DISSOLVING → DISSOLVING` | `set_expression()` called mid-transition | Kill current tween; begin new tween from interrupted modulate state (F3). |
| `SHOWING(hold_locked) → DISSOLVING` | Coalesced `set_expression()` applied when hold window expires | Begin new tween from current (settled) modulate state. |
| `SHOWING → IDLE` | `session_complete` fires; Conversion UI scene freed | Hide portrait; clear texture cache; kill any running tweens. |

Thumbnail transitions are not a state machine — single-frame texture swaps triggered by `npc_state_changed` in Village Map View.

---

### Interactions with Other Systems

| System | Relationship | Interface |
|---|---|---|
| Conversion UI | Upstream — primary driver + scene lifecycle owner | Calls `set_expression(expression_key)` based on dialogue beat and outcome. Responsible for expression key selection logic. Instantiates `PortraitController` at session open; frees it on `session_complete`. May subscribe to `dissolve_started`/`dissolve_completed` for text-reveal or audio synchronisation. |
| NPC Character System (NPCRegistry) | Upstream — asset source | Reads `npc.belief_state` on `_ready()` to determine the opening expression; reads `npc.archetype` → `get_archetype_definition()` → `portrait_asset_path`. Village Map View (not `PortraitController`) subscribes to `npc_state_changed` for thumbnail updates. |
| NPCArchetypeDefinition | Upstream — asset source | Reads `portrait_asset_path` to locate textures per archetype. |
| GameConfig (`PortraitConfig`) | Upstream — visual config | Reads `dissolve_duration_ms`, `conversion_dissolve_duration_ms`, `conversion_overlay_color`, overlay phase timings, `reduced_motion_*` fields. Also consumes existing `UITimingConfig.portrait_expression_hold_frames`. |
| Village Map View | Downstream — thumbnail consumer | Hosts per-NPC thumbnail `TextureRect` nodes. Subscribes to `npc_state_changed` and updates thumbnail expression key per Rule 7 mapping. |
| Rival Faith System | Indirect | Rival-caused regressions fire `npc_state_changed(npc_id, CONVERTED, WAVERING)` → Village Map View reverts that NPC's thumbnail to `open_receptive`. No direct P&E interface. |
| Audio System | Downstream — conversion chime timing | Subscribes to `dissolve_started`; when `expression_key == "moved_convinced"`, fires the conversion chime (per Dialogue & Conversion System Visual/Audio). Optional. |
| NPC Trait Database | Prospective (post-MVP) | The Trait Database Interactions table lists P&E as a consumer of `archetype_tags`/trait IDs for expression selection. **MVP does not read traits** — expression selection is belief/outcome-driven only. Trait-specific micro-expressions are a post-MVP candidate (see Open Questions). |
| Save & Load System | None | Expression state is transient and never serialized. Thumbnails and opening expressions derive from saved belief state. |

**Cross-system updates required before implementation** (full drafts in Appendix below).
- `GameConfig` GDD must add a `PortraitConfig` domain block (new 7th domain) with: `dissolve_duration_ms`, `conversion_dissolve_duration_ms`, `conversion_overlay_color`, `conversion_overlay_surge_alpha`, `conversion_overlay_surge_ms`, `conversion_overlay_hold_ms`, `conversion_overlay_fade_ms`, `reduced_motion_dissolve_ms`, `reduced_motion_overlay_fade_ms`. `UITimingConfig.portrait_expression_hold_frames` already exists — consumed, no change.
- NPC Character System GDD must document the `portrait_asset_path` **format contract** on `NPCArchetypeDefinition` (field exists in schema; format is not yet specified).
- NPC Trait Database GDD: one-line handoff note in the archetypes section (archetype definitions, owned by NPC Character System, carry `portrait_asset_path`; the Trait DB itself does not).

**Exposed API:**
```gdscript
# PortraitController (scene node — not Autoload)

func set_expression(expression_key: String) -> void
# Load and cross-dissolve to the given expression. Interrupts any in-progress
# dissolve (F3). Coalesces calls arriving during the expression hold window
# (Rule 11) — the most recent call wins. No-op for the currently displayed key
# (Rule 13). Conversion overlay fires immediately for "moved_convinced" (Rule 5).

signal dissolve_started(expression_key: String)
# Emitted when a cross-dissolve tween begins. Audio System uses this to time the
# conversion chime when expression_key == "moved_convinced". Not emitted for
# instant (session-open / reduced-motion) swaps.

signal dissolve_completed(expression_key: String)
# Emitted when the cross-dissolve tween finishes. Conversion UI may use this
# to synchronise dialogue text reveal or audio timing with the portrait.
```

## Formulas

### F1 — Standard Cross-Dissolve Alpha (linear)

The standard cross-dissolve alpha formula is defined as:

```
a_back(t) = t / D_s
a_front(t) = 1 - a_back(t)
```

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `t` | elapsed time | float | [0, D_s] | Seconds since the tween started |
| `D_s` | standard dissolve duration | float | [0.15, 0.8] | `GameConfig.portraits.dissolve_duration_ms / 1000.0`. Default: 0.35s (350ms) |
| `a_back(t)` | incoming texture alpha | float | [0.0, 1.0] | `_back_rect.modulate.a`. Animates 0.0 → 1.0 |
| `a_front(t)` | outgoing texture alpha | float | [1.0, 0.0] | `_front_rect.modulate.a`. Mirrors `a_back` — the two layers are complementary, so the composite is always fully opaque |

**Output range:** `a_back(t)` ∈ [0.0, 1.0] for `t` ∈ [0, D_s]. Linear ramp — constant visual rate. Applied with `Tween.TRANS_LINEAR`.

**Example:** `D_s = 0.35`. At `t = 0.175`: `a_back = 0.5` — the incoming and outgoing faces are exactly half-blended. At `t = 0.35`: `a_back = 1.0` — swap completes.

### F2 — Conversion Dissolve Alpha (sine ease-in-out)

The conversion dissolve alpha formula is defined as:

```
a_back(t) = (1 - cos(π · t / D_c)) / 2
a_front(t) = 1 - a_back(t)
```

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `t` | elapsed time | float | [0, D_c] | Seconds since the tween started |
| `D_c` | conversion dissolve duration | float | [0.2, 1.0] | `GameConfig.portraits.conversion_dissolve_duration_ms / 1000.0`. Default: 0.4s (400ms) |
| `a_back(t)` | incoming texture alpha | float | [0.0, 1.0] | `_back_rect.modulate.a` during a conversion dissolve |
| `a_front(t)` | outgoing texture alpha | float | [1.0, 0.0] | Mirror of `a_back` |

**Output range:** `a_back(t)` ∈ [0.0, 1.0]. This is the standard S-curve for `TRANS_SINE / EASE_IN_OUT`: slow start, fast middle, slow landing — the face "arrives" rather than sliding. It is used **only** for `moved_convinced`.

**Example:** `D_c = 0.4`. At `t = 0.1` (quarter elapsed): `a_back = (1 - cos(π/4)) / 2 ≈ 0.146` — noticeably slower than the linear case (0.25). At `t = 0.2` (half elapsed): `a_back = 0.5`. At `t = 0.3`: `a_back ≈ 0.854` — the landing slows.

### F3 — Interrupted Dissolve Resume

The interrupted dissolve resume formula is defined as:

```
a_start = f(τ / D)
a_back(t) = a_start + (1 - a_start) · f(t / D)
a_front(t) = 1 - a_back(t)
```

where `f(u)` is the easing function of the killed tween: `f(u) = u` (linear, F1) or `f(u) = (1 - cos(π·u)) / 2` (sine, F2), and `D` is the killed tween's duration.

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `τ` | interruption time | float | [0, D) | Elapsed time of the killed tween when `set_expression()` interrupted it |
| `a_start` | resumed incoming alpha | float | [0.0, 1.0) | Alpha of the interrupted incoming texture at kill time — `_back_rect` becomes the new front at this alpha (Rule 4), not snapped to 1.0 |
| `D` | killed tween duration | float | > 0 | `D_s` or `D_c` of the killed dissolve |
| `f(u)` | easing function | function | — | The killed tween's easing, applied to the new tween over its own duration |
| `a_back(t)` | new incoming alpha | float | [a_start, 1.0] | Alpha of the newly requested texture over the new tween |
| `a_front(t)` | new outgoing alpha | float | [1.0 - a_start, 0.0] | The interrupted texture fades out from its current composite share |

**Output range:** continuous composite — because `a_back + a_front = 1` holds both during the killed tween and during the resumed tween, the swap from "old back as new front" to "new back" produces no visible discontinuity or flash.

**Example:** A 350ms linear dissolve toward `considering_uncertain` is interrupted at `τ = 0.175` (`a_start = 0.5`) by `set_expression("open_receptive")`. The new tween starts with `open_receptive` at alpha 0.5 (the half-visible `considering_uncertain` face instantly drops to "front" status) and ramps to 1.0 over the full new `D`. The interrupted face is never fully shown — Rule 4's "most recent call wins."

### F4 — Conversion Overlay Alpha Envelope

The conversion overlay envelope formula is defined as:

```
T_total = T_surge + T_hold + T_fade

a_overlay(t) =
    A_max · (t / T_surge)²                                  if 0 ≤ t < T_surge
    A_max                                                   if T_surge ≤ t < T_surge + T_hold
    A_max · (1 - (1 - (t - T_surge - T_hold) / T_fade)²)    if T_surge + T_hold ≤ t ≤ T_total
    0.0                                                     if t > T_total
```

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `t` | time since overlay trigger | float | ≥ 0 | Seconds since `set_expression("moved_convinced")` was called |
| `T_surge` | surge duration | float | [0.05, 0.5] | `GameConfig.portraits.conversion_overlay_surge_ms / 1000.0`. Default: 0.15s (150ms). Eased in (quadratic) — the warmth arrives then accelerates |
| `T_hold` | hold duration | float | [0.0, 0.3] | `GameConfig.portraits.conversion_overlay_hold_ms / 1000.0`. Default: 0.05s (50ms) |
| `T_fade` | fade duration | float | [0.1, 1.5] | `GameConfig.portraits.conversion_overlay_fade_ms / 1000.0`. Default: 0.5s (500ms). Eased out (quadratic) — the warmth recedes slowly |
| `T_total` | total overlay lifetime | float | > 0 | Default: 0.7s (700ms) |
| `A_max` | peak overlay alpha | float | [0.2, 0.8] | `GameConfig.portraits.conversion_overlay_surge_alpha`. Default: 0.55 |
| `a_overlay(t)` | overlay alpha | float | [0.0, A_max] | Applied as `overlay.modulate.a`; RGB channels fixed at `conversion_overlay_color` |

**Output range:** [0.0, 0.55] at defaults. The overlay is a pure alpha envelope over a fixed colour — no hue shift, no position animation.

**Restart rule:** if `set_expression("moved_convinced")` fires while the overlay is already active, the envelope restarts from `t = 0` (surge again). It fires once per call regardless of previous expression state (Rule 5).

**Reduced-motion override:** when `AccessibilitySystem.reduced_motion_enabled` is true, the surge and hold phases are skipped: `a_overlay(t) = A_max · (1 - t / T_rm_fade)` for `t ∈ [0, T_rm_fade]`, where `T_rm_fade = GameConfig.portraits.reduced_motion_overlay_fade_ms / 1000.0` (default 0.1s). The final colour cast still appears instantly, then fades without motion.

**Example (defaults):** at `t = 0.075` (mid-surge): `a = 0.55 · (0.5)² = 0.1375`. At `t = 0.15–0.20`: `a = 0.55`. At `t = 0.45`: `a = 0.55 · (1 - (1 - 0.5)²) = 0.4125`. At `t = 0.70`: `a = 0.0`.

### F5 — Thumbnail Expression Mapping

The thumbnail expression mapping formula is defined as:

```
thumb_key(npc) = B2E(npc.belief_state)
```

where `B2E` is the belief-state → expression-key map from Rule 7:

```
B2E(STEADFAST) = "closed_resistant"
B2E(OPEN)      = "neutral_listening"
B2E(WAVERING)  = "open_receptive"
B2E(CONVERTED) = "moved_convinced"
```

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `npc` | NPC record | NpcRecord | — | From `NPCRegistry.get_npc(npc_id)` |
| `npc.belief_state` | belief state | BeliefState | {STEADFAST, OPEN, WAVERING, CONVERTED} | Canonical enum per NPC Character System GDD |
| `thumb_key` | thumbnail expression key | String | one of the 4 mapped keys | Key of the texture swapped into the Village Map thumbnail `TextureRect` |

**Update trigger:** the mapping is re-evaluated exactly when `NPCRegistry.npc_state_changed(npc_id, old_state, new_state)` fires. Village Map View receives the signal and applies `thumb_key = B2E(new_state)` as a single-frame texture swap — no tween, no hold window, no `dissolve_*` signals. A regression (`CONVERTED → WAVERING` from the Rival Faith System) simply maps to `open_receptive` — the thumbnail cools within one frame.

**Output range:** always one of the four mapped keys. `npc.belief_state` outside the enum (save corruption) is handled by NPCRegistry deserialization (defaults to `STEADFAST`) before this formula is ever evaluated.

### F6 — Expression Hold Window

The expression hold window formula is defined as:

```
lock_frames = GameConfig.ui_timing.portrait_expression_hold_frames

coalesced_call(key) =
    if lock_active:
        pending_key = key              # most recent call wins; previous pending discarded
        (apply pending_key when lock_frames_remaining reaches 0)
    else if key != current_expression:
        start dissolve (F1/F2)         # normal path
    else:
        no-op                          # Rule 13
```

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `lock_frames` | hold window length | int | [1, 120] | `GameConfig.ui_timing.portrait_expression_hold_frames`. Default: 30 |
| `lock_active` | hold in progress | bool | {true, false} | True from dissolve completion until `lock_frames` rendered frames have elapsed |
| `lock_frames_remaining` | frames left in hold | int | [0, lock_frames] | Decrements by 1 each rendered frame; 0 ends the lock and flushes any pending key |
| `pending_key` | coalesced target | String | any key | The most recent key received during the lock; overwritten by each new call (never a queue) |

**Output range / refresh dependency:** the wall-clock hold is `lock_frames / refresh_rate`. At 60Hz: 30 frames ≈ 500ms. At 120Hz: ≈ 250ms. Because the hold is a *lower-bound dwell* (anti-flicker), not a precise beat, this variance is acceptable at MVP — see Edge Case EC-12 and Tuning Knobs.

**Example:** dissolve to `neutral_listening` completes at frame N (lock starts, 30 frames). `set_expression("considering_uncertain")` arrives at frame N+5 → stored as pending. `set_expression("open_receptive")` arrives at frame N+9 → replaces pending. At frame N+30, a dissolve toward `open_receptive` begins. `considering_uncertain` is never shown — most recent call wins, no queue.

## Edge Cases

**EC-1: Rapid re-click during a dissolve.** `set_expression()` arrives mid-tween. Per Rule 4/F3: kill the tween, resume from the interrupted alpha, begin the new dissolve. No queue, no flicker, no composite discontinuity. If the re-click arrives *after* the tween completes but within the hold window, Rule 11/F6 coalescing applies instead — same "most recent wins" outcome, applied at lock expiry. The Mobile Touch Framework's 100ms input debounce additionally filters finger-bounce double-taps at the OS level; P&E handles anything that still gets through.

**EC-2: `set_expression()` with the currently displayed key.** No-op (Rule 13): no texture load, no tween, no signals. The Conversion UI is expected to skip redundant calls, but the guard is in P&E.

**EC-3: NPC belief state changes mid-conversation.** `npc_state_changed` may fire for the current NPC (e.g., a rival outcome resolved after a save-restore). `PortraitController` does **not** subscribe to `npc_state_changed` — the Conversion UI remains the sole expression driver during a session. The current dissolve completes to whatever the UI last requested; the system does not auto-correct to the new belief state. At MVP this is unreachable in normal play (the rival acts only between sessions), but the rule makes behaviour deterministic for any future caller.

**EC-4: Rival regression while the Village Map is visible.** `npc_state_changed(npc_id, CONVERTED, WAVERING)` fires → Village Map View swaps that NPC's thumbnail from `moved_convinced` to `open_receptive` within one frame (F5). No animation, no overlay — the thumbnail cools instantly. The `rival_acted` marker is a Village Map View concern, not P&E's.

**EC-5: Conversion requested mid-dissolve to another expression.** Example: the UI calls `set_expression("considering_uncertain")` at approach-confirm, then immediately `set_expression("moved_convinced")` when `outcome_resolved` lands. F3 handles the dissolve interrupt; the conversion overlay fires immediately (Rule 5) and runs its full 700ms envelope regardless of the interrupted tween. The chime hook (`dissolve_started("moved_convinced")`) still fires — audio never misses a conversion moment.

**EC-6: Missing texture for one key.** `{portrait_asset_path}{expression_key}.png` fails to load. Log one error per `(archetype_id, expression_key)` pair (deduplicated — no log spam), display `closed_resistant` as fallback, and continue the session. The fallback texture itself must exist (see EC-7); if it does not, display the `_front_rect` as a solid `ColorRect` placeholder and log a hard error.

**EC-7: Archetype path invalid or all six textures missing.** `portrait_asset_path` points to a non-existent directory, or all six loads fail. Log a hard error naming the archetype. The portrait renders `closed_resistant` fallback for every key. Debug builds additionally surface an assertion so the art pipeline catches it before playtest. Gameplay continues — a missing face must never crash a conversion.

**EC-8: Reduced-motion enabled mid-session.** The flag is read at each expression change (Rule 12). If the player enables reduced motion in OS settings mid-conversation (rare but possible via background settings change), the *next* expression change snaps instead of dissolving; any in-flight tween is allowed to complete (aborting it mid-frame is more jarring than finishing). The overlay fades per the reduced-motion envelope from the next conversion.

**EC-9: Dark mode / low-contrast portrait.** The conversion overlay at `A_max = 0.55` over the darkest portrait texture must remain perceptible. Verification: with the darkest authored portrait, the overlay at peak must raise the portrait region's average luminance by ≥ 0.10 relative to the un-overlaid frame (measured in the `0.0–1.0` sRGB luminance of a rendered frame grab). If a future art pass ships darker textures that fail this, lower `conversion_overlay_surge_alpha` rather than changing the colour hue. Colour is never the sole signal: conversion is also marked by the audio chime and the lighting surge owned by Dialogue & Conversion System, so colour-blind players always have a second channel.

**EC-10: Long dialogue lines.** Expression state is fully decoupled from text length — the portrait holds its current expression until the next `set_expression()` or session end. A very long approach line does not trigger additional dissolves, extend the current dissolve, or queue anything. The portrait simply sits in `considering_uncertain` for the line's duration — stillness is the design (Rule 9).

**EC-11: App backgrounded mid-dissolve or mid-overlay.** On restore, the GSM restores any mid-session save to `IDLE` (Save & Load System Rule 6: `IN_SESSION → IDLE`) — the conversation scene is not restored, so the portrait is freed with it. Tweens are killed in `_exit_tree()` (see EC-13) to avoid orphan-tween warnings. No expression state is persisted (Dependencies: Save & Load has no interface with P&E).

**EC-12: 120Hz / variable-refresh devices.** The hold window (F6) is frame-counted, so it is ~500ms at 60Hz and ~250ms at 120Hz. Because the hold is a lower-bound anti-flicker dwell and the UI's own session timers (seconds-long beats) dominate real pacing, this variance is imperceptible in normal play. If playtest on high-refresh devices reports flicker, promote the hold to a millisecond value (`portrait_expression_hold_ms`) in `PortraitConfig` — flagged in Tuning Knobs.

**EC-13: Session teardown mid-animation.** `session_complete` fires while a dissolve or overlay is running → the Conversion UI frees the scene. `_exit_tree()` kills both tweens (no orphan warnings) and clears the texture cache (Rule 8). The Village Map thumbnails are unaffected — they are separate nodes with their own lifecycle.

**EC-14: Off-screen portraits.** In `IDLE` the full portrait is not instantiated — no textures loaded, no tweens running, zero per-frame cost. Village Map thumbnails exist for all NPCs (8–12 at MVP); off-screen ones are culled by Godot's viewport, and the single-frame swap cost of an update is negligible. No special handling beyond standard Godot culling.

**EC-15: Single-archetype village (all NPCs share one archetype).** Cache keys are `"{archetype_id}/{expression_key}"`, so one archetype's six textures serve every NPC in the village. No per-NPC duplication, no cache blow-up. The same applies to thumbnails (four belief keys per archetype).

**EC-16: `set_expression()` called before `_ready()` completes.** The six-texture preload (Rule 8) has not finished. The call is a no-op with a warning — the Conversion UI contract is to instantiate the scene, await its `ready` signal, then drive expressions. Defensive, not a supported path.

## Dependencies

### Systems This System Depends On

| System | GDD | Type | Interface |
|---|---|---|---|
| NPC Character System | `npc-character-system.md` | **Hard** | `NPCRegistry.get_npc(npc_id)` for `belief_state` (opening expression) and `archetype`; `get_archetype_definition(archetype)` → `portrait_asset_path`. `npc_state_changed` consumed by Village Map View (not by `PortraitController`) for thumbnail updates. |
| Game Config | `game-config.md` | **Hard** | `GameConfig.portraits` (`PortraitConfig` — **new domain, see Appendix A**): dissolve durations, overlay colour/timing, reduced-motion values. Consumes existing `GameConfig.ui_timing.portrait_expression_hold_frames`. Read at call time, never cached. |
| Conversion UI | `design/gdd/../conversion-ui` *(GDD pending — system #12)* | **Hard** (lifecycle) | Instantiates and frees the `PortraitController` scene; calls `set_expression()`. P&E cannot exist without a scene owner. The contract is defined here; Conversion UI GDD must reference it. |
| NPC Trait Database | `npc-trait-database.md` | **None at MVP** (prospective) | No runtime reads. The Trait Database's Interactions table lists P&E as a trait consumer — that is a post-MVP aspiration (trait-driven micro-expressions, OQ-1), not an MVP dependency. |
| Accessibility System | *(GDD pending — system #19, Alpha)* | **Soft (provisional)** | Reads `AccessibilitySystem.reduced_motion_enabled: bool`. Provisional contract — if absent, defaults to `false` (Rule 12). |
| Godot Engine | `docs/engine-reference/godot/` | **Hard** | `TextureRect`, `Control`, `Tween` (`TRANS_LINEAR`, `TRANS_SINE`, `EASE_IN_OUT`), `ResourceLoader.load()`. Verified against the 4.6 engine reference — no post-cutoff APIs used. |

### Systems That Depend On This System

| System | GDD | What It Uses |
|---|---|---|
| Conversion UI | *(GDD pending — system #12)* | Primary consumer. Calls `set_expression()` per dialogue beat/outcome; subscribes to `dissolve_started`/`dissolve_completed`; owns scene lifecycle. |
| Village Map View | *(GDD pending — system #13)* | Hosts per-NPC thumbnail `TextureRect`s; applies the Rule 7/F5 mapping on `npc_state_changed`. |
| Rival Faith System | `rival-faith-system.md` | Indirect — its `CONVERTED → WAVERING` regressions flow through `npc_state_changed` to the thumbnail consumer. No direct P&E call. |
| Audio System | *(GDD pending — system #16)* | Subscribes to `dissolve_started`; conversion chime on `expression_key == "moved_convinced"` (per Dialogue & Conversion System Visual/Audio). Optional at MVP. |
| Dialogue & Conversion System | `dialogue-conversion-system.md` | Consumes the *effect* (its Visual/Audio section specifies portrait cross-dissolves, the considering beat, and the conversion surge). No direct interface — DCS drives the Conversion UI, which drives P&E. |

### Architectural Notes

- `PortraitController` is deliberately **not an Autoload**: exactly one instance exists per conversation, created and destroyed with the scene. Thumbnails are owned by Village Map View. There is no shared portrait singleton to coordinate.
- The system holds **no persistent state** — nothing to serialize. Expression state is derived from NPCRegistry (opening) + Conversion UI calls (during session).
- All timing reads are pull-pattern (`GameConfig.portraits.*` at call time), consistent with Game Config Rule 3.

## Tuning Knobs

### Owned by this system — `GameConfig.portraits` (PortraitConfig, new domain — Appendix A)

| Knob | Field | Default | Safe Range | Effect | What Breaks at Extremes |
|---|---|---|---|---|---|
| Standard dissolve | `dissolve_duration_ms` | 350 | 150–800 | Duration of all non-conversion cross-dissolves (F1). | Below 150ms: reads as a flicker, no emotional beat. Above 800ms: sluggish on mobile; conversations drag. Design target 300–400ms (Art Bible §7.4). |
| Conversion dissolve | `conversion_dissolve_duration_ms` | 400 | 200–1000 | Duration of the `moved_convinced` dissolve (F2). | Below 200ms: the arrival is rushed. Above 1000ms: the moment overstays. Keep ≥ standard dissolve — conversion must feel *slower*, earned. |
| Overlay colour | `conversion_overlay_color` | `#F2A33C` warm amber | any Color | RGB of the conversion overlay (alpha from F4). | Over-saturated hues fight the portrait; grey reads as failure. Warm amber matches the lighting register (Art Bible §2.3). |
| Overlay peak alpha | `conversion_overlay_surge_alpha` | 0.55 | 0.20–0.80 | Peak opacity of the conversion overlay. | Below 0.20: imperceptible. Above 0.80: obscures the face — the portrait is the story. |
| Surge duration | `conversion_overlay_surge_ms` | 150 | 50–500 | Ease-in phase of the overlay envelope (F4). | Below 50ms: the warmth "pops". Above 500ms: conversion feels hesitant. |
| Hold duration | `conversion_overlay_hold_ms` | 50 | 0–300 | Flat peak phase of the envelope. | 0 removes the beat; above 300ms the screen tints for too long. |
| Fade duration | `conversion_overlay_fade_ms` | 500 | 100–1500 | Ease-out phase of the envelope. | Below 100ms: the warmth vanishes abruptly. Above 1500ms: the tint lingers into the map return. |
| Reduced-motion dissolve | `reduced_motion_dissolve_ms` | 0 | 0–200 | Transition duration when reduced motion is enabled (Rule 12). | 0 = instant snap. Above 200ms defeats the point of the setting. |
| Reduced-motion overlay fade | `reduced_motion_overlay_fade_ms` | 100 | 0–500 | Overlay fade duration when reduced motion is enabled (F4 override). | 0 = overlay appears and disappears instantly (colour cast only). Above 500ms reintroduces motion. |

### Consumed from existing config (owned by Game Config GDD — no change)

| Knob | Field | Default | Safe Range | Effect |
|---|---|---|---|---|
| Expression hold window | `UITimingConfig.portrait_expression_hold_frames` | 30 | 1–120 | Minimum dwell of a shown expression (F6). Frame-based — refresh dependent (EC-12). **Promotion candidate:** if high-refresh playtest flags flicker, add `portrait_expression_hold_ms` to `PortraitConfig` and deprecate the frame version. |

### Content-level knobs (authored, not numeric)

| Knob | Default | Effect |
|---|---|---|
| Expression key set | 6 keys (Rule 6) | Adding keys requires art for every archetype + mapping updates. Fixed at MVP. |
| Portrait texture set per archetype | 6 full + 4 thumbnail | 7 archetypes → 42 full + 28 thumbnails at MVP. See Visual/Audio. |

### Derived values (not directly tunable)

| Derived Value | Formula | Notes |
|---|---|---|
| Total overlay lifetime | `conversion_overlay_surge_ms + conversion_overlay_hold_ms + conversion_overlay_fade_ms` | 700ms at defaults. |
| Hold wall-clock (60Hz) | `portrait_expression_hold_frames / 60` | ≈ 500ms at default. |
| Hold wall-clock (120Hz) | `portrait_expression_hold_frames / 120` | ≈ 250ms at default. |

## Visual/Audio Requirements

### Asset Matrix (MVP)

| Asset | Size | Count | Notes |
|---|---|---|---|
| Full portrait textures | 780×1014px @2x (390×507 logical) | 6 keys × 7 archetypes = 42 | PNG with alpha. Full-bleed in the portrait zone (60–65% of screen height). One texture per expression key. |
| Village Map thumbnails | 160×160px @2x (80×80 dp logical) | 4 belief keys × 7 archetypes = 28 | Separately authored compositions — a face readable at 160px differs from a face readable at 780px. Downscaling full portraits at runtime is explicitly **not** recommended (OQ-2). |

**Expression set art direction (applies to every archetype):**

| Expression Key | Art Direction |
|---|---|
| `closed_resistant` | Guarded posture, neutral-set mouth, eyes tracking the speaker but unreachable. Baseline for STEADFAST. |
| `neutral_listening` | Present, attentive, no commitment. The conversation's resting face. |
| `considering_uncertain` | Interior conflict: eyes slightly down or flickering, micro-tension. Shown when the approach lands (DCS Step 5). |
| `open_receptive` | Softened features, warmth beginning — the "almost." |
| `withdrawn_resistant` | Averted gaze, defensive shoulder, wall rebuilt. |
| `moved_convinced` | Luminous, peaceful, transformed — the only expression with implied light. |

- **Motion budget:** the cross-dissolve is the *only* animation (Rule 9). 300–400ms linear, no bounce easing (Art Bible §7.4). The conversion dissolve uses sine ease-in-out (F2) — the one permitted deviation.
- **Lighting integration:** P&E owns portrait `modulate` and the conversion overlay only. Lighting temperature shifts, rim light, and the ink-bleed on map return are owned by Dialogue & Conversion System / Village Map View (Art Bible §2.2–2.4, §4.3).
- **Colour language:** the overlay colour and alpha are config-driven (`conversion_overlay_color`); conversion is never communicated by hue alone (EC-9).

### Audio

| Event | Requirement |
|---|---|
| `dissolve_started("moved_convinced")` | **Conversion chime fires** at cross-dissolve onset (per DCS Visual/Audio: `music_conversion_chime_01`, one-shot, non-looping). Hook: Audio System subscribes to `dissolve_started`. |
| `dissolve_completed(key)` | Optional soft page-turn/parchment cue (`sfx_trait_revealed` family) if Conversion UI chooses to sync text reveal to dissolve completion. Not required at MVP. |
| All other transitions | No audio. Silence is the weight between expressions. |
| Thumbnail swaps | No audio — silent single-frame updates. |

> 📌 **Asset Spec flag** — Visual/Audio requirements are defined. After the Art Bible is approved, run `/asset-spec system:portrait-expression-system` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## UI Requirements

### Portrait Zone (conversation screen)

- The full portrait occupies the upper 60–65% of the viewport (per DCS UI Requirements: portrait zone). `PortraitController` fills the zone; its `TextureRect` children use **aspect-preserving** stretch (`keep aspect centered`) — no distortion on any aspect ratio; letterbox bars are filled by the mood-lit background owned by DCS.
- The portrait is **non-interactive** — it is not a registered touch target during conversation. All interaction (approach buttons, Inspect) lives in the choice zone below and is registered with the Mobile Touch Framework.
- No UI chrome over the portrait: no borders, badges, or labels. The face is the content.
- No loading indicators: the six textures preload in `_ready()` (Rule 8); a conversation session never waits on a texture load.
- Safe-area: the portrait zone must respect top safe-area insets (notch) — the zone rect is computed by the Conversion UI layout, P&E fills whatever rect it is given.

### Village Map Thumbnails

- Each NPC's thumbnail displays at 80×80 dp logical (160×160px @2x) — comfortably above the 44×44dp minimum tap target; the tap target itself is registered by Village Map View.
- Thumbnail updates are **instant swaps** (F5) — no dissolve, no animation, no lock. This is deliberate: the map is a read-state surface; only the conversation carries animation.
- Non-approachable states (cooldown/locked) render as overlays owned by Village Map View — P&E only provides the base expression texture.

### Reduced Motion

- No player-facing toggle at MVP. The system honors `AccessibilitySystem.reduced_motion_enabled` (Rule 12) silently. A settings surface for the flag belongs to the Accessibility System GDD (Alpha).

## Acceptance Criteria

**AC-01 — Standard dissolve completes correctly.**
Given `GameConfig.portraits.dissolve_duration_ms = 350` and a `PortraitController` showing `closed_resistant`, when `set_expression("neutral_listening")` is called, then `dissolve_started("neutral_listening")` emits immediately, `_back_rect` alpha follows F1, and within `350ms ± 16ms` (one frame at 60Hz) `dissolve_completed("neutral_listening")` emits, `_back_rect.modulate.a == 1.0`, `_front_rect.modulate.a == 0.0`, and front/back references are swapped.

**AC-02 — Same-key call is a no-op.**
Given the portrait is showing `neutral_listening` with no dissolve in progress, when `set_expression("neutral_listening")` is called, then no tween starts and neither `dissolve_started` nor `dissolve_completed` is emitted within 100ms.

**AC-03 — Interrupted dissolve resumes from current alpha (F3).**
Given a 350ms linear dissolve toward `considering_uncertain` that has run 175ms (interrupted `a_start = 0.5`), when `set_expression("open_receptive")` is called, then the old tween is killed, the new tween starts with the incoming texture at alpha `0.5 ± 0.01`, and the new dissolve completes within `350ms ± 16ms` with no composite alpha discontinuity (composite = `a_back + a_front` never deviates from `1.0` by more than 0.01 at any sampled frame).

**AC-04 — Conversion overlay envelope (F4).**
Given defaults (`A_max = 0.55`, 150/50/500ms), when `set_expression("moved_convinced")` is called, then the overlay `modulate.a` reaches `0.55 ± 0.02` at `150ms ± 16ms`, holds `0.55 ± 0.02` until `200ms ± 16ms`, and reaches `0.0 ± 0.02` by `700ms ± 32ms`. The RGB channels equal `conversion_overlay_color` at every sample.

**AC-05 — Overlay restarts per call.**
Given the overlay is mid-fade at `t = 400ms`, when `set_expression("moved_convinced")` is called again, then the envelope restarts at `t = 0` (surge) — the overlay peaks at `0.55` again `150ms` later.

**AC-06 — Thumbnail updates on state change (F5).**
Given a Village Map with an OPEN NPC (thumbnail `neutral_listening`), when `npc_state_changed(npc_id, OPEN, WAVERING)` fires, then within one rendered frame the thumbnail `TextureRect` displays `open_receptive`. No tween runs, no `dissolve_*` signal is emitted by any `PortraitController`.

**AC-07 — Rival regression cools the thumbnail within one frame.**
Given a CONVERTED NPC (thumbnail `moved_convinced`), when `npc_state_changed(npc_id, CONVERTED, WAVERING)` fires (rival regression), then within one frame the thumbnail displays `open_receptive`.

**AC-08 — Missing texture falls back.**
Given an archetype whose set lacks `withdrawn_resistant.png`, when `set_expression("withdrawn_resistant")` is called, then exactly one error is logged for that `(archetype_id, expression_key)` pair, the portrait displays `closed_resistant`, and the session continues without interruption.

**AC-09 — Hold window coalesces (F6).**
Given `portrait_expression_hold_frames = 30` and a dissolve that completed 10 frames ago, when `set_expression("considering_uncertain")` is called at frame 10 and `set_expression("open_receptive")` at frame 14, then no tween starts before the lock expires, `open_receptive` (not `considering_uncertain`) is applied at frame 30, and `considering_uncertain` is never displayed.

**AC-10 — Reduced motion snaps transitions.**
Given `AccessibilitySystem.reduced_motion_enabled = true` and `reduced_motion_dissolve_ms = 0`, when `set_expression("open_receptive")` is called, then the texture swaps in a single frame with no tween and no `dissolve_started` emission.

**AC-11 — Reduced motion trims the overlay.**
Given `AccessibilitySystem.reduced_motion_enabled = true` and `reduced_motion_overlay_fade_ms = 100`, when `set_expression("moved_convinced")` is called, then the overlay appears at `A_max` and fades to `0.0` within `100ms ± 16ms`; the surge and hold phases do not occur.

**AC-12 — Six textures preloaded at instantiation; cache cleared at teardown.**
Given a `PortraitController` instantiated for a LABORER NPC, when `_ready()` completes, then all six `res://assets/portraits/laborer/*.png` textures are in the cache (no load occurs on the first `set_expression` call). When the scene is freed, the cache Dictionary is emptied; no texture references remain (verified by a memory-leak check over 100 instantiate/destroy cycles).

**AC-13 — No ambient animation.**
Given the portrait in `SHOWING` (settled) for 5 seconds with no `set_expression()` calls, then no property of `_front_rect`, `_back_rect`, or the overlay changes across any sampled frame.

**AC-14 — Teardown mid-animation is clean.**
Given a dissolve or overlay running, when the scene is freed (`_exit_tree`), then no orphan-tween warnings are logged and no errors occur; the Village Map thumbnails remain unaffected.

**AC-15 — Portrait fits without distortion.**
Given viewport aspect ratios of 19.5:9, 16:9, and 4:3, when the conversation opens, then the portrait texture is fully visible within the portrait zone, aspect-correct (`scale_x == scale_y`), and occupies 60–65% of screen height.

**AC-16 — Overlay contrast floor (EC-9).**
Given the darkest authored portrait texture, when the conversion overlay is at `A_max`, then the portrait region's mean sRGB luminance is at least 0.10 higher than the same region without the overlay.

**AC-17 — No hardcoded magic numbers.**
Given any GDScript file in `src/` implementing this system, when reviewed, then every duration, alpha, and colour value is read from `GameConfig.portraits.*` or `GameConfig.ui_timing.portrait_expression_hold_frames` — no numeric literals for balance/visual values.

## Open Questions

**OQ-1 — Trait-driven micro-expressions (post-MVP).** The NPC Trait Database GDD lists P&E as a consumer of trait IDs for expression selection; MVP expression selection is belief/outcome-driven only. Should specific trait combinations add micro-variants (e.g., a `bereaved` NPC's `closed_resistant` reads slightly softer)? **Recommended:** keep MVP as specified; revisit after playtest to see if portraits need trait-level differentiation.

**OQ-2 — Thumbnail authoring pipeline.** 28 thumbnails (4 keys × 7 archetypes) vs. runtime downscale of full portraits. Separate authoring preserves face readability at small size but doubles art volume; runtime downscale saves art but risks unreadable faces and per-NPC memory overhead. **Recommended:** separately authored thumbnails at MVP; decide with the Art Director when the asset pipeline is specced.

**OQ-3 — Reduced-motion flag source.** P&E reads `AccessibilitySystem.reduced_motion_enabled` (provisional contract). The Accessibility System GDD (Alpha) has not been authored. Confirm the flag name/ownership when that GDD is written; until then the default-false fallback applies.

**OQ-4 — Frame-based hold on high-refresh devices.** `portrait_expression_hold_frames` is refresh-dependent (EC-12). Acceptable as a lower-bound at MVP; promote to `portrait_expression_hold_ms` in `PortraitConfig` if playtest flags flicker. Should the promotion happen pre-MVP to avoid a config schema change later?

**OQ-5 — Multiple variants per expression key.** Exactly 6 keys per archetype at MVP. Post-MVP, per-key variants (2–3 textures per expression, selected by the same recency mechanism the DCS uses) would add variety across repeated conversations. Deferred — requires a variant-selection rule and more art.

---

# Appendix — Cross-System Updates (draft for the same approval)

## A. GameConfig GDD (`design/gdd/game-config.md`)

**A1. New domain — `PortraitConfig` (7th domain).** Update Rule 2 ("Six config domains" → seven; add bullet): `PortraitConfig` — dissolve timings, conversion overlay colour/timing, reduced-motion overrides. New `.tres` at `res://assets/data/config/portrait_config.tres`. Add to AC-10 ("all 6 domains" → "all 7 domains", add `GameConfig.portraits`), and add a row to the Interactions table: Portrait & Expression System — direct consumer — `PortraitConfig`.

**A2. Domain field ranges table** (add to §Formulas):

| Field | Min | Max | Default | Required |
|---|---|---|---|---|
| `dissolve_duration_ms` | 150 | 800 | 350 | Yes |
| `conversion_dissolve_duration_ms` | 200 | 1000 | 400 | Yes |
| `conversion_overlay_color` | Color | Color | `Color8(242, 163, 60)` (#F2A33C warm amber) | Yes |
| `conversion_overlay_surge_alpha` | 0.20 | 0.80 | 0.55 | Yes |
| `conversion_overlay_surge_ms` | 50 | 500 | 150 | Yes |
| `conversion_overlay_hold_ms` | 0 | 300 | 50 | Yes |
| `conversion_overlay_fade_ms` | 100 | 1500 | 500 | Yes |
| `reduced_motion_dissolve_ms` | 0 | 200 | 0 | Yes |
| `reduced_motion_overlay_fade_ms` | 0 | 500 | 100 | Yes |

No change to `UITimingConfig.portrait_expression_hold_frames` (1–120, default 30 — already present, now consumed by P&E as the hold window). Note in Edge Cases (per GameConfig EC-7 precedent): overlay phase timings are validated individually, not cross-field; P&E's F4 clamps total overlay lifetime if a tuning error ever makes phases inconsistent.

## B. NPC Character System GDD (`design/gdd/npc-character-system.md`)

`portrait_asset_path` already exists in the `NPCArchetypeDefinition` schema (Rule 3, `String # res:// path to portrait asset set`). Add the missing format contract as a note under Rule 3:

- Value is a **directory** path: `res://assets/portraits/{archetype_id}/` (lowercase archetype slug).
- Required field — no default; every archetype definition must set it.
- Must contain exactly six files named `{expression_key}.png` for the six MVP keys (`closed_resistant`, `neutral_listening`, `considering_uncertain`, `open_receptive`, `withdrawn_resistant`, `moved_convinced`).
- Debug-only validation at `initialize_village()`: `DirAccess.dir_exists_absolute(path)` — log a warning (do not crash) if missing; the P&E fallback (EC-6/7) covers runtime.

## C. NPC Trait Database GDD (`design/gdd/npc-trait-database.md`)

One-line addition to the archetypes section intro (line ~336): "Archetype definitions also carry `portrait_asset_path` and `social_influence_weight` — both owned by the NPC Character System GDD; the Trait Database does not define them." (Also resolves the stale P&E consumer claim in its Interactions table — mark P&E as prospective, not direct.)

## D. Systems Index (`design/gdd/systems-index.md`)

- Row 11: `Portrait & Expression System (inferred)` → Status `Designed` (was `In Design`), Design Doc `design/gdd/portrait-expression-system.md` (applied 2026-08-09).
- Progress Tracker: "Design docs started: 10 → 11"; "MVP systems designed: 10 / 14 → 11 / 14".

## E. Session State (`production/session-state/active.md`)

- STATUS block: Task → `Portrait & Expression System GDD — Designed (complete draft approved)`.
- Current Task item 4: add `✅ Portrait & Expression System (design/gdd/portrait-expression-system.md)`; correct the count from 8/14 to 11/14 (Rival Faith and Save & Load were completed since that list was written).
- Cross-System Updates Pending: add the three entries (GameConfig PortraitConfig, NPC Character System portrait_asset_path contract, Trait DB note).
- Next: `Design Conversion UI GDD (system #12) — deps: Dialogue & Conversion ✅, Portrait & Expression ✅, Mobile Touch ✅`.
