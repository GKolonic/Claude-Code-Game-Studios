# Mobile Touch Framework

> **Status**: In Design
> **Author**: Design session + ux-designer + gameplay-programmer agents
> **Last Updated**: 2026-04-20
> **Implements Pillar**: Pillar 2 — Many Roads to the Divine; Pillar 3 — The Arc Must Feel Earned

## Overview

The Mobile Touch Framework is a platform input abstraction layer loaded at game startup that standardises all touch input for *The Faithful* on iOS and Android. It translates raw `InputEventScreenTouch` and `InputEventScreenDrag` events from Godot's input system into named semantic gestures — **Tap**, **Long Press**, **Swipe**, and **Drag** — and emits typed signals that UI and gameplay systems consume without knowing anything about the underlying platform event model.

The framework serves a single structural goal: no consuming system (Conversion UI, Village Map View, HUD & Progress System, Accessibility System) should read raw touch events directly. All touch handling flows through this layer, which enforces project-wide constraints: a minimum tap target size of **44×44dp**, portrait-only orientation, and one-handed interaction patterns. Consuming systems register touch-enabled areas with the framework; the framework performs hit-testing against those areas using device-independent pixel (dp) coordinates and fires the appropriate gesture signal.

The framework does not contain game logic. It does not know what a conversion attempt is, what an NPC is, or what selecting a village position means. It knows: a touch started here, it ended there, it lasted this long, it moved this far. Everything above that level of abstraction is the consuming system's responsibility. The framework exists to ensure that the 44dp standard, one-handed ergonomics, and touch-input consistency are enforced once — at the boundary — rather than duplicated across every UI and gameplay screen.

## Player Fantasy

*The Faithful* is a slow game, but slowness must never feel like sluggishness — and touch is where that distinction lives. The Mobile Touch Framework exists to hold that line. The player's finger should register instantly, with zero ambiguity about whether a tap landed: when they reach for an NPC portrait, they get that NPC, not the one beside them. What the tap *produces* — a conversation that begins, an approach that unfolds, a moment in someone's life that may or may not change — can carry all the gravity it deserves.

The defining moment this system must protect: tapping GRIEF on a dialogue card should feel like placing a hand on someone's shoulder. Immediate in intent. Patient in consequence. The input layer commits without hesitation; the game layer responds with weight. If those two things blur — if the input itself feels slow, or if a committed tap feels like it might not have landed — the ritual of conversion is broken before it begins.

Players never notice this system when it works. They notice it the moment it fails: a tap that went to the wrong NPC, a swipe through outcome text that became an accidental approach selection, a thumb growing tired on a ten-minute commute. The Player Fantasy here is defined by its failures as much as its successes — perfect touch infrastructure is the one that disappears entirely and leaves the prophet's decisions in the center of the screen.

## Detailed Design

### Core Rules

1. **The framework is an Autoload singleton.** It is listed first in Project Settings → Autoloads to guarantee input processing priority. It reads raw touch events in `_input()` — not `_unhandled_input()` — so that Control nodes cannot silently consume events before the framework sees them. The framework does not call `set_input_as_handled()` unless an event is consumed by a registered touch area.

2. **Single-finger only at MVP.** All `InputEventScreenTouch` and `InputEventScreenDrag` events where `finger_index != 0` are silently discarded. No signal is emitted, no error is logged. Multi-touch is unsupported in MVP. This constraint is exposed as a named boolean constant: `SINGLE_FINGER_MODE = true`.

3. **Three gesture types at MVP.** The framework classifies touch sequences into exactly three gesture types and one cancellation event:
   - **Tap**: finger pressed and released within 350ms with movement ≤ 8dp from touch-down point.
   - **Long Press**: finger held for ≥ 600ms with movement ≤ 8dp from touch-down point.
   - **Swipe**: finger travels ≥ 40dp from touch-down point with release velocity ≥ 150dp/s. Classified into four cardinal directions (Up, Down, Left, Right) using 45-degree angle sectors.
   - **Touch Cancelled**: OS-level interruption (phone call, lock screen) or gesture timeout (800ms without resolution).

4. **Dead band between Tap and Long Press.** Any touch that ends between 350ms and 600ms without exceeding the swipe threshold resolves as a cancelled gesture — no signal is emitted. This prevents the ambiguous zone between a late tap and an early long press from producing unexpected behaviour in commute conditions.

5. **Minimum tap target: 44×44dp, enforced at hit-test time.** All target sizes in config and design documents are expressed in dp. The framework converts at registration using the formula `pixels = dp × (DisplayServer.screen_get_dpi() / 160.0)`, cached once at startup. If `screen_get_dpi()` returns 0 or an implausible value (emulator failure), the framework falls back to 160 DPI and logs a warning. At hit-test time, registered targets smaller than 44×44dp are expanded to 44×44dp using center-anchored rect inflation — the visual size is unchanged; only the hit region expands. A debug-mode warning is logged at registration for any target below the minimum, naming the node path and actual dp size.

6. **Touch noise floor: 8dp.** Finger movement of 8dp or less from the touch-down point at any moment during a press is treated as positional noise, not intentional movement. This is the slop threshold — it does not reclassify the gesture.

7. **Swipe requires two conditions.** A swipe fires only when (a) the finger travels ≥ 40dp from touch-down AND (b) release velocity ≥ 150dp/s. A slow 40dp drag that fails the velocity condition resolves as a cancelled gesture. This two-condition gate prevents commute-vibration drag from firing swipes.

8. **Long press fires on threshold, not on release.** When the hold duration reaches 600ms without cancellation, the framework emits `long_press_started`. When the finger is subsequently released, the framework emits `long_press_released`. This allows consuming systems to respond to hold-begin (e.g., show tooltip overlay) and hold-end (e.g., dismiss tooltip) as separate events.

9. **Layer blocking uses a priority stack and Recursive Control disable.** The framework maintains an ordered priority stack of blocking layers. Consuming systems call `push_blocking_layer(id)` when a modal is opened and `pop_blocking_layer(id)` when it is dismissed. While a blocking layer is active, all registered touch areas with priority below the blocking layer's tier receive no signals. For UI subtrees (menus, dialogs), the framework additionally calls Godot 4.5's Recursive Control disable to prevent Control nodes from consuming input through `_gui_input()`. CanvasLayer `layer` values are **not** used as input priority discriminators — they control rendering order only.

10. **Hit-testing is event-driven, not polled.** The area registry is only iterated inside `_input()` callbacks, never in `_process()`. The only per-frame computation is the long press elapsed time counter — a single float comparison, not a registry scan. The area registry supports a maximum of 32 simultaneously registered areas per screen (design constraint, not a code limit — exceeding this count is flagged in debug mode).

11. **dp conversion is the framework's responsibility.** No consuming system works in pixel-space for sizing or hit-testing. The framework exposes `pixels_per_dp: float` as a read-only property. All design values in this document (44dp, 8dp, 40dp, etc.) are in dp.

12. **Haptic feedback is framework-level; visual feedback is not.** The framework emits a brief (80ms) haptic pulse via `Input.vibrate_handheld()` on every confirmed Tap. No visual ripple or tap confirmation animation is rendered by the framework — those are consuming system responsibilities tied to the game's art direction. This is an absolute rule.

13. **Input debounce: 100ms.** If a new touch begins within 100ms of a previous touch ending at the same position (±10dp), the new touch is discarded. This prevents double-fire from finger bounce on rough commute surfaces.

14. **Gesture timeout: 800ms.** If a touch-down event fires and no touch-up event arrives within 800ms (phone locked, OS interrupt), the gesture is cancelled and `touch_cancelled` is emitted. The framework returns to IDLE regardless of prior state.

15. **Exposed constants (non-overridable at MVP):**

| Constant | Value | Description |
|---|---|---|
| `TAP_MAX_DURATION_MS` | 350 | Tap ceiling in milliseconds |
| `LONG_PRESS_MIN_DURATION_MS` | 600 | Long press floor in milliseconds |
| `TOUCH_SLOP_DP` | 8 | Noise floor — movement below this is ignored |
| `SWIPE_MIN_DISTANCE_DP` | 40 | Minimum travel for swipe classification |
| `SWIPE_MIN_VELOCITY_DP_S` | 150 | Minimum release velocity for swipe classification |
| `TAP_TARGET_MIN_SIZE_DP` | 44 | Minimum tap target dimension |
| `TAP_TARGET_MIN_GAP_DP` | 8 | Minimum edge-to-edge gap between adjacent targets |
| `TAP_TARGET_RECOMMENDED_GAP_DP` | 16 | Recommended gap for primary action buttons |
| `TAP_TARGET_MIN_CENTROID_DIST_DP` | 56 | Debug warning threshold for adjacent target centroids |
| `SAFE_ZONE_BOTTOM_FRACTION` | 0.55 | Bottom 55% of screen height — primary interaction zone |
| `DEBOUNCE_INTERVAL_MS` | 100 | Duplicate touch filter window |
| `GESTURE_TIMEOUT_MS` | 800 | Maximum open gesture duration before cancellation |
| `HAPTIC_TAP_DURATION_MS` | 80 | Haptic pulse length on tap confirmation |
| `SINGLE_FINGER_MODE` | true | Discards all non-zero finger index events |
| `MAX_REGISTERED_AREAS` | 32 | Debug warning threshold for area registry count |

---

### States and Transitions

| State | Description |
|---|---|
| `IDLE` | No active finger. Awaiting `InputEventScreenTouch` with `pressed = true` and `finger_index == 0`. |
| `TOUCH_DOWN` | Finger is down. Hold timer started. Touch-down position locked. Movement tracking active. |
| `LONG_PRESS_PENDING` | Hold timer has reached 600ms without exceeding 8dp slop. `long_press_started` emitted. Awaiting release. |
| `SWIPE_TRACKING` | Finger has moved ≥ 40dp from touch-down. Tap and Long Press cancelled. Velocity tracking active. |
| `RESOLVING` | Finger lifted. Final gesture being classified and signal emitted. |

**Transitions:**

```
IDLE
  ├─ Touch down (finger_index == 0) ──────────────────────────► TOUCH_DOWN
  │   [lock touch_down_position, start hold timer, reset slop]

TOUCH_DOWN
  ├─ Movement ≤ 8dp (noise) ─────────────────────────────────► [stay TOUCH_DOWN]
  ├─ Movement > 8dp, < 40dp ─────────────────────────────────► [stay TOUCH_DOWN; tracking]
  ├─ Movement ≥ 40dp ────────────────────────────────────────► SWIPE_TRACKING
  │   [cancel hold timer; begin velocity tracking]
  ├─ Hold timer ≥ 600ms ─────────────────────────────────────► LONG_PRESS_PENDING
  │   [emit long_press_started]
  ├─ Touch up (duration ≤ 350ms, movement ≤ 8dp) ───────────► RESOLVING [Tap]
  ├─ Touch up (350ms < duration < 600ms) ────────────────────► RESOLVING [Cancelled]
  └─ Timeout (800ms) or OS cancel ───────────────────────────► IDLE [emit touch_cancelled]

LONG_PRESS_PENDING
  ├─ Touch up ────────────────────────────────────────────────► RESOLVING [Long Press]
  │   [emit long_press_released]
  ├─ Movement ≥ 40dp ────────────────────────────────────────► SWIPE_TRACKING
  │   [cancel long press; no long_press_released emitted]
  └─ OS cancel ───────────────────────────────────────────────► IDLE [emit touch_cancelled]

SWIPE_TRACKING
  ├─ Touch up (distance ≥ 40dp AND velocity ≥ 150dp/s) ─────► RESOLVING [Swipe]
  ├─ Touch up (distance ≥ 40dp AND velocity < 150dp/s) ─────► RESOLVING [Cancelled]
  └─ OS cancel ───────────────────────────────────────────────► IDLE [emit touch_cancelled]

RESOLVING
  ├─ Tap ─────────────────────────────────────────────────────► IDLE
  │   [hit-test registry at tap position; emit tapped(target, position) if hit;
  │    emit haptic pulse; emit nothing for miss]
  ├─ Long Press ──────────────────────────────────────────────► IDLE
  │   [hit-test registry at hold position; emit long_pressed(target, position) if hit]
  ├─ Swipe ───────────────────────────────────────────────────► IDLE
  │   [classify cardinal direction; emit swiped(direction, delta, velocity)]
  └─ Cancelled ───────────────────────────────────────────────► IDLE
      [no signal emitted]
```

**Invariant:** Only one touch (finger_index == 0) is tracked at any time. A second finger during an active gesture is discarded. If a second touch begins while the state machine is in TOUCH_DOWN, LONG_PRESS_PENDING, or SWIPE_TRACKING, it is silently ignored — the active gesture continues.

---

### Interactions with Other Systems

**Framework API (consuming systems call these):**

- `register(control: Control, priority: int)` — registers a Control as a touch target. Computes dp size; logs warning if below 44dp; adds to priority-sorted registry. Must be called in `_ready()`.
- `unregister(control: Control)` — removes a touch target. Must be called on `tree_exiting`.
- `push_blocking_layer(layer_id: StringName)` — adds a blocking layer to the priority stack. All registered areas with lower priority than the blocking layer stop receiving gesture signals.
- `pop_blocking_layer(layer_id: StringName)` — removes the blocking layer. Lower-priority areas resume receiving signals.
- `pixels_per_dp: float` — read-only property. Cached at startup from `DisplayServer.screen_get_dpi()`.

**Signals emitted by the framework (consuming systems connect to these):**

- `tapped(target: Control, position: Vector2)` — emitted when a Tap completes on a registered target.
- `long_press_started(target: Control, position: Vector2)` — emitted when a Long Press threshold is reached.
- `long_press_released(target: Control, position: Vector2)` — emitted when the finger is lifted after a Long Press.
- `swiped(direction: SwipeDirection, delta: Vector2, velocity: float)` — screen-level; not tied to a specific registered target.
- `touch_cancelled()` — emitted on OS interrupt, timeout, or dead-band resolution.

| Consuming System | Gestures Used | Registration Notes |
|---|---|---|
| Conversion UI | `tapped` (NPC portrait, approach buttons); `swiped` (card scroll) | Registers approach buttons and portrait; pushes blocking layer when Conversion UI is open |
| Village Map View | `tapped` (select NPC/village position) | Registers map interaction areas; blocked when Conversion UI is active |
| HUD & Progress System | `tapped` (faith meter detail) | Always registered; lowest priority tier |
| Accessibility System | Observer only — connects to framework signals for haptic/audio augmentation | No `register()` calls |

## Formulas

### F-1: dp-to-Pixel Conversion (`dp_to_pixels`)

Converts all design values from device-independent pixels (dp) to physical screen pixels. Called once at startup; result cached as `pixels_per_dp`.

| Symbol | Type | Range | Description |
|---|---|---|---|
| `dp` | float | 0 — unbounded | Input value in device-independent pixels |
| `raw_dpi` | int | 0 — OS reported | Raw DPI from `DisplayServer.screen_get_dpi()` |
| `dpi_safe` | int | 72 — 640 | DPI after implausibility clamp; falls back to 160 if outside range |
| `px` | float | 0 — unbounded | Equivalent value in physical screen pixels |

```
dpi_safe = clamp(raw_dpi, 72, 640)   # if raw_dpi == 0 or implausible → 160
px = dp × (dpi_safe / 160.0)
```

**Example:** 44dp on a 390 DPI device → `44 × (390 / 160.0) = 107.25 px`

---

### F-2: Tap Target Rect Inflation (`inflate_tap_rect`)

Expands a registered Control's hit rect to the 44dp minimum, centered on the visual center. Applied at registration time; visual size is not affected. Width and height handled independently.

| Symbol | Type | Range | Description |
|---|---|---|---|
| `rect` | Rect2 | any screen rect | Registered visual bounds in pixels |
| `min_px` | float | 107–170 px | `TAP_TARGET_MIN_SIZE_DP × pixels_per_dp` |
| `deficit_w` | float | 0 — min_px | Width shortfall; 0 if already wide enough |
| `deficit_h` | float | 0 — min_px | Height shortfall; 0 if already tall enough |
| `inflated` | Rect2 | ≥ min_px × min_px | Expanded hit rect, center-anchored to input |

```
deficit_w = max(0, min_px - rect.width)
deficit_h = max(0, min_px - rect.height)
inflated.x      = rect.x - deficit_w / 2
inflated.y      = rect.y - deficit_h / 2
inflated.width  = rect.width  + deficit_w
inflated.height = rect.height + deficit_h
```

**Example:** 60×28dp button at 320 DPI (pixels_per_dp = 2.0), min_px = 88px. Input: 120×56px. Width already ≥ 88 → no change. Height: deficit = 32px → y shifts −16px, height = 88px.

---

### F-3: Swipe Release Velocity (`swipe_release_velocity`)

Computes the gesture's exit speed using the oldest retained position sample (maximises delta_t for noise stability). Output fed directly into the `swiped` signal's `velocity` parameter and compared against `SWIPE_MIN_VELOCITY_DP_S`.

| Symbol | Type | Range | Description |
|---|---|---|---|
| `last_position_px` | Vector2 | screen bounds | Finger position at release, in pixels |
| `sample_position_px` | Vector2 | screen bounds | Oldest position in the rolling sample window |
| `release_time_ms` | int | 0 — unbounded | Timestamp of touch-up event, in milliseconds |
| `sample_time_ms` | int | 0 — unbounded | Timestamp of oldest retained sample |
| `delta_t` | float | > 0 | Elapsed time in seconds; guarded against zero (see Edge Cases) |
| `velocity_dp_s` | float | 0 — ~4000 | Speed in dp/s; compared against SWIPE_MIN_VELOCITY_DP_S |

```
delta_px       = last_position_px - sample_position_px
delta_t        = (release_time_ms - sample_time_ms) / 1000.0
velocity_px_s  = length(delta_px) / delta_t
velocity_dp_s  = velocity_px_s / pixels_per_dp
```

**Example:** Release at (400, 200)px, oldest sample at (300, 350)px, 80ms ago, pixels_per_dp = 2.0:
- `length((100, −150)) ≈ 180.3 px`
- `velocity_px_s = 180.3 / 0.08 = 2253 px/s`
- `velocity_dp_s = 2253 / 2.0 = 1126 dp/s` → exceeds 150 threshold → swipe fires.

---

### F-4: Swipe Direction Classification (`classify_swipe_direction`)

Maps the full gesture arc (touch-down to release) to one of four cardinal directions using 45-degree sectors. Uses the full arc vector, not the velocity window.

| Symbol | Type | Range | Description |
|---|---|---|---|
| `delta` | Vector2 | unbounded | Displacement from touch-down to release in screen pixels (x right, y down) |
| `angle_deg` | float | (−180, +180] | atan2 result; y negated to convert screen-space (y-down) to math convention |
| `Direction` | enum | {RIGHT, UP, LEFT, DOWN} | Classified cardinal direction |

```
angle_rad = atan2(-delta.y, delta.x)
angle_deg = degrees(angle_rad)

RIGHT : angle_deg in (−45,  +45]
UP    : angle_deg in (+45, +135]
LEFT  : angle_deg in (+135, +180] ∪ (−180, −135]
DOWN  : angle_deg in (−135, −45]
```

Boundary convention: ties (exactly ±45°, ±135°, ±180°) resolve to the lower-numbered enum value (RIGHT=0, UP=1, LEFT=2, DOWN=3).

**Example:** delta = (100, −150) (rightward and upward). `atan2(150, 100) ≈ 56.3°` → falls in (+45, +135] → **UP**.

---

### F-5: Debounce Proximity Check (`debounce_proximity`)

Determines whether a new touch-down event is a bounce duplicate of the previous touch. Both conditions must be true to discard.

| Symbol | Type | Range | Description |
|---|---|---|---|
| `new_position_px` | Vector2 | screen bounds | Touch-down position of candidate new touch |
| `prev_position_px` | Vector2 | screen bounds | Touch-down position of most recently completed touch |
| `elapsed_ms` | int | 0 — unbounded | Time since previous touch ended |
| `distance_dp` | float | 0 — unbounded | Euclidean distance between positions in dp |
| `is_duplicate` | bool | {true, false} | If true, discard the candidate touch |

```
delta_px     = new_position_px - prev_position_px
distance_dp  = length(delta_px) / pixels_per_dp
is_duplicate = (elapsed_ms < DEBOUNCE_INTERVAL_MS) AND (distance_dp <= 10.0)
```

**Example:** prev touch ended at (200, 400)px. New touch at (208, 393)px. Elapsed: 60ms. pixels_per_dp = 2.5:
- `distance_dp = sqrt(64 + 49) / 2.5 ≈ 4.25 dp`
- `(60 < 100) AND (4.25 ≤ 10)` → **discarded**.

## Edge Cases

**EC-1: Simultaneous multi-finger touch-down**
If `finger_index != 0` fires a touch-down while a finger_index == 0 gesture is already active (TOUCH_DOWN, LONG_PRESS_PENDING, or SWIPE_TRACKING), the second touch is silently discarded. The active gesture continues uninterrupted. If `finger_index != 0` fires while in IDLE, it is also silently discarded. No signal is emitted, no error logged. `SINGLE_FINGER_MODE = true` is the constant that gates this.

**EC-2: Touch-up without a preceding touch-down**
If `InputEventScreenTouch` with `pressed = false` arrives while the state machine is in IDLE, the event is silently discarded. This can occur when the app is foregrounded mid-gesture (user was holding when screen locked; app resumes with finger still down but the touch-down event was lost). The framework remains in IDLE and emits nothing.

**EC-3: `DisplayServer.screen_get_dpi()` returns 0 or implausible value**
Values outside 72–640 DPI (including 0, which some emulators return) trigger the 160 DPI fallback defined in F-1. A warning is logged naming the detected value and the fallback applied. DPI is cached once at startup and never re-queried per frame.

**EC-4: Gesture timeout while app is backgrounded**
If the app is backgrounded during an active gesture (phone call, lock screen), the OS may not deliver a touch-up event. After `GESTURE_TIMEOUT_MS` (800ms) without a touch-up, the framework emits `touch_cancelled` and returns to IDLE. No special backgrounding code is required — this is the same timeout path as any other cancellation.

**EC-5: delta_t = 0 in swipe velocity calculation (F-3)**
If `release_time_ms == sample_time_ms` (same timestamp — possible on extremely fast swipes or clock precision limits), division by zero in F-3 is prevented by a guard: if `delta_t <= 0`, velocity is set to `SWIPE_MIN_VELOCITY_DP_S + 1` (ensuring the swipe fires) and a debug warning is logged. This is the only case where velocity is assumed rather than computed.

**EC-6: Target registered with size below 44×44dp**
Detected at registration time via F-2. The hit rect is silently inflated to the 44dp minimum (center-anchored). A debug-mode warning is logged naming the node path and actual dp size. The visual size is unchanged. Inflation happens once per registration — not recomputed per frame.

**EC-7: Blocking layer push without a matching pop**
If a consuming system calls `push_blocking_layer(id)` but never calls `pop_blocking_layer(id)` (e.g., modal removed without proper cleanup), the blocking layer stack is permanently polluted and lower-priority areas receive no signals. The framework exposes `clear_blocking_layers()` callable from `NOTIFICATION_WM_WINDOW_FOCUS_OUT`. Cleanup is a consuming-system contract — the framework does not silently auto-correct it.

**EC-8: Swipe transition from LONG_PRESS_PENDING**
If the finger moves ≥ 40dp while in LONG_PRESS_PENDING, the state transitions to SWIPE_TRACKING. `long_press_released` is NOT emitted — the long press is cancelled mid-hold. `long_press_started` was already emitted at threshold entry. Consuming systems that show UI on `long_press_started` must also handle cancellation by connecting to `swiped` or `touch_cancelled`. This is a consuming-system contract.

**EC-9: Debounce discards an intentional rapid second tap**
The 100ms debounce window at ±10dp is intentionally aggressive for commute conditions. A second tap on the same target within 100ms will be discarded. MVP has no double-tap gestures, so this is not a functional loss. If double-tap is added post-MVP, the debounce window must be shortened or a double-tap fast-path added before the debounce gate.

**EC-10: Area registry exceeds 32 simultaneously registered areas**
If the registered area count exceeds `MAX_REGISTERED_AREAS` at registration time, a debug-mode warning is logged naming the registering node. No registration is refused — 32 is a design constraint, not a code limit. This warning in production indicates a screen design problem (too many interactive targets), not a framework failure.

## Dependencies

### Upstream (what this framework depends on)

| System | Dependency Type | What is needed |
|--------|----------------|----------------|
| Game Config (System 1) | Data | All 15 named constants (`TAP_MAX_DURATION_MS`, `LONG_PRESS_MIN_DURATION_MS`, `TOUCH_SLOP_DP`, etc.) are compile-time constants in MVP. If any require live tuning without a rebuild post-MVP, promote them to Game Config entries. |
| Godot Input System | Engine | `InputEventScreenTouch` and `InputEventScreenDrag` via `_input()`. Standard Godot 4.6 input API — no plugin required. |
| `DisplayServer` API | Engine | `screen_get_dpi()` called once at startup for dp conversion (F-1). Falls back to 160 DPI if result is 0 or outside 72–640 range. |
| `Input` API | Engine | `vibrate_handheld(duration_ms)` called on confirmed Tap. Silently no-ops on platforms where haptic is unavailable (emulator, desktop test builds). |
| Godot 4.5+ Recursive Control disable | Engine | Used by `push_blocking_layer()` to prevent Control nodes consuming input via `_gui_input()` while a blocking layer is active. Verify API availability in Godot 4.6 before implementation. |

### Downstream (what depends on this framework)

| System | What it receives |
|--------|-----------------|
| Conversion UI (System 12) | `tapped` (approach buttons, NPC portrait); `swiped` (card scroll); calls `push_blocking_layer` / `pop_blocking_layer` when Conversion UI opens/closes |
| Village Map View (System 13) | `tapped` (select NPC or village position); blocked when Conversion UI layer is active |
| HUD & Progress System (System 14) | `tapped` (faith meter detail); always registered at lowest priority tier |
| Accessibility System (System 19) | Observer only — connects to `tapped`, `long_press_started`, `swiped`, `touch_cancelled` for haptic/audio augmentation; makes no `register()` calls |

**Consuming-system contract:** All downstream systems must call `register()` in `_ready()` and `unregister()` on `tree_exiting`. Each downstream system's own Dependencies section must reference this document.

## Tuning Knobs

| Knob | Current Value | Safe Range | What It Affects | When to Tune |
|------|--------------|------------|-----------------|--------------|
| `TAP_MAX_DURATION_MS` | 350ms | 200–500ms | Ceiling for tap classification. Below 200ms misses intentional taps on slow devices. Above 500ms, taps and long presses blur — dead band disappears. | If playtest shows missed taps on older devices, raise toward 450ms. |
| `LONG_PRESS_MIN_DURATION_MS` | 600ms | 400–900ms | Floor for long press. Must remain > `TAP_MAX_DURATION_MS` + dead band. Minimum gap between tap ceiling and long press floor is 100ms. | Raise if accidental long-presses fire too often; lower if long-press feels sluggish. |
| `TOUCH_SLOP_DP` | 8dp | 4–16dp | Noise floor — movement below this is ignored and does not reclassify the gesture. Too low: vibration noise fires false swipes. Too high: short intentional swipes are suppressed. | Raise on rough-commute playtest builds if swipes misfire. Lower if short swipes are dropped. |
| `SWIPE_MIN_DISTANCE_DP` | 40dp | 20–80dp | Minimum travel for swipe classification. Below 20dp, accidental drags trigger swipes. Above 80dp, intentional short swipes are rejected. | Tune after playtest on the smallest target device screen size. |
| `SWIPE_MIN_VELOCITY_DP_S` | 150dp/s | 80–300dp/s | Minimum release velocity for swipe to fire. The two-condition gate (distance AND velocity) prevents slow drag from triggering swipes. Lowering lets slow swipes fire; raising requires a decisive flick. | Raise if slow drags misfire as swipes in vibration conditions. Lower if intentional swipes are dropped. |
| `TAP_TARGET_MIN_SIZE_DP` | 44dp | 44dp (floor — do not lower) | Minimum tap target dimension enforced at hit-test time. 44dp is the iOS HIG and Android Material Design minimum. Lowering causes accessibility failures. | Do not lower. May raise for primary action buttons (56–64dp recommended). |
| `TAP_TARGET_MIN_GAP_DP` | 8dp | 4–16dp | Minimum edge-to-edge gap between adjacent targets for debug warnings. Does not block registration. | Raise if adjacent-target mis-taps appear in playtest. |
| `DEBOUNCE_INTERVAL_MS` | 100ms | 50–200ms | Window during which a second tap at the same position is discarded as bounce. Too low: double-fire on rough surfaces. Too high: legitimate rapid second taps are lost. | Tune after commute-condition playtest. |
| `GESTURE_TIMEOUT_MS` | 800ms | 500–1500ms | Maximum open gesture duration before cancellation. Should exceed any intentional long press but remain shorter than a plausible accidental hold. | Raise only if OS interruptions arrive more than 800ms late on target devices. |
| `HAPTIC_TAP_DURATION_MS` | 80ms | 20–120ms | Duration of haptic pulse on confirmed tap. Below 20ms is imperceptible on most devices. Above 120ms feels like an error vibration. | Lower if haptic feels intrusive. Raise if players report it not registering. |
| `MAX_REGISTERED_AREAS` | 32 | Design constraint — not a code limit | Debug warning threshold for area registry count. Exceeding it signals a screen design problem, not a framework failure. | Raise only if a specific screen deliberately requires more than 32 interactive areas after design review. |

**Non-overridable at MVP:** All constants above are non-overridable at runtime in MVP (`SINGLE_FINGER_MODE = true` is additionally fixed). Post-MVP, any knob flagged for live tuning should be promoted to Game Config and exposed via a debug overlay panel.

## Visual/Audio Requirements

### Audio

| Event | Sound | Notes |
|-------|-------|-------|
| Confirmed Tap (hit) | Short, high-pitched confirmation chime — light and immediate | Fires on every successful tap hit. Must feel rewarding, not intrusive — playtesters should notice its absence more than its presence. Sits below dialogue audio and music in the mix. |
| Confirmed Tap (miss — no registered area hit) | No sound | Silence on a miss is intentional. Do not play an error sound — the game world simply does not respond. |
| Long Press Started | Low, slow resonant hum — distinct from tap chime | Signals the hold has been recognised and something is pending. Must not be alarming. |
| Long Press Released | Soft resolution tone | Paired with `long_press_started`. Should feel like a breath released. |
| Swipe | No SFX at framework level | Swipe audio is the consuming system's responsibility (e.g., card scroll in Conversion UI). The framework emits the signal; audio response is context-dependent. |
| Touch Cancelled | No sound | OS interruptions must not produce audio. Silence avoids jarring the player during a phone call or notification. |

### Haptic

| Event | Pattern | Notes |
|-------|---------|-------|
| Confirmed Tap | Single pulse, `HAPTIC_TAP_DURATION_MS` (80ms) | Framework-level. Always fires on tap confirmation regardless of which consuming system handles the result. |
| Long Press Started | No haptic at framework level | Consuming systems may add a haptic pulse via their own logic if the long-press action warrants it (e.g., tooltip appearance). |
| Swipe, Cancellation | No haptic | Framework-level haptic is tap-only. All other haptic is consuming-system responsibility. |

### Visual

The framework emits no visual feedback. No ripple, highlight, or tap-confirmation animation is rendered at the framework level. All visual response to touch events is the consuming system's responsibility, tied to art direction. This is an absolute rule — do not add visual feedback to the framework layer.

## UI Requirements

### Debug Overlay (dev builds only)

The framework exposes a debug overlay toggled by a developer gesture (triple-tap in a corner, or an autoload flag in the Godot editor). The overlay renders:

- All registered touch areas as semi-transparent rect outlines, color-coded by priority tier
- The inflated hit rect vs. visual rect for any area below 44dp (shows the inflation gap)
- Current state machine state as a text label (IDLE / TOUCH_DOWN / LONG_PRESS_PENDING / SWIPE_TRACKING / RESOLVING)
- Active blocking layer stack as a list
- `pixels_per_dp` value and the raw DPI it was derived from
- A warning badge on any registered area below the 44dp minimum
- A horizontal line marking the `SAFE_ZONE_BOTTOM_FRACTION` (0.55) boundary

The debug overlay is never visible in release builds. It is the framework's only self-rendered UI surface.

### No Production UI

The framework renders nothing in production. All visual affordances — tap highlights, approach button states, NPC portrait selection rings — are consuming system responsibilities.

### Consuming System UI Contracts

| Consuming System | UI Responsibility |
|-----------------|------------------|
| Conversion UI (System 12) | Render approach button pressed states on `tapped`; show tooltip overlay on `long_press_started`; dismiss on `long_press_released` or `touch_cancelled` |
| Village Map View (System 13) | Render NPC selection ring on `tapped`; clear selection on `touch_cancelled` |
| HUD & Progress System (System 14) | Render faith meter expansion animation on `tapped` |
| Accessibility System (System 19) | Render screen-reader focus indicator on `tapped` and `long_press_started` |

### Safe Zone Enforcement

`SAFE_ZONE_BOTTOM_FRACTION = 0.55` defines the bottom 55% of screen height as the primary interaction zone for one-handed portrait play. The framework does not enforce this at the API level — it is a design constraint. UI designers must ensure all primary action buttons register within this zone.

## Acceptance Criteria

**AC-1: Tap classification — correct hit**
*Given* a registered 60×60dp Control at screen center, *when* a finger touches down and releases within 350ms with movement ≤ 8dp, *then* `tapped(target, position)` is emitted exactly once with the correct target reference, and a haptic pulse of 80ms fires.

**AC-2: Tap classification — miss (no registered area)**
*Given* no registered area at the touch position, *when* a tap gesture completes, *then* no signal is emitted and no haptic fires.

**AC-3: Tap target inflation**
*Given* a registered Control with a visual size of 20×20dp, *when* a tap lands at the visual center, *then* the tap resolves as a hit (inflated rect is 44×44dp centered on the visual bounds). *And* a debug warning was logged at registration time naming the node path and actual dp size.

**AC-4: Long press — starts and releases**
*Given* a registered Control, *when* a finger is held motionless for ≥ 600ms, *then* `long_press_started` is emitted at exactly the 600ms threshold. *When* the finger is subsequently released, *then* `long_press_released` is emitted. Neither `tapped` nor `touch_cancelled` is emitted.

**AC-5: Dead band — no signal in ambiguous zone**
*Given* a finger held for 400ms (between `TAP_MAX_DURATION_MS` 350ms and `LONG_PRESS_MIN_DURATION_MS` 600ms) with movement ≤ 8dp, *when* the finger releases, *then* no signal is emitted and the state machine returns to IDLE.

**AC-6: Swipe classification — all four directions**
*Given* a touch-down followed by a drag of ≥ 40dp at ≥ 150dp/s release velocity in each of the four cardinal directions, *when* the finger releases, *then* `swiped` is emitted with the correct `SwipeDirection` enum value per direction, classified using the 45-degree sectors defined in F-4.

**AC-7: Swipe velocity gate — slow drag rejected**
*Given* a finger that travels 50dp from touch-down but releases at < 150dp/s, *when* the finger releases, *then* no `swiped` signal is emitted and no haptic fires. The state machine returns to IDLE.

**AC-8: Multi-finger discard**
*Given* an active gesture on `finger_index == 0` (state = TOUCH_DOWN), *when* a second finger (`finger_index == 1`) touches down, *then* the second event is silently discarded, the active gesture continues uninterrupted, and no signal is emitted for the second finger.

**AC-9: Blocking layer — lower-priority areas suppressed**
*Given* areas A (priority 1) and B (priority 10) both registered, *when* `push_blocking_layer("modal", tier=5)` is called, *then* taps on area A (priority 1 < 5) produce no signal and taps on area B (priority 10 > 5) still produce `tapped`. *When* `pop_blocking_layer("modal")` is called, *then* taps on area A resume producing `tapped`.

**AC-10: Gesture timeout**
*Given* an active gesture in TOUCH_DOWN state, *when* 800ms elapse without a touch-up event, *then* `touch_cancelled` is emitted and the state machine returns to IDLE.

**AC-11: Debounce — bounce discarded**
*Given* a tap that completed at position P at time T, *when* a new touch-down fires at position P ± 10dp within 100ms of T, *then* the new touch is discarded and no signal is emitted.

**AC-12: DPI fallback**
*Given* a device where `DisplayServer.screen_get_dpi()` returns 0, *when* the framework initialises, *then* `pixels_per_dp` is set to `1.0` (160 DPI fallback) and a warning is logged naming the detected value and the fallback applied.

**AC-13: dp conversion accuracy**
*Given* a device with a reported DPI of 390, *when* a 44dp minimum tap target is computed, *then* the result is `44 × (390 / 160.0) = 107.25px`, verified via the `pixels_per_dp` read-only property.

**AC-14: No visual output in release builds**
*Given* a release build (debug overlay flag = false), *when* any gesture fires, *then* the framework renders no UI elements to the screen. Verified by screenshot comparison — no framework-owned nodes are visible.

## Open Questions

None — all sections complete. Post-MVP questions to revisit:
- Promote any tuning knobs that need live adjustment to Game Config
- Evaluate double-tap gesture support (requires narrowing debounce window first)
- Re-evaluate `SINGLE_FINGER_MODE` if multi-touch interactions are added post-MVP
