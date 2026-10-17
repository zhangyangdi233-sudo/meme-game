extends SceneTree
## Routing smoke: in the main scene, the host hands settings intents to the settings handler and presents the
## result. What each intent writes is covered by test_settings_intent_handler.

const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")

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
		var exit_overlay := game_root.find_child("ExitConfirmationOverlay", true, false) as Control
		GameEventBus.raise(UiIntentsScript.EXIT_GAME_REQUESTED)
		_assert_true(game_root.game.exit_prompt_seen, "the host should route an exit request to the settings handler")
		_assert_true(exit_overlay != null and exit_overlay.visible, "the host should present the quit prompt")
		game_root._cancel_quit_game()

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

		game_root.queue_free()
		await process_frame

	if _failures.is_empty():
		print("settings intents scene tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
