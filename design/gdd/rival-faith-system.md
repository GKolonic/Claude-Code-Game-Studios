# Rival Faith System

> **Status**: In Design
> **Author**: Design session + agents
> **Last Updated**: 2026-04-26
> **Implements Pillar**: Pillar 1 — Every Soul Has a Story; Pillar 3 — The Arc Must Feel Earned; Pillar 4 — History Writes Itself

## Overview

The Rival Faith System is the turn-resolution layer that gives the opposing religion an active presence in every village. After the player's turn completes and before `turn_advanced` fires, the system runs its evaluation loop: it inspects the current village population, selects one or more NPC targets from OPEN, WAVERING, and recently-converted NPCs, chooses a counter-approach by reading the target's revealed traits and selecting the approach most likely to push back against the player's progress, and calls `NPCRegistry.apply_conversion_outcome()` to apply the result — the same mutation path the player uses, called from the antagonist's side. CONVERTED NPCs are approachable by the rival for a short grace window after conversion (a tunable turn count) during which a successful rival approach can regress them to WAVERING; after the window closes, the conversion becomes permanent. The system owns no dialogue content and no UI — its outputs surface through the same NPC state changes the rest of the game reads. At MVP, exactly one rival faith is active per village; the system's target-selection and approach-choice logic is designed to accommodate multiple rivals post-MVP without architectural change.

The game needs this system because faith spread without active opposition is empire-building without stakes. Without the Rival Faith System, the village is a puzzle with a single player — once an NPC is OPEN, the only question is how long conversion takes. With it, every convert is immediately contested: the rival faith is attending the same village the player is, reading the same characters, and making different arguments. The player experiences this not as a UI interrupt but as a world that pushes back — an NPC they thought was nearly won is suddenly more distant; a convert they celebrated yesterday now wavers. The system is a pressure gauge, not a combatant. It does not mirror the player's power; it maintains the tension that makes each conversion feel hard-won.

## Player Fantasy

The other prophet knocks on the same four doors you knock on. They speak to Grief, Ambition, Doubt, and Fear — not because they have read your doctrine, but because those are the only doors there are. They are in this village for the same reason you are, reading the same faces, waiting for the same silences to open. You will never see them. You will never argue with them directly. But you will find their work in every NPC who closes again after you thought them open, and in every convert who you had believed was yours — and who now is not so sure.

A faith that spreads without resistance is not a faith: it is a fashion. The Rival Faith System exists so that every conversion you hold is one you have earned twice — once in the conversation that opened the soul, and once again in the turns that followed, as the world tried to reclaim what you had won. When a recently converted villager regresses to WAVERING, the correct feeling is not *I lost a roll.* It is *of course. Of course she would doubt. She buried her son last winter, and grief does not stay quiet, and someone else was already there with a different answer to the same question.* The system is a pressure gauge, not an enemy. It does not grow. It does not escalate dramatically. It simply maintains the gravity of a real world that does not bend merely because you arrived.

This system is working when the player pauses between turns and feels, for a moment, the weight of absence — the turns they were not there. It is working when a regression produces a specific, explicable feeling rather than an arbitrary setback: *I should have returned to her sooner. I knew she was wavering.* It is working when a stretch of stable converts feels like a held breath, not a guarantee — because the player has learned that converts can be contested, and stability is maintained, not given. The system fails the moment the player stops caring who regressed and starts treating a WAVERING NPC as a resource to re-acquire. If the rival faith is invisible for too long, its absence is what defines it. If its effects are too frequent, it tips from context into harassment. The window is narrow: present enough to make the player feel watched, quiet enough to make each regression feel personal.

## Detailed Design

### Core Rules

**1. Entry point and execution model.** The Rival Faith System is implemented as an Autoload singleton (`RivalFaithSystem`). It subscribes to `GameStateManager.turn_advancing` at `_ready()`. All evaluation — target selection, approach scoring, outcome resolution, and mutation — runs synchronously inside `process_turn()`. The system completes before `turn_advanced` fires. No `await`, no deferred calls.

**2. Aggression interval.** The rival does not act every turn. It acts only when:
```
GameStateManager.get_turn_number() > 0
AND GameStateManager.get_turn_number() % GameConfig.rival.aggression_interval_turns == 0
```
On non-action turns, `process_turn()` returns immediately. The first rival action occurs at turn `aggression_interval_turns` — the player has a free opening window of N-1 turns before rival pressure begins.

**3. Target eligibility.** On an action turn, the rival builds an eligible target pool. An NPC is eligible if:
- `belief_state IN [CONVERTED (with recently_converted_turns_remaining > 0), WAVERING, OPEN]`
- `access_gate == null` OR all `access_gate.required_npc_ids` have reached the required belief state

The rival does NOT respect the cooldown gate or approach-count cap — it may act on any NPC meeting the above criteria regardless of `cooldown_turns_remaining` or `approach_count`.

**4. Target priority and tie-breaking.** The rival selects one NPC per action turn using this ordered priority:

| Priority | Condition |
|---|---|
| 1st | `belief_state == CONVERTED AND recently_converted_turns_remaining > 0` |
| 2nd | `belief_state == WAVERING` |
| 3rd | `belief_state == OPEN` |

Within a tier: select the NPC with the lowest `approach_count`. If tied: select the NPC with the lowest index in `NPCRegistry.get_all_npcs()` (earliest registration order — deterministic). If no eligible targets exist across all tiers (village is all-STEADFAST or all CONVERTED NPCs are past the grace window with no WAVERING or OPEN remaining), the rival skips its action for this turn.

**5. Approach selection.** For the selected NPC, the rival scores all four `DialogueApproach` values against the NPC's full `assigned_traits` (not just `revealed_traits` — the rival is omniscient about village characters):
```
rival_net_affinity(approach) = Σ TraitDatabase.get_affinity(trait_id, approach)
                                for trait_id in npc.assigned_traits
```
The rival selects the approach with the highest `rival_net_affinity`. Ties resolved by `DialogueApproach` enum order. If all four approaches have `rival_net_affinity ≤ 0.0`, the rival selects the least-negative — it always acts on its chosen target. If `GameConfig.rival.counter_approach_random_weight > 0.0`, the rival instead selects uniformly at random with that probability (default 0.0 — no randomness). See §Formulas.

**6. Outcome resolution.** The rival calls `ConversionLogicEngine.resolve(approach, npc_id)` — the same pure function the player uses. No separate formula. After the CLE returns an outcome, the rival applies its `reharden_strength` post-resolution bias (§Formulas). The biased outcome is used for mutation.

**7. Outcome application.** The rival calls `NPCRegistry.apply_conversion_outcome(npc_id, outcome, approach, OutcomeCaller.RIVAL)`.

The `OutcomeCaller.RIVAL` flag activates the grace-window regression rule: if the target has `belief_state == CONVERTED` AND `recently_converted_turns_remaining > 0` AND outcome is `PERSUADED` or `SOFTENED`, the NPC regresses `CONVERTED → WAVERING`. After the grace window closes, conversion is permanent — `PERSUADED` and `SOFTENED` on CONVERTED NPCs are no-ops regardless of caller. `RESISTED` and `HARDENED` on CONVERTED NPCs are always no-ops.

All other state transitions follow the NPC Character System outcome table (Rule 5). Rival actions increment `approach_count` and `approach_history` on the target NPC, and set `cooldown_turns_remaining = GameConfig.conversion.approach_cooldown_turns` — identical to player actions.

**8. Trait revelation.** The rival never calls `reveal_trait()` or `trigger_inspect_reveal()`. Its moves are silent state changes. The player observes rival activity through NPC belief state changes on the village map (via the `npc_state_changed` signal) and through the `rival_acted` signal (see Interactions below).

**9. Grace window mechanics.** When any NPC transitions to `CONVERTED` via any caller, `apply_conversion_outcome()` sets `npc.recently_converted_turns_remaining = GameConfig.rival.grace_window_turns`. This field decrements in `NPCRegistry.advance_turn()` alongside `cooldown_turns_remaining` (floor 0), once per turn at GSM Step 3 — before the rival acts at Step 5. Therefore a newly converted NPC has already lost 1 grace-turn by the time the rival evaluates that same turn. The player-accessible grace window is effectively `grace_window_turns - 1` additional turns of rival vulnerability after the conversion turn.

**10. Faith power on regression and re-conversion.** When `npc_state_changed(npc_id, CONVERTED, WAVERING)` fires (rival regression), the Game State Manager removes `npc_id` from `converted_ids`. This allows the faith power award to fire again when the player re-converts the same NPC. Reclaiming a rival-regressed NPC earns full faith power — the re-conversion counts as a new conversion.

**11. Cross-system updates required before implementation.**

The following GDDs must be updated before this system can be implemented:

*(a) NPC Character System GDD:*
- Add `recently_converted_turns_remaining: int` to `NpcRecord` schema (default: 0)
- Update `advance_turn()` to decrement this field (floor 0) alongside `cooldown_turns_remaining`
- Update `apply_conversion_outcome()` to: (i) set `recently_converted_turns_remaining = GameConfig.rival.grace_window_turns` when processing any `WAVERING → CONVERTED` transition from any caller; (ii) accept `caller: OutcomeCaller = OutcomeCaller.PLAYER` as a new parameter; (iii) execute `CONVERTED → WAVERING` regression when `caller == RIVAL`, `belief_state == CONVERTED`, `recently_converted_turns_remaining > 0`, and outcome is `PERSUADED` or `SOFTENED`
- Add `OutcomeCaller` enum: `{PLAYER, RIVAL, FAITH_SPREAD}`
- Update Rule 5 outcome table and Edge Case E6 to document the grace-window exception

*(b) Game State Manager GDD:*
- Update the `npc_state_changed` handler: on a `CONVERTED → WAVERING` regression signal, remove `npc_id` from `converted_ids`. This enables faith power re-award on re-conversion.

---

### States and Transitions

The Rival Faith System is stateless between turns — it maintains no session-level state. The evaluation loop is a single synchronous pass per action turn:

| Phase | Trigger / Condition | Action |
|---|---|---|
| `turn_advancing` fires | GSM Step 5 | `RivalFaithSystem.process_turn()` begins |
| Interval not met | `turn == 0` OR `turn % aggression_interval_turns != 0` | Return immediately — no action this turn |
| Interval met | Eligible target pool built | Apply priority, select target |
| No eligible targets | Pool is empty across all tiers | Skip action — return. Interval still counts |
| Target selected | Target NPC identified | Score 4 approaches, pick highest affinity (with optional random weight) |
| Approach selected | Best approach identified | Call `ConversionLogicEngine.resolve(approach, npc_id)` |
| Outcome returned | CLE returns `ConversionOutcome` | Apply `reharden_strength` post-resolution bias |
| Biased outcome ready | Final outcome determined | Call `NPCRegistry.apply_conversion_outcome(..., OutcomeCaller.RIVAL)` → `npc_state_changed` fires; emit `rival_acted` signal |
| `process_turn()` returns | Synchronous pass complete | `turn_advanced` fires — downstream systems react to any state changes |

---

### Interactions with Other Systems

| System | Relationship | Calls Made |
|---|---|---|
| `GameStateManager` | Upstream — turn lifecycle | Subscribes to `turn_advancing` signal; queries `get_turn_number()` |
| `NPCRegistry` (NPC Character System) | Upstream — reads and mutates NPC state | `get_all_npcs()` (target pool); `apply_conversion_outcome(npc_id, outcome, approach, OutcomeCaller.RIVAL)` |
| `ConversionLogicEngine` | Upstream — pure outcome resolver | `resolve(approach, npc_id)` — at most once per action turn |
| `TraitDatabase` | Upstream — trait affinity for approach scoring | `get_affinity(trait_id, approach)` — over full `assigned_traits`; never over `revealed_traits` only |
| `GameConfig` / `RivalFaithConfig` | Upstream — configuration | `aggression_interval_turns`, `reharden_strength`, `counter_approach_random_weight`, `grace_window_turns` — read at call time, not cached |
| `Village Map View` | Downstream — reacts to belief state changes | Subscribes to `npc_state_changed` (from NPCRegistry) and `rival_acted` (from this system) |
| `HUD & Progress System` | Downstream — rival activity display | Subscribes to `rival_acted` if rival activity indicator is shown |

**Exposed API:**
```gdscript
# RivalFaithSystem (Autoload)

# Signals
signal rival_acted(target_npc_id: String, approach: DialogueApproach, outcome: ConversionOutcome)
# Emitted after apply_conversion_outcome() completes, once per rival action.
# Village Map View and HUD subscribe to mark rival activity on the NPC.
# Not emitted on skip turns or turns where no eligible target exists.
```

## Formulas

### Formula 1 — Rival Approach Scoring

The rival approach scoring formula is defined as:

```
rival_net_affinity(a) = Σ TraitDatabase.get_affinity(tᵢ, a)
                          for tᵢ in npc.assigned_traits

selected_approach = argmax { rival_net_affinity(a) : a ∈ DialogueApproach }
```

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `a` | Approach | DialogueApproach | {GRIEF, AMBITION, DOUBT, FEAR} | The approach being scored |
| `tᵢ` | Trait identifier | String | element of `npc.assigned_traits` | Each trait in the NPC's full assigned trait set — the rival reads all traits, not just revealed ones |
| `get_affinity(tᵢ, a)` | Single trait affinity | float | {-1.0, -0.5, 0.0, +0.5, +1.0} | Affinity of trait `tᵢ` for approach `a`. Source: `TraitDatabase`. Returns 0.0 for unknown inputs |
| `N` | Trait count | int | [2, 4] | Number of traits in `npc.assigned_traits` at MVP |
| `rival_net_affinity(a)` | Approach score | float | [-4.0, +4.0] | Sum of all per-trait affinities for approach `a`. Used for ranking only — absolute value is discarded after selection |
| `selected_approach` | Chosen approach | DialogueApproach | {GRIEF, AMBITION, DOUBT, FEAR} | The approach with the highest `rival_net_affinity` |

**Output range:** `selected_approach` is always one of the four `DialogueApproach` values. `rival_net_affinity(a)` ∈ [-4.0, +4.0] in 0.5 increments. If all four approaches have `rival_net_affinity ≤ 0.0`, the least-negative is selected — the rival always acts. Ties on `rival_net_affinity` resolved by `DialogueApproach` enum ordinal order.

**Example — Widow NPC, traits: `bereaved` (GRIEF +1.0, FEAR -0.5), `lonely` (GRIEF +0.5, DOUBT +0.5), `mortal_minded` (DOUBT +0.5, FEAR +0.5):**

| Approach | bereaved | lonely | mortal_minded | rival_net_affinity |
|---|---|---|---|---|
| GRIEF | +1.0 | +0.5 | 0.0 | **+1.5** |
| AMBITION | 0.0 | 0.0 | 0.0 | 0.0 |
| DOUBT | 0.0 | +0.5 | +0.5 | +1.0 |
| FEAR | -0.5 | 0.0 | +0.5 | 0.0 |

Selected: **GRIEF** (+1.5). The rival correctly identifies the same best approach a well-informed player should choose. Its omniscience means it reads the soul correctly even for traits the player has not revealed.

---

### Formula 2 — Reharden Strength Bias

The reharden strength bias formula is defined as:

```
bias_trigger_probability = |reharden_strength - 1.0|

bias_direction = PROMOTE  if reharden_strength > 1.0
                 DEMOTE   if reharden_strength < 1.0
                 NONE     if reharden_strength == 1.0

final_outcome =
  if rng.randf() < bias_trigger_probability:
    PROMOTE: shift cle_outcome one rank up the severity ladder (ceiling: HARDENED)
    DEMOTE:  shift cle_outcome one rank down the severity ladder (floor: PERSUADED)
  else:
    cle_outcome
```

**Outcome severity ladder (rival perspective):** PERSUADED → SOFTENED → RESISTED → HARDENED. One step per bias trigger maximum. Cannot move more than one step per resolution.

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `reharden_strength` | Rival strength scalar | float | [0.5, 1.5] | `GameConfig.rival.reharden_strength`. At 1.0 = neutral rival; below 1.0 = weakened rival; above 1.0 = strengthened rival. Default: **1.0** |
| `bias_trigger_probability` | Trigger chance | float | [0.0, 0.5] | Derived: `|reharden_strength - 1.0|`. At default 1.0: 0.0 — bias never fires |
| `bias_direction` | Shift direction | enum | {PROMOTE, DEMOTE, NONE} | Whether bias moves outcome toward HARDENED (PROMOTE) or PERSUADED (DEMOTE) |
| `cle_outcome` | CLE output | ConversionOutcome | {PERSUADED, SOFTENED, RESISTED, HARDENED} | Raw outcome from `ConversionLogicEngine.resolve()` before bias |
| `final_outcome` | Biased outcome | ConversionOutcome | {PERSUADED, SOFTENED, RESISTED, HARDENED} | Outcome passed to `NPCRegistry.apply_conversion_outcome()` |

**Output range:** `final_outcome` is always a valid `ConversionOutcome`. Ladder floors prevent movement outside the four-value set. At `reharden_strength = 1.0` the bias never fires — `final_outcome` always equals `cle_outcome`.

**Example — `reharden_strength = 1.25`, CLE returns SOFTENED:**
- `bias_trigger_probability = 0.25`, `bias_direction = PROMOTE`
- `rng.randf() = 0.18` → fires → SOFTENED + PROMOTE = **RESISTED**

**Example — `reharden_strength = 1.0`, any CLE outcome:**
- `bias_trigger_probability = 0.0` → never fires → `final_outcome = cle_outcome`

**Design note:** At default `reharden_strength = 1.0`, the rival's danger comes entirely from Formula 1 (omniscient approach selection) — not from inflated outcome probabilities. `reharden_strength` is a difficulty lever: raise above 1.0 for Hard mode, lower below 1.0 for Easy mode relief.

---

### Formula 3 — Counter-Approach Random Weight

The counter-approach random weight formula is defined as:

```
use_random = rng.randf() < counter_approach_random_weight

selected_approach =
  if use_random: uniform_choice({GRIEF, AMBITION, DOUBT, FEAR})
  else:          argmax { rival_net_affinity(a) }  [Formula 1 result]
```

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `counter_approach_random_weight` | Random probability | float | [0.0, 1.0] | `GameConfig.rival.counter_approach_random_weight`. Probability the rival ignores Formula 1 and selects uniformly at random. Default: **0.0** (pure best-approach at MVP). Recommended safe range: [0.0, 0.40] |
| `use_random` | Random branch taken | bool | {true, false} | Bernoulli trial result. True with probability `counter_approach_random_weight` |
| `uniform_choice({...})` | Random approach | DialogueApproach | {GRIEF, AMBITION, DOUBT, FEAR} | Each approach selected with probability 0.25 |
| `selected_approach` | Final approach | DialogueApproach | {GRIEF, AMBITION, DOUBT, FEAR} | Approach used against the target NPC this turn |

**Output range:** Always one of the four `DialogueApproach` values. At `counter_approach_random_weight = 0.0`, always returns the Formula 1 result. Formula 1 is computed regardless of branch (≤16 affinity lookups — negligible cost).

**Example — `counter_approach_random_weight = 0.20`, `rng.randf() = 0.14`:**
`0.14 < 0.20` → random branch → uniform_choice → DOUBT (Formula 1 result GRIEF discarded)

**Design note:** Default 0.0 makes the rival a pure optimal-reader — legible and strategically interesting. Post-MVP, 0.05–0.15 adds feel-of-imperfection without undermining legibility.

## Edge Cases

**If no eligible targets exist** (all NPCs are STEADFAST, or all CONVERTED NPCs have `recently_converted_turns_remaining == 0` and no WAVERING or OPEN remain): the rival skips its action. Nothing is called, `rival_acted` is not emitted. The turn interval still counts — the interval counter does not reset.

**If the eligible pool is non-empty but all candidates have `access_gate` conditions not yet satisfied**: all are excluded. The rival skips as above.

**If the rival acts on a cooldown-gated NPC** (`cooldown_turns_remaining > 0`): valid. The rival does not enforce the cooldown gate (NPC Character System E9). `apply_conversion_outcome()` is called normally; `cooldown_turns_remaining` is reset to `approach_cooldown_turns` by the call.

**If all four `rival_net_affinity` scores are exactly 0.0**: the rival selects the approach with the lowest `DialogueApproach` enum ordinal (GRIEF at MVP). 0.0 is not treated as "no viable approach" — the rival always acts when it has a target. The enum-ordinal tie-break is deterministic; `counter_approach_random_weight` is still applied as a Bernoulli trial before this selection.

**If the rival's `reharden_strength` bias promotes the CLE outcome to HARDENED against a CONVERTED NPC within the grace window**: HARDENED on CONVERTED is always a no-op on belief state (the grace-window regression rule activates only for PERSUADED and SOFTENED). No regression fires. `approach_count`, `approach_history`, and `cooldown_turns_remaining` still update normally. This is a wasted rival action — the bias turned a potentially regressive outcome into an ineffective one.

**If `grace_window_turns = 0` in config**: `recently_converted_turns_remaining` is set to 0 on every CONVERTED transition, and the eligibility check `> 0` never passes. The rival can never regress CONVERTED NPCs. This is a valid config that disables the grace-window mechanic entirely — not a bug. No special-case code needed.

**If `recently_converted_turns_remaining` decrements to 0 on the same turn as conversion** (when `grace_window_turns = 1`): the rival's eligibility check evaluates after `advance_turn()` (Step 3) runs, before the rival acts (Step 5). At `grace_window_turns = 1`, the field is decremented from 1 to 0 on the same turn as the conversion — the NPC is never in the rival's eligible pool. The rival gets zero attempts. Designers should use `grace_window_turns ≥ 2` to allow at least one rival opportunity after a conversion.

**If the rival exhausts an NPC's `approach_count` cap and then regresses that NPC**: after a rival-caused regression (CONVERTED→WAVERING), if `approach_count == max_approaches_per_npc`, the player cannot re-approach the NPC. The NPC remains WAVERING permanently — a rival victory. This is intentional: the rival spending an NPC's last approach on the turn of regression is a real, irrecoverable threat. Rival approach-count increment is not suppressed.

**If the rival's approach choice is the same approach the rival used on previous turns against the same NPC**: `approach_history[approach]` accumulates across both player and rival calls. When the player subsequently uses the same approach, the CLE applies the repeat penalty based on the combined history. The rival can degrade the player's probability for specific approaches on a given NPC. This is intentional. `approach_history` is not caller-tagged.

**If faith power should be refunded when the rival regresses a CONVERTED NPC**: faith power is never refunded. When `npc_state_changed(npc_id, CONVERTED, WAVERING)` fires, the GSM removes `npc_id` from `converted_ids` but does NOT subtract `faith_power_per_conversion`. Faith power and any policy unlocks earned from this conversion are permanent. The player loses only the NPC's current contribution to the win-condition count.

**If the player successfully re-converts a rival-regressed NPC**: because the GSM removed `npc_id` from `converted_ids` on regression, the converted-ids guard does not block the faith-power award. The player earns full `faith_power_per_conversion` again. Reclaiming a rival-regressed NPC counts as a new conversion for faith-power purposes.

**If the rival's `process_turn()` evaluates at Step 5 and an NPC was unlocked by Faith Spread at Step 4**: the rival's eligible pool is built at Step 5 call time, after Faith Spread has already fired. An NPC whose access gate was satisfied by a Step 4 conversion is eligible for rival targeting on that same turn. The player has no opportunity to act before the rival reaches this newly-unlocked NPC.

**If `aggression_interval_turns = 1`**: the rival acts every turn. At `grace_window_turns = 2`, each new convert has `recently_converted_turns_remaining = 2` after conversion, which decrements to 1 at Step 3 on the conversion turn — making the NPC eligible at Step 5 on the conversion turn. The rival gets exactly one shot per convert at this configuration. On the following turn, the window decrements to 0 and the NPC is no longer eligible.

**If a rival action fires at the exact turn a village would be won** (rival acts at Step 5, win check at Step 6): the rival regression fires before the win check. If the regression drops `converted_count` below `village_win_conversion_pct`, the win does not trigger that turn. The player must re-convert or convert another NPC on a future turn.

**If the village is already in VILLAGE_WON or VILLAGE_LOST state**: the GSM will not advance turns in these states, so `turn_advancing` will not fire. The rival cannot act in a resolved village.

**If `rival_acted` should be emitted when the rival acts but the outcome produces no belief state change** (e.g., a WAVERING NPC receives RESISTED): `rival_acted` is emitted unconditionally after `apply_conversion_outcome()` is called, regardless of whether a state transition occurred. Village Map View and HUD subscribe to `rival_acted` to mark rival activity — suppressing it on non-state-changing outcomes would make RESISTED results invisible, breaking the "you feel watched" experience.

## Dependencies

### Systems This System Depends On

| System | GDD | Type | Data Interface |
|---|---|---|---|
| NPC Character System | `npc-character-system.md` | **Hard** | `NPCRegistry.get_all_npcs()` (target pool construction), `apply_conversion_outcome(npc_id, outcome, approach, OutcomeCaller.RIVAL)` (outcome mutation). Requires cross-system updates to NpcRecord schema and `apply_conversion_outcome()` API before implementation (see Core Rule 11). |
| Conversion Logic Engine | `conversion-logic-engine.md` | **Hard** | `ConversionLogicEngine.resolve(approach, npc_id) → ConversionOutcome`. Called at most once per rival action turn. Uses the identical interface as the player — no custom rival formula. |
| NPC Trait Database | `npc-trait-database.md` | **Hard** | `TraitDatabase.get_affinity(trait_id, approach) → float`. Queried over `npc.assigned_traits` (full set, not just revealed) during approach scoring. |
| Game State Manager | `game-state-manager.md` | **Hard** | Subscribes to `turn_advancing` signal. Queries `get_turn_number()` for interval check. Requires GSM GDD update: `npc_state_changed` handler must remove `npc_id` from `converted_ids` on CONVERTED→WAVERING regression (see Core Rule 10). |
| Game Config / RivalFaithConfig | `game-config.md` | **Hard** | `GameConfig.rival.aggression_interval_turns`, `reharden_strength`, `counter_approach_random_weight`, `grace_window_turns`. Read at call time — not cached. |

### Systems That Depend On This System

| System | GDD | What It Uses |
|---|---|---|
| Village Map View | *(GDD pending)* | Subscribes to `rival_acted(npc_id, approach, outcome)` to display a rival-activity marker on the target NPC's portrait or map position. |
| HUD & Progress System | *(GDD pending)* | Subscribes to `rival_acted` if a rival activity indicator is displayed in the HUD. |
| Save & Load System | *(GDD pending)* | Nothing to serialize directly — RivalFaithSystem is stateless between turns. The rival's behavior is fully derived from GSM's `turn_number` (serialized by GSM) and NPCRegistry state (serialized by NPC Character System). |

### Bidirectional Consistency Note

The NPC Character System GDD (Interactions table) already lists the Rival Faith System as a caller of `apply_conversion_outcome()`. After implementation of Core Rule 11 updates, the NPC Character System GDD's API block and Rule 5 outcome table must also reference the `OutcomeCaller` parameter and the grace-window regression behavior.

## Tuning Knobs

### From `GameConfig.rival` (RivalFaithConfig — owned by this GDD)

| Knob | Default | Safe Range | Effect | What Breaks at Extremes |
|---|---|---|---|---|
| `aggression_interval_turns` | 3 | 1–5 | How often (in player turns) the rival acts. Lower = more frequent pressure. At 1, rival acts every turn. | Below 1: invalid (modulo 0 or always-true). Above 5: rival is imperceptible; converts feel permanent and wins feel unearned. |
| `reharden_strength` | 1.0 | 0.5–1.5 | Scales how likely the rival's CLE outcome is promoted toward HARDENED (above 1.0) or demoted toward PERSUADED (below 1.0). At 1.0: no bias — rival uses raw CLE math. | Below 0.5: rival almost never achieves HARDENED; pressure is very low. Above 1.5: 50% promotion rate; rival feels frustratingly effective and unpredictable. |
| `counter_approach_random_weight` | 0.0 | 0.0–0.40 | Probability the rival ignores Formula 1 and picks a random approach instead. At 0.0: rival always picks the best approach (legible, strategic). | Above 0.40: rival becomes erratic and unpredictable — feels arbitrary. At 1.0: rival is completely random; strategic depth is eliminated. |
| `grace_window_turns` | 2 | 0–5 | Turns after conversion during which the rival can regress CONVERTED NPCs. At 0: mechanic disabled. At 2: player has 1 full protected turn after the conversion turn (due to `advance_turn()` decrement firing before rival). | Above 5: converts feel perpetually vulnerable; winning feels impossible. At 1 or below: rival gets 0 effective shots per convert (see Edge Cases). |

### From `GameConfig.conversion` (owned by Game Config GDD — affects this system)

| Knob | Default | Safe Range | Relevant Effect on Rival |
|---|---|---|---|
| `approach_cooldown_turns` | 3 | 1–6 | Rival actions set the same cooldown on NPCs. Higher cooldown after a rival action creates a longer window of NPC unavailability for the player to counter. |
| `max_approaches_per_npc` | 5 | 3–8 | Rival actions count against this cap. Lower caps increase the risk of rival approach-exhaustion stranding a regressed NPC permanently. |

### Knob Interaction Warnings

**`grace_window_turns` × `aggression_interval_turns`:** The effective rival opportunity count per convert is approximately `floor((grace_window_turns - 1) / aggression_interval_turns)`. At defaults (grace=2, interval=3), the rival gets at most 1 shot per convert. At grace=4 and interval=1, the rival gets 3 shots per convert — very high pressure on newly converted NPCs. Tune these together.

**`reharden_strength` × omniscient approach scoring:** The rival's danger comes from two independent sources: accurate approach selection (Formula 1) plus outcome promotion bias (Formula 2). Setting `reharden_strength = 1.25` while using default omniscient selection creates a rival that is both accurate and has a 25% chance of promoting its outcome by one rank. Test both in combination, not in isolation.

## Visual/Audio Requirements

The Rival Faith System produces no visual or audio output directly. All player-facing indication of rival activity comes from downstream systems reacting to this system's signals and NPCRegistry state changes:

- **NPC belief state changes** (via `npc_state_changed` from NPCRegistry) drive the NPC Character System's Visual/Audio requirements — portrait expression shifts, map color changes, and cooldown overlays apply normally.
- **`rival_acted` signal** is the designated hook for Village Map View to render any rival-activity marker (e.g., a subtle indicator on the targeted NPC's portrait). The exact form of this marker is defined in the Village Map View GDD, not here.
- **No rival dialogue, no rival portrait, no rival audio.** The rival faith is an atmospheric presence felt through NPC reactions — not a visible character in the scene.

📌 **Asset Spec flag:** No assets owned by this system. Assets produced from rival activity (any marker, icon, or overlay on the village map) are specified in the Village Map View GDD.

## UI Requirements

The Rival Faith System has no UI of its own. It emits `rival_acted(npc_id, approach, outcome)` as the designated contract for UI systems to observe rival activity. All UI elements related to rival activity are owned by downstream systems:

- **Village Map View**: may render a rival-activity marker on the targeted NPC's portrait after `rival_acted` fires. Form and art direction defined in Village Map View GDD.
- **HUD & Progress System**: may display a rival activity counter or indicator. Defined in HUD & Progress System GDD.

This system exposes no query methods for UI consumption beyond the `rival_acted` signal.

## Acceptance Criteria

**AC-01 — Interval firing.** Given `aggression_interval_turns = 3`, the rival calls `apply_conversion_outcome()` exactly on turns 3, 6, 9, … and does not call it on any other turn. On turn 0 and on turns 1, 2, 4, 5, `process_turn()` returns without calling any NPCRegistry or CLE method.

**AC-02 — Target priority: CONVERTED before WAVERING before OPEN.** Given one eligible NPC in each state (CONVERTED within grace window, WAVERING, OPEN), the rival selects the CONVERTED NPC. If the CONVERTED NPC is removed, the rival selects the WAVERING NPC. If both are removed, it selects the OPEN NPC.

**AC-03 — Tie-breaking within a priority tier.** Given two WAVERING NPCs with `approach_count` values of 2 and 4, the rival selects the one with `approach_count = 2`. Given two WAVERING NPCs with equal `approach_count`, the rival selects the one with the lower index in `NPCRegistry.get_all_npcs()`.

**AC-04 — Omniscient approach selection.** Given an NPC with traits `bereaved` (GRIEF +1.0) and `ambitious` (AMBITION +1.0), where only `bereaved` has been revealed to the player (`revealed_traits = ["bereaved"]`), the rival scores both traits and selects the approach with the higher combined affinity — not the approach that only `bereaved` favors. The rival's approach choice matches the result of scoring over `assigned_traits`, not `revealed_traits`.

**AC-05 — Grace-window regression.** Given a CONVERTED NPC with `recently_converted_turns_remaining = 1` (after `advance_turn()` has already decremented it on the current turn), when the rival selects that NPC and the CLE returns PERSUADED or SOFTENED, `apply_conversion_outcome()` transitions the NPC from CONVERTED to WAVERING and `rival_acted` is emitted.

**AC-06 — Grace-window permanence.** Given a CONVERTED NPC with `recently_converted_turns_remaining = 0`, when the rival selects that NPC and the CLE returns PERSUADED or SOFTENED, belief state does not change — the NPC remains CONVERTED. `rival_acted` is still emitted. No regression occurs regardless of `reharden_strength`.

**AC-07 — `rival_acted` emitted on non-state-changing outcomes.** Given a WAVERING NPC that receives a RESISTED outcome from the rival (no belief state transition occurs), `rival_acted(npc_id, approach, RESISTED)` is still emitted. Village Map View and HUD can observe this outcome.

**AC-08 — `rival_acted` not emitted on skip.** Given no eligible targets (all NPCs STEADFAST, or all CONVERTED NPCs past the grace window with no WAVERING or OPEN remaining), `process_turn()` returns without emitting `rival_acted` and without calling `apply_conversion_outcome()`.

**AC-09 — Cooldown bypass.** Given an NPC with `cooldown_turns_remaining = 2` (player-imposed cooldown), the rival includes that NPC in its eligible pool and may select and act on it. The rival's `apply_conversion_outcome()` call resets `cooldown_turns_remaining` to `GameConfig.conversion.approach_cooldown_turns` — identical to a player action.

**AC-10 — Approach count shared.** After the rival acts on an NPC, that NPC's `approach_count` increments by 1 and the rival's chosen approach is appended to `approach_history`. When the player subsequently uses the same approach on that NPC, the CLE applies the repeat penalty based on the combined history including the rival's entry.

**AC-11 — `reharden_strength = 1.0` produces no bias.** Over 1000 simulated rival resolutions with `reharden_strength = 1.0`, the distribution of `final_outcome` matches the distribution of `cle_outcome` exactly (no promotion or demotion). `bias_trigger_probability = 0.0` — the bias branch never fires.

**AC-12 — Reharden bias direction.** Given `reharden_strength = 1.25` and a mocked RNG that always returns 0.10 (below the 0.25 trigger threshold), every CLE-returned SOFTENED outcome is promoted to RESISTED, and every RESISTED is promoted to HARDENED. Given `reharden_strength = 0.75` and the same RNG, every SOFTENED is demoted to PERSUADED, and PERSUADED is not demoted further.

**AC-13 — Faith power re-award on re-conversion.** When the rival regresses NPC X from CONVERTED to WAVERING, `npc_id X` is removed from GSM's `converted_ids`. When the player subsequently re-converts NPC X, the faith power award fires again — `faith_power_per_conversion` is added to the player's total. The re-conversion is not blocked by the converted-ids guard.

**AC-14 — No trait revelation.** `reveal_trait()` and `trigger_inspect_reveal()` are never called by `RivalFaithSystem` under any execution path. After any number of rival action turns, `revealed_traits` on all NPCs reflects only player-triggered reveals.

**AC-15 — No session state.** `RivalFaithSystem` holds no instance variables beyond its RNG seed. Two calls to `process_turn()` with identical GSM and NPCRegistry state (and identical RNG state) produce identical outputs. No data persists on the singleton between turns.

**AC-16 — Win check timing.** Given a village at `converted_count = win_threshold - 1`, where one remaining OPEN NPC converts at Step 4 (Faith Spread) and `converted_count` reaches `win_threshold`, the rival acts at Step 5 before the win check at Step 6. If the rival regresses the newly converted NPC, `converted_count` drops back below threshold and the village does not reach `VILLAGE_WON` that turn.

**AC-17 — Access gate enforcement.** Given an NPC with an `access_gate` whose `required_npc_ids` have not yet reached the required belief states, the rival does not include that NPC in its eligible pool. The NPC is skipped regardless of its own belief state.

## Open Questions

**OQ-01 — Multi-rival signal contract.** The architecture explicitly supports multiple rivals post-MVP "without architectural change," but `rival_acted(npc_id, approach, outcome)` carries no `rival_id` parameter, and the aggression interval is a single global value. Before adding a second rival, resolve: (a) does `rival_acted` need a `rival_id` field so Village Map View can distinguish which rival acted? (b) does each rival track its own turn interval independently, or do they share a single interval and alternate? Defer until post-MVP scope is defined.

**OQ-02 — Rival narrative identity at MVP.** The system is mechanically complete with no narrative identity — the rival faith has no name, no doctrine, and no visual representation. Village Map View will need to render some rival-activity marker (`rival_acted` hook). Confirm: is the rival intentionally anonymous at MVP (a mechanical pressure, not a named antagonist), or does Village Map View GDD need a placeholder name and icon to ship? If anonymous is intentional, document it as a design decision rather than leaving it implicit.
