extends SceneTree

var _failures: Array[String] = []


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
	var manager_script := load("res://framework/ui/draggable_window_manager.gd") as Script
	_assert_true(drag_script != null, "draggable button script should exist")
	_assert_true(drop_script != null, "drop button script should exist")
	if drag_script == null or drop_script == null:
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
	_test_drag_preview_takes_the_set_color(drag_script)
	_test_draggable_window_manager(manager_script)


func _test_drag_preview_takes_the_set_color(drag_script: Script) -> void:
	var drag := drag_script.new() as DraggableButton
	drag.set_drag_payload("token", "n1", "哈吉米")
	drag.drag_preview_color = Color("2F6B1F")
	var preview := drag.build_drag_preview()
	_assert_eq(preview.text, "哈吉米", "the drag preview should show the drag label")
	_assert_eq(preview.get_theme_color("font_color"), Color("2F6B1F"), "the drag preview should use the color the caller set")
	preview.free()
	drag.free()


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
	var disabled_pos: Vector2 = window.position
	_assert_true(not manager.move_window("panel", Vector2(20.0, 0.0)), "a disabled manager should refuse move_window")
	_assert_eq(window.position, disabled_pos, "a disabled manager should not move windows")
	window.queue_free()
	manager.queue_free()


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s. Expected %s, got %s" % [message, str(expected), str(actual)])
