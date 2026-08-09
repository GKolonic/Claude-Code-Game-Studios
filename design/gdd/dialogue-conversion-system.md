# Dialogue & Conversion System

> **Status**: Complete
> **Author**: Design session + agents
> **Last Updated**: 2026-04-25
> **Implements Pillar**: Pillar 1 — Every Soul Has a Story; Pillar 2 — Many Roads to the Divine; Pillar 4 — History Writes Itself

## Overview

The Dialogue & Conversion System is the orchestration layer that transforms a player's tap on an NPC into a complete conversion exchange — from approach selection through outcome resolution to the narrative line that explains what just happened. It reads the approachable NPC list from `NPCRegistry`, presents the four canonical dialogue approaches to the player, calls `ConversionLogicEngine.resolve()` to determine the outcome, applies that outcome and any trait reveal to `NPCRegistry`, then retrieves the appropriate dialogue and outcome lines from `DialogueDatabase` using a per-NPC and per-archetype recency system that prevents repetition. It holds the only runtime state the conversion loop requires: the current session's NPC target, chosen approach, and the line-selection history used to avoid showing the same text twice. It writes to `NPCRegistry`; everything else it reads from.

The system exists because the four Autoloads it coordinates are each purposefully stateless or narrowly scoped — without this layer, the call sequence from player tap to outcome has no owner, no gating, and no guarantee that `apply_conversion_outcome()` is always called after `resolve()`. It is also the enforcer of approachability: no approach reaches `ConversionLogicEngine` unless `NPCRegistry.get_approachable_npcs()` confirms the NPC is eligible. Experienced as a player, the Dialogue & Conversion System is the voice of every conversion: the prophet's words, the held moment before the outcome, the NPC's response, and the single hidden truth revealed about who they are. Every character moment in the game flows through it.

## Player Fantasy

The Dialogue & Conversion System exists to deliver one experience: the moment a player taps an approach button and leans forward. Not because the mechanic is interesting, but because the person across from them is.

This system is the interface between the player and every soul in the village. When it works, the player feels the weight of each conversation before they speak: *this person has a life I know only in outline, and I am about to ask them to change the deepest thing about themselves.* That is the fantasy — not the power of a prophet with an empire behind them, but the intimacy of a prophet with nothing yet, who must win one person at a time. Every conversion is both a small miracle and a small theft. The player is asking a stranger to leave behind what their parents believed, what their village agreed upon, what comforted them at funerals. The system must make that weight felt every time — on the first NPC in the first village and on the hundredth NPC in the hundredth.

The system succeeds when a player pauses before selecting GRIEF and asks themselves: *is this the right thing to say to her?* It succeeds when a SOFTENED outcome lands and the player thinks *she almost let me in* rather than *I rolled badly.* It succeeds when a HARDENED outcome produces a specific human failure — *I misjudged him* — rather than a mechanical setback. It fails the moment a player stops thinking about the person and starts thinking about the probability.

The four approach buttons are not a menu. They are the four things a prophet can offer a stranger: shared suffering, a better future, a harder question, or a truth neither of them wants to say aloud. The system's sole obligation is to make choosing between them feel like choosing what to say to a real person — slowly, with conviction, knowing you only get a few chances.

## Detailed Design

### Core Rules

**1. A session is exactly one approach attempt.** Each tap on an approachable NPC portrait begins one session. The session runs from NPC selection to outcome display and ends when the player is returned to the village map. To attempt a second approach on the same NPC (if not yet at `max_approaches_per_npc` and after the cooldown expires), the player must re-tap from the map. A session cannot contain multiple approach attempts.

**2. Approachability is gated before any UI is shown.** On NPC tap, the system calls `NPCRegistry.get_approachable_npcs()` and confirms the tapped NPC appears in the returned list before opening the approach selection screen. Non-approachable NPC portraits on the village map have their tap targets disabled by the Conversion UI; this check is a defense, not a primary gate. If the check fails (tapped NPC not approachable), the session does not begin and no state changes.

**3. Session sequence — full step-by-step flow:**

```
Step 1: Player taps NPC portrait on village map
         → Verify approachable (NPCRegistry.get_approachable_npcs())
         → Verify DialogueDatabase.is_loaded()
         → Store npc_id in session state
         → State: IDLE → APPROACH_SELECTION

Step 2: Approach selection screen opens
         → Call NPCRegistry.get_npc(npc_id) — reads archetype, revealed_traits,
           assigned_traits.size(), belief_state
         → Compute approach alignment signal per approach (Rule 5)
         → Display: NPC portrait, display_name, archetype, revealed trait cards,
           [N traits hidden] count, 4 approach buttons (with alignment signal),
           Inspect button (if hidden traits remain)

Step 3 (optional): Player taps Inspect button
         → Call NPCRegistry.trigger_inspect_reveal(npc_id)
         → Revealed trait card animates in; hidden count decrements
         → Player remains in APPROACH_SELECTION; may inspect again if traits remain
           (each inspect call reveals one trait)
         → If player backs out without selecting an approach → State: SESSION_COMPLETE
           (inspect reveals are permanent — they are NOT reverted on cancel)

Step 4: Player taps an approach button
         → Store chosen DialogueApproach in session state
         → State: APPROACH_SELECTION → APPROACH_CONFIRMED

Step 5: Prophet speaks — brief beat (held breath)
         → Portrait shifts to a "considering" or listening expression
         → Approach category label shown briefly (e.g., "You speak to her grief")
         → Hold: UITimingConfig.approach_confirm_hold_sec (tuning knob — see §Tuning Knobs)
         → No content retrieved yet; the player sits with their choice

Step 6: Approach line displayed
         → Call DialogueDatabase.get_approach_lines(approach)
         → Apply per-NPC per-approach recency selection (Rule 6) → select one line
         → Display the approach line (the prophet's words)
         → Hold: UITimingConfig.dialogue_line_hold_sec
         → State: APPROACH_CONFIRMED → LINE_DISPLAYING

Step 7: Outcome resolved (the Engine call)
         → Write pending-session save record: { npc_id, approach, status: "pending" }
         → Call ConversionLogicEngine.resolve(approach, npc_id) → returns ConversionOutcome
         → State: LINE_DISPLAYING → RESOLVING

Step 8: Outcome applied — the finally block
         → IMMEDIATELY call NPCRegistry.apply_conversion_outcome(npc_id, outcome, approach)
         → This call is treated as a finally block. It CANNOT be skipped under any
           condition. It updates belief_state, cooldown_turns_remaining, approach_count,
           and approach_history. The npc_state_changed signal fires if belief state changed.
         → Update pending-session record: { status: "resolved" }
         → State: RESOLVING → OUTCOME_DISPLAY

Step 9 — NORMAL PATH (PERSUADED / SOFTENED / RESISTED):
         → Call DialogueDatabase.get_outcome_summary(approach, outcome)
         → Apply per-NPC per-(approach, outcome) recency selection → select one line
         → Display outcome summary line (what the NPC did)
         → Hold: UITimingConfig.outcome_display_hold_sec
         → If outcome != RESISTED: call NPCRegistry.reveal_trait(npc_id, approach)
           → NPCRegistry identifies and reveals the highest-affinity hidden trait for
             the approach used; emits trait_revealed signal
           → Revealed trait card animates in AFTER the outcome line has displayed
           → If all traits already revealed: no-op

Step 9 — HARDENED PATH:
         → Call NPCRegistry.reveal_trait(npc_id, approach) FIRST
           → Trait card animates in (what you misread about this person)
         → Hold: UITimingConfig.hardened_reveal_hold_sec
         → Call DialogueDatabase.get_outcome_summary(approach, HARDENED)
         → Apply recency selection → select one line
         → Display outcome summary line (what it cost you)
         → Hold: UITimingConfig.outcome_display_hold_sec

Step 10: Session complete
         → Clear per-session state (npc_id, chosen approach)
         → Clear pending-session save record
         → Recency state (Rule 6) persists for the village's lifetime
         → Emit session_complete signal
         → State: OUTCOME_DISPLAY → SESSION_COMPLETE → IDLE
         → Control returned to village map
```

**4. Inspect is available during approach selection only.** The Inspect action — which calls `NPCRegistry.trigger_inspect_reveal(npc_id)` — is available while the player is in `APPROACH_SELECTION`. It is not available once the player has tapped an approach button. Inspect reveals are permanent regardless of whether the player proceeds with an approach or cancels the session.

**5. Approach alignment signal — grey out based on revealed traits only.** Before displaying the approach selection screen, the system computes an `AlignmentSignal` for each of the four approaches using only the NPC's `revealed_traits`. The signal drives visual de-emphasis on the approach buttons (greyed appearance for NEGATIVE); all four buttons remain tappable.

```
AlignmentSignal enum: POSITIVE | NEUTRAL | NEGATIVE

For each approach:
  net_affinity = sum of TraitDatabase.get_affinity(trait_id, approach)
                 for each trait_id in npc.revealed_traits
  if net_affinity > 0.0:  → POSITIVE
  if net_affinity < 0.0:  → NEGATIVE
  else:                   → NEUTRAL
```

**Critical constraint:** alignment signal computation uses ONLY `revealed_traits`. It must NEVER access `assigned_traits` or call `ConversionLogicEngine` — doing so would surface information derived from hidden traits, eliminating the incentive to inspect.

**6. Line selection — recency tracking (W = 2).** The system owns three categories of persistent recency state, all saved with the village:

| State | Key | Scope | Minimum pool to work correctly |
|---|---|---|---|
| Approach lines | `[npc_id][approach] → Array[int]` — last 2 indices shown | Per-NPC, per-approach | L_approach = 3 (pool size) > W = 2 ✓ |
| Outcome lines | `[npc_id][(approach, outcome)] → Array[int]` | Per-NPC, per approach–outcome pair | L_outcome = 3 > W = 2 ✓ |
| Inspect lines | `[archetype] → Array[int]` | Per-archetype (not per-NPC) | L_inspect = 3 > W = 2 ✓ |

Selection algorithm (same for all three pools):
```
eligible = [0, 1, 2] minus recent[key]
chosen = eligible[rng.randi_range(0, eligible.size() - 1)]
recent[key].append(chosen)
if recent[key].size() > W: recent[key].pop_front()
```

Inspect line recency is keyed per archetype, not per NPC — because multiple NPCs of the same archetype share the same inspect line pool, the last-shown line must be excluded across all encounters with any NPC of that archetype, per Dialogue Content Database EC-10.

**7. Approach count is never shown as a number.** The system does not surface `approach_count` numerically to the player. When `approach_count == max_approaches_per_npc - 1` (one approach remaining), the Conversion UI signals this through observable character cues — not a counter. Exact cue form is a UX system decision; this system exposes `approach_count` for downstream UI reads but does not dictate how it is displayed.

**8. Turn advancement is the Game State Manager's responsibility.** This system does not call `NPCRegistry.advance_turn()` and does not own turn pacing. After a session completes, the player returns to the village map and may initiate further sessions. The Game State Manager advances the turn when the player signals end-of-turn or when `get_approachable_npcs()` returns an empty list.

**9. Session safety — mid-session exit handling.** Before calling `ConversionLogicEngine.resolve()` (Step 7), the system writes a pending-session record to the save file: `{ npc_id, approach, status: "pending" }`. After `apply_conversion_outcome()` completes (Step 8), the record is updated to `{ status: "resolved" }`. On game resume, if a pending-session record is found with `status: "pending"`, the system calls `NPCRegistry.apply_conversion_outcome(npc_id, RESISTED, approach)` as a safe sentinel — RESISTED produces no belief state change and no trait reveal, and the player cannot benefit from a force-quit. The player is returned to the map with no dialogue displayed.

---

### States and Transitions

| State | Valid Transitions | Trigger |
|---|---|---|
| `IDLE` | → `APPROACH_SELECTION` | Player taps approachable NPC; approachability confirmed |
| `IDLE` | (stays `IDLE`) | Player taps non-approachable NPC (defense check) |
| `APPROACH_SELECTION` | → `APPROACH_CONFIRMED` | Player taps an approach button |
| `APPROACH_SELECTION` | → `IDLE` | Player cancels / backs out before selecting approach |
| `APPROACH_SELECTION` | (stays) | Player taps Inspect button — trait revealed, state stays |
| `APPROACH_CONFIRMED` | → `LINE_DISPLAYING` | `approach_confirm_hold_sec` elapses; approach line selected and shown |
| `LINE_DISPLAYING` | → `RESOLVING` | `dialogue_line_hold_sec` elapses |
| `RESOLVING` | → `OUTCOME_DISPLAY` | `ConversionLogicEngine.resolve()` returns; `apply_conversion_outcome()` called |
| `RESOLVING` | (no exit except `OUTCOME_DISPLAY`) | Cannot be cancelled; resolve→apply is atomic |
| `OUTCOME_DISPLAY` | → `SESSION_COMPLETE` | Outcome hold elapses (normal: `outcome_display_hold_sec`; HARDENED: `hardened_reveal_hold_sec` + `outcome_display_hold_sec`) |
| `SESSION_COMPLETE` | → `IDLE` | Session state cleared; control returned to map |

---

### Interactions with Other Systems

| System | Relationship | Calls Made |
|---|---|---|
| `NPCRegistry` (NPC Character System) | Upstream — reads and mutates NPC state | `get_approachable_npcs()`, `get_npc(npc_id)`, `apply_conversion_outcome(npc_id, outcome, approach)`, `reveal_trait(npc_id, approach)` *, `trigger_inspect_reveal(npc_id)` |
| `ConversionLogicEngine` | Upstream — pure outcome resolver | `resolve(approach, npc_id)` — called exactly once per session |
| `DialogueDatabase` | Upstream — read-only content | `is_loaded()`, `get_approach_lines(approach)`, `get_outcome_summary(approach, outcome)` |
| `TraitDatabase` | Upstream — trait affinity for alignment signal only | `get_affinity(trait_id, approach)` — over `revealed_traits` only; never over hidden traits |
| `GameConfig` / `UITimingConfig` | Upstream — timing values | `approach_confirm_hold_sec`, `dialogue_line_hold_sec`, `outcome_display_hold_sec`, `hardened_reveal_hold_sec` |
| `Conversion UI` | Downstream — presentation layer | Consumes signals; calls `begin_session()`, `select_approach()`, `trigger_inspect()`, `cancel_session()`, `get_approach_alignment()` |
| `Game State Manager` | Peer — owns turn lifecycle | Subscribes to `session_complete` signal; calls `NPCRegistry.advance_turn()` at end of player turn |
| `Rival Faith System` | Peer — same NPCRegistry caller | Both call `apply_conversion_outcome()`; each runs its own session flow independently |
| `Save & Load System` | Downstream — persistence | Must serialize recency state (approach lines, outcome lines, inspect lines) and pending-session record |
| `Audio System` | Downstream — reacts to outcomes | Subscribes to `outcome_resolved(outcome)` signal for music cues |

*`reveal_trait(npc_id: String, approach: DialogueApproach)` — updated API. NPCRegistry determines the correct trait internally by querying TraitDatabase for the highest-affinity hidden trait. The NPC Character System GDD must be updated to reflect this signature change before implementation begins.

**Exposed API:**
```gdscript
# DialogueConversionSystem (Autoload singleton)

# Commands (called by Conversion UI)
func begin_session(npc_id: String) -> void
func select_approach(approach: DialogueApproach) -> void
func trigger_inspect() -> void       # only valid in APPROACH_SELECTION state
func cancel_session() -> void        # only valid in APPROACH_SELECTION state

# Queries (called by Conversion UI to build approach buttons)
func get_approach_alignment(npc_id: String, approach: DialogueApproach) -> AlignmentSignal

# Signals
signal session_begun(npc_id: String)
signal approach_line_ready(line: String)
signal outcome_resolved(outcome: ConversionOutcome, summary_line: String, revealed_trait_id: String)
signal session_complete()
signal trait_inspected(trait_id: String)
```

## Formulas

### Formula 1 — Approach Alignment Signal

```
net_affinity(a) = Σ TraitDatabase.get_affinity(tᵢ, a)
                  for each tᵢ in npc.revealed_traits

AlignmentSignal(a) =
  POSITIVE  if net_affinity(a) > 0.0
  NEGATIVE  if net_affinity(a) < 0.0
  NEUTRAL   otherwise (including net_affinity = 0.0 and R = 0)
```

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `tᵢ` | Revealed trait ID | String | element of `npc.revealed_traits` | One revealed trait ID, passed to `TraitDatabase.get_affinity()` |
| `A(tᵢ, a)` | Trait–approach affinity | float | {-1.0, -0.5, 0.0, +0.5, +1.0} | Affinity of trait `tᵢ` for approach `a`. Returns 0.0 for unknown inputs per NPC Trait Database API contract |
| `R` | Revealed trait count | int | [0, 4] | `npc.revealed_traits.size()`. Zero is valid — sum over empty set = 0.0 → all four approaches return NEUTRAL, no special case required |
| `net_affinity` | Net affinity for approach | float | [-4.0, +4.0] in 0.5 increments | Sum of per-trait affinities for approach `a` over revealed traits. Magnitude is unused — only sign matters |
| `a` | Approach | DialogueApproach | {GRIEF, AMBITION, DOUBT, FEAR} | The approach whose signal is being computed |
| `AlignmentSignal` | Output signal | enum | {POSITIVE, NEUTRAL, NEGATIVE} | Visual hint for approach button de-emphasis in the Conversion UI |

**Output range:** `AlignmentSignal` ∈ {POSITIVE, NEUTRAL, NEGATIVE}. The threshold is a strict sign comparison — no dead zone. A dead zone would corrupt the player's ability to infer trait-approach relationships from revealed information, undermining the prophet-as-reader fantasy.

**Dependency assumption:** `TraitDatabase.get_affinity(trait_id, approach)` returns 0.0 for any unknown `trait_id` (per NPC Trait Database Rule 7). If a trait ID in `revealed_traits` no longer exists in TraitDatabase (patch-desync), the formula degrades cleanly — the unknown trait contributes 0.0 and does not distort the signal.

**Dynamic recomputation after inspect:** The Conversion UI must call `get_approach_alignment()` after each inspect reveal (Step 3 in the session flow). The method reads `revealed_traits` at call time, so it automatically reflects any newly revealed trait. The signal is not cached between calls. If the UI does not recompute after inspect, approach buttons will show stale alignment signals for the remainder of the session.

**Worked example — NPC with two revealed traits:** `bereaved` (GRIEF +1.0, FEAR -0.5) and `proud` (GRIEF -0.5, FEAR 0.0):

| Approach | bereaved | proud | net_affinity | Signal |
|---|---|---|---|---|
| GRIEF | +1.0 | -0.5 | +0.5 | POSITIVE |
| AMBITION | 0.0 | 0.0 | 0.0 | NEUTRAL |
| DOUBT | 0.0 | 0.0 | 0.0 | NEUTRAL |
| FEAR | -0.5 | 0.0 | -0.5 | NEGATIVE |

---

### Formula 2 — Recency Line Selection

```
eligible(key) = {0, 1, ..., L-1} \ set(recent[key])

chosen = eligible[rng.randi_range(0, eligible.size() - 1)]

recent[key].append(chosen)
if recent[key].size() > W:
    recent[key].pop_front()
```

**Invariant:** `L > W` must hold for `eligible` to be non-empty. At defaults (L=3, W=2), `eligible.size()` ∈ [1, 3] — minimum 1 guaranteed candidate.

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `L` | Pool size | int | ≥ W+1; L=3 at MVP | Number of lines in the dialogue pool for this slot |
| `W` | Recency window | int | 2 (unified across all pool types) | Number of most-recently-shown line indices excluded from selection |
| `recent[key]` | Recency history | Array[int] | size ∈ [0, W]; elements ∈ [0, L-1] | Sliding window of the last W line indices shown for this key. Oldest entry at index 0. Initialized to `[]` on first access — null is not a valid initial state |
| `eligible` | Candidate indices | Set[int] | size ∈ [L-W, L]; minimum 1 | Pool indices not in `recent[key]`; always non-empty when L > W |
| `chosen` | Selected index | int | [0, L-1] | Index into the dialogue pool array |
| `key` | Recency scope key | typed | see pool table below | Scoping key for recency state lookup |

**Pool key definitions:**

| Pool | Key Type | Scope |
|---|---|---|
| Approach lines | `(npc_id: String, approach: DialogueApproach)` | Per-NPC, per-approach |
| Outcome lines | `(npc_id: String, approach: DialogueApproach, outcome: ConversionOutcome)` | Per-NPC, per approach–outcome pair |
| Inspect lines | `archetype: NPCArchetype` | Per-archetype (shared across all NPCs of that archetype in this village) |

**Recency state lifetime:** All three recency pools are scoped to the current village. When the Game State Manager emits the `village_cleared` signal (this system subscribes), this system's recency state is reset to empty. Recency does not persist across villages or playthroughs — each new village starts with a clean selection history.

**Defensive rule — empty eligible:** If `eligible.is_empty()` (L ≤ W invariant violation — bad data or save corruption), clear `recent[key]` and select from the full pool `{0, 1, ..., L-1}` uniformly. Log a warning. Never crash or return an out-of-range index.

**Output range:** `chosen` ∈ [0, L-1]. Deterministic for a fixed RNG seed.

**Worked example** — Approach GRIEF, `npc_id = village1_widow_1`, `L = 3`, `W = 2`, prior history `[1, 0]`:

```
recent[(village1_widow_1, GRIEF)] = [1, 0]
eligible = {0, 1, 2} \ {1, 0} = {2}
chosen = 2
recent → append 2 → [1, 0, 2]; size 3 > W 2 → pop_front → [0, 2]
```

Next call: `eligible = {0, 1, 2} \ {0, 2} = {1}` → forced selection of index 1. Anti-repeat pattern cycles all three lines with no consecutive repeats.

## Edge Cases

**EC-1. Player taps a non-approachable NPC.**
Session does not begin. `get_approachable_npcs()` check fails. No state change, no UI transition. Tap targets for non-approachable NPCs should be disabled by the Village Map View — this is a defense, not the primary gate.

**EC-2. `DialogueDatabase.is_loaded()` returns false at session start.**
System logs an error; session does not begin; player stays on map. A false `is_loaded()` is a startup blocker that should have been caught before the village map is reachable. If somehow reached, no content call is made and no session state is set.

**EC-3. Player cancels session after using Inspect.**
The inspect reveal via `trigger_inspect_reveal()` is permanent. Cancellation from `APPROACH_SELECTION` does not revert it. The NPC's `revealed_traits` contains the newly revealed trait; the player returns to the map with that information. Inspect is not contingent on completing an approach.

**EC-4. All traits revealed before Inspect is tapped.**
`trigger_inspect_reveal()` is a no-op (NPC Character System E10). The Inspect button should not be visible if `revealed_traits.size() == assigned_traits.size()`. If the UI shows it incorrectly, the call is safe — it returns without mutation.

**EC-5. Non-RESISTED outcome when all traits are already revealed.**
`reveal_trait(npc_id, approach)` is a no-op (NPC Character System E10). Normal path: outcome line plays; no trait card animation. HARDENED path exception: the HARDENED display path leads with the trait reveal. If all traits are already revealed, the HARDENED path has nothing to show first — it falls back to the normal display path (outcome line only, no trait reveal prefix).

**EC-6. Mid-session device exit between `resolve()` and `apply_conversion_outcome()`.**
Pending-session record was written before Step 7 with `status: "pending"`. On resume: apply `NPCRegistry.apply_conversion_outcome(npc_id, RESISTED, approach)` as a sentinel, clear the record, return player to map. No trait reveal, no dialogue displayed. The player cannot benefit from force-quitting.

**EC-7. Stale pending-session record found when a new session begins.**
If a pending-session record exists when `begin_session()` is called, the system processes the stale record first. `status: "pending"` → apply RESISTED sentinel for the stale NPC, clear record. `status: "resolved"` → apply already happened but cleanup didn't complete; clear record only. Then begin the new session normally.

**EC-8. HARDENED outcome on a STEADFAST NPC.**
NPC Character System E5: STEADFAST is the floor; belief state does not regress. `approach_count` and `cooldown_turns_remaining` still update. The HARDENED display path still fires — trait revealed first (what you misread), then the outcome line. The HARDENED narrative beat plays even though no state regressed: the NPC showed resistance, and the player learns something about them.

**EC-9. Double-tap on an approach button after APPROACH_CONFIRMED.**
Once state transitions to `APPROACH_CONFIRMED`, `select_approach()` is a no-op. The Conversion UI should disable approach buttons immediately after one is tapped; this is a defense against lag-tap scenarios.

**EC-10. Zero revealed traits — all four AlignmentSignals are NEUTRAL.**
This is the starting state of every NPC. The formula degrades cleanly (empty sum = 0.0 → NEUTRAL, no special case). All four approach buttons appear equally weighted. Inspect button is visible if hidden traits remain. This is correct — the player must inspect to gain alignment guidance.

**EC-11. `recent[key]` is null in deserialized save data.**
Any recency key with a null value is treated as `[]` on first access and a warning is logged. Null-checking on deserialization is mandatory — calling `set(null)` in GDScript will crash.

**EC-12. Recency pool drops below L > W invariant after a content change.**
If a pool is reduced to L=2 while W=2, `eligible` would be empty. The defensive rule fires: clear `recent[key]`, select from the full pool, log a warning. Not reachable in correctly built content — the Dialogue Content Database sets `is_loaded() = false` for under-filled pools.

**EC-13. `begin_session()` called while a session is already active.**
If state is not `IDLE`, `begin_session()` is a no-op and logs a warning. The system is not re-entrant. The Conversion UI must not allow a second NPC tap during an active session.

**EC-14. Single-archetype village (all NPCs share the same archetype).**
Inspect recency is per-archetype and shared across all NPCs of the same type. In a village of all-Widow NPCs, the inspect line rotation is shared — no two consecutive inspected NPCs show the same line. This is correct behavior per Dialogue Content Database EC-10.

**EC-15. `select_approach()` or `trigger_inspect()` called before `begin_session()`.**
Called while state is `IDLE`. Both are no-ops and log warnings. No session state is set, no NPCRegistry calls are made.

## Dependencies

### Systems This System Depends On

| System | GDD | Dependency |
|---|---|---|
| NPC Character System | `npc-character-system.md` | Provides `NPCRegistry` — full NPC query and mutation API. Hard dependency: `get_approachable_npcs()`, `get_npc()`, `apply_conversion_outcome()`, `reveal_trait(npc_id, approach)` [updated signature — see note], `trigger_inspect_reveal()`. Without NPCRegistry, no session can begin or complete. **API update required:** `reveal_trait()` must change from `(npc_id, trait_id)` to `(npc_id, approach)` so NPCRegistry determines the correct trait internally. NPC Character System GDD must be updated before implementation. |
| Conversion Logic Engine | `conversion-logic-engine.md` | Provides `ConversionLogicEngine.resolve(approach, npc_id) -> ConversionOutcome`. Hard dependency. The Engine is stateless; `apply_conversion_outcome()` must always be called after `resolve()` — treat as a finally block. |
| Dialogue Content Database | `dialogue-content-database.md` | Provides `DialogueDatabase` — approach lines, outcome summary lines, and inspect line pools. Hard dependency. Must verify `is_loaded()` before any content call. Also provides `DialogueApproach` and `ConversionOutcome` enum definitions. |
| NPC Trait Database | `npc-trait-database.md` | Provides `TraitDatabase.get_affinity(trait_id, approach)` — queried during alignment signal computation over `revealed_traits` only. Soft dependency: if unavailable, alignment signal defaults to NEUTRAL for all approaches; sessions can proceed without greying. |
| Game Config / UITimingConfig | `game-config.md` | Provides `approach_confirm_hold_sec`, `dialogue_line_hold_sec`, `outcome_display_hold_sec`, `hardened_reveal_hold_sec`. Hard dependency: without timing values, the session sequence has no hold durations. |

---

### Systems That Depend On This System

| System | GDD | What it uses |
|---|---|---|
| Conversion UI | *(GDD pending)* | Primary presentation consumer. Calls all command methods (`begin_session`, `select_approach`, `trigger_inspect`, `cancel_session`, `get_approach_alignment`). Subscribes to all signals (`session_begun`, `approach_line_ready`, `outcome_resolved`, `session_complete`, `trait_inspected`). |
| Game State Manager | *(GDD pending)* | Subscribes to `session_complete` to know when a conversion attempt has finished. Does not call any command methods on this system. |
| Save & Load System | *(GDD pending)* | Must serialize this system's recency state (approach lines, outcome lines, inspect lines) and the pending-session record — the only runtime state this system owns between sessions. |
| Audio System | *(GDD pending)* | Subscribes to `outcome_resolved(outcome)` to trigger music cues and conversion-moment audio. |
| Rival Faith System | *(GDD pending)* | Calls `NPCRegistry.apply_conversion_outcome()` directly — not through this system. Runs its own independent session flow without using this system's state machine or DialogueDatabase. |
| Tutorial & Onboarding | *(GDD pending)* | Observes `session_begun`, `approach_line_ready`, `outcome_resolved`, and `session_complete` signals as tutorial progression hooks. Must not intercept or block the session sequence. |

---

### Cross-System Updates Required Before Implementation

1. **NPC Character System GDD**: Update `NPCRegistry.reveal_trait()` from `reveal_trait(npc_id: String, trait_id: String)` to `reveal_trait(npc_id: String, approach: DialogueApproach)`.

2. **Dialogue Content Database GDD + Entity Registry**: Rename `ConversionOutcome.CONVERTED` → `PERSUADED` (flagged in NPC Character System GDD Rule 9). Registry entry "CONVERTED | SOFTENED | RESISTED | HARDENED" must be updated to "PERSUADED | SOFTENED | RESISTED | HARDENED".

## Tuning Knobs

This system reads existing tuning values from `UITimingConfig` (owned by Game Config GDD) and introduces three new fields. All values are read at call time — nothing is cached.

### New Fields — `UITimingConfig`

| Knob | GameConfig Field | Default | Safe Range | Effect |
|---|---|---|---|---|
| Approach confirm hold | `approach_confirm_hold_sec` | 0.6s | 0.3–1.2s | Duration of the "held breath" beat between approach button tap and approach line appearing. Below 0.3s the beat is imperceptible and the sequence reads as a form submission. Above 1.2s the pacing feels slow on mobile. **New field.** |
| HARDENED reveal hold | `hardened_reveal_hold_sec` | 1.0s | 0.5–1.5s | Hold duration between the trait reveal card and the HARDENED outcome summary line. Too short: the reveal has no weight. Too long: stalls the session on mobile. **New field.** |

### New Domain — `DialogueConfig` (new GameConfig domain)

| Knob | GameConfig Field | Default | Safe Range | Effect |
|---|---|---|---|---|
| Recency window | `DialogueConfig.recency_window` | 2 | 1–(L−1) | Number of recently-shown line indices excluded from the next selection across all pool types. Must satisfy W < L at all times. W=1 prevents back-to-back repeats only. W=2 (default) prevents any line from appearing twice in a row. Do not set W ≥ L — violates the invariant and triggers the defensive clear fallback on every call. **New field.** |

### Existing Fields Consumed (owned by Game Config GDD)

| Knob | GameConfig Field | Owned By |
|---|---|---|
| Dialogue line hold | `UITimingConfig.dialogue_line_hold_sec` | Game Config GDD |
| Outcome display hold | `UITimingConfig.outcome_display_hold_sec` | Game Config GDD |
| Approach cooldown turns | `ConversionConfig.approach_cooldown_turns` | Game Config GDD (read via NPCRegistry) |
| Max approaches per NPC | `ConversionConfig.max_approaches_per_npc` | Game Config GDD (read via NPCRegistry) |

### Interaction Warning

`approach_confirm_hold_sec` + `dialogue_line_hold_sec` together determine how long the player sits with the approach line before the outcome. If both are tuned to their minimums, the sequence from tap to outcome is very short and loses its felt weight. When tuning either, test the full approach-to-outcome rhythm as a sequence, not each hold in isolation.

## Visual/Audio Requirements

The conversation screen operates in the Conversation mood register (Art Bible §2.2): portrait as sole lit object, background at 50–60% of portrait value and saturation, lighting temperature as emotional encoding. All UI elements appear placed rather than animated — no entrance animations except where emotion demands them.

| Event | Visual Requirement | Audio Requirement |
|---|---|---|
| **Session opens — approach selection screen** | NPC portrait at full resolution in portrait zone (upper 60–65% of screen) at belief-state-appropriate expression. Background drops to 50–60% value. Approach and Inspect buttons placed without animation — a scribe setting them down. (Principle 1: Weight Before Flash) | None — village ambient continues. Silence is the weight of the approach screen. |
| **Inspect — trait card revealed** | Trait card appears in inspection panel via cross-dissolve at 300–400ms linear (§7.4). Grisaille marginalia treatment: Iron Ink outline, mid-value partial fill at 40–60% value, semantic color per trait category. Alignment signal on approach buttons updates silently if changed. NPC portrait does not change — the player is reading, not provoking. | Soft reveal sound: single quiet page-turn/parchment tone (`sfx_trait_revealed`). One cue per reveal. |
| **Approach confirmed — held breath beat** | Approach category label placed in dialogue zone (italicised body face: *"You speak to her grief."*). Portrait cross-dissolves to a "considering/attending" expression variant (300–400ms linear). Approach buttons become non-interactive but do not change visual state. | None — 0.6s hold in silence. This is the held breath. |
| **Approach line displayed** | Approach line placed in dialogue zone in full — no typewriter effect. Body face, 16–17pt, left-aligned (§7.2). Portrait holds "considering" expression. No other element changes. | None — ambient only through the hold. |
| **PERSUADED resolved** (STEADFAST→OPEN or OPEN→WAVERING) | Outcome summary line placed. Portrait cross-dissolves to new belief state expression (300–400ms). Lighting shifts ~+200K warmer (psychological light sourcing, §5). Not the conversion surge — that is reserved for CONVERTED alone. | Soft ambient tone shift: warmer register for OPEN; low contemplative sting for WAVERING. Audio System distinguishes by new belief state from `outcome_resolved(PERSUADED)`. |
| **SOFTENED resolved** | Outcome summary line placed. Portrait cross-dissolves to new belief state expression (300–400ms). Lighting shifts ~+100K warmer — "almost." Visually distinct from PERSUADED in degree only. | Same soft ambient tone shift as PERSUADED at lower amplitude or shorter duration. Sound of something settling, not opening. |
| **RESISTED resolved** | Outcome summary line placed. Portrait cross-dissolves within same belief state to a subtle draw-back or averted-gaze variant. Lighting drops ~−300K cooler than approach baseline — dignified, not alarming (§2.4). No red flash, no punishing indicator. Resistance is posture and light, not UI alarm. | None — ambient only. Silence is a door not yet open. |
| **HARDENED — Beat 1 (trait reveal)** | Portrait cross-dissolves to regressed belief state expression (300–400ms). Lighting drops −300–400K cooler (§2.4). Trait card appears in inspection panel — what you misread about this person. | Weighted low tone on card appearance (`sfx_trait_hardened`) — heavier than `sfx_trait_revealed`. One cue at Beat 1 only. |
| **HARDENED — Beat 2 (outcome line)** | After `hardened_reveal_hold_sec`, outcome summary line placed in dialogue zone. Cool lighting holds. Two-beat grammar: *you misread them / and this is what it cost you.* | None — Beat 2 lands in silence. |
| **Trait revealed — normal path (PERSUADED/SOFTENED)** | Trait card appears in inspection panel after outcome hold elapses via cross-dissolve (300–400ms). Portrait does not change — the emotional moment has landed; the trait card is the manuscript annotation. | Soft reveal sound: `sfx_trait_revealed`. Same cue as Inspect — trait reveal always sounds like a page turning. |
| **Session complete — map return (non-CONVERTED)** | Page-turn dissolve to village map (§7.7). NPC thumbnail updates to belief-state expression. Color temperature halo updates: warmer for advancement, cooler for HARDENED. Cooldown overlay applied immediately. Map does not animate on non-CONVERTED return. | Village ambient resumes. No additional cue unless belief state changed — tone shift already fired during outcome display. |
| **CONVERTED — Phase 1 (portrait)** | Portrait cross-dissolves to CONVERTED expression ("peaceful/luminous"). Lighting enters Conversion Success surge: +400–600K warmer (§2.3), subtle warm non-naturalistic rim light from above. Surge eases in 400–600ms, holds 1500–2000ms, fades 800ms. This is the only non-naturalistic lighting in the system — earned by being singular. Outcome summary line placed beneath portrait. | **Conversion chime fires** (`music_conversion_chime_01`) at portrait cross-dissolve onset. One-shot, non-looping. Carries through page-turn dissolve, fading as ink-bleed completes. |
| **CONVERTED — Phase 2 (map return)** | Page-turn dissolve to village map. Faith-spread ink-bleed initiates from NPC's map position: Scripture Gold at 30–40% opacity, bleeding outward irregularly over 1500–2000ms (§4.3). Organic, asymmetric. Only animation active during this transition. NPC thumbnail updates to CONVERTED expression with luminous warm halo. | Conversion chime carries through from Phase 1 and fades here. |

**Art Bible principles audit:**

| Principle | Events governed |
|---|---|
| Principle 1 — Weight Before Flash | Session open; approach confirm beat; approach line; RESISTED; map return; CONVERTED ink-bleed (earns its motion) |
| Principle 2 — The Portrait Is the Story | All events — portrait drives emotional read at every state |
| §2.2 Conversation Mood | Events 1–9 — close candlelight, portrait as sole lit object |
| §2.3 Conversion Success | CONVERTED Phase 1 only — warmth surge, non-naturalistic rim light |
| §2.4 Conversion Failure | RESISTED and HARDENED — cool shift, posture draw-back, no alarm |
| §7.4 Cross-dissolve durations | All portrait expression transitions — 300–400ms linear, no bounce easing |
| §7.7 Page-turn dissolve | Map ↔ conversation transition |
| §4.3 Ink-bleed | CONVERTED Phase 2 only — organic, noise-driven |

> 📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:dialogue-conversion-system` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## UI Requirements

### Screen Layout

The conversation screen occupies the full portrait viewport and divides into two zones:

- **Portrait zone** (upper 60–65%): NPC portrait fills this area. Mood-lit per the Conversation register (Art Bible §2.2). No other primary content here — the portrait is the story.
- **Choice zone** (lower 35–40%): Approach buttons, Inspect button, trait display panel, and dialogue zone all live here. Content in this zone changes as the session progresses.
- **Dialogue zone** (within choice zone): A fixed text area at the top of the choice zone. Displays approach category label (APPROACH_CONFIRMED state), approach line (LINE_DISPLAYING onward), and outcome summary line (OUTCOME_DISPLAY). Only one piece of content is displayed at a time — text does not accumulate.

---

### Approach Buttons

- All four approach buttons (`GRIEF`, `AMBITION`, `DOUBT`, `FEAR`) are always shown on the approach selection screen.
- **Minimum tap target: 44×44dp** per platform requirements.
- At screen open, call `get_approach_alignment(npc_id, approach)` for each of the four approaches and apply the result:
  - `POSITIVE` → normal visual state
  - `NEUTRAL` → normal visual state
  - `NEGATIVE` → greyed/de-emphasized visual state. The button remains fully tappable. De-emphasis is a hint, not a lock.
- **After each Inspect reveal**: call `get_approach_alignment()` for all four approaches again and re-render button states. Inspect may change the alignment signal.
- After the player taps one approach (`APPROACH_CONFIRMED`), all four buttons become non-interactive. They do not disappear — the session hasn't resolved yet and the player should see their choice.
- Approach buttons are fully removed from the layout once `LINE_DISPLAYING` begins.

---

### Inspect Button

- Visible **only while hidden traits remain** (`revealed_traits.size() < assigned_traits.size()`).
- When all traits are revealed, the Inspect button is **fully absent** from the layout (not greyed — removed).
- **Minimum tap target: 44×44dp**.
- Available in `APPROACH_SELECTION` state only. Once the player taps an approach (→ `APPROACH_CONFIRMED`), Inspect is unavailable.
- Each tap calls `trigger_inspect()`, which reveals one trait. The Inspect button remains visible after a reveal if further hidden traits exist.
- The UI subscribes to the `trait_inspected(trait_id: String)` signal to animate the trait card in.

---

### Trait Display

- **Revealed trait cards**: displayed in a trait panel within the choice zone. Each card shows the trait's display name and flavor text. Affinity values are **never shown** to the player — never display a number for how well a trait matches an approach.
- **Hidden trait count**: displayed as `[N traits hidden]` below the revealed cards. Decrements by one on each inspect reveal. When zero, the label is removed along with the Inspect button.
- Trait cards animate in on reveal (cross-dissolve per Visual/Audio Requirements). Already-revealed cards at session open appear placed — no entrance animation.

---

### Dialogue Zone

- **In `APPROACH_CONFIRMED` state**: approach category label displayed in the dialogue zone in italics (e.g., *"You speak to her grief."*).
- **In `LINE_DISPLAYING` state**: approach line replaces the label. Displayed in full — **no typewriter effect**. Body face, 16–17pt minimum, left-aligned.
- **In `OUTCOME_DISPLAY` state**: outcome summary line replaces the approach line. Displayed in full — no typewriter.
- Only one line appears at a time. No scrolling, no history. The previous line is replaced, not pushed down.

---

### HARDENED Display Path — UI Branching

The UI must inspect the `outcome` field from the `outcome_resolved(outcome, summary_line, revealed_trait_id)` signal and branch:

- **HARDENED**: show trait card first (trait reveal in inspection panel), hold for `hardened_reveal_hold_sec`, then place outcome summary line in dialogue zone.
- **All other outcomes (PERSUADED, SOFTENED, RESISTED)**: place outcome summary line in dialogue zone first, then (if `revealed_trait_id` is non-empty and outcome ≠ RESISTED) animate trait card in after `outcome_display_hold_sec`.

The trait card used in the HARDENED Beat 1 is `revealed_trait_id` from the signal. The UI does not select the trait — it receives it.

---

### Back / Cancel

- A back/cancel action is available **in `APPROACH_SELECTION` state only** via `cancel_session()`.
- After the player taps an approach (`APPROACH_CONFIRMED` and beyond), cancellation is not available. The sequence from approach tap to outcome is non-cancellable.
- The UI does not show a "cancel" button in `APPROACH_CONFIRMED`, `LINE_DISPLAYING`, `RESOLVING`, or `OUTCOME_DISPLAY` states.

---

### Approach Count Display

- The remaining approach count (`max_approaches_per_npc - approach_count`) must **not** be shown as a number.
- When `approach_count == max_approaches_per_npc - 1` (one attempt remaining), the UI surfaces an implicit warning through observable character cues (expression change, atmospheric shift, or similar). The exact form is a UX system decision — this system exposes `approach_count` for the UI to read but does not dictate the cue.

---

### Timer Ownership

The UI owns all timer management. The system's state machine transitions on UI-fired events, not internal timers:

- On approach button tap: call `select_approach()` immediately (state advances to APPROACH_CONFIRMED); the approach line is emitted by DCS and held by the UI to the confirm-hold boundary (`approach_confirm_hold_sec` elapses)
- After approach line is displayed: start `dialogue_line_hold_sec` timer → on expiry, advance to RESOLVING
- After outcome line is displayed: start `outcome_display_hold_sec` timer → on expiry, advance to SESSION_COMPLETE
- For HARDENED Beat 1 (trait reveal): start `hardened_reveal_hold_sec` timer → on expiry, place outcome line

All timing values are read from `UITimingConfig` at the time the timer is started.

---

> 📌 **UX Spec** — Run `/ux-design conversation-screen` to produce the detailed per-screen UX spec for the conversation screen layout, `outcome-display` spec for the HARDENED vs. normal outcome display paths, and the `trait-card` component spec for reveal animation and content rules.

## Acceptance Criteria

### AC-1: Session State Machine

**AC-1.1:** When a player taps an NPC that is in the approachable list and `DialogueDatabase` reports loaded, the system transitions from `IDLE` to `APPROACH_SELECTION` and emits `session_begun(npc_id)`.

**AC-1.2:** When a player taps an approach button while in `APPROACH_SELECTION`, the system transitions to `APPROACH_CONFIRMED` and does not transition to any other state first.

**AC-1.3:** After the approach-confirm hold elapses and the approach line is displayed, the system transitions from `APPROACH_CONFIRMED` to `LINE_DISPLAYING`.

**AC-1.4:** After the dialogue-line hold elapses, the system transitions from `LINE_DISPLAYING` to `RESOLVING`.

**AC-1.5:** After the outcome is applied, the system transitions from `RESOLVING` to `OUTCOME_DISPLAY`. No other state is reachable from `RESOLVING`.

**AC-1.6:** After the outcome hold elapses, the system transitions from `OUTCOME_DISPLAY` to `SESSION_COMPLETE`, then immediately to `IDLE`.

**AC-1.7:** `session_complete` is emitted exactly once per session, during the `SESSION_COMPLETE` → `IDLE` transition.

**AC-1.8:** The system cannot exit `RESOLVING` to any state other than `OUTCOME_DISPLAY`, regardless of external input.

**AC-1.9:** `cancel_session()` called while in `APPROACH_SELECTION` transitions the system to `IDLE` and returns the player to the village map.

**AC-1.10:** `cancel_session()` called in any state other than `APPROACH_SELECTION` produces no state change and no error visible to the player.

**AC-1.11:** `select_approach()` called after the system is already in `APPROACH_CONFIRMED` or any later state produces no state change.

**AC-1.12:** `select_approach()` called while in `IDLE` (before `begin_session()`) produces no state change and does not begin a session.

**AC-1.13:** `trigger_inspect()` called while in any state other than `APPROACH_SELECTION` produces no trait reveal and no state change.

---

### AC-2: Approachability Gate

**AC-2.1:** Tapping an NPC that is not in the approachable list does not begin a session, does not emit `session_begun`, and leaves the system in `IDLE`.

**AC-2.2:** No approach selection screen or any other session UI element is shown when the approachability check fails.

**AC-2.3:** When `DialogueDatabase.is_loaded()` returns false at the moment `begin_session()` is called, the session does not begin, the system remains in `IDLE`, and no UI transition occurs.

**AC-2.4:** The approachability check is evaluated before any session state is set and before any UI is displayed.

---

### AC-3: Re-entrancy and Concurrent Session Guards

**AC-3.1:** Calling `begin_session()` while the system is in any state other than `IDLE` produces no state change, does not emit `session_begun`, and does not alter the in-progress session.

**AC-3.2:** After the no-op in AC-3.1, the original session continues to its normal conclusion without interruption.

**AC-3.3:** `begin_session()` called with a different `npc_id` while a session is active does not replace the active session's target NPC.

---

### AC-4: Inspect Behavior

**AC-4.1:** Tapping the Inspect button while in `APPROACH_SELECTION` reveals one previously hidden trait and emits `trait_inspected(trait_id)` carrying the ID of the newly revealed trait.

**AC-4.2:** After an inspect reveal, the system remains in `APPROACH_SELECTION` — the state does not change.

**AC-4.3:** If hidden traits remain after one inspect, the Inspect button is still present and tappable; each subsequent tap reveals one additional trait.

**AC-4.4:** An inspect reveal that occurs before the player cancels the session is permanent: after `cancel_session()` is called, the NPC's revealed trait count is higher than it was before the session began.

**AC-4.5:** The Inspect button is absent from the layout (not merely greyed or disabled) when `revealed_traits.size() == assigned_traits.size()`.

**AC-4.6:** Calling `trigger_inspect()` when all traits are already revealed produces no trait reveal, no signal emission, and no state change.

**AC-4.7:** The Inspect button is not present or interactive in any state other than `APPROACH_SELECTION`.

**AC-4.8:** The `trait_inspected` signal is emitted for each individual inspect reveal — one emit per trait revealed.

---

### AC-5: Alignment Signal — Formula 1

**AC-5.1:** When an NPC has zero revealed traits, `get_approach_alignment()` returns `NEUTRAL` for all four approaches (`GRIEF`, `AMBITION`, `DOUBT`, `FEAR`).

**AC-5.2:** When the net affinity for an approach is strictly greater than 0.0 across all revealed traits, `get_approach_alignment()` returns `POSITIVE` for that approach.

**AC-5.3:** When the net affinity for an approach is strictly less than 0.0 across all revealed traits, `get_approach_alignment()` returns `NEGATIVE` for that approach.

**AC-5.4:** When the net affinity for an approach is exactly 0.0, `get_approach_alignment()` returns `NEUTRAL` — there is no dead zone around zero.

**AC-5.5:** `get_approach_alignment()` only reflects traits that have been revealed to the player. Adding a hidden trait to an NPC's `assigned_traits` without revealing it does not change the alignment signal.

**AC-5.6:** After each inspect reveal, calling `get_approach_alignment()` returns a signal that reflects the newly revealed trait — the signal changes if the new trait has non-zero affinity for any approach.

**AC-5.7:** `get_approach_alignment()` returns the same value on repeated calls with no intervening inspect reveals — the result is deterministic.

**AC-5.8:** The alignment signal computation does not generate a conversion outcome, does not modify any NPC state, and does not call into `ConversionLogicEngine`.

---

### AC-6: Recency Line Selection — Formula 2

**AC-6.1:** The same dialogue line is never shown on two consecutive approach selections for the same NPC and approach combination when the pool contains three or more lines.

**AC-6.2:** After three consecutive selections from a three-line pool for the same NPC and approach, each of the three lines has been shown at least once.

**AC-6.3:** The same outcome summary line is never shown on two consecutive resolutions of the same approach–outcome combination for the same NPC when the pool contains three or more lines.

**AC-6.4:** The same inspect line is never shown on two consecutive inspect triggers for NPCs of the same archetype when the pool contains three or more lines.

**AC-6.5:** Inspect line recency is shared across all NPCs of the same archetype — the line shown for NPC A of archetype X is excluded from the next inspect selection on any NPC B of that same archetype X.

**AC-6.6:** After `NPCRegistry.clear_village()` is called, all three recency pools are empty — a line shown last in the previous village may be shown first in the new village.

**AC-6.7:** If a recency pool's eligible set would be empty (invariant violation), the system selects a line from the full pool and logs a warning — no crash, no out-of-range index.

**AC-6.8:** A recency key that has never been accessed initializes to an empty history — the first selection from any pool is unconstrained.

**AC-6.9:** After the recency window slides (oldest entry evicted), the evicted index becomes eligible again immediately on the next selection.

---

### AC-7: Core Session Flow and Resolve Guarantee

**AC-7.1:** The conversion outcome is determined exactly once per session — resolved after the dialogue-line hold elapses and before the outcome display begins.

**AC-7.2:** No session path — including timed holds, device events, or error conditions — results in `resolve()` returning without `apply_conversion_outcome()` subsequently being called.

**AC-7.3:** A pending-session record with `status: "pending"` exists in save state from the moment `resolve()` is called until `apply_conversion_outcome()` returns.

**AC-7.4:** After `apply_conversion_outcome()` returns, the pending-session record is updated to `status: "resolved"` before the outcome display begins.

**AC-7.5:** Approach line selection and display occur before `resolve()` is called — the player sees the prophet's words before the outcome is determined.

**AC-7.6:** On the HARDENED path: the trait reveal card is shown and the `hardened_reveal_hold_sec` hold elapses before the outcome summary line is placed in the dialogue zone.

**AC-7.7:** On the normal path (PERSUADED or SOFTENED): the outcome summary line is shown and the `outcome_display_hold_sec` hold elapses before the trait reveal card animates in.

**AC-7.8:** On the RESISTED path: no trait reveal card is shown and `reveal_trait()` is not called during the session.

**AC-7.9:** On the PERSUADED or SOFTENED path when all traits are already revealed: the outcome summary line is displayed and no trait reveal card is shown.

**AC-7.10:** On the HARDENED path when all traits are already revealed: the system falls back to the normal display path — outcome summary line first, no trait reveal card, no `hardened_reveal_hold_sec` hold before the outcome line.

**AC-7.11:** Each timed hold uses the value read from `GameConfig` at the moment the timer starts, not a cached value from session start.

---

### AC-8: Session Safety and Resume Handling

**AC-8.1:** On game resume when a pending-session record with `status: "pending"` exists, no dialogue screen is shown — the player is returned directly to the village map.

**AC-8.2:** On game resume with a `status: "pending"` record, the stale NPC's state is updated with a RESISTED outcome before the player can interact with the map.

**AC-8.3:** On game resume with a `status: "pending"` record, the stale NPC's belief state is unchanged after the RESISTED sentinel is applied.

**AC-8.4:** On game resume with a `status: "pending"` record, the pending-session record is fully cleared before the player can begin a new session.

**AC-8.5:** On game resume when a pending-session record with `status: "resolved"` exists, the record is cleared and the player begins normally with no additional penalty.

**AC-8.6:** If a stale pending-session record exists when `begin_session()` is called mid-play (not on resume), the stale record is processed first — `status: "pending"` triggers RESISTED sentinel for the stale NPC, `status: "resolved"` triggers record-clear only — before the new session begins.

**AC-8.7:** The player cannot gain an advantage from force-quitting during `RESOLVING` — no favorable outcome is committed to NPC state unless `apply_conversion_outcome()` completes.

---

### AC-9: Signal API Contracts

**AC-9.1:** `session_begun(npc_id)` is emitted exactly once at the start of each session, carrying the ID of the NPC being approached.

**AC-9.2:** `outcome_resolved` is emitted exactly once per session, carrying three fields: the `ConversionOutcome`, the selected outcome summary line string, and the `revealed_trait_id` (empty string if no trait was revealed).

**AC-9.3:** `session_complete` is emitted exactly once per session, after the outcome hold has elapsed and before control returns to the map.

**AC-9.4:** `trait_inspected(trait_id)` is emitted once for each inspect action that results in a trait reveal, carrying the ID of the newly revealed trait.

**AC-9.5:** `outcome_resolved` is not emitted before `apply_conversion_outcome()` has been called — the signal reflects a committed outcome, not a pending one.

**AC-9.6:** No signal is emitted when `begin_session()` is called as a no-op (system already active).

**AC-9.7:** `session_complete` is not emitted when `cancel_session()` is called from `APPROACH_SELECTION` — cancellation is not a session completion.

---

### AC-10: Tuning Knob Behavior

**AC-10.1:** `approach_confirm_hold_sec`, `hardened_reveal_hold_sec`, and `DialogueConfig.recency_window` are each readable from `GameConfig` during a live session without a game restart.

**AC-10.2:** Changing `DialogueConfig.recency_window` while a session is in progress does not alter the recency behavior of the current session — the new value takes effect starting with the next `begin_session()` call.

**AC-10.3:** All timing hold values are read from `UITimingConfig` at the moment each timer starts, not pre-read and stored at session start.

---

### AC-11: HARDENED on STEADFAST NPC (EC-8)

**AC-11.1:** When a HARDENED outcome occurs on a STEADFAST NPC, the NPC's belief state after the session is STEADFAST — it does not regress below STEADFAST.

**AC-11.2:** When a HARDENED outcome occurs on a STEADFAST NPC, the HARDENED display path still executes — the trait reveal card is shown before the outcome summary line, with the `hardened_reveal_hold_sec` hold between them.

**AC-11.3:** When a HARDENED outcome occurs on a STEADFAST NPC, `approach_count` and `cooldown_turns_remaining` are updated as they would be for any HARDENED outcome.

---

### AC-12: Approach Count — Non-Display Rule

**AC-12.1:** At no point during a session does the player see a numeric count of remaining approach attempts — no digit, fraction, or counter is shown.

**AC-12.2:** When the player has one approach attempt remaining on an NPC, the session proceeds normally — the player is not blocked from making the attempt.

---

### AC-13: Dialogue Zone — Single-Line Display

**AC-13.1:** Only one piece of text occupies the dialogue zone at any time — placing the approach line removes the approach category label; placing the outcome summary line removes the approach line.

**AC-13.2:** Text in the dialogue zone appears in full immediately when placed — no typewriter or character-by-character reveal effect is used.

**AC-13.3:** No text from a prior session remains in the dialogue zone when a new session opens.

## Open Questions

**OQ-1. Implicit approach-count warning cue — what form does it take?**
The system exposes `approach_count` for the UI to read, and Rule 7 states that when one approach remains (`approach_count == max_approaches_per_npc - 1`) the UI surfaces "observable character cues." The exact cue form — expression shift, atmospheric change, subtle dialogue tint — is deferred to the UX spec. **RESOLVED (2026-08-09):** the Conversion UI GDD (system #12, Rule 12) defines the cue as a **−150K background mood-lighting cooling** from the session baseline at session open — no numbers, no text. Form fixed at MVP; subject to `/ux-design` post-MVP (Conversion UI OQ-1).

**OQ-2. Mid-play stale pending record (EC-7) — is the player notified?**
When `begin_session()` is called with a stale `status: "pending"` record (EC-7), the sentinel fires and the stale NPC receives a RESISTED outcome silently. The current spec does not state whether the player sees a brief notification or whether the stale processing is fully invisible. If the player notices their previous NPC now has a cooldown they don't remember applying, they may perceive a bug. Decision needed: silent (current spec) or brief map-layer notice?

**OQ-3. Does the Rival Faith System trigger trait reveals?**
The Rival Faith System calls `NPCRegistry.apply_conversion_outcome()` directly. Whether it also calls `reveal_trait(npc_id, approach)` during its session flow is undefined — the Rival Faith System GDD has not been authored yet. If it does reveal traits, the recency state for inspect lines could be affected. Resolution: Rival Faith System GDD must specify whether it calls reveal_trait() and, if so, whether those reveals use the same recency pool.

**OQ-4. Save & Load serialization format for recency state.**
This GDD specifies that the Save & Load System must serialize the three recency pools and the pending-session record, but does not define the serialization format (JSON shape, key encoding, version migration strategy). Resolution: Save & Load System GDD must define the contract, and this system's implementation must conform to it.

**OQ-5. Tutorial & Onboarding — guidance without blocking the session.**
The Tutorial & Onboarding system is flagged as a downstream dependent that must not intercept or block the session sequence. It is unclear how onboarding guidance (e.g., "tap an approach button to continue") can be presented without pausing the state machine. Resolution: Tutorial & Onboarding GDD must specify the non-blocking overlay pattern it uses for in-session guidance.
