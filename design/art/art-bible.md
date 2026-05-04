# Art Bible: The Faithful

> **Status**: Draft — All 9 sections complete
> **Created**: 2026-04-20
> **Last Updated**: 2026-04-20

---

## 1. Visual Identity Statement

### The One-Line Visual Rule

**Every screen is a page from an illuminated manuscript: composed with intention, weighted with history, and alive with human drama.**

This rule governs every production decision. When a layout feels cluttered, ask whether a manuscript page would carry that much information. When a color choice is uncertain, ask whether it belongs on vellum. When an animation is proposed, ask whether it serves the drama of the moment or merely moves.

---

### Supporting Visual Principles

#### Principle 1: Weight Before Flash

Every visual element must earn its presence through meaning, not spectacle. Ornamentation exists to elevate content — a gilded border draws attention to the sacred, not to itself. Particle effects, transitions, and decorative elements are permitted only when they reinforce the emotional truth of a moment.

**Design test:** When choosing between an animated flourish and a still, composed image, this principle chooses the still image — unless the animation communicates something the still cannot (e.g., a conversion spreading like ink, not a spinning coin congratulating the player).

**Pillar served:** Pillar 3 — The Arc Must Feel Earned. Empty spectacle cheapens the weight of hard-won progress. Every visual beat must feel commensurate with what the player has invested.

---

#### Principle 2: The Portrait Is the Story

Character portraits are the primary narrative surface of this game. A portrait must communicate a character's archetype, emotional state, and cultural context at a glance — before any text is read. Clothing, posture, lighting direction, and iconographic detail do the work that dialogue tags and stat bars do in other games.

**Design test:** When a character's belief state, social class, or emotional response is ambiguous in the portrait alone, the portrait is not finished. A player should be able to read a new NPC's archetype and current emotional stance from their portrait within two seconds, with no supporting text.

**Pillar served:** Pillar 1 — Every Soul Has a Story. The portrait is the player's first and most repeated encounter with each character. If it reads as generic, the NPC reads as a resource. If it reads as a person, the conversion becomes personal.

---

#### Principle 3: Geography Is Theology

The world map is not a logistics screen — it is a theological statement. The visual language of regions communicates the spiritual condition of their inhabitants. Player-faith territory should read as warm, inhabited, and organically grown. Rival territory should read as colder, more geometric, or more austere — not evil, but philosophically different. Unconverted territory reads as grey-beige neutral, neither warm nor cold, waiting.

**Design test:** When designing a map region or its conversion transition, this principle asks: does the visual change communicate a spiritual shift, or merely a territorial one? The color temperature change from unconverted to player-faith must feel like warmth entering the world, not like a flag being planted.

**Pillar served:** Pillar 4 — History Writes Itself. The map is the historical record emerging in real time. The player should be able to read the current spiritual state of the world at a glance, without a stats panel, as if reading a period map that encodes the mapmaker's biases and beliefs.

---

## 2. Mood & Atmosphere

The game passes through distinct emotional registers as the player moves between states. Each register has a precise lighting character, a set of atmospheric adjectives that constrain asset creation, an energy level, and one anchor visual element that carries the mood. Art direction for every new asset must be measured against the register it will appear in.

---

### 2.1 Idle / Village Map View

**Primary emotion target:** Quiet anticipation — the feeling of standing at the edge of a new place, taking its measure before acting.

**Lighting character:** Warm late-afternoon gold. Color temperature approximately 3200K–3800K. Soft, diffused shadows — no hard cast shadows. The light reads as if filtering through parchment or gauze. Low contrast between lit and shadow areas; the world is not threatening.

**Atmospheric adjectives:** Unhurried, sun-warmed, inhabited, slightly worn, hopeful.

**Energy level:** Contemplative. The idle state should never feel urgent. It is the player's moment to read the board, not to react.

**Anchor visual element:** The map's parchment texture. Visible ink-stain geography, hand-lettered region names in a calligraphic style, and the gentle color wash of existing faith spread. The texture carries the mood entirely — if the parchment reads as warm and aged, the state reads correctly even without any animation.

---

### 2.2 Conversation (Mid-Dialogue)

**Primary emotion target:** Intimate tension — two people with different beliefs in close proximity, each trying to understand or persuade the other. Not adversarial, but not comfortable.

**Lighting character:** Close, directional, slightly warmer than ambient. Portrait lighting reads as candlelight or a small hearth — a single warm source from below-right or above-left (consistent per character archetype — see Section 5). The background drops in value and saturation so the portrait is the only lit object. Shadows on faces are deeper here than in the map view, reinforcing the sense of interiority.

**Atmospheric adjectives:** Close, searching, uncertain, consequential, still.

**Energy level:** Tense-contemplative. The player should feel the weight of what they are about to say. UI elements appear without animation; the scene does not rush.

**Anchor visual element:** The portrait itself, with the NPC's eyes. Eyes carry the emotional state — skepticism reads in the angle and focus, grief reads in the dropped gaze, openness reads in the direct address. The eyes are the most labor-intensive element of every portrait for this reason.

---

### 2.3 Conversion Success

**Primary emotion target:** Quiet revelation — not triumphant celebration, but the specific emotion of watching someone understand something for the first time. The conversion moment is sacred, not a score screen.

**Lighting character:** A warmth surge — color temperature increases visibly (approximately 400K–600K warmer than ambient) for the duration of the moment. The portrait gains a subtle warm rim light from above, as if touched by something outside the frame. Returns to normal conversation lighting after 2–3 seconds. This is the one moment where lighting is non-naturalistic; it is justified by the game's spiritual context.

**Atmospheric adjectives:** Still, luminous, earned, fragile, expanding.

**Energy level:** Reverent release. The tension of the conversation breaks, but not into euphoria — into something quieter and more lasting.

**Anchor visual element:** The ink-spread transition on the map. When a conversion registers, a bloom of warm color bleeds outward from the converted NPC's location on the map, moving like ink dropped into water — organic, slightly irregular, unstoppable once begun. This is the game's signature visual moment and must read with craft.

---

### 2.4 Conversion Failure / Resistance

**Primary emotion target:** Sober recognition — not frustration or punishment, but the honest weight of being turned away. The player should feel that the NPC's resistance is real, not arbitrary.

**Lighting character:** A subtle cool shift. Color temperature drops approximately 300K–400K. The portrait's shadow areas deepen slightly. The visual does not become dramatic or alarming — this is not a failure state, it is information.

**Atmospheric adjectives:** Closed, weighted, honest, dignified, patient.

**Energy level:** Grounded. The scene settles rather than spiking. Resistance should never feel like the game punishing the player — it should feel like a door that is not yet open.

**Anchor visual element:** The NPC's posture shift in the portrait — a slight draw-back, a crossed arm, an averted gaze. The emotional truth lives in the body language, not in a red X or a failure flash.

---

### 2.5 Rival Faith Threat

**Primary emotion target:** Wary alertness — the player's faith is not alone in the world. A rival is present, active, and believes in their cause as deeply as the player believes in theirs.

**Lighting character:** Rival-faith regions and characters carry the rival's color temperature (see Section 4 for rival palette). The contrast between the player's warm territories and the rival's cooler zones creates the threat visually — not darkness or corruption, but philosophical cold. Rival NPC portraits use a cooler, more lateral lighting direction than player-faith characters.

**Atmospheric adjectives:** Alert, austere, ideological, lateral, measured.

**Energy level:** Watchful tension. Neither panic nor aggression — the feeling of two competing ideas aware of each other.

**Anchor visual element:** The rival faith's color bleed on the map. Where the player sees warm ink spreading, the rival's territory shows a cooler, more geometric color pattern — as if the rival mapmaker used a different ink entirely. The visual contrast at territorial boundaries communicates the stakes without a UI alert.

---

### 2.6 Menus / Title Screen

**Primary emotion target:** Invitation — the sense of something ancient and important waiting to be opened. The title screen is the cover of the manuscript.

**Lighting character:** Deep, rich, and still. A warm single-source illumination from off-screen — candle or oil lamp. High contrast between the title elements and the background. The overall temperature is warmer than any in-game state, as if the manuscript has just been opened in a dim room.

**Atmospheric adjectives:** Ancient, expectant, ceremonial, composed, weighty.

**Energy level:** Ceremonial stillness. No idle animation loops that distract. Any animation (e.g., a slow candle flicker, a slow ink-fill of the title lettering) is slow, deliberate, and non-looping or very slow-looping.

**Anchor visual element:** The title logotype itself, rendered in the style of an illuminated manuscript initial capital — the first letter of "The Faithful" gilded and decorated, the remaining letters in a period-appropriate hand. This is the game's brand mark and must be designed with the same care as a commissioned manuscript piece.

---

## 3. Shape Language

Shape language is the grammar of visual communication — before color, before detail, before animation, silhouette and geometry carry meaning. This section defines the rules so that every character, environment, and UI element speaks the same visual dialect.

---

### 3.1 Character Silhouette Philosophy

**Mobile-first readability constraint:** Portraits appear at two primary sizes: full-screen (conversation) and small thumbnail (map/congregation list, approximately 80×80px at standard resolution). Every character silhouette must be unambiguous at thumbnail size. This means the silhouette must be legible in black on white, with no reliance on color, texture, or internal detail.

**The rule of one read:** A character's archetype must be communicated by a single dominant shape choice. The head covering, the staff, the collar — one element carries the archetype. All other elements support but do not compete.

**Archetype shape dictionary:**

| Archetype | Dominant Shape Language | Silhouette Anchor |
|-----------|------------------------|-------------------|
| **Believer (early convert)** | Soft rounded forms, humble posture, head slightly inclined | A bowed curve — the shape of someone leaning toward something |
| **Skeptic** | Angular jaw, level gaze, upright posture, arms crossed or closed | A vertical axis with horizontal resistance — stable but closed |
| **Noble / Court figure** | Broad shoulders, elaborate collar or headwear, weight in the upper body | A widened trapezoid — power sitting in the chest and shoulders |
| **Rival faith figure** | Upright, lateral symmetry, formal garment lines — more geometric than organic | A strong vertical with geometric ornament — a different kind of authority |
| **The Prophet (player figure)** | Spare, upright, no crown or crown-equivalent — the authority is interior, not costumed | A clean vertical with one distinguishing mark — staff, specific garment, or visible symbol |

**Distinguishing principle:** The player should never mistake an archetype for another at thumbnail size. Where two archetypes share similar silhouettes (e.g., noble and rival authority figure), distinguish them through the horizontal-vs.-vertical geometry of their ornament: player-faith nobles carry organic, flowing ornament; rival-faith authority carries rectilinear ornament.

---

### 3.2 Environment Geometry

**Architectural philosophy — organic imperfection over geometric precision:** Player-faith villages and regions use architecture derived from hand-built craft — rounded archways, slightly uneven stone courses, buildings that lean into each other as communities do. Straight lines exist, but they are not perfectly straight. Corners are slightly rounded. Rooflines vary.

This communicates the human, accumulated quality of a lived community — the visual opposite of an imperial or formal religion that builds in perfect right angles.

**Rival faith architecture uses the inverse:** More rectilinear, more deliberate, more monumental. Perfect symmetry where the player's faith shows organic asymmetry. This is not "evil architecture" — it is architecture that communicates a different theology (order, law, hierarchy versus community, revelation, personal covenant).

**Map-view geometry:** The regional map reads as a period cartographic document. Geographic forms (mountains, rivers, forests) use the stylized shorthand of medieval cartography — illustrative, not photographic. Mountains are triangular conventions, not realistic peaks. Forests are rows of rounded tree symbols. The intentional stylization keeps the map readable as a single composed image rather than a zoomed-out 3D landscape.

**Scale compression:** On the map, architectural elements (villages, holy sites, strongholds) are rendered slightly larger than true scale — the cartographic convention of importance-scaled iconography. A village icon is large enough to carry a character portrait anchor. A holy site has a distinctive silhouette readable at a glance.

---

### 3.3 UI Shape Grammar

**The illuminated manuscript as UI model — with restraint:** Manuscript borders are the direct reference for UI chrome (panels, frames, dialogue boxes). The approach is restrained manuscript vocabulary: corner flourishes, a thin rule with a small decorative midpoint, interlaced knotwork on major panel edges only.

**Rules for UI geometry:**

- Panel corners use a small organic flourish (leaf or knotwork motif), not a sharp or rounded-rectangle cut. The panel edge is slightly irregular, as if drawn by hand.
- Interior tap targets (buttons, dialogue choices) are clean, large, and touch-safe (minimum 44×44pt). They do not carry heavy ornamentation — the border of the containing panel carries the period decoration; the interactive elements inside are legible and uncluttered.
- Information panels (trait display, belief state, conversion progress) use a lightweight inner border — a single fine rule — without manuscript ornamentation. The decoration is reserved for the frame; the data is clean.
- No drop shadows, gradients as the primary UI fill, or flat-design geometric shapes. UI surfaces use the parchment texture as a base — they are objects in the world, not floating screen elements.

**Hierarchy by weight:** The UI grammar uses weight (line thickness, ornament density) to communicate importance. The dialogue panel, as the most important UI element during conversation, has the heaviest border ornament. Supplementary information (NPC stats, historical log) has progressively lighter borders. The system reads as a manuscript where illuminated capitals draw the eye before regular text.

---

### 3.4 Hero Shapes vs. Supporting Shapes

**Hero shapes are singular and organic.** The player's eye should fall first on character portraits, then on the active region of the map (wherever the player's faith is currently spreading), then on the primary action UI (dialogue choices, conversion button). These elements are the largest, have the highest value contrast against their backgrounds, and use the most refined shape language.

**Supporting shapes are smaller, lower-contrast, and more geometric.** UI chrome, map geography, secondary NPCs in the congregation view, and historical log entries are visually subordinate. They use the same vocabulary but at reduced weight and scale.

**The golden ratio of portrait-to-background:** In conversation view, the portrait occupies the upper 60–65% of the portrait panel, the dialogue text 20–25%, and the choice UI 15–20%. This proportion ensures the character's face is always the dominant element — the eye lands on the person before the words.

---

### 3.5 Rival Faith Geometric Distinction

Rival faith characters and territories must read as geometrically distinct from player-faith elements without reading as evil or corrupt. The distinction is philosophical, not moral.

**Rival characters:** Where player-faith archetypes use organic, slightly asymmetric forms, rival faith characters lean into formal symmetry. Their garments have geometric pattern work (rectilinear grids, repeating angular motifs) rather than organic interlace. Their posture is more formally upright — the silhouette is more precisely balanced on a vertical axis.

**Rival territories on the map:** Player-faith regions develop an organic, irregular border edge (like ink bleeding into paper). Rival faith territories have a harder, more deliberate edge — not a pixel-perfect straight line, but a line drawn with a straightedge rather than a free hand. The internal texture of rival territory is cooler and more patterned; player territory is warmer and more organic.

**The underlying principle:** Two different theologies produce two different visual worlds. The player should be able to tell at a glance where their influence ends and the rival's begins — and understand without words that both are organized, coherent belief systems, not good versus evil.

---

## 4. Color System

Color in The Faithful is not decoration — it is the game's primary information system. The map's faith spread, a character's emotional state, and the threat level of a rival faith are all communicated through color before any text is read. This section defines the full color vocabulary: what every color means, how the palette shifts by game state, and how to ensure critical information survives for colorblind players.

---

### 4.1 Primary Palette

Seven named colors form the complete world palette. Every asset in the game must be constructable from these colors and their tints/shades. No color outside this palette is permitted without explicit art director approval.

| Name | Hex | Role |
|------|-----|------|
| **Vellum** | `#F5E6C8` | The base — the parchment ground of the world. Every UI surface, every map background, every negative space reads against this tone. It is not white; it is aged, warm, and slightly golden. Nothing in the game is pure white. |
| **Scripture Gold** | `#C8922A` | The player's faith color. Faith spread on the map, conversion success moments, the Prophet's identifying accent, positive progress indicators, the title logotype. Gold communicates sacred value and hard-won wealth — it is the color of something that has been believed in long enough to become precious. |
| **Embers Red** | `#8B2C1A` | Urgency and consequence. Active resistance from a powerful NPC, a rival faith's aggressive move, an impending persecution event. Not danger in the abstract — specifically the heat of conflict between two committed beliefs. Used sparingly so it retains its alarm weight. |
| **Iron Ink** | `#2C2418` | Text, line work, portrait shadow regions, map cartographic lines. Not pure black — it has a warm brown undertone that keeps it from reading as digital or cold. All outlines and strokes use this color rather than black. |
| **Pilgrim Blue** | `#3D5A78` | The rival faith's primary identifier. Cool, measured, and authoritative — a blue that reads as sincerely organized, not evil. Used on rival NPC portraits, rival territory on the map, and rival faith UI elements when they appear. |
| **Ash Grey** | `#9E9585` | Unconverted territory and characters with no faith affiliation. Neutral, slightly warm, but clearly desaturated relative to both faith colors. The color of spiritual indeterminacy — not dead, but not yet alive to either faith. |
| **Hearthlight** | `#E8B86D` | Warm ambient glow — the soft secondary light in portrait lighting, the gentle warmth of a converted village at rest, the tint of candle-lit menu screens. A lighter, more diffuse version of Scripture Gold. Where Scripture Gold marks progress and faith, Hearthlight marks warmth, safety, and belonging. |

---

### 4.2 Semantic Color Rules

Color is the player's fastest read. These rules must be followed without exception so that color teaches the player the game's language before they consciously learn it.

| Color | What It Communicates |
|-------|---------------------|
| **Scripture Gold** | Your faith is here. Progress is happening. Something sacred is being made. |
| **Pilgrim Blue** | A competing truth is here. Take note. |
| **Ash Grey** | This is unclaimed — a person or place without spiritual commitment. Potential. |
| **Embers Red** | Conflict is active. A powerful force resists or threatens. Attention required. |
| **Vellum** | Neutral ground — background, history, the world as it was before. |
| **Iron Ink** | Structure, clarity, the written record. What is known. |
| **Hearthlight** | Safety, belonging, a moment of warmth. The feeling after a hard thing succeeds. |

**Combination rules:**
- Scripture Gold and Embers Red together communicate a faith under direct attack — use only for persecution events and crusade-path confrontations.
- Pilgrim Blue and Embers Red together on a rival NPC portrait signals an aggressive rival faction leader, not a neutral rival believer.
- Ash Grey and Hearthlight together signal a conversion-in-progress — a character beginning to warm before the full Gold commitment.

---

### 4.3 Player Faith vs. Rival Faith Color Temperature Contrast

**The ink-soaking spread effect — technical specification:**

The map's faith spread uses a color temperature shift, not just a hue overlay. This is a critical distinction for the effect to read correctly.

- **Unconverted territory:** Rendered in Ash Grey (`#9E9585`) over the Vellum base. The combined read is approximately 5500K — neutral daylight. Neither warm nor cold.
- **Player-faith territory:** A Scripture Gold wash at approximately 30–40% opacity over the Vellum base, combined with a Hearthlight tint in the texture highlights. Combined read approximately 3400K — candlelight warmth.
- **Rival-faith territory:** A Pilgrim Blue wash at approximately 20–30% opacity over the Ash Grey. Combined read approximately 7000K — overcast, cool. Not grey — specifically cooler than neutral.

**The spread transition:** When a conversion registers, the color change moves outward from the convert's map icon as a radial bleed — the Script Gold wash expanding irregularly (driven by a noise function — implementation delegated to technical-artist). The transition duration is 1.5–2 seconds. The edge of the bleed is intentionally soft and irregular, not a clean circle. The effect reads as ink dropped into damp paper: expanding, organic, irreversible-feeling.

**The contested boundary:** Where player territory and rival territory share a border, a narrow transition zone exists — approximately 8–12px at standard map resolution — where the two color temperatures blend. This contested edge is visually distinct from both and communicates the spiritual friction at the border without additional UI elements.

---

### 4.4 UI Palette

The UI palette is derived from the world palette, not separate from it. The game should never feel like a game-UI sitting on top of a world — it should feel like the world and its documentation system are the same object.

| UI Context | Color Application |
|-----------|-------------------|
| **Panel backgrounds** | Vellum base with slight warm variation — no pure white, no flat grey |
| **Panel borders / chrome** | Iron Ink at full opacity for the primary rule; Scripture Gold at 40–60% opacity for decorative flourishes |
| **Primary action buttons** | Scripture Gold fill, Iron Ink text. The most important tap target in any screen. |
| **Secondary / passive buttons** | Vellum fill, Iron Ink border and text. Present but not competing. |
| **Destructive / high-consequence actions** | Embers Red border accent on an otherwise neutral button — not a full red fill. The accent communicates gravity. |
| **Progress indicators (conversion progress)** | Scripture Gold fill on an Ash Grey base track — the gold physically expanding toward completion. |
| **Rival faith UI elements** | Pilgrim Blue accent on Vellum — same vocabulary as player UI, cooler temperature. |
| **Inactive / disabled elements** | Ash Grey at 50% opacity over Vellum |
| **Text — primary (dialogue, labels)** | Iron Ink at 100% opacity |
| **Text — secondary (timestamps, annotations)** | Iron Ink at 60% opacity |
| **Text — faith reference within dialogue** | Scripture Gold for player-faith references; Pilgrim Blue for rival-faith references |

---

### 4.5 Colorblind Safety

The game uses color as a primary information system. Three semantic pairs carry critical gameplay information and must survive protanopia and deuteranopia (red-green, most common) colorblind conditions.

**Critical semantic pairs requiring backup cues:**

| Pair | Risk | Backup Cue |
|------|------|-----------|
| **Scripture Gold vs. Ash Grey** (faith spread progress) | Low — high value contrast. Gold is significantly brighter than grey. | Texture: converted territory has a fine organic texture pattern; unconverted has no texture. Backup: small faith icon watermark in converted regions. |
| **Scripture Gold vs. Pilgrim Blue** (player faith vs. rival faith) | Low — blue-yellow axis preserved in most colorblindness types. | Icon language: player-faith icons use the faith symbol; rival-faith icons use a distinct geometric rival symbol. Color is redundant with icon shape. |
| **Embers Red vs. Scripture Gold** (conflict vs. progress) | **HIGH** — red-green colorblindness collapses warm reds and golds. | Required backups: (1) Embers Red elements use a slow irregular pulse animation (0.5–1Hz) that gold progress elements never use. (2) Conflict icons use angular silhouette; progress icons use rounded fill silhouette. (3) Embers Red elements include a secondary conflict icon (crossed-swords or flame mark). |
| **Pilgrim Blue vs. Ash Grey** (rival faith vs. unconverted) | Medium — may collapse in achromatopsia. | Rival-faith territory carries a repeating geometric pattern in map texture. Unconverted territory has no pattern — flat tone only. |

**Global rule:** No critical information is communicated by color alone. Every semantic color has at least one non-color backup channel (shape, texture, animation, or icon).

**Testing requirement:** All primary game screens must be reviewed through a colorblindness simulator (Godot 4.5+ built-in accessibility color filters) before marking art-complete. Screenshot evidence filed in `production/qa/evidence/`.

---

## 5. Character Design Direction

### 5.1 Visual Archetype Treatments

Each archetype has a fixed visual grammar. These are not just costume descriptions — they are immediate communication systems. Every element earns its place by telling the player something true about the character before a single line of dialogue is read.

---

**The Believer (Early Convert)**

*Clothing style:* Working garments — rough-woven undyed linen or coarse wool, practical and worn. A single piece of iconographic ornament has been added recently and awkwardly: a small token, a wrapped cord at the wrist, something not quite integrated with the rest of the costume. This is the visual grammar of recent change — a person whose outer life has not yet caught up to their inner transformation.

*Color temperature:* Transitional warm. The base palette reads in Ash Grey #9E9585 tones but with a growing warmth in the face and light source. Believers receive a faint upward warmth from below — the candlelight of private devotion, not yet public.

*Lighting direction:* Soft frontal light with a warm secondary source low and to the side. The face is fully legible. There are no deep shadows — these are people with nothing left to hide.

*Posture philosophy:* Leaning forward and slightly open. The shoulders have dropped from a formerly guarded position. Not triumphant — relieved.

*The one defining feature:* The hands. Believers are the only archetype whose hands are prominently visible in portrait — open-palmed, reaching slightly toward the viewer, or folded in new-learned reverence. The gesture is always slightly unpracticed.

---

**The Skeptic**

*Clothing style:* Pragmatic and intentionally unremarkable — a merchant's coat, a craftsman's apron, a scholar's plain robe. Nothing is symbolic. The absence of iconography is itself a statement.

*Color temperature:* Neutral to cool. Desaturated skin tones; light sources that are flat and direct rather than atmospheric.

*Lighting direction:* Even, slightly cool sidelight. The light of a workshop or counting house: functional.

*Posture philosophy:* Arms crossed or hands occupied with something (a ledger, a tool, a cup). The posture communicates the Skeptic was doing something before the Prophet arrived and would prefer to return to it.

*The one defining feature:* The eyebrow. One eyebrow is perpetually and specifically raised — not a sneer, not hostility, but the precise expression of a person waiting for evidence. The brow is the Skeptic's primary expression axis. At high conversion progress, it lowers. At full conversion, both brows relax into the Believer posture.

---

**The Noble / Court Figure**

*Clothing style:* Layered and iconographically dense. Every surface communicates allegiance — to a ruling family, a civic order, a merchant guild. There is deliberate visual weight: heavy fabric, jewelry, insignia. Underneath the layers, something is readable in the face that the costume is trying to suppress.

*Color temperature:* Rich but cooled gold — the gold of secular wealth, not sacred warmth. The palette is in the #C8922A family but desaturated by approximately 30%. The light source is overhead and formal, like a throne room chandelier.

*Lighting direction:* Strong top-down with deep lateral shadows on the face. This is the lighting of power and performance. When conversion nears completion, this shifts subtly toward the warmer, more frontal Believer lighting.

*Posture philosophy:* Composed and still. Movement in expression communicates vulnerability — the posture defaults to stillness and micro-expressions do the work.

*The one defining feature:* The eyes. The Noble portrait is the only archetype where the eyes hold direct, unbroken eye contact with the viewer — the gaze of a person accustomed to being looked at, turned deliberately into a tool. At moments of genuine conversion progress, the gaze breaks briefly before returning.

---

**The Rival Faith Figure**

*Clothing style:* Geometric precision. Where player-faith garments are hand-stitched and organic, rival faith clothing is structured and patterned. Repeating geometric motifs — borders, interlocking shapes, strict symmetry. The iconography is dense but ordered, legible from a distance.

*Color temperature:* Pilgrim Blue #3D5A78 dominant. The skin tones are not cold — these are still human beings — but the surrounding palette creates contrast that makes the face feel isolated within a cool field.

*Lighting direction:* Bright, nearly shadowless overhead light. Cool and even — it reveals rather than warms. There is no mystery in their presentation because they do not believe mystery is a virtue.

*Posture philosophy:* Open and confident but formally upright. Not hostile — the rival faith should never read as a villain. They are a competing truth-claim, not an evil.

*The one defining feature:* The symmetry. Every element of the Rival Faith Figure portrait is deliberately balanced — costume elements mirror left-right, the figure is centered in frame, hair and adornment are formally arranged. This is the most significant visual distinction from player-faith archetypes, who are always rendered with slight asymmetry.

---

**The Prophet (Player Character)**

*Clothing style:* Simple to the point of austerity. A single outer garment, undecorated, in undyed or simply-dyed cloth. No insignia of rank, no adornment, no family markers. The clothing reads as chosen simplicity, not poverty — there is intention in it.

*Color temperature:* Warm but sourceless. Where other characters' warmth comes from a legible light source, the Prophet has a faint internal warmth — a glow from within rather than from without. This is achieved through warm mid-tones in the face and hands even when the ambient light is cool. The effect should be subtle: the viewer may not consciously identify it but should feel the difference.

*Lighting direction:* Unique among the archetypes — the light source on the Prophet is unclear. It is warm, it illuminates evenly, and it does not match the environmental light of the conversation background. This slight visual inconsistency is intentional and must never be "corrected."

*Posture philosophy:* The Prophet is the only archetype whose posture changes based on game stage rather than remaining fixed. Early game: leaning slightly forward, open, earnest. Mid game: upright, quieter. Late game: formally still with weight — the posture of someone who has survived long enough to carry history.

*The one defining feature — the persistent visual signature:* The Prophet always makes direct eye contact with the viewer, but unlike the Noble (whose gaze is assessment), the Prophet's gaze is waiting. The eyes are slightly wider than resting, the brows level — the expression of a person who has said something true and is willing to remain in the silence while it lands. This gaze is the Prophet's persistent visual signature. It is non-negotiable across all art produced for this character.

---

### 5.2 Expression Style Philosophy

Target: **expressive restraint** — emotions are present and readable, but the register is that of a 15th-century painted miniature, not a contemporary animated series. The maximum expression range is approximately 60% of what a contemporary cartoon character would display.

**Five base expression states per NPC archetype** (composited to cover the conversion arc):
1. Closed / resistant (default resting)
2. Considering / uncertain (conversion progress visible)
3. Moved / affected (breakthrough moments)
4. Convinced / open (late-stage conversion)
5. Converted (post-conversion portrait variant)

The Prophet requires an additional state: Witnessing (the expression held while an NPC speaks).

---

### 5.3 Level of Detail Philosophy

**Full-screen portrait (conversation view):** The portrait occupies 60-65% of screen height. At this size, fully rendered and narratively load-bearing: facial expression, eyes, hands when visible, the archetype's defining feature, primary costume layers, and iconographic ornament.

**Thumbnail / map-view portrait (80×80px):** Only four elements remain readable and must be preserved: silhouette shape, primary color temperature, the archetype's defining feature (simplified), and the facial expression quadrant. All other detail collapses gracefully.

**Thumbnail legibility is a blocking production criterion.** Every portrait must be reviewed at 80×80px during production. If the archetype is not immediately identifiable at that size by silhouette and color temperature alone, the full-size design must be revised.

---

### 5.4 Prophet Visual Identity Across Regions

The Prophet visits multiple cultural regions. The persistent visual signature is the gaze (defined in 5.1) plus one always-present costume element: **a single cord, wrapped three times around the wrist, in undyed natural fiber.** This cord is present in every Prophet portrait regardless of regional costume variation.

**Regional costume adaptation rule:** Outer garments adapt to the regional visual vocabulary, but the austerity principle is maintained. The cord remains. The gaze remains. The internally-sourced warmth remains.

---

### 5.5 Cultural Visual Vocabulary

All cultures are expressed through the illuminated manuscript visual system. The question is not "what does this culture look like" but "how would a scribe from this culture have illustrated their own world?"

**Three axes of differentiation — varying by region without breaking the system:**
1. *Textile pattern language:* Each culture has a distinct pattern vocabulary (geometric, organic vine, calligraphic, etc.), applied as a "regional layer" over base character templates.
2. *Natural material palette:* Secondary accent colors shift by region within a defined range — coastal sea-green, northern birch-grey, desert terracotta. All extend rather than replace the primary palette.
3. *Architectural proportion:* Building shapes differ by region but all use the same hand-drawn parchment illustration style.

**What does not vary:** Vellum base, Iron Ink outline weight, warm-source lighting convention, illuminated manuscript technique, the organic/geometric distinction between player-faith and rival-faith designs.

---

## 6. Environment Design Language

### 6.1 The Two Primary Environment Contexts

Two distinct visual environments: the **village map view** and the **conversation background**. They serve different functions and require different levels of detail — but must read as pages from the same book.

---

### 6.2 The Village Map View

**What it is:** A top-down or near-isometric view of a village and surroundings, rendered as a period cartographic illustration on parchment. The player reads NPC positions, faith spread, and social opportunity from this view.

**The visual register:** A medieval mapmaker's rendering — the kind of map drawn by someone who had been there but was primarily interested in communicating meaning, not accurate spatial data. Proportions are adjusted for readability. Important buildings are larger. The illustrative priority is "what does the viewer need to understand?" not "what is the precise spatial relationship?"

**Faith spread visual language:** As player faith spreads, warm Hearthlight and Scripture Gold tones bleed and soak into the vellum base around converted NPC positions, as though warm-toned ink has been applied to damp paper. Rival faith presence is expressed as cooler Pilgrim Blue bleeding from contested edges. Unconverted areas remain in raw Vellum. This is the game's primary data visualization and must be immediately readable without a legend.

**NPC position markers:** NPCs are represented as small portrait thumbnails (80×80px). Their faith state is reinforced by a small warm or cool halo — not text, not a percentage bar. Color temperature communicates faith status at a glance.

**Camera and orientation:** Portrait-oriented to match the device. Village occupies the upper 60-70%; information UI occupies the lower 30-40%. The map should feel like something being held and read, not something viewed from altitude.

---

### 6.3 Architectural Style: Player Faith Villages

**Historical reference points:** The architecture of early Christian communities in the Levant and North Africa — specifically the domestic and semi-public spaces of common people: courtyard houses, simple meeting rooms, structures that carry their function in their proportions rather than their ornament. The selection is thematic: faith that lives in borrowed rooms, converted homes, and modest gathering spaces, not in purpose-built monuments.

**Level of ruin and completion:** Complete but worn — inhabited, used, slightly shabby. Rooflines sag fractionally. Plaster has been repaired in visible patches. As faith spreads, architectural health improves — new plaster, repaired thresholds, small additions. Prosperity becomes architecturally legible.

**Era feel:** Deliberately non-specific. The architecture should read as ancient to a modern player but should not be dateable. Mixed architectural references coexist without anachronism anxiety — this is a myth-time world.

**Organic imperfection:** Buildings are never perfectly symmetrical on the map. Walls are slightly irregular. Rooflines have character. The illustration style allows the hand of the mapmaker to be felt.

---

### 6.4 Rival Faith Architecture

More established and institutionally confident. Repeated motifs in friezes, patterned tile visible at map scale, formal symmetry in facades. Geometric visual principle applies architecturally: repeated arches at consistent intervals, towers with deliberate proportional relationships, gateways that are clearly gateways.

**The theological communication:** The visual distinction communicates that the rival faith has had time to develop aesthetic doctrine, not that it is evil. Rival faith architecture must never look decayed, oppressive, or threatening. It should look mature, coherent, and aesthetically serious — a genuine visual alternative.

At map scale, rival faith structures are rendered with Pilgrim Blue accents in their illustration — not because they are made of blue stone, but because the period mapmaker has used a cooler ink to distinguish them. This is a map convention, not a physical reality.

---

### 6.5 Natural Environment — Cartographic Conventions

All natural environment elements use period cartographic illustration conventions. The guiding question for each element: "how did mapmakers from roughly the 12th to 17th century conventionally represent this?"

- **Mountains:** Repeating series of small perspective humps — the classic "molehill" cartographic convention. Each hump is slightly different, drawn with a single confident line and minimal shading.
- **Forests:** Groups of small rounded tree symbols — each a circle of foliage atop a short trunk. Density of symbols communicates forest density.
- **Rivers:** A single fluid line that widens toward the sea, drawn with variable ink weight. A shallow Pilgrim Blue wash at ~30% opacity fills the river form.
- **Coastlines and open water:** Slightly irregular coastline. Open water indicated with parallel horizontal hatching lines — the classic period convention — at low opacity.
- **Other terrain:** Any new element (marshes, cultivated fields) receives a conventional symbol derived from period cartography, added to the project's symbol library at that time.

---

### 6.6 Conversation Background Design Philosophy

**What is visible:** The conversation screen places the NPC portrait (60-65% of screen height) in front of a visible background that communicates where this conversation is taking place — without competing with the portrait.

**The focus relationship:** The background is rendered at approximately 50-60% of the portrait's detail level — looser linework, less internal detail, slightly reduced contrast. The portrait must always feel like the primary object. The background is a setting that has been appropriately stepped back.

**Background-to-portrait lighting coherence:** The background light source matches the portrait's ambient lighting convention. The exception is the Prophet's portrait, which has its own internally-sourced lighting that creates a slight inconsistency — retained intentionally.

**Background depth and layering:** Two layers: far background (architecture, sky, large elements) and near-background/foreground edge (a doorframe, window sill, market stall edge, foliage, architectural column). This creates depth without complex perspective.

**Background variety vs. production efficiency:** Each major conversation location type requires one background template (village exterior, domestic interior, noble interior, sacred space, open road, rival territory). NPCs in the same location type share the template. Approximately 6-8 base templates cover the full game.

---

### 6.7 Environmental Storytelling Guidelines

**Village health:**
- Roof condition: intact vs. sagging reads immediately at map scale
- Wall plaster: clean vs. repaired in multiple patches
- Threshold condition: fresh-worn paths indicate use; overgrown indicates isolation
- Market/gathering space: populated common area communicates social health

**Faith presence:**
- The ink-bleed faith spread mechanic handles primary faith-presence communication
- Small iconographic symbols associated with the player faith appear on buildings as conversion spreads — not announced or labeled, visible on close inspection, growing from small threshold markings to public gathering symbols

**Social status:**
- Building scale relative to neighbors is the primary status indicator at map scale
- Number of visible layers in a building's illustration (one story vs. upper story vs. tower) communicates wealth

**The rule for all environmental storytelling:** Every status indicator must have a visual form that reads without explanation to a player who has never seen it before. If a new player cannot infer the general meaning from context and comparison, that element is not communicating — it is just decoration.

---

## 7. UI/HUD Visual Direction

### 7.1 Screen Inventory

| Screen | Manuscript Analog | Visual Treatment |
|--------|-------------------|-----------------|
| Title Screen | Manuscript Cover | Illuminated initial capital, logotype in calligraphic hand, single CTA button. Deep Iron Ink background, Hearthlight warming at edges. Single very slow candle-light flicker (8–12s cycle). No idle animation loops. |
| Village Map View | Cartographic Page | Full parchment texture. Period cartographic illustration. NPC markers, faith-spread color, and nav overlays as manuscript annotations. No persistent HUD bar. Faith state legible from map color alone. |
| Conversation Screen | Portrait Folio | NPC portrait upper 60-65%, dialogue 20-25%, choices 15-20%. Heaviest manuscript border ornament in game. Background: receding atmospheric treatment, low saturation, low contrast. |
| Congregation Overview | Parish Register | Scrollable ledger-style list. Small circular portrait thumbnails, name, trait summary, faith-state glyph. Ruled-line vellum texture. Light border treatment — working document, not illuminated page. 6-7 entries visible before scrolling. |
| Settings Screen | Colophon | Utilitarian. Parchment texture present, manuscript ornamentation minimal. Clean toggles/sliders in the Vellum/Iron Ink/Gold vocabulary. |
| Conversion Success/Failure | Marginalia Illumination | Full-panel state change within conversation screen. Success: portrait lighting surges warm, Scripture Gold ink-bleed radiates from heart position, one-line poetic caption in calligraphic hand. Failure: portrait cools, NPC posture shifts, one-line response in Iron Ink. Holds 2–3 seconds. |

---

### 7.2 Typography System

**Two typefaces working in concert:**

- **Display face** (headings, NPC names, dialogue speaker labels, title logotype): An uncial or semi-uncial inspired face — the visual lineage of insular manuscript hands — with enough regularization to remain readable at medium size on mobile. Must not parody period lettering; must feel like a serious typographic interpretation. Recommended direction: IM Fell English, or equivalent openly-licensed face.

- **Body face** (dialogue text, register entries, choice options, captions): A humanist serif or legible slab with warm personality. Must survive 16px on high-DPI mobile without hinting failures. Recommended: Gentium or EB Garamond (both openly licensed with proven mobile legibility).

**Size and weight hierarchy:**

| Level | Use | Minimum Size | Weight | Face |
|-------|-----|-------------|--------|------|
| Display / Hero | Title logotype, major headers | 36pt | Heavy/Bold | Display |
| H1 | NPC name in conversation | 22–24pt | Bold | Display |
| H2 | Screen title, location name | 18–20pt | Regular | Display |
| Body | Dialogue text, register entries | 16–17pt | Regular | Body |
| Caption | Trait labels, annotations | 13–14pt | Regular/Light | Body |
| Micro | Icon labels, colorblind backup text | 11–12pt | Regular | Body |

**Hard minimum:** Nothing critical to gameplay below 13pt. Nothing at all below 11pt. Test on a physical 4.7-inch phone, not a simulator.

**Line length:** No more than 30–35 characters per line on the narrowest phone target. Wrap aggressively; never compress font size to fit longer lines.

**Tracking/leading:** Display face: +20 to +40 tracking units. Body: default tracking, 1.4–1.5x line height.

---

### 7.3 Iconography Style

Icons in this game are manuscript marginalia — small, hand-drawn figures that annotate without competing.

**Stroke weight:** 2pt at 1x (4pt at 2x export). Same weight as manuscript border fine rules.

**Fill style:** Partially filled — a mid-value fill (~40-60% value, in the relevant semantic color) with an Iron Ink outline at full opacity. Mirrors the manuscript convention of color washes beneath ink line work. No pure flat-color fills and no pure outline-only icons.

**Detail levels by size:**
- 44pt+: 3–4 internal detail lines maximum
- 24–43pt: 1–2 internal detail lines, or none
- 16–23pt: Silhouette only. No internal lines. These sizes used only for non-critical secondary information.

No gradients, bevel effects, or drop shadows on any icon.

**Subject matter:** Icons reference the game's period vocabulary without being archaeological. A sword uses a hand-and-a-half silhouette; a crown is a simple open three-point form. Faith icons use abstracted geometry invented for the game's world — not borrowed from real-world religious traditions.

**Grid:** All icons drawn on a 24×24pt grid at 1x (2pt padding each side, 20×20pt active area). Exported at 2x as 48×48pt physical pixels.

---

### 7.4 Animation Philosophy

**The manuscript does not move — it breathes.** This is the governing principle of all UI animation.

**What animates:** State transitions (screen enters/exits, conversion moments, map faith spread), touch feedback responses, ambient atmospheric elements (title screen candle flicker, conversation screen edge lighting). These animations communicate meaning.

**What does not animate:** UI chrome (borders, panels, decorative flourishes), static information displays, the map geography base layer. These are the manuscript page itself — composed, not performed.

**Duration and easing by animation type:**

| Type | Duration | Easing |
|------|----------|--------|
| Screen enter | 250–350ms | Ease-out cubic |
| Screen exit | 200–280ms | Ease-in cubic |
| Touch tap confirmation | 80–120ms | Ease-out quad |
| Dialogue choice appear | 180–220ms, staggered 60ms per choice | Ease-out cubic |
| Conversion success lighting surge | 400–600ms surge, 1500–2000ms hold, 800ms fade | Ease-out surge / ease-in fade |
| Faith spread ink bleed | 1500–2000ms total | Custom noise-driven (see Section 4.3) |
| Portrait expression cross-dissolve | 300–400ms | Linear |
| Candle flicker (ambient) | 4000–6000ms per cycle | Ease-in-out sine |

**The "no bounce" rule:** No bounce easing, spring physics, or overshoot easing anywhere in the game. A manuscript page does not spring. Bounce easing is incompatible with the game's tonal register.

**Performance constraint:** All UI animations must complete within the 60fps budget. No physics-driven animation; all animations use Godot's `Tween` class. If a device cannot maintain 60fps during a transition, the transition is too complex and must be simplified — not sped up.

---

### 7.5 Diegetic vs. Screen-Space UI

**Decision: Hybrid diegetic — the UI is the document that contains the world.**

The village map IS the document; the characters exist within it. The conversation screen is a folio page — portrait, dialogue panel, and choices are parts of the same composed surface, not separate layers. System-level UI (settings, congregation register) is the back matter of the manuscript.

A traditional HUD (semi-transparent bars, floating labels, minimap overlay) would place a game-UI layer between the player and the manuscript. The manuscript metaphor requires that the player IS reading the manuscript. Every piece of information must feel like it was placed on the page by a scribe's hand.

**Implementation implication:** There is no single always-visible HUD node in the scene hierarchy. Each screen composes its own information layout as a complete document page. Treat each screen as a self-contained layout, not a persistent layer system.

---

### 7.6 Conversation Screen Layout — Extended Rules

**Portrait zone (upper 60–65%):**
- Face eye level at approximately 40% down from the top of the portrait zone — the compositional golden zone
- Portrait width fills zone to 90% of screen width (5% margin each side)
- NPC name and archetype label at the bottom edge of the portrait zone, overlapping the top of the dialogue panel by 8–10pt
- Lighting shift indicator for emotional state operates within this zone only

**Dialogue zone (next 20–25%):**
- One beat per panel, advancing on tap — not a scroll transcript. This is the rhythm of the manuscript.
- Body face at 16–17pt, centered horizontally, left-aligned within a 30–35 character column
- Subtle parchment ruled-line texture visible in zone background

**Choice zone (lower 15–20%):**
- 2–4 choices maximum per beat
- Each choice is full-width, minimum 44pt tall, Iron Ink text on Vellum base
- Active choice highlights with light Scripture Gold background tint
- Trait-alignment indicators appear as small manuscript glyphs at left edge of each choice row — glyphs only, no text labels
- Choice zone is a list within the same text area as the dialogue zone, not a separate panel

**Information explicitly absent from conversation view:**
- No persistent faith level or resource counter during conversation
- No probability display ("60% success chance") — trait glyphs imply alignment; explicit odds undermine Pillar 4
- No skip button for atmospheric animations (accessibility exception: if player has enabled reduced-motion in system settings, Godot 4.5+ AccessKit integration should respect this — implement as a project-level accessibility flag)

---

### 7.7 Village Map UI Overlay

Map annotations must look as if a scribe or cartographer placed them there — not a UI designer.

**NPC selection indicators:** A fine-ink circle (hand-drawn style — slightly irregular) around the marker on tap. A small annotation tag (rectangular, manuscript style, NPC name and faith glyph) rises from the marker's top edge. Body face at 13pt. Persists until player taps elsewhere.

**Faith-spread labels:** Hand-lettered region names embedded in the map at design time, not floating UI text. These labels shift color temperature with the region's faith state as part of the map's color wash shader. Implementation: region names must be baked into the map atlas; dynamic region naming requires a separate approach — surface this tradeoff to technical-artist.

**Navigation:** Tap-to-select primary navigation. No floating nav arrows, minimap, or zoom chrome. Zoom via pinch gesture only. A single compass rose in the lower-right — manuscript cartographic style — doubles as "return to full map" button.

**Scene transition:** Map-to-conversation is a page-turn dissolve (not a slide or zoom) — the map fades to Vellum background and the conversation folio appears over it.

---

## 8. Asset Standards

### 8.1 File Format Standards

| Asset Category | Format | Justification |
|---------------|--------|---------------|
| Character portraits (full conversation) | PNG, RGBA | Lossless — portrait detail and hand-painted texture must not degrade. Alpha needed for non-rectangular portrait edges. |
| Character portraits (thumbnail/map) | PNG, RGBA | Same reasoning at smaller size. No JPEG at any portrait size. |
| Map background (cartographic layer) | PNG, RGB | Lossless for primary map texture. No alpha needed at the base layer. |
| Map region overlays (faith-spread masks) | PNG, single-channel (grayscale) | Faith spread is applied by shader at runtime; mask defines spread area only. Grayscale halves channel data. |
| UI panels and chrome | PNG, RGBA | Alpha required for organic-edge decorative flourish shapes. |
| UI icons | PNG, RGBA | 24×24pt grid at 1x, exported at 2x. Lossless mandatory. |
| VFX sprite sheets | PNG, RGBA | Sequential frame sheets. Alpha required for organic edge effects. |
| Audio (music) | OGG Vorbis | Godot 4's native streaming format. 192kbps for ambient music. |
| Audio (SFX) | WAV (16-bit, 44.1kHz) | Short clips benefit from uncompressed format for precise timing. |
| Fonts | .ttf or .otf | Import into Godot 4's DynamicFont system. Subset to Latin + period punctuation. |

**No JPEG anywhere.** JPEG compression artifacts are incompatible with the manuscript aesthetic — they read as digital compression, not painterly texture.

---

### 8.2 Naming Convention

Master convention: `[category]_[name]_[variant]_[size].[ext]`

**Character Portraits:**
```
portrait_[npc-id]_[expression]_[size].png
```
- `npc-id`: lowercase hyphenated (`elder-thomas`, `merchant-miriam`, `rival-bishop`)
- `expression`: emotionally named — `neutral`, `open`, `resistant`, `grieving`, `suspicious`, `joyful`, `converted`
- `size`: `full` (conversation) or `thumb` (map/register)
- Example: `portrait_elder-thomas_converted_full.png`

*Note: Do not use generic `idle`. Every expression must be emotionally named — the difference between `neutral` and `open` is narratively meaningful.*

**Map Assets:**
```
map_[type]_[descriptor]_[variant].png
```
- Examples: `map_bg_base.png`, `map_region-mask_north_neutral.png`, `map_icon_village_large.png`, `map_icon_holysite_player.png`

**UI Elements:**
```
ui_[component]_[name]_[state].png
```
- `component`: `btn`, `panel`, `icon`, `border`, `frame`
- `state`: `default`, `hover`, `pressed`, `disabled`
- Examples: `ui_btn_primary_default.png`, `ui_panel_dialogue_default.png`, `ui_icon_faith-glyph_default.png`

**VFX Sprite Sheets:**
```
vfx_[effect]_[loop-type]_[size].png
```
- Examples: `vfx_ink-bleed_oneshot_large.png`, `vfx_candle-flicker_loop_small.png`

**Audio:**
```
[category]_[name]_[variant].[ext]
```
- Examples: `music_map-idle_village.ogg`, `sfx_conversion-success_01.wav`

---

### 8.3 Texture Resolution Tiers

**Core rule: Design and paint at 1x logical resolution. Export all raster assets at 2x physical pixels.** Godot 4's CanvasItem scaling handles the mapping for retina/high-DPI displays.

| Asset Category | 1x Design Size | 2x Export Size | Notes |
|---------------|---------------|----------------|-------|
| Portrait — full conversation | 390×507pt | 780×1014px | Portrait zone at 60-65% of a 390×844pt canvas (iPhone 14 logical) |
| Portrait — thumbnail / map marker | 80×80pt | 160×160px | Circular crop applied at runtime via shader or CanvasItem masking |
| Map background (full cartographic layer) | 390×844pt | 780×1688px | Full portrait canvas. Largest single texture — verify fits within 512MB ceiling. |
| Map region overlay masks | Per-region bounding box, min 128×128pt | 256×256px minimum | Grayscale single-channel. Tile where region shapes permit. |
| UI panels and chrome | Variable; min 44×44pt | Min 88×88px | Use 9-slice scaling for resizable panels. |
| UI icons | 24×24pt | 48×48px | Packed into icon atlas (see 8.4) |
| VFX sprite sheets | 128×128pt to 256×256pt per frame | 256×256px to 512×512px per frame | Full sheet size governed by atlas limit |

---

### 8.4 Atlas / Sprite Sheet Policy

**Pack into atlases (reduces draw calls toward the ≤100 budget):**
- All UI icons → `atlas_ui-icons.png`, max 1024×1024px at 2x
- All UI chrome (panels, borders, buttons) → `atlas_ui-chrome.png`, max 2048×2048px at 2x. Use 9-slice on resizable elements.
- All VFX sprite sheet frames (one atlas per effect)
- Portrait thumbnails → `atlas_portraits-thumb.png`, max 2048×2048px at 2x (holds 165 thumbnails at 160×160px — sufficient for Full Vision NPC count)

**Do not pack into atlases:**
- Full conversation portraits (780×1014px each; loaded one at a time)
- Map background (unique, full-screen, single texture)

**Atlas size limit:** 2048×2048px at 2x for all atlases.

**Godot import settings:** Set all atlas textures to `Compress: VRAM Compressed`. Enable `Mipmaps: Off` for all UI and 2D assets — mipmaps are for 3D textures and waste memory in 2D.

---

### 8.5 Compression Standards

| Platform | Format | Godot Import Setting |
|----------|--------|---------------------|
| iOS (Metal) | ASTC 4×4 | `compress/mode = 2` (VRAM Compressed) — Godot auto-selects ASTC on iOS |
| Android | ETC2 | `compress/mode = 2` — Godot auto-selects ETC2 on Android |

**Practical rule:** Set all assets to `VRAM Compressed` in the Godot importer. Do not manually set ASTC or ETC2 — let Godot's export pipeline handle format selection per platform.

**Exception — full conversation portraits:** Verify that ASTC 4×4 quality is acceptable for portrait skin tones and hand-painted texture. If ASTC introduces visible banding on portrait gradients, escalate to technical-artist.

**Source files:** Maintain full-resolution uncompressed PNG source files in `assets/art/source/`. These are not committed to the game build but must be version-controlled for iteration.

---

### 8.6 Polygon Budget — 2D Mesh and Skeletal Elements

This game is 2D only. Polygon budgets apply only to 2D mesh assets and skeletal portrait rigs if adopted.

**Portrait rigs (if adopted):** Current specification uses still portrait images with discrete expression variants. If skeletal 2D rigs are adopted in future (Godot's Skeleton2D or Spine via GDExtension):
- Maximum 80 bones per portrait rig
- Maximum 4 mesh regions per portrait (head/face, torso, left arm, right arm/hand)
- Requires producer sign-off before implementation

**Map overlays:** Faith spread region overlays rendered as textured `Polygon2D` meshes. Maximum 32 vertices per region polygon. Complex boundaries must be simplified.

**General rule:** No decorative UI element implemented as a procedural polygon mesh. All UI chrome uses sprites or nine-patch rects.

---

### 8.7 Layer / Z-Order Convention

**Village Map View — layer stack:**

| Z-Index | Layer Name | Contents |
|---------|-----------|---------|
| 0 | `map_base` | Full cartographic background texture |
| 10 | `map_region_overlays` | Faith-spread color wash masks |
| 20 | `map_geography_detail` | Mountains, forests, rivers — rendered above faith wash so geography reads through color change |
| 30 | `map_icons` | Settlement, holy site, stronghold markers |
| 40 | `map_npc_markers` | Per-NPC portrait thumbnails and faith glyphs |
| 50 | `map_annotations` | Selection indicator rings, annotation tags |
| 60 | `map_ui_chrome` | Compass rose, persistent screen-edge UI |
| 70 | `map_transition_overlay` | Page-turn dissolve effect (active only during transitions) |

**Conversation View — layer stack:**

| Z-Index | Layer Name | Contents |
|---------|-----------|---------|
| 0 | `conv_background` | Atmospheric background |
| 10 | `conv_portrait` | NPC portrait sprite |
| 20 | `conv_lighting_fx` | Lighting surge VFX, rim light overlay |
| 30 | `conv_frame` | Manuscript border frame and corner flourishes |
| 40 | `conv_dialogue_panel` | Dialogue text area with ruled parchment texture |
| 50 | `conv_npc_label` | NPC name/archetype label (overlapping portrait/dialogue boundary) |
| 60 | `conv_choices` | Choice cell list |
| 70 | `conv_trait_glyphs` | Trait alignment icons on choice rows |
| 80 | `conv_transition_overlay` | Page-turn dissolve effect |

**Rule:** No element from the map layer stack appears in the conversation layer stack and vice versa. These are separate scene compositions, not a single scene with toggled visibility.

---

## 9. Reference Direction

### Reference 1: Civilization VI — Leader Portrait Composition

**Specific visual element to draw from:** The way lead portrait artists use a tightly compressed, warm-vignette-lit face against a culturally specific background that falls into soft focus. The face is always the highest-contrast element. The background carries cultural iconography (architecture, costume detail, environmental suggestion) at roughly 30–40% of the portrait's value contrast — context without competition. The illuminated framing around each leader portrait — decorative borders using motifs specific to that civilization's art tradition — is the direct model for The Faithful's conversation screen frame design.

**What to explicitly avoid:** Civilization VI's portraits are heroic and idealized — lit like Roman busts, with dramatic three-quarter lighting that flatters and monumentalizes. The Faithful's NPCs must not be idealized. Ordinary believers, skeptics, and grieving converts must read as human and lived-in. Avoid the Civ VI tendency to make every character look powerful.

**Pillar and section served:** Section 7.5 (portrait zone proportions) and Section 3 (shape language — face as dominant compositional element). Serves Pillar 1: Every Soul Has a Story.

---

### Reference 2: Crusader Kings II — Event Illustration Style

**Specific visual element to draw from:** The painted rectangular vignettes accompanying major events. These are still, painterly, and compositionally deliberate. The technique of placing two figures in close physical proximity within a small frame to communicate tension or intimacy — a confessor leaning toward a dying noble, a suspicious courtier watching from a doorway — is directly applicable to The Faithful's conversation screen. The visual language communicates relationship and power dynamic through body positioning and framing alone, before any text is read.

**What to explicitly avoid:** CK2's illustrations are often dark — deep shadow areas, murky backgrounds, figures emerging from near-blackness. The Faithful is warmer and more intimate. Do not adopt CK2's shadow depth or its tendency toward cool, slightly greenish shadow tones. The Faithful's shadow areas stay warm (Iron Ink with its brown undertone, not blue-black or green-black).

**Pillar and section served:** Section 7.6 (conversation screen layout — body language and proximity communication) and Section 2.2 (conversation mood — intimate tension). Serves Pillar 1.

---

### Reference 3: Reigns — Information Hierarchy Discipline

**Specific visual element to draw from:** The deliberate restriction of the choice interface to a small number of short, clear options. The visual restraint — a single face, a single request, few choices — is the model for The Faithful's information hierarchy discipline. The choice zone must never grow complex enough that the player's eye is divided between reading choices and reading the NPC. Also draw from Reigns' card-back texture treatment: a plain, slightly aged surface that makes the face feel like it is emerging from an object, not floating in a void.

**What to explicitly avoid:** Reigns achieves its minimalism by reducing character portraiture to near-abstraction — stylized, low-detail faces that read more as icons than portraits. The Faithful requires the opposite: high-detail, emotionally specific faces. Reigns' lesson is about information hierarchy and layout restraint, not about portrait simplification.

**Pillar and section served:** Section 7.6 (choice zone design). Serves Pillar 2: Many Roads to the Divine — the demonstration that meaningful choice does not require many options.

---

### Reference 4: The Hours of Jeanne d'Evreux (Jean Pucelle, c. 1324–1328)

**Specific visual element to draw from:** The grisaille marginalia technique — secondary figures and decorative border elements rendered in grey monochrome ink wash while primary devotional images received full color illumination. This is the direct model for The Faithful's secondary information display: congregation register entries, map annotation tags, and trait glyph icons should have the visual weight of grisaille marginalia — present, detailed, craftsmanlike, but grey-toned against the vellum. Full color — Scripture Gold, Embers Red, Pilgrim Blue — is reserved for primary information, as it was in the manuscript tradition for the sacred image versus the marginal commentary.

**What to explicitly avoid:** Pucelle's marginalia include hybrid creatures, grotesques, and playful figures (jousting knights, acrobats, drolleries) serving a decorative-satirical function. The Faithful's visual language is earnest and emotionally serious. Do not adopt the playful-grotesque quality of medieval marginalia. The illustrative character, yes. The humor and absurdism, no.

**Pillar and section served:** Section 7.3 (iconography style — partial-fill grisaille-inspired treatment) and Section 4.4 (UI palette — full color reserved for primary information). Serves Principle 1: Weight Before Flash. *Source: MET Open Access digital collection — high-resolution scans available for production reference.*

---

### Reference 5: Disco Elysium — Psychological Portrait Lighting (ZA/UM, Aleksander Rostov et al., 2019)

**Specific visual element to draw from:** The technique of using portrait light sourcing and color temperature to communicate a character's internal emotional condition rather than the scene's ambient lighting. Characters with repressed trauma are lit from an unusual angle; characters in denial have nearly clinical flat portrait light; characters at emotional breaking points are lit with warm intensity that feels intimate to the point of uncomfortable. This technique — using light as psychological notation, not environmental notation — is directly applicable to The Faithful's portrait system, where a character's current emotional resistance or openness should be legible in the quality of light on their face before the player reads any trait indicator.

**What to explicitly avoid:** Disco Elysium's portrait style is expressionistic and contemporary — thick impasto-like brushwork, slightly distorted proportions, highly saturated skin tones in shadow regions. The Faithful requires a more controlled, period-referencing hand. The brushwork should suggest a trained miniaturist, not a twentieth-century expressionist. Do not adopt DE's visible brushwork texture, color exaggeration in skin tones, or willingness to distort proportion for emotional effect. Borrow the technique of psychological light sourcing; execute it with period-consistent restraint.

**Pillar and section served:** Section 5 (Character Design Direction) and Section 2 (Mood and Atmosphere — specifically the way lighting shifts communicate emotional state). Serves Principle 2: The Portrait Is the Story — the specific practice of encoding psychological information through portrait lighting direction and color temperature.
