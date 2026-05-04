# Game State Manager

> **Status**: Complete
> **Author**: Design session + agents
> **Last Updated**: 2026-04-25
> **Implements Pillar**: Pillar 3 — The Arc Must Feel Earned; Pillar 4 — History Writes Itself

## Overview

The Game State Manager is the turn lifecycle and game-state authority for The Faithful. It owns four responsibilities that no other system is positioned to hold: advancing the NPC turn clock, initialising and clearing village scenes, evaluating win and loss conditions, and accumulating faith power from conversion outcomes. It is the only system that calls `NPCRegistry.advance_turn()`, `NPCRegistry.initialize_village()`, and `NPCRegistry.clear_village()` — exclusive ownership enforced by convention and verified at architecture time. It listens to `DialogueConversionSystem.session_complete` to know when a player action has resolved, then decides whether the turn should advance (player signals end-of-turn) or is forced to advance (all approachable NPCs exhausted). After each `advance_turn()` call it reads `NPCRegistry.get_npcs_by_belief(CONVERTED)` to evaluate the village win condition against `ProgressionConfig.village_win_conversion_pct` (default: 0.75). If the condition is met, it emits `village_won`; if `get_approachable_npcs()` returns empty while conversion is below the threshold, it evaluates the village loss condition. It increments `faith_power` by `ProgressionConfig.faith_power_per_conversion` on each CONVERTED belief-state transition, emitting `faith_power_changed` for the HUD & Progress System. At MVP it manages a single village scene; the macro-layer extension (region transitions, world win/lose condition) is post-MVP and is designed for but not implemented in the first milestone.

The system exists because without it, the call sequence from "player ends their turn" to "cooldowns tick, rival faith moves, faith spread propagates, win condition is checked" has no owner. The NPC Character System is a data store and cannot initiate turns. The Dialogue & Conversion System owns only a single session. The Faith Spread and Rival Faith Systems respond to turns but do not manage them. The Game State Manager is the single point that knows the current phase of play and sequences all per-turn operations.

## Player Fantasy

There is a moment, near the end of every village, when the prophet senses victory before the chronicle confirms it — three souls left, then two, then the final wavering heart. The Game State Manager is what makes that moment possible. It is the system that counts the turning tide, knows when the threshold has been crossed, and declares what the player's accumulated choices have earned. The fantasy is the sacred mathematics of conviction: a slow accumulation of converted souls building toward a tipping point the player can feel in their hands. When the last village falls into faith, it does not feel scripted; it feels inevitable, and earned.

The player never touches this system. But they feel it in the weight of each turn ending, in the crisis when all NPCs go cold and the turn advances with nothing accomplished, and in the quiet authority with which the game says: *this village is yours now.* The Game State Manager is the keeper of the arc. Every individual conversation the Dialogue & Conversion System delivers, every soul the NPC Character System tracks — the Game State Manager is the one that holds them together into a story with a shape.

## Detailed Design

### Core Rules

**1. Exclusive turn lifecycle ownership.** The Game State Manager is the only system that calls `NPCRegistry.advance_turn()`, `NPCRegistry.initialize_village()`, and `NPCRegistry.clear_village()`. No other system may call these methods. Enforced by convention; violations are a critical architecture bug.

**2. Two turn-advance triggers.** A turn advances when either condition is true:
- **(a) Player trigger**: The Village Map UI calls `GameStateManager.request_end_turn()` while GSM state is `IDLE`.
- **(b) Exhaustion trigger**: After a `session_complete` signal from the Dialogue & Conversion System, the GSM calls `NPCRegistry.get_approachable_npcs()`. If it returns empty and the win condition is not met, the turn advances automatically — no player action required.

**3. Turn phase sequence.** When a turn advances, operations execute in this fixed order:

```
Step 1:  Transition GSM state → TURN_ADVANCING
Step 2:  Emit turn_advancing(turn_number)
Step 3:  NPCRegistry.advance_turn()              ← decrements all NPC cooldowns
Step 4:  FaithSpreadSystem.process_turn()        ← passive spread on post-tick NPC states
Step 5:  RivalFaithSystem.process_turn()         ← rival counter-pressure after spread
Step 6:  Evaluate win condition
           CONVERTED_count / total_npc_count >= village_win_conversion_pct
           → VILLAGE_WON: emit village_won(turn_number); STOP turn sequence
Step 7:  Evaluate loss condition
           get_approachable_npcs() returns empty
           → VILLAGE_LOST: emit village_lost(turn_number); STOP turn sequence
Step 8:  Increment turn_number
Step 9:  Emit turn_advanced(turn_number)
Step 10: Transition GSM state → IDLE
```

*Ordering rationale:* `advance_turn()` runs first so all cooldown states are correct when Faith Spread and Rival Faith read `get_approachable_npcs()`. Faith Spread runs before Rival Faith — organic neighbor influence precedes reactive counter-pressure, so the Rival Faith System targets accurate updated states. Win is checked before loss: if the last NPC converts via spread on the same turn the approachable list empties, that is a win, not a loss.

**4. Faith power accumulation.** The GSM subscribes to `NPCRegistry.npc_state_changed(npc_id, old_state, new_state)`. When `new_state == BeliefState.CONVERTED`, it awards `ProgressionConfig.faith_power_per_conversion` (default: 10) immediately and emits `faith_power_changed(new_total)`. Faith power is a run-wide accumulator — it is not reset on `clear_village()`. It persists across all village transitions for the duration of a playthrough, as it gates the multi-village expansion path unlocks (missionary threshold: 100, court: 250, crusade: 500).

*Deduplication guard:* The GSM maintains a `converted_ids: Array[String]` set. If `npc_state_changed` fires with `new_state == CONVERTED` for an `npc_id` already in this set, the award is skipped and a warning is logged. `converted_ids` is cleared on `village_cleared`.

*Rival regression handler:* When `npc_state_changed` fires with `old_state == BeliefState.CONVERTED AND new_state == BeliefState.WAVERING` (caused by a Rival Faith System grace-window regression), the GSM removes `npc_id` from `converted_ids`. No faith power is deducted — unlocks and awards from the original conversion are permanent. Removing the ID from `converted_ids` re-arms the deduplication guard, so when the player re-converts that NPC the faith-power award fires again. Reclaiming a rival-regressed NPC counts as a new conversion for faith-power purposes.

**5. Village win condition.** Evaluated each turn at Step 6. The condition is:

```
converted_count / total_npc_count >= ProgressionConfig.village_win_conversion_pct
```

where `converted_count = NPCRegistry.get_npcs_by_belief(CONVERTED).size()` and `total_npc_count` is cached at `initialize_village()` time and not recomputed mid-turn.

**6. Village loss condition.** Evaluated each turn at Step 7, only if the win condition is not met. The condition is: `NPCRegistry.get_approachable_npcs()` returns empty. An empty approachable list with no win means no path to victory remains this turn — all NPCs are either at `max_approaches_per_npc`, on cooldown, or behind unmet access gates.

**7. Scene lifecycle.** The GSM owns the village load and clear sequence:

*Village load:*
```
1. GSM calls NPCRegistry.initialize_village(npc_definitions)
2. NPCRegistry emits village_initialized
3. GSM receives village_initialized → transitions UNINITIALIZED → IDLE
4. GSM emits village_ready(village_id)
```

*Village clear (after WIN or LOST only):*
```
1. GSM emits village_clearing()
2. GSM calls NPCRegistry.clear_village()
3. GSM resets: converted_ids = []; turn_number = 0
4. GSM emits village_cleared()
   ← DCS subscribes and resets recency state on this signal
5. GSM transitions → UNINITIALIZED
```

**Godot 4.6 constraint:** `NPCRegistry.clear_village()` must only be called from within the `SceneTree.scene_changed` callback — never inline during the WIN/LOST state transition. Scene changes in Godot 4.x are deferred to end-of-frame; calling `clear_village()` before the transition completes risks use-after-free on nodes the outgoing scene still holds.

**8. Turn gate.** End-of-turn is blocked in all GSM states except `IDLE`. The Village Map UI disables the End Turn tap target based on GSM state. `request_end_turn()` is a no-op and logs a warning when GSM state is not `IDLE`. The GSM never queues a deferred turn advance — if the player taps End Turn during `IN_SESSION` and the UI fails to block it, the call is swallowed. The exhaustion auto-advance (Rule 2b) fires after `session_complete` covers all auto-advance cases.

**9. Signal-only relationship with DCS.** The GSM subscribes to DCS signals (`session_begun`, `session_complete`) but never calls any DCS method. DCS is not in the GSM's dependency list — the coupling is signal-only, so the systems can be initialized independently.

**10. Autoload initialization order.** GSM must be listed in Project Settings after `NPCRegistry` and `DialogueConversionSystem`. GSM connects to external signals via `call_deferred("_connect_signals")` in `_ready()` to ensure all Autoloads are initialized before any signal emitted during `_ready()` could be missed.

---

### States and Transitions

| State | Description |
|---|---|
| `UNINITIALIZED` | Before `village_initialized` fires. GSM exists but cannot process turns or sessions. |
| `IDLE` | Village loaded; player may tap NPCs; turn advance allowed. |
| `IN_SESSION` | DCS session running (`session_begun` received; `session_complete` not yet received). Player turn advance blocked. |
| `TURN_ADVANCING` | Turn phase sequence (Steps 1–10 above) is executing. No player input processed. |
| `VILLAGE_WON` | Win condition met. Village locked; clear sequence fires. |
| `VILLAGE_LOST` | Loss condition met. Village locked; clear sequence fires. |

| From | To | Trigger |
|---|---|---|
| `UNINITIALIZED` | `IDLE` | `NPCRegistry.village_initialized` signal |
| `IDLE` | `IN_SESSION` | `DCS.session_begun(npc_id)` signal |
| `IDLE` | `TURN_ADVANCING` | `request_end_turn()` called OR exhaustion trigger fires after `session_complete` |
| `IN_SESSION` | `IDLE` | `DCS.session_complete` signal |
| `IDLE` | `TURN_ADVANCING` | (exhaustion check immediately follows `session_complete` → `IDLE` transition) |
| `TURN_ADVANCING` | `VILLAGE_WON` | Win condition true (Step 6) |
| `TURN_ADVANCING` | `VILLAGE_LOST` | Loss condition true (Step 7) |
| `TURN_ADVANCING` | `IDLE` | Neither condition met (Step 10) |
| `VILLAGE_WON` / `VILLAGE_LOST` | `UNINITIALIZED` | Village clear sequence complete |

---

### Interactions with Other Systems

| System | Relationship | Calls / Signals |
|---|---|---|
| `NPCRegistry` (NPC Character System) | Upstream — data store and turn clock | Calls: `initialize_village()`, `advance_turn()`, `clear_village()`, `get_npcs_by_belief(CONVERTED)`, `get_approachable_npcs()`. Subscribes to: `village_initialized`, `npc_state_changed` |
| `DialogueConversionSystem` | Peer — subscribes only | Subscribes to: `session_begun`, `session_complete`. Never calls DCS methods. |
| `FaithSpreadSystem` | Downstream — responds to turns | Calls: `FaithSpreadSystem.process_turn()` at Step 4 each turn |
| `RivalFaithSystem` | Downstream — responds to turns | Calls: `RivalFaithSystem.process_turn()` at Step 5 each turn |
| `HUD & Progress System` | Downstream — display | Subscribes to: `faith_power_changed`, `turn_advanced`, `village_won`, `village_lost`. Calls: `get_faith_power()`, `get_turn_number()` |
| `Save & Load System` | Downstream — persistence | Calls: `get_turn_number()`, `get_faith_power()`, `get_gsm_state()` at save time. GSM calls `initialize_village()` path on load. |
| `Audio System` | Downstream — reactive | Subscribes to: `village_won`, `village_lost`, `turn_advanced` for music cue transitions |
| `Tutorial & Onboarding` | Downstream — observes | Subscribes to GSM signals as tutorial progression hooks. Must not intercept or block any sequence. |
| `Village Map UI` | Downstream — player input surface | Calls: `request_end_turn()`. Subscribes to: `village_ready`, `turn_advanced`, `village_won`, `village_lost` to update tap targets and UI state. |

**Exposed API:**

```gdscript
# GameStateManager (Autoload singleton)

# Signals
signal village_ready(village_id: String)
signal turn_advancing(turn_number: int)
signal turn_advanced(turn_number: int)
signal village_won(turn_number: int)
signal village_lost(turn_number: int)
signal faith_power_changed(new_total: int)
signal village_clearing()
signal village_cleared()

# Commands (Village Map UI only)
func request_end_turn() -> void  # no-op if state != IDLE

# Queries (HUD, Save & Load)
func get_turn_number() -> int
func get_faith_power() -> int
func get_gsm_state() -> GSMState

# Save & Load (SaveLoadSystem only)
func get_save_data() -> Dictionary          # returns { "turn_number", "faith_power", "gsm_state" (String), "converted_ids", "village_id" }
func restore_from_save(data: Dictionary) -> void  # applies Rule 6 restoration; emits village_ready or triggers clear sequence
```

## Formulas

### Formula 1 — Village Win Condition

```
win = (converted_count / total_npc_count) >= village_win_conversion_pct
```

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `converted_count` | Converted NPC count | int | [0, `total_npc_count`] | `NPCRegistry.get_npcs_by_belief(CONVERTED).size()` — read each turn at Step 6 |
| `total_npc_count` | Village NPC count | int | [1, ~20] | Cached at `initialize_village()` time; not recomputed mid-turn |
| `village_win_conversion_pct` | Win threshold | float | [0.5, 1.0] | Default: 0.75. Read from `ProgressionConfig` |
| `win` | Win result | bool | {true, false} | True if converted fraction meets or exceeds threshold |

**Output range:** Boolean. In GDScript 4, `/` between two `int` operands returns `float` — no cast needed. The comparison is `>=`, so hitting exactly the threshold is a win.

**Edge case — `total_npc_count = 0`:** Rejected by `initialize_village()` before the GSM accepts the village definition. This formula is never evaluated for a zero-NPC village.

**Edge case — `converted_count > total_npc_count`:** Impossible when the `converted_ids` deduplication guard is enforced, but `converted_count` is clamped to `total_npc_count` defensively before evaluation.

**Worked example — 8 NPCs, default threshold (0.75):**
`6 / 8 = 0.75 >= 0.75` → `win = true`. Minimum winning count: 6 of 8.
At 5: `5 / 8 = 0.625` → `win = false`.

**Worked example — 12 NPCs, default threshold (0.75):**
`9 / 12 = 0.75 >= 0.75` → `win = true`. Minimum winning count: 9 of 12.

---

### Formula 2 — Faith Power Accumulation

```
faith_power = faith_power + faith_power_per_conversion
```

Applied once per unique CONVERTED belief-state transition, detected via `NPCRegistry.npc_state_changed(npc_id, old_state, BeliefState.CONVERTED)`.

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `faith_power` | Faith power total | int | [0, unbounded] | Run-wide accumulator. Starts at 0. Never reset on `clear_village()`. Persists across all villages in the playthrough. |
| `faith_power_per_conversion` | Award per conversion | int | [1, 100] | Default: 10. Read from `ProgressionConfig.faith_power_per_conversion` |

**Output range:** [0, unbounded]. No cap is applied — once all three expansion paths are unlocked (max threshold: 500), excess faith power is inert. The `converted_ids` deduplication guard prevents double-awards within a village.

**Threshold crossings at default (10 fp/conversion):**

| Expansion Path | Unlock Threshold | Conversions Required |
|---|---|---|
| Missionary | 100 fp | 10 |
| Court | 250 fp | 25 |
| Crusade | 500 fp | 50 |

**Worked example — one full 10-NPC village, default (10 fp/conversion):**
10 conversions × 10 = 100 fp. Missionary path unlocks on the final conversion of that village.
Crusade path (500 fp) requires approximately 5 full villages at 10 NPCs each.

**Edge case — signal fires twice for same `npc_id`:** Deduplication guard in GSM skips the award and logs a warning. `CONVERTED` is a terminal state per NPC Character System Rule 5 — the guard is a defense, not an expected code path.

## Edge Cases

**EC-1. Zero-NPC village at `initialize_village()`.** If `npc_definitions` is empty, `initialize_village()` rejects the call immediately — logs an error and remains `UNINITIALIZED`. The GSM never transitions to `IDLE` for a zero-NPC village. The win-condition formula divide-by-zero is never reached.

**EC-2. Single-NPC village.** With `total_npc_count = 1`, any non-zero `village_win_conversion_pct` produces a binary outcome: convert the one NPC (1/1 = 1.0 ≥ threshold → win) or exhaust approaches without converting (loss). No intermediate progress state exists. Threshold tuning guides must account for this: single-NPC villages are pass/fail by design.

**EC-3. Win and loss conditions evaluate true in the same turn.** If `FaithSpreadSystem.process_turn()` converts the last required NPC in Step 4 and `RivalFaithSystem.process_turn()` simultaneously causes the approachable list to empty in Step 5, the win check (Step 6) runs before the loss check (Step 7). Win takes precedence. The GSM must evaluate win and loss only at Steps 6 and 7 — not inside signal handlers. `npc_state_changed` firing mid-sequence must not trigger an early win evaluation.

**EC-4. `session_begun` received while `TURN_ADVANCING`.** If a deferred signal queues during the turn sequence, the `session_begun` handler checks GSM state. If not `IDLE`, the signal is discarded and a warning is logged. GSM does not transition out of `TURN_ADVANCING` on this signal.

**EC-5. `session_complete` received while `IDLE` (no prior `session_begun`).** Orphaned signal from a crashed or reset session. The `session_complete` handler checks current state; if not `IN_SESSION`, the signal is discarded and a warning logged. The exhaustion auto-advance does not fire on an orphaned `session_complete`.

**EC-6. `session_complete` never arrives — GSM stuck `IN_SESSION` indefinitely.** If DCS crashes or a dialogue path has no exit, `IN_SESSION` is permanent: turns freeze, End Turn is blocked, exhaustion never triggers. Current rules have no timeout or recovery. See Open Questions OQ-1.

**EC-7. Spread-triggered CONVERTED during turn sequence.** `FaithSpreadSystem.process_turn()` (Step 4) may emit `npc_state_changed` with `new_state == CONVERTED` synchronously. The GSM faith-power handler fires mid-sequence, updating `converted_ids`. The win condition at Step 6 reads `get_npcs_by_belief(CONVERTED)` live — it includes these spread-converted NPCs. `converted_count` must always be a fresh call at Step 6, never a value cached before Step 4.

**EC-8. `npc_state_changed` fires with `old_state == CONVERTED` and `new_state == CONVERTED`.** The `converted_ids` guard is keyed on `npc_id`, not on the `(old_state, new_state)` pair. If NPCRegistry emits this redundantly due to a bug, the guard skips the faith-power award and logs a warning. The guard is intentionally id-keyed rather than transition-keyed.

**EC-9. App backgrounded or interrupted during `TURN_ADVANCING`.** Save & Load reads `get_gsm_state() = TURN_ADVANCING`. Restoring to `TURN_ADVANCING` mid-sequence is unsafe — cooldowns may have already decremented, spread may have run, but win/loss has not been evaluated. The Save & Load System must restore a `TURN_ADVANCING` save as `IDLE`, treating the turn as having advanced (`turn_number` is the current value; NPC cooldown states reflect `advance_turn()` output). Save & Load GDD must specify this handling.

**EC-10. Save captured while `VILLAGE_WON` or `VILLAGE_LOST`.** The clear sequence is deferred to `scene_changed`; if the app is killed between state transition and scene change, the save holds `VILLAGE_WON` with `converted_ids` still populated. On load, Save & Load must detect this state and re-trigger the clear sequence rather than restoring to a playable village. The GSM must expose a safe re-entry point for this recovery path.

**EC-11. `request_end_turn()` called while `UNINITIALIZED`.** Explicitly a no-op. The turn gate rule (Rule 8) blocks all states except `IDLE` — `UNINITIALIZED` is not `IDLE`. Logged as a warning. This case covers the gap between `village_cleared` and the next `village_initialized` signal.

**EC-12. `initialize_village()` called while `IDLE` (double-initialization).** If a scene transition bug calls `initialize_village()` on an already-active village, the call is a no-op — the GSM logs an error and returns without mutating state. `initialize_village()` only proceeds when GSM state is `UNINITIALIZED`.

## Dependencies

### Systems This System Depends On

| System | GDD | Dependency Nature | Specific Interface |
|---|---|---|---|
| NPC Character System | `npc-character-system.md` | **Hard** — without NPCRegistry, the GSM cannot initialize villages, advance turns, or evaluate win conditions. | Calls: `initialize_village()`, `advance_turn()`, `clear_village()`, `get_npcs_by_belief(CONVERTED)`, `get_approachable_npcs()`. Subscribes to: `village_initialized`, `npc_state_changed` |
| Game Config | `game-config.md` | **Hard** — `ProgressionConfig` provides both win-condition threshold and faith-power award rate. Without it, neither formula can evaluate. | Reads: `ProgressionConfig.village_win_conversion_pct` (win condition), `ProgressionConfig.faith_power_per_conversion` (award rate), `ProgressionConfig.missionary_unlock_threshold`, `ProgressionConfig.court_unlock_threshold`, `ProgressionConfig.crusade_unlock_threshold` (for threshold-crossing notification to HUD) |

---

### Systems That Depend On This System

| System | GDD | What It Uses |
|---|---|---|
| Dialogue & Conversion System | `dialogue-conversion-system.md` | GSM subscribes to DCS signals (`session_begun`, `session_complete`). GSM never calls DCS methods. DCS subscribes to `village_cleared` to reset its recency state. |
| Faith Spread System | *(GDD pending)* | GSM calls `FaithSpreadSystem.process_turn()` at turn Step 4. Faith Spread System is a downstream responder — it does not initiate turns. |
| Rival Faith System | *(GDD pending)* | GSM calls `RivalFaithSystem.process_turn()` at turn Step 5. Rival Faith System is a downstream responder — it does not initiate turns. |
| HUD & Progress System | *(GDD pending)* | Subscribes to `faith_power_changed`, `turn_advanced`, `village_won`, `village_lost`. Calls `get_faith_power()`, `get_turn_number()` to populate progress displays. |
| Save & Load System | *(GDD pending)* | Calls `get_turn_number()`, `get_faith_power()`, `get_gsm_state()` at save time. Must handle `TURN_ADVANCING` and `VILLAGE_WON/LOST` restored states (EC-9, EC-10). GSM calls `initialize_village()` on the load path. |
| Audio System | *(GDD pending)* | Subscribes to `village_won`, `village_lost`, `turn_advanced` for music cue transitions. |
| Tutorial & Onboarding | *(GDD pending)* | Subscribes to GSM signals as progression hooks. Must not intercept or block any GSM operation. |
| Village Map UI | *(GDD pending)* | Calls `request_end_turn()`. Subscribes to `village_ready`, `turn_advanced`, `village_won`, `village_lost` to enable/disable tap targets and update UI state. Reads `get_gsm_state()` to manage End Turn button availability. |

---

### Cross-System Updates Required Before Implementation

1. **Dialogue & Conversion System GDD** — The DCS GDD (§Formulas, recency state lifetime) states: "When the Game State Manager calls `NPCRegistry.clear_village()`, this system's recency state is reset to empty." The mechanism has been updated: DCS now subscribes to GSM's `village_cleared` signal rather than being called directly. The DCS GDD must be updated to reflect this before implementation.

2. **This GDD** — Updated to accommodate the Rival Faith System (Core Rule 11b): the `npc_state_changed` handler now also handles `CONVERTED → WAVERING` regression by removing `npc_id` from `converted_ids`. Reflected above in Rule 4 (rival regression handler) and AC-4.5. No further update required.

3. **This GDD** — Updated to accommodate the Save & Load System (Rule 8a): `get_save_data()` and `restore_from_save()` added to the API block. `get_save_data()` includes `village_id` (the active village identifier, cached at `initialize_village()` time). `restore_from_save()` implements the state restoration rules defined in the Save & Load System GDD §Detailed Design Rule 6. No further update required.

## Tuning Knobs

The Game State Manager introduces no new tuning knobs. All values it reads are owned by the Game Config GDD. They are listed here for implementer reference.

### Consumed from `ProgressionConfig` (owned by `game-config.md`)

| Knob | Field | Default | Safe Range | Effect on GSM |
|---|---|---|---|---|
| Village win threshold | `village_win_conversion_pct` | 0.75 | 0.50–1.00 | Minimum converted fraction to trigger `village_won`. At 0.50, half the village converts to win. At 1.00, every NPC must convert — loss is nearly guaranteed in any village with an inaccessible NPC. |
| Faith power per conversion | `faith_power_per_conversion` | 10 | 1–100 | Amount added to `faith_power` on each CONVERTED transition. Scales how quickly expansion paths unlock relative to NPC count. |
| Missionary unlock threshold | `missionary_unlock_threshold` | 100 | 10–1000 | `faith_power` total at which the Missionary expansion path becomes available. |
| Court unlock threshold | `court_unlock_threshold` | 250 | 10–1000 | `faith_power` total at which the Court expansion path becomes available. Must be > `missionary_unlock_threshold`. |
| Crusade unlock threshold | `crusade_unlock_threshold` | 500 | 10–1000 | `faith_power` total at which the Crusade expansion path becomes available. Must be > `court_unlock_threshold`. |

### Tuning Interaction Warning

`village_win_conversion_pct` and `faith_power_per_conversion` interact indirectly: a higher win threshold means more conversions per village, which means more faith power accumulated per village. If `village_win_conversion_pct` is raised to 1.0 while `faith_power_per_conversion` remains at 10, the Crusade path (500 fp) unlocks faster relative to the total NPC count in a full game — because the player must convert more NPCs per village to advance. Tuning one without considering the other will distort the expansion path unlock cadence.

## Visual/Audio Requirements

No direct visual or audio requirements. The GSM emits signals (`village_won`, `village_lost`, `turn_advanced`, `faith_power_changed`) that the Audio System subscribes to for music cue transitions. The visual expressions of those events — conversion surges, cooldown overlays, village map color shifts — are specified in the downstream system GDDs (Audio System, Portrait & Expression System, Village Map View).

## UI Requirements

No direct UI requirements. The GSM exposes `get_gsm_state()`, `get_faith_power()`, and `get_turn_number()` for downstream UI systems to read on demand. The End Turn button behavior and faith power display are specified in the Village Map UI and HUD & Progress System GDDs respectively. The GSM does not own or specify any UI element — it surfaces data and emits signals; UI systems decide how to present them.

## Acceptance Criteria

### AC-1: State Machine

**AC-1.1:** GIVEN the game loads and `village_initialized` has not fired, WHEN any call is made to the GSM, THEN the GSM state is `UNINITIALIZED` and no turn operations execute.

**AC-1.2:** GIVEN GSM is `UNINITIALIZED`, WHEN `NPCRegistry.village_initialized` fires, THEN GSM transitions to `IDLE` and emits `village_ready(village_id)`.

**AC-1.3:** GIVEN GSM is `IDLE`, WHEN `DCS.session_begun(npc_id)` fires, THEN GSM transitions to `IN_SESSION`.

**AC-1.4:** GIVEN GSM is `IN_SESSION`, WHEN `DCS.session_complete` fires, THEN GSM transitions to `IDLE`.

**AC-1.5:** GIVEN a turn advance is triggered, WHEN the turn sequence begins (Step 1), THEN GSM state is `TURN_ADVANCING` for the entire duration of Steps 1–10. WHEN Step 10 completes with no win or loss, THEN GSM transitions to `IDLE`.

**AC-1.6:** GIVEN GSM is `TURN_ADVANCING`, WHEN the win condition evaluates true (Step 6), THEN GSM transitions to `VILLAGE_WON` and the turn sequence stops — Steps 7–10 do not execute.

**AC-1.7:** GIVEN GSM is `TURN_ADVANCING`, WHEN the loss condition evaluates true (Step 7), THEN GSM transitions to `VILLAGE_LOST` and the turn sequence stops — Steps 8–10 do not execute.

---

### AC-2: Turn Advance Triggers

**AC-2.1:** GIVEN GSM is `IDLE`, WHEN `request_end_turn()` is called, THEN the turn sequence begins and GSM transitions to `TURN_ADVANCING`.

**AC-2.2:** GIVEN GSM is `IN_SESSION` and `session_complete` fires and `get_approachable_npcs()` returns empty, WHEN GSM transitions to `IDLE`, THEN the turn advance fires automatically without any player action.

**AC-2.3:** GIVEN GSM is `IN_SESSION` and `session_complete` fires and `get_approachable_npcs()` returns a non-empty list, WHEN GSM transitions to `IDLE`, THEN no turn advance fires — GSM remains `IDLE`.

---

### AC-3: Turn Phase Sequence and Ordering

**AC-3.1:** GIVEN a turn advances, WHEN Step 3 executes, THEN `NPCRegistry.advance_turn()` is called exactly once, and all NPC cooldowns are decremented before any spread or rival processing begins.

**AC-3.2:** GIVEN a turn advances, WHEN Steps 4 and 5 execute, THEN `FaithSpreadSystem.process_turn()` completes before `RivalFaithSystem.process_turn()` begins.

**AC-3.3:** GIVEN a turn advances where both the win and loss conditions would evaluate true, WHEN Step 6 and Step 7 run, THEN `village_won` fires and `village_lost` does not — win takes precedence.

**AC-3.4:** GIVEN a turn advances and neither win nor loss fires, WHEN Step 8 executes, THEN `turn_number` has incremented by exactly 1 and `turn_advanced(new_turn_number)` is emitted.

---

### AC-4: Faith Power Accumulation

**AC-4.1:** GIVEN an NPC transitions from `WAVERING` to `CONVERTED`, WHEN `NPCRegistry.npc_state_changed` fires, THEN `faith_power` increases by exactly `ProgressionConfig.faith_power_per_conversion` (default: 10) and `faith_power_changed(new_total)` is emitted.

**AC-4.2:** GIVEN an NPC is already in `converted_ids` and `npc_state_changed` fires again with `new_state == CONVERTED` for that same `npc_id`, WHEN the GSM handler runs, THEN `faith_power` does not change and no `faith_power_changed` signal fires.

**AC-4.3:** GIVEN `village_cleared` fires after a village win, WHEN the GSM processes the signal, THEN `converted_ids` is empty AND `faith_power` retains its pre-clear value unchanged.

**AC-4.4:** GIVEN the player has accumulated 90 `faith_power` and converts 1 more NPC, WHEN the award applies, THEN `faith_power` equals 100 and `faith_power_changed(100)` is emitted.

**AC-4.5:** GIVEN the Rival Faith System regresses NPC X from CONVERTED to WAVERING (emitting `npc_state_changed(npc_id_X, CONVERTED, WAVERING)`), WHEN the GSM handler fires, THEN `npc_id_X` is removed from `converted_ids` and `faith_power` does not change. WHEN the player subsequently re-converts NPC X, THEN `faith_power` increases by `faith_power_per_conversion` and `faith_power_changed` is emitted — the re-conversion is not blocked by the `converted_ids` guard.

---

### AC-5: Village Win Condition (Formula 1)

**AC-5.1:** GIVEN a village with 8 NPCs and `village_win_conversion_pct = 0.75`, WHEN `converted_count` reaches 6, THEN `6/8 = 0.75 >= 0.75` evaluates true and `village_won` is emitted.

**AC-5.2:** GIVEN a village with 8 NPCs and `village_win_conversion_pct = 0.75`, WHEN `converted_count` is 5, THEN `5/8 = 0.625 >= 0.75` evaluates false and `village_won` is NOT emitted.

**AC-5.3:** GIVEN `converted_count / total_npc_count` equals exactly `village_win_conversion_pct`, WHEN the win check runs, THEN `village_won` is emitted — the `>=` comparison is inclusive.

**AC-5.4:** GIVEN a single-NPC village (`total_npc_count = 1`) and `village_win_conversion_pct = 0.75`, WHEN that NPC converts, THEN `1/1 = 1.0 >= 0.75` evaluates true and `village_won` fires. WHEN all approaches are exhausted without converting, THEN `village_lost` fires.

**AC-5.5:** GIVEN `FaithSpreadSystem.process_turn()` converts an NPC (emitting `npc_state_changed` synchronously during Step 4) that brings `converted_count` from 5 to 6 in an 8-NPC village, WHEN the win check runs at Step 6, THEN `converted_count` reads as 6 (live query from NPCRegistry) and `village_won` fires.

---

### AC-6: Village Loss Condition

**AC-6.1:** GIVEN the win condition is false, WHEN `get_approachable_npcs()` returns empty at Step 7, THEN `village_lost` is emitted and the turn sequence stops.

**AC-6.2:** GIVEN win condition is true and `get_approachable_npcs()` also returns empty, WHEN the turn sequence runs, THEN `village_won` fires (Step 6) and `village_lost` does NOT fire.

---

### AC-7: Scene Lifecycle

**AC-7.1:** GIVEN GSM is `UNINITIALIZED`, WHEN `initialize_village(npc_definitions)` is called with a non-empty list, THEN `NPCRegistry.initialize_village()` is called and the GSM waits for `village_initialized` before transitioning to `IDLE`.

**AC-7.2:** GIVEN `initialize_village()` is called while GSM is `IDLE`, WHEN the call is received, THEN the GSM logs an error, does not call `NPCRegistry.initialize_village()`, and does not change state.

**AC-7.3:** GIVEN `initialize_village()` is called with an empty NPC list, WHEN the call is received, THEN the GSM logs an error and remains `UNINITIALIZED`.

**AC-7.4:** GIVEN `VILLAGE_WON` or `VILLAGE_LOST` is reached, WHEN `NPCRegistry.clear_village()` is called, THEN it is called from within the `SceneTree.scene_changed` callback — NOT synchronously during the state transition that triggered WIN/LOST.

**AC-7.5:** GIVEN `village_cleared` fires, WHEN DCS receives this signal, THEN DCS recency state resets to empty. (Integration test between GSM and DCS.)

---

### AC-8: Turn Gate

**AC-8.1:** GIVEN GSM is in any state other than `IDLE`, WHEN `request_end_turn()` is called, THEN no turn advance begins and no state change occurs.

**AC-8.2:** GIVEN GSM is `IN_SESSION` and `request_end_turn()` is called, WHEN the call is received, THEN the active session continues normally to `session_complete` without interruption.

---

### AC-9: DCS Signal Relationship

**AC-9.1:** GIVEN all Autoloads have initialized, WHEN `session_begun` fires after GSM's `_ready()` completes, THEN GSM receives the signal and transitions to `IN_SESSION` — no signals fired during peer Autoload `_ready()` are silently dropped.

**AC-9.2:** GIVEN `session_begun` fires while GSM is `TURN_ADVANCING`, WHEN the handler runs, THEN GSM remains `TURN_ADVANCING` and does not transition to `IN_SESSION`.

**AC-9.3:** GIVEN `session_complete` fires while GSM is `IDLE` (no prior `session_begun`), WHEN the handler runs, THEN GSM remains `IDLE` and no exhaustion check or turn advance fires.

**AC-9.4:** At no point during a test run does the GSM call any method on `DialogueConversionSystem` directly — all communication is via subscribed signals only.

## Open Questions

**OQ-1. Recovery path when `session_complete` never arrives.**
If `DialogueConversionSystem` crashes or a dialogue path has no exit, the GSM is stuck in `IN_SESSION` indefinitely — turns freeze and the game is unplayable. The current design has no timeout or force-recovery path. Two options: (a) the DCS GDD guarantees `session_complete` is emitted on every exit path, including crashes and mid-session device backgrounding; or (b) the GSM exposes a `force_end_session()` debug/recovery escape hatch that the Save & Load System or OS-interrupt handler can call. Resolution required before DCS implementation begins.

**OQ-2. Save & Load recovery for `TURN_ADVANCING` and `VILLAGE_WON/LOST` states.**
EC-9 and EC-10 identify that saves taken during mid-turn or mid-clear states require explicit recovery logic. The current GDD describes the expected restored state (TURN_ADVANCING → IDLE; VILLAGE_WON/LOST → re-trigger clear sequence) but does not define the exact save format or restoration procedure. Resolution: Save & Load System GDD must specify how GSM state is serialized, how mid-turn saves are marked, and what the re-entry sequence is for WIN/LOST states.

**OQ-3. Does GSM detect and emit expansion path unlock events, or does the Multi-path Expansion System self-monitor?**
The GSM reads all three expansion unlock thresholds (`missionary_unlock_threshold`, `court_unlock_threshold`, `crusade_unlock_threshold`) and could emit dedicated signals when `faith_power` crosses each threshold. Alternatively, the Multi-path Expansion System could subscribe to `faith_power_changed` and do its own threshold checking. The current design does not specify which system owns threshold detection. Resolution: Multi-path Expansion System GDD must clarify the detection pattern. If GSM emits threshold signals, they should be added to the API section of this GDD before implementation.
