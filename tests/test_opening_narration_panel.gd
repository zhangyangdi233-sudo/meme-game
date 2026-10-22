extends SceneTree
## The opening narration panel: two seconds of true black, then the current line of chapter one's opening in the
## chosen language and its formal font. It repaints from the chapter progress model, holds while settings is open,
## and a click raises the advance intent only while a line is shown.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const PanelScript = preload("res://scripts/ui/opening_narration_panel.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const CatalogScript = preload("res://scripts/game/narrative_session_catalog.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const PropertyBootScript = preload("res://scripts/game/property_boot.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")

var _failures: Array[String] = []
var _heard: Array = []


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	await _run()
	RegistryScript.clear()
	if _failures.is_empty():
		print("opening narration panel tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	PropertyBootScript.install()
	var bus := GameEventBusScript.new()
	bus.intent_emitted.connect(func(intent_name: String, payload: Dictionary) -> void: _heard.append([intent_name, payload]))
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, bus)
	await _test_black_for_two_seconds_then_the_first_line()
	await _test_the_line_follows_the_progress_and_the_language()
	await _test_settings_holds_the_black_and_the_clicks()
	await _test_a_click_advances_only_while_a_line_is_shown()
	await _test_a_complete_narration_shows_no_line()


func _test_black_for_two_seconds_then_the_first_line() -> void:
	_write_progress(ProgressScript.initial())
	_write(PropertyKeysScript.LOCALE, "zh")
	var panel := await _mount()
	var black := Harness.find_node_by_name(panel, "OpeningBlack") as ColorRect
	var line := Harness.find_node_by_name(panel, "OpeningNarrationLine") as Label
	_assert_true(black != null and black.visible, "the opening should start on black")
	if black != null:
		_assert_eq(black.color, UiPalette.VOID, "the opening black should be true black")
	_assert_true(line != null and not line.visible, "no line should show during the black")
	panel._process(1.5)
	_assert_true(black.visible and not line.visible, "the black should last two seconds")
	panel._process(0.6)
	_assert_true(not black.visible, "the black should lift after two seconds")
	_assert_true(line.visible, "the first line should show after the black")
	_assert_eq(line.text, str(CatalogScript.opening_lines("zh")[0]), "the first line should come from the catalog")
	var hint := Harness.find_node_by_name(panel, "OpeningNarrationHint") as Label
	_assert_true(hint != null and hint.visible and not hint.text.is_empty(), "a hint should say how to continue")
	await _unmount(panel)


func _test_the_line_follows_the_progress_and_the_language() -> void:
	_write_progress(ProgressScript.initial())
	_write(PropertyKeysScript.LOCALE, "zh")
	var panel := await _mount()
	panel._process(2.1)
	var line := Harness.find_node_by_name(panel, "OpeningNarrationLine") as Label
	_write_progress(ProgressScript.advance_narration(ProgressScript.initial()))
	_assert_eq(line.text, str(CatalogScript.opening_lines("zh")[1]), "advancing the progress should repaint the next line")
	_write(PropertyKeysScript.LOCALE, "ja")
	_assert_eq(line.text, str(CatalogScript.opening_lines("ja")[1]), "switching to Japanese should repaint the line")
	_assert_eq(line.get_theme_font("font"), LocaleFont.font("ja"), "the Japanese line should use the Japanese formal font")
	_write(PropertyKeysScript.LOCALE, "en")
	_assert_eq(line.text, str(CatalogScript.opening_lines("en")[1]), "switching to English should repaint the line")
	_assert_eq(line.get_theme_font("font"), LocaleFont.font("en"), "the English line should use the English formal font")
	_write(PropertyKeysScript.LOCALE, "zh")
	await _unmount(panel)


func _test_settings_holds_the_black_and_the_clicks() -> void:
	_write_progress(ProgressScript.initial())
	var panel := await _mount()
	_write(PropertyKeysScript.SETTINGS_OPEN, true)
	panel._process(5.0)
	var black := Harness.find_node_by_name(panel, "OpeningBlack") as ColorRect
	_assert_true(black.visible, "open settings should hold the black")
	_write(PropertyKeysScript.SETTINGS_OPEN, false)
	panel._process(2.1)
	_assert_true(not black.visible, "closing settings should let the black run out")
	_heard.clear()
	_write(PropertyKeysScript.SETTINGS_OPEN, true)
	panel._gui_input(_click())
	_assert_eq(_heard, [], "a click while settings is open should not advance")
	_write(PropertyKeysScript.SETTINGS_OPEN, false)
	await _unmount(panel)


func _test_a_click_advances_only_while_a_line_is_shown() -> void:
	_write_progress(ProgressScript.initial())
	var panel := await _mount()
	_heard.clear()
	panel._gui_input(_click())
	_assert_eq(_heard, [], "a click during the black should not advance")
	panel._process(2.1)
	panel._gui_input(_click())
	_assert_eq(_heard, [[UiIntentsScript.OPENING_NARRATION_ADVANCED, {}]], "a click on a shown line should raise the advance intent")
	_heard.clear()
	var release := _click()
	release.pressed = false
	panel._gui_input(release)
	var right := _click()
	right.button_index = MOUSE_BUTTON_RIGHT
	panel._gui_input(right)
	_assert_eq(_heard, [], "a release or another button should not advance")
	await _unmount(panel)


func _test_a_complete_narration_shows_no_line() -> void:
	var read := ProgressScript.initial()
	while ProgressScript.is_reading_narration(read):
		read = ProgressScript.advance_narration(read)
	_write_progress(read)
	var panel := await _mount()
	panel._process(2.1)
	var line := Harness.find_node_by_name(panel, "OpeningNarrationLine") as Label
	_assert_true(not line.visible, "a complete narration should show no line")
	_heard.clear()
	panel._gui_input(_click())
	_assert_eq(_heard, [], "a complete narration should not raise the advance intent")
	await _unmount(panel)


func _mount() -> Control:
	var panel := PanelScript.new() as Control
	root.add_child(panel)
	await process_frame
	return panel


func _unmount(panel: Control) -> void:
	panel.queue_free()
	await process_frame


func _click() -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


func _write_progress(progress: Dictionary) -> void:
	var manager := RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	(manager.model(PropertyKeysScript.CHAPTER_ONE_PROGRESS) as MapPropertyModel).replace_all(progress)


func _write(property_name: String, value: Variant) -> void:
	var manager := RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	(manager.model(property_name) as ValuePropertyModel).write(value)


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
