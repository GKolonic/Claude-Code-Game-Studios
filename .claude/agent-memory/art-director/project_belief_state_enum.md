---
name: Belief state enum canonical names
description: The authoritative BeliefState enum values differ from labels used in some briefs — use GDD values in all specs
type: project
---

Canonical BeliefState enum (from `design/gdd/npc-character-system.md`, Rule 2):
- STEADFAST (default — not hostile, simply unbroken)
- OPEN (receptive; first contact registered)
- WAVERING (between worlds; highest drama; highest conversion probability)
- CONVERTED (terminal for player/faith-spread callers)

Progression: STEADFAST → OPEN → WAVERING → CONVERTED (linear, one direction for player)

Some briefs and early design notes use CLOSED instead of STEADFAST. CLOSED is not an enum value. Always use STEADFAST.

ConversionOutcome enum (same GDD, Rule 9 cross-system flag): PERSUADED, SOFTENED, RESISTED, HARDENED. Note: CONVERTED was renamed to PERSUADED to avoid collision with BeliefState.CONVERTED.

**Why:** A brief used CLOSED/WAVERING/OPEN/CONVERTED. Any spec written with CLOSED instead of STEADFAST would create naming inconsistency with the system the Portrait layer directly consumes.

**How to apply:** In all portrait/expression GDD sections and implementation specs, use STEADFAST not CLOSED. Flag any document that uses the old terminology.
