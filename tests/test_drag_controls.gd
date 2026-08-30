extends SceneTree

var _failures: Array[String] = []
var _ring_selection_events: Array[int] = []


func _init() -> void:
	_run_and_finish.call_deferred()


func _run_and_finish() -> void:
	_run()
	if _failures.is_empty():
		print("drag control tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	var drag_script := load("res://framework/ui/draggable_button.gd") as Script
	var drop_script := load("res://framework/ui/drop_button.gd") as Script
	var ring_script := load("res://framework/ui/radial_selector_ring.gd") as Script
	var manager_script := load("res://framework/ui/draggable_window_manager.gd") as Script
	_assert_true(drag_script != null, "draggable button script should exist")
	_assert_true(drop_script != null, "drop button script should exist")
	_assert_true(ring_script != null, "radial selector ring script should exist")
	if drag_script == null or drop_script == null or ring_script == null:
		return
	var drag: Button = drag_script.new()
	drag.set_drag_payload("token", "n1", "哈吉米")
	var payload: Variant = drag._get_drag_data(Vector2.ZERO)
	_assert_eq(payload.get("kind", ""), "token", "drag payload should expose kind")
	_assert_eq(payload.get("id", ""), "n1", "drag payload should expose id")

	var drop: Button = drop_script.new()
	drop.configure_drop_target("token", "target")
	var accepted: bool = drop._can_drop_data(Vector2.ZERO, payload)
	var rejected: bool = drop._can_drop_data(Vector2.ZERO, {"kind": "meme", "id": "m1"})
	_assert_true(accepted, "drop target should accept matching drag kind")
	_assert_true(not rejected, "drop target should reject mismatched drag kind")
	drag.free()
	drop.free()
	_test_radial_selector_ring(ring_script)
	_test_draggable_window_manager(manager_script)


func _test_radial_selector_ring(ring_script: Script) -> void:
	var ring = ring_script.new()
	ring.name = "RadialSelectorRingTest"
	ring.size = Vector2(900.0, 600.0)
	for index in 4:
		var item := Control.new()
		item.name = "Item%d" % index
		item.custom_minimum_size = Vector2(134.0, 54.0)
		ring.add_child(item)
	get_root().add_child(ring)
	ring.call("_layout_ring_items")

	var motion_profile: Dictionary = ring.get_motion_profile()
	var motion_properties: Array = motion_profile.get("properties", [])
	_assert_true(float(motion_profile.get("duration", 0.0)) > 0.0, "ring motion profile should expose a positive duration")
	_assert_eq(motion_profile.get("transition"), Tween.TRANS_QUINT, "ring motion should use quint transition")
	_assert_eq(motion_profile.get("ease"), Tween.EASE_OUT, "ring motion should ease out")
	_assert_true(bool(motion_profile.get("interrupts_previous", false)), "ring motion profile should declare tween interruption")
	_assert_true("position" in motion_properties, "ring motion profile should expose position animation")
	_assert_true("scale" in motion_properties, "ring motion profile should expose scale animation")
	_assert_true("modulate:a" in motion_properties, "ring motion profile should expose opacity animation")

	_ring_selection_events.clear()
	ring.selection_changed.connect(_on_ring_selection_changed)
	var wheel_down := InputEventMouseButton.new()
	wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_down.pressed = true
	_assert_true(ring.handle_navigation_event(wheel_down), "mouse wheel should step radial selection")
	_assert_eq(ring.selected_index, 1, "mouse wheel should select the next radial item")
	ring.call("_layout_ring_items")
	var first_tween := ring.get("_motion_tween") as Tween
	_assert_true(first_tween != null and first_tween.is_valid(), "selection change should start a motion tween")

	var pan := InputEventPanGesture.new()
	pan.delta = Vector2(0.0, 0.75)
	_assert_true(not ring.handle_navigation_event(pan), "small pan gesture should accumulate before selecting")
	pan.delta = Vector2(0.0, 0.75)
	_assert_true(ring.handle_navigation_event(pan), "accumulated pan gesture should step radial selection")
	_assert_eq(ring.selected_index, 2, "pan gesture should select the next radial item")
	if first_tween != null:
		_assert_true(not first_tween.is_valid(), "new selection should terminate the previous tween")
	ring.call("_layout_ring_items")
	var second_tween := ring.get("_motion_tween") as Tween
	_assert_true(second_tween != null and second_tween.is_valid(), "latest selection should own the active tween")

	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.pressed = true
	_assert_true(ring.handle_navigation_event(wheel_up), "reverse mouse wheel should step radial selection")
	_assert_eq(ring.selected_index, 1, "reverse mouse wheel should select the previous radial item")
	_assert_eq(_ring_selection_events, [1, 2, 1], "ring navigation should emit each selected index")
	if second_tween != null:
		_assert_true(not second_tween.is_valid(), "subsequent selection should terminate the active tween")
	ring.free()


func _test_draggable_window_manager(manager_script: Script) -> void:
	_assert_true(manager_script != null, "draggable window manager script should exist")
	if manager_script == null:
		return
	var manager = manager_script.new()
	get_root().add_child(manager)
	var window := ColorRect.new()
	window.size = Vector2(200.0, 120.0)
	window.position = Vector2(40.0, 30.0)
	get_root().add_child(window)
	var handle := Control.new()
	handle.size = Vector2(200.0, 24.0)
	window.add_child(handle)
	manager.register(window, "panel", handle)
	_assert_true(manager.move_window("panel", Vector2(12.0, 8.0)), "move_window should shift a registered window")
	_assert_eq(manager.get_window_position("panel"), Vector2(52.0, 38.0), "get_window_position should match the moved position")
	_assert_eq(manager.get_window_position("missing"), manager.MISSING_WINDOW_POSITION, "unknown ids should return the missing-window sentinel")
	_assert_true(not manager.move_window("missing", Vector2.ONE), "move_window should reject unknown ids")
	# Per-id min_x merges with hang-off-screen allowance instead of replacing it.
	window.position = Vector2(-80.0, 10.0)
	manager.set_window_min_x("panel", 40.0)
	manager.move_window("panel", Vector2.ZERO)
	_assert_true(window.position.x >= 40.0, "per-id min_x should raise the left clamp")
	manager.set_window_min_x("panel", -200.0)
	window.position = Vector2(-80.0, 10.0)
	manager.move_window("panel", Vector2.ZERO)
	_assert_true(window.position.x < 0.0, "a low per-id min_x should still allow partial off-screen hang")
	var released: Array[String] = []
	manager.window_drag_released.connect(func(window_id: String) -> void: released.append(window_id))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.global_position = Vector2(50.0, 40.0)
	handle.gui_input.emit(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.global_position = Vector2(50.0, 40.0)
	handle.gui_input.emit(release)
	_assert_eq(released, ["panel"], "releasing a drag should emit window_drag_released")
	manager.enabled = false
	released.clear()
	handle.gui_input.emit(press)
	handle.gui_input.emit(release)
	_assert_eq(released, [], "a disabled manager should ignore handle input")
	window.queue_free()
	manager.queue_free()


func _on_ring_selection_changed(index: int) -> void:
	_ring_selection_events.append(index)


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s. Expected %s, got %s" % [message, str(expected), str(actual)])
