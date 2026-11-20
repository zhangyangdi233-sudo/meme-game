extends SceneTree
## The opening narration panel: two seconds of true black, then the current line of chapter one's opening behind its
## speaker tag, in the chosen language and its formal font. It repaints from the chapter progress model, holds while settings is open,
## and a click raises the advance intent only while a line is shown.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const PanelScene = preload("res://scenes/ui/opening_narration.tscn")
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
var _voiced: Array = []


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
	await _test_every_language_reads_from_first_line_to_last()
	await _test_the_narrator_speaks_each_shown_line_without_its_tag()
	await _test_the_voice_stops_with_settings_the_end_and_hiding()
	await _test_the_same_narrator_speaks_the_crt_focus_cinematic()


## Round one's CRT focus cinematic is the same narrator (the old version reused its opening control): no black, the
## catalog's `crt_focus` lines behind the speaker tag with its own hint, the line the host shows, and a click raises
## the cinematic's intent, nothing while no line shows or settings is open.
func _test_the_same_narrator_speaks_the_crt_focus_cinematic() -> void:
	var basement := ProgressScript.jump_to_round(ProgressScript.initial(), 1)
	_write_progress(basement)
	for locale_code in ["zh", "ja", "en"]:
		_write(PropertyKeysScript.LOCALE, locale_code)
		var panel := PanelScene.instantiate() as Control
		panel.configure_crt_focus()
		root.add_child(panel)
		await process_frame
		var black := Harness.find_node_by_name(panel, "OpeningBlack") as ColorRect
		var line := Harness.find_node_by_name(panel, "OpeningNarrationLine") as Label
		var hint := Harness.find_node_by_name(panel, "OpeningNarrationHint") as Label
		_assert_true(not black.visible, "%s: the cinematic should show no black" % locale_code)
		_assert_true(not line.visible, "%s: no line should show while the view turns" % locale_code)
		_heard.clear()
		panel._gui_input(_click())
		_assert_eq(_heard, [], "%s: a click while no line shows should raise nothing" % locale_code)
		var lines: Array = CatalogScript.crt_focus_lines(locale_code)
		_assert_eq(lines.size(), CatalogScript.CRT_FOCUS_LINE_COUNT, "%s: the cinematic should have seven lines" % locale_code)
		for index in lines.size():
			panel.show_crt_focus_line(index)
			_assert_true(line.visible and hint.visible, "%s: line %d should show" % [locale_code, index])
			_assert_eq(line.text, CatalogScript.opening_speaker(locale_code) + str(lines[index]), "%s: line %d behind the speaker tag" % [locale_code, index])
		_assert_eq(hint.text, CatalogScript.crt_focus_hint(locale_code), "%s: the cinematic's own hint" % locale_code)
		_assert_eq(line.get_theme_font("font"), LocaleFont.font(locale_code), "%s: the line should use the language's formal font" % locale_code)
		panel._gui_input(_click())
		_assert_eq(_heard, [[UiIntentsScript.CRT_FOCUS_ADVANCED, {}]], "%s: a click on a shown line should raise the cinematic's intent" % locale_code)
		_heard.clear()
		_write(PropertyKeysScript.SETTINGS_OPEN, true)
		panel._gui_input(_click())
		_assert_eq(_heard, [], "%s: a click with settings open should raise nothing" % locale_code)
		_write(PropertyKeysScript.SETTINGS_OPEN, false)
		panel.show_crt_focus_line(-1)
		_assert_true(not line.visible, "%s: no line should show as the view turns back" % locale_code)
		await _unmount(panel)
	_assert_eq(CatalogScript.crt_focus_lines("zh")[0], "这个对你来说不陌生", "the first line is the old version's")
	_assert_eq(CatalogScript.crt_focus_hint("en"), "Click to continue", "the English hint is the old version's")
	_write(PropertyKeysScript.LOCALE, "zh")
	await create_timer(0.15).timeout


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
	_assert_eq(line.text, _spoken("zh", 0), "the first line should come from the catalog behind the speaker tag")
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
	_assert_eq(line.text, _spoken("zh", 1), "advancing the progress should repaint the next line")
	_write(PropertyKeysScript.LOCALE, "ja")
	_assert_eq(line.text, _spoken("ja", 1), "switching to Japanese should repaint the line")
	_assert_eq(line.get_theme_font("font"), LocaleFont.font("ja"), "the Japanese line should use the Japanese formal font")
	_write(PropertyKeysScript.LOCALE, "en")
	_assert_eq(line.text, _spoken("en", 1), "switching to English should repaint the line")
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


func _test_every_language_reads_from_first_line_to_last() -> void:
	for locale_code in ["zh", "ja", "en"]:
		_write_progress(ProgressScript.initial())
		_write(PropertyKeysScript.LOCALE, locale_code)
		var panel := await _mount()
		panel._process(2.1)
		var line := Harness.find_node_by_name(panel, "OpeningNarrationLine") as Label
		var read := ProgressScript.initial()
		var shown := 0
		while ProgressScript.is_reading_narration(read):
			_assert_true(line.visible, "%s line %d should be on screen" % [locale_code, shown])
			_assert_eq(line.text, _spoken(locale_code, shown), "%s should show line %d behind the speaker tag" % [locale_code, shown])
			read = ProgressScript.advance_narration(read)
			_write_progress(read)
			shown += 1
		_assert_eq(shown, ProgressScript.OPENING_LINE_COUNT, "%s should read every line" % locale_code)
		_assert_true(not line.visible, "%s should end after its last line" % locale_code)
		await _unmount(panel)
	_write(PropertyKeysScript.LOCALE, "zh")


## Blips the panel's voice has sounded: [character, sample index]. The voice's own clock is off so a test drives it.
func _voice_of(panel: Control) -> Node:
	var voice := panel.get("_blips") as Node
	voice.set_process(false)
	voice.blip_played.connect(func(character: String, sample_index: int) -> void: _voiced.append([character, sample_index]))
	return voice


func _test_the_narrator_speaks_each_shown_line_without_its_tag() -> void:
	_write_progress(ProgressScript.initial())
	_write(PropertyKeysScript.LOCALE, "zh")
	var panel := await _mount()
	var voice := _voice_of(panel)
	_voiced.clear()
	_assert_true(not voice.is_speaking(), "the narrator should be silent during the black")
	panel._process(2.1)
	var first := str(CatalogScript.opening_lines("zh")[0])
	_assert_true(not _voiced.is_empty() and _voiced[0][0] == first.substr(0, 1), "the first shown line should speak from its first character, not the speaker tag")
	# The sample index counts characters from the line's own start: with the tag in front it would be offset by its length.
	_assert_eq(_voiced[0][1], first.unicode_at(0) % 6, "the voice should index the line without the speaker tag")
	var after_first := _voiced.size()
	_write_progress(ProgressScript.initial())
	panel._repaint()
	_assert_eq(_voiced.size(), after_first, "repainting the same line should not speak it again")
	_write_progress(ProgressScript.advance_narration(ProgressScript.initial()))
	_assert_eq(_voiced.size(), after_first + 1, "the next line should start its own voice")
	_assert_eq(_voiced[after_first][0], str(CatalogScript.opening_lines("zh")[1]).substr(0, 1), "the next line should speak its own first character")
	var before_language := _voiced.size()
	_write(PropertyKeysScript.LOCALE, "ja")
	_assert_eq(_voiced.size(), before_language + 1, "a language change should speak the line again in that language")
	_assert_eq(_voiced[before_language][0], str(CatalogScript.opening_lines("ja")[1]).substr(0, 1), "the Japanese line should be spoken from its first character")
	_write(PropertyKeysScript.LOCALE, "zh")
	await _unmount(panel)


func _test_the_voice_stops_with_settings_the_end_and_hiding() -> void:
	_write_progress(ProgressScript.initial())
	var panel := await _mount()
	var voice := _voice_of(panel)
	_voiced.clear()
	panel._process(2.1)
	_assert_true(voice.is_speaking(), "a shown line should be speaking")
	_write(PropertyKeysScript.SETTINGS_OPEN, true)
	_assert_true(not voice.is_speaking(), "open settings should silence the voice")
	var heard := _voiced.size()
	voice.tick(100.0)
	_write(PropertyKeysScript.SETTINGS_OPEN, false)
	voice.tick(100.0)
	_assert_eq(_voiced.size(), heard, "closing settings should not resume or replay the line")
	_write_progress(ProgressScript.advance_narration(ProgressScript.initial()))
	_assert_true(voice.is_speaking(), "the next line after settings should speak again")
	panel.hide()
	_assert_true(not voice.is_speaking(), "hiding the panel should stop the voice")
	panel.show()
	var read := ProgressScript.initial()
	while ProgressScript.is_reading_narration(read):
		read = ProgressScript.advance_narration(read)
	_write_progress(read)
	_assert_true(not voice.is_speaking(), "a read narration should stop the voice")
	await _unmount(panel)
	# Headless frames can end before the audio thread releases stopped playbacks.
	await create_timer(0.15).timeout


func _spoken(locale_code: String, line_index: int) -> String:
	return CatalogScript.opening_speaker(locale_code) + str(CatalogScript.opening_lines(locale_code)[line_index])


func _mount() -> Control:
	var panel := PanelScene.instantiate() as Control
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
