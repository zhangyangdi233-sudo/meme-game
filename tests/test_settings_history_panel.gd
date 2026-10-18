extends SceneTree
## SettingsHistoryPanel: chrome plus intent signals and settings open/close state.

const PanelScript = preload("res://scripts/ui/settings_history_panel.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const BootScript = preload("res://scripts/game/property_boot.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const ScreenManagerScript = preload("res://scripts/ui/screen_manager.gd")
const DialogScreenScript = preload("res://scripts/ui/dialog_screen.gd")

var _failures: Array[String] = []
var _registered: Array = []
var _volume_events: Array = []
var _vhs_events: Array = []
var _autoplay_events: Array = []
var _language_events: Array = []
var _save_events: Array = []
var _return_events: Array = []
var _exit_events: Array = []
var _history_toggle_events: Array = []
var _exit_confirmed_events: Array = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _run()
	if _failures.is_empty():
		print("settings history panel tests passed")
		RegistryScript.clear()
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		RegistryScript.clear()
		quit(1)


func _on_intent(intent_name: String, payload: Dictionary) -> void:
	match intent_name:
		UiIntentsScript.VOLUME_CHANGED:
			_volume_events.append(payload.get(UiIntentsScript.KEY_VALUE))
		UiIntentsScript.VHS_TOGGLED:
			_vhs_events.append(payload.get(UiIntentsScript.KEY_VALUE))
		UiIntentsScript.AUTOPLAY_TOGGLED:
			_autoplay_events.append(payload.get(UiIntentsScript.KEY_VALUE))
		UiIntentsScript.LANGUAGE_SELECTED:
			_language_events.append(payload.get(UiIntentsScript.KEY_LOCALE))
		UiIntentsScript.MANUAL_SAVE_PRESSED:
			_save_events.append(true)
		UiIntentsScript.RETURN_MAIN_MENU_PRESSED:
			_return_events.append(true)
		UiIntentsScript.EXIT_GAME_REQUESTED:
			_exit_events.append(true)
		UiIntentsScript.HISTORY_TOGGLE_REQUESTED:
			_history_toggle_events.append(true)
		UiIntentsScript.EXIT_CONFIRMED:
			_exit_confirmed_events.append(payload)


func _run() -> void:
	RegistryScript.clear()
	BootScript.install()
	var host := Control.new()
	host.name = "SettingsHost"
	host.size = Vector2(1600, 900)
	root.add_child(host)

	var panel = PanelScript.new()
	panel.name = "SettingsHistoryPanel"
	root.add_child(panel)
	RegistryScript.bind(ServiceKeysScript.UI_THEME, GameUiThemeScript.new())
	panel.mount(host, {
		"register_draggable": _register_draggable,
		"vhs_enabled": true,
		"locales": [
			{"code": "zh", "name": "中文"},
			{"code": "en", "name": "English"},
		],
	})
	var bus: GameEventBus = GameEventBusScript.new()
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, bus)
	bus.intent_emitted.connect(_on_intent)
	_assert_true(not panel.has_signal("settings_open_changed"), "the panel should not keep a private signal for the open flag; the model is the only channel")
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

	if volume_slider != null:
		_assert_true(volume_slider.editable, "volume slider should remain adjustable")

	if language_option != null:
		_assert_eq(language_option.item_count, 2, "language option should list the snapshot locales")

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

	var open_model := _model(PropertyKeysScript.SETTINGS_OPEN)
	_assert_true(not bool(open_model.read()), "settings should start closed")
	panel.toggle_settings()
	_assert_true(bool(open_model.read()), "toggle_settings should write the open model")
	_assert_true(settings != null and settings.visible, "toggle_settings should show the settings window")
	panel.close_settings()
	_assert_true(not bool(open_model.read()), "close_settings should write the open model closed")
	_assert_true(settings != null and not settings.visible, "close_settings should hide the settings window")
	panel.toggle_settings()
	var close_button := _find_node_by_name(settings, "SettingsCloseButton") as Button
	if close_button != null:
		close_button.pressed.emit()
	_assert_true(not bool(open_model.read()), "the settings close button should close the window")
	open_model.write(true)
	_assert_true(settings != null and settings.visible, "writing the open model should show the window by itself")
	open_model.write(false)
	_assert_true(settings != null and not settings.visible, "writing the open model closed should hide the window")

	if volume_slider != null:
		volume_slider.value = 42.0
		_assert_eq(_volume_events.size(), 1, "adjusting volume should emit volume_changed once")
		_assert_true(_volume_events.size() == 1 and is_equal_approx(float(_volume_events[0]), 42.0), "volume_changed should carry the slider value")
	if vhs_toggle != null:
		vhs_toggle.toggled.emit(false)
		_assert_eq(_vhs_events, [false], "the VHS toggle should emit vhs_toggled")
	if autoplay_button != null:
		autoplay_button.toggled.emit(true)
		_assert_eq(_autoplay_events, [true], "the autoplay toggle should emit autoplay_toggled")
	if language_option != null:
		language_option.item_selected.emit(1)
		_assert_eq(_language_events, ["en"], "language selection should emit the locale code, not the index")
	if save_button != null:
		save_button.pressed.emit()
		_assert_eq(_save_events, [true], "the save button should emit manual_save_pressed")
	var return_main := _find_node_by_name(settings, "SettingsReturnMainButton") as Button
	if return_main != null:
		return_main.pressed.emit()
		_assert_eq(_return_events, [true], "the return-main button should emit return_main_menu_pressed")
	if settings_exit != null:
		settings_exit.pressed.emit()
		_assert_eq(_exit_events, [true], "the exit button should emit exit_game_requested")
	if history_button != null:
		history_button.pressed.emit()
		_assert_eq(_history_toggle_events, [true], "the history button should emit history_toggle_requested")
		_assert_true(history != null and not history.visible, "history toggle intent alone should not open the window; the host calls toggle()")

	_test_open_settings_follow_the_models(panel, volume_slider, autoplay_button, language_option)
	_test_history_window_follows_the_model(panel, host)

	_test_labels_follow_pollution(panel, volume_label, autoplay_button, volume_slider)
	_test_save_status_follows_the_model(panel, settings)

	_test_exit_request_opens_the_dialog(panel, host, bus)

	host.queue_free()
	panel.queue_free()
	await process_frame


func _test_open_settings_follow_the_models(panel: SettingsHistoryPanel, volume_slider: HSlider, autoplay_button: CheckButton, language_option: OptionButton) -> void:
	if volume_slider == null or autoplay_button == null or language_option == null:
		_failures.append("settings controls should exist before checking the models")
		return
	var volume := _model(PropertyKeysScript.MASTER_VOLUME)
	var autoplay := _model(PropertyKeysScript.AUTOPLAY_ENABLED)
	var locale := _model(PropertyKeysScript.LOCALE)
	volume.write(30.0)
	autoplay.write(true)
	locale.write("en")
	var events_before := _volume_events.size() + _autoplay_events.size() + _language_events.size()

	panel.set_settings_open(true)
	_assert_true(is_equal_approx(volume_slider.value, 30.0), "opening settings should sync the volume model")
	_assert_true(autoplay_button.button_pressed, "opening settings should sync the autoplay model")
	_assert_eq(str(language_option.get_selected_metadata()), "en", "opening settings should select the language model")

	volume.write(12.0)
	autoplay.write(false)
	locale.write("zh")
	_assert_true(is_equal_approx(volume_slider.value, 12.0), "open settings should follow volume writes")
	_assert_true(not autoplay_button.button_pressed, "open settings should follow autoplay writes")
	_assert_eq(str(language_option.get_selected_metadata()), "zh", "open settings should follow language writes")
	_assert_eq(_volume_events.size() + _autoplay_events.size() + _language_events.size(), events_before, "syncing from a model should not echo an intent back")

	panel.close_settings()
	volume.write(90.0)
	autoplay.write(true)
	locale.write("en")
	_assert_true(is_equal_approx(volume_slider.value, 12.0), "closed settings should stop receiving volume")
	_assert_true(not autoplay_button.button_pressed, "closed settings should stop receiving autoplay")
	_assert_eq(str(language_option.get_selected_metadata()), "zh", "closed settings should stop receiving the language")

	panel.set_settings_open(true)
	_assert_true(is_equal_approx(volume_slider.value, 90.0), "reopening settings should sync again")
	panel.close_settings()
	autoplay.write(false)
	locale.write("zh")


func _test_labels_follow_pollution(panel: SettingsHistoryPanel, volume_label: Label, autoplay_button: CheckButton, volume_slider: HSlider) -> void:
	var pollution := _model(PropertyKeysScript.POLLUTION)
	pollution.write(0)
	_assert_eq(volume_label.text, "音量", "clean pollution should keep the default volume label")
	pollution.write(30)
	_assert_eq(volume_label.text, "外面的声音", "even closed settings should follow pollution so reopening is never stale")
	pollution.write(0)
	panel.set_settings_open(true)
	_assert_eq(volume_label.text, "音量", "an open window should show the current pollution")
	pollution.write(30)
	_assert_eq(volume_label.text, "外面的声音", "mid pollution should rename the volume label by itself")
	_assert_eq(autoplay_button.text, "让我替你继续说", "mid pollution should rename the autoplay label by itself")
	pollution.write(100)
	_assert_eq(volume_label.text, "它离你有多近", "max pollution should use the corrupted volume label")
	_assert_true(volume_slider.editable, "max pollution must keep the volume slider adjustable")
	panel.close_settings()
	pollution.write(0)
	_assert_eq(volume_label.text, "音量", "closed settings should keep following pollution")


func _test_save_status_follows_the_model(panel: SettingsHistoryPanel, settings: Control) -> void:
	var status := _find_node_by_name(settings, "SettingsSaveStatus") as Label
	var model := _model(PropertyKeysScript.SAVE_STATUS)
	panel.set_settings_open(true)
	_assert_eq(status.text, "", "the status should start empty")
	model.write("已保存")
	_assert_eq(status.text, "已保存", "an open settings window should show the new status by itself")
	panel.close_settings()
	model.write("失败")
	_assert_eq(status.text, "已保存", "closed settings should stop receiving the status")
	panel.set_settings_open(true)
	_assert_eq(status.text, "失败", "reopening settings should show the current status")
	panel.close_settings()
	model.write("")


func _test_history_window_follows_the_model(panel: SettingsHistoryPanel, host: Control) -> void:
	var history := _find_node_by_name(host, "HistoryWindow") as Control
	var entries := RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER).model(PropertyKeysScript.HISTORY_ENTRIES) as ListPropertyModel
	entries.add(_line("L1", "first"))
	_assert_eq(entries.changed.get_connections().size(), 0, "a closed history window should not listen")
	_assert_true(_find_node_by_name(history, "HistoryEntry0") == null, "a closed history window should not paint")

	panel.toggle()
	_assert_true(history.visible, "toggle should show the history window")
	_assert_eq(entries.changed.get_connections().size(), 1, "an open history window should listen once")
	_assert_true(_find_node_by_name(history, "HistoryEntry0") != null, "opening should paint the lines already recorded")
	entries.add(_line("L2", "second"))
	_assert_true(_find_node_by_name(history, "HistoryEntry1") != null, "a new line should appear in the open window by itself")

	panel.toggle()
	_assert_true(not history.visible, "a second toggle should hide the window")
	_assert_eq(entries.changed.get_connections().size(), 0, "a hidden history window should let go of the model")
	panel.toggle()
	panel.close()
	_assert_eq(entries.changed.get_connections().size(), 0, "close should let go of the model")
	entries.reset()


func _line(line_id: String, text: String) -> Dictionary:
	return {"lineId": line_id, "originalSpeaker": "A", "currentSpeaker": "A", "originalText": text, "displayText": text, "revisionStage": 0, "revisionMarkup": ""}


func _model(property_name: String) -> ValuePropertyModel:
	var manager := RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	return manager.model(property_name) as ValuePropertyModel


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


## The exit request opens the shared Dialog: the plea, then 返回 (focused, Escape) and 仍然退出 from left to right.
## Only 仍然退出 raises the exit confirm; the panel builds no confirmation nodes of its own.
func _test_exit_request_opens_the_dialog(panel: SettingsHistoryPanel, host: Control, bus: GameEventBus) -> void:
	var holder := Node.new()
	holder.name = "DialogHolder"
	root.add_child(holder)
	var canvas := CanvasLayer.new()
	holder.add_child(canvas)
	var layer := Control.new()
	layer.name = "UIRoot"
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(layer)
	var dialog_manager: ScreenManager = ScreenManagerScript.new(bus, DialogScreenScript, holder)
	holder.add_child(dialog_manager)
	RegistryScript.bind(ServiceKeysScript.DIALOG, dialog_manager)
	_exit_confirmed_events.clear()

	panel.request_quit()
	var screen := _find_node_by_name(layer, "DialogLayer") as Control
	_assert_true(screen != null and screen.visible, "an exit request should open the dialog")
	var message := _find_node_by_name(screen, "DialogMessage") as Label
	_assert_eq(message.text if message != null else "", "真的要抛弃我吗？", "the dialog should ask the exit plea")
	var buttons := _dialog_buttons(screen)
	_assert_eq(buttons.map(func(button: Button) -> String: return button.text), ["返回", "仍然退出"], "the dialog should offer 返回 then 仍然退出")
	_assert_true(buttons.size() == 2 and root.gui_get_focus_owner() == buttons[0], "返回 should take the first focus")
	_press_escape()
	_assert_true(screen != null and not screen.visible, "Escape should close the exit dialog")
	_assert_eq(_exit_confirmed_events, [], "Escape should not confirm the exit")

	panel.request_quit()
	buttons = _dialog_buttons(screen)
	if buttons.size() == 2:
		buttons[0].pressed.emit()
	_assert_true(screen != null and not screen.visible, "返回 should close the exit dialog")
	_assert_eq(_exit_confirmed_events, [], "返回 should not confirm the exit")

	panel.request_quit()
	buttons = _dialog_buttons(screen)
	if buttons.size() == 2:
		buttons[1].pressed.emit()
	_assert_true(screen != null and not screen.visible, "仍然退出 should close the exit dialog")
	_assert_eq(_exit_confirmed_events, [{}], "仍然退出 should raise one empty exit confirm")

	for node_name in ["ExitConfirmationOverlay", "ExitConfirmationMessage", "ExitConfirmationReturnButton", "ExitConfirmationConfirmButton"]:
		_assert_true(_find_node_by_name(host, node_name) == null and _find_node_by_name(panel, node_name) == null, "the panel should not build %s" % node_name)
	RegistryScript.unbind(ServiceKeysScript.DIALOG, dialog_manager)
	holder.free()


func _dialog_buttons(screen: Node) -> Array[Button]:
	var found: Array[Button] = []
	var row := _find_node_by_name(screen, "DialogButtonRow")
	if row == null:
		return found
	for child in row.get_children():
		if child is Button and not child.is_queued_for_deletion():
			found.append(child as Button)
	return found


func _press_escape() -> void:
	for pressed in [true, false]:
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.physical_keycode = KEY_ESCAPE
		escape.pressed = pressed
		root.push_input(escape)


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
