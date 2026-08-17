class_name NPCFlavourData
extends Resource
## NPCFlavourData — one archetype's flavour content (Dialogue Content
## Database GDD Core Rule 6): a one-sentence short_descriptor (the "stranger
## at a distance" impression shown before traits are revealed) and exactly 3
## inspect_lines describing observable behaviour, social posture or first
## impressions — NOT trait/conversion information (trait text is owned by the
## NPC Trait Database). Static definition only; recency across encounters is
## the Dialogue & Conversion System's responsibility (EC-10).

## Which NPCArchetype this entry describes (GameEnums.NPCArchetype int).
@export var archetype: GameEnums.NPCArchetype = GameEnums.NPCArchetype.LABORER
## One-sentence first-encounter descriptor. May be empty only as a content
## error (EC-2); the Portrait & Expression System must fall back when empty.
@export var short_descriptor: String = ""
## Inspect-panel lines (3 at MVP per the L_inspect invariant).
@export var inspect_lines: Array[String] = []