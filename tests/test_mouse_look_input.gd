extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	root.visible = false
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1600, 900)
	var main = load("res://scenes/babel_meme_game.tscn").instantiate()
	root.add_child(main)
	for route in ["chapter", "legacy"]:
		if route == "chapter":
			main.start_chapter1_game()
		else:
			main.new_game()
			main._skip_prologue()
			main.set_view_state("npc_up")
		await process_frame
		await process_frame
		_check(main._reality_mouse_look_enabled, route + ": entering reality captures the mouse")
		var yaw_before: float = main._reality_yaw
		var pitch_before: float = main._reality_pitch
		var camera_rotation_before: Vector3 = main._camera.rotation
		var actions_before: int = main.game.actions_remaining
		_move_mouse(Vector2(96.0, 32.0))
		_check(not is_equal_approx(main._reality_yaw, yaw_before), route + ": viewport mouse motion turns the camera horizontally")
		_check(not is_equal_approx(main._reality_pitch, pitch_before), route + ": viewport mouse motion tilts the camera vertically")
		_check(main.game.actions_remaining == actions_before, route + ": looking does not spend actions")
		await process_frame
		await process_frame
		_check(not main._camera.rotation.is_equal_approx(camera_rotation_before), route + ": mouse input reaches the actual camera")
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		root.push_input(escape, true)
		_check(main._settings_open and not main._reality_mouse_look_enabled, route + ": Escape opens settings and releases the mouse")
		yaw_before = main._reality_yaw
		_move_mouse(Vector2(64.0, 0.0))
		_check(is_equal_approx(main._reality_yaw, yaw_before), route + ": released mouse cannot turn the camera")
		_click(Vector2(800.0, 450.0))
		_check(not main._reality_mouse_look_enabled, route + ": clicking behind settings cannot capture the mouse")
		root.push_input(escape, true)
		_check(not main._settings_open and main._reality_mouse_look_enabled, route + ": closing settings resumes mouse look")
		main._set_reality_mouse_look(false)
		_click(Vector2(800.0, 450.0))
		_check(main._reality_mouse_look_enabled, route + ": clicking the world recaptures a released mouse")
		_move_mouse(Vector2(64.0, 0.0))
		_check(not is_equal_approx(main._reality_yaw, yaw_before), route + ": mouse look resumes after recapture")
		if route == "chapter":
			var settings_key := InputEventKey.new()
			settings_key.keycode = KEY_F10
			settings_key.pressed = true
			root.push_input(settings_key, true)
			await process_frame
			_check(main._settings_open and not main._reality_mouse_look_enabled, "chapter: settings releases the mouse")
			yaw_before = main._reality_yaw
			_click(Vector2(1500.0, 780.0))
			_check(not main._reality_mouse_look_enabled, "chapter: clicking outside settings keeps the cursor available to the menu")
			_move_mouse(Vector2(64.0, 0.0))
			_check(is_equal_approx(main._reality_yaw, yaw_before), "chapter: moving the settings cursor does not turn the camera")
			var close := main._settings_window.find_child("SettingsCloseButton", true, false) as Button
			_click(close.get_global_rect().get_center())
			_check(not main._settings_open, "chapter: settings buttons still receive clicks")
			_check(main._reality_mouse_look_enabled, "chapter: closing settings resumes mouse look")
			_click(Vector2(800.0, 450.0))
			_check(main._reality_mouse_look_enabled, "chapter: world click resumes mouse look after closing settings")
		else:
			main._set_reality_mouse_look(false)
			_click(main._view_toggle_button.get_global_rect().get_center())
			_check(main.game.view_state == "phone_down", "legacy: phone button still receives clicks through the UI root")
			_check(not main._reality_mouse_look_enabled, "legacy: phone UI releases the mouse")
			yaw_before = main._reality_yaw
			_move_mouse(Vector2(64.0, 0.0))
			_check(is_equal_approx(main._reality_yaw, yaw_before), "legacy: phone UI mouse motion does not turn the camera")
	main._set_reality_mouse_look(false)
	main.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("mouse look input tests passed")
	quit(0 if failures.is_empty() else 1)


func _move_mouse(delta: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(800.0, 450.0)
	motion.global_position = motion.position
	motion.relative = delta
	root.push_input(motion, true)


func _click(position: Vector2) -> void:
	var click := InputEventMouseButton.new()
	click.position = position
	click.global_position = position
	click.button_index = MOUSE_BUTTON_LEFT
	click.button_mask = MOUSE_BUTTON_MASK_LEFT
	click.pressed = true
	root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	click.button_mask = 0
	root.push_input(click, true)


func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
