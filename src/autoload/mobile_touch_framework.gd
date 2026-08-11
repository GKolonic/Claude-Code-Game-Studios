extends Node
## MobileTouchFramework — Autoload stub, ADR-0001 slot 4.
## Foundation: the sole input boundary — tap/long-press/swipe detection via
## _input(), dp conversion, blocking-layer stack. Real logic lands in Sprint 1
## task 1-13. Boot-order shell: asserts GameConfig (slot 1) is booted
## (architecture §3.1 — GameConfig optional future dependency; engine input).

func _ready() -> void:
	assert(is_instance_valid(GameConfig),
		"MobileTouchFramework (slot 4): GameConfig (slot 1) must boot first (ADR-0001)")
