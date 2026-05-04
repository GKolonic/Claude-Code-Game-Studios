# Portrait & Expression System

> **Status**: In Design
> **Author**: game-designer + art-director + ux-designer
> **Last Updated**: 2026-04-26
> **Implements Pillar**: Every Soul Has a Story

## Overview

The Portrait & Expression System renders each NPC as a living face rather than a dialogue box. It maps two inputs — NPC belief state and dialogue beat — to a portrait asset and expression state, then drives smooth cross-dissolves between expressions as the conversation unfolds. At the infrastructure level, the system loads archetype-specific portrait textures from `portrait_asset_path` (defined per `NPCArchetypeDefinition`), resolves the current expression key from game state, and manages the transition pipeline on a `TextureRect`-pair cross-dissolve rig. At the player-facing level, it is the primary source of non-verbal emotional signal in the game: a face that shifts from closed resistance to cautious consideration to genuine conviction, cross-dissolving through states in 300–400ms, with a warm-colour overlay surge when a soul finally turns. Two output formats serve two contexts: a full-screen portrait (780×1014px at 2x) occupying 60–65% of screen height during conversation, and a thumbnail (160×160px at 2x) used on the Village Map to show at-a-glance belief state. The system exposes a single `set_expression(expression_key: String)` interface; the Conversion UI drives it from dialogue beat events.

## Player Fantasy

The fantasy is not yours alone — it is mutual. Across every conversation, you are watching a soul, and the portrait makes it impossible to forget that they are also a person being watched. When their expression shifts from `closed_resistant` to `considering_uncertain`, you feel the small moral weight of having reached someone. When you fail and the portrait cools, you feel the small moral weight of having pushed too hard.

This is the system's core purpose: not to animate a face, but to make every approach choice feel like it is being received by a person. Conversion, when it comes, should feel earned — not because the numbers cleared, but because you watched the face across the table slowly open to you. Failure should leave a residue: the withdrawn warmth, the cooled expression, the reminder that you are doing something *to* another person.

Pillar served: **Every Soul Has a Story** — the portrait is the constant reminder that conversion is not a transaction.

## Detailed Design

### Core Rules

**1. Expression key contract.** An expression key is a String that maps to one portrait texture in an NPC's archetype portrait set. The Conversion UI calls `PortraitController.set_expression(expression_key)` — this is the only external write interface. The system loads the texture corresponding to the key, cross-dissolves to it, and holds it until the next `set_expression()` call or the conversation ends.

**2. Portrait asset location.** Textures are loaded from `portrait_asset_path` defined on `NPCArchetypeDefinition`. The path is a directory (`res://assets/portraits/{archetype_id}/`). The system appends `{expression_key}.png` to construct the full path: `{portrait_asset_path}{expression_key}.png`. All textures for an archetype share the same directory. Missing textures log an error and display `closed_resistant` as a fallback.

**3. Cross-dissolve rig.** The full portrait is a `Control` node containing two stacked `TextureRect` children: `_front_rect` (currently visible expression) and `_back_rect` (incoming expression, initially alpha 0). On `set_expression()`, the incoming texture loads into `_back_rect`; a `Tween` animates `_back_rect.modulate.a` 0.0→1.0 and `_front_rect.modulate.a` 1.0→0.0 simultaneously over the dissolve duration. On tween completion, front/back references are swapped and modulate values reset (front = 1.0, back = 0.0). The tween interpolation is `TRANS_LINEAR` except for the conversion expression (Rule 5).

**4. Dissolve interruption.** If `set_expression()` is called while a dissolve is in progress, the current tween is killed immediately. `_back_rect` becomes the new front at its current alpha (not snapped to 1.0), and a new tween begins toward the newly requested expression. Expression changes never queue — the most recent call always wins.

**5. Conversion warm-colour overlay.** When `set_expression("moved_convinced")` is called, a `ColorRect` overlay (`conversion_overlay_color` from `GameConfig.portraits`) animates above the dissolve rig:

| Phase | Timing | Modulate Alpha | Easing |
|---|---|---|---|
| Surge | 150ms | 0.0 → 0.55 | ease-in |
| Hold | 50ms | 0.55 | — |
| Fade | 500ms | 0.55 → 0.0 | ease-out |

The conversion dissolve uses `TRANS_SINE / EASE_IN_OUT` at `GameConfig.portraits.conversion_dissolve_duration_ms` (default 400ms vs. 350ms standard). The overlay fires once per call regardless of previous expression state.

**6. Expression key set — MVP.** Six expression keys are defined. Every archetype portrait set must provide a texture for each:

| Expression Key | Emotional Register | Primary Trigger |
|---|---|---|
| `closed_resistant` | Closed, guarded, unreachable | Belief state: CLOSED, STEADFAST; conversation default at session start |
| `neutral_listening` | Present, non-committed, observing | Conversation baseline; belief state: OPEN |
| `considering_uncertain` | Interior conflict, something landed | Approach delivered — awaiting outcome |
| `open_receptive` | Warmth, openness, being reached | Belief state: WAVERING; SOFTENED/PERSUADED outcome |
| `withdrawn_resistant` | Withdrawal, defence, emotional wall rebuilt | RESISTED or HARDENED outcome |
| `moved_convinced` | Conviction, transformation, arrival | Conversion moment; belief state: CONVERTED |

**7. Thumbnail format.** The thumbnail (160×160px at 2x) is a `TextureRect` owned and managed by the Village Map View — not part of the cross-dissolve rig. It displays a static belief-state expression and does NOT update during active conversations. It updates when `npc_state_changed` fires (Village Map View subscribes directly). Belief-state → thumbnail expression mapping:

| Belief State | Thumbnail Expression Key |
|---|---|
| STEADFAST | `closed_resistant` |
| CLOSED | `closed_resistant` |
| OPEN | `neutral_listening` |
| WAVERING | `open_receptive` |
| CONVERTED | `moved_convinced` |

**8. Texture caching.** Textures are loaded via `ResourceLoader.load()` on first access and cached in a `Dictionary` keyed by `"{archetype_id}/{expression_key}"`. All six expression textures for the current NPC's archetype are pre-loaded in `_ready()` when the `PortraitController` node is instantiated (which occurs when the Conversion UI scene opens). The cache is cleared when `session_complete` fires and the Conversion UI scene is destroyed. Village Map thumbnails cache only the belief-state expression for each NPC, not all six.

**9. No ambient animation.** The portrait is static between expression changes — no idle breathing, no blink cycles, no ambient motion. The cross-dissolve is the only animation the system produces. Stillness between transitions makes each dissolve land.

**10. Ownership model.** `PortraitController` is a scene-level node instantiated by the Conversion UI scene — not an Autoload. One instance exists per active conversation; it is created and destroyed with the conversation scene. The Village Map View manages its own thumbnail `TextureRect` nodes independently. No singleton coordinates all portrait state.

---

### States and Transitions

| State | Description |
|---|---|
| `IDLE` | No conversation active. Full portrait hidden or not instantiated. Village Map thumbnails visible. |
| `SHOWING` | Portrait visible, current expression stable. No tween running. |
| `DISSOLVING` | Cross-dissolve tween in progress between two expressions. |

| Transition | Trigger | Action |
|---|---|---|
| `IDLE → SHOWING` | Conversion UI scene instantiated | Load belief-state expression for the NPC; display without dissolve (instant show). |
| `SHOWING → DISSOLVING` | `set_expression()` called | Load incoming texture into `_back_rect`; start tween. |
| `DISSOLVING → SHOWING` | Tween completes | Swap front/back refs; reset modulate; emit `dissolve_completed`. |
| `DISSOLVING → DISSOLVING` | `set_expression()` called mid-transition | Kill current tween; begin new tween from interrupted modulate state. |
| `SHOWING → IDLE` | `session_complete` fires; Conversion UI scene freed | Hide portrait; clear texture cache. |

Thumbnail transitions are not a state machine — single-frame texture swaps triggered by `npc_state_changed` in Village Map View.

---

### Interactions with Other Systems

| System | Relationship | Interface |
|---|---|---|
| Conversion UI | Upstream — primary driver | Calls `set_expression(expression_key)` based on dialogue beat and outcome. Responsible for expression key selection logic. |
| NPC Character System (NPCRegistry) | Upstream — asset source | Reads `npc.belief_state` on `_ready()` to determine the opening expression. Village Map View (not `PortraitController`) subscribes to `npc_state_changed` for thumbnail updates. |
| NPCArchetypeDefinition | Upstream — asset source | Reads `portrait_asset_path` to locate textures per archetype. |
| GameConfig (`PortraitConfig`) | Upstream — visual config | Reads `dissolve_duration_ms`, `conversion_dissolve_duration_ms`, `conversion_overlay_color`. |
| Village Map View | Downstream — thumbnail consumer | Hosts per-NPC thumbnail `TextureRect` nodes. Subscribes to `npc_state_changed` and updates thumbnail expression key per Rule 7 mapping. |
| Rival Faith System | Indirect | Rival-caused regressions fire `npc_state_changed(npc_id, CONVERTED, WAVERING)` → Village Map View reverts that NPC's thumbnail to `open_receptive`. |

**Cross-system updates required before implementation.**
- `GameConfig` GDD must add a `PortraitConfig` block with fields: `dissolve_duration_ms` (int, default 350), `conversion_dissolve_duration_ms` (int, default 400), `conversion_overlay_color` (Color, default warm amber).
- NPC Trait Database GDD must document `portrait_asset_path` as a required field on `NPCArchetypeDefinition` if not already present.

**Exposed API:**
```gdscript
# PortraitController (scene node — not Autoload)

func set_expression(expression_key: String) -> void
# Load and cross-dissolve to the given expression. Interrupts any in-progress dissolve.

signal dissolve_completed(expression_key: String)
# Emitted when the cross-dissolve tween finishes. Conversion UI may use this
# to synchronise dialogue text reveal or audio timing with the portrait.
```

## Formulas

[To be designed]

## Edge Cases

[To be designed]

## Dependencies

[To be designed]

## Tuning Knobs

[To be designed]

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

[To be designed]

## Open Questions

[To be designed]
