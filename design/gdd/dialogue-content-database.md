# Dialogue Content Database

> **Status**: Designed
> **Author**: Design session + narrative-director agent
> **Last Updated**: 2026-04-20
> **Implements Pillar**: Pillar 1 — Every Soul Has a Story; Pillar 4 — History Writes Itself

## Overview

The Dialogue Content Database is a read-only data registry loaded at game startup from a single resource file (`res://assets/data/dialogue/dialogue_database.tres`). It is the authoritative store of all player-facing text in *The Faithful* — approach names and descriptions, dialogue lines presented during a conversion attempt, outcome summaries displayed after a conversion resolves, and NPC reaction strings for the inspect panel. It holds no logic: it does not compute success probabilities, choose which line to display, or track what has been said to whom. Those concerns belong to the Dialogue & Conversion System and the Conversion Logic Engine respectively.

The database organises content into three domains: **Approach Content** (names, short descriptions, and dialogue lines for each of the four canonical approaches — `GRIEF`, `AMBITION`, `DOUBT`, and `FEAR`), **Outcome Content** (result strings for conversion success, partial progress, resistance, and hardening, keyed by approach and outcome type), and **NPC Flavour Content** (archetype-level short descriptors and inspect-panel lines used by the Portrait & Expression System and the Conversion UI).

The database exposes a typed GDScript API (`DialogueDatabase`) that consuming systems call to retrieve content by approach, outcome type, and archetype key. It never stores runtime state — no record of which line was last shown, which NPC has heard which line, or how many times an approach has been tried. Those concerns belong to the Dialogue & Conversion System. The database exists because every system that displays text to the player needs a single authoritative source — centralising content prevents duplication, enables late-stage writing revisions without touching game logic, and ensures all text can be localised from one place.

## Player Fantasy

The Dialogue Content Database is not experienced directly — players feel it through the texture of every word spoken during a conversion. The writing within it should be held to a single test: **every line may be the only scene this NPC gets.** At 8–12 NPCs per village and 10–20 minute sessions, most characters receive one or two exchanges in a given playthrough. Each line must carry the full weight of meeting a person once.

A successful conversion in words should feel like recognition — the moment an NPC hears their own unspoken thought spoken aloud by the prophet. It is not persuasion; it is being seen. Partial progress should feel like a hand briefly touched and withdrawn. Resistance should feel like a life the player was not invited into — firmly, humanely closed.

The four dialogue approaches are emotional registers, not mechanical labels. Approach lines must be specific to their register and non-interchangeable: a GRIEF line that could be reshuffled into FEAR without loss of meaning is too vague and fails Pillar 1. GRIEF is hushed and present-tense. AMBITION names a hunger the listener hasn't admitted aloud. DOUBT asks a careful question rather than winning a debate. FEAR states an uncomfortable truth both parties wish weren't true. If any line could belong to any approach, it belongs to none — and should be rewritten.

## Detailed Design

### Core Rules

1. **The database is a static content registry.** It is loaded once at game startup from `res://assets/data/dialogue/dialogue_database.tres` and never modified at runtime. It holds no state — no record of which lines have been shown, which NPCs have been approached, or how many times any line has appeared. State tracking belongs to the Dialogue & Conversion System.

2. **Four content domains.** The database stores all player-facing text across exactly four domains:
   - **Approach Content** — lines the prophet speaks when attempting a conversion using one of the four canonical approaches.
   - **Outcome Content** — result text displayed after a conversion attempt resolves.
   - **NPC Flavour Content** — archetype intro descriptors and inspect-panel lines shown in the NPC portrait panel.
   - **Rival Faith Content** — lines attributed to rival missionaries, witnessed by the player, keyed by the same four canonical approaches.

3. **The four canonical dialogue approaches** (locked vocabulary — must not be modified here; defined in the NPC Trait Database):
   - `GRIEF` — shared suffering and comfort
   - `AMBITION` — opportunity, status, and future reward
   - `DOUBT` — philosophical inquiry and reasoned argument
   - `FEAR` — consequence, mortality, and existential threat

4. **The four canonical conversion outcomes** (owned by this GDD and referenced by all consuming systems):
   - `CONVERTED` — NPC fully converts to the player's faith
   - `SOFTENED` — NPC's openness increased but they did not convert
   - `RESISTED` — no change to NPC's belief state; neutral
   - `HARDENED` — NPC's resistance increased; they are now harder to convert

5. **Line pool size.** Every approach slot, outcome slot, rival faith slot, and inspect line slot contains exactly **3 lines** at MVP. This is the minimum pool size at which random-without-recent-repeat selection can function without immediate repetition. Pool size is uniform across all slots at MVP; post-MVP, high-frequency slots may be expanded.

6. **NPC flavour structure.** Each of the 7 NPC archetypes (Laborer, Elder, Merchant, Soldier, Scholar, Widow/Bereaved, Noble) has:
   - `short_descriptor: String` — one sentence shown in the portrait panel on first encounter, before any traits are revealed (the "stranger at a distance" impression).
   - `inspect_lines: Array[String]` — 3 lines shown when the player tap-inspects the NPC. These describe observable behaviour, social posture, or first impressions — not trait information (trait text is owned by the NPC Trait Database's `description` fields).

7. **Outcome content is keyed by approach–outcome pair.** A GRIEF success line is distinct from an AMBITION success line. The database contains 16 outcome slots (4 approaches × 4 outcome types) × 3 lines = **48 outcome summary strings** at MVP. Generic outcome text (the same line regardless of which approach caused the outcome) is not permitted — it collapses the emotional distinction between approaches.

8. **Rival faith lines use the same approach keys as player lines.** Rival missionaries speak from the same four emotional registers as the player. Lines are keyed by `DialogueApproach` and returned as a pool of 3. They are written in third person or reported speech (the player witnesses, not speaks) and must not be interchangeable with player approach lines — the rival's voice is audibly different even when using the same approach.

9. **Exposed API (read-only, five methods):**
   - `get_approach_lines(approach: DialogueApproach) -> Array[String]` — returns the full 3-line pool for the given approach. Calling system handles line selection and recency tracking.
   - `get_outcome_summary(approach: DialogueApproach, outcome: ConversionOutcome) -> Array[String]` — returns the 3-line pool for the given approach–outcome pair.
   - `get_npc_flavour(archetype: NPCArchetype) -> NPCFlavourData` — returns the archetype's short descriptor and inspect lines.
   - `get_rival_lines(approach: DialogueApproach) -> Array[String]` — returns the 3-line rival faith pool for the given approach.
   - `is_loaded() -> bool` — returns true after startup load completes without error.
   The database does **not** expose: line selection logic, recency state, NPC-level data, or any runtime tracking.

10. **Writing rules (mandatory content constraints — enforced at content review, not at runtime):**
    - **Angle Constraint:** Each of the 3 lines in a slot must approach the same emotional beat from a structurally different angle (different concrete detail, different NPC action described, different sensory register). Rewording the same image with synonyms fails this constraint.
    - **No Shared Nouns:** Within a slot, the 3 lines must not repeat the same concrete noun. If line 1 mentions "her hands," line 2 cannot.
    - **Approach Purity Test:** Every line must fail if moved to a different approach's slot. A GRIEF line that reads as FEAR is too vague and must be rewritten.
    - **Tense Convention:** GRIEF lines are present-tense (the moment of speaking). AMBITION lines are future-tense (what comes next). DOUBT and FEAR may use either but must be consistent within a slot.
    - **Outcome Lines Are Reports:** Outcome summaries describe what the NPC did — action, posture, expression. They do not interpret ("she seemed moved") or pass judgment. The player provides their own interpretation.

---

### States and Transitions

The Dialogue Content Database is **stateless**. It contains only static text content that does not change during or between play sessions. The database is loaded once at startup and never written to at runtime.

No state machine applies. The single meaningful lifecycle event is the load:

| Phase | State | Description |
|---|---|---|
| Before startup load | `UNLOADED` | Resource file has not been read. `is_loaded()` returns false. All API calls return null. |
| After successful load | `LOADED` | All content is in memory. `is_loaded()` returns true. All API calls return content. |
| Load failure | `UNLOADED` | Resource file missing or malformed. Error logged. Game cannot proceed without a fallback. |

No transitions exist after the `LOADED` state is reached. The database does not reload, patch, or update at runtime.

---

### Interactions with Other Systems

| Consuming System | Data Requested | Interface Used |
|---|---|---|
| Dialogue & Conversion System | Approach lines for the chosen approach; outcome summary for the resolved `(approach, outcome)` pair | `get_approach_lines(approach)`, `get_outcome_summary(approach, outcome)` |
| Portrait & Expression System | NPC flavour data — short descriptor and inspect lines — for the NPC's archetype | `get_npc_flavour(archetype)` |
| Conversion UI | Displays what Dialogue & Conversion System and Portrait & Expression System supply — no direct database reads | Indirect (via the two systems above) |
| Rival Faith System | Rival approach lines for the approach the rival missionary is using | `get_rival_lines(approach)` |
| NPC Character System | No direct dependency — archetype identifiers originate here but NPC Character System does not read the dialogue database | None |
| Conversion Logic Engine | No direct dependency — it reads trait affinities from the NPC Trait Database, not text from this database | None |
| Save & Load System | No dependency — dialogue content is static config; nothing here is serialised | None |

## Formulas

### Content Volume Formula

This formula defines the total number of strings stored in the database as a function of its structural parameters. It serves as a correctness invariant: if a content build produces a string count that differs from this formula's output, the database is malformed.

```
V_total = (A × L_approach) + (A × O × L_outcome) + (R × (1 + L_inspect)) + (A × L_rival)
```

**Variables:**

| Symbol | Name | Type | Range | Description |
|---|---|---|---|---|
| `A` | approach_count | int | {4} | Number of canonical dialogue approaches. Fixed at 4 (GRIEF, AMBITION, DOUBT, FEAR). |
| `O` | outcome_count | int | {4} | Number of canonical conversion outcomes. Fixed at 4 (CONVERTED, SOFTENED, RESISTED, HARDENED). |
| `R` | archetype_count | int | {7} | Number of NPC archetypes. Fixed at 7 at MVP. |
| `L_approach` | lines_per_approach | int | [3, unbounded] | Lines per approach slot. MVP default: 3. |
| `L_outcome` | lines_per_outcome | int | [3, unbounded] | Lines per approach–outcome slot. MVP default: 3. |
| `L_inspect` | inspect_lines_per_archetype | int | [3, unbounded] | Inspect panel lines per archetype. MVP default: 3. The `+1` in the formula accounts for the `short_descriptor`, which is a single string outside the inspect pool. |
| `L_rival` | lines_per_rival_approach | int | [3, unbounded] | Lines per rival faith approach slot. MVP default: 3. |
| `V_total` | total_string_count | int | [1, unbounded] | Total strings stored in the database. |

**Output range:** Uncapped. There is no gameplay maximum — the constraint on V_total is content budget, not game logic. The formula is used to validate that the built database matches the designed specification.

**MVP worked example** (all L values = 3):
- Approach lines: 4 × 3 = 12
- Outcome lines: 4 × 4 × 3 = 48
- Flavour content: 7 × (1 + 3) = 28
- Rival faith lines: 4 × 3 = 12
- **V_total = 100**

**Note on recency constraint:** The minimum viable value for any `L_*` variable is determined by the recency window `W` defined in the Dialogue & Conversion System: all `L_*` values must exceed `W`. At MVP, `W = 2` (last 2 lines excluded from selection), so `L_* ≥ 3` for all slot types. The recency window formula belongs in the Dialogue & Conversion System GDD, not here.

## Edge Cases

**EC-1: A slot's line pool contains fewer than 3 entries at load time (content author error).**
The database logs a warning identifying the exact slot (e.g., `[DialogueDatabase] WARN: approach slot GRIEF has 2 lines — minimum is 3`), sets `is_loaded()` to `false`, and returns an empty array for that slot. Returning partial content would silently allow the Dialogue & Conversion System's recency-window logic to enter an infinite loop or always return the same line — a worse failure than refusing to serve the slot.

**EC-2: An `NPCFlavourData` entry's `short_descriptor` is an empty string.**
`get_npc_flavour()` returns the struct with the empty descriptor (inspect lines may be valid). `is_loaded()` remains `true` — the struct is structurally present. The Portrait & Expression System must treat an empty `short_descriptor` as a content error and use a safe fallback string rather than displaying a blank panel. A warning is logged naming the archetype.

**EC-3: The same string appears twice in the same slot (duplicate line).**
The database does not deduplicate at runtime. Deduplication is a content pipeline responsibility — a build-time validation tool must detect and reject duplicate lines before the resource ships. Runtime deduplication would silently reduce the effective pool size below 3 without the caller knowing, causing the recency-window logic to fail. A duplicate caught at build time surfaces the author error at the correct moment.

**EC-4: A new `DialogueApproach`, `ConversionOutcome`, or `NPCArchetype` value is added post-MVP without corresponding content in the database.**
The API method called with the new enum value hits the invalid-key path and returns an empty array with a warning — the database cannot distinguish "valid enum value with no content" from "invalid enum value." The content volume formula (`V_total`) acts as the correctness invariant: adding an approach increments `A` from 4, and any content build that does not update content accordingly will fail the formula check at build time. Post-MVP formula extension note: if per-slot `L` values diverge (some slots expanded beyond 3), the MVP formula's uniform `L` assumption breaks and the formula must be generalised to sum per-slot counts.

**EC-5: A localised string for a slot entry is an empty string in the translated resource.**
The database must treat any `string.is_empty()` entry in a pool as a missing line and apply the under-filled-slot rule (EC-1): log a warning and set `is_loaded()` to `false` for that locale. If a translation key is missing entirely, Godot's `tr()` fallback returns the raw key identifier — the player sees `"dialogue.grief.01"` rather than dialogue. This is a content pipeline validation failure; the database cannot detect it at runtime.

**EC-6: `get_npc_flavour()` returns an `NPCFlavourData` resource by reference.**
GDScript passes `Resource` objects by reference. A consuming system that mutates the returned object would corrupt the database for all subsequent callers in the same session. `get_npc_flavour()` must return a copy (`.duplicate()`) or `NPCFlavourData` must be implemented as a non-`Resource` type (plain `Dictionary` or a `RefCounted` subclass with no shared mutable fields). This is an implementation constraint enforced at architecture review, not a content edge case.

**EC-7: An approach line contains a proper noun (character name, place name) that does not exist in all player game states.**
The database is a static registry with no access to runtime game state and cannot resolve context-dependent references. Any line containing a proper noun that is not guaranteed to exist in every possible game state fails content review and must be rewritten using concrete observable detail (physical object, sensory impression, relational position). This extends Core Rule 10 (Approach Purity Test): approach lines must be proper-noun-free at authoring time.

**EC-8: An outcome line's emotional register is incompatible with its outcome key (e.g., a HARDENED slot line reads as progress).**
Outcome content is keyed by approach–outcome pair. A GRIEF/HARDENED slot must contain lines describing an NPC closing off — not language readable as softening or success. Content review must include a wrong-key test: show the line without its key and verify a reviewer independently assigns the correct outcome. Any outcome line that could plausibly belong to a different outcome type fails review and must be rewritten. This extends Core Rule 10 (Outcome Lines Are Reports).

**EC-9: Rival faith lines are tonally indistinguishable from player approach lines for the same approach.**
Core Rule 8 requires rival lines to be "audibly different." The enforcement test: a player approach line and a rival approach line for the same approach must be reviewed side-by-side. A reviewer given both lines without labels must be able to identify which is rival and which is player. If they cannot, both must be rewritten. Structural markers that enforce distinction: rival lines use reported speech or third-person observation; the player's approaches are always voiced in second person.

**EC-10: The same archetype inspect line is shown to two consecutive NPC encounters sharing the same archetype.**
The database is stateless and does not track recency at the archetype level. The Dialogue & Conversion System is responsible for maintaining **archetype-scoped** inspect line recency state (not NPC-scoped). This is a downstream contract requirement: the database supplies a pool of 3 inspect lines; the consuming system must exclude the last-shown line per archetype across all NPC encounters, not just per-NPC. If this requirement is absent from the Dialogue & Conversion System GDD, it is a dependency gap.

**EC-11: A DOUBT or FEAR slot contains lines of mixed tense (some present, some future).**
Core Rule 10 states DOUBT and FEAR may use either tense but must be consistent within a slot. Tense consistency is evaluated across all 3 lines as a unit — individual lines that pass tense review can still fail slot-level review. Content authors must assign a slot-level tense tag (`SLOT_TENSE: present` or `SLOT_TENSE: future`) in the source file, and all 3 lines must conform to it. Mixed-tense slots fail review unconditionally.

**EC-12: A 3-line slot's collective emotional register drifts toward a different approach, even though each individual line passes the Approach Purity Test.**
Individual purity can pass while the slot as a whole reads as an adjacent approach (e.g., a DOUBT slot whose 3 lines all foreground mortality will read as FEAR across repeated encounters). Content review must include a slot-level purity audit: the 3 lines are read as a sequence and a reviewer identifies the approach from the slot alone. If the slot reads as a different approach, at least one line must be replaced — even if no individual line fails the single-line purity test.

**EC-13: An archetype's `short_descriptor` and `inspect_lines` describe contradictory first impressions.**
The `short_descriptor` and all 3 `inspect_lines` for an archetype must be reviewed as a set of 4. They must describe different facets of the same observable person — not different people. A contradiction between any of the 4 strings (e.g., descriptor calls the NPC "still and watchful" but an inspect line says "gestures broadly while talking to neighbours") fails archetype content review and destabilises the player's model of the character before any conversion attempt begins.

## Dependencies

### Upstream

None. The Dialogue Content Database has zero upstream dependencies. It is a Foundation layer system. It does not read from any other game system at runtime. Its only external dependency is the static `.tres` resource file it loads at startup.

### Downstream

| System | Data Consumed | Nature of Dependency |
|---|---|---|
| Dialogue & Conversion System | Approach lines for the chosen approach; outcome summary strings for the resolved `(approach, outcome)` pair | Direct — reads on every conversion attempt. Must maintain per-NPC and per-archetype recency state for line selection; the database only supplies the pool. |
| Portrait & Expression System | `NPCFlavourData` per archetype — `short_descriptor` and `inspect_lines` | Direct — reads when rendering the NPC portrait panel on first encounter and on player tap-inspect. |
| Rival Faith System | Rival approach lines keyed by `DialogueApproach` | Direct — reads when the rival missionary makes a conversion attempt. |
| Conversion UI | No direct reads — displays content that Dialogue & Conversion System and Portrait & Expression System have already retrieved | Indirect (via the two systems above). |
| NPC Character System | No direct dependency — archetype identifiers originate here but NPC Character System does not query the dialogue database | None. |
| Conversion Logic Engine | No direct dependency — reads trait affinities from the NPC Trait Database, not text from this database | None. |
| Save & Load System | No dependency — dialogue content is static config; nothing here is serialised in save files | None. |

## Tuning Knobs

### Numeric tuning (lives in GameConfig)

This system has no numeric tuning knobs in the conventional sense — it is a static content registry with no probability calculations, scaling factors, or timers. The values that govern how its content is consumed (recency window size `W`, timing hold durations) belong to other systems:

| Knob | Owner | Effect on This System |
|---|---|---|
| Recency window `W` | Dialogue & Conversion System | Determines the minimum viable `L_*` value across all slots. Must satisfy `W < L_*` for all slot types. At MVP: `W = 2`, requiring `L_* ≥ 3`. |
| `UITimingConfig.dialogue_line_hold_sec` | `UITimingConfig` (owned by Game Config) | Controls how long an approach line is displayed — not defined here, but affects how many words a line can contain before it exceeds display time. Writing constraint: lines must be readable within the configured hold duration. |

### Content tuning (lives in the database resource)

Tuning the content means editing the `.tres` resource or source content file directly. The meaningful content-level tuning operations are:

- **Expanding a line pool:** Adding a 4th or 5th line to a frequently repeated slot increases variety. Any expansion must update `V_total` per the content volume formula. The recency window `W` does not need to change — it only needs to remain below the new `L_*` value.
- **Adjusting `L_*` values uniformly:** If all slot pools are expanded from 3 to 5 lines post-MVP, `L_approach = L_outcome = L_inspect = L_rival = 5` and `V_total` increases to 168. No gameplay tuning changes are required — the Dialogue & Conversion System's recency window remains valid as long as `W < 5`.
- **Adding a new archetype:** New archetype requires one `short_descriptor` and 3 `inspect_lines`. `R` increments by 1, `V_total` increases by 4. No other system changes are required at the database layer, but the NPC Character System must also recognise the new archetype ID.
- **Deprecating content:** Lines cannot be removed from an active slot (pool drops below minimum). To retire a line, replace it with a different line rather than deleting it. Slots must always maintain `L_* ≥ W + 1`.

### Cross-system constraint

All `L_*` variables must exceed the recency window `W` defined in the Dialogue & Conversion System. This is the single most important constraint linking this database to its consuming system. If `W` is tuned upward post-MVP (e.g., to `W = 3` for a longer no-repeat guarantee), all `L_*` values must be verified to remain above `W`. A `W` change that violates this constraint without expanding content pools will cause the selection algorithm to fail.

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

**AC-1: Database loads at startup without error**
Given the game launches with a valid database resource at `res://assets/data/dialogue/dialogue_database.tres`, when startup load completes, then `DialogueDatabase.is_loaded()` returns `true` and no errors or warnings are printed to the Godot output log.

**AC-2: Total string count matches formula (content audit — ADVISORY)**
Given the MVP database resource is built, when content is audited by calling all approach slots, outcome slots, archetype slots, and rival slots and counting non-empty strings, then the total equals 100 per the Section D formula (`V_total = 4×3 + 4×4×3 + 7×(1+3) + 4×3 = 100`). This criterion is verified by a content audit pass, not an automated runtime test.

**AC-3: Approach line pool is correct for all four approaches**
Given the database is loaded, when `get_approach_lines()` is called for each of the four approaches (GRIEF, AMBITION, DOUBT, FEAR), then each call returns exactly 3 non-empty strings.

**AC-4: Outcome summary pool is correct for all 16 approach–outcome pairs**
Given the database is loaded, when `get_outcome_summary(approach, outcome)` is called for all 16 valid combinations (4 approaches × 4 outcomes), then each call returns exactly 3 non-empty strings.

**AC-5: NPC flavour data is valid for all seven archetypes**
Given the database is loaded, when `get_npc_flavour()` is called for each of the 7 archetypes (Laborer, Elder, Merchant, Soldier, Scholar, Widow/Bereaved, Noble), then each call returns an `NPCFlavourData` object with a non-empty `short_descriptor` string and an `inspect_lines` array containing exactly 3 non-empty strings.

**AC-6: Rival faith line pool is correct for all four approaches**
Given the database is loaded, when `get_rival_lines()` is called for each of the four approaches, then each call returns exactly 3 non-empty strings.

**AC-7: Invalid approach enum returns empty array without crash**
Given the database is loaded, when `get_approach_lines()` is called with an invalid or out-of-range `DialogueApproach` value, then the method returns an empty `Array` and no exception or crash occurs.

**AC-8: Invalid outcome combination returns empty array without crash**
Given the database is loaded, when `get_outcome_summary()` is called with an invalid approach or invalid outcome enum value, then the method returns an empty `Array` and no exception or crash occurs.

**AC-9: Invalid archetype returns null without crash**
Given the database is loaded, when `get_npc_flavour()` is called with an invalid `NPCArchetype` value, then the method returns `null` and no exception or crash occurs.

**AC-10: Under-filled slot sets is_loaded() to false**
Given a database resource where one slot contains fewer than 3 lines, when `DialogueDatabase._ready()` completes, then `is_loaded()` returns `false` and a warning is logged identifying the under-filled slot.

**AC-11: All get_* methods return safely when is_loaded() is false**
Given `is_loaded()` returns `false` (e.g., after a load failure or with an under-filled slot), when any of the four `get_*` methods are called, then each returns an empty array or `null` (matching its invalid-input contract) without crashing.

**AC-12: Empty short_descriptor triggers warning but returns struct**
Given a database where one archetype's `short_descriptor` is an empty string, when `get_npc_flavour()` is called for that archetype, then the method returns the `NPCFlavourData` struct (not `null`), and a warning is logged to the Godot output identifying the archetype.

**AC-13: get_npc_flavour() returns a copy, not a shared reference**
Given the database is loaded, when `get_npc_flavour(ELDER)` is called twice and the `short_descriptor` field of the first returned object is mutated, then the second call returns an object with the original `short_descriptor` value unchanged.

## Open Questions

**OQ-1: Schema versioning for the database resource.**
The systems-designer identified schema version mismatch as the most likely post-MVP failure mode. No schema versioning mechanism has been designed for the `.tres` resource. Should the database resource include a `schema_version: int` field checked at load time? If the schema changes (e.g., `NPCFlavourData` gains a field), what is the migration path for existing resource files? **Recommended direction:** Add a `schema_version` field at MVP even if it is always `1` — establishing the pattern costs nothing and the alternative is an unmigrateable break at the first post-MVP schema change.

**OQ-2: Content pipeline tooling for build-time validation.**
Several edge cases (EC-3 duplicate lines, EC-5 localisation completeness, EC-7 proper noun detection, EC-11 slot-level tense tags) depend on a build-time content validation tool that does not yet exist. This GDD specifies what the tool must catch but not how it is implemented. **Recommended direction:** Design the validation tool as a Godot editor plugin or a standalone script that reads the source content file and emits structured errors. This becomes a tools-programmer task in a future sprint.

**OQ-3: Source content format — data in .tres vs. external format.**
The database is specified to load from a `.tres` file, but authoring dialogue content directly in `.tres` format is impractical for writers. The actual authoring format (JSON, CSV, YAML, Google Sheets export) and the pipeline that converts it to `.tres` has not been decided. **Recommended direction:** Decide on the authoring format before any content is written. This decision will become an ADR. Likely choice: YAML or CSV with a Godot import plugin, keeping the runtime `.tres` format intact.

**OQ-4: Localisation integration point.**
The GDD specifies that the database stores text that will need localisation, but it does not specify whether localisation is handled via Godot's built-in `TranslationServer` (string key lookup), a separate localised `.tres` per locale, or another mechanism. **Recommended direction:** Defer to the Localisation system GDD (not yet designed). Flag this database as a localisation dependency — all 100 MVP strings must be accessible via a stable key scheme for translation.

**OQ-5: "Deep attempt" line variants.**
The systems-designer flagged that there is currently no distinction between a first approach to an NPC and a sixth approach. Post-MVP, lines that acknowledge repeated contact ("You've said that before, prophet") would require either a separate content pool keyed by attempt depth or a flag on the approach call. This requires the Dialogue & Conversion System to surface attempt count when requesting lines. **Recommended direction:** Design out of scope for MVP. Ensure the Dialogue & Conversion System's recency tracking architecture captures attempt count per NPC so this can be wired in post-MVP without an API change to this database.
