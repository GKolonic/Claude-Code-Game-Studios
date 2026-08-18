class_name NPCArchetypeDatabaseCatalogue
extends Resource
## NPCArchetypeDatabaseCatalogue — the serialised 7-archetype container
## loaded from res://assets/data/npcs/archetypes.tres (NPC Character System
## GDD Rule 3 data; ADR-0002 architecture diagram). Pure data carrier that
## mirrors TraitDatabaseCatalogue / DialogueDatabaseCatalogue (Sprint 1
## precedent); the NPCRegistry Autoload (2-6) owns indexing + the typed
## get_archetype_definition() API.

@export var archetypes: Array[NPCArchetypeDefinition] = []