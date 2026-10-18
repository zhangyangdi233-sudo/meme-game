extends SceneTree
## Routing smoke: in the main scene, the host hands settings intents to the settings handler and presents the
## result. What each intent writes is covered by test_settings_intent_handler.

const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")

const TEST_SAVE_PATH := "user://test_settings_quit_save.dat"
const TEST_PREFERENCES_PATH := "user://test_settings_quit_preferences.cfg"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	root.size = Vector2i(1600, 900)
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "the main scene should load")
	if scene != null:
		var game_root := scene.instantiate()
		root.add_child(game_root)
		game_root._locale.set_locale("zh")
		game_root.new_game()
		game_root._skip_prologue()
		await process_frame

		var manager := RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
		var volume := manager.model(PropertyKeysScript.MASTER_VOLUME) as ValuePropertyModel

		GameEventBus.raise(UiIntentsScript.VOLUME_CHANGED, {UiIntentsScript.KEY_VALUE: 37.0})
		_assert_eq(float(volume.read()), 37.0, "the host should route a volume intent to the settings handler")
		GameEventBus.raise(UiIntentsScript.VHS_TOGGLED, {UiIntentsScript.KEY_VALUE: false})
		_assert_eq(game_root._vhs_enabled, false, "the host should present a VHS toggle")
		GameEventBus.raise(UiIntentsScript.VHS_TOGGLED, {UiIntentsScript.KEY_VALUE: true})

		var history: Control = game_root._settings_history_panel.get_history_window()
		GameEventBus.raise(UiIntentsScript.HISTORY_TOGGLE_REQUESTED)
		_assert_true(history != null and history.visible, "the host should present a history toggle")
		GameEventBus.raise(UiIntentsScript.HISTORY_TOGGLE_REQUESTED)
		GameEventBus.raise(UiIntentsScript.EXIT_GAME_REQUESTED)
		var exit_dialog := game_root.find_child("DialogLayer", true, false) as Control
		_assert_true(game_root.game.exit_prompt_seen, "the host should route an exit request to the settings handler")
		_assert_true(exit_dialog != null and exit_dialog.visible, "the host should present the quit prompt in the dialog")
		_press_dialog_button(exit_dialog, "DialogButton0")

		var settings := game_root.find_child("SettingsWindow", true, false) as Control
		GameEventBus.raise(UiIntentsScript.SETTINGS_PRESSED)
		_assert_true(settings != null and settings.visible, "a settings intent should open the settings window")
		GameEventBus.raise(UiIntentsScript.SETTINGS_PRESSED)
		_assert_true(settings != null and not settings.visible, "a second settings intent should close it")

		var open_model := manager.model(PropertyKeysScript.SETTINGS_OPEN) as ValuePropertyModel
		var view_toggle: Button = game_root._view_toggle_button
		var toggle_shown_before: bool = view_toggle != null and view_toggle.visible
		open_model.write(true)
		_assert_true(settings != null and settings.visible, "writing the open model should show the settings window")
		_assert_true(view_toggle != null and not view_toggle.visible, "the host should re-evaluate chrome when the open model changes")
		open_model.write(false)
		_assert_true(settings != null and not settings.visible, "writing the open model closed should hide the window")
		_assert_eq(view_toggle != null and view_toggle.visible, toggle_shown_before, "closing by model should restore the chrome")

		# Last: 仍然退出 asks the tree to quit, so no frame runs after it and the test finishes right away.
		_test_quit_anyway_saves_and_quits(game_root)
		game_root.free()
	_finish()


## 仍然退出 in the exit dialog raises the exit confirm; the host saves the run and the preferences, then quits.
func _test_quit_anyway_saves_and_quits(game_root: Node) -> void:
	game_root._save_path = TEST_SAVE_PATH
	game_root._locale.preferences_path = TEST_PREFERENCES_PATH
	for path in [TEST_SAVE_PATH, TEST_PREFERENCES_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	GameEventBus.raise(UiIntentsScript.EXIT_GAME_REQUESTED)
	_press_dialog_button(game_root.find_child("DialogLayer", true, false), "DialogButton1")
	_assert_true(FileAccess.file_exists(TEST_SAVE_PATH), "仍然退出 should save the run before quitting")
	_assert_true(FileAccess.file_exists(TEST_PREFERENCES_PATH), "仍然退出 should save the preferences before quitting")
	for path in [TEST_SAVE_PATH, TEST_PREFERENCES_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _finish() -> void:
	if _failures.is_empty():
		print("settings intents scene tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _press_dialog_button(dialog: Node, button_name: String) -> void:
	var button := dialog.find_child(button_name, true, false) as BaseButton if dialog != null else null
	_assert_true(button != null, "the dialog should show %s" % button_name)
	if button != null:
		button.pressed.emit()


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
