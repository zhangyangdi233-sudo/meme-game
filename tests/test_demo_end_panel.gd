extends SceneTree
## The demo's end screen: black text on white in the chosen language and its formal font. It repaints from the locale
## model, and its button raises the same intent as the settings window's way back to the main menu.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const PanelScene = preload("res://scenes/ui/demo_end.tscn")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const PropertyBootScript = preload("res://scripts/game/property_boot.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")

var _failures: Array[String] = []
var _heard: Array[String] = []


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	await _run()
	RegistryScript.clear()
	if _failures.is_empty():
		print("demo end panel tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	PropertyBootScript.install()
	var bus := GameEventBusScript.new()
	bus.intent_emitted.connect(func(intent_name: String, _payload: Dictionary) -> void: _heard.append(intent_name))
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, bus)
	_write_locale("zh")
	var panel := PanelScene.instantiate() as Control
	root.add_child(panel)
	await process_frame
	var white := Harness.find_node_by_name(panel, "DemoEndWhite") as ColorRect
	var text := Harness.find_node_by_name(panel, "DemoEndText") as Label
	var button := Harness.find_node_by_name(panel, "DemoEndMenuButton") as Button
	_assert_eq(white.color, Color.WHITE, "the end screen should be white")
	_assert_eq(text.get_theme_color("font_color"), Color.BLACK, "the end text should be black")
	_assert_eq(text.text, "Demo 到此结束", "zh text")
	_assert_eq(text.get_theme_font("font"), LocaleFont.font("zh"), "the text should use the language's formal font")
	_write_locale("ja")
	_assert_eq(text.text, "demoはここまでです", "ja text")
	_assert_eq(text.get_theme_font("font"), LocaleFont.font("ja"), "the font should follow the language")
	_write_locale("en")
	_assert_eq(text.text, "The demo ends here.", "en text")
	button.pressed.emit()
	_assert_eq(_heard, [UiIntentsScript.RETURN_MAIN_MENU_PRESSED], "the button should ask for the main menu")
	panel.queue_free()
	await process_frame


func _write_locale(locale: String) -> void:
	var manager := RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	(manager.model(PropertyKeysScript.LOCALE) as ValuePropertyModel).write(locale)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
