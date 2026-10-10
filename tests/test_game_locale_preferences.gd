extends SceneTree
## Language and volume live in preference models. The preferences file reads and writes them; the run save does not.

const LocaleScript = preload("res://scripts/localization/game_locale.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const BootScript = preload("res://scripts/game/property_boot.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("game locale preference tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_every_preference_has_a_place_in_the_file()
	_test_preferences_round_trip_through_the_models()
	_test_missing_file_resets_language_and_keeps_volume()
	_test_unknown_saved_language_never_reaches_listeners()
	_test_translator_follows_the_language_model()
	_test_pinned_translator_leaves_the_language_alone()


func _test_every_preference_has_a_place_in_the_file() -> void:
	for property_name in PropertyKeysScript.PREFERENCES:
		_assert_true(LocaleScript.PREFERENCE_FILE_KEYS.has(property_name), "preference %s should have a section in the preferences file" % property_name)


func _test_preferences_round_trip_through_the_models() -> void:
	_boot()
	var path := _fresh_path("round_trip")
	var writer = LocaleScript.new()
	writer.preferences_path = path
	writer.select_language("ja")
	_model(PropertyKeysScript.MASTER_VOLUME).write(42.0)
	_model(PropertyKeysScript.AUTOPLAY_ENABLED).write(true)
	_assert_true(writer.save_preferences(false, true, "phone"), "saving preferences should succeed")

	var config := ConfigFile.new()
	_assert_eq(config.load(path), OK, "the preferences file should exist")
	_assert_true(not _config_has_key(config, PropertyKeysScript.AUTOPLAY_ENABLED), "the preferences file should not store run state")

	_model(PropertyKeysScript.LOCALE).write("zh")
	_model(PropertyKeysScript.MASTER_VOLUME).write(80.0)
	var reader = LocaleScript.new()
	reader.preferences_path = path
	var others: Dictionary = reader.load_preferences(true)
	_assert_eq(_model(PropertyKeysScript.LOCALE).read(), "ja", "loading should write the saved language into the model")
	_assert_eq(_model(PropertyKeysScript.MASTER_VOLUME).read(), 42.0, "loading should write the saved volume into the model")
	_assert_eq(reader.current_locale, "ja", "the translator should read the loaded language")
	_assert_true(reader.language_selected, "loading should remember that a language was chosen")
	_assert_true(not others.has("master_volume"), "volume should not come back as a loose value")
	_assert_eq(others.get("vhs_enabled", true), false, "other preferences should still load")
	_assert_eq(others.get("camera_source", ""), "phone", "camera source should still load")
	DirAccess.remove_absolute(path)


func _test_missing_file_resets_language_and_keeps_volume() -> void:
	_boot()
	_model(PropertyKeysScript.LOCALE).write("en")
	_model(PropertyKeysScript.MASTER_VOLUME).write(55.0)
	var locale = LocaleScript.new()
	locale.preferences_path = _fresh_path("missing")
	locale.load_preferences(true)
	_assert_eq(_model(PropertyKeysScript.LOCALE).read(), "zh", "a missing preferences file should fall back to Chinese")
	_assert_eq(_model(PropertyKeysScript.MASTER_VOLUME).read(), 55.0, "a missing preferences file should keep the current volume")


func _test_unknown_saved_language_never_reaches_listeners() -> void:
	_boot()
	_model(PropertyKeysScript.LOCALE).write("en")
	var path := _fresh_path("unknown")
	var config := ConfigFile.new()
	config.set_value("language", "locale", "fr")
	config.save(path)
	var seen: Array = []
	var listener := func(value: Variant) -> void: seen.append(value)
	_model(PropertyKeysScript.LOCALE).register(listener)
	var locale = LocaleScript.new()
	locale.preferences_path = path
	locale.load_preferences(true)
	_model(PropertyKeysScript.LOCALE).unregister(listener)
	_assert_eq(seen, ["en", "zh"], "an unknown saved language should reach listeners only as the fallback")
	DirAccess.remove_absolute(path)


func _test_translator_follows_the_language_model() -> void:
	_boot()
	var locale = LocaleScript.new()
	_assert_eq(locale.translate("资金 7"), "资金 7", "Chinese should not translate")
	_model(PropertyKeysScript.LOCALE).write("en")
	_assert_eq(locale.current_locale, "en", "the translator should read the language model")
	_assert_eq(locale.translate("资金 7"), "FUNDS 7", "the translator should reload when the language model changes")
	locale.set_locale("ja")
	_assert_eq(_model(PropertyKeysScript.LOCALE).read(), "ja", "setting the language should write the model")
	locale.current_locale = "en"
	_assert_eq(_model(PropertyKeysScript.LOCALE).read(), "en", "assigning the language should write the model")


func _test_pinned_translator_leaves_the_language_alone() -> void:
	_boot()
	var pinned = LocaleScript.for_locale("en")
	_assert_eq(pinned.current_locale, "en", "a pinned translator should use its own language")
	_assert_eq(pinned.translate("资金 7"), "FUNDS 7", "a pinned translator should translate into its language")
	_assert_eq(_model(PropertyKeysScript.LOCALE).read(), "zh", "a pinned translator should not change the game language")
	pinned.set_locale("ja")
	_assert_eq(pinned.current_locale, "ja", "a pinned translator can switch its own language")
	_assert_eq(_model(PropertyKeysScript.LOCALE).read(), "zh", "switching a pinned translator should not change the game language")


func _boot() -> void:
	RegistryScript.clear()
	BootScript.install()


func _model(property_name: String) -> ValuePropertyModel:
	var manager := RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	return manager.model(property_name) as ValuePropertyModel


func _fresh_path(label: String) -> String:
	var path := "user://test_locale_preferences_%s_%d.cfg" % [label, Time.get_ticks_usec()]
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return path


func _config_has_key(config: ConfigFile, key: String) -> bool:
	for section in config.get_sections():
		if config.has_section_key(section, key):
			return true
	return false


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
