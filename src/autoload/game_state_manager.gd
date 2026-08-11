extends Node
## GameStateManager — Autoload stub, ADR-0001 slot 8.
## Core: turn authority, faith power, village win/loss; exclusive NPC-lifecycle
## caller. Listed AFTER DialogueConversionSystem (GSM Rule 10 / ADR-0001).
## Real logic lands at M3. Boot-order shell: asserts slots 1-7 are booted and
## connects to DCS session signals via call_deferred so the subscription
## happens after EVERY Autoload finished _ready() — a session signal cannot
## fire before the connection exists (ADR-0001 verification, QA BOOT-3).

func _ready() -> void:
	assert(is_instance_valid(GameConfig),
		"GSM (slot 8): GameConfig (slot 1) must boot first (ADR-0001)")
	assert(is_instance_valid(NPCRegistry),
		"GSM (slot 8): NPCRegistry (slot 5) must boot first (ADR-0001)")
	assert(is_instance_valid(DialogueConversionSystem),
		"GSM (slot 8): DCS (slot 7) must boot before GSM (GSM Rule 10 / ADR-0001)")
	# Deferred connect: runs after all Autoloads complete _ready(), so DCS
	# exists and no session signal can be missed.
	call_deferred("_connect_signals")

## ADR-0001: GSM subscribes to DCS session signals only after every Autoload's
## _ready() has run. Asserted here as well — a misordered boot fails loudly.
func _connect_signals() -> void:
	assert(is_instance_valid(DialogueConversionSystem),
		"GSM._connect_signals: DCS must exist before connecting (ADR-0001)")
	DialogueConversionSystem.session_begun.connect(_on_dcs_session_begun)
	DialogueConversionSystem.session_complete.connect(_on_dcs_session_complete)

func _on_dcs_session_begun(_npc_id: String) -> void:
	pass

func _on_dcs_session_complete() -> void:
	pass
