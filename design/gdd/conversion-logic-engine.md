# Conversion Logic Engine

> **Status**: Complete
> **Author**: Design session + agents
> **Last Updated**: 2026-04-25
> **Implements Pillar**: Pillar 2 — Many Roads to the Divine; Pillar 4 — History Writes Itself

## Overview

The Conversion Logic Engine is a stateless computation layer that resolves a single question on behalf of the Dialogue & Conversion System: given a dialogue approach and a target NPC's trait set, what is the outcome of this conversion attempt? It takes as input the chosen `DialogueApproach`, the target NPC's `assigned_traits` (fetched from `NPCRegistry`), and the current game configuration, and returns one of four `ConversionOutcome` values — `PERSUADED`, `SOFTENED`, `RESISTED`, or `HARDENED`. It holds no runtime state — no knowledge of which NPC was just approached, no history of attempts, no cooldown tracking. Those concerns belong to the NPC Character System. The Engine owns exactly one thing: the math that translates the alignment between a dialogue approach and an NPC's trait affinities into a probability, and the mapping of that probability to an outcome through a single random roll against outcome thresholds.

The Engine exists because the conversion formula must be a single, auditable function. If conversion logic is distributed across multiple systems, two bugs become inevitable: an outcome calculated in one place and applied in another, with neither knowing the full picture. By centralising the formula here, the Dialogue & Conversion System and the Rival Faith System can both resolve conversion attempts through the same logic without duplicating it — and the formula can be unit-tested in complete isolation from all presentation and state systems.

## Player Fantasy

The Conversion Logic Engine exists so that every conversion outcome feels like a reading of a human soul — not a roll of dice. The player must be able to look at a HARDENED result and say *"I misjudged her"*, not *"the game cheated me."* This is the emotional contract the Engine upholds, invisibly, in every exchange.

The player fantasy at stake is the prophet who *sees people clearly*. When a GRIEF appeal lands with a Bereaved widow, the satisfaction is not "the dice were kind" — it is "I understood her." The player leans into each choice with genuine conviction: this approach, for this person, for this reason. The Engine is what makes that conviction meaningful. When it validates the player's read, the moment feels earned. When it doesn't — when the Proud Soldier receives FEAR and hardens — it is the Engine confirming what the player should have known: this person would not be threatened, and now she knows you tried.

That second moment is as important as the first. A HARDENED outcome is not punishment from an arbitrary system; it is the world maintaining its integrity. The Soldier has an inner life the player failed to honour, and the Engine is what makes that failure *stick* — permanent, legible, and the player's own. This is how Pillar 3 is delivered at the mechanical level: not through scripted tragedy, but through a formula that respects every NPC's internal logic enough to push back against approaches that violate it.

The system fails — and every downstream experience fails with it — if outcomes begin to feel like variance rather than character. A player who suspects the Engine of randomness stops trying to read people and starts trying to game probabilities. The prophet becomes a gambler. The character-driven core of the game dissolves. The Engine's sole responsibility is to prevent that dissolution: to be transparent enough that every outcome, in retrospect, was explicable.

## Detailed Design

### Core Rules

**1. The Engine is a pure function.** `ConversionLogicEngine.resolve(approach, npc_id)` takes a `DialogueApproach` and an NPC ID, reads the NPC's current state from `NPCRegistry` and trait affinities from `TraitDatabase`, computes a probability, makes a single random roll, and returns a `ConversionOutcome`. It writes nothing. It stores no state. Calling it twice with identical inputs and the same RNG seed returns identical results.

**2. Inputs.** The Engine reads the following at resolve time:

| Input | Source | Description |
|---|---|---|
| `approach` | Caller | The `DialogueApproach` being used (GRIEF / AMBITION / DOUBT / FEAR) |
| `npc.assigned_traits` | `NPCRegistry.get_npc(npc_id)` | Full list of trait IDs, revealed and hidden |
| `npc.belief_state` | `NPCRegistry.get_npc(npc_id)` | Current `BeliefState` (STEADFAST / OPEN / WAVERING) |
| `npc.approach_history` | `NPCRegistry.get_npc(npc_id)` | `Dictionary[DialogueApproach → int]` — how many times each approach has been used |
| `A(t, a)` per trait | `TraitDatabase.get_affinity(trait_id, approach)` | Affinity float in [-1.0, 1.0] per trait |
| All tuning values | `GameConfig.conversion.*` | `base_success_chance`, `trait_modifier_weight`, `trait_modifier_cap`, belief modifiers, outcome band fractions, repeat penalty values, floor, ceiling |

**3. Probability computation.** The Engine computes the final success probability in four additive steps:

- **Step 1 — Trait modifier subtotal:** For each trait in `npc.assigned_traits`, compute `A(trait_id, approach) × trait_modifier_weight`. Sum all results. Clamp the subtotal to `[-trait_modifier_cap, +trait_modifier_cap]`.
- **Step 2 — Belief state modifier:** Add `belief_modifier[npc.belief_state]` — a fixed float looked up from `GameConfig.conversion` (STEADFAST: 0.0, OPEN: +0.10, WAVERING: +0.20).
- **Step 3 — Repeat approach penalty:** Read `npc.approach_history.get(approach, 0)`. Subtract `min(repeat_count × repeat_penalty_per_use, max_repeat_penalty)`.
- **Step 4 — Clamp:** `P_final = clamp(base_success_chance + step1 + step2 - step3, min_success_chance, max_success_chance)`.

**4. Outcome resolution.** A single uniform random roll determines the outcome. The four outcomes occupy contiguous zones on [0.0, 1.0), derived dynamically from `P_final`:

```
P_remaining = 1.0 - P_final
P_softened  = P_remaining × softened_band_fraction
P_resisted  = P_remaining × resisted_band_fraction
P_hardened  = P_remaining - P_softened - P_resisted

roll = random_float(0.0, 1.0)

if roll < P_final:                                    → PERSUADED
elif roll < P_final + P_softened:                     → SOFTENED
elif roll < P_final + P_softened + P_resisted:        → RESISTED
else:                                                 → HARDENED
```

Dynamic band sizing ensures the four zones always sum to 1.0, and `P_hardened` shrinks toward 0 as `P_final` approaches `max_success_chance` — a perfectly aligned approach on a WAVERING NPC essentially never hardens them.

**5. The Engine does not validate approachability.** It will resolve a conversion for any NPC ID it receives. Approachability gating (cooldown, access gate, max approach count) is enforced by the caller before invoking the Engine. Calling the Engine on a locked or cooldown-gated NPC is a caller error; the Engine returns a valid outcome regardless.

**6. The Engine does not apply the outcome.** After `resolve()` returns, the caller is responsible for passing the result to `NPCRegistry.apply_conversion_outcome()`. The Engine's job ends at the return value.

---

### States and Transitions

The Conversion Logic Engine is **stateless**. It has no internal state machine, no persistent data, and no lifecycle phases. Every call to `resolve()` is independent of all prior calls. State lives in `NPCRegistry` (belief state, approach history) and `GameConfig` (tuning values); the Engine only reads from both.

---

### Interactions with Other Systems

| System | Relationship | Data Flow |
|---|---|---|
| NPC Trait Database | Upstream dependency | Engine calls `TraitDatabase.get_affinity(trait_id, approach)` for each of the NPC's traits on every `resolve()` call |
| NPC Character System (`NPCRegistry`) | Upstream dependency | Engine calls `NPCRegistry.get_npc(npc_id)` to obtain `assigned_traits`, `belief_state`, and `approach_history` |
| Game Config (`ConversionConfig`) | Upstream dependency | Engine reads all tuning values at resolve time — never cached between calls |
| Dialogue & Conversion System | Downstream caller | Calls `resolve(approach, npc_id)` on the player's behalf after approach selection; passes the returned `ConversionOutcome` to `NPCRegistry.apply_conversion_outcome()` |
| Rival Faith System | Downstream caller | Calls `resolve(approach, npc_id)` on the rival's behalf; identical interface to Dialogue & Conversion System |
| Dialogue Content Database | No relationship | The Engine returns only a `ConversionOutcome` enum value — no text is read or produced |
| Save & Load System | No relationship | The Engine holds no state; nothing to serialize |

**Exposed API:**

```gdscript
# ConversionLogicEngine (Autoload singleton)
func resolve(approach: DialogueApproach, npc_id: String) -> ConversionOutcome
```

## Formulas

### Formula 1 — Trait Modifier Subtotal

```
trait_subtotal = clamp(Σ [A(tᵢ, a) × W]  for i = 1..N,  −T_cap,  +T_cap)
```

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `A(tᵢ, a)` | Base affinity | float | {-1.0, -0.5, 0.0, +0.5, +1.0} | Affinity of trait `tᵢ` for approach `a`. Read via `TraitDatabase.get_affinity(tᵢ, a)`. Five discrete bands only. |
| `W` | Trait modifier weight | float | [0.0, 1.0] | Global scaling factor. `GameConfig.conversion.trait_modifier_weight`. Default: **0.25**. |
| `N` | Trait count | int | [2, 4] | Number of traits in `npc.assigned_traits`. |
| `T_cap` | Trait modifier cap | float | [0.10, 0.75] | Maximum absolute contribution from trait stacking. `GameConfig.conversion.trait_modifier_cap`. Default: **0.50**. |
| `trait_subtotal` | Clamped trait modifier | float | [-0.50, +0.50] | Net additive trait modifier added to base probability. |

**Output range:** [-0.50, +0.50] at default `T_cap`. Without the cap, four fully-aligned traits at W=0.25 could contribute +1.0; the cap limits this to +0.50, preventing any single approach from dominating.

**Worked example — Widow, GRIEF approach, 4 traits:**
- `bereaved` +1.0 GRIEF: 1.0 × 0.25 = +0.25
- `lonely` +1.0 GRIEF: 1.0 × 0.25 = +0.25
- `mortal_minded` +0.5 GRIEF: 0.5 × 0.25 = +0.125
- `superstitious` 0.0 GRIEF: 0.0 × 0.25 = 0.0
- Sum = +0.625 → clamped to **+0.50**

---

### Formula 2 — Belief State Modifier

```
belief_modifier = B_table[npc.belief_state]
```

**Variables:**

| Symbol | Name | Type | Value | Description |
|---|---|---|---|---|
| `B_table[STEADFAST]` | Steadfast modifier | float | **0.0** | Baseline — no modification. |
| `B_table[OPEN]` | Open modifier | float | **+0.10** | `GameConfig.conversion.belief_modifier_open`. NPC is receptive; first crack in the wall. |
| `B_table[WAVERING]` | Wavering modifier | float | **+0.20** | `GameConfig.conversion.belief_modifier_wavering`. NPC is between worlds — meaningfully easier to move. |
| `belief_modifier` | Output | float | {0.0, +0.10, +0.20} | Additive contribution to `P_raw`. |

**Design note:** WAVERING +0.20 is just under one strong-affinity trait (+0.25), preserving the primacy of trait-reading. A WAVERING NPC with a mismatched approach is still harder to convert than a STEADFAST NPC with a perfectly matched approach.

---

### Formula 3 — Repeat Approach Penalty

```
repeat_penalty = min(approach_history[approach] × repeat_penalty_per_use,  max_repeat_penalty)
```

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `approach_history[approach]` | Prior use count | int | [0, max_approaches_per_npc] | Number of times this approach has been used on this NPC. Read from `npc.approach_history`. 0 if never used. |
| `repeat_penalty_per_use` | Per-use cost | float | [0.0, 0.15] | `GameConfig.conversion.repeat_penalty_per_use`. Default: **0.05**. |
| `max_repeat_penalty` | Penalty ceiling | float | [0.0, 0.30] | `GameConfig.conversion.max_repeat_penalty`. Default: **0.15**. Penalty caps after 3 uses. |
| `repeat_penalty` | Output | float | [0.0, max_repeat_penalty] | Subtractive modifier on `P_raw`. |

**Worked example:** Using GRIEF for the 4th time: `min(4 × 0.05, 0.15) = min(0.20, 0.15) = 0.15` (cap reached at 3rd use).

---

### Formula 4 — Final Conversion Probability

```
P_raw   = base_success_chance + trait_subtotal + belief_modifier − repeat_penalty
P_final = clamp(P_raw,  min_success_chance,  max_success_chance)
```

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `base_success_chance` | Base probability | float | [0.05, 0.95] | `GameConfig.conversion.base_success_chance`. Default: **0.35**. Probability at neutral traits, STEADFAST, no repeats. |
| `trait_subtotal` | Trait contribution | float | [-0.50, +0.50] | Output of Formula 1. |
| `belief_modifier` | Belief contribution | float | {0.0, +0.10, +0.20} | Output of Formula 2. |
| `repeat_penalty` | Repeat cost | float | [0.0, 0.15] | Output of Formula 3. |
| `min_success_chance` | Probability floor | float | [0.01, 0.20] | `GameConfig.conversion.min_success_chance`. Default: **0.05**. No approach is ever futile. |
| `max_success_chance` | Probability ceiling | float | [0.50, 1.00] | `GameConfig.conversion.max_success_chance`. Default: **0.80**. No conversion is ever guaranteed. |
| `P_final` | Final probability | float | [0.05, 0.80] | Input to the outcome roll. |

**Drama space at key P_final values (defaults):**

| P_final | PERSUADED | SOFTENED | RESISTED | HARDENED |
|---|---|---|---|---|
| 0.05 (worst) | 5% | 27% | 23% | 45% |
| 0.35 (neutral) | 35% | 18% | 15% | 32% |
| 0.55 (good fit) | 55% | 12% | 10% | 23% |
| 0.80 (ceiling) | 80% | 11% | 9% | 0% |

---

### Formula 5 — Outcome Resolution

```
P_remaining = 1.0 − P_final
P_softened  = P_remaining × softened_band_fraction
P_resisted  = P_remaining × resisted_band_fraction
P_hardened  = P_remaining − P_softened − P_resisted

roll = random_float(0.0, 1.0)

PERSUADED  if roll < P_final
SOFTENED   elif roll < P_final + P_softened
RESISTED   elif roll < P_final + P_softened + P_resisted
HARDENED   otherwise
```

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `softened_band_fraction` | SOFTENED fraction | float | [0.20, 0.70] | `GameConfig.conversion.softened_band_fraction`. Default: **0.545**. Share of failure space allocated to SOFTENED. |
| `resisted_band_fraction` | RESISTED fraction | float | [0.20, 0.70] | `GameConfig.conversion.resisted_band_fraction`. Default: **0.455**. Share of failure space allocated to RESISTED. Constraint: fractions must sum ≤ 1.0; HARDENED takes the remainder. |
| `roll` | Random roll | float | [0.0, 1.0) | Single uniform draw. The only source of randomness in the Engine. |

**Constraint:** `softened_band_fraction + resisted_band_fraction` must be < 1.0. At defaults (0.545 + 0.455 = 1.0), HARDENED gets only the floating-point remainder when P_final > 0. When P_final = 0.80, HARDENED zone = 0% — HARDENED is impossible at the ceiling.

**Minimum path to conversion** (base = 0.35, neutral traits, no belief modifier, no repeats): Three PERSUADED outcomes required (STEADFAST→OPEN→WAVERING→CONVERTED). Probability of a perfect 3-step chain: 0.35 × 0.45 × 0.55 ≈ **8.7%**. An experienced player reading traits well (P_final ≈ 0.65 per step): 0.65 × 0.70 × 0.75 ≈ **34%**.

## Edge Cases

**EC-1. Floating-point negative HARDENED zone.**
If `softened_band_fraction + resisted_band_fraction` produces a value of 1.0000000001 due to IEEE 754 rounding, `P_hardened` becomes a tiny negative number. The threshold comparison would then incorrectly catch rolls in an impossible zone. Resolution: `P_hardened = max(0.0, P_remaining − P_softened − P_resisted)`. The HARDENED zone is always floor-clamped to 0.0 before any threshold comparison.

**EC-2. Band fractions misconfigured to sum above 1.0.**
If a designer sets `softened_band_fraction + resisted_band_fraction > 1.0`, `P_hardened` is negative before EC-1 applies. Resolution: At the start of every `resolve()` call, validate that the sum is ≤ 1.0. If violated, log an error and clamp `resisted_band_fraction` to `1.0 − softened_band_fraction`, then proceed. Config is read fresh each call, so live tuning changes take immediate effect.

**EC-3. `npc_id` not found in `NPCRegistry`.**
`NPCRegistry.get_npc(npc_id)` returns `null` (per NPC Character System E14). Resolution: Null-check the `NpcRecord` immediately after the call. If null: log an error identifying the invalid ID and return `ConversionOutcome.RESISTED` as a safe sentinel. `RESISTED` is the only safe default — it produces no state side-effects when passed to `apply_conversion_outcome()`. `PERSUADED` would advance a non-existent NPC; `HARDENED` would regress one. This is a caller contract violation; `RESISTED` is a sentinel, not a meaningful gameplay result.

**EC-4. `resolve()` called on a CONVERTED NPC.**
`get_approachable_npcs()` excludes CONVERTED NPCs, but the Engine does not enforce approachability (Core Rule 5). `CONVERTED` is not a valid key in `B_table` (which covers only STEADFAST / OPEN / WAVERING). Resolution: If `belief_state == CONVERTED`, treat as STEADFAST (modifier 0.0) and log a warning. The `apply_conversion_outcome()` call downstream applies a no-op regardless — downstream no-op enforcement is the NPC Character System's responsibility.

**EC-5. `GameConfig.conversion` fields missing or null.**
A malformed `ConversionConfig` resource could return null for any required field. Resolution: Validate all GameConfig reads at the top of `resolve()` before any arithmetic. If any required field is null or outside its documented range, log an error and return `RESISTED`. Validation is a single pass at entry — null-checks are not scattered across formula steps.

**EC-6. `npc.assigned_traits` is empty.**
Theoretically prevented by `traits_per_npc_min = 2`, but possible via save deserialization corruption. Resolution: The sum in Formula 1 over an empty array yields 0.0. `trait_subtotal = clamp(0.0, −0.50, +0.50) = 0.0`. The Engine proceeds on base probability alone — the formula degrades cleanly to the neutral-trait case.

**EC-7. `trait_modifier_weight` (`W`) set to 0.0 via `GameConfig`.**
Formula 1 returns `trait_subtotal = 0.0` for any trait combination. Traits become cosmetic. This is valid configuration (a documented tuning extreme). The Engine does not warn against it.

**EC-8. `apply_conversion_outcome()` never called after `resolve()` returns.**
If the caller exits early between `resolve()` and `apply_conversion_outcome()`, the NPC's `approach_history` and `cooldown_turns_remaining` are not updated. The stale `approach_history` means the next `resolve()` call for this approach underestimates the repeat penalty. Resolution: The Engine is stateless — no inconsistency occurs within it. The Dialogue & Conversion System must guarantee `apply_conversion_outcome()` is always called in a finally-equivalent block after `resolve()`.

**EC-9. Invalid `approach` value passed by caller.**
A caller passes an approach value not in `{GRIEF, AMBITION, DOUBT, FEAR}`. Resolution: Validate the `approach` parameter is a valid `DialogueApproach` enum member at entry. If invalid, log an error and return `RESISTED`. `TraitDatabase.get_affinity()` would return 0.0 for unknown approaches anyway, but the validation prevents a misleading result from being silently treated as a neutral-trait resolution.

**EC-10. Roll lands exactly on a zone boundary.**
`if roll < P_final` uses strict less-than. A roll of exactly `P_final` falls into SOFTENED, not PERSUADED. This is correct — all zone comparisons use strict `<`, so each boundary belongs to the zone above it. Implementers must not use `<=` for the first comparison.

**EC-11. RESISTED is the only outcome with no benefit.**
RESISTED is the only outcome that increments `approach_count` and sets `cooldown_turns_remaining` while providing neither a trait reveal nor a belief state advance. The Engine returns `RESISTED` and downstream systems apply no state changes. A RESISTED result is a spent approach with no return — not a neutral probe.

**EC-12. Ceiling is always maintained — no approach guarantees conversion.**
Maximum possible `P_raw`: `0.35 (base) + 0.50 (trait cap) + 0.20 (WAVERING) − 0.0 (no repeats) = 1.05` → clamped to `0.80`. At `P_final = 0.80`, PERSUADED is 80%, HARDENED is 0%, and SOFTENED + RESISTED together hold 20%. No approach against any NPC in any state can exceed `P_final = 0.80`. The 20% non-PERSUADED space at the ceiling is the game's guarantee that conversion always requires some faith.

**EC-13. "Reset to farm" exploit bounded by `max_approaches_per_npc`.**
A player could theoretically HARDEN a WAVERING NPC (using a worst-case mismatched approach at `P_final ≈ 0.05`, producing ~43% HARDENED probability) and re-convert to WAVERING, cycling for narrative beats. Resolution: `max_approaches_per_npc = 5` is the structural safeguard. Reaching WAVERING requires at least 3 approaches; a HARDENED regression consumes a 4th, leaving at most 1 before the NPC is permanently exhausted. The exploit is bounded by the NPC Character System's approach counter, not by the Engine.

## Dependencies

### Systems This System Depends On

| System | GDD | Dependency |
|---|---|---|
| NPC Trait Database | `npc-trait-database.md` | Provides `TraitDatabase.get_affinity(trait_id, approach)` — called for every trait on every `resolve()`. Hard dependency: without it, Formula 1 cannot execute. |
| NPC Character System | `npc-character-system.md` | Provides `NPCRegistry.get_npc(npc_id)` — supplies `assigned_traits`, `belief_state`, and `approach_history`. Hard dependency: without it, the Engine has no NPC data to operate on. |
| Game Config | `game-config.md` | Provides all `ConversionConfig` tuning values. Hard dependency: without it, the Engine cannot compute any probability. |
| Dialogue Content Database | `dialogue-content-database.md` | Defines `ConversionOutcome` and `DialogueApproach` enums consumed by `resolve()`'s signature and return type. Soft dependency at runtime — no data is read from the database; only the enum definitions are shared. |

---

### Systems That Depend On This System

| System | GDD | What it uses |
|---|---|---|
| Dialogue & Conversion System | *(GDD pending)* | Primary caller. Calls `resolve(approach, npc_id)` after the player selects an approach. Passes the returned `ConversionOutcome` to `NPCRegistry.apply_conversion_outcome()`. |
| Rival Faith System | *(GDD pending)* | Secondary caller. Calls `resolve(approach, npc_id)` to determine rival conversion attempts. Uses the identical interface as Dialogue & Conversion System. |

---

### Architectural Note

The Engine is intentionally positioned between the data layer (NPC Trait Database, NPC Character System, Game Config) and the orchestration layer (Dialogue & Conversion System, Rival Faith System). This placement ensures:
- The formula is testable in isolation — all inputs can be mocked without standing up any presentation system
- Both callers (player and rival) use identical conversion logic — no divergence between player and AI conversion math
- Adding a third caller (e.g., a future Event System that triggers miraculous conversions) requires no changes to the Engine

## Tuning Knobs

All tuning values live in `GameConfig.conversion` (`ConversionConfig` resource). This system reads them all at resolve time — nothing is cached. The knobs below are defined by this GDD and must be added to the Game Config GDD.

### Probability Shape Knobs

| Knob | GameConfig Field | Default | Safe Range | Effect |
|---|---|---|---|---|
| Base success chance | `base_success_chance` | 0.35 | 0.20–0.55 | Neutral-state probability — no trait alignment, STEADFAST, first attempt. Above 0.45 feels generous; below 0.25 makes cold-approach attempts punishing. Already in Game Config GDD. |
| Trait modifier weight | `trait_modifier_weight` | 0.25 | 0.10–0.40 | Strength of each trait affinity contribution. At 0.0 traits are cosmetic; at 0.40 a single +1.0 trait contributes +0.40. Already in Game Config GDD. |
| Trait modifier cap | `trait_modifier_cap` | 0.50 | 0.25–0.75 | Maximum total shift from trait stacking, regardless of how many traits align. Below 0.25, perfect trait alignment barely moves the needle. Above 0.75, three aligned traits push into near-certain territory before belief state is factored in. **New field.** |
| Probability floor | `min_success_chance` | 0.05 | 0.01–0.15 | Minimum P_final — no approach is ever futile. Below 0.02 feels cruel; above 0.15 undermines HARDENED risk on mismatched approaches. **New field.** |
| Probability ceiling | `max_success_chance` | 0.80 | 0.65–0.95 | Maximum P_final — no conversion is ever guaranteed. The 20% gap at ceiling is the game's faith requirement. Below 0.65 makes excellent play feel unrewarding; above 0.90 trivialises skilled conversion. **New field.** |

### Belief State Modifier Knobs

| Knob | GameConfig Field | Default | Safe Range | Effect |
|---|---|---|---|---|
| OPEN modifier | `belief_modifier_open` | +0.10 | 0.0–0.25 | Probability bonus when NPC is OPEN. At 0.0 belief states have no mechanical effect. **New field.** |
| WAVERING modifier | `belief_modifier_wavering` | +0.20 | 0.05–0.35 | Probability bonus when NPC is WAVERING. Must always be ≥ `belief_modifier_open`; if equal, the escalating drama of the WAVERING state is lost. **New field.** |

### Outcome Band Knobs

| Knob | GameConfig Field | Default | Safe Range | Effect |
|---|---|---|---|---|
| SOFTENED band fraction | `softened_band_fraction` | 0.545 | 0.30–0.70 | Share of failure space allocated to SOFTENED. Higher = SOFTENED is the dominant failure; lower pushes failures toward RESISTED and HARDENED. Must sum with `resisted_band_fraction` ≤ 1.0. **New field.** |
| RESISTED band fraction | `resisted_band_fraction` | 0.455 | 0.20–0.60 | Share of failure space allocated to RESISTED. At very low values (< 0.20) HARDENED becomes nearly as common as RESISTED, which feels cruel for reasonable approach choices. **New field.** |

### Repeat Approach Penalty Knobs

| Knob | GameConfig Field | Default | Safe Range | Effect |
|---|---|---|---|---|
| Penalty per repeat use | `repeat_penalty_per_use` | 0.05 | 0.0–0.12 | Probability reduction per additional use of the same approach. At 0.0 mono-approach spam has no mechanical cost. **New field.** |
| Maximum repeat penalty | `max_repeat_penalty` | 0.15 | 0.0–0.30 | Ceiling on total repeat penalty. At 0.30 repeated approaches suffer a 30-point hit — severe enough to invalidate a strong approach after 3 uses. **New field.** |

### Hard Mode Modifier

| Knob | GameConfig Field | Default | Safe Range | Effect |
|---|---|---|---|---|
| Hard mode base modifier | `hard_mode_base_modifier` | 0.80 | 0.50–1.00 | Multiplicative scalar on `base_success_chance` in hard mode only: `0.35 × 0.80 = 0.28`. Makes cold-approach harder while keeping the trait-reading reward intact. Already in Game Config GDD. |

### Interaction Warnings

- Raising `trait_modifier_weight` above 0.35 while keeping `trait_modifier_cap` at 0.50 makes the cap bite on 2-trait NPCs instead of 3 — traits feel dominant earlier.
- If `belief_modifier_wavering > max_success_chance − base_success_chance − trait_modifier_cap` (currently 0.80 − 0.35 − 0.50 = −0.05), a WAVERING modifier alone can push a neutral-trait NPC past the ceiling, making trait reading irrelevant for WAVERING NPCs.
- `softened_band_fraction + resisted_band_fraction` must remain ≤ 1.0 at all times. Validated at runtime on every `resolve()` call (see EC-2).

## Acceptance Criteria

All criteria are unit-testable in isolation. The Engine is a pure function — every criterion below can be verified by calling `resolve()` with controlled inputs and a fixed RNG seed, then asserting the returned `ConversionOutcome`.

---

### AC-1. Pure Function Contract

| ID | Criterion | Pass Condition |
|---|---|---|
| AC-1.1 | Determinism | Calling `resolve(approach, npc_id)` twice with the same RNG seed and unchanged `NPCRegistry` / `GameConfig` returns the identical `ConversionOutcome` both times. |
| AC-1.2 | No state written | After any `resolve()` call, `NPCRegistry.get_npc(npc_id)` returns an identical record to the one before the call — belief state, approach history, and cooldown are all unchanged. |
| AC-1.3 | No side effects on GameConfig | All `GameConfig.conversion` fields read identically before and after a `resolve()` call. |

---

### AC-2. Formula 1 — Trait Modifier Subtotal

| ID | Criterion | Pass Condition |
|---|---|---|
| AC-2.1 | Single aligned trait | NPC with one trait at affinity +1.0, `W = 0.25`, `T_cap = 0.50` → `trait_subtotal = +0.25`. |
| AC-2.2 | Stacking — no cap | NPC with two traits at +1.0 each, `W = 0.25`, `T_cap = 0.50` → `trait_subtotal = +0.50` (sum = 0.50, no clamping). |
| AC-2.3 | Stacking — cap reached | NPC with four traits all at +1.0, `W = 0.25`, `T_cap = 0.50` → `trait_subtotal = +0.50` (sum = 1.0, clamped to cap). |
| AC-2.4 | Negative cap | NPC with four traits all at −1.0, `W = 0.25`, `T_cap = 0.50` → `trait_subtotal = −0.50`. |
| AC-2.5 | Zero affinity | NPC with any number of traits all at 0.0 → `trait_subtotal = 0.0`. |
| AC-2.6 | Empty trait list (EC-6) | NPC with `assigned_traits = []` → `trait_subtotal = 0.0`; `resolve()` completes without error. |
| AC-2.7 | Worked example (Widow / GRIEF) | NPC with traits `bereaved (+1.0), lonely (+1.0), mortal_minded (+0.5), superstitious (0.0)` against GRIEF, defaults → `trait_subtotal = +0.50` (sum 0.625, clamped). |

---

### AC-3. Formula 2 — Belief State Modifier

| ID | Criterion | Pass Condition |
|---|---|---|
| AC-3.1 | STEADFAST | `belief_state = STEADFAST` → `belief_modifier = 0.0`. |
| AC-3.2 | OPEN | `belief_state = OPEN`, defaults → `belief_modifier = +0.10`. |
| AC-3.3 | WAVERING | `belief_state = WAVERING`, defaults → `belief_modifier = +0.20`. |
| AC-3.4 | CONVERTED fallback (EC-4) | `belief_state = CONVERTED` → `belief_modifier = 0.0`; a warning is logged; `resolve()` returns a valid `ConversionOutcome`. |

---

### AC-4. Formula 3 — Repeat Approach Penalty

| ID | Criterion | Pass Condition |
|---|---|---|
| AC-4.1 | First use (no penalty) | `approach_history[approach] = 0`, defaults → `repeat_penalty = 0.0`. |
| AC-4.2 | Second use | `approach_history[approach] = 1`, `repeat_penalty_per_use = 0.05`, `max_repeat_penalty = 0.15` → `repeat_penalty = 0.05`. |
| AC-4.3 | Cap at third use | `approach_history[approach] = 3`, defaults → `repeat_penalty = min(0.15, 0.15) = 0.15` (cap reached). |
| AC-4.4 | Cap holds beyond third use | `approach_history[approach] = 10`, defaults → `repeat_penalty = 0.15` (cap does not increase). |
| AC-4.5 | Zero weight configured | `repeat_penalty_per_use = 0.0` → `repeat_penalty = 0.0` regardless of use count. |

---

### AC-5. Formula 4 — Final Conversion Probability

| ID | Criterion | Pass Condition |
|---|---|---|
| AC-5.1 | Neutral baseline | Default config, STEADFAST, zero-affinity traits, first use → `P_final = 0.35`. |
| AC-5.2 | Floor enforced | Config producing `P_raw < 0.05` (default floor) → `P_final = 0.05`. |
| AC-5.3 | Ceiling enforced | Config producing `P_raw > 0.80` (default ceiling) → `P_final = 0.80`. |
| AC-5.4 | Maximum theoretical P_raw | `base = 0.35, trait_subtotal = +0.50, belief = +0.20, repeat = 0.0` → `P_raw = 1.05` → `P_final = 0.80` (ceiling). |
| AC-5.5 | Minimum theoretical P_raw | `base = 0.35, trait_subtotal = −0.50, belief = 0.0, repeat = 0.15` → `P_raw = −0.30` → `P_final = 0.05` (floor). |
| AC-5.6 | All four components sum correctly | A calculated example with known non-zero values for all four inputs returns the expected `P_final` within floating-point tolerance (±0.0001). |

---

### AC-6. Formula 5 — Outcome Resolution

| ID | Criterion | Pass Condition |
|---|---|---|
| AC-6.1 | PERSUADED zone | `P_final = 0.60`, roll = 0.50 → `PERSUADED`. |
| AC-6.2 | SOFTENED zone | `P_final = 0.60`, defaults; roll lands in `[0.60, 0.60 + P_softened)` → `SOFTENED`. |
| AC-6.3 | RESISTED zone | `P_final = 0.60`, defaults; roll lands in `[0.60 + P_softened, 0.60 + P_softened + P_resisted)` → `RESISTED`. |
| AC-6.4 | HARDENED zone | `P_final = 0.05` (floor), defaults; roll = 0.99 → `HARDENED`. |
| AC-6.5 | HARDENED impossible at ceiling | `P_final = 0.80`, `softened + resisted fractions = 1.0` (defaults) → roll of any value produces `PERSUADED`, `SOFTENED`, or `RESISTED` only. Repeat across 1000 seeded rolls: no `HARDENED` returned. |
| AC-6.6 | Boundary — PERSUADED/SOFTENED | Roll = exactly `P_final` → `SOFTENED` (strict `<` on first comparison). |
| AC-6.7 | Four outcomes cover full range | Across 10,000 seeded rolls at `P_final = 0.35` (defaults), all four `ConversionOutcome` values appear and the empirical distribution matches expected bands within ±3%. |

---

### AC-7. Edge Case Handling

| ID | Criterion | Pass Condition |
|---|---|---|
| AC-7.1 | EC-1: Negative HARDENED zone | `softened + resisted = 1.0000000001` (float rounding) → `P_hardened` is floor-clamped to 0.0; no `HARDENED` returned; no crash. |
| AC-7.2 | EC-2: Band fractions > 1.0 | `softened_band_fraction = 0.7, resisted_band_fraction = 0.7` → an error is logged; `resisted_band_fraction` is clamped to `0.30` before computation; `resolve()` returns a valid outcome. |
| AC-7.3 | EC-3: Unknown NPC ID | `resolve(approach, "nonexistent_id")` → an error is logged identifying the ID; returns `ConversionOutcome.RESISTED`. |
| AC-7.4 | EC-5: Null GameConfig field | Any required `GameConfig.conversion` field set to null → an error is logged; returns `ConversionOutcome.RESISTED`. |
| AC-7.5 | EC-9: Invalid approach value | Passing an out-of-enum approach value → an error is logged; returns `ConversionOutcome.RESISTED`. |
| AC-7.6 | EC-10: Boundary ownership | Roll = exactly `P_final` → `SOFTENED`, not `PERSUADED` (strict `<` behaviour confirmed). |

---

### AC-8. API Contract

| ID | Criterion | Pass Condition |
|---|---|---|
| AC-8.1 | Signature | `ConversionLogicEngine.resolve(approach: DialogueApproach, npc_id: String) -> ConversionOutcome` compiles and is callable from GDScript without type errors. |
| AC-8.2 | Autoload availability | `ConversionLogicEngine.resolve(...)` is callable from any script in the project without additional imports or scene dependencies. |
| AC-8.3 | Both callers succeed | The Engine can be called from a Dialogue & Conversion System stub and a Rival Faith System stub in the same test run without conflict or shared state leakage between calls. |
| AC-8.4 | GameConfig read-at-call-time | Changing a `GameConfig.conversion` field between two `resolve()` calls with identical NPC inputs produces a different `P_final` in the second call, confirming values are not cached. |
