# NPC Trait Database

> **Status**: Designed
> **Author**: Design session + systems-designer agent
> **Last Updated**: 2026-08-09
> **Implements Pillar**: Pillar 1 — Every Soul Has a Story; Pillar 2 — Many Roads to the Divine

## Summary

The NPC Trait Database is the static data layer that defines every trait available in The Faithful — what each trait is, how rare it is, and how it responds to the four dialogue approaches. It is the vocabulary all other NPC and conversion systems read from.

## Overview

The NPC Trait Database is a read-only data registry loaded at game startup from a single resource file (`res://assets/data/traits/trait_database.tres`). It stores the complete, versioned catalogue of NPC traits used by The Faithful. Each entry in the catalogue defines a trait's unique identifier, display name, rarity tier, archetype tags, and affinity modifiers — one per dialogue approach. The database exposes a typed GDScript API (`TraitDatabase`) that other systems call to look up traits by ID, query affinity values, and retrieve the full trait pool for weighted random assignment. It holds no runtime state: it does not track which NPC has which trait, whether a trait is revealed, or how many times it has been encountered. Those concerns belong to the NPC Character System. The database exists because conversion logic, dialogue presentation, portrait expression, and NPC generation all need a single authoritative definition of what a trait *is* — centralising that definition prevents duplication, enables late-stage tuning, and ensures that adding a new trait in one place propagates everywhere automatically.

## Player Fantasy

The trait system is working well when the player looks at an NPC's revealed traits and the right approach becomes legible — not obvious to the point of triviality, but clear enough that a considered choice feels personally earned. The defining player moment is reading a grieving widow's `Bereaved` trait and understanding, without being told explicitly, that reaching her through her sorrow is not manipulation but connection. A second moment arrives when a seemingly stubborn Elder turns out to carry the `Seeker` trait — a rare crack in a hard surface — and the player who noticed it is rewarded for looking carefully. The system fails if every NPC feels like a lock and every approach feels like a key; it succeeds when traits feel like glimpses of a real person's interior life.

## Detailed Design

### Core Rules

1. **A trait is a structured data record.** Each trait consists of:
   - `id: String` — unique snake_case identifier (e.g., `"bereaved"`, `"ambitious"`). Immutable after creation.
   - `display_name: String` — player-facing name shown in the dialogue UI (e.g., `"Bereaved"`, `"Ambitious"`).
   - `description: String` — one-sentence flavour text shown in the NPC inspect panel (what kind of person has this trait).
   - `rarity: TraitRarity` — enum value: `COMMON`, `UNCOMMON`, or `RARE`.
   - `approach_affinity: Dictionary` — keyed by `DialogueApproach` enum; float value in `[-1.0, 1.0]` for each of the four approaches. All four approaches must be present; an approach with no meaningful affinity has value `0.0`.
   - `archetype_tags: Array[String]` — list of NPC archetype IDs (e.g., `["widow", "elder", "laborer"]`) that may carry this trait. Used by NPC Character System to weight trait selection per archetype. An empty array means the trait is archetype-agnostic (eligible for any archetype).

2. **Total trait count at MVP.** The MVP catalogue contains 16 traits: 7 Common, 6 Uncommon, and 3 Rare. This count supports 8–12 NPCs feeling distinctly different from each other. It is designed to be extended post-MVP by adding new entries without modifying existing ones.

3. **Rarity tiers.** Three tiers match the locked GameConfig values:
   - **Common** (weight 60): Core personality traits that most people plausibly carry. Expected to appear on most NPCs. Define the baseline of conversion difficulty and emotional range.
   - **Uncommon** (weight 30): Traits that reflect stronger or more particular life experiences. Appear on roughly half of NPCs. Create meaningful differentiation within archetype groups.
   - **Rare** (weight 10): Traits that represent exceptional inner lives — deep spiritual readiness, profound trauma, or unusual openness. Appear infrequently. When present, they substantially alter conversion dynamics. Finding one on an NPC should feel significant.

4. **The four dialogue approaches.** All affinity values are keyed to exactly these four approach identifiers. These names are the canonical vocabulary across all GDDs.
   - `GRIEF` — approach through shared suffering and comfort
   - `AMBITION` — approach through opportunity, status, and future reward
   - `DOUBT` — approach through questioning, philosophical inquiry, and reasoned argument
   - `FEAR` — approach through consequence, mortality, and existential threat

5. **Approach affinity values.** Each trait stores a float in `[-1.0, 1.0]` for every approach. Values cluster into five meaningful bands:
   - `+1.0`: Strong positive resonance — this approach aligns perfectly with this trait.
   - `+0.5`: Positive resonance — this approach works well on someone with this trait.
   - `0.0`: Neutral — this trait neither helps nor hinders this approach.
   - `-0.5`: Resistance — this approach tends to push someone with this trait away.
   - `-1.0`: Strong resistance — this approach is likely to harden or alienate someone with this trait.
   Values outside the five bands are not used in MVP, keeping the system learnable for players.

6. **Archetypes.** An archetype is a named NPC social role (see Trait Catalogue below). Archetypes are not stored in the trait database — they are defined in the NPC Character System. The trait database stores only the `archetype_tags` array on each trait, which the NPC Character System reads to build per-archetype trait weight tables. This keeps the database dependency-free: it does not need to know what an archetype *is*, only that its ID exists.

7. **Exposed API vs. internal data.** The `TraitDatabase` singleton exposes:
   - `get_trait(id: String) -> TraitData` — returns the full trait record or null if not found.
   - `get_affinity(trait_id: String, approach: DialogueApproach) -> float` — returns the affinity value or `0.0` for missing/unknown inputs.
   - `get_all_traits() -> Array[TraitData]` — returns the full catalogue, used during NPC generation.
   - `get_traits_by_rarity(rarity: TraitRarity) -> Array[TraitData]` — returns all traits of a given rarity tier.
   - `get_traits_for_archetype(archetype_id: String) -> Array[TraitData]` — returns all traits whose `archetype_tags` include the given archetype ID, union with all archetype-agnostic traits.
   The database does **not** expose: NPC ownership, revealed/hidden state, trait assignment history, or any runtime state. Those are NPC Character System concerns.

---

### Trait Catalogue

#### Dialogue Approaches

| Approach | Lever | Description |
|---|---|---|
| `GRIEF` | Shared suffering and comfort | Reaches NPCs through empathy for loss, pain, or loneliness. Appeals to the desire to not be alone in suffering. |
| `AMBITION` | Opportunity and status | Reaches NPCs through the possibility of betterment — social, material, or spiritual advancement. Appeals to desire and self-interest. |
| `DOUBT` | Inquiry and reasoned argument | Reaches NPCs through questioning what they already believe. Appeals to intellectual openness or latent dissatisfaction with their current worldview. |
| `FEAR` | Consequence and mortality | Reaches NPCs through the weight of what happens if they do not convert — death, damnation, societal collapse. Appeals to self-preservation and dread. |

---

#### Trait List

Each trait entry lists: Name, ID, Rarity, Description, and an Affinity table with all four approaches, followed by Archetype Tags.

---

**COMMON TRAITS**

---

**Bereaved**
- `id`: `bereaved`
- Rarity: Common
- Description: Has lost a child, spouse, or parent recently; grief has cracked their world open and left them searching.
- Archetype tags: `widow`, `elder`, `laborer`

| Approach | Affinity |
|---|---|
| GRIEF | +1.0 |
| AMBITION | -0.5 |
| DOUBT | 0.0 |
| FEAR | 0.0 |

---

**Ambitious**
- `id`: `ambitious`
- Rarity: Common
- Description: Wants more than their current station — more respect, more wealth, more influence over their neighbors.
- Archetype tags: `merchant`, `soldier`, `noble`

| Approach | Affinity |
|---|---|
| GRIEF | -0.5 |
| AMBITION | +1.0 |
| DOUBT | 0.0 |
| FEAR | 0.0 |

---

**Superstitious**
- `id`: `superstitious`
- Rarity: Common
- Description: Lives by omens, luck, and unseen forces; already half-convinced the world is full of divine agency.
- Archetype tags: `laborer`, `elder`, `widow`

| Approach | Affinity |
|---|---|
| GRIEF | 0.0 |
| AMBITION | 0.0 |
| DOUBT | -0.5 |
| FEAR | +1.0 |

---

**Proud**
- `id`: `proud`
- Rarity: Common
- Description: Carries a strong sense of personal dignity; hates to appear weak, gullible, or manipulated.
- Archetype tags: `soldier`, `noble`, `merchant`

| Approach | Affinity |
|---|---|
| GRIEF | -0.5 |
| AMBITION | +0.5 |
| DOUBT | +0.5 |
| FEAR | -1.0 |

---

**Dutiful**
- `id`: `dutiful`
- Rarity: Common
- Description: Defined by obligation to family, community, or lord; measures all things by whether they serve their duty.
- Archetype tags: `soldier`, `laborer`, `elder`

| Approach | Affinity |
|---|---|
| GRIEF | 0.0 |
| AMBITION | -0.5 |
| DOUBT | -0.5 |
| FEAR | +0.5 |

---

**Lonely**
- `id`: `lonely`
- Rarity: Common
- Description: Isolated by circumstance or temperament; craves belonging and will follow the warmth of community.
- Archetype tags: `widow`, `laborer`, `scholar`

| Approach | Affinity |
|---|---|
| GRIEF | +1.0 |
| AMBITION | 0.0 |
| DOUBT | 0.0 |
| FEAR | -0.5 |

---

**Fearful**
- `id`: `fearful`
- Rarity: Common
- Description: Lives in constant anxiety — about the harvest, the lord's tax, illness, death; fear is their baseline.
- Archetype tags: `laborer`, `widow`, `merchant`

| Approach | Affinity |
|---|---|
| GRIEF | +0.5 |
| AMBITION | 0.0 |
| DOUBT | -0.5 |
| FEAR | +1.0 |

---

**UNCOMMON TRAITS**

---

**Grievously Wronged**
- `id`: `grievously_wronged`
- Rarity: Uncommon
- Description: Has suffered a specific injustice — cheated, beaten, dispossessed — and hasn't stopped being angry about it.
- Archetype tags: `laborer`, `widow`, `soldier`

| Approach | Affinity |
|---|---|
| GRIEF | +0.5 |
| AMBITION | +0.5 |
| DOUBT | -0.5 |
| FEAR | 0.0 |

---

**Cynical**
- `id`: `cynical`
- Rarity: Uncommon
- Description: Has seen enough of the world to expect disappointment; distrusts promises and resists enthusiasm.
- Archetype tags: `merchant`, `soldier`, `scholar`

| Approach | Affinity |
|---|---|
| GRIEF | 0.0 |
| AMBITION | -0.5 |
| DOUBT | +1.0 |
| FEAR | -0.5 |

---

**Status-Hungry**
- `id`: `status_hungry`
- Rarity: Uncommon
- Description: Desperately wants social elevation; watches who the powerful favor and adjusts their behavior accordingly.
- Archetype tags: `merchant`, `noble`, `soldier`

| Approach | Affinity |
|---|---|
| GRIEF | -0.5 |
| AMBITION | +1.0 |
| DOUBT | 0.0 |
| FEAR | 0.0 |

---

**Mortal-Minded**
- `id`: `mortal_minded`
- Rarity: Uncommon
- Description: Acutely aware of their own mortality — a recent illness, a close friend's death — and preoccupied with what comes after.
- Archetype tags: `elder`, `widow`, `merchant`

| Approach | Affinity |
|---|---|
| GRIEF | +0.5 |
| AMBITION | 0.0 |
| DOUBT | +0.5 |
| FEAR | +1.0 |

---

**Intellectually Restless**
- `id`: `intellectually_restless`
- Rarity: Uncommon
- Description: Reads anything they can find; chafes at dogma; wants to understand the architecture of the world.
- Archetype tags: `scholar`, `noble`, `merchant`

| Approach | Affinity |
|---|---|
| GRIEF | 0.0 |
| AMBITION | 0.0 |
| DOUBT | +1.0 |
| FEAR | -1.0 |

---

**Loyal to Community**
- `id`: `loyal_to_community`
- Rarity: Uncommon
- Description: Defines themselves through belonging to this village, this people, this tradition; suspicious of outside influence.
- Archetype tags: `elder`, `laborer`, `widow`

| Approach | Affinity |
|---|---|
| GRIEF | +0.5 |
| AMBITION | -0.5 |
| DOUBT | -0.5 |
| FEAR | 0.0 |

---

**RARE TRAITS**

---

**Seeker**
- `id`: `seeker`
- Rarity: Rare
- Description: Has been quietly searching for something to believe in for years; the old ways have felt hollow for as long as they can remember.
- Archetype tags: `scholar`, `elder`, `widow`, `laborer`

| Approach | Affinity |
|---|---|
| GRIEF | +0.5 |
| AMBITION | +0.5 |
| DOUBT | +1.0 |
| FEAR | 0.0 |

---

**Broken by Loss**
- `id`: `broken_by_loss`
- Rarity: Rare
- Description: A catastrophic loss — whole family, all wealth, life's purpose — has left them hollowed out and dangerously open.
- Archetype tags: `widow`, `soldier`, `laborer`

| Approach | Affinity |
|---|---|
| GRIEF | +1.0 |
| AMBITION | -1.0 |
| DOUBT | +0.5 |
| FEAR | 0.0 |

---

**Visionary**
- `id`: `visionary`
- Rarity: Rare
- Description: Has experienced something they cannot explain — a dream, a vision, an inexplicable event — and has been waiting for it to mean something.
- Archetype tags: `elder`, `scholar`, `widow`, `laborer`

| Approach | Affinity |
|---|---|
| GRIEF | 0.0 |
| AMBITION | +0.5 |
| DOUBT | +0.5 |
| FEAR | +1.0 |

---

#### NPC Archetypes

Each archetype defines a social role in the village, which traits are weighted toward it, and its social influence weight (how much converting this NPC radiates toward neighbors — consumed by the Faith Spread System).

Archetype definitions also carry `portrait_asset_path` and `social_influence_weight` — both owned by the NPC Character System GDD; the Trait Database does not define them.

A social influence weight of `1.0` is baseline (average NPC). Values above `1.0` mean conversion ripples further through the community; values below `1.0` mean conversion is more personally contained.

---

**Laborer**
- Role: Field worker, craftsperson, or servant. The majority of any village population. Defined by daily survival and physical work.
- Trait weight distribution: `bereaved` +20%, `superstitious` +20%, `dutiful` +15%, `fearful` +20%, `grievously_wronged` +10%. All other traits at base weight.
- Social influence weight: `0.8` — Laborers are numerous but their individual conversions spread slowly. A cluster of laborer conversions, however, creates visible social momentum.

---

**Elder**
- Role: Village patriarch or matriarch, keeper of tradition, respected voice in community decisions. Older, harder to move, but high-impact when converted.
- Trait weight distribution: `dutiful` +25%, `loyal_to_community` +30%, `mortal_minded` +20%, `bereaved` +15%, `seeker` +10% (rare bonus). All other traits at base weight.
- Social influence weight: `2.0` — Elders anchor community belief. Converting one visibly shifts the village's receptiveness to subsequent approaches.

---

**Merchant**
- Role: Trader, shopkeeper, or traveling dealer. Pragmatic. Has seen more of the world than most. Mixes self-interest with social calculation.
- Trait weight distribution: `ambitious` +25%, `cynical` +20%, `status_hungry` +15%, `fearful` +10%, `mortal_minded` +10%. All other traits at base weight.
- Social influence weight: `1.5` — Merchants move between social groups. A converted merchant seeds conversations across the village organically.

---

**Soldier**
- Role: Guard, veteran, or militiaman. Trained to obey, but privately often marked by what they've seen or done in service.
- Trait weight distribution: `dutiful` +30%, `proud` +20%, `grievously_wronged` +15%, `broken_by_loss` +10% (rare bonus), `fearful` +10%. All other traits at base weight.
- Social influence weight: `1.2` — Soldiers influence peers and the laborers who respect them, but their pride makes them slower to publicly endorse faith.

---

**Scholar**
- Role: Priest of the old faith, scribe, or traveling tutor. Educated, possibly skeptical, but also potentially the most profoundly open.
- Trait weight distribution: `intellectually_restless` +35%, `cynical` +15%, `seeker` +15% (rare bonus), `visionary` +10% (rare bonus), `proud` +10%. All other traits at base weight.
- Social influence weight: `1.8` — Scholars are few but publicly credible. A converted scholar is a visible ideological defection.

---

**Widow/Bereaved**
- Role: Any NPC defined primarily by recent devastating loss — a widow, a parent who lost children, a survivor of disaster. Not solely female; the archetype is grief-shaped.
- Trait weight distribution: `bereaved` +40%, `lonely` +25%, `broken_by_loss` +20% (rare bonus), `mortal_minded` +15%, `superstitious` +10%. All other traits at base weight.
- Social influence weight: `0.9` — Widowed NPCs are somewhat isolated, but converting one is emotionally resonant and can move other bereaved characters observing the transformation.

---

**Noble**
- Role: Minor lord, landowner, or administrator. Holds real power over other NPCs — converting one can unlock or restrict access to parts of the village.
- Trait weight distribution: `proud` +30%, `ambitious` +20%, `status_hungry` +25%, `intellectually_restless` +10%, `loyal_to_community` +10%. All other traits at base weight.
- Social influence weight: `2.5` — Nobles exert direct social authority. A converted noble actively facilitates or impedes other conversions depending on their stance.

---

### States and Transitions

The NPC Trait Database is **stateless**. It contains only static definitions that do not change during a play session or between sessions. The database is loaded once at startup and never modified at runtime.

The concept of "state" for a trait applies to an **NPC's relationship to their own trait**, not to the trait definition itself. This state is owned by the NPC Character System, not the Trait Database. The two states are:

| State | Definition | Owner |
|---|---|---|
| `HIDDEN` | The trait is assigned to the NPC but not yet revealed to the player. The player cannot see the trait name, description, or affinity information. | NPC Character System |
| `REVEALED` | The trait has been disclosed to the player through a dialogue event, an inspection action, or a community observation. The player can read the trait name and description in the NPC inspect panel. | NPC Character System |

Revelation triggers are defined in the NPC Character System and Dialogue & Conversion System GDDs, not here. The Trait Database provides no mechanism for state tracking; it only provides the data that other systems display once a trait is revealed.

**Practical consequence**: The Trait Database's `get_trait(id)` API always returns the full trait record regardless of reveal state. Enforcing which data the player sees is the responsibility of the calling system.

---

### Interactions with Other Systems

| Consuming System | Data Flow | Interface Used |
|---|---|---|
| NPC Character System | Reads the full catalogue and per-archetype filtered lists to construct each new NPC's trait set via weighted random assignment. Owns hidden/revealed state per NPC. | `get_all_traits()`, `get_traits_by_rarity(rarity)`, `get_traits_for_archetype(archetype_id)` |
| Conversion Logic Engine | Reads approach-trait affinity values during conversion probability calculation. Calls the database for each trait the target NPC carries. | `get_affinity(trait_id, approach)` |
| Dialogue & Conversion System | Reads trait display names and descriptions to populate the NPC inspect panel. Only requests data for traits marked REVEALED by the NPC Character System. | `get_trait(id)` — display fields only |
| Portrait & Expression System | **Prospective (post-MVP)** — no MVP reads. Trait-driven micro-expressions would read archetype tags / trait IDs for expression selection; MVP expression selection is belief/outcome-driven only (Portrait & Expression System GDD Rule 6). | `get_trait(id)` — archetype_tags field (post-MVP) |
| Faith Spread System | Does not read from the Trait Database directly. It reads per-NPC social influence weights from the NPC Character System, which are derived from archetype definitions (stored in NPC Character System, not here). | No direct interface |
| Rival Faith System | Does not read from the Trait Database directly. It uses the Conversion Logic Engine, which reads affinities on its behalf. | No direct interface |
| Save & Load System | Does not save or load trait definitions. Trait records are static config. The save file stores only NPC trait assignment IDs and reveal states (owned by NPC Character System). | No direct interface |

---

## Formulas

### Approach-Trait Affinity Modifier

This formula produces a signed float modifier that the Conversion Logic Engine adds to the base success chance when a specific dialogue approach is used against an NPC carrying a specific trait.

```
affinity_modifier = A(t, a) × W
```

**Named expression:**
`affinity_modifier = base_affinity_value × trait_modifier_weight`

**Variable table:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `A(t, a)` | `base_affinity_value` | float | [-1.0, 1.0] | The raw affinity of trait `t` for approach `a`, read directly from the trait's `approach_affinity` dictionary in the Trait Database. |
| `W` | `trait_modifier_weight` | float | [0.0, 1.0] | Global scaling factor for how strongly trait affinities affect conversion chance. Stored in `GameConfig.conversion.trait_modifier_weight`. Default: 0.25. |
| `affinity_modifier` | output modifier | float | [-1.0, 1.0] | The signed additive modifier applied to the base success chance in the Conversion Logic Engine. Positive values increase success chance; negative values decrease it. |

**Output range:** The output is bounded by `[-1.0, 1.0]` because `A(t, a)` is in `[-1.0, 1.0]` and `W` is in `[0.0, 1.0]`. The product cannot exceed these bounds. No additional clamping is required at this layer, but the Conversion Logic Engine must clamp the final total success chance to `[0.0, 1.0]` after summing all modifiers.

**Neutral value:** An output of `0.0` represents no affinity effect. This occurs when `A(t, a) = 0.0` (the trait has no affinity for this approach) regardless of `W`, or when `W = 0.0` (trait affinities are globally disabled via config).

**Worked example — Bereaved NPC, GRIEF approach:**
- Trait `bereaved`: `A(bereaved, GRIEF) = +1.0`
- `GameConfig.conversion.trait_modifier_weight = 0.25` (default)
- `affinity_modifier = 1.0 × 0.25 = +0.25`
- Interpretation: The GRIEF approach adds 0.25 to the base conversion success chance for this NPC.

**Worked example — Bereaved NPC, AMBITION approach:**
- Trait `bereaved`: `A(bereaved, AMBITION) = -0.5`
- `W = 0.25`
- `affinity_modifier = -0.5 × 0.25 = -0.125`
- Interpretation: The AMBITION approach subtracts 0.125 from the base success chance — a soft penalty, not a wall.

**Multi-trait stacking note:** If an NPC has multiple traits, the Conversion Logic Engine calls this formula once per trait and sums the results before adding to base chance. That stacking behavior is defined in the Conversion Logic Engine GDD, not here. The Trait Database formula only defines the per-trait contribution.

---

### Trait Assignment Formula

This formula governs how many traits a new NPC receives and which traits are selected, using rarity-weighted random draws without replacement.

**Step 1 — Determine trait count:**
```
trait_count = random_int_inclusive(traits_per_npc_min, traits_per_npc_max)
```

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `traits_per_npc_min` | minimum trait count | int | [1, 5] | From `GameConfig.traits.traits_per_npc_min`. Default: 2. |
| `traits_per_npc_max` | maximum trait count | int | [1, 8] | From `GameConfig.traits.traits_per_npc_max`. Default: 4. |
| `trait_count` | assigned count | int | [2, 4] at defaults | Number of trait slots to fill for this NPC. Uniform random draw across the inclusive range. |

**Step 2 — Build the weighted candidate pool:**

For each trait in the archetype's eligible trait list (archetype-tagged traits plus archetype-agnostic traits), assign a selection weight based on rarity:

```
selection_weight(trait) = rarity_weight(trait.rarity)
```

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `rarity_weight(COMMON)` | common weight | int | [1, 100] | `GameConfig.traits.common_trait_weight`. Default: 60. |
| `rarity_weight(UNCOMMON)` | uncommon weight | int | [1, 100] | `GameConfig.traits.uncommon_trait_weight`. Default: 30. |
| `rarity_weight(RARE)` | rare weight | int | [1, 100] | `GameConfig.traits.rare_trait_weight`. Default: 10. |

**Step 3 — Draw without replacement:**

Repeat `trait_count` times:
```
selected_trait = weighted_random_choice(candidate_pool)
candidate_pool.erase(selected_trait)
```

Each draw is a weighted random selection from the remaining candidates. The selected trait is removed from the pool before the next draw, preventing duplicates. This is sampling without replacement from a weighted pool.

**Output range:** The result is an `Array[String]` of `trait_count` unique trait IDs, where `trait_count` is in `[traits_per_npc_min, traits_per_npc_max]`.

**Worked example — Laborer NPC, default weights:**

Eligible pool (simplified to 5 traits for illustration):
- `bereaved` (Common) — base weight 60, archetype bonus +20% → effective weight 72
- `superstitious` (Common) — base weight 60, archetype bonus +20% → effective weight 72
- `dutiful` (Common) — base weight 60, archetype bonus +15% → effective weight 69
- `grievously_wronged` (Uncommon) — base weight 30, archetype bonus +10% → effective weight 33
- `seeker` (Rare) — base weight 10, no archetype bonus → effective weight 10

Total pool weight: 256. Draw 1: 72/256 ≈ 28% chance of `bereaved`, 10/256 ≈ 4% chance of `seeker`.

If `bereaved` is drawn first, it is removed. Draw 2 proceeds from the remaining 4 traits with renormalized weights.

**Archetype weight bonus application:** Archetype weight bonuses are percentage additions to the base rarity weight. A +20% bonus on a Common trait (base 60) yields weight 72. These bonuses are defined in the NPC Character System's archetype definitions (not in the Trait Database), and are applied by the NPC Character System when constructing the weighted pool before calling the draw formula.

---

## Edge Cases

**EC-1: NPC receives duplicate traits from random assignment.**
The draw-without-replacement mechanic in the Trait Assignment Formula prevents this structurally — each drawn trait is removed from the candidate pool before the next draw. If the NPC Character System calls `TraitDatabase.get_all_traits()` and constructs the pool correctly, duplicates are impossible. If a bug causes the same trait ID to appear twice in the candidate pool (e.g., a trait appearing in both the archetype list and the agnostic list), the NPC Character System must deduplicate the pool before drawing. The Trait Database guarantees every trait ID is unique within the catalogue; the NPC Character System is responsible for building a deduplicated pool.

**EC-2: An archetype's eligible trait pool is smaller than `traits_per_npc_min`.**
This cannot occur with the MVP catalogue: every archetype has access to all 16 traits (archetype-tagged traits plus the archetype-agnostic union), which exceeds `traits_per_npc_max` of 4. However, if post-MVP a hypothetical niche archetype had a restricted pool, the NPC Character System must detect `pool.size() < trait_count` before drawing and clamp `trait_count` to `pool.size()`. The resulting NPC has fewer traits than the configured minimum, which is preferable to an infinite loop or null assignment. A `push_warning` is emitted identifying the archetype and pool size.

**EC-3: A trait's affinity references an approach that doesn't exist in the database.**
Trait affinity dictionaries are keyed by the `DialogueApproach` enum, not by strings. If the GDScript enum does not contain a value that a trait's dictionary references, Godot will not parse the resource. This is caught at load time, not at runtime. To prevent this: trait `.tres` files must use the enum integer values, and the `TraitDatabase` loader validates that all four `DialogueApproach` enum values are present in each trait's affinity dictionary. Any missing approach key is filled with `0.0` and a warning is logged naming the trait and missing approach.

**EC-4: A trait is visible to the player but the NPC doesn't respond to the approach it "should" respond to.**
This is not an edge case — it is intended. The Trait Database defines affinity values; the Conversion Logic Engine applies them to a probability calculation; the Dialogue & Conversion System presents the outcome. A `+1.0` affinity does not guarantee success — it shifts probability. If a player reads `bereaved` and uses GRIEF but the conversion fails, the system is functioning correctly: high affinity means better odds, not certainty. The Player Fantasy section explicitly notes that outcomes should feel explainable, not predetermined. No special handling is needed.

**EC-5: New traits added post-MVP — backward compatibility with existing saved NPCs.**
Save files store trait assignments as arrays of trait ID strings (e.g., `["bereaved", "ambitious"]`). Adding a new trait to the catalogue does not affect existing saves — existing NPCs retain their assigned IDs, which still resolve correctly. Removing or renaming a trait ID would break existing saves. Post-MVP changes must therefore: (a) never remove a trait ID from the catalogue — instead, set a `deprecated: true` field and exclude deprecated traits from new assignment pools; (b) never rename a trait ID — create a new ID and deprecate the old one. The NPC Character System must handle loading a saved NPC whose trait ID is not found in the current catalogue by falling back to a `"unknown_trait"` placeholder trait and logging a warning, rather than crashing.

---

## Dependencies

### Upstream

None. The NPC Trait Database has zero upstream dependencies. It is a Foundation layer system. It does not read from any other game system at runtime. Its only external dependency is the static `.tres` resource file it loads at startup.

### Downstream

| System | Data Consumed | Nature of Dependency |
|---|---|---|
| NPC Character System | Full trait catalogue, per-rarity lists, per-archetype filtered lists, rarity weights | Direct — reads at NPC generation time and any time a new NPC is created |
| Conversion Logic Engine | Per-trait affinity values for a specific approach | Direct — reads on every conversion attempt |
| Dialogue & Conversion System | Trait display name and description (revealed traits only) | Direct — reads when populating NPC inspect panel |
| Portrait & Expression System | Trait archetype tags, specific trait IDs | Prospective (post-MVP) — no MVP reads. Trait-driven micro-expressions would read archetype tags / trait IDs for expression selection; MVP expression selection is belief/outcome-driven only (Portrait & Expression System GDD Rule 6) |
| Faith Spread System | No direct dependency | Indirect — receives social influence weights from NPC Character System, which are archetype-level data not stored here |
| Rival Faith System | No direct dependency | Indirect — operates through Conversion Logic Engine |
| Save & Load System | No dependency at runtime | Indirect — save files contain trait ID strings; loading resolves them through NPC Character System, which calls this database |

---

## Tuning Knobs

### Numeric tuning (lives in GameConfig)

The following values are owned by `GameConfig.traits` (`TraitConfig` domain) and must not be duplicated here. Refer to the Game Config GDD for ranges and defaults.

| Knob | GameConfig Field | Default | Effect on Trait System |
|---|---|---|---|
| Common trait selection weight | `TraitConfig.common_trait_weight` | 60 | Higher values make common traits dominate NPC assignment; lower values give rarer traits a relatively larger share |
| Uncommon trait selection weight | `TraitConfig.uncommon_trait_weight` | 30 | Increase to make uncommon traits appear on most NPCs; decrease to reserve them for memorable characters |
| Rare trait selection weight | `TraitConfig.rare_trait_weight` | 10 | Raise above 15 and rare traits lose their surprise value; drop below 5 and players may never encounter them in a short session |
| Minimum traits per NPC | `TraitConfig.traits_per_npc_min` | 2 | Raising to 3 makes all NPCs feel more complex but increases cognitive load on the player |
| Maximum traits per NPC | `TraitConfig.traits_per_npc_max` | 4 | Raising to 5–6 creates richer characters but risks making some NPCs feel contradictory or hard to read |
| Trait modifier weight | `ConversionConfig.trait_modifier_weight` | 0.25 | The single most impactful trait tuning knob — at 0.0, traits are flavor only; at 1.0, traits fully determine conversion outcomes; 0.20–0.35 is the recommended playtesting range |

### Content tuning (lives in the trait catalogue)

Tuning the trait catalogue itself means editing the `.tres` resource data, not adjusting numeric constants. The meaningful content-level tuning operations are:

- **Adjusting affinity values:** Changing a trait's affinity from `+0.5` to `+1.0` for a specific approach shifts how strongly that trait affects conversion. Any value change must be justified by a playtest observation and documented in a Quick Spec.
- **Adjusting archetype weight bonuses:** Changing how likely a trait is for a given archetype (the percentage bonuses in archetype definitions, which live in the NPC Character System) shapes the character of each role. This is the primary dial for making Merchants feel distinct from Soldiers without changing trait definitions.
- **Adding traits:** New traits can be added at any time without breaking existing content. Follow the entry format. Assign an ID that will never be reused. Tag appropriate archetypes.
- **Deprecating traits:** Set `deprecated: true` on the trait entry. Deprecated traits are excluded from new NPC generation pools but remain resolvable by ID for backward save compatibility.

### Safe ranges for core numeric knobs

| Knob | Conservative Range | Risk Outside Range |
|---|---|---|
| `rare_trait_weight` | 5–15 | Below 5: Rare traits become mythically rare; playtests may not encounter them. Above 20: Rare traits appear on most NPCs; they lose meaning. |
| `trait_modifier_weight` | 0.15–0.40 | Below 0.15: Traits feel cosmetic; NPC reading loses strategic value. Above 0.40: Trait stacking can push success chance to near-certainty or near-zero, undermining Pillar 2 (no dominant strategy). |
| `traits_per_npc_max` | 2–5 | Above 5: Risk of contradictory trait combinations (e.g., `proud` + `lonely` + `bereaved` + `cynical` + `seeker` creates an unreadable character). |

---

## Acceptance Criteria

**AC-1: Database loads at startup without error**
Given the game launches with a valid `trait_database.tres` file at `res://assets/data/traits/trait_database.tres`,
When `TraitDatabase._ready()` completes,
Then no errors or warnings are printed to the Godot output log, and `TraitDatabase.is_loaded()` returns `true`.

**AC-2: Trait lookup by ID returns correct data**
Given the database is loaded,
When `TraitDatabase.get_trait("bereaved")` is called,
Then the returned `TraitData` object has `id == "bereaved"`, `display_name == "Bereaved"`, `rarity == TraitRarity.COMMON`, and `approach_affinity[DialogueApproach.GRIEF] == 1.0`.

**AC-3: Approach-trait affinity returns correct modifier for a known pair**
Given `GameConfig.conversion.trait_modifier_weight == 0.25`,
When `TraitDatabase.get_affinity("bereaved", DialogueApproach.GRIEF)` is called and the result is multiplied by `0.25`,
Then the result equals `0.25` (tolerance ±0.001).

**AC-4: Trait assignment respects rarity weights**
Given a simulation of 10,000 trait assignments using the default weights (60/30/10) against a pool containing equal counts of Common, Uncommon, and Rare traits,
When the counts of assigned traits by rarity are recorded,
Then Common traits constitute between 57% and 63% of all assignments, Uncommon between 27% and 33%, and Rare between 8% and 12%.

**AC-5: No NPC receives duplicate traits**
Given the NPC Character System generates 1,000 NPCs using the Trait Assignment Formula,
When each NPC's trait array is inspected,
Then no NPC's array contains the same trait ID more than once.

**AC-6: traits_per_npc constraint is respected**
Given `GameConfig.traits.traits_per_npc_min == 2` and `GameConfig.traits.traits_per_npc_max == 4`,
When the NPC Character System generates 500 NPCs,
Then every NPC has between 2 and 4 traits inclusive, and no NPC has fewer than 2 or more than 4.

**AC-7: Unknown trait ID returns null without crash**
Given the database is loaded,
When `TraitDatabase.get_trait("nonexistent_trait_id")` is called,
Then the method returns `null` and no error is thrown.

**AC-8: All traits in catalogue have approach affinities for all four approaches**
Given the database is loaded,
When each trait in `TraitDatabase.get_all_traits()` is iterated,
Then every trait's `approach_affinity` dictionary contains keys for `DialogueApproach.GRIEF`, `DialogueApproach.AMBITION`, `DialogueApproach.DOUBT`, and `DialogueApproach.FEAR`, and each value is a float in `[-1.0, 1.0]`.

**AC-9: get_affinity returns 0.0 for an unknown trait ID**
Given the database is loaded,
When `TraitDatabase.get_affinity("nonexistent_id", DialogueApproach.GRIEF)` is called,
Then the return value is `0.0` and no error is thrown.

**AC-10: All 16 MVP traits are present in the loaded catalogue**
Given the database is loaded,
When `TraitDatabase.get_all_traits().size()` is called,
Then the result is 16.

**AC-11: Rarity distribution in catalogue matches design intent**
Given the database is loaded,
When traits are grouped by rarity,
Then the count of COMMON traits is 7, UNCOMMON is 6, and RARE is 3.

---

## Open Questions

**OQ-1: Trait visibility to the player before revelation.**
Should the player see that an NPC *has* hidden traits (a count indicator like "2 traits hidden") but not their content, or should hidden traits be entirely invisible? The current GDD specifies that the hidden/revealed state belongs to the NPC Character System, but the UI convention for communicating hidden traits has not been decided. **Recommended direction:** Show a count of unrevealed traits ("2 traits hidden") so the player knows there is more to learn about this person, without showing what those traits are. This supports Pillar 1 (every soul has a story) by making hidden depth legible.

**OQ-2: Can a trait be partially revealed?**
A fully binary hidden/revealed state is simple. But a "partially revealed" state (the player knows the trait exists but not its full affinity data) could add a middle layer of discovery — the player sees `Bereaved` but doesn't yet know whether DOUBT or GRIEF is the stronger approach. **Recommended direction:** Defer to MVP with binary states. If playtests suggest players want a discovery arc within a single NPC, add a `PARTIALLY_REVEALED` state post-MVP.

**OQ-3: Trait contradiction handling.**
No rules currently prevent an NPC from receiving both `proud` and `broken_by_loss` — a combination that is thematically coherent but creates near-opposite affinity signals for GRIEF (0.0 vs +1.0) and FEAR (-1.0 vs 0.0). Is this a feature (complex, realistic) or a bug (confusing, unreadable)? **Recommended direction:** Allow contradictions at MVP. The conversion system handles them mathematically (affinities sum), and the narrative team can write dialogue that acknowledges internal conflict. If playtests report confusion, add a post-MVP archetype-level constraint that prevents specific trait pairs from co-occurring.

**OQ-4: Social influence weight ownership.**
The archetype definitions above list social influence weights (e.g., Elder = 2.0, Noble = 2.5). These values feed directly into the Faith Spread System. Currently this document defines them as part of the archetype description, but they likely belong in the NPC Character System GDD (which owns archetypes) rather than here. **Recommended direction:** Move social influence weights to the NPC Character System GDD when that document is authored. The values listed here are provisional design intent and should be treated as a handoff note to that GDD, not as canonical definitions.
