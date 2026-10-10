extends SceneTree
## In the main scene, the host's handler writes volume and autoplay into their models and routes the rest.

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
		var autoplay := manager.model(PropertyKeysScript.AUTOPLAY_ENABLED) as ValuePropertyModel

		GameEventBus.raise(UiIntentsScript.VOLUME_CHANGED, {UiIntentsScript.KEY_VALUE: 37.0})
		_assert_eq(float(volume.read()), 37.0, "a volume intent should write the volume model")
		GameEventBus.raise(UiIntentsScript.AUTOPLAY_TOGGLED, {UiIntentsScript.KEY_VALUE: true})
		_assert_eq(bool(autoplay.read()), true, "an autoplay intent should write the autoplay model")
		GameEventBus.raise(UiIntentsScript.AUTOPLAY_TOGGLED, {UiIntentsScript.KEY_VALUE: false})
		_assert_eq(bool(autoplay.read()), false, "a second autoplay intent should write the model again")

		var settings := game_root.find_child("SettingsWindow", true, false) as Control
		GameEventBus.raise(UiIntentsScript.SETTINGS_PRESSED)
		_assert_true(settings != null and settings.visible, "a settings intent should open the settings window")
		GameEventBus.raise(UiIntentsScript.SETTINGS_PRESSED)
		_assert_true(settings != null and not settings.visible, "a second settings intent should close it")

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
