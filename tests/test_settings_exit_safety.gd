extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	root.size = Vector2i(1600, 900)
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "settings safety test should load the main scene")
	if scene != null:
		var game_root := scene.instantiate()
		root.add_child(game_root)
		game_root._locale.set_locale("zh")
		game_root.new_game()
		game_root._skip_prologue()
		await process_frame

		var rail := _find_node_by_name(game_root, "InternationalHUDRail") as Control
		var settings := _find_node_by_name(game_root, "SettingsWindow") as Control
		var settings_scroll := _find_node_by_name(game_root, "SettingsScroll") as ScrollContainer
		var settings_footer := _find_node_by_name(game_root, "SettingsSystemFooter") as Control
		var settings_exit := _find_node_by_name(game_root, "SettingsExitGameButton") as Button
		var volume_label := _find_node_by_name(game_root, "SettingsVolumeLabel") as Label
		var volume_slider := _find_node_by_name(game_root, "SettingsVolumeSlider") as HSlider

		_assert_true(rail != null, "gameplay should retain the collapsible HUD drawer")
		_assert_true(_find_node_by_name(rail, "ExitGameButton") == null, "the HUD drawer must not contain an exit command")
		_assert_true(settings != null, "gameplay should expose a settings window")
		_assert_true(settings_scroll != null, "long settings should use a scrollable body")
		_assert_true(settings_footer != null, "reliable system commands should use a fixed settings footer")
		_assert_true(settings_exit != null, "settings should contain the in-game exit command")
		if settings != null and settings_exit != null:
			_assert_true(settings.is_ancestor_of(settings_exit), "the exit command should belong to SettingsWindow")
			_assert_true(settings_scroll == null or not settings_scroll.is_ancestor_of(settings_exit), "the exit command should stay fixed instead of scrolling out of reach")
			_assert_eq(settings_exit.text, "退出游戏", "the exit command should remain readable")

		game_root._toggle_settings_window()
		_assert_true(settings != null and settings.visible, "the settings icon should open the settings window")
		if settings != null and settings_exit != null:
			_assert_true(settings.get_global_rect().encloses(settings_exit.get_global_rect()), "the exit command should remain inside the settings window")
			_assert_true(
				settings.get_global_rect().end.y <= root.size.y + 1.0,
				"the settings window should keep the exit command inside the viewport (settings=%s, viewport=%s)" % [settings.get_global_rect(), root.size]
			)
		if settings_exit != null:
			settings_exit.pressed.emit()
		var confirmation := _find_node_by_name(game_root, "DialogLayer") as Control
		var message := _find_node_by_name(confirmation, "DialogMessage") as Label
		_assert_true(confirmation != null and confirmation.visible, "requesting exit should show one confirmation layer")
		_assert_true(message != null and message.text == "真的要抛弃我吗？", "the exit confirmation should use the requested sentence")

		_press_escape()
		_assert_true(confirmation != null and not confirmation.visible, "Escape should close the exit confirmation")
		game_root._request_quit_game()
		_assert_true(confirmation != null and confirmation.visible, "a later exit request should still show the same single confirmation layer")
		var return_button := _find_node_by_name(confirmation, "DialogButton0") as Button
		_assert_true(return_button != null and return_button.text == "返回", "the dialog should keep the safe 返回 command")
		if return_button != null:
			return_button.pressed.emit()
		_assert_true(confirmation != null and not confirmation.visible, "返回 should close the exit confirmation")

		game_root.game.pollution = 100
		game_root._render_status()
		_assert_true(volume_label != null and not volume_label.text.is_empty(), "pollution may rename volume but must leave a readable control label")
		_assert_true(volume_slider != null and volume_slider.visible and volume_slider.editable, "volume must remain adjustable at maximum pollution")
		if volume_slider != null:
			volume_slider.value = 37.0
			_assert_true(is_equal_approx(volume_slider.value, 37.0), "the volume slider should still accept values at maximum pollution")

		game_root.queue_free()
		await process_frame

	if _failures.is_empty():
		print("settings exit safety tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _press_escape() -> void:
	for pressed in [true, false]:
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.physical_keycode = KEY_ESCAPE
		escape.pressed = pressed
		root.push_input(escape)


func _find_node_by_name(node: Node, target_name: String) -> Node:
	if node == null:
		return null
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found := _find_node_by_name(child, target_name)
		if found != null:
			return found
	return null


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
