extends SceneTree
## SettingsHistoryPanel settings shell: named chrome, layout, camera slot. No game-handler wiring.

const PanelScript = preload("res://scripts/ui/settings_history_panel.gd")

var _failures: Array[String] = []
var _registered: Array = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _run()
	if _failures.is_empty():
		print("settings history panel tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	var host := Control.new()
	host.name = "SettingsHost"
	host.size = Vector2(1600, 900)
	root.add_child(host)

	var panel = PanelScript.new()
	panel.name = "SettingsHistoryPanel"
	root.add_child(panel)
	panel.mount(host, {
		"panel_factory": _panel,
		"label_factory": _label,
		"soft_style": _soft_style,
		"theme_color": _theme_color,
		"ui_font_size": _ui_font_size,
		"register_draggable": _register_draggable,
		"master_volume": 80.0,
		"vhs_enabled": true,
		"autoplay_enabled": false,
		"locales": [
			{"code": "zh", "name": "中文"},
			{"code": "en", "name": "English"},
		],
		"current_locale": "zh",
	})
	await process_frame

	var settings := panel.get_settings_window() as Control
	_assert_true(settings != null, "mount should expose the settings window")
	_assert_true(settings != null and settings.name == "SettingsWindow", "settings window should keep the test node name")
	_assert_true(settings != null and not settings.visible, "settings window should start closed")

	var settings_scroll := _find_node_by_name(settings, "SettingsScroll") as ScrollContainer
	var settings_footer := _find_node_by_name(settings, "SettingsSystemFooter") as Control
	var settings_exit := _find_node_by_name(settings, "SettingsExitGameButton") as Button
	var volume_label := _find_node_by_name(settings, "SettingsVolumeLabel") as Label
	var volume_slider := _find_node_by_name(settings, "SettingsVolumeSlider") as HSlider
	var vhs_toggle := _find_node_by_name(settings, "SettingsVHSToggle") as CheckButton
	var language_option := _find_node_by_name(settings, "SettingsLanguageOption") as OptionButton
	var save_button := _find_node_by_name(settings, "SettingsManualSaveButton") as Button
	var autoplay_button := _find_node_by_name(settings, "SettingsAutoplayButton") as CheckButton
	var history_button := _find_node_by_name(settings, "SettingsHistoryButton") as Button
	var camera_slot := panel.get_camera_slot() as Control

	_assert_true(settings_scroll != null, "settings should use a named scroll body")
	_assert_true(settings_footer != null, "settings should keep a fixed system footer")
	_assert_true(settings_exit != null, "settings should contain SettingsExitGameButton")
	_assert_true(volume_label != null, "settings should contain SettingsVolumeLabel")
	_assert_true(volume_slider != null, "settings should contain SettingsVolumeSlider")
	_assert_true(vhs_toggle != null, "settings should contain the VHS toggle")
	_assert_true(language_option != null, "settings should contain the language option")
	_assert_true(save_button != null, "settings should contain the save button")
	_assert_true(autoplay_button != null, "settings should contain the autoplay button")
	_assert_true(history_button != null, "settings should contain the history button")
	_assert_true(camera_slot != null, "settings should expose a camera slot for the adapter")
	if camera_slot != null:
		_assert_true(camera_slot.get_child_count() == 0, "camera slot should start empty so the adapter can inject the camera block")
		_assert_true(settings_scroll == null or settings_scroll.is_ancestor_of(camera_slot), "camera slot should live in the scroll body")

	if settings != null and settings_exit != null:
		_assert_true(settings.is_ancestor_of(settings_exit), "the exit command should belong to SettingsWindow")
		_assert_true(settings_scroll == null or not settings_scroll.is_ancestor_of(settings_exit), "the exit command should stay fixed instead of scrolling out of reach")
		_assert_eq(settings_exit.text, "退出游戏", "the exit command should remain readable")
		_assert_true(settings_exit.pressed.get_connections().is_empty(), "slice 2 should not wire the exit button to a game handler")

	if volume_slider != null:
		_assert_true(volume_slider.editable, "volume slider should remain adjustable")
		_assert_true(is_equal_approx(volume_slider.value, 80.0), "volume slider should take the snapshot value")
		_assert_true(volume_slider.value_changed.get_connections().is_empty(), "slice 2 should not wire the volume slider to a game handler")

	if language_option != null:
		_assert_eq(language_option.item_count, 2, "language option should list the snapshot locales")
		_assert_true(language_option.item_selected.get_connections().is_empty(), "slice 2 should not wire language selection to a game handler")

	var settings_regs := 0
	for entry in _registered:
		if str(entry.get("id", "")) == "settings":
			settings_regs += 1
	_assert_true(settings_regs >= 1, "settings window should register with DraggableWindowManager")

	panel.layout_settings(Vector2(1600, 900))
	if settings != null:
		_assert_true(settings.position == Vector2(180, 16), "1600x900 settings layout should keep the default origin")
		_assert_true(settings.size == Vector2(430, 868), "1600x900 settings layout should use the capped window size")

	var history := _find_node_by_name(host, "HistoryWindow") as Control
	_assert_true(history != null, "mount should still build the history window")

	host.queue_free()
	panel.queue_free()
	await process_frame


func _panel() -> PanelContainer:
	return PanelContainer.new()


func _label(text: String, _size: int, _color: Color) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _soft_style(_bg: Color, _border: Color) -> StyleBoxFlat:
	return StyleBoxFlat.new()


func _theme_color(_key: String) -> Color:
	return Color.WHITE


func _ui_font_size(requested: int) -> int:
	return requested


func _register_draggable(window: Control, window_id: String, handle: Control) -> void:
	_registered.append({
		"window": window,
		"id": window_id,
		"handle": handle,
	})


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
