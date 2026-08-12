class_name TraitDatabaseCatalogue
extends Resource
## TraitDatabaseCatalogue — the serialised 16-trait container loaded by the
## TraitDatabase Autoload from res://assets/data/traits/trait_database.tres.
## Pure data carrier (ADR-0002); the Autoload owns indexing + the typed API.

@export var traits: Array[TraitData] = []
