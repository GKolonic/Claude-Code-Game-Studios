class_name DialogueDatabaseCatalogue
extends Resource
## DialogueDatabaseCatalogue — the serialised 100-string dialogue content
## container loaded by the DialogueDatabase Autoload from
## res://assets/data/dialogue/dialogue_database.tres.
## Pure data carrier (ADR-0002); the Autoload owns indexing, validation and
## the typed read-only API (Dialogue Content Database GDD Rule 9).
##
## Slot organisation (GDD §Detailed Rules / §Formulas):
## - approach_lines: DialogueApproach int -> Array[String] (3 lines each at MVP)
## - outcome_lines:  "%d_%d" % [approach, outcome] -> Array[String] (3 each)
## - npc_flavour:    Array[NPCFlavourData], one entry per NPCArchetype
## - rival_lines:    DialogueApproach int -> Array[String] (3 each at MVP)

## Approach-line pools keyed by GameEnums.DialogueApproach int (0..3).
@export var approach_lines: Dictionary = {}
## Outcome pools keyed by the string key "%d_%d" % [approach, outcome].
@export var outcome_lines: Dictionary = {}
## One NPCFlavourData per archetype; `archetype` field carries the key.
@export var npc_flavour: Array[NPCFlavourData] = []
## Rival-faith pools keyed by GameEnums.DialogueApproach int (0..3).
@export var rival_lines: Dictionary = {}