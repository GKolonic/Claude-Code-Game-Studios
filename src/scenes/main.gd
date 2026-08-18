extends Node
## Main — boot/router node for main.tscn (ADR-0004; Sprint 1 story 1-22).
##
## Scaffold/sketch per architecture §9 OQ-6 and save-load-system.md OQ-02:
## the boot scene calls SaveLoadSystem.load_game() exactly once after every
## Autoload's _ready() has run (ADR-0001 order guarantees SaveLoadSystem is
## live at slot 10). Behaviour is deliberately deferred:
##   - real load/restore (save file checks, GSM/NPCRegistry restore) → M4
##   - village_map + hud_progress instantiation on load_completed → M6
##   - return-to-title routing after resolution_complete → M6 (HUD OQ-4)
## At MVP scaffold, "no save exists" is the only possible outcome, so the
## title placeholder renders via the load_not_found (and load_failed) path.
## This node holds no gameplay logic — scenes are presentation-only (ADR-0003).

@onready var _title_label: Label = %TitleLabel


func _ready() -> void:
	# Subscribe BEFORE emitting: load_game() fires load_not_found synchronously.
	SaveLoadSystem.load_not_found.connect(_show_title)
	SaveLoadSystem.load_failed.connect(_show_title)
	SaveLoadSystem.load_completed.connect(_on_load_completed)

	# ADR-0004 lifecycle: Main (boot) calls load_game() once, after Autoloads
	# ready. SaveLoadSystem guards re-entry (Save&Load GDD EC-8).
	SaveLoadSystem.load_game()


func _show_title() -> void:
	## load_not_found / load_failed: no session to restore → title placeholder.
	_title_label.visible = true


func _on_load_completed(village_id: String) -> void:
	## load_completed: M4+ will instantiate village_map + hud_progress here
	## (ADR-0004 lifecycle). Scaffold logs only — unreachable until M4 writes
	## a real save file.
	print("[Main] load_completed(%s) — village/HUD instantiation deferred to M4/M6" % village_id)