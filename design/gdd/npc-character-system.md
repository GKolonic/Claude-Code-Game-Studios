# NPC Character System

> **Status**: Complete
> **Author**: Design session + agents
> **Last Updated**: 2026-08-09
> **Implements Pillar**: Pillar 1 — Every Soul Has a Story; Pillar 4 — History Writes Itself

## Overview

The NPC Character System is the runtime data layer that gives every NPC in The Faithful an individual identity. It creates, stores, and exposes the per-NPC record that all other character-aware systems read from: the NPC's archetype, their assigned traits and hidden/revealed state, their current belief state, their social connections to neighboring NPCs, and their conversion cooldown state. The system owns NPC lifecycle — it instantiates a new NPC record at scene load using the trait assignment procedure defined in the NPC Trait Database, and it updates NPC state in response to conversion outcomes reported by the Dialogue & Conversion System. It exposes a typed GDScript API (`NPCRegistry`) that other systems call to look up individual NPCs, query their current belief state, and iterate over the village population. It holds no presentation logic and no dialogue content — it is a structured data store with controlled mutation. The system exists because every downstream system (Dialogue, Portrait, Faith Spread, Save/Load, Village Map, and the macro-layer Follower Economy) needs a single authoritative description of who an NPC is and what state they are in. Duplicating or distributing that data across systems would cause synchronisation failures; centralising it here ensures that a conversion is reflected everywhere simultaneously.

## Player Fantasy

A narrative strategy game lives or dies on a single question: does the player believe the characters are real? Not cinematically real — systemically real. The NPC Character System is how The Faithful answers yes to that question.

When the player approaches a proud soldier and reads a trait list that mentions a fallen brother, the game is making a promise: this man is tracked, remembered, and irreversibly his own person. When that soldier resists a grief appeal — because pride is in the way of grief — and then later softens after a converted Elder speaks well of the faith, that promise is kept. The player doesn't think about social connections graphs or belief state mutations. They think: *of course. He respected that man.*

This system is working when the player pauses before each new NPC portrait and wants to read who this person is — not what stats they represent. It is working when a failed conversion feels like a failure with a specific human being, not a dice roll: the player can explain why they failed. It is working when players tell stories about their runs using names, not mechanics: "the merchant was the key — once she converted, the whole market quarter opened up."

The system fails — and the game fails with it — if NPC records are shallow enough that any two soldiers feel interchangeable, or if belief state changes are invisible enough that the player can't trace cause and effect from their decisions to the world's response. The richness of individual NPCs and the fidelity of their state tracking are not implementation details. They are the primary experience.

The player never touches this system. Every conversion, every portrait, every village map color shift, every piece of emergent drama the game produces — those are the player's experience. This system is what makes all of them possible, and what makes them feel true.

## Detailed Design

### Core Rules

**1. NPC data record schema.** Each NPC is represented by a single `NpcRecord` Resource that stores all per-character state. This is the canonical object all downstream systems read from:

```
NpcRecord (Resource):
  npc_id:                   String        # format: [village_id]_[archetype_slug]_[index]
  archetype:                NPCArchetype  # enum — see Rule 3
  display_name:             String        # player-visible name; hand-authored at MVP
  assigned_traits:          Array[String] # full list of trait IDs from TraitDatabase
  revealed_traits:          Array[String] # subset of assigned_traits visible to player
  belief_state:             BeliefState   # enum — see Rule 2
  cooldown_turns_remaining:           int           # turns until approachable; 0 = approachable
  recently_converted_turns_remaining: int           # rival grace window turns remaining; 0 = window closed
  approach_count:                     int           # total approaches made (gate: max_approaches_per_npc)
  approach_history:         Dictionary    # DialogueApproach → int (attempt count per approach)
  social_connections:       Array[NPCConnection]
  map_position:             Vector2i      # grid position on village map
  access_gate:              NPCAccessGate # nullable — if set, NPC is locked until condition met

NPCConnection (Resource):
  target_npc_id:     String             # must match a valid npc_id in NPCRegistry
  relationship_type: RelationshipType   # enum — see Rule 4
  influence_weight:  float              # [0.0, 1.0] — base social spread strength

NPCAccessGate (Resource):
  required_belief_state: BeliefState    # state that gating NPCs must reach
  required_npc_ids:      Array[String]  # all listed NPCs must reach required_belief_state
```

`social_influence_weight` is **not** stored on `NpcRecord` — it lives on `NPCArchetypeDefinition` and is retrieved via `NPCRegistry.get_archetype_definition(npc.archetype)`.

---

**2. Belief states.** Each NPC has a `BeliefState` that tracks their relationship to the player's faith. States advance through a single linear progression:

`STEADFAST → OPEN → WAVERING → CONVERTED`

- `STEADFAST` — The NPC holds to their existing inner world. This is the default state at scene load. Not hostile — simply unbroken.
- `OPEN` — The NPC has become genuinely receptive. First contact has registered; the player can reach them meaningfully.
- `WAVERING` — The NPC is between worlds. Old faith has loosened; the new faith pulls at them. Highest conversion probability; the drama state.
- `CONVERTED` — The NPC has committed. Permanent for the session. Contributes to the follower economy; influences neighbors via social connections.

---

**3. Seven archetypes.** Archetypes are defined in this system via `NPCArchetypeDefinition` Resources — not in the NPC Trait Database, which only stores archetype tag references. Each definition includes:

```
NPCArchetypeDefinition (Resource):
  archetype_id:            NPCArchetype
  display_name:            String
  role_description:        String          # one-sentence internal description
  social_influence_weight: float           # [0.1, 5.0] — Faith Spread multiplier; 1.0 = baseline
  trait_weight_bonuses:    Array[NPCArchetypeTraitBonus]
  portrait_asset_path:     String          # res:// path to portrait asset set

NPCArchetypeTraitBonus (Resource):
  trait_id:  String   # must match TraitDatabase entry
  bonus_pct: float    # [0.0, 1.0] — additive % on rarity base weight (e.g. 0.20 = +20%)
```

The seven archetype definitions, with social influence weights and trait bonuses:

| Archetype ID | Display Name | Social Influence Weight | Key Trait Bonuses |
|---|---|---|---|
| `LABORER` | Laborer | 0.8 | bereaved +20%, superstitious +20%, dutiful +15%, fearful +20%, grievously_wronged +10% |
| `ELDER` | Elder | 2.0 | dutiful +25%, loyal_to_community +30%, mortal_minded +20%, bereaved +15%, seeker +10% |
| `MERCHANT` | Merchant | 1.5 | ambitious +25%, cynical +20%, status_hungry +15%, fearful +10%, mortal_minded +10% |
| `SOLDIER` | Soldier | 1.2 | dutiful +30%, proud +20%, grievously_wronged +15%, broken_by_loss +10%, fearful +10% |
| `SCHOLAR` | Scholar | 1.8 | intellectually_restless +35%, cynical +15%, seeker +15%, visionary +10%, proud +10% |
| `WIDOW` | Widow | 0.9 | bereaved +40%, lonely +25%, broken_by_loss +20%, mortal_minded +15%, superstitious +10% |
| `NOBLE` | Noble | 2.5 | proud +30%, ambitious +20%, status_hungry +25%, intellectually_restless +10%, loyal_to_community +10% |

**`portrait_asset_path` format contract** (consumed by the Portrait & Expression System):
- Value is a **directory** path: `res://assets/portraits/{archetype_id}/` (lowercase archetype slug).
- Required field — no default; every archetype definition must set it.
- Must contain exactly six files named `{expression_key}.png` for the six MVP expression keys (`closed_resistant`, `neutral_listening`, `considering_uncertain`, `open_receptive`, `withdrawn_resistant`, `moved_convinced`).
- Debug-only validation at `initialize_village()`: `DirAccess.dir_exists_absolute(path)` — log a warning (do not crash) if missing; the Portrait & Expression System fallback covers runtime (its EC-6/EC-7).

---

**4. Relationship types.** Social connections use a `RelationshipType` enum. MVP requires the first seven; the remaining five are post-MVP:

| Value | MVP? | Direction | Spread behavior |
|---|---|---|---|
| `SPOUSE` | ✓ | Bidirectional | Highest trust; amplifies conversion influence in both directions |
| `MENTOR` | ✓ | Mentor → student | Teaching relationship; student defaults to mentor's worldview shift |
| `CLOSE_FRIEND` | ✓ | Bidirectional | Long-term affection; strong bidirectional influence |
| `NEIGHBOR` | ✓ | Bidirectional | Ambient proximity; weak but omnidirectional |
| `KIN` | ✓ | Bidirectional | Extended family (non-spouse); moderate influence via GRIEF and DUTY appeals |
| `RIVAL` | ✓ | Bidirectional | Contrarian identity — one's conversion increases the other's resistance |
| `EMPLOYER` | ✓ | Employer → employee (strong); reversed (weak) | Employer conversion exerts downward social pressure |
| `PARENT_OF` | post-MVP | Parent → child | Parental authority over adult children persists |
| `CONGREGATION` | post-MVP | Scholar → congregation | Spiritual relationship — Scholar converts before congregation |
| `TRADING_PARTNER` | post-MVP | Bidirectional | AMBITION approach only; no belief pressure via GRIEF or DOUBT |
| `SWORN_ENEMY` | post-MVP | Bidirectional | One conversion triggers belief regression in the other (OPEN → STEADFAST) |
| `AUTHORITY_OVER` | post-MVP | Authority → subject | Coercive; FEAR backfire risk |

---

**5. Conversion outcome mapping.** `apply_conversion_outcome()` accepts a `caller: OutcomeCaller` parameter (default: `OutcomeCaller.PLAYER`) — see API block for enum definition. When called, the NPC Character System applies one belief state mutation per this table:

| Outcome | From STEADFAST | From OPEN | From WAVERING | From CONVERTED |
|---|---|---|---|---|
| `PERSUADED` | → OPEN | → WAVERING | → CONVERTED † | → WAVERING ‡ |
| `SOFTENED` | → OPEN | → WAVERING | no change | → WAVERING ‡ |
| `RESISTED` | no change | no change | no change | no-op |
| `HARDENED` | no change | → STEADFAST | → OPEN | no-op |

† On any `WAVERING → CONVERTED` transition (any caller): sets `recently_converted_turns_remaining = GameConfig.rival.grace_window_turns`.  
‡ Rival grace-window regression — applies only when `caller == OutcomeCaller.RIVAL AND recently_converted_turns_remaining > 0`. Otherwise no-op for all callers.

Key rules from this table:
- A STEADFAST NPC cannot be converted in a single conversation. Minimum path: STEADFAST → OPEN → WAVERING → CONVERTED requires at least three positive approaches.
- Only `PERSUADED` can complete a conversion from WAVERING. `SOFTENED` advances toward WAVERING but cannot seal the conversion.
- `HARDENED` regresses belief state one step. Only a misaligned approach (strong negative trait affinity) produces `HARDENED`. `RESISTED` is neutral refusal; it does not regress.
- `CONVERTED` is terminal for `PLAYER` and `FAITH_SPREAD` callers. For `OutcomeCaller.RIVAL`, `PERSUADED` and `SOFTENED` trigger `CONVERTED → WAVERING` regression during the grace window (`recently_converted_turns_remaining > 0`). After the grace window closes, conversion is permanent regardless of caller.

After any non-no-op outcome: set `cooldown_turns_remaining = GameConfig.conversion.approach_cooldown_turns` (default: 3), increment `approach_count`, and increment `approach_history[approach]` by 1.

---

**6. Approachability gates.** An NPC is approachable if and only if all three conditions are true:
1. `cooldown_turns_remaining == 0`
2. `approach_count < GameConfig.conversion.max_approaches_per_npc` (default: 5)
3. `access_gate == null` OR all NPCs in `access_gate.required_npc_ids` have `belief_state >= access_gate.required_belief_state`

`NPCRegistry.get_approachable_npcs()` enforces all three conditions. Locked or cooldown-gated NPCs are visible on the Village Map but cannot be selected for dialogue.

---

**7. Trait hidden/revealed state.** All traits start hidden (`revealed_traits` is empty at generation). The UI always shows `[N traits hidden]` where N = `assigned_traits.size() - revealed_traits.size()`. A trait moves from hidden to revealed by exactly one of three triggers:

- **Inspect action**: Player taps the NPC inspect button. NPCRegistry reveals one hidden trait: the trait with the highest absolute affinity value across all four approaches. Ties resolved by index in `assigned_traits`.
- **Dialogue outcome**: Any outcome other than `RESISTED` reveals the hidden trait with the highest affinity magnitude for the approach used. If all traits are already revealed, this is a no-op.
- **Social observation** (post-MVP): Passive reveal from a close CONVERTED neighbor. Deferred to Faith Spread System.

Revelation is permanent within and across sessions. `revealed_traits` must be persisted in the save file.

---

**8. NPC generation.** `NPCRegistry.initialize_village()` calls `generate_npc()` once per NPC slot in the village scene definition. Generation is deterministic given the same `rng_seed`:

1. Validate `npc_id` format matches `[village_id]_[archetype_slug]_[index]` and is not already registered. If already registered, log a warning and return the existing record.
2. Set `belief_state = BeliefState.STEADFAST`.
3. Set `cooldown_turns_remaining = 0`, `approach_count = 0`, `approach_history = {}`, `revealed_traits = []`.
4. Call the Trait Assignment Formula (NPC Trait Database GDD §Formulas): fetch archetype-filtered trait pool, apply this archetype's `trait_weight_bonuses`, deduplicate, draw without replacement `trait_count` times using `rng_seed`. Store result as `assigned_traits`.
5. Set `social_connections`, `map_position`, and `access_gate` from the village scene definition file (hand-authored at MVP).
6. Register and return the completed `NpcRecord`.

When loading from a save file, `NPCRegistry.deserialize()` is called instead — no trait redraw occurs.

---

**9. Cross-system flag — ConversionOutcome rename.** The `ConversionOutcome` enum was defined in the Dialogue Content Database GDD as `CONVERTED | SOFTENED | RESISTED | HARDENED`. This GDD renames `CONVERTED` to `PERSUADED` to eliminate the naming collision with `BeliefState.CONVERTED`. The Dialogue Content Database GDD must be updated to reflect this change before implementation begins.

---

### States and Transitions

**NPC Belief State Machine:**

```
              PERSUADED / SOFTENED
STEADFAST ──────────────────────────► OPEN
    ▲                                   │ PERSUADED / SOFTENED
    │ HARDENED                          ▼
    │                               WAVERING
    └──────────────────────────────────-│ HARDENED
                                        │ PERSUADED only
                                        ▼
                                    CONVERTED (terminal — no exit)
```

| Trigger | Valid Transitions |
|---|---|
| `PERSUADED` outcome | STEADFAST→OPEN, OPEN→WAVERING, WAVERING→CONVERTED |
| `SOFTENED` outcome | STEADFAST→OPEN, OPEN→WAVERING |
| `RESISTED` outcome | None (no-op on state) |
| `HARDENED` outcome | OPEN→STEADFAST, WAVERING→OPEN |
| Any non-no-op outcome | Sets `cooldown_turns_remaining`; increments `approach_count` |
| `advance_turn()` called | Decrements all `cooldown_turns_remaining` and `recently_converted_turns_remaining` by 1 (floor 0 each) |

**Trait Reveal State Machine (per trait, per NPC):**

```
HIDDEN ──────────────────────────────► REVEALED (permanent — no revert)
        Inspect action
        OR non-RESISTED dialogue outcome
        OR social observation (post-MVP)
```

---

### Interactions with Other Systems

| Consuming System | Data Consumed | NPCRegistry Methods Called |
|---|---|---|
| Dialogue & Conversion System | NPC record, approachable list, outcome mutation, trait reveal | `get_npc()`, `get_approachable_npcs()`, `apply_conversion_outcome()`, `reveal_trait()`, `trigger_inspect_reveal()` |
| Village Map View | All NPCs, belief states, map positions | `get_all_npcs()`, `get_npcs_by_belief()`, `npc_state_changed` signal |
| Portrait & Expression System | NPC archetype, belief state, revealed traits | `get_npc()` |
| Save & Load System | Full village NPC state | `serialize()`, `deserialize()` |
| Faith Spread System | All NPCs, social connections, archetype definitions, outcome mutation | `get_all_npcs()`, `get_connections()`, `get_archetype_definition()`, `apply_conversion_outcome()` |
| Game State Manager | Turn lifecycle, village init/clear, CONVERTED count for win condition | `advance_turn()`, `initialize_village()`, `clear_village()`, `get_npcs_by_belief(CONVERTED)` |
| Follower Economy System | CONVERTED NPC count per archetype | `get_npcs_by_belief(CONVERTED)` |
| Rival Faith System | NPC records, approachable NPCs, outcome mutation | `get_npc()`, `get_approachable_npcs()`, `apply_conversion_outcome()` |

**NPCRegistry Autoload — full typed API:**

```gdscript
# Query
get_npc(npc_id: String) -> NpcRecord
get_all_npcs() -> Array[NpcRecord]
get_npcs_by_belief(state: BeliefState) -> Array[NpcRecord]
get_approachable_npcs() -> Array[NpcRecord]          # enforces all 3 approachability gates
get_connections(npc_id: String) -> Array[NPCConnection]
get_archetype_definition(archetype: NPCArchetype) -> NPCArchetypeDefinition
get_hidden_trait_count(npc_id: String) -> int

# Enums
enum OutcomeCaller { PLAYER, RIVAL, FAITH_SPREAD }

# Mutation (Dialogue & Conversion System, Rival Faith System, and Faith Spread System only)
apply_conversion_outcome(npc_id: String, outcome: ConversionOutcome, approach: DialogueApproach, caller: OutcomeCaller = OutcomeCaller.PLAYER) -> void

# Trait Reveal (Dialogue & Conversion System only)
reveal_trait(npc_id: String, approach: DialogueApproach) -> void  # NPCRegistry selects highest-affinity hidden trait for this approach internally
trigger_inspect_reveal(npc_id: String) -> void       # reveals highest-affinity hidden trait

# Turn Lifecycle (Game State Manager only)
advance_turn() -> void

# Initialization (Game State Manager only)
initialize_village(npc_definitions: Array[Dictionary]) -> void
clear_village() -> void

# Persistence (Save & Load System only)
serialize() -> Dictionary
deserialize(data: Dictionary) -> void

# Signals
signal npc_state_changed(npc_id: String, old_state: BeliefState, new_state: BeliefState)
signal npc_cooldown_expired(npc_id: String)
signal trait_revealed(npc_id: String, trait_id: String)
signal village_initialized()
```

## Formulas

### Archetype Trait Weight Formula

This formula is applied by the NPC Character System when constructing the weighted trait candidate pool during NPC generation. It converts a trait's rarity base weight into an archetype-specific effective weight by applying the archetype's bonus for that trait.

The Trait Assignment Formula (draw procedure and count determination) is owned by the **NPC Trait Database GDD §Formulas** and is called by this system — not redefined here.

```
effective_weight = rarity_base_weight × (1 + bonus_pct)
```

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `rarity_base_weight` | Rarity base weight | int | {10, 30, 60} | Base selection weight for the trait's rarity tier, from `GameConfig.traits` — RARE=10, UNCOMMON=30, COMMON=60 |
| `bonus_pct` | Archetype bonus | float | [0.0, 1.0] | The archetype-specific percentage bonus for this trait, from `NPCArchetypeTraitBonus.bonus_pct`. 0.0 if the archetype has no entry for this trait |
| `effective_weight` | Effective weight | float | [10.0, ~84.0] | Final selection weight used in the weighted draw. Replaces `rarity_base_weight` for this trait in the pool |

**Output range:** Floor is the rarity base weight with no bonus (10.0 for RARE). Practical ceiling at current authored bonuses is 60 × 1.40 = 84.0 (Widow archetype, `bereaved` trait at +40% bonus). The output is not clamped — the upper bound is design-controlled by authored `bonus_pct` values.

**Worked example — Widow archetype, `bereaved` trait (COMMON, +40% bonus):**
- `rarity_base_weight = 60`
- `bonus_pct = 0.40`
- `effective_weight = 60 × (1 + 0.40) = 84.0`

**Worked example — Widow archetype, `seeker` trait (RARE, no bonus):**
- `rarity_base_weight = 10`
- `bonus_pct = 0.0`
- `effective_weight = 10 × (1 + 0.0) = 10.0`

**Pool construction:** Applied to every eligible trait (archetype-tagged traits plus archetype-agnostic traits from `TraitDatabase.get_traits_for_archetype()`). The resulting `effective_weight` values form the weighted pool passed to the Trait Assignment Formula draw procedure. Traits with `bonus_pct = 0.0` retain their rarity base weight unmodified.

## Edge Cases

### Generation & Initialization

**E1. Duplicate `npc_id` on `initialize_village()`.**
Log a warning and return the existing record. No duplicate entries are created. This can happen if a scene definition lists the same NPC slot twice.

**E2. `access_gate.required_npc_ids` references a non-existent `npc_id`.**
Detected at `initialize_village()` time. Log an error and set `access_gate = null` on the affected NPC (treated as no gate). The NPC becomes immediately approachable. Do not crash.

**E3. `social_connections` references a non-existent `target_npc_id`.**
Detected at `initialize_village()` time. Log an error and drop the invalid connection from the list. The NPC's other connections remain intact.

**E4. Deserialization encounters an unknown `BeliefState` or `RelationshipType` value.**
If the saved value cannot be mapped to a current enum member, log an error and default to `STEADFAST` (for `BeliefState`) or drop the connection (for `RelationshipType`). Never crash on load.

---

### Belief State Floor / Ceiling

**E5. `HARDENED` outcome applied to a STEADFAST NPC.**
`STEADFAST` is the floor. Outcome is a no-op on belief state. Cooldown and approach count still update normally — the approach registered; the NPC cannot go below `STEADFAST`.

**E6. Any outcome applied to a CONVERTED NPC.**
For `OutcomeCaller.PLAYER` and `OutcomeCaller.FAITH_SPREAD`, `CONVERTED` is terminal — all four outcomes are no-ops on belief state. For `OutcomeCaller.RIVAL`, `PERSUADED` and `SOFTENED` trigger `CONVERTED → WAVERING` regression when `recently_converted_turns_remaining > 0` (grace window active); `RESISTED` and `HARDENED` are always no-ops on CONVERTED NPCs regardless of caller. `get_approachable_npcs()` never returns a CONVERTED NPC — the Rival Faith System is the only legitimate caller on CONVERTED NPCs; any PLAYER-caller call on CONVERTED is a bug. Cooldown and approach count still update normally on any non-no-op call.

---

### Approachability & Village Exhaustion

**E7. All NPCs are at `max_approaches_per_npc` and none are convertible.**
`get_approachable_npcs()` returns an empty array. The Game State Manager is responsible for detecting this and triggering the "village exhausted" outcome (fail state or advance — defined in Game Config GDD). This system emits no special signal for this condition; the Game State Manager polls `get_approachable_npcs()` each turn.

**E8. All NPCs are locked behind `access_gate` conditions at game start.**
This is a scene authoring error — the village is unplayable until a gate condition is satisfied externally. At `initialize_village()`, validate that at least one NPC has `access_gate == null`. If none do, log an error and clear the access gate on the NPC with the fewest `required_npc_ids`. In debug builds, push an assertion failure.

**E9. `apply_conversion_outcome()` called on a cooldown-gated or access-gated NPC.**
Valid — the Rival Faith System may legitimately apply outcomes to NPCs the player cannot currently approach. Gate checks are enforced by `get_approachable_npcs()` for player actions only; the mutation API itself does not enforce approachability. Caller is responsible for checking gates if needed.

---

### Trait Revelation

**E10. Reveal triggered when all traits are already revealed.**
No-op. Both `reveal_trait()` and `trigger_inspect_reveal()` check `revealed_traits.size() == assigned_traits.size()` and return without mutation. No signal emitted.

**E11. `trigger_inspect_reveal()` called when `assigned_traits` is empty.**
Impossible in a correctly generated `NpcRecord` — generation always assigns at least one trait. If it occurs due to a data error, log an error and return without mutation.

---

### Social Connections

**E12. Two NPCs with a `RIVAL` relationship are both converted in the same turn** (via Faith Spread).
Faith Spread applies outcomes sequentially. Once the first rival is `CONVERTED`, their state is terminal — the second rival's conversion cannot regress it. Both end up `CONVERTED`. This is intentional: the RIVAL resistance effect only applies during the approach window; simultaneous conversion in a single Faith Spread pass is valid.

---

### Persistence

**E13. `clear_village()` called while NPCs have active cooldowns.**
All `NpcRecord` entries are removed from the registry and cooldown state is discarded. No timers or deferred callbacks hold references to `NpcRecord` objects after `clear_village()` — callers must stop any iteration before clearing.

**E14. `get_npc()` called with an unregistered `npc_id`.**
Returns `null`. Callers must null-check before dereferencing. All internal callers that receive IDs from `get_all_npcs()` or `get_approachable_npcs()` will never receive invalid IDs from this system; only callers with hard-coded IDs are at risk.

## Dependencies

### Systems This System Depends On

| System | GDD | Dependency |
|---|---|---|
| NPC Trait Database | `npc-trait-database.md` | Provides `TraitDatabase` — the full trait pool, rarity weights, archetype tags, and affinity values. Required at `initialize_village()` to run the trait assignment procedure. Without it, NPC generation cannot proceed. |
| Game Config | `game-config.md` | Provides `GameConfig.traits` (rarity base weights), `GameConfig.conversion.approach_cooldown_turns`, and `GameConfig.conversion.max_approaches_per_npc`. All tuning values read from here, never hardcoded. |
| Dialogue Content Database | `dialogue-content-database.md` | Defines `ConversionOutcome` and `DialogueApproach` enums consumed by `apply_conversion_outcome()`. **Cross-system flag:** `ConversionOutcome.CONVERTED` must be renamed to `PERSUADED` in that GDD before implementation to eliminate the naming collision with `BeliefState.CONVERTED`. |

---

### Systems That Depend On This System

| System | GDD | What it reads |
|---|---|---|
| Dialogue & Conversion System | *(GDD pending)* | Full NPC records, approachable NPC list, outcome mutation, trait reveal. Primary consumer — all player conversion interactions route through this. |
| Village Map View | *(GDD pending)* | All NPC records, belief states, map positions. Subscribes to `npc_state_changed` signal to recolor the map. |
| Portrait & Expression System | *(GDD pending)* | NPC archetype, belief state, revealed traits. Reads on portrait render; subscribes to `npc_state_changed` for expression updates. |
| Save & Load System | *(GDD pending)* | Full village NPC state via `serialize()` / `deserialize()`. |
| Faith Spread System | *(GDD pending)* | All NPC records, social connections, archetype definitions. Calls `apply_conversion_outcome()` as part of end-of-turn spread resolution. |
| Game State Manager | *(GDD pending)* | Turn lifecycle (`advance_turn()`), village init/clear, CONVERTED count for win condition check. |
| Follower Economy System | *(GDD pending)* | CONVERTED NPC count per archetype via `get_npcs_by_belief(CONVERTED)`. Used by macro-layer resource calculations. |
| Rival Faith System | *(GDD pending)* | NPC records, approachable NPCs, outcome mutation. Mirrors player conversion logic from the antagonist side. |

---

### Architectural Notes

- This system is a **pure data store with controlled mutation** — it holds no game logic beyond state transition rules and approachability gating. All decision logic (which approach to use, whether to spread faith, macro-layer effects) lives in consumer systems.
- `NPCRegistry` is an **Autoload singleton** — all consumer systems access it without a reference passed at construction. This is appropriate because NPC state is global to the village scene.
- The NPC Trait Database and Game Config are the only systems this system reads from at runtime. All other relationships are write/signal.
- `ConversionOutcome` is **defined in the Dialogue Content Database GDD** but consumed here — the rename flag above must be resolved before implementation begins.

## Tuning Knobs

### From `GameConfig.conversion` (owned by Game Config GDD)

| Knob | Default | Safe Range | Gameplay Effect |
|---|---|---|---|
| `approach_cooldown_turns` | 3 | 1–6 | How long after any approach before the player can talk to an NPC again. Lower = faster pacing, easier to complete conversion chains; higher = forces village-wide breadth before depth. |
| `max_approaches_per_npc` | 5 | 3–8 | Hard cap on total approaches per NPC lifetime. Below 3, conversion is nearly impossible (STEADFAST→OPEN→WAVERING→CONVERTED needs 3 minimum). Above 8, the player can camp one NPC indefinitely. |

---

### From `NPCArchetypeDefinition` (owned by this system, authored in Resource files)

| Knob | Default Range | Safe Range | Gameplay Effect |
|---|---|---|---|
| `social_influence_weight` per archetype | 0.8–2.5 (see Detailed Rules §3) | 0.1–5.0 | Scales how powerfully a CONVERTED NPC spreads faith through their social connections. Raising Noble above 3.0 makes a single Noble conversion near-deterministic for the whole village. Lowering Laborer below 0.5 makes laborer conversions feel unrewarding. |
| `trait_weight_bonuses` per archetype/trait | 0.10–0.40 (see Detailed Rules §3) | 0.0–0.60 | Shifts how probable a trait is for a given archetype. Bonuses above 0.60 make the trait near-certain for that archetype, reducing character variety. A bonus of 0.0 leaves the trait at its rarity base weight. |

---

### From `NPCConnection.influence_weight` (authored per-village in scene definition)

| Knob | Default | Safe Range | Gameplay Effect |
|---|---|---|---|
| `influence_weight` per connection | 1.0 (baseline) | 0.0–1.0 | Per-edge strength of social spread, used by the Faith Spread System as a multiplier. Setting a SPOUSE connection to 0.3 makes that marriage cold; setting a NEIGHBOR to 1.0 makes them unusually close. Should be hand-authored per village for narrative consistency. |

---

### Rarity Tier Base Weights (owned by Game Config GDD — affects all archetypes)

| Tier | Default Weight | Effect of Raising |
|---|---|---|
| RARE | 10 | Makes rare traits appear more often; reduces the drama of discovering one. |
| UNCOMMON | 30 | Pulls the distribution toward mid-tier traits. |
| COMMON | 60 | Baseline. Flattening toward RARE (e.g. 20/30/40) compresses personality variety. |

---

### Derived Limits (not directly tunable — emerge from the above)

| Derived Value | Formula | Notes |
|---|---|---|
| Minimum turns to convert one NPC | `3 × approach_cooldown_turns` | Three PERSUADED outcomes required from STEADFAST. At default (cooldown = 3), minimum is 9 turns per NPC. |
| Maximum trait weight in pool | `rarity_base_weight × (1 + max_bonus_pct)` | At current authored bonuses: `60 × 1.40 = 84.0` (Widow / bereaved). |

## Visual/Audio Requirements

| State / Event | Visual Requirement | Audio Requirement |
|---|---|---|
| `BeliefState.STEADFAST` | NPC portrait uses neutral expression set | None (ambient village audio) |
| `BeliefState.OPEN` | Portrait shifts to receptive expression set | Soft ambient tone shift on transition |
| `BeliefState.WAVERING` | Portrait uses conflicted/torn expression set | Low contemplative musical sting on transition |
| `BeliefState.CONVERTED` | Portrait uses peaceful/luminous expression set; village map tile shifts to faith color | Conversion chime — the signature audio moment of the game |
| `cooldown_turns_remaining > 0` | NPC portrait on village map shows cooldown overlay (dimmed or hatched); tap target disabled | None |
| `access_gate` locked | NPC portrait on village map shows locked state (lock icon or desaturated); tap target disabled | None |
| `trait_revealed` signal | Trait card animates into view in inspection panel | Soft reveal sound |
| `approach_count` approaching `max_approaches_per_npc` | No required visual at this layer — left to UI system to decide | None |

All expression sets are defined per archetype. The Portrait & Expression System reads `belief_state` from this system to select the correct set — this system does not reference asset paths directly (those live in `NPCArchetypeDefinition.portrait_asset_path`).

## UI Requirements

| UI Element | Requirement |
|---|---|
| NPC inspection panel | Must display: archetype display name, current `belief_state` label, all `revealed_traits` as cards, count of hidden traits as `[N traits hidden]`. Must show Inspect button if `revealed_traits.size() < assigned_traits.size()`. |
| Village map NPC portrait | Must communicate approachability (active / cooldown / locked / converted) as four visually distinct states. Tap target must meet minimum 44×44dp touch size. |
| Cooldown indicator | Must communicate that an NPC is temporarily unavailable. Exact form (turn count number vs. abstract overlay) is a UI system decision — this system exposes `cooldown_turns_remaining` as an integer for the UI to display as it sees fit. |
| Access gate indicator | Must communicate that an NPC is locked and what is required to unlock. This system exposes `access_gate.required_npc_ids` and `access_gate.required_belief_state` for the UI to read and render a hint (e.g. "Convert the Elder first"). |
| Trait card | Must display trait `display_name` (from `TraitDatabase`). Affinity values are **not** shown to the player — only the trait name and its flavor description. |

## Acceptance Criteria

### NPC Generation

**AC-1.** Given a village scene definition with 8 NPCs and a fixed `rng_seed`, calling `initialize_village()` twice with the same seed produces identical `NpcRecord` arrays (same trait assignments, same belief states, same connections). *(Determinism)*

**AC-2.** Every generated `NpcRecord` has `belief_state = STEADFAST`, `cooldown_turns_remaining = 0`, `approach_count = 0`, `revealed_traits = []` on fresh init. *(Clean initial state)*

**AC-3.** Every `NpcRecord.assigned_traits` list contains only trait IDs that exist in `TraitDatabase` and are tagged for the NPC's archetype (or are archetype-agnostic). No invalid trait IDs appear. *(Schema integrity)*

**AC-4.** A Widow archetype NPC has `bereaved` in `assigned_traits` at a statistically higher rate than a Soldier archetype NPC, across 100 generated villages with randomized seeds. *(Archetype bias works)*

---

### Belief State Transitions

**AC-5.** Calling `apply_conversion_outcome(npc_id, PERSUADED, approach)` on a STEADFAST NPC sets `belief_state = OPEN`. Calling it again sets `belief_state = WAVERING`. Calling it a third time sets `belief_state = CONVERTED`. *(Linear progression)*

**AC-6.** Calling `apply_conversion_outcome(npc_id, HARDENED, approach)` on a STEADFAST NPC leaves `belief_state = STEADFAST`. *(Floor holds)*

**AC-7.** Calling `apply_conversion_outcome(npc_id, PERSUADED, approach)` on a CONVERTED NPC leaves `belief_state = CONVERTED` and emits no `npc_state_changed` signal. *(Terminal state)*

**AC-8.** After any non-no-op outcome, `cooldown_turns_remaining == GameConfig.conversion.approach_cooldown_turns` and `approach_count` has incremented by 1. *(Cooldown and counter update)*

**AC-9.** After calling `advance_turn()` N times, `cooldown_turns_remaining` decreases by N (floor 0) for all NPCs. *(Turn tick)*

---

### Approachability

**AC-10.** An NPC with `cooldown_turns_remaining > 0` does not appear in `get_approachable_npcs()`. *(Cooldown gate)*

**AC-11.** An NPC with `approach_count == max_approaches_per_npc` does not appear in `get_approachable_npcs()`. *(Max approaches gate)*

**AC-12.** An NPC whose `access_gate.required_npc_ids` includes an NPC not yet at `required_belief_state` does not appear in `get_approachable_npcs()`. Once all required NPCs reach the required state, the gated NPC appears in the list. *(Access gate)*

---

### Trait Revelation

**AC-13.** After `trigger_inspect_reveal()`, exactly one trait moves from hidden to revealed: the trait with the highest absolute affinity magnitude across all four approaches. *(Inspect reveals highest-affinity trait)*

**AC-14.** After a non-RESISTED dialogue outcome using approach X, exactly one trait moves from hidden to revealed: the hidden trait with the highest affinity magnitude for approach X. *(Dialogue reveals approach-relevant trait)*

**AC-15.** Calling `trigger_inspect_reveal()` when all traits are already revealed does not change `revealed_traits` and does not emit `trait_revealed`. *(No-op on full reveal)*

---

### Signals

**AC-16.** `npc_state_changed` is emitted exactly once per belief state transition, carrying the correct `npc_id`, `old_state`, and `new_state`. It is not emitted on no-op outcomes. *(Signal accuracy)*

**AC-17.** `npc_cooldown_expired` is emitted exactly once per NPC per cooldown cycle, on the `advance_turn()` call that brings `cooldown_turns_remaining` to 0. *(Cooldown expiry signal)*

---

### Persistence

**AC-18.** Calling `serialize()` followed by `clear_village()` followed by `deserialize(data)` produces an `NPCRegistry` state identical to the pre-clear state: same `NpcRecord` contents including `revealed_traits`, `belief_state`, `approach_count`, and `cooldown_turns_remaining`. *(Round-trip fidelity)*

**AC-19.** `deserialize()` with a payload containing an unknown `BeliefState` value does not crash. The affected NPC loads with `belief_state = STEADFAST`. *(Graceful schema migration)*

---

### Edge Case Defenses

**AC-20.** A scene definition with a duplicate `npc_id` produces exactly one registered `NpcRecord` for that ID, and a warning is logged. *(Duplicate guard)*

**AC-21.** A scene definition where all NPCs have `access_gate != null` results in exactly one NPC having its access gate cleared at init, and a log error is written. *(Unplayable village guard)*

## Open Questions

| # | Question | Impact | Owner |
|---|---|---|---|
| OQ-1 | Does the player ever see the social connection graph, or is it entirely invisible? A visible graph would help players plan; an invisible one preserves mystery and emergent surprise. | Affects Village Map View GDD and whether `get_connections()` needs a UI surface. | Design |
| OQ-2 | Does the UI show `cooldown_turns_remaining` as a number (e.g. "3 turns") or as an abstract visual? A number is more legible for strategy; an abstract state is more atmospheric. | UI Requirements above intentionally defers this to the UI system. | UX / UI |
| OQ-3 | Should the player receive any warning as an NPC approaches `max_approaches_per_npc`? A warning could prompt strategic reconsideration; no warning creates harsher stakes. | Affects approach count UI surface. | Design |
| OQ-4 | At MVP, all NPC `display_name` values are hand-authored. Is there a procedural name generation fallback for playtesting before content is authored? | Affects `initialize_village()` — currently assumes `display_name` is always provided in scene definition. | Design / Tools |
