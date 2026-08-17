extends Node
## MobileTouchFramework — Autoload, ADR-0001 slot 4. The sole input boundary.
##
## Translates raw InputEventScreenTouch / InputEventScreenDrag into the named
## semantic gestures (Tap / Long Press / Swipe / Drag tracking) and emits the
## ADR-0003 pinned signal surface. Implemented per the Mobile Touch Framework
## GDD (Rules 1-15, F-1..F-5, AC-1..14) and ADR-0006 (Accepted, task 1-9).
##
## R3 mitigation (ADR-0006 Decision 4): MTF never relies on event arrival
## order. Hit-testing is registry-based (priority-sorted, 44dp-inflated rects)
## and set_input_as_handled() is called ONLY when a registered target
## consumed the event (tap hit, long-press release hit, swipe fired) — so
## Godot's reverse-scene-order _input() propagation cannot starve consumers.
##
## dp conversion is MTF-owned: pixels_per_dp is computed once at startup from
## DisplayServer.screen_get_dpi() with the F-1 160-DPI fallback. All gesture
## thresholds are expressed in dp and are compile-time constants at MVP
## (promotion path: ADR-0005). Haptic fires on confirmed Tap only (Rule 12);
## the framework renders nothing (AC-14).

signal tapped(target: Control, position: Vector2)
signal long_press_started(target: Control, position: Vector2)
signal long_press_released(target: Control, position: Vector2)
signal swiped(direction: GameEnums.SwipeDirection, delta: Vector2, velocity: float)
signal touch_cancelled()

# --- Rule 15 constants (non-overridable at MVP) ---------------------------
const TAP_MAX_DURATION_MS := 350
const LONG_PRESS_MIN_DURATION_MS := 600
const TOUCH_SLOP_DP := 8
const SWIPE_MIN_DISTANCE_DP := 40
const SWIPE_MIN_VELOCITY_DP_S := 150
const TAP_TARGET_MIN_SIZE_DP := 44
const TAP_TARGET_MIN_GAP_DP := 8
const TAP_TARGET_RECOMMENDED_GAP_DP := 16
const TAP_TARGET_MIN_CENTROID_DIST_DP := 56
const SAFE_ZONE_BOTTOM_FRACTION := 0.55
const DEBOUNCE_INTERVAL_MS := 100
const GESTURE_TIMEOUT_MS := 800
const HAPTIC_TAP_DURATION_MS := 80
const SINGLE_FINGER_MODE := true
const MAX_REGISTERED_AREAS := 32

# F-5 debounce proximity bound (Rule 13: ±10dp) — fixed per the GDD formula.
const DEBOUNCE_MAX_DIST_DP := 10.0

# GDD §States state machine
const STATE_IDLE := 0
const STATE_TOUCH_DOWN := 1
const STATE_LONG_PRESS_PENDING := 2
const STATE_SWIPE_TRACKING := 3
const STATE_RESOLVING := 4  # transient — kept for parity with the GDD table

# AC-14: the framework owns no debug-overlay UI at MVP; the release-flag is
# declared for the debug overlay contract and asserted by tests.
const DEBUG_OVERLAY_ENABLED := false

## Read-only (computed once at _ready; consumers must not write).
var pixels_per_dp: float = 1.0

var _state := STATE_IDLE
var _registry: Array[Dictionary] = []         # {control, priority, rect}
var _blocking_layers: Array[Dictionary] = []  # {id, tier, subtree}
var _saved_filters: Dictionary = {}           # id -> {Control: int}

var _down_time_ms := 0
var _down_pos := Vector2.ZERO
var _last_pos := Vector2.ZERO
var _swipe_sample_pos := Vector2.ZERO
var _swipe_sample_time_ms := 0
var _in_swipe_tracking := false
var _long_press_target: Control = null

var _last_touch_end_time_ms := -1000000
var _last_touch_end_pos := Vector2.ZERO

## Test seam: inject a fake clock for deterministic synthetic-input tests.
## Production uses the real wall clock (Time.get_ticks_msec()).
var _time_source: Callable = func() -> int: return Time.get_ticks_msec()

var _warnings: PackedStringArray = []
var _haptic_pulses := 0
var _handled_count := 0  # R3 discipline audit hook


func _ready() -> void:
	assert(is_instance_valid(GameConfig),
		"MobileTouchFramework (slot 4): GameConfig (slot 1) must boot first (ADR-0001)")
	pixels_per_dp = _compute_pixels_per_dp(DisplayServer.screen_get_dpi())


func _process(_delta: float) -> void:
	# Long-press threshold and gesture timeout are wall-clock driven so no
	# input events are required; the same checks run inside _input() so
	# synthetic-input tests can advance a fake clock deterministically.
	_check_hold_timer()
	_check_timeout()


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	_check_hold_timer()
	_check_timeout()
	# Godot 4.6 names the finger id `index` on InputEventScreenTouch/Drag
	# (no `finger_index` member). SINGLE_FINGER_MODE silently discards every
	# non-zero finger (EC-1, Rule 2).
	var finger := 0
	if event is InputEventScreenTouch:
		finger = (event as InputEventScreenTouch).index
	else:
		finger = (event as InputEventScreenDrag).index
	if SINGLE_FINGER_MODE and finger != 0:
		return  # silent discard (EC-1, Rule 2)
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	else:
		_handle_drag(event as InputEventScreenDrag)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _state != STATE_IDLE:
			return  # second finger during an active gesture (EC-1 invariant)
		if _debounce_rejects(event.position):
			return  # finger bounce (Rule 13 / F-5 / AC-11)
		_state = STATE_TOUCH_DOWN
		_down_pos = event.position
		_last_pos = event.position
		_down_time_ms = _now_ms()
		_in_swipe_tracking = false
		_long_press_target = null
		return
	_handle_release(event)


func _handle_drag(event: InputEventScreenDrag) -> void:
	if _state == STATE_IDLE or _state == STATE_RESOLVING:
		return
	if _in_swipe_tracking:
		# Track position; keep the FIRST swipe sample as the "oldest retained
		# sample" for velocity stability (F-3).
		_last_pos = event.position
		return
	_last_pos = event.position
	if _distance_dp(_down_pos, _last_pos) >= SWIPE_MIN_DISTANCE_DP:
		_state = STATE_SWIPE_TRACKING
		_in_swipe_tracking = true
		# F-3: the "oldest retained sample" is the touch-down position —
		# retained for the whole gesture — and the sample timestamp is when
		# the swipe window opened (threshold crossing). This matches the GDD
		# F-3 example (oldest sample is NOT the crossing position) and makes
		# the release velocity measure the flick over (release - window open).
		_swipe_sample_pos = _down_pos
		_swipe_sample_time_ms = _now_ms()
		# Long press is cancelled mid-hold; no long_press_released is emitted
		# (EC-8 — consuming systems connect to swiped/touch_cancelled too).


func _handle_release(event: InputEventScreenTouch) -> void:
	if _state == STATE_IDLE or _state == STATE_RESOLVING:
		return  # EC-2: touch-up without a preceding touch-down
	var duration := _now_ms() - _down_time_ms
	var dist_dp := _distance_dp(_down_pos, _last_pos)
	var release_pos := _last_pos
	match _state:
		STATE_LONG_PRESS_PENDING:
			var target := _hit_test(release_pos)
			if target == null:
				target = _long_press_target
			if target != null:
				emit_signal("long_press_released", target, release_pos)
				_mark_handled()
			_reset_gesture(release_pos)
		STATE_SWIPE_TRACKING:
			var velocity := _swipe_velocity_dp_s()
			var delta_px := _last_pos - _down_pos
			if dist_dp >= SWIPE_MIN_DISTANCE_DP and velocity >= SWIPE_MIN_VELOCITY_DP_S:
				emit_signal("swiped", _classify_swipe_direction(delta_px), delta_px, velocity)
				_mark_handled()
			# Slow drag (dist ok, velocity < threshold) or short drag resolves
			# as a cancelled gesture — no signal (AC-7).
			_reset_gesture(release_pos)
		_:
			# TOUCH_DOWN — movement never reached the swipe threshold.
			if dist_dp <= TOUCH_SLOP_DP:
				if duration <= TAP_MAX_DURATION_MS:
					_confirm_tap(event.position)
				elif duration < LONG_PRESS_MIN_DURATION_MS:
					pass  # dead band (Rule 4 / AC-5) — no signal
				# duration >= LONG_PRESS_MIN is unreachable here: the hold
				# timer (run at the top of _input) would already have moved
				# the state to LONG_PRESS_PENDING.
			# Movement > slop and < 40dp: cancelled — no signal.
			_reset_gesture(release_pos)


func _confirm_tap(p_position: Vector2) -> void:
	var target := _hit_test(p_position)
	if target != null:
		emit_signal("tapped", target, p_position)
		_haptic_pulses += 1
		Input.vibrate_handheld(HAPTIC_TAP_DURATION_MS)  # haptic on tap only (Rule 12)
		_mark_handled()
	# Miss: no signal, no haptic (AC-2).


# --- timers ---------------------------------------------------------------

func _check_hold_timer() -> void:
	var elapsed := _now_ms() - _down_time_ms
	# Rule 3 (LONG PRESS = held >= 600ms WITH movement <= 8dp from touch-down):
	# a finger that drifted past the slop while holding never long-presses; it
	# stays in TOUCH_DOWN and is subject to the 800ms gesture timeout instead.
	if _state == STATE_TOUCH_DOWN and elapsed >= LONG_PRESS_MIN_DURATION_MS \
			and _distance_dp(_down_pos, _last_pos) <= TOUCH_SLOP_DP:
		_state = STATE_LONG_PRESS_PENDING
		_long_press_target = _hit_test(_down_pos)
		if _long_press_target != null:
			emit_signal("long_press_started", _long_press_target, _down_pos)


func _check_timeout() -> void:
	if _state != STATE_TOUCH_DOWN and _state != STATE_SWIPE_TRACKING:
		return
	if _now_ms() - _down_time_ms >= GESTURE_TIMEOUT_MS:
		emit_signal("touch_cancelled")
		_state = STATE_IDLE
		_in_swipe_tracking = false
		_long_press_target = null


# --- registry -------------------------------------------------------------

## Registers a Control as a touch target. Computes the dp size at
## registration, inflates the hit rect to the 44dp minimum (F-2, center-
## anchored) and inserts into the priority-sorted registry. Must be called
## from the consumer's _ready() (GDD consuming-system contract).
func register(control: Control, priority: int) -> void:
	if control == null:
		push_warning("MTF: register called with a null control — ignored")
		return
	var rect := control.get_global_rect()
	var dp_w := rect.size.x / pixels_per_dp
	var dp_h := rect.size.y / pixels_per_dp
	if dp_w < TAP_TARGET_MIN_SIZE_DP or dp_h < TAP_TARGET_MIN_SIZE_DP:
		_warn("target %s measures %0.1fx%0.1fdp (below %ddp minimum) — hit rect inflated; visual size unchanged" % [
			_control_path(control), dp_w, dp_h, TAP_TARGET_MIN_SIZE_DP])
	var inflated := _inflate_rect(rect, TAP_TARGET_MIN_SIZE_DP * pixels_per_dp)
	if _registry.size() >= MAX_REGISTERED_AREAS:
		_warn("area registry exceeds %d registered areas (design constraint; check screen layout) — %s" % [
			MAX_REGISTERED_AREAS, _control_path(control)])
	_warn_adjacent_targets(control, inflated)
	_registry.append({"control": control, "priority": priority, "rect": inflated})
	_registry.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.priority) > int(b.priority))


## Removes a touch target. Must be called from the consumer's tree_exiting.
func unregister(control: Control) -> void:
	for i in range(_registry.size() - 1, -1, -1):
		if _registry[i].control == control:
			_registry.remove_at(i)


## Debug warning helpers for adjacent-target spacing (Rule 15 gap constants).
func _warn_adjacent_targets(p_control: Control, p_rect: Rect2) -> void:
	for entry in _registry:
		var other: Rect2 = entry.rect
		if _rects_overlap(p_rect, other):
			var gap_x := maxf(0.0, maxf(p_rect.position.x, other.position.x)
				- minf(p_rect.end.x, other.end.x))
			var gap_y := maxf(0.0, maxf(p_rect.position.y, other.position.y)
				- minf(p_rect.end.y, other.end.y))
			var min_gap_dp := maxf(gap_x, gap_y) / pixels_per_dp
			if min_gap_dp < TAP_TARGET_MIN_GAP_DP:
				_warn("targets %s and %s are within %0.1fdp edge-to-edge (minimum %ddp)" % [
					_control_path(p_control), _control_path(entry.control), min_gap_dp,
					TAP_TARGET_MIN_GAP_DP])
		var other_center := other.get_center()
		var my_center := p_rect.get_center()
		var centroid_dist_dp := my_center.distance_to(other_center) / pixels_per_dp
		if centroid_dist_dp < TAP_TARGET_MIN_CENTROID_DIST_DP:
			_warn("targets %s and %s centroids are %0.1fdp apart (debug threshold %ddp)" % [
				_control_path(p_control), _control_path(entry.control), centroid_dist_dp,
				TAP_TARGET_MIN_CENTROID_DIST_DP])


func _rects_overlap(a: Rect2, b: Rect2) -> bool:
	return a.position.x < b.end.x and b.position.x < a.end.x \
		and a.position.y < b.end.y and b.position.y < a.end.y


## Priority-sorted registry hit-test. Highest-priority area whose inflated
## rect contains the point wins (ADR-0006 Decision 4 — geometry, not arrival
## order). Blocked areas (below any active blocking layer's tier) are skipped.
func _hit_test(p_position: Vector2) -> Control:
	for entry in _registry:
		if not _area_active(entry):
			continue
		if entry.rect.has_point(p_position):
			return entry.control
	return null


func _area_active(p_entry: Dictionary) -> bool:
	if _blocking_layers.is_empty():
		return true
	var priority: int = p_entry.priority
	for layer in _blocking_layers:
		if priority < int(layer.tier):
			return false
	return true


# --- blocking layers (Rule 9; owner: Conversion UI — ADR-0003/0006) -------

## Adds a blocking layer to the priority stack. Areas with priority below
## `tier` stop receiving signals until the layer is popped. Optional
## `subtree` triggers Godot 4.5+ Recursive Control disable (verified on 4.6)
## so Controls in that subtree cannot consume input via _gui_input() either.
## Conversion UI is the ONLY sanctioned caller while a session is open.
func push_blocking_layer(layer_id: StringName, tier: int = 0, subtree: Control = null) -> void:
	if _find_layer(layer_id) != -1:
		push_warning("MTF: blocking layer '%s' is already active — ignoring duplicate push" % layer_id)
		return
	_blocking_layers.append({"id": layer_id, "tier": tier, "subtree": subtree})
	if subtree != null:
		var saved: Dictionary = {}
		_collect_and_disable(subtree, saved)
		_saved_filters[layer_id] = saved


## Removes the blocking layer; lower-priority areas resume receiving signals
## and the subtree's Control filters are restored.
func pop_blocking_layer(layer_id: StringName) -> void:
	var idx := _find_layer(layer_id)
	if idx == -1:
		push_warning("MTF: pop_blocking_layer('%s') with no matching active layer" % layer_id)
		return
	var layer: Dictionary = _blocking_layers[idx]
	_blocking_layers.remove_at(idx)
	if layer.subtree != null and _saved_filters.has(layer_id):
		_restore_filters(layer.subtree, _saved_filters[layer_id])
		_saved_filters.erase(layer_id)


## Clears the whole stack and restores every subtree (EC-7: e.g. on window
## focus loss).
func clear_blocking_layers() -> void:
	for layer in _blocking_layers:
		if layer.subtree != null and _saved_filters.has(layer.id):
			_restore_filters(layer.subtree, _saved_filters[layer.id])
			_saved_filters.erase(layer.id)
	_blocking_layers.clear()


func _find_layer(layer_id: StringName) -> int:
	for i in range(_blocking_layers.size()):
		if _blocking_layers[i].id == layer_id:
			return i
	return -1


func _collect_and_disable(p_node: Node, p_saved: Dictionary) -> void:
	if p_node is Control:
		var control := p_node as Control
		p_saved[control] = control.mouse_filter
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in p_node.get_children():
		_collect_and_disable(child, p_saved)


func _restore_filters(p_node: Node, p_saved: Dictionary) -> void:
	if p_node is Control:
		var control := p_node as Control
		if p_saved.has(control):
			control.mouse_filter = p_saved[control]
	for child in p_node.get_children():
		_restore_filters(child, p_saved)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		clear_blocking_layers()


# --- dp + math ------------------------------------------------------------

## F-1: pixels_per_dp from the raw device DPI with the 160-DPI fallback for
## 0/implausible values (EC-3, AC-12). Clamped to the 72-640 plausible band.
func _compute_pixels_per_dp(raw_dpi: int) -> float:
	if raw_dpi <= 0 or raw_dpi < 72 or raw_dpi > 640:
		_warn("implausible detected DPI %d — falling back to 160 DPI (pixels_per_dp = 1.0)" % raw_dpi)
		return 1.0
	return float(raw_dpi) / 160.0


## F-2: center-anchored rect inflation to the minimum tap-target size.
## Width and height handled independently; visual size is unchanged.
func _inflate_rect(p_rect: Rect2, p_min_px: float) -> Rect2:
	var deficit_w := maxf(0.0, p_min_px - p_rect.size.x)
	var deficit_h := maxf(0.0, p_min_px - p_rect.size.y)
	var out := p_rect
	out.position.x -= deficit_w / 2.0
	out.position.y -= deficit_h / 2.0
	out.size.x += deficit_w
	out.size.y += deficit_h
	return out


## F-3: swipe release velocity in dp/s using the oldest retained sample
## (maximises delta_t). EC-5: delta_t <= 0 is assumed to be a swipe.
func _swipe_velocity_dp_s() -> float:
	var delta_px := _last_pos - _swipe_sample_pos
	var delta_t := (_now_ms() - _swipe_sample_time_ms) / 1000.0
	if delta_t <= 0.0:
		_warn("swipe velocity delta_t <= 0 (same-timestamp release) — assuming swipe fires (EC-5)")
		return SWIPE_MIN_VELOCITY_DP_S + 1.0
	var velocity_px_s := delta_px.length() / delta_t
	return velocity_px_s / pixels_per_dp


## F-4: classify the full gesture arc into cardinal directions using 45-degree
## sectors; ties resolve deterministically to the lower-numbered enum value.
func _classify_swipe_direction(p_delta_px: Vector2) -> GameEnums.SwipeDirection:
	var angle_deg := rad_to_deg(atan2(-p_delta_px.y, p_delta_px.x))
	if angle_deg > -45.0 and angle_deg <= 45.0:
		return GameEnums.SwipeDirection.RIGHT
	if angle_deg > 45.0 and angle_deg <= 135.0:
		return GameEnums.SwipeDirection.UP
	if angle_deg > 135.0 or angle_deg <= -135.0:
		return GameEnums.SwipeDirection.LEFT
	return GameEnums.SwipeDirection.DOWN


## F-5: debounce proximity — both conditions must hold to discard a new touch.
func _debounce_rejects(p_position: Vector2) -> bool:
	var elapsed := _now_ms() - _last_touch_end_time_ms
	if elapsed >= DEBOUNCE_INTERVAL_MS:
		return false
	return _distance_dp(p_position, _last_touch_end_pos) <= DEBOUNCE_MAX_DIST_DP


func _distance_dp(a: Vector2, b: Vector2) -> float:
	return a.distance_to(b) / pixels_per_dp


func _reset_gesture(p_release_pos: Vector2) -> void:
	_last_touch_end_time_ms = _now_ms()
	_last_touch_end_pos = p_release_pos
	_state = STATE_IDLE
	_in_swipe_tracking = false
	_long_press_target = null


func _now_ms() -> int:
	return int(_time_source.call())


## R3 discipline: handled-mark ONLY for events consumed by a registered
## target. The viewport guard keeps off-tree test instances safe.
func _mark_handled() -> void:
	_handled_count += 1
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _warn(p_message: String) -> void:
	var msg := "MTF: " + p_message
	if OS.is_debug_build():
		push_warning(msg)
	_warnings.append(msg)


func _control_path(p_control: Control) -> String:
	return p_control.get_path() if p_control.is_inside_tree() else p_control.name


# --- debug / test hooks ---------------------------------------------------

func get_state() -> int:
	return _state


func get_state_name() -> String:
	match _state:
		STATE_IDLE:
			return "IDLE"
		STATE_TOUCH_DOWN:
			return "TOUCH_DOWN"
		STATE_LONG_PRESS_PENDING:
			return "LONG_PRESS_PENDING"
		STATE_SWIPE_TRACKING:
			return "SWIPE_TRACKING"
		_:
			return "RESOLVING"


## Last N runtime warnings (DPI fallback, inflation, registry limit, R3
## velocity assumption...). Test/debug visibility — not a public contract.
func get_warnings() -> PackedStringArray:
	return _warnings.duplicate()


## Number of confirmed-tap haptic pulses emitted (Rule 12 audit hook).
func get_haptic_pulse_count() -> int:
	return _haptic_pulses


## Number of events marked handled (R3 mitigation audit hook: must equal the
## count of consumed gestures, never misses/dead-bands/discards).
func get_handled_count() -> int:
	return _handled_count


func get_registered_count() -> int:
	return _registry.size()


func get_blocking_layer_count() -> int:
	return _blocking_layers.size()


func has_blocking_layer(layer_id: StringName) -> bool:
	return _find_layer(layer_id) != -1