extends Node
## GameConfig — Autoload stub, ADR-0001 slot 1.
## Foundation: loads and validates the nine config-domain resources (.tres)
## and exposes typed accessors (pull pattern). Real logic lands in Sprint 1
## task 1-10. This stub is a boot-order shell: GameConfig is registered first
## (GameConfig GDD Rule 2 / EC-5, ADR-0001), so _ready() has no upstream
## dependencies to assert.

func _ready() -> void:
	# Slot 1 (ADR-0001): every downstream Autoload reads GameConfig in its
	# _ready(); nothing upstream to assert here.
	pass
