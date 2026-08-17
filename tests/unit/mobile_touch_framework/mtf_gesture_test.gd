extends GutTest
## MobileTouchFramework unit suite — Sprint 1 task 1-13 (MTF GDD AC-1..AC-14;
## QA plan MTF-1..8, MTF-10..17).
##
## Synthetic InputEvents per QA plan OQ-A: events are constructed with
## InputEventScreenTouch/Drag and delivered by calling the MTF instance's
## _input() directly — deterministic, no emulator layer, and the LIVE
## MobileTouchFramework autoload is never disturbed (its IDLE state machine
## stays untouched across the suite).
##
## Time is deterministic via an injected fake clock (_time_source). Every
## test instance is a fresh MobileTouchFramework (no _ready), pixels_per_dp
## is pinned to 1.0 for dp==px math unless the test is about dp conversion.

const MTF_SCRIPT := preload("res://src/autoload/mobile_touch_framework.gd")

var _mtf = null
var _now: Dictionary = {"t": 0}
var _controls: Array[Control] = []
var _mtfs: Array = []  # extra fresh MTF instances to free in after_each


func before_each() -> void:
	_now.t = 0
	_mtf = MTF_SCRIPT.new()
	_mtf._time_source = _fake_clock
	_mtf.pixels_per_dp = 1.0
	_mtf._warnings.clear()
	watch_signals(_mtf)


func after_each() -> void:
	if is_instance_valid(_mtf):
		_mtf.free()
	for control in _controls:
		if is_instance_valid(control):
			control.free()
	_controls.clear()
	for mtf in _mtfs:
		if is_instance_valid(mtf):
			mtf.free()
	_mtfs.clear()


func _fake_clock() -> int:
	# Resolved at call time — no lambda capture semantics involved.
	return _now.t


func _advance(p_ms: int) -> void:
	_now.t += p_ms


func _register(p_control: Control, p_priority: int = 0,
		p_pos: Vector2 = Vector2(100, 100), p_size: Vector2 = Vector2(60, 60)) -> Control:
	p_control.position = p_pos
	p_control.size = p_size
	add_child(p_control)
	_controls.append(p_control)
	_mtf.register(p_control, p_priority)
	return p_control


func _touch_down(p_pos: Vector2, p_finger: int = 0) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = p_finger
	ev.pressed = true
	ev.position = p_pos
	_mtf._input(ev)


func _touch_up(p_pos: Vector2, p_finger: int = 0) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = p_finger
	ev.pressed = false
	ev.position = p_pos
	_mtf._input(ev)


func _drag(p_pos: Vector2, p_finger: int = 0) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = p_finger
	ev.position = p_pos
	_mtf._input(ev)


func _tap_at(p_pos: Vector2, p_finger: int = 0) -> void:
	_touch_down(p_pos, p_finger)
	_advance(100)
	_touch_up(p_pos, p_finger)


func _last_swipe_params() -> Array:
	return get_signal_parameters(_mtf, "swiped", 0)


# --- AC-1..2: tap classification ------------------------------------------

func test_ac_1_tap_hit_emits_once_with_target_and_haptic() -> void:
	# AC-1: 60x60dp control at screen center-ish; down+release within 350ms,
	# movement <= 8dp -> tapped(target, position) exactly once + 80ms haptic.
	var control := _register(Control.new())
	_touch_down(Vector2(130, 130))
	_advance(100)
	_touch_up(Vector2(130, 130))
	assert_signal_emit_count(_mtf, "tapped", 1, "tapped must fire exactly once (AC-1)")
	assert_signal_emitted_with_parameters(_mtf, "tapped", [control, Vector2(130, 130)])
	assert_eq(_mtf.get_haptic_pulse_count(), 1, "haptic must fire on confirmed tap (AC-1)")
	assert_eq(_mtf.get_handled_count(), 1, "consumed tap must mark the event handled")
	assert_eq(_mtf.get_state(), MTF_SCRIPT.STATE_IDLE, "state must return to IDLE")


func test_ac_2_tap_miss_emits_nothing() -> void:
	# AC-2: no registered area at the position -> no signal, no haptic.
	_touch_down(Vector2(400, 400))
	_advance(100)
	_touch_up(Vector2(400, 400))
	assert_signal_not_emitted(_mtf, "tapped")
	assert_signal_not_emitted(_mtf, "long_press_started")
	assert_signal_not_emitted(_mtf, "long_press_released")
	assert_signal_not_emitted(_mtf, "swiped")
	assert_eq(_mtf.get_haptic_pulse_count(), 0, "miss must not fire haptic (AC-2)")
	assert_eq(_mtf.get_handled_count(), 0, "miss must NOT mark the event handled (R3)")


# --- AC-3: tap target inflation -------------------------------------------

func test_ac_3_tap_target_inflation_44dp_floor() -> void:
	# AC-3: 20x20dp control -> inflated hit rect 44x44 centered on the visual
	# bounds. A tap at the inflated corner hits; one pixel beyond misses.
	# Name BEFORE registration so the warning names the node (AC-3).
	var control := Control.new()
	control.name = "SmallTarget"
	_register(control, 0, Vector2(100, 100), Vector2(20, 20))
	assert_true(_warnings_contain("SmallTarget"), "registration must warn naming node path")
	assert_true(_warnings_contain("44"), "registration warning must name the actual dp size")
	_touch_down(Vector2(88, 88))  # inflated rect corner (44x44 centered on 100,100)
	_advance(50)
	_touch_up(Vector2(88, 88))
	assert_signal_emitted_with_parameters(_mtf, "tapped", [control, Vector2(88, 88)])
	# Second gesture one pixel outside the inflated rect -> miss.
	_touch_down(Vector2(87, 110))
	_advance(50)
	_touch_up(Vector2(87, 110))
	assert_signal_emit_count(_mtf, "tapped", 1, "tap outside inflated rect must miss")
	assert_eq(_mtf.get_haptic_pulse_count(), 1)


func _warnings_contain(p_fragment: String) -> bool:
	for w in _mtf.get_warnings():
		if w.contains(p_fragment):
			return true
	return false


# --- AC-4..5: long press + dead band --------------------------------------

func test_ac_4_long_press_starts_at_600ms_and_releases() -> void:
	# AC-4: motionless hold -> long_press_started at exactly 600ms; release ->
	# long_press_released. No tapped / touch_cancelled.
	var control := _register(Control.new())
	_touch_down(Vector2(130, 130))
	_advance(599)
	_drag(Vector2(130, 130))
	assert_signal_not_emitted(_mtf, "long_press_started",
		"threshold must not fire before 600ms")
	_advance(1)  # total 600ms
	_drag(Vector2(130, 130))
	assert_signal_emit_count(_mtf, "long_press_started", 1,
		"long_press_started must fire at exactly 600ms (AC-4)")
	assert_signal_emitted_with_parameters(_mtf, "long_press_started", [control, Vector2(130, 130)])
	assert_eq(_mtf.get_state(), MTF_SCRIPT.STATE_LONG_PRESS_PENDING)
	_advance(100)
	_touch_up(Vector2(130, 130))
	assert_signal_emit_count(_mtf, "long_press_released", 1,
		"release after threshold must emit long_press_released (AC-4)")
	assert_signal_not_emitted(_mtf, "tapped")
	assert_signal_not_emitted(_mtf, "touch_cancelled")
	assert_eq(_mtf.get_haptic_pulse_count(), 0, "long press must NOT fire tap haptic")
	assert_eq(_mtf.get_state(), MTF_SCRIPT.STATE_IDLE)


func test_ac_5_dead_band_emits_nothing() -> void:
	# AC-5: 400ms hold with movement <= 8dp -> no signal, back to IDLE.
	_register(Control.new())
	_touch_down(Vector2(130, 130))
	_advance(400)
	_touch_up(Vector2(130, 130))
	assert_signal_not_emitted(_mtf, "tapped")
	assert_signal_not_emitted(_mtf, "long_press_started")
	assert_signal_not_emitted(_mtf, "long_press_released")
	assert_signal_not_emitted(_mtf, "touch_cancelled")
	assert_eq(_mtf.get_haptic_pulse_count(), 0)
	assert_eq(_mtf.get_state(), MTF_SCRIPT.STATE_IDLE, "dead band must return to IDLE (AC-5)")


func test_tap_boundary_at_350ms() -> void:
	# Edge: exactly TAP_MAX_DURATION_MS is still a tap.
	_register(Control.new())
	_touch_down(Vector2(130, 130))
	_advance(350)
	_touch_up(Vector2(130, 130))
	assert_signal_emit_count(_mtf, "tapped", 1)


func test_dead_band_at_351ms() -> void:
	# Edge: 1ms past the tap ceiling -> dead band, silent.
	_register(Control.new())
	_touch_down(Vector2(130, 130))
	_advance(351)
	_touch_up(Vector2(130, 130))
	assert_signal_not_emitted(_mtf, "tapped")


# --- AC-6..7: swipes ------------------------------------------------------

func test_ac_6_swipe_classification_four_directions() -> void:
	# AC-6: >=40dp drag at >=150dp/s in each cardinal direction -> swiped with
	# the correct SwipeDirection (F-4 sectors); velocity ~1000dp/s (100px/0.1s).
	var expectations := [
		[Vector2(200, 640), Vector2(300, 640), GameEnums.SwipeDirection.RIGHT, Vector2(100, 0)],
		[Vector2(200, 640), Vector2(200, 540), GameEnums.SwipeDirection.UP, Vector2(0, -100)],
		[Vector2(200, 640), Vector2(100, 640), GameEnums.SwipeDirection.LEFT, Vector2(-100, 0)],
		[Vector2(200, 640), Vector2(200, 740), GameEnums.SwipeDirection.DOWN, Vector2(0, 100)],
	]
	for expected in expectations:
		var fresh := MTF_SCRIPT.new()
		_mtfs.append(fresh)  # after_each frees it (clean-up even on failure)
		fresh._time_source = _fake_clock
		fresh.pixels_per_dp = 1.0
		fresh._warnings.clear()
		watch_signals(fresh)
		_now.t = 0
		_register_on(fresh, Control.new())
		var from: Vector2 = expected[0]
		var to: Vector2 = expected[1]
		fresh._input(_make_touch(from, true))
		_now.t = 400
		fresh._input(_make_touch_drag(to))
		_now.t = 500
		fresh._input(_make_touch(to, false))
		assert_signal_emit_count(fresh, "swiped", 1,
			"direction %s must emit swiped exactly once" % GameEnums.SwipeDirection.keys()[expected[2]])
		var params: Array = get_signal_parameters(fresh, "swiped", 0)
		assert_eq(params[0], expected[2], "swipe direction mismatch (AC-6)")
		assert_eq(params[1], expected[3], "swipe delta mismatch (AC-6)")
		assert_almost_eq(float(params[2]), 1000.0, 1.0, "swipe velocity ~1000dp/s (AC-6)")
		# fresh is freed by after_each via _mtfs — no inline free.


func test_ac_7_swipe_velocity_gate_rejects_slow_drag() -> void:
	# AC-7: 50dp travelled but release velocity < 150dp/s -> no swiped, no
	# haptic, IDLE (silent cancelled).
	_register(Control.new())
	_touch_down(Vector2(200, 640))
	_now.t = 400
	_drag(Vector2(250, 640))  # 50dp >= 40dp -> SWIPE_TRACKING
	_now.t = 799  # (799-400)ms -> velocity ~125.3dp/s < 150
	_touch_up(Vector2(250, 640))
	assert_signal_not_emitted(_mtf, "swiped")
	assert_signal_not_emitted(_mtf, "tapped")
	assert_eq(_mtf.get_haptic_pulse_count(), 0)
	assert_eq(_mtf.get_state(), MTF_SCRIPT.STATE_IDLE, "velocity-cancel must return to IDLE (AC-7)")


func test_swipe_sector_boundaries() -> void:
	# F-4 boundary convention (45-degree sectors; ties resolve deterministically).
	var cases := {
		Vector2(100, -99): GameEnums.SwipeDirection.RIGHT,  # 44.7 deg
		Vector2(100, -101): GameEnums.SwipeDirection.UP,    # 45.3 deg
		Vector2(100, 99): GameEnums.SwipeDirection.RIGHT,   # -44.7 deg
		Vector2(100, 101): GameEnums.SwipeDirection.DOWN,   # -45.3 deg
		Vector2(-100, -99): GameEnums.SwipeDirection.LEFT,  # 135.3 deg
		Vector2(-100, -101): GameEnums.SwipeDirection.UP,   # 134.7 deg
		Vector2(-100, 99): GameEnums.SwipeDirection.LEFT,   # -135.3 deg
		Vector2(-100, 101): GameEnums.SwipeDirection.DOWN,  # -134.7 deg
	}
	for delta in cases:
		assert_eq(_mtf._classify_swipe_direction(delta), cases[delta],
			"delta %s must classify as %s" % [str(delta),
				GameEnums.SwipeDirection.keys()[cases[delta]]])


# --- AC-8: multi-finger ---------------------------------------------------

func test_ac_8_second_finger_discarded_gesture_continues() -> void:
	# AC-8: finger 1 during an active finger-0 gesture is silently discarded;
	# the active gesture continues and resolves as a normal tap.
	var control := _register(Control.new())
	_touch_down(Vector2(130, 130), 0)
	_advance(50)
	_touch_down(Vector2(400, 400), 1)  # discarded
	_advance(50)
	_touch_up(Vector2(130, 130), 0)
	assert_signal_emit_count(_mtf, "tapped", 1,
		"finger-0 tap must fire; finger-1 must not produce signals (AC-8)")
	assert_signal_emitted_with_parameters(_mtf, "tapped", [control, Vector2(130, 130)])
	# Release of the discarded finger afterwards must also be ignored (EC-2).
	_advance(50)
	_touch_up(Vector2(400, 400), 1)
	assert_signal_emit_count(_mtf, "tapped", 1)


# --- AC-9: blocking layers (QA MTF-9; ADR-0006 Decision 5) ----------------

func test_ac_9_blocking_layer_suppresses_lower_priority() -> void:
	# AC-9: A(prio 1) and B(prio 10); push_blocking_layer("modal", tier 5) ->
	# taps on A produce no signal, taps on B still fire; pop -> A resumes.
	var a := _register(Control.new(), 1, Vector2(100, 100), Vector2(60, 60))
	var b := _register(Control.new(), 10, Vector2(200, 100), Vector2(60, 60))
	_mtf.push_blocking_layer(&"modal", 5)
	# Tap on A -> suppressed: no signal, no handled-mark (R3).
	_tap_at(Vector2(130, 130))
	assert_signal_not_emitted(_mtf, "tapped", "A(prio 1 < tier 5) must be silenced (AC-9)")
	assert_eq(_mtf.get_handled_count(), 0, "suppressed tap must not mark handled")
	# Tap on B -> still fires with the correct target.
	_tap_at(Vector2(230, 130))
	assert_signal_emit_count(_mtf, "tapped", 1, "B(prio 10 >= tier 5) must still fire (AC-9)")
	assert_signal_emitted_with_parameters(_mtf, "tapped", [b, Vector2(230, 130)])
	assert_eq(_mtf.get_haptic_pulse_count(), 1, "allowed tap haptics as normal")
	# Pop -> A resumes.
	_mtf.pop_blocking_layer(&"modal")
	_tap_at(Vector2(130, 130))
	assert_signal_emit_count(_mtf, "tapped", 2, "A must resume after pop (AC-9)")
	assert_signal_emitted_with_parameters(_mtf, "tapped", [a, Vector2(130, 130)])


func test_ac_9_unregister_resumes_immediately_after_pop() -> void:
	# Unregister while a blocking layer is active: no stale entries linger
	# after pop (registry is priority-sorted, removals never re-add).
	var a := _register(Control.new(), 1, Vector2(100, 100), Vector2(60, 60))
	_register(Control.new(), 10, Vector2(200, 100), Vector2(60, 60))
	_mtf.push_blocking_layer(&"modal", 5)
	_mtf.unregister(a)
	_mtf.pop_blocking_layer(&"modal")
	assert_eq(_mtf.get_registered_count(), 1, "unregister must remove the entry")
	_tap_at(Vector2(130, 130))
	assert_signal_not_emitted(_mtf, "tapped", "unregistered control must never fire")


func test_blocking_layer_subtree_controls_disabled_and_restored() -> void:
	# Rule 9 / ADR-0006 guide: a blocking layer over a UI subtree sets every
	# Control's mouse_filter to IGNORE (blocks _gui_input() consumption) and
	# restores the saved filters on pop.
	var modal := Control.new()
	modal.name = "Modal"
	add_child(modal)
	_controls.append(modal)
	var button := Button.new()
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(button)
	_controls.append(button)
	var child := Control.new()
	child.mouse_filter = Control.MOUSE_FILTER_PASS
	button.add_child(child)
	_controls.append(child)
	_mtf.push_blocking_layer(&"modal", 5, modal)
	assert_eq(button.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"subtree button must be disabled while blocked (Rule 9)")
	assert_eq(child.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"recursive disable must reach grandchildren")
	_mtf.pop_blocking_layer(&"modal")
	assert_eq(button.mouse_filter, Control.MOUSE_FILTER_STOP,
		"subtree button filter must be restored on pop")
	assert_eq(child.mouse_filter, Control.MOUSE_FILTER_PASS,
		"subtree child filter must be restored on pop")
	assert_eq(_mtf.get_blocking_layer_count(), 0)


func test_blocking_layer_stack_ordering_and_clear() -> void:
	# Rule 9 stack: layers l1(tier 3) + l2(tier 8); a(prio 1) blocked by l1,
	# b(prio 5) pass l1 but blocked by l2, c(prio 10) unblocked. clear_layer
	# stack restores everything (EC-7 path).
	var a := _register(Control.new(), 1, Vector2(100, 100), Vector2(60, 60))
	var b := _register(Control.new(), 5, Vector2(200, 100), Vector2(60, 60))
	var c := _register(Control.new(), 10, Vector2(300, 100), Vector2(60, 60))
	_mtf.push_blocking_layer(&"l1", 3)
	_mtf.push_blocking_layer(&"l2", 8)
	assert_eq(_mtf.get_blocking_layer_count(), 2)
	_tap_at(Vector2(130, 130))  # a -> blocked by l1
	_tap_at(Vector2(230, 130))  # b -> blocked by l2
	_tap_at(Vector2(330, 130))  # c -> passes both tiers
	assert_signal_emit_count(_mtf, "tapped", 1, "only c must fire under the 2-layer stack")
	assert_signal_emitted_with_parameters(_mtf, "tapped", [c, Vector2(330, 130)])
	_mtf.clear_blocking_layers()
	assert_eq(_mtf.get_blocking_layer_count(), 0, "clear must empty the stack")
	_tap_at(Vector2(130, 130))
	_tap_at(Vector2(230, 130))
	assert_signal_emit_count(_mtf, "tapped", 3, "all areas must resume after clear (EC-7)")


# --- AC-10: gesture timeout -----------------------------------------------

func test_ac_10_gesture_timeout_emits_touch_cancelled() -> void:
	# AC-10: a drag that drifted past slop (so no long press applies) and no
	# touch-up within 800ms -> touch_cancelled, IDLE.
	_register(Control.new())
	_touch_down(Vector2(200, 640))
	_now.t = 100
	_drag(Vector2(220, 660))  # ~28dp from down: > 8dp slop, < 40dp swipe
	_now.t = 801
	_drag(Vector2(220, 660))  # check fires on event arrival
	assert_signal_emit_count(_mtf, "touch_cancelled", 1,
		"timeout must emit touch_cancelled (AC-10)")
	assert_signal_not_emitted(_mtf, "tapped")
	assert_eq(_mtf.get_state(), MTF_SCRIPT.STATE_IDLE)


# --- AC-11: debounce ------------------------------------------------------

func test_ac_11_debounce_discards_bounce_tap_within_100ms() -> void:
	# AC-11: a new touch within 100ms at <= 10dp of the previous touch end is
	# discarded; a later touch outside the window is accepted.
	var control := _register(Control.new())
	_touch_down(Vector2(130, 130))
	_advance(100)
	_touch_up(Vector2(130, 130))
	assert_signal_emit_count(_mtf, "tapped", 1)
	# Bounce: 50ms later, ~7dp away -> discarded (no second tap).
	_advance(50)  # t=150, elapsed 50ms < 100ms
	_touch_down(Vector2(135, 125))
	assert_eq(_mtf.get_state(), MTF_SCRIPT.STATE_IDLE,
		"bounce touch-down must be discarded before the state machine (AC-11)")
	_advance(50)
	_touch_up(Vector2(135, 125))  # state IDLE -> EC-2 discard
	assert_signal_emit_count(_mtf, "tapped", 1)
	# Legitimate second tap after the window: elapsed 100ms -> accepted.
	_advance(50)  # t=250, elapsed (250-150)=100ms -> not < 100ms
	_touch_down(Vector2(130, 130))
	_advance(100)
	_touch_up(Vector2(130, 130))
	assert_signal_emit_count(_mtf, "tapped", 2,
		"a tap after the debounce window must be accepted (AC-11)")


# --- AC-12..13: dp conversion ---------------------------------------------

func test_ac_12_dpi_fallback_for_zero_or_implausible() -> void:
	# AC-12: raw DPI 0 -> pixels_per_dp 1.0 + warning naming the value.
	_mtf._warnings.clear()
	assert_eq(_mtf._compute_pixels_per_dp(0), 1.0, "DPI 0 must fall back to 160 (AC-12)")
	assert_true(_warnings_contain("0"), "fallback warning must name the detected value")
	# Implausible low/high also fall back.
	assert_eq(_mtf._compute_pixels_per_dp(-5), 1.0)
	assert_eq(_mtf._compute_pixels_per_dp(641), 1.0)
	# In-band values convert directly (72 and 640 clamp edges).
	assert_almost_eq(_mtf._compute_pixels_per_dp(72), 0.45, 0.0001)
	assert_almost_eq(_mtf._compute_pixels_per_dp(640), 4.0, 0.0001)


func test_ac_13_dp_conversion_accuracy_at_390_dpi() -> void:
	# AC-13: DPI 390 -> pixels_per_dp = 390/160 = 2.4375; a 44dp minimum tap
	# target = 44 x 2.4375 = 107.25px.
	var ppd: float = _mtf._compute_pixels_per_dp(390)
	assert_almost_eq(ppd, 2.4375, 0.0001, "pixels_per_dp at 390 DPI must be 2.4375 (AC-13)")
	var min_px: float = float(MTF_SCRIPT.TAP_TARGET_MIN_SIZE_DP) * ppd
	assert_almost_eq(min_px, 107.25, 0.001, "44dp must convert to 107.25px (AC-13)")
	_mtf.pixels_per_dp = ppd
	var rect: Rect2 = _mtf._inflate_rect(Rect2(100, 100, 20, 20), min_px)
	assert_almost_eq(rect.size.x, 107.25, 0.001, "inflated width must be 107.25px (AC-13)")
	assert_almost_eq(rect.size.y, 107.25, 0.001, "inflated height must be 107.25px (AC-13)")
	assert_almost_eq(rect.position.x, 56.375, 0.001, "inflation must be center-anchored")


# --- AC-14: no visual output ----------------------------------------------

func test_ac_14_no_visual_output_in_release_builds() -> void:
	# AC-14 (automated assert; OQ-C): the framework renders nothing — zero
	# child nodes after real gestures, and the debug-overlay flag is off.
	assert_false(MTF_SCRIPT.DEBUG_OVERLAY_ENABLED,
		"debug overlay must be disabled (AC-14)")
	_register(Control.new())
	_touch_down(Vector2(130, 130))
	_advance(100)
	_touch_up(Vector2(130, 130))
	_touch_down(Vector2(200, 200))
	_now.t += 400
	_touch_up(Vector2(200, 200))
	assert_eq(_mtf.get_child_count(), 0,
		"MTF must own no rendered nodes after gestures (AC-14)")
	# Manual export spot-check evidence path: see session-state record — an
	# Android export + screenshot pass is prescribed at M7 (no export
	# templates installed this sprint; sprint plan Section F).


# --- EC-8: long press -> swipe transition ----------------------------------

func test_ec_8_long_press_transitions_to_swipe_without_released() -> void:
	# EC-8: movement >= 40dp while LONG_PRESS_PENDING -> SWIPE_TRACKING;
	# long_press_released must NOT be emitted; the swipe still fires.
	# Control registered over the gesture area so the hold hit-tests.
	_register(Control.new(), 0, Vector2(200, 600), Vector2(120, 80))
	_touch_down(Vector2(200, 640))
	_now.t = 600
	_drag(Vector2(200, 640))  # hold timer -> long_press_started
	assert_signal_emit_count(_mtf, "long_press_started", 1)
	_now.t = 700
	_drag(Vector2(300, 640))  # >= 40dp -> SWIPE_TRACKING (EC-8)
	assert_signal_not_emitted(_mtf, "long_press_released",
		"EC-8: no release signal when the hold becomes a swipe")
	_now.t = 750
	_touch_up(Vector2(300, 640))
	assert_signal_emit_count(_mtf, "swiped", 1)
	assert_signal_emit_count(_mtf, "long_press_released", 0)


# --- R3 discipline (MTF-16) -----------------------------------------------

func test_r3_handled_mark_only_for_consumed_gestures() -> void:
	# R3/ADR-0006: handled-mark count must equal consumed gestures only.
	# Miss + dead band + discarded multi-finger must leave it at zero; each
	# consumed tap/swipe increments by one.
	_touch_down(Vector2(400, 400))  # miss
	_advance(100)
	_touch_up(Vector2(400, 400))
	assert_eq(_mtf.get_handled_count(), 0, "miss must not mark handled (R3)")
	_register(Control.new())
	_touch_down(Vector2(130, 130))  # hit
	_advance(100)
	_touch_up(Vector2(130, 130))
	assert_eq(_mtf.get_handled_count(), 1, "consumed tap must mark handled once")


# --- MTF-15: sole input boundary (code scan) -------------------------------

func test_mtf_15_no_src_code_reads_input_outside_mtf() -> void:
	# ADR-0006 Decision 1 (control-manifest Forbidden rule): no src/ .gd file
	# outside mobile_touch_framework.gd may reference raw touch events, the
	# Input singleton, or set_input_as_handled. Scans the whole src/ tree.
	var offenders := _scan_src_excluding_mtf(["InputEventScreenTouch", "InputEventScreenDrag", "Input.", "set_input_as_handled"])
	assert_eq(offenders, [], "sole input boundary violated (MTF-15) — offenders: %s" % str(offenders))


func test_mtf_16_set_input_as_handled_lives_only_in_mtf() -> void:
	# R3 / ADR-0006: set_input_as_handled may appear ONLY inside MTF; every
	# other src file must be free of it.
	var offenders := _scan_src_excluding_mtf(["set_input_as_handled"])
	assert_eq(offenders, [], "set_input_as_handled outside MTF (MTF-16) — offenders: %s" % str(offenders))


func _scan_src(p_patterns: Array[String]) -> Array[String]:
	return _walk_for_patterns("res://src", p_patterns, false)


func _scan_src_excluding_mtf(p_patterns: Array[String]) -> Array[String]:
	return _walk_for_patterns("res://src", p_patterns, true)


func _walk_for_patterns(p_dir: String, p_patterns: Array[String], p_exclude_mtf: bool) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(p_dir)
	if dir == null:
		return out
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full := p_dir.path_join(file_name)
		if dir.current_is_dir():
			out.append_array(_walk_for_patterns(full, p_patterns, p_exclude_mtf))
		elif file_name.ends_with(".gd"):
			if p_exclude_mtf and file_name == "mobile_touch_framework.gd":
				file_name = dir.get_next()
				continue
			var text := FileAccess.get_file_as_string(full)
			for pattern in p_patterns:
				if text.contains(pattern):
					out.append("%s contains '%s'" % [full, pattern])
		file_name = dir.get_next()
	dir.list_dir_end()
	return out


# --- helpers (fresh instances for looped / independent gestures) ----------

func _register_on(p_mtf, p_control: Control) -> Control:
	p_control.position = Vector2(300, 600)
	p_control.size = Vector2(120, 80)
	add_child(p_control)
	_controls.append(p_control)
	p_mtf.register(p_control, 0)
	return p_control


func _make_touch(p_pos: Vector2, p_pressed: bool, p_finger: int = 0) -> InputEventScreenTouch:
	var ev := InputEventScreenTouch.new()
	ev.index = p_finger
	ev.pressed = p_pressed
	ev.position = p_pos
	return ev


func _make_touch_drag(p_pos: Vector2, p_finger: int = 0) -> InputEventScreenDrag:
	var ev := InputEventScreenDrag.new()
	ev.index = p_finger
	ev.position = p_pos
	return ev