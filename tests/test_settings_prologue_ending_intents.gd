extends SceneTree
## Settings, HUD settings button, prologue and ending raise their actions on the event bus.

const BootScript = preload("res://scripts/game/property_boot.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const SettingsHistoryPanelScript = preload("res://scripts/ui/settings_history_panel.gd")
const AppleHudPanelScript = preload("res://scripts/ui/apple_hud_panel.gd")
const ProloguePanelScript = preload("res://scripts/ui/prologue_panel.gd")
const EndingScreenPanelScript = preload("res://scripts/ui/ending_screen_panel.gd")

var _failures: Array[String] = []
var _heard: Array = []


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("settings prologue ending intents tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_intent_names_and_payload_keys()
	_test_settings_window_raises_its_actions()
	_test_exit_confirmation_raises_confirmed()
	_test_hud_settings_button_raises_settings_pressed()
	_test_prologue_raises_finished()
	_test_ending_raises_language_choice_and_restart()


func _test_intent_names_and_payload_keys() -> void:
	_assert_eq(UiIntentsScript.VOLUME_CHANGED, "volume_changed", "volume intent name")
	_assert_eq(UiIntentsScript.AUTOPLAY_TOGGLED, "autoplay_toggled", "autoplay intent name")
	_assert_eq(UiIntentsScript.VHS_TOGGLED, "vhs_toggled", "vhs intent name")
	_assert_eq(UiIntentsScript.ENDING_LANGUAGE_SELECTED, "ending_language_selected", "ending language intent name")
	_assert_eq(UiIntentsScript.MANUAL_SAVE_PRESSED, "manual_save_pressed", "manual save intent name")
	_assert_eq(UiIntentsScript.RETURN_MAIN_MENU_PRESSED, "return_main_menu_pressed", "return main menu intent name")
	_assert_eq(UiIntentsScript.EXIT_GAME_REQUESTED, "exit_game_requested", "exit request intent name")
	_assert_eq(UiIntentsScript.EXIT_CONFIRMED, "exit_confirmed", "exit confirmed intent name")
	_assert_eq(UiIntentsScript.HISTORY_TOGGLE_REQUESTED, "history_toggle_requested", "history toggle intent name")
	_assert_eq(UiIntentsScript.SETTINGS_PRESSED, "settings_pressed", "settings pressed intent name")
	_assert_eq(UiIntentsScript.PROLOGUE_FINISHED, "prologue_finished", "prologue finished intent name")
	_assert_eq(UiIntentsScript.RESTART_REQUESTED, "restart_requested", "restart intent name")
	_assert_eq(UiIntentsScript.KEY_VALUE, "value", "value payload key")
	_assert_eq(UiIntentsScript.KEY_CHOICE_ID, "choice_id", "choice id payload key")


func _test_settings_window_raises_its_actions() -> void:
	_bind_bus()
	var host := Control.new()
	host.size = Vector2(1600, 900)
	root.add_child(host)
	var panel := SettingsHistoryPanelScript.new()
	root.add_child(panel)
	panel.mount(host, {
		"panel_factory": func() -> PanelContainer: return PanelContainer.new(),
		"label_factory": _label,
		"soft_style": func(_bg: Color, _border: Color) -> StyleBoxFlat: return StyleBoxFlat.new(),
		"theme_color": _theme_color,
		"ui_font_size": func(_size: int) -> int: return 16,
		"register_draggable": func(_window: Control, _id: String, _handle: Control) -> void: pass,
		"vhs_enabled": true,
		"locales": [{"code": "zh", "name": "中文"}, {"code": "en", "name": "English"}],
	})
	var settings := panel.get_settings_window() as Control

	(settings.find_child("SettingsVolumeSlider", true, false) as HSlider).value_changed.emit(42.0)
	_assert_eq(_heard, [[UiIntentsScript.VOLUME_CHANGED, {UiIntentsScript.KEY_VALUE: 42.0}]], "the slider should raise its value")
	_heard.clear()
	(settings.find_child("SettingsVHSToggle", true, false) as CheckButton).toggled.emit(false)
	_assert_eq(_heard, [[UiIntentsScript.VHS_TOGGLED, {UiIntentsScript.KEY_VALUE: false}]], "the vhs toggle should raise its value")
	_heard.clear()
	(settings.find_child("SettingsAutoplayButton", true, false) as CheckButton).toggled.emit(true)
	_assert_eq(_heard, [[UiIntentsScript.AUTOPLAY_TOGGLED, {UiIntentsScript.KEY_VALUE: true}]], "the autoplay toggle should raise its value")
	_heard.clear()
	(settings.find_child("SettingsLanguageOption", true, false) as OptionButton).item_selected.emit(1)
	_assert_eq(_heard, [[UiIntentsScript.LANGUAGE_SELECTED, {UiIntentsScript.KEY_LOCALE: "en"}]], "the language option should raise the locale code")
	_heard.clear()
	_press(settings, "SettingsManualSaveButton")
	_assert_eq(_heard, [[UiIntentsScript.MANUAL_SAVE_PRESSED, {}]], "the save button should raise an empty intent")
	_heard.clear()
	_press(settings, "SettingsReturnMainButton")
	_assert_eq(_heard, [[UiIntentsScript.RETURN_MAIN_MENU_PRESSED, {}]], "the return-main button should raise an empty intent")
	_heard.clear()
	_press(settings, "SettingsExitGameButton")
	_assert_eq(_heard, [[UiIntentsScript.EXIT_GAME_REQUESTED, {}]], "the exit button should raise an empty intent")
	_heard.clear()
	_press(settings, "SettingsHistoryButton")
	_assert_eq(_heard, [[UiIntentsScript.HISTORY_TOGGLE_REQUESTED, {}]], "the history button should raise an empty intent")

	panel.free()
	host.free()
	RegistryScript.clear()


func _test_exit_confirmation_raises_confirmed() -> void:
	_bind_bus()
	var host := Control.new()
	root.add_child(host)
	var panel := SettingsHistoryPanelScript.new()
	root.add_child(panel)
	panel.build_exit_confirmation_overlay(host, {
		"panel_factory": func() -> PanelContainer: return PanelContainer.new(),
		"label_factory": _label,
		"soft_style": func(_bg: Color, _border: Color) -> StyleBoxFlat: return StyleBoxFlat.new(),
		"theme_color": _theme_color,
		"ui_font_size": func(size: int) -> int: return size,
	})
	_press(host, "ExitConfirmationConfirmButton")
	_assert_eq(_heard, [[UiIntentsScript.EXIT_CONFIRMED, {}]], "the confirm button should raise an empty intent")
	panel.free()
	host.free()
	RegistryScript.clear()


func _test_hud_settings_button_raises_settings_pressed() -> void:
	_bind_bus()
	var host := Control.new()
	host.size = Vector2(1600, 900)
	root.add_child(host)
	var panel := AppleHudPanelScript.new()
	root.add_child(panel)
	panel.mount(host, {
		"panel_factory": func() -> PanelContainer: return PanelContainer.new(),
		"label_factory": _label,
		"theme_color": _theme_color,
		"style_factory": func(_bg: Color, _border: Color) -> StyleBoxFlat: return StyleBoxFlat.new(),
	})
	_press(host, "HUDSettingsIcon")
	_assert_eq(_heard, [[UiIntentsScript.SETTINGS_PRESSED, {}]], "the HUD settings icon should raise an empty intent")
	panel.free()
	host.free()
	RegistryScript.clear()


func _test_prologue_raises_finished() -> void:
	_bind_bus()
	var host := Control.new()
	root.add_child(host)
	var panel := ProloguePanelScript.new()
	root.add_child(panel)
	panel.mount(host, {
		"label_factory": _label,
		"theme_color": _theme_color,
		"prologue_lines": ["one", "two"],
	})
	panel.skip()
	_assert_eq(_heard, [[UiIntentsScript.PROLOGUE_FINISHED, {}]], "finishing the prologue should raise an empty intent")
	panel.free()
	host.free()
	RegistryScript.clear()


func _test_ending_raises_language_choice_and_restart() -> void:
	_bind_bus()
	var host := Control.new()
	host.size = Vector2(1600, 900)
	root.add_child(host)
	var panel := EndingScreenPanelScript.new()
	root.add_child(panel)
	panel.mount(host, {
		"label_factory": _label,
		"theme_color": _theme_color,
		"epilogue_lines": func() -> Array: return ["line"],
		"language_choices": func() -> Array: return [{"id": "blank", "label": "Blank"}],
		"language_output": func() -> String: return "",
		"relationship_residue": func() -> int: return 0,
		"relationship_state_label": func() -> String: return "",
	})
	panel.render()
	panel._on_language_choice_pressed("blank")
	_assert_eq(_heard, [[UiIntentsScript.ENDING_LANGUAGE_SELECTED, {UiIntentsScript.KEY_CHOICE_ID: "blank"}]], "an ending choice should raise its id")
	_heard.clear()
	panel._on_restart_pressed()
	_assert_eq(_heard, [[UiIntentsScript.RESTART_REQUESTED, {}]], "the restart button should raise an empty intent")
	panel.free()
	host.free()
	RegistryScript.clear()


func _bind_bus() -> void:
	RegistryScript.clear()
	BootScript.install()
	_heard.clear()
	var bus: GameEventBus = GameEventBusScript.new()
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, bus)
	bus.intent_emitted.connect(func(intent_name: String, payload: Dictionary) -> void: _heard.append([intent_name, payload]))


func _press(host: Node, button_name: String) -> void:
	var button := host.find_child(button_name, true, false) as BaseButton
	_assert_true(button != null, "%s should exist" % button_name)
	if button != null:
		button.pressed.emit()


func _label(text: String, _size: int, _color: Color) -> Label:
	var label_node := Label.new()
	label_node.text = text
	return label_node


func _theme_color(_key: String) -> Color:
	return Color("F5F7F2")


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
