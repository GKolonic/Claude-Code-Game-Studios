# Game Config

> **Status**: Designed
> **Author**: Design session + systems-designer agent
> **Last Updated**: 2026-08-09
> **Implements Pillar**: All pillars (infrastructure — enables tuning without code changes)

## Summary

Game Config is the single external data file that holds every tunable value in The Faithful. No gameplay value is ever hardcoded in GDScript — all balance numbers, timing constants, and threshold values live in `.tres` resource files organised by domain and loaded at startup by an Autoload singleton. When a designer changes a number, they edit a resource file; no code changes, no recompile.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None`

## Overview

Game Config is The Faithful's tuning infrastructure. Every balance value, timing constant, probability modifier, and threshold used by gameplay systems is stored in external Godot `.tres` resource files organised by domain (conversion, traits, faith spread, rival faith, progression, UI timing, portrait). An Autoload singleton named `GameConfig` loads these files at startup, validates ranges, and exposes typed accessors to the rest of the game. Systems never read from files directly — they call `GameConfig.conversion.base_success_chance` and receive a float. This separation means designers can change any number without touching GDScript, and the entire tuning surface is visible in the Godot editor's resource inspector rather than buried in code.

## Player Fantasy

The player never directly experiences Game Config — they experience its effects. When a balance pass makes stubborn NPCs slightly more persuadable, or when a tuning session makes the rival faith feel more threatening, those shifts are what players feel. For the designer, the fantasy is control: every number has a name, a range, and a home. Nothing is magic. Nothing requires a code deploy to change. The game is tunable from the editor, and the editor is the truth.

## Detailed Design

### Core Rules

1. **No hardcoded values.** Every numeric constant used in gameplay logic must be sourced from a GameConfig domain. The only exceptions are pure mathematical constants (e.g., `PI`, array indices, loop bounds) and strings used as dictionary keys. If a programmer hardcodes a balance value, it is a bug.

2. **Seven config domains.** All tuning values are grouped into exactly seven `Resource` subclasses, each in its own `.tres` file:
   - `ConversionConfig` — approach success rates, trait modifier weights, cooldown durations
   - `TraitConfig` — trait rarity weights, archetype trait counts, modifier magnitudes
   - `FaithSpreadConfig` — passive spread radius, spread rate per tick, attrition rate
   - `RivalFaithConfig` — rival aggression interval, counter-approach selection weights, re-hardening strength
   - `ProgressionConfig` — faith power thresholds, milestone unlock triggers, expansion path costs
   - `UITimingConfig` — dialogue display durations, transition timings, animation hold frames
   - `PortraitConfig` — dissolve timings, conversion overlay colour/timing, reduced-motion overrides (`res://assets/data/config/portrait_config.tres`)

3. **Pull pattern.** Systems read config values on demand by calling `GameConfig.[domain].[field]`. Config does not push values to systems, emit signals on load, or cache values inside callers. This prevents stale-value bugs.

4. **Immutable at runtime on mobile.** Once loaded on a shipped build, config values do not change during a play session. Hot-reload (Rule 5) is editor-only and stripped from export builds.

5. **Editor-only hot-reload.** In the Godot editor, `GameConfig` watches its `.tres` files for changes and reloads the affected domain when a file is saved. This allows live tuning without restarting the scene. Hot-reload emits a `config_reloaded(domain_name: String)` signal that systems may connect to if they cache config values locally (though they are strongly discouraged from doing so — see Rule 3).

6. **Validation on load.** On startup (and on hot-reload), `GameConfig` validates every field against its declared range (min/max in the Formulas section). Out-of-range values are clamped and a warning is logged. Missing required fields cause a hard error that prevents the game from running.

7. **Single-file authority.** There is exactly one `.tres` file per domain. There are no per-level overrides, per-difficulty multiplier files, or runtime patches. Difficulty scaling is implemented as fields within the relevant domain (e.g., `ConversionConfig.hard_mode_base_modifier: float`), not as a separate config layer.

### States and Transitions

| State | Description | Entry Condition | Exit Condition |
|---|---|---|---|
| `UNLOADED` | No config data in memory | Game start | `GameConfig._ready()` is called |
| `LOADING` | Reading `.tres` files from disk | Autoload `_ready()` begins | All 7 domain files parsed |
| `LOADED` | All domains validated and accessible | All files parsed and validated | Game exits, or hot-reload triggered |
| `HOT_RELOADING` | A domain file changed (editor only) | File watcher detects a `.tres` save | Domain re-validated and swapped |

The game's `_ready()` calls in other Autoloads must not complete until `GameConfig` is in the `LOADED` state. Autoload order in `project.godot` must list `GameConfig` first.

### Interactions with Other Systems

| System | Relationship | What GameConfig Provides |
|---|---|---|
| Conversion Logic Engine | Direct consumer | `ConversionConfig` — base rates, trait modifier weights, cooldown values |
| NPC Character System | Direct consumer | `TraitConfig` — rarity weights, archetype trait counts |
| Faith Spread System | Direct consumer | `FaithSpreadConfig` — spread radius, rate, attrition |
| Rival Faith System | Direct consumer | `RivalFaithConfig` — aggression interval, counter-approach weights |
| Multi-path Expansion System | Direct consumer | `ProgressionConfig` — faith power thresholds, expansion costs |
| Dialogue & Conversion System | Direct consumer | `UITimingConfig` — dialogue hold durations |
| Conversion UI | Direct consumer | `UITimingConfig` — transition timings, animation holds |
| Portrait & Expression System | Direct consumer | `PortraitConfig` — dissolve timings, overlay colour/timing, reduced-motion overrides |
| HUD & Progress System | Direct consumer | `ProgressionConfig` — milestone thresholds for progress display |
| Game State Manager | Indirect consumer | Reads progression thresholds via GameConfig to evaluate win conditions |
| Save & Load System | Non-consumer | Config is not saved with game state — it is always reloaded from `.tres` files |
| All other systems | No direct dependency | Systems that do not consume tuning values do not reference GameConfig |

## Formulas

### Validation / Clamping Formula

Applied to every field on load and hot-reload:

```
loaded_value = clamp(file_value, field.min, field.max)
if loaded_value != file_value:
    push_warning("GameConfig: [domain].[field] clamped from %s to %s" % [file_value, loaded_value])
```

### Domain Field Ranges

**ConversionConfig**

| Field | Min | Max | Default | Required |
|---|---|---|---|---|
| `base_success_chance` | 0.05 | 0.95 | 0.35 | Yes |
| `trait_modifier_weight` | 0.0 | 1.0 | 0.25 | Yes |
| `approach_cooldown_turns` | 1 | 10 | 3 | Yes |
| `hard_mode_base_modifier` | 0.5 | 1.0 | 0.8 | No |
| `max_approaches_per_npc` | 1 | 20 | 5 | Yes |

**TraitConfig**

| Field | Min | Max | Default | Required |
|---|---|---|---|---|
| `common_trait_weight` | 1 | 100 | 60 | Yes |
| `uncommon_trait_weight` | 1 | 100 | 30 | Yes |
| `rare_trait_weight` | 1 | 100 | 10 | Yes |
| `traits_per_npc_min` | 1 | 5 | 2 | Yes |
| `traits_per_npc_max` | 1 | 8 | 4 | Yes |

**FaithSpreadConfig**

| Field | Min | Max | Default | Required |
|---|---|---|---|---|
| `passive_spread_radius` | 1 | 5 | 2 | Yes |
| `spread_rate_per_tick` | 0.01 | 0.5 | 0.05 | Yes |
| `attrition_rate_per_tick` | 0.0 | 0.3 | 0.02 | Yes |
| `spread_tick_interval_sec` | 5.0 | 120.0 | 30.0 | Yes |

**RivalFaithConfig**

| Field | Min | Max | Default | Required |
|---|---|---|---|---|
| `aggression_interval_turns` | 2 | 20 | 6 | Yes |
| `reharden_strength` | 0.1 | 1.0 | 0.4 | Yes |
| `counter_approach_random_weight` | 0.0 | 1.0 | 0.3 | Yes |

**ProgressionConfig**

| Field | Min | Max | Default | Required |
|---|---|---|---|---|
| `faith_power_per_conversion` | 1 | 100 | 10 | Yes |
| `missionary_unlock_threshold` | 10 | 1000 | 100 | Yes |
| `court_unlock_threshold` | 10 | 1000 | 250 | Yes |
| `crusade_unlock_threshold` | 10 | 1000 | 500 | Yes |
| `village_win_conversion_pct` | 0.5 | 1.0 | 0.75 | Yes |

**UITimingConfig**

| Field | Min | Max | Default | Required |
|---|---|---|---|---|
| `approach_confirm_hold_sec` | 0.3 | 1.2 | 0.6 | Yes |
| `hardened_reveal_hold_sec` | 0.5 | 1.5 | 1.0 | Yes |
| `dialogue_line_hold_sec` | 0.5 | 5.0 | 2.0 | Yes |
| `outcome_display_hold_sec` | 0.5 | 5.0 | 2.5 | Yes |
| `scene_transition_duration_sec` | 0.1 | 2.0 | 0.5 | Yes |
| `portrait_expression_hold_frames` | 1 | 120 | 30 | Yes |
| `trait_card_reveal_ms` | 200 | 600 | 350 | Yes |

*Fields `approach_confirm_hold_sec` and `hardened_reveal_hold_sec` proposed by the DCS GDD; `trait_card_reveal_ms` proposed by the Conversion UI GDD (system #12, F3) — all three consumed by the Conversion UI. Added 2026-08-09.*

**PortraitConfig**

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

*No change to `UITimingConfig.portrait_expression_hold_frames` (1–120, default 30) — already present; it is now also consumed by the Portrait & Expression System as the expression hold window.*

## Edge Cases

**EC-1: Missing `.tres` file.** If a domain file cannot be found at startup, `GameConfig` logs a hard error and the game halts with a descriptive message: `"GameConfig: Required file res://assets/data/config/conversion_config.tres not found."` The game must not continue with missing config — a missing file means an unknown tuning state, which is worse than a crash.

**EC-2: Corrupt or unparseable `.tres` file.** Godot's resource loader will throw a parse error. `GameConfig` does not catch this — it surfaces the Godot error directly. The developer must fix the file.

**EC-3: Out-of-range field value.** Clamped silently with a `push_warning`. The game continues with the clamped value. This handles human error in the editor (e.g., accidentally entering `1.5` for a field with max `1.0`).

**EC-4: Missing required field.** If a field marked `Required: Yes` in the range table is absent from the `.tres` file, `GameConfig` logs a hard error and halts. Optional fields use their `Default` value when absent.

**EC-5: System reads config before `LOADED`.** If any system calls `GameConfig.conversion.base_success_chance` before `GameConfig` has completed loading, the call accesses a null domain object and throws a null reference error. This is prevented by Autoload order: `GameConfig` must be first. If the order is wrong, the null dereference provides a clear stack trace.

**EC-6: Duplicate domain files.** The config system references exactly one path per domain (hardcoded in `GameConfig._ready()`). There is no file discovery — no situation where two files compete.

**EC-7: Cross-field inconsistency.** Fields within a domain are validated individually, not relationally. If `traits_per_npc_min > traits_per_npc_max` due to a tuning error, both values pass range validation individually. The NPC Character System is responsible for clamping `min` to `max` when it reads these values. A future enhancement could add cross-field assertions to `GameConfig`, but it is not required for MVP.

**EC-8: Hot-reload failure (editor only).** If a `.tres` file is saved in a temporarily invalid state (mid-edit), the hot-reload validation fails. `GameConfig` logs a warning, discards the reload, and retains the last valid domain state. The `config_reloaded` signal is not emitted for failed reloads.

**EC-9: Cross-field inconsistency in PortraitConfig overlay timings.** Per the EC-7 precedent, PortraitConfig overlay phase timings (`conversion_overlay_surge_ms`, `conversion_overlay_hold_ms`, `conversion_overlay_fade_ms`) are validated individually, not cross-field. If a tuning error ever makes the phases inconsistent, the Portrait & Expression System's F4 formula clamps the total overlay lifetime.

## Dependencies

### Upstream (what this system depends on)

None. Game Config has zero dependencies. It is the foundation layer.

### Downstream (what depends on this system)

**Direct consumers (read config values explicitly):**
- Conversion Logic Engine — `ConversionConfig`
- NPC Character System — `TraitConfig`
- Faith Spread System — `FaithSpreadConfig`
- Rival Faith System — `RivalFaithConfig`
- Multi-path Expansion System — `ProgressionConfig`
- Dialogue & Conversion System — `UITimingConfig`
- Conversion UI — `UITimingConfig`
- Portrait & Expression System — `PortraitConfig`
- HUD & Progress System — `ProgressionConfig`
- Game State Manager — `ProgressionConfig` (win condition thresholds)

**Transitive dependents (depend on a direct consumer):**
- Dialogue & Conversion System (depends on Conversion Logic Engine)
- Portrait & Expression System (depends on NPC Character System)
- Village Map View (depends on NPC Character System)
- Save & Load System (depends on Game State Manager)
- Tutorial & Onboarding (depends on Dialogue & Conversion System)
- Rival Faith System (also depends on Dialogue & Conversion System)
- Audio System (depends on Game State Manager)

## Tuning Knobs

All fields in all seven domains are tuning knobs. Future GDDs should reference this document when listing their tuning knobs — they do not need to re-specify range/default for values that live here.

**High-priority knobs for first playtest:**

| Knob | Domain | Default | Safe Range | Effect |
|---|---|---|---|---|
| `base_success_chance` | ConversionConfig | 0.35 | 0.20–0.55 | Core conversion feel — lower = harder, higher = trivial |
| `approach_cooldown_turns` | ConversionConfig | 3 | 1–7 | Pacing between attempts on the same NPC |
| `village_win_conversion_pct` | ProgressionConfig | 0.75 | 0.60–0.90 | How complete a village must be before moving on |
| `spread_rate_per_tick` | FaithSpreadConfig | 0.05 | 0.01–0.15 | How quickly passive spread fills the map |
| `aggression_interval_turns` | RivalFaithConfig | 6 | 3–12 | How often the rival faith challenges converts |
| `spread_tick_interval_sec` | FaithSpreadConfig | 30.0 | 10.0–60.0 | Real-time pacing of passive faith spread |
| `faith_power_per_conversion` | ProgressionConfig | 10 | 5–20 | Economy rate — how fast expansion paths unlock |
| `dialogue_line_hold_sec` | UITimingConfig | 2.0 | 1.0–3.5 | Pacing feel of the conversation screen |

## Acceptance Criteria

**AC-1: Load on startup**
Given a project with valid `.tres` files for all 7 domains,
When the game launches,
Then `GameConfig` is in `LOADED` state before any other Autoload calls its `_ready()`.

**AC-2: Typed accessor access**
Given `GameConfig` is `LOADED`,
When any system calls `GameConfig.conversion.base_success_chance`,
Then it receives a `float` value within the declared min/max range.

**AC-3: Out-of-range clamping**
Given a `.tres` file with `base_success_chance = 1.5` (above max of 0.95),
When `GameConfig` loads the file,
Then the loaded value is `0.95` and a warning is logged.

**AC-4: Missing required field halts game**
Given a `.tres` file missing a required field (e.g., `base_success_chance` absent from ConversionConfig),
When `GameConfig` loads the file,
Then the game halts with a descriptive error message naming the missing field.

**AC-5: Missing file halts game**
Given a domain `.tres` file does not exist at its expected path,
When `GameConfig._ready()` runs,
Then the game halts with an error message naming the missing file path.

**AC-6: No hardcoded values in gameplay systems**
Given any GDScript file in `src/gameplay/` or `src/core/`,
When the file is reviewed,
Then it contains no numeric literals that correspond to balance values (floats for probabilities, ints for cooldown turns, etc.) — all such values are sourced from `GameConfig`.

**AC-7: Hot-reload updates live values (editor only)**
Given the editor is running and `GameConfig` is `LOADED`,
When a `.tres` file is saved with a changed value,
Then within one frame `GameConfig.[domain].[field]` returns the new value, and `config_reloaded` signal is emitted.

**AC-8: Hot-reload not present in export build**
Given a game exported for iOS or Android,
When the build is inspected,
Then no file-watcher code or `config_reloaded` signal handler is present (stripped by export configuration).

**AC-9: Save/Load round-trip does not re-save config**
Given a saved game file,
When the file is inspected,
Then it contains no config values — only game state (NPC belief states, faith power, etc.).

**AC-10: All 7 domains accessible**
Given `GameConfig` is `LOADED`,
When each domain accessor is called (`GameConfig.conversion`, `GameConfig.traits`, `GameConfig.faith_spread`, `GameConfig.rival_faith`, `GameConfig.progression`, `GameConfig.ui_timing`, `GameConfig.portraits`),
Then each returns a non-null Resource object with all required fields populated.

## Open Questions

- **Difficulty system**: If the game adds difficulty settings post-MVP, should difficulty live as fields within each domain (current approach via `hard_mode_base_modifier`) or as a separate DifficultyConfig domain that multiplies other values? Lean toward fields-within-domain for now to avoid a multiplier layer.
- **Localisation of config values**: UITimingConfig holds display durations. If localisation introduces languages with longer text, some durations may need locale-specific overrides. Defer to Localisation Lead when localisation begins.
- **Config versioning**: If a `.tres` file schema changes between game updates (field added/removed), saved game files are unaffected (they don't store config), but old `.tres` files from the player's prior install could be missing new fields. For mobile, this is handled by shipping the `.tres` files in the build — players always get the new files. No migration system needed.
