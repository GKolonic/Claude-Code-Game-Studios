# Save & Load System

> **Status**: In Design
> **Author**: Design session + agents
> **Last Updated**: 2026-04-26
> **Implements Pillar**: Pillar 3 — The Arc Must Feel Earned

## Overview

The Save & Load System is the persistence layer for The Faithful. It owns two responsibilities: serializing the complete village session state to a save file on the device's local filesystem, and deserializing that file to restore an identical session on next launch. The system writes a single save slot — one active session at a time — using Godot's `FileAccess` API to a JSON file in the `user://` virtual filesystem. It saves in exactly two circumstances: immediately after `DialogueConversionSystem.session_complete` fires (following any completed player conversation), and when the application receives an OS background notification (`NOTIFICATION_APPLICATION_PAUSED` on Android; `NOTIFICATION_WM_WINDOW_FOCUS_OUT` on iOS). The save payload is assembled from two sources: `GameStateManager` provides `get_turn_number()`, `get_faith_power()`, `get_gsm_state()`, and the `converted_ids` array; `NPCRegistry` provides its `serialize() → Dictionary` output. Each dependency system owns its own serialization logic; this system owns only the file write, the file read, and the restoration sequence. On load, the system deserializes the JSON payload, restores `GameStateManager` fields directly, and calls `NPCRegistry.deserialize(data)`. Two restoration rules resolve `GameStateManager` OQ-2: a save captured during `TURN_ADVANCING` restores as `IDLE` with `turn_number` unchanged (the turn is treated as having advanced — cooldowns already decremented); a save captured during `VILLAGE_WON` or `VILLAGE_LOST` re-triggers the GSM clear sequence on load rather than restoring a playable village state. The system holds no runtime state between save events — it is a stateless write/read utility that runs only when saving or loading. There is no manual save, no multiple save slots, and no cloud sync at MVP.

The system exists because mobile sessions are interrupted. A player mid-village on a commute has no guarantee of an uninterrupted session. Without the Save & Load System, every background or force-quit resets all conversion progress. With it, the question of "where was I?" never arises — the session resumes at the exact turn, NPC belief states, and faith power total the player left it.

## Player Fantasy

The Save & Load System is working when the player never thinks about it. The fantasy it enables is not a mechanic but a guarantee: the faith you built belongs to you. Close the app mid-conversation, receive a call, commute through a tunnel — none of it costs a turn. When you return, the widow is still wavering at exactly the threshold where you left her. The prophet is still standing in the same village, in the same moment, with the same open doors.

This is the persistence promise of a mobile game that asks for patience. The arc must feel earned, and an arc that can be arbitrarily reset by a phone call is not earned — it is interrupted. The Save & Load System is the silent guarantee behind every other system: what you build stays built.

## Detailed Design

### Core Rules

**1. Single auto-save slot.** One save file always at `user://faithful_save.json`. No manual save. No multiple slots. Every write overwrites the previous file. The file is either present (session to restore) or absent (no save — start fresh).

**2. Save triggers — three, in priority order.**

| Trigger | Signal / Hook | Timing |
|---|---|---|
| Post-conversation | `DialogueConversionSystem.session_complete` | `call_deferred("_execute_save")` — deferred one frame so GSM fully processes `session_complete` before state is read |
| OS background | `_notification(NOTIFICATION_APPLICATION_PAUSED)` (Android) / `NOTIFICATION_WM_WINDOW_FOCUS_OUT` (iOS) | Synchronous — fires immediately before OS may suspend the process |
| Terminal state | `GameStateManager.village_won` / `village_lost` | Synchronous — captures final state before the clear sequence runs |

Only one save executes per frame if triggers stack. The background save takes priority over a pending deferred post-conversation save.

**3. Save payload schema.**

```json
{
  "save_version": 1,
  "saved_at": "2026-04-26T14:33:00Z",
  "gsm": {
    "turn_number": 4,
    "faith_power": 30,
    "gsm_state": "IDLE",
    "converted_ids": ["village_01_elder_0", "village_01_merchant_1"]
  },
  "npc_registry": { "...": "opaque blob from NPCRegistry.serialize()" }
}
```

`npc_registry` is the verbatim `Dictionary` output of `NPCRegistry.serialize()`, JSON-encoded. Its internal schema is owned by the NPC Character System GDD. `SaveLoadSystem` does not inspect or validate its contents — it is passed through as an opaque blob on both save and load.

**4. Saving sequence.** When any save trigger fires:

```
1. If a deferred save is pending and a synchronous save fires: cancel the deferred save; proceed with synchronous.
2. Call GameStateManager.get_save_data() → Dictionary  [see Rule 8 — cross-system update]
3. Call NPCRegistry.serialize() → Dictionary
4. Assemble payload per schema (Rule 3). Set save_version = SAVE_VERSION_CURRENT constant.
   Set saved_at = Time.get_datetime_string_from_system(true) [UTC].
5. JSON.stringify(payload) → String.
6. FileAccess.open("user://faithful_save.json", FileAccess.WRITE) → handle.
7. If handle == null: log error "Save failed — cannot open file"; emit save_failed. Return.
8. ok = handle.store_string(json_string)  ← returns bool in Godot 4.4+
9. handle.close()
10. If not ok: log error "Save failed — write error"; emit save_failed. Return.
11. Emit save_completed.
```

**5. Loading sequence.** Called once at startup by the game boot sequence (not by `_ready()`):

```
1. If not FileAccess.file_exists("user://faithful_save.json"): emit load_not_found. Return (new game).
2. handle = FileAccess.open("user://faithful_save.json", FileAccess.READ)
3. If handle == null: log error; emit load_failed. Return.
4. raw = handle.get_as_text(); handle.close()
5. result = JSON.parse_string(raw)
6. If result == null or typeof(result) != TYPE_DICTIONARY: log error "Corrupt save"; emit load_failed. Return.
7. If result.save_version > SAVE_VERSION_CURRENT: log error "Save from future version"; emit load_failed. Return.
8. If result.save_version < SAVE_VERSION_CURRENT: run schema migration — _migrate_save(result, result.save_version).
9. Call NPCRegistry.deserialize(result.npc_registry)
10. Call GameStateManager.restore_from_save(result.gsm)  [see Rule 8 — cross-system update]
11. Emit load_completed(village_id)
```

**6. GSM state restoration rules.** `GameStateManager.restore_from_save(data)` applies these rules when interpreting the saved `gsm_state`:

| Saved State | Restored As | Reason |
|---|---|---|
| `IDLE` | `IDLE` | Stable state — restore directly. |
| `IN_SESSION` | `IDLE` | App killed during dialogue. Treat conversation as incomplete — NPC state was saved after previous `session_complete`. |
| `TURN_ADVANCING` | `IDLE` | Partial turn sequence. Treated as advanced — cooldowns already decremented in NPC state. `turn_number` not incremented (Step 8 may not have run). |
| `VILLAGE_WON` | triggers clear sequence | Re-trigger `village_clearing()` → `clear_village()` → `village_cleared()` on next frame. |
| `VILLAGE_LOST` | triggers clear sequence | Same as `VILLAGE_WON`. |
| `UNINITIALIZED` | `IDLE` + warn | Should never be saved. Log warning; attempt IDLE restore. |

**7. Schema versioning.** `SAVE_VERSION_CURRENT = 1` at MVP. The version integer increments whenever a field is added, removed, or renamed in the payload schema. `_migrate_save(data, from_version)` handles any `save_version < SAVE_VERSION_CURRENT` save. At MVP no migration exists (no version 0). The function exists as a no-op stub — the designated location for all future migration logic.

**8. Cross-system API additions required before implementation.**

*(a) GameStateManager GDD — add two methods to the API:*
- `get_save_data() -> Dictionary` — returns `{ "turn_number": int, "faith_power": int, "gsm_state": String, "converted_ids": Array[String] }` where `gsm_state` is the enum name as a String (e.g. `"IDLE"`)
- `restore_from_save(data: Dictionary) -> void` — applies Rule 6 restoration, restores all fields, transitions to the appropriate stable state, emits `village_ready(village_id)` or triggers the clear sequence

*(b) NPC Character System GDD — no API changes required.* `NPCRegistry.serialize()` and `deserialize()` are already defined. `deserialize()` must NOT emit `village_initialized` — restoration is complete when `restore_from_save()` emits `village_ready`.

**9. New game path.** If no save file is found at startup (`load_not_found` emitted), the game boot sequence calls `GameStateManager.initialize_village(npc_definitions)` via the normal path. No save is written until the first `session_complete` fires.

**10. No runtime state.** `SaveLoadSystem` is an Autoload singleton. It holds no session state between events — no "is saving" flag is needed (GDScript is single-threaded; the deferred-save mechanism prevents re-entrant writes naturally).

---

### States and Transitions

The Save & Load System is stateless between operations. Three informal phases:

| Phase | Trigger | Description |
|---|---|---|
| Startup load | Scene tree ready | Checks for save file; emits `load_completed`, `load_not_found`, or `load_failed` |
| Idle | — | Subscribed to triggers; no active processing |
| Saving | See Rule 2 | Synchronous or deferred write; emits `save_completed` or `save_failed` |

No persistent state variable is maintained between phases.

---

### Interactions with Other Systems

| System | Relationship | Interface |
|---|---|---|
| `DialogueConversionSystem` | Upstream — save trigger | Subscribes to `session_complete`. Defers save one frame after signal. |
| `GameStateManager` | Upstream — save source / load target | Save: calls `get_save_data()`. Load: calls `restore_from_save(data)`. Subscribes to `village_won`, `village_lost` for terminal-state saves. |
| `NPCRegistry` (NPC Character System) | Upstream — save source / load target | Save: calls `serialize() → Dictionary`. Load: calls `deserialize(data)`. |
| Village Map View | Downstream — load observer | Subscribes to `load_completed` to rebuild map visual state. |
| HUD & Progress System | Downstream — load observer | Subscribes to `load_completed` to refresh displayed faith power and turn count. |
| Audio System | Downstream — load observer | Subscribes to `load_completed` for correct ambient music state on restore. |
| Game Boot (SceneTree) | Orchestrator | Calls `SaveLoadSystem.load_game()` once at startup before village scenes are created. |

**Exposed API:**

```gdscript
# SaveLoadSystem (Autoload)

# Called once at boot by game initialization sequence
func load_game() -> void

# Signals
signal load_completed(village_id: String)   # load succeeded — downstream systems rebuild
signal load_not_found()                      # no save file — proceed as new game
signal load_failed()                         # file corrupt or unreadable — treat as new game
signal save_completed()                      # write succeeded
signal save_failed()                         # write failed — log only, do not interrupt gameplay

# Constants
const SAVE_VERSION_CURRENT: int = 1
const SAVE_FILE_PATH: String = "user://faithful_save.json"
```

## Formulas

The Save & Load System defines no mathematical formulas. It is a serialization/deserialization utility — its logic is conditional (file exists / does not exist, version matches / does not match) and sequential (assemble payload → write → close), not computational.

**Schema version comparison** — the only comparison used:

```
load_blocked = (result.save_version > SAVE_VERSION_CURRENT)
migrate_needed = (result.save_version < SAVE_VERSION_CURRENT)
current = (result.save_version == SAVE_VERSION_CURRENT)
```

No variables, no ranges, no balance values. All numeric parameters in this system (`turn_number`, `faith_power`, `converted_ids`) are owned by their source GDDs and serialized verbatim.

## Edge Cases

**EC-1 — Corrupt save (JSON parse fails).** `JSON.parse_string()` returns `null` or a non-Dictionary value. Log the error, emit `load_failed`, and proceed as a new game. The corrupt file is left on disk — the next `session_complete` or background save will overwrite it.

**EC-2 — Future save version detected.** `result.save_version > SAVE_VERSION_CURRENT`. The player downgrades the app after playing a newer version. Emit `load_failed`; treat as new game. Do not attempt to deserialize a schema the current code does not understand.

**EC-3 — Storage full during write.** `FileAccess.open()` returns `null` or `store_string()` returns `false`. Emit `save_failed`; gameplay continues without interruption. The previous save file remains intact (see EC-4 atomic write pattern). Log a warning: "Save failed — check device storage."

**EC-4 — OS kills process mid-write (partial file).** Direct overwrite risks a truncated file if the process dies between file open and close. Resolution: write to `user://faithful_save_tmp.json` first, then rename to `user://faithful_save.json` using `DirAccess.rename()`. If the process dies before rename, the old save is intact and the temp file is orphaned. Temp file cleanup at startup: if `faithful_save_tmp.json` exists and `faithful_save.json` does not, attempt to read the temp file as a recovery path. If both exist, delete the temp file.

**EC-5 — `NPCRegistry.deserialize()` fails.** If `deserialize()` returns partial or corrupt NPC state, the session is unplayable. After the call, validate by checking `NPCRegistry.get_all_npcs()` — if empty after deserialization of a non-empty save, emit `load_failed` and leave the save file intact. In debug builds, push an assertion failure.

**EC-6 — `converted_ids` references non-existent NPC IDs.** Possible if the village scene definition changes between app versions. After `NPCRegistry.deserialize()`, validate that all IDs in `gsm_data.converted_ids` exist in `NPCRegistry.get_all_npcs()`. Remove any stale IDs and log a warning per removed ID. Faith power is not retroactively corrected — awards are permanent, but the win-condition count reflects only valid IDs.

**EC-7 — Background save fires before any `session_complete`.** Player opens the app, does nothing, backgrounds it. GSM state is `IDLE`, turn 0, faith power 0, NPC registry in initial state. This is a valid save — captures initial state correctly. On reload, the initial village is restored. No special handling needed.

**EC-8 — `load_game()` called more than once.** Guarded by an `_is_loaded: bool` flag initialized to `false`. On second call, log a warning and return immediately. Only the first call at startup executes the load sequence.

**EC-9 — Background notification fires while a deferred post-conversation save is pending.** The synchronous background save completes and clears `_deferred_save_pending`. When the deferred frame executes, it checks the flag — false — and no-ops. One save fires. The background save captures the same or more recent state.

**EC-10 — `village_won` or `village_lost` fires while a deferred save is pending.** The terminal state save fires synchronously, capturing the WIN/LOST state. The deferred save is cancelled. The terminal save always takes precedence.

## Dependencies

### Systems This System Depends On

| System | GDD | Type | Interface |
|---|---|---|---|
| Game State Manager | `game-state-manager.md` | **Hard** | Save: `get_save_data() → Dictionary`. Load: `restore_from_save(data: Dictionary)`. Subscribes to: `village_won`, `village_lost`. Cross-system update required (Rule 8a): both methods must be added to the GSM GDD before implementation. |
| NPC Character System | `npc-character-system.md` | **Hard** | Save: `NPCRegistry.serialize() → Dictionary`. Load: `NPCRegistry.deserialize(data: Dictionary)`. Both methods already defined in the NPC Character System GDD API. |
| Dialogue & Conversion System | `dialogue-conversion-system.md` | **Hard** (trigger only) | Subscribes to `session_complete` signal as the post-conversation save trigger. Never calls any DCS method. |

### Systems That Depend On This System

| System | GDD | What It Uses |
|---|---|---|
| Village Map View | *(GDD pending)* | Subscribes to `load_completed` to rebuild map visual state after a session restore. |
| HUD & Progress System | *(GDD pending)* | Subscribes to `load_completed` to refresh faith power and turn count displays. |
| Audio System | *(GDD pending)* | Subscribes to `load_completed` for correct ambient music state on restore. |
| Tutorial & Onboarding | *(GDD pending)* | Subscribes to `load_not_found` to know this is a first-time session requiring onboarding. |

### Architectural Note — Autoload Initialization Order

`SaveLoadSystem` must be initialized after `NPCRegistry` and `GameStateManager` in Project Settings, because `load_game()` calls both `NPCRegistry.deserialize()` and `GameStateManager.restore_from_save()` — both Autoloads must be present before `load_game()` executes.

**Required order:** `NPCRegistry` → `GameStateManager` → `DialogueConversionSystem` → `SaveLoadSystem`

## Tuning Knobs

The Save & Load System has no gameplay-facing tuning knobs. It is a deterministic utility. The one developer-facing constant:

| Constant | Value | When to Change |
|---|---|---|
| `SAVE_VERSION_CURRENT` | 1 | Increment whenever the save payload schema changes (field added, removed, or renamed). Never decrement. Triggers the migration path for older saves. |

There are no balance values, no rate controls, and no difficulty modifiers. Save frequency is determined by game events (`session_complete`, OS background notification, terminal state signals) — not by a timer or configurable interval.

## Visual/Audio Requirements

The Save & Load System produces no visual or audio output. It operates silently. Downstream systems react to its signals (`load_completed`, `load_not_found`, `load_failed`, `save_failed`) — any player-facing indication of load failure or save failure is owned by those systems, not by this one.

No assets are owned or required by this system.

## UI Requirements

The Save & Load System has no UI of its own. It emits signals that UI systems may observe:

- `load_failed` — the HUD or a modal dialog may inform the player that the save could not be loaded (they start a new game). Exact UI form is defined by the relevant UI GDD.
- `save_failed` — optionally surfaced as a transient notification ("Could not save — check device storage"). Not required at MVP; log-only is sufficient for the first milestone.

This system does not display progress indicators, spinners, or any loading screen. On mobile, saves complete in under 16ms and are imperceptible.

## Acceptance Criteria

**AC-01 — New game on missing save.** On first launch with no save file at `user://faithful_save.json`, `load_game()` emits `load_not_found` and does not emit `load_completed` or `load_failed`. The game initializes via the normal `initialize_village()` path.

**AC-02 — Round-trip fidelity.** Given a village at turn 5, faith power 40, two CONVERTED NPCs with specific `belief_state`, `cooldown_turns_remaining`, `approach_count`, and `revealed_traits` values: after one save-load cycle, all field values are identical to pre-save state. *(Integrates with NPC Character System AC-18.)*

**AC-03 — Post-conversation auto-save.** After `DialogueConversionSystem.session_complete` fires, a save executes on the following frame. `save_completed` is emitted. The saved file's `gsm_state` field equals `"IDLE"` — the GSM has settled before the deferred write executes.

**AC-04 — Background save fires synchronously.** When `NOTIFICATION_APPLICATION_PAUSED` (Android) or `NOTIFICATION_WM_WINDOW_FOCUS_OUT` (iOS) is received, `_execute_save()` runs synchronously in the same notification handler. `save_completed` or `save_failed` fires before the handler returns.

**AC-05 — TURN_ADVANCING restoration.** Given a save file with `gsm_state = "TURN_ADVANCING"` and `turn_number = 3`, after `load_game()`, `GameStateManager.get_gsm_state()` returns `IDLE` and `get_turn_number()` returns `3`. NPC cooldowns reflect the already-decremented values from the save.

**AC-06 — VILLAGE_WON restoration.** Given a save file with `gsm_state = "VILLAGE_WON"`, after `load_game()`, the GSM clear sequence fires: `village_clearing` → `clear_village()` → `village_cleared`. `load_completed` is not emitted; the player proceeds through the win resolution flow.

**AC-07 — Corrupt save handled gracefully.** Given a save file containing invalid JSON, `load_game()` emits `load_failed` and does not crash. `load_completed` is not emitted. The game initializes as a new game.

**AC-08 — Future version rejected.** Given a save file with `save_version = 99`, `load_game()` emits `load_failed` without attempting deserialization.

**AC-09 — Storage full does not crash.** Given no available device storage, a save trigger fires. `save_failed` is emitted. Gameplay continues. The previous save file is not corrupted — the atomic write (temp file + rename) ensures the old file remains intact until the rename completes.

**AC-10 — Stale converted_ids cleaned.** Given a save file whose `converted_ids` includes an NPC ID not present in the deserialized `NPCRegistry`, that ID is removed from `converted_ids` after load. The stale ID does not appear in `get_save_data().converted_ids` post-load.

**AC-11 — `load_game()` idempotent.** Calling `load_game()` a second time logs a warning and returns immediately. GSM and NPCRegistry state are unchanged by the second call.

**AC-12 — Terminal state save captures final state.** When `village_won` fires, the save is written synchronously before the clear sequence begins. The saved `gsm_state` is `"VILLAGE_WON"`, not `"UNINITIALIZED"`.

**AC-13 — Autoload order enforced.** In an integration test, `load_game()` called during `SaveLoadSystem._ready()` can call `NPCRegistry.deserialize()` and `GameStateManager.restore_from_save()` without null-reference errors — confirming NPCRegistry and GSM are initialized first.

## Open Questions

**OQ-01 — `load_completed(village_id)` — source of village ID.** The `load_completed` signal carries a `village_id` parameter. At MVP there is one village and the ID is fixed, but the signal contract must be established before implementation. Two options: (a) `village_id` is embedded in the GSM save payload as a new field in `get_save_data()`; (b) `village_id` is derived from the first NPC's ID prefix after deserialization (e.g., `"village_01_elder_0"` → `"village_01"`). Option (a) requires adding `village_id` to the GSM cross-system update (Rule 8a). Resolve before implementing the load sequence.

**OQ-02 — `load_game()` call site.** The GDD specifies that `load_game()` is called "once at startup by the game boot sequence," but no boot scene or boot system is currently defined. Resolve: does `SaveLoadSystem._ready()` call `load_game()` itself (simplest, but means all Autoloads must be ready before `_ready()` runs), or does a dedicated boot scene call it after scene setup completes? The latter is safer but requires a boot scene. Resolve before architecture review.

**OQ-03 — `delete_save()` for new-game reset.** At MVP there is no in-game "new game" or "erase data" flow. If a settings screen or main menu needs this, a `delete_save() -> void` method should be added to `SaveLoadSystem`. Defer to when a settings or main menu GDD is authored.

**OQ-04 — Multi-village save format post-MVP.** The current single-slot format holds one village state. Post-MVP, the game will have multiple villages at different completion stages. Moving from one village blob to a map of village states plus a current-village pointer is the primary schema migration risk. Flag for the Region & World Map System GDD — that GDD should specify multi-village state shape, and this GDD will need a `save_version = 2` migration at that time.
