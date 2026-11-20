extends SceneTree
## In a run F10 toggles settings and Escape closes them; Escape with nothing to leave opens them (old version).
## In the prologue the keys reach the host too; inside the CRT terminal Escape first leaves the terminal.
## Opening releases the mouse; closing recaptures it only in the plain world view. An open Dialog keeps both keys.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const DialogScreenScript = preload("res://scripts/ui/dialog_screen.gd")
const TEST_SAVE_PATH := "user://test_settings_keys_scene_save.dat"
const TEST_PREFERENCES_PATH := "user://test_settings_keys_scene_preferences.cfg"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	root.size = Vector2i(1600, 900)
	_remove_files()
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	var game_root = scene.instantiate()
	game_root._save_path = TEST_SAVE_PATH
	root.add_child(game_root)
	await process_frame
	game_root._locale.preferences_path = TEST_PREFERENCES_PATH
	game_root._locale.set_locale("zh")
	await _test_prologue_keys(game_root)
	await _test_terminal_keys(game_root)
	await _test_a_language_change_in_the_terminal_keeps_the_cursor(game_root)
	await _test_world_keys(game_root)
	await _test_dialog_holds_the_keys(game_root)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	game_root.queue_free()
	await process_frame
	_remove_files()
	if _failures.is_empty():
		print("settings keys scene tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_prologue_keys(game_root) -> void:
	game_root.new_game()
	await process_frame
	_assert_eq(game_root.session_mode(), "prologue", "a new run should start in the prologue")
	_push_key(game_root, KEY_F10)
	await process_frame
	_assert_true(_settings_open(), "F10 should open settings during the opening narration")
	_assert_eq(Input.get_mouse_mode(), Input.MOUSE_MODE_VISIBLE, "open settings should free the mouse")
	_push_key(game_root, KEY_F10)
	await process_frame
	_assert_true(not _settings_open(), "F10 again should close settings")
	_assert_true(not game_root._reality_mouse_look_enabled, "closing during the narration should not capture the mouse")
	_push_key(game_root, KEY_ESCAPE)
	await process_frame
	_assert_true(_settings_open(), "Escape should open settings during the opening narration")
	_push_key(game_root, KEY_ESCAPE)
	await process_frame
	_assert_true(not _settings_open(), "Escape should close open settings")


func _test_terminal_keys(game_root) -> void:
	game_root._jump_to_basement_round(1)
	await process_frame
	await process_frame
	var adapter = game_root._reality_scene_adapter
	adapter.player.position = adapter.chapter_terminal_position() + Vector3(0.0, 0.02, 0.0)
	adapter.player.velocity = Vector3.ZERO
	for frame in 10:
		await physics_frame
	game_root.set_view_state("npc_up")
	_push_key(game_root, KEY_F)
	await process_frame
	_assert_eq(str(adapter.interaction_outcome().get("kind")), "terminal", "F at the CRT should enter the terminal")
	_push_key(game_root, KEY_F10)
	await process_frame
	_assert_true(_settings_open(), "F10 should open settings inside the terminal")
	_push_key(game_root, KEY_ESCAPE)
	await process_frame
	_assert_true(not _settings_open(), "Escape should close settings first")
	_assert_eq(str(adapter.interaction_outcome().get("kind")), "terminal", "closing settings should stay in the terminal")
	_assert_true(not game_root._reality_mouse_look_enabled, "closing settings in the terminal should not capture the mouse")
	_push_key(game_root, KEY_ESCAPE)
	await process_frame
	_assert_true(str(adapter.interaction_outcome().get("kind")) != "terminal", "Escape should then leave the terminal")
	_assert_true(not _settings_open(), "leaving the terminal should not open settings")


## Changing the language in settings leaves the terminal; the cursor must stay free under the open window and come
## back captured only once settings close in the world view.
func _test_a_language_change_in_the_terminal_keeps_the_cursor(game_root) -> void:
	var adapter = game_root._reality_scene_adapter
	_push_key(game_root, KEY_F)
	await process_frame
	_assert_eq(str(adapter.interaction_outcome().get("kind")), "terminal", "setup should enter the terminal again")
	_push_key(game_root, KEY_F10)
	await process_frame
	game_root._on_settings_language_selected("ja")
	await process_frame
	_assert_true(_settings_open(), "a language change should leave settings open")
	_assert_true(not game_root._reality_mouse_look_enabled, "a language change should not capture the mouse under the settings window")
	game_root._on_settings_language_selected("zh")
	await process_frame
	_push_key(game_root, KEY_ESCAPE)
	await process_frame
	_assert_true(not _settings_open(), "Escape should close settings after the language change")
	_assert_true(game_root._reality_mouse_look_enabled, "closing settings in the world view should capture the mouse look")


func _test_world_keys(game_root) -> void:
	# Round two owns the phone, so it can be raised below.
	game_root._jump_to_basement_round(2)
	await process_frame
	await process_frame
	game_root.set_view_state("npc_up")
	_push_key(game_root, KEY_ESCAPE)
	await process_frame
	_assert_true(_settings_open(), "Escape with nothing to leave should open settings")
	_assert_true(not game_root._reality_mouse_look_enabled, "open settings should release the mouse look")
	# Open settings hold the world's keys: Tab must not raise the phone or capture the mouse under the window.
	_push_key(game_root, KEY_TAB)
	await process_frame
	_assert_eq(str(game_root.game.view_state), "npc_up", "Tab should do nothing while settings are open")
	_push_key(game_root, KEY_TAB)
	await process_frame
	_assert_true(not game_root._reality_mouse_look_enabled, "Tab should not capture the mouse while settings are open")
	_push_key(game_root, KEY_F10)
	await process_frame
	_assert_true(not _settings_open(), "F10 should close settings")
	_assert_true(game_root._reality_mouse_look_enabled, "closing in the world view should capture the mouse look again")
	game_root.set_view_state("phone_down")
	_assert_eq(str(game_root.game.view_state), "phone_down", "setup should raise the phone")
	_push_key(game_root, KEY_F10)
	await process_frame
	_assert_true(_settings_open(), "F10 should open settings with the phone up")
	_push_key(game_root, KEY_F10)
	await process_frame
	_assert_true(not game_root._reality_mouse_look_enabled, "closing with the phone up should leave the cursor free")


func _test_dialog_holds_the_keys(game_root) -> void:
	var dialog := RegistryScript.resolve(ServiceKeysScript.DIALOG) as ScreenManager
	dialog.open({
		DialogScreenScript.KEY_MESSAGE: "返回",
		DialogScreenScript.KEY_BUTTONS: [{DialogScreenScript.KEY_TEXT: "返回"}],
	})
	await process_frame
	_push_key(game_root, KEY_F10)
	await process_frame
	_assert_true(not _settings_open(), "F10 should do nothing while the Dialog is open")
	dialog.close()
	await process_frame


func _settings_open() -> bool:
	var manager := RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	var model := manager.model(PropertyKeysScript.SETTINGS_OPEN) as ValuePropertyModel
	return model != null and bool(model.read())


func _push_key(game_root, keycode: Key) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = keycode
		key.physical_keycode = keycode
		key.pressed = pressed
		game_root.get_viewport().push_input(key, true)


func _remove_files() -> void:
	for path in [TEST_SAVE_PATH, TEST_PREFERENCES_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
