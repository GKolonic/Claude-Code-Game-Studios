# Game Concept: The Faithful

*Created: 2026-04-19*
*Status: Draft*

---

## Elevator Pitch

> It's a narrative strategy game where you play as a prophet spreading a new religion — one conversation at a time — from a single village to a world-shaping faith. You'll win converts through persuasion, political manipulation, and holy war, watching your humble movement grow into an empire of belief.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Narrative Strategy / Empire Builder |
| **Platform** | Mobile (iOS / Android) |
| **Target Audience** | Story-driven strategy fans, ages 20–40 |
| **Player Count** | Single-player |
| **Session Length** | 10–20 minutes (mobile-optimized) |
| **Monetization** | TBD |
| **Estimated Scope** | Small MVP (weeks); Medium V1 (3–6 months); Large Full Vision (1–2 years, solo) |
| **Comparable Titles** | Civilization VI, Crusader Kings II, Reigns |

---

## Core Fantasy

You are a prophet with a message and nothing else. Watch something sacred grow from a single believer to a movement that reshapes the world. The fantasy is the underdog arc — the slow, hard-won expansion of an idea against resistance, cynicism, and rival faiths. No other game puts the player in the role of the religion itself, responsible for every soul won and every schism risked.

---

## Unique Hook

Like Civilization's empire-building arc, AND ALSO every convert is a character with their own beliefs, fears, and reasons to resist — making each conversion a personal story, not a resource transaction.

---

## Two-Scale Game Architecture

The game operates at two interlocking scales. Neither scale exists in isolation — micro decisions have macro consequences, and macro pressure shapes which micro targets matter.

### Micro Scale — The Faithful (NPC Layer)
The player conducts individual conversion conversations with NPCs. Each NPC has traits, a current belief state, and social connections. The conversion approach the player chooses (appeal to grief, ambition, doubt, or fear) determines both whether the NPC converts AND which follower type pool grows:

| NPC Type Converted | Follower Type Added |
|--------------------|---------------------|
| Ordinary congregation member | General Follower (→ generates XP for the Policy Tree) |
| Zealous believer or young idealist | Fanatic (→ deployed on regional missions) |
| Merchant, noble, or community leader | Wealthy Follower (→ generates Gold for church buildings) |

**This is the legacy mechanic**: each NPC conversion is an irreversible decision that compounds upward. Who you win, in what order, determines the shape of your faith.

### Macro Scale — Divine Dominion (Regional Layer)
As NPC conversions accumulate, they aggregate into regional follower economies. The player manages three follower types across regions, deploys Fanatics on missions, spends Gold on buildings (Mission → Chapel → Church → Cathedral), and spends XP on the Policy & Doctrine Tree. Regions are captured when the player's combined follower count exceeds 50% of that region's total religious population.

**Turn-based**: each player action (issue a mission, purchase a policy, construct a building) advances the game state. No real-time timers during active play.

### Win / Lose Conditions

| Condition | Rule |
|-----------|------|
| **Win** | Control 50%+ of all world regions simultaneously |
| **Lose** | All regions fall below 10% conversion — the faith is extinguished |

### Integration Point
The micro and macro layers share state through the NPC Character System and Game State Manager. NPC-level conversion results flow up into the regional Follower Economy. Regional pressure (rival AI advancing in a region, Opposition Score rising) flows down into which NPCs are available and how resistant they are. A region under rival pressure surfaces more hardened NPCs; a region your faith dominates surfaces more open ones.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** (sensory pleasure) | N/A | — |
| **Fantasy** (make-believe, role-playing) | 2 | Player embodies a prophet and growing religious institution |
| **Narrative** (drama, story arc) | 3 | Emergent stories from NPC relationships, rival faiths, political drama |
| **Challenge** (obstacle course, mastery) | 4 | Reading characters correctly, choosing conversion strategy |
| **Fellowship** (social connection) | N/A | Single-player focused |
| **Discovery** (exploration, secrets) | 1 | Emergent stories from systems; surprising NPC reactions; unexpected alliances |
| **Expression** (self-expression, creativity) | 5 | Choose your religion's path — peaceful, political, or militant |
| **Submission** (relaxation, comfort zone) | N/A | — |

### Key Dynamics (Emergent player behaviors)

- Players will learn to read NPC traits before committing to a conversion approach
- Players will seek out politically valuable targets (merchants, nobles) to unlock new paths
- Players will replay scenarios to try different approaches after a failed conversion
- Players will tell stories about their runs: "I converted the king's own advisor against him"

### Core Mechanics (Systems we build)

1. **Character system** — Each NPC has traits (fearful, ambitious, grieving, skeptical), a current belief state, and social connections that influence how they can be reached
2. **Dialogue/conversion system** — Touch-based dialogue choices that appeal to specific traits; success probability shifts based on approach alignment
3. **Faith spread** — Converts create social pressure on their neighbors, opening or closing conversion opportunities
4. **Multi-path expansion** — Missionary (peaceful persuasion), Court (political manipulation), Crusade (militant pressure) as unlockable strategies
5. **Rival faith system** — Opposing beliefs with their own NPCs that actively counter the player's spread

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** (freedom, meaningful choice) | Choose conversion approach, target priority, and expansion path freely | Core |
| **Competence** (mastery, skill growth) | Getting better at reading NPC traits; unlocking more conversion tools | Supporting |
| **Relatedness** (connection, belonging) | Emotional investment in individual NPCs — their stories, resistance, and eventual conversion | Core |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** (goal completion, collection, progression) — How: Region-by-region conversion milestones; faith level unlocks
- [x] **Explorers** (discovery, understanding systems, finding secrets) — How: Uncovering NPC backstories; discovering which approaches work on which character types
- [ ] **Socializers** (relationships, cooperation, community) — How: N/A (single-player)
- [ ] **Killers/Competitors** (domination, PvP, leaderboards) — How: N/A

### Flow State Design

- **Onboarding curve**: First village is a tutorial in disguise — 3–4 NPCs with clearly readable traits, one conversion path available. Player discovers the system by doing.
- **Difficulty scaling**: Later regions introduce NPCs with conflicting traits, rival faith pressure, and political complexity that requires combining multiple approaches.
- **Feedback clarity**: Dialogue choices show trait alignment indicators; conversion success/failure is accompanied by a character moment that explains why.
- **Recovery from failure**: A failed conversion doesn't lock the player out — NPCs cool down and can be re-approached with a different strategy. Failure is a clue.

---

## Core Loop

### Moment-to-Moment (30 seconds)

Read an NPC's visible traits → select a dialogue approach (appeal to their grief, ambition, doubt, or fear) → witness the result: conversion, partial progress, or resistance. Each exchange is a small character story.

### Short-Term (5–15 minutes)

Build a congregation in a single location. Each convert shifts the social fabric — a converted merchant opens trade, a converted soldier offers protection, a converted noble opens political doors. Natural stopping point: a town fully won, fully lost, or at a pivot moment.

### Session-Level (10–20 minutes)

Spread from one village to a region. A rival faith is present. A local ruler is watching. Decide whether to convert the court directly, go around the king through the people, or apply pressure through your growing congregation. Session ends with the faith in a new position — stronger, persecuted, or fragmented.

### Long-Term Progression

Prophet → Local Sect → Regional Faith → Political Force → World Religion. As power grows, so does complexity: schisms, heresies, and rival faiths multiply. New tools unlock (missionaries, holy sites, political agents, crusade banners) that open new strategic options.

### Retention Hooks

- **Curiosity**: What happens if I take the militant path this region? What does this NPC's backstory unlock?
- **Investment**: Converts the player has befriended; a religion shaped by their specific choices
- **Mastery**: Learning which NPC types respond to which approaches; optimizing expansion routes
- **Social**: N/A (single-player; potential for async leaderboards later)

---

## Game Pillars

### Pillar 1: Every Soul Has a Story
NPCs are characters, not resources. Each person has beliefs, fears, and history that make their conversion personal — never mechanical.

*Design test: Between a bulk-convert mechanic and individual NPC dialogue, this pillar chooses dialogue every time.*

### Pillar 2: Many Roads to the Divine
No single strategy dominates. The patient missionary, the scheming courtier, and the holy warrior are all valid expressions of the faith's spread.

*Design test: Between locking a playstyle and allowing free strategy switching, this pillar chooses freedom.*

### Pillar 3: The Arc Must Feel Earned
The journey from obscure prophet to world religion must feel real — slow, organic, full of setbacks. Scale is a reward, not a given.

*Design test: Between fast early-game growth and slow meaningful spread with setbacks, this pillar chooses slow.*

### Pillar 4: History Writes Itself
Drama emerges from systems, not scripts. Schisms, persecutions, and unlikely alliances should surprise even the designer.

*Design test: Between a scripted dramatic event and an emergent system that produces similar drama, this pillar chooses the emergent system.*

### Anti-Pillars (What This Game Is NOT)

- **NOT a military simulation**: Combat is a tool, not the game. Building a full military system would compromise "Every Soul Has a Story."
- **NOT random conversion rolls**: Every conversion outcome must feel explainable and character-driven. Arbitrary RNG undermines player agency.
- **NOT a single optimal religion build**: Multiple valid paths must coexist. A "correct" strategy destroys "Many Roads to the Divine."
- **NOT a scripted story**: Player-authored drama must emerge from systems. Pre-written narrative events undermine "History Writes Itself."

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Civilization VI | Empire-building arc, "one more turn" pull, regional expansion | Religion is the only victory condition; NPCs are characters not units | Validates the core loop pacing and scope feel |
| Crusader Kings II | Character-driven emergent stories, political manipulation through relationships | Mobile-first, focused solely on faith spread, no military sim | Validates the player appetite for character-driven strategy |
| Reigns | Mobile portrait-based decision making, simple binary choices with deep consequences | More dialogue depth, persistent world, empire-building arc | Validates mobile touch-based narrative strategy |

**Non-game inspirations**: The early chapters of any world religion's history — the fragility of a new idea, the charisma required to win the first converts, the moment a movement becomes too large to control.

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 20–40 |
| **Gaming experience** | Mid-core |
| **Time availability** | 10–20 minute sessions on commutes, lunch breaks, evenings |
| **Platform preference** | Mobile-first |
| **Current games they play** | Reigns, Civilization (PC crossover), 80 Days |
| **What they're looking for** | A strategy game with emotional weight — decisions that feel meaningful, not just optimal |
| **What would turn them away** | Pure twitch mechanics, excessive grinding, pay-to-win monetization |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot 4 — free, strong 2D tooling, exports to iOS/Android, good fit for solo developer |
| **Key Technical Challenges** | NPC trait system with enough variation to stay interesting; dialogue system that's expressive without requiring thousands of lines; mobile build pipeline for Godot |
| **Art Style** | 2D illustrated — portrait-based character art for conversations, stylized regional map view |
| **Art Pipeline Complexity** | Medium — custom 2D character portraits + map assets |
| **Audio Needs** | Moderate — ambient music per region, UI feedback sounds, conversion moment audio cues |
| **Networking** | None (single-player; async leaderboards possible later) |
| **Content Volume** | MVP: 1 village, 8–12 NPCs; V1: 3–5 regions, 40–60 NPCs; Full: world map, 200+ NPCs |
| **Procedural Systems** | NPC trait generation (procedural variety within hand-crafted archetypes) |

---

## Risks and Open Questions

### Design Risks
- Core dialogue loop may feel repetitive before enough NPC variety is implemented
- Player motivation after converting a full region — what's the "one more turn" pull between regions?
- Balancing when NPCs feel appropriately resistant vs. arbitrarily unconvertable

### Technical Risks
- Writing enough dialogue variation to avoid repetition without becoming a full writing project
- Godot's mobile export pipeline adds build complexity for a first-time developer
- NPC social graph (who influences whom) may require more complexity than initially estimated

### Market Risks
- Mobile strategy audience skews toward lighter fare — character-driven depth may be a harder sell
- No direct competitor means no proven market, but also no roadmap to learn from

### Scope Risks
- NPC content volume could balloon — each new character type requires dialogue, traits, and art
- "History writes itself" emergent systems are architecturally complex; early shortcuts may require rewrites

### Open Questions
- How many NPC archetypes are needed before the system feels non-repetitive? (Answer via MVP playtesting)
- Does losing a conversion feel educational or frustrating? (Answer via early prototype feedback)
- What is the right session endpoint — a timer, a natural narrative beat, or player-initiated? (Answer via playtesting)

---

## MVP Definition

**Core hypothesis**: Players find the character-driven conversion dialogue engaging and want to keep converting NPCs across a full village.

**Required for MVP**:
1. One village with 8–12 NPCs, each with 2–3 visible traits and a belief state
2. Dialogue/conversion system with 3–4 approach types that align with specific traits
3. A simple rival faith with 1–2 NPC defenders that actively resist conversion
4. Win condition: convert the entire village
5. Basic feedback — character portraits, trait indicators, conversion success/failure moments

**Explicitly NOT in MVP** (defer to later):
- Regional map view and multi-region expansion
- Political/court manipulation system
- Crusade/militant path
- Procedural NPC generation
- Audio beyond placeholder sounds
- Any monetization system

### Scope Tiers

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 1 village, 8–12 NPCs | Conversion dialogue, rival faith, win/lose state | Weeks |
| **Vertical Slice** | 1 full region (3 villages), 30 NPCs | Core loop + faith spread pressure, social connections between NPCs | 2–3 months |
| **Alpha** | 3 regions, 60+ NPCs | All three paths (missionary, court, crusade), schism events | 6 months |
| **Full Vision** | World map, 200+ NPCs | Complete systems, procedural NPC generation, full emergent doctrine | 1–2 years |

---

## Visual Identity Anchor

**Selected Direction**: 2D Illustrated — warm, painterly portraits with a stylized parchment-and-ink map view

**One-line visual rule**: Every screen should feel like a page from an illuminated manuscript — beautiful, deliberate, and weighted with history.

**Supporting visual principles**:
- Character portraits carry the emotional weight — expressions, clothing, and iconography communicate belief and resistance without words
- The map view reads at a glance — faith spread shown as color/texture bleeding across regions, like ink soaking into paper
- UI is minimal and touch-friendly — large tap targets, no clutter, information revealed on demand

**Color philosophy**: Warm golds, deep reds, and aged parchment tones for the player's faith; cooler, more austere palettes for rival faiths. Conversion shifts a location's color temperature visibly.

---

## Next Steps

- [ ] Run `/setup-engine` to configure Godot 4 and populate version-aware reference docs
- [ ] Run `/art-bible` to formalize the visual identity — do this BEFORE writing system GDDs
- [ ] Run `/design-review design/gdd/game-concept.md` to validate concept completeness
- [ ] Run `/map-systems` to decompose the concept into individual systems with dependencies
- [ ] Author per-system GDDs with `/design-system` for each identified system
- [ ] Plan technical architecture with `/create-architecture`
- [ ] Prototype the conversion dialogue system with `/prototype conversion-dialogue`
- [ ] Validate with `/playtest-report` after prototype
- [ ] Plan first sprint with `/sprint-plan new`
