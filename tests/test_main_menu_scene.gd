extends SceneTree
## Main menu layout scene: node contract, palette roles under both palettes, and isolation from the global UI theme walk.
## With a save, holding START opens the restart dialog; the hint above START shows only with a save.

const ScreenManagerScript = preload("res://scripts/ui/screen_manager.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const MainMenuScreenScript = preload("res://scripts/ui/main_menu_screen.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const BootScript = preload("res://scripts/game/property_boot.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const DialogScreenScript = preload("res://scripts/ui/dialog_screen.gd")
const UICatalogScript = preload("res://scripts/localization/ui_catalog.gd")
const DialogDebugPanelScene = preload("res://scenes/ui/dialog_debug_panel.tscn")

const POLLUTED_STAGE := {"palette_key": "pollution_palette_5"}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_deferred")


func _run_deferred() -> void:
	await process_frame
	root.size = Vector2i(1600, 900)
	_run()
	await _run_hold()
	if _failures.is_empty():
		print("main menu scene tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_palettes_define_menu_bg()
	_test_mount_keeps_node_contract()
	_test_art_buttons_keep_their_art()
	_test_open_menu_follows_the_save()
	_test_closed_menu_keeps_its_last_look()
	_test_two_open_menus_follow_the_same_facts()
	_test_global_theme_walk_skips_menu()
	_test_misspelled_palette_role_is_reported()
	_test_off_grid_font_size_is_reported()


func _run_hold() -> void:
	await _test_holding_start_with_a_save_opens_the_restart_dialog()
	await _test_a_short_press_with_a_save_still_continues()
	await _test_keys_and_the_pad_hold_start_too()
	await _test_without_a_save_holding_start_starts_a_new_game()
	await _test_the_restart_dialog_words_and_buttons()
	await _test_yes_restarts_and_no_or_escape_only_close()
	await _test_closing_the_menu_closes_the_restart_dialog()
	await _test_the_hold_hint_follows_the_save_language_and_hover()
	await _test_the_debug_panel_shows_how_long_start_is_held()


func _test_holding_start_with_a_save_opens_the_restart_dialog() -> void:
	var mounted := await _mount_with_dialog(true)
	var heard := _listen(mounted)
	_mouse_start(mounted, true)
	_tick(mounted, 0.5)
	_tick(mounted, 0.29)
	_assert_true(not _dialog_open(mounted), "held under 0.8 seconds the restart dialog stays closed")
	_tick(mounted, 0.02)
	_assert_true(_dialog_open(mounted), "held 0.8 seconds the restart dialog opens before release")
	_mouse_start(mounted, false)
	_assert_eq(heard, [] as Array[String], "releasing after the dialog opened raises nothing")
	_assert_true(_dialog_open(mounted), "releasing after the dialog opened leaves it open")
	_dispose_all(mounted)


func _test_a_short_press_with_a_save_still_continues() -> void:
	var mounted := await _mount_with_dialog(true)
	var heard := _listen(mounted)
	_mouse_start(mounted, true)
	_tick(mounted, 0.7)
	_mouse_start(mounted, false)
	_assert_eq(heard, [UiIntentsScript.CONTINUE_GAME] as Array[String], "released under 0.8 seconds START continues")
	_assert_true(not _dialog_open(mounted), "a short press opens no dialog")
	# A later hold starts its count again instead of adding to the short press.
	_mouse_start(mounted, true)
	_tick(mounted, 0.2)
	_assert_true(not _dialog_open(mounted), "a new hold counts from zero")
	_mouse_start(mounted, false)
	_dispose_all(mounted)


func _test_keys_and_the_pad_hold_start_too() -> void:
	for source in ["enter", "space", "pad"]:
		var mounted := await _mount_with_dialog(true)
		var heard := _listen(mounted)
		var start := _start(mounted)
		start.grab_focus()
		_confirm(source, true)
		_tick(mounted, 0.81)
		_assert_true(_dialog_open(mounted), "holding %s on a focused START opens the restart dialog" % source)
		# The key release goes to the dialog, so START may never hear it; the open dialog ends the hold.
		_tick(mounted, 0.5)
		_assert_eq(_held_seconds(), 0.0, "once %s opens the dialog the hold stops counting" % source)
		_confirm(source, false)
		_assert_true(_dialog_open(mounted), "releasing %s does not press the dialog's focused button" % source)
		_assert_eq(heard, [] as Array[String], "releasing %s after the dialog opened raises nothing" % source)
		_dispose_all(mounted)
	var mounted := await _mount_with_dialog(true)
	var heard := _listen(mounted)
	_start(mounted).grab_focus()
	_confirm("enter", true)
	_tick(mounted, 0.3)
	_confirm("enter", false)
	_assert_eq(heard, [UiIntentsScript.CONTINUE_GAME] as Array[String], "a short Enter on START continues")
	_dispose_all(mounted)


func _test_without_a_save_holding_start_starts_a_new_game() -> void:
	var mounted := await _mount_with_dialog(false)
	var heard := _listen(mounted)
	_mouse_start(mounted, true)
	_tick(mounted, 1.0)
	_tick(mounted, 1.0)
	_assert_true(not _dialog_open(mounted), "without a save holding START opens no dialog")
	_mouse_start(mounted, false)
	_assert_eq(heard, [UiIntentsScript.START_GAME] as Array[String], "without a save releasing a long hold starts a new game")
	_dispose_all(mounted)


func _test_the_restart_dialog_words_and_buttons() -> void:
	var mounted := await _mount_with_dialog(true)
	_hold_until_dialog(mounted)
	var dialog := _dialog_screen(mounted)
	_assert_eq(_text(dialog, "DialogMessage"), "[确定要重新开始游戏吗？]", "the question is the catalog source key, translated")
	var buttons := _dialog_buttons(mounted)
	_assert_eq(buttons.size(), 2, "the restart dialog has two buttons")
	if buttons.size() == 2:
		_assert_eq(buttons[0].text, "[是]", "YES sits on the left")
		_assert_eq(buttons[1].text, "[否]", "NO sits on the right")
		_assert_true(buttons[1].has_focus(), "NO takes the focus when the dialog opens")
	for locale in ["en", "ja"]:
		var entries: Dictionary = UICatalogScript.entries(locale)
		var expected: Dictionary = {
			"en": {"确定要重新开始游戏吗？": "Are you sure you want to restart?", "是": "YES", "否": "NO", "长按重新开始": "hold to restart"},
			"ja": {"确定要重新开始游戏吗？": "ゲームを再起動してもよろしいですか？", "是": "はい", "否": "いいえ", "长按重新开始": "長押しでリスタート"},
		}[locale]
		for source in expected.keys():
			_assert_eq(str(entries.get(source, "")), str(expected[source]), "%s catalog should word %s" % [locale, source])
	_dispose_all(mounted)


func _test_yes_restarts_and_no_or_escape_only_close() -> void:
	var mounted := await _mount_with_dialog(true)
	var heard := _listen(mounted)
	if not _hold_until_dialog(mounted):
		_dispose_all(mounted)
		return
	_dialog_buttons(mounted)[1].pressed.emit()
	_assert_true(not _dialog_open(mounted), "NO closes the dialog")
	_assert_eq(heard, [] as Array[String], "NO raises nothing")
	_mouse_start(mounted, false)
	_hold_until_dialog(mounted)
	_press_escape()
	_assert_true(not _dialog_open(mounted), "Escape closes the dialog")
	_assert_eq(heard, [] as Array[String], "Escape works like NO and raises nothing")
	_mouse_start(mounted, false)
	_hold_until_dialog(mounted)
	_dialog_buttons(mounted)[0].pressed.emit()
	_assert_true(not _dialog_open(mounted), "YES closes the dialog")
	_assert_eq(heard, [UiIntentsScript.RESTART_REQUESTED] as Array[String], "YES asks the host to restart on the bound bus")
	_dispose_all(mounted)


func _test_closing_the_menu_closes_the_restart_dialog() -> void:
	var mounted := await _mount_with_dialog(true)
	var heard := _listen(mounted)
	_hold_until_dialog(mounted)
	mounted["manager"].close()
	_assert_true(not _dialog_open(mounted), "closing the main menu closes its restart dialog")
	_assert_eq(heard, [] as Array[String], "the dialog closed with the menu runs no callback")
	_dispose_all(mounted)


func _test_the_hold_hint_follows_the_save_language_and_hover() -> void:
	var mounted := await _mount_with_dialog(false)
	var hint := Harness.find_node_by_name(mounted["screen"], "MainMenuHoldHint") as Label
	var start := _start(mounted)
	_assert_true(hint != null, "the main menu should have the hold hint label")
	if hint == null:
		_dispose_all(mounted)
		return
	_assert_true(not hint.visible, "without a save the hint is hidden")
	Harness.publish_title_facts(0, true)
	_assert_true(hint.visible, "the hint shows once a save appears")
	_assert_eq(hint.text, "[长按重新开始]", "the hint is the catalog source key, translated")
	var hint_rect := hint.get_global_rect()
	var start_rect := start.get_global_rect()
	_assert_true(is_equal_approx(hint_rect.position.x, start_rect.position.x), "the hint is left-aligned with START")
	_assert_true(hint_rect.end.y <= start_rect.position.y + 1.0, "the hint sits above START")
	var idle := hint.get_theme_color("font_color")
	_assert_eq(idle, MainMenuScreenScript.HINT_COLOR_IDLE, "the hint is pale while START is idle")
	start.mouse_entered.emit()
	_assert_eq(hint.get_theme_color("font_color"), MainMenuScreenScript.HINT_COLOR_ACTIVE, "hovering START darkens the hint")
	start.mouse_exited.emit()
	_assert_eq(hint.get_theme_color("font_color"), MainMenuScreenScript.HINT_COLOR_IDLE, "leaving START pales the hint again")
	start.grab_focus()
	_assert_eq(hint.get_theme_color("font_color"), MainMenuScreenScript.HINT_COLOR_ACTIVE, "focusing START darkens the hint")
	start.release_focus()
	_assert_eq(hint.get_theme_color("font_color"), MainMenuScreenScript.HINT_COLOR_IDLE, "START losing focus pales the hint")
	Harness.publish_title_facts(0, false)
	_assert_true(not hint.visible, "the hint hides when the save goes away")
	# The menu re-opens after a language switch and words the hint again.
	(mounted["theme"] as GameUiTheme).configure({"locale_translate": func(source: String) -> String: return "<%s>" % source})
	Harness.publish_title_facts(0, true)
	mounted["manager"].close()
	mounted["manager"].open({})
	_assert_eq(hint.text, "<长按重新开始>", "re-opening the menu words the hint in the new language")
	_dispose_all(mounted)


func _test_the_debug_panel_shows_how_long_start_is_held() -> void:
	var mounted := await _mount_with_dialog(true)
	var panel := DialogDebugPanelScene.instantiate() as Control
	(mounted["layer"] as Control).add_child(panel)
	var label := Harness.find_node_by_name(panel, "DialogDebugHoldTime") as Label
	_assert_true(label != null, "the debug panel should show how long START is held")
	if label == null:
		_dispose_all(mounted)
		return
	_assert_eq(label.text, "START 按住：0.00 秒", "before a hold the panel shows zero")
	_mouse_start(mounted, true)
	_tick(mounted, 0.25)
	_tick(mounted, 0.25)
	_assert_eq(label.text, "START 按住：0.50 秒", "while held the panel shows the seconds so far")
	_mouse_start(mounted, false)
	_assert_eq(label.text, "START 按住：0.00 秒", "releasing START resets the panel")
	_dispose_all(mounted)


func _test_palettes_define_menu_bg() -> void:
	var ui_theme := GameUiThemeScript.new()
	_assert_eq(ui_theme.theme_color("menu_bg", {}), Color("5DAE6B"), "palette_1 should define menu_bg")
	_assert_eq(ui_theme.theme_color("menu_bg", POLLUTED_STAGE), Color("9CFF24"), "pollution_palette_5 should define menu_bg")


func _test_mount_keeps_node_contract() -> void:
	var mounted := _mount(0, false)
	var host: Control = mounted["host"]
	var layer: Control = mounted["screen"]
	_assert_true(layer != null and layer.name == "MainMenuLayer", "mount should expose the MainMenuLayer root")
	for node_name in [
		"MainMenuBackground",
		"MainMenuBand",
		"MainMenuStrip",
		"MainMenuRedBackdrop",
		"MainMenuTitleArt",
		"MainMenuStartButton",
		"MainMenuExitButton",
		"MainMenuLanguageButton",
	]:
		_assert_true(Harness.find_node_by_name(host, node_name) != null, "main menu should keep node %s" % node_name)

	_assert_true(Harness.find_node_by_name(host, "MainMenuContinueButton") == null, "START replaces the old continue button")

	mounted["manager"].close()
	_assert_true(is_instance_valid(layer) and not layer.visible, "closing the title should hide the same layer")
	_dispose(mounted)


func _test_art_buttons_keep_their_art() -> void:
	var mounted := _mount(0, false)
	var host: Control = mounted["host"]
	for button_name in ["MainMenuStartButton", "MainMenuLanguageButton", "MainMenuExitButton"]:
		var button := Harness.find_node_by_name(host, button_name) as TextureButton
		_assert_true(button != null, "%s should be a TextureButton" % button_name)
		if button != null:
			_assert_true(button.texture_normal != null and button.texture_hover != null and button.texture_normal != button.texture_hover, "%s should swap leave art for hover art" % button_name)
	_dispose(mounted)


func _test_global_theme_walk_skips_menu() -> void:
	var mounted := _mount(0, false)
	var host: Control = mounted["host"]
	var ui_theme := GameUiThemeScript.new()
	var probe := Label.new()
	probe.name = "MainMenuWalkProbe"
	(mounted["screen"] as Node).add_child(probe)
	ui_theme.apply_ui_theme(host, {})
	_assert_true(not probe.has_theme_color_override("font_color"), "global theme walk must not restyle the menu")
	_dispose(mounted)


func _test_misspelled_palette_role_is_reported() -> void:
	var mounted := _mount(0, false)
	var layer = mounted["screen"]
	_assert_true(layer.palette_role_errors().is_empty(), "shipped main menu should have no palette role errors")
	var title := Harness.find_node_by_name(layer, "MainMenuStartButton")
	title.set_meta("palette_role", "surfce")
	var errors: PackedStringArray = layer.palette_role_errors()
	_assert_true(errors.size() == 1, "a misspelled role should be reported once")
	if errors.size() == 1:
		_assert_true(errors[0].contains("MainMenuStartButton") and errors[0].contains("surfce"), "the report should name the node and the bad role")
	_dispose(mounted)


func _test_off_grid_font_size_is_reported() -> void:
	var mounted := _mount(0, false)
	var layer = mounted["screen"]
	_assert_true(layer.font_size_errors().is_empty(), "shipped main menu should have no font size errors")
	var title := Harness.find_node_by_name(layer, "MainMenuStartButton") as Control
	title.add_theme_font_size_override("font_size", 95)
	var errors: PackedStringArray = layer.font_size_errors()
	_assert_true(errors.size() == 1, "an off-grid, over-cap size should be reported once")
	if errors.size() == 1:
		_assert_true(errors[0].contains("MainMenuStartButton") and errors[0].contains("95"), "the report should name the node and the size")
	title.add_theme_font_size_override("font_size", 99)
	_assert_true(layer.font_size_errors().size() == 1, "an on-grid size above 90 should still be reported")
	title.add_theme_font_size_override("font_size", 50)
	_assert_true(layer.font_size_errors().size() == 1, "an off-grid size under the cap should be reported")
	_dispose(mounted)


func _test_open_menu_follows_the_save() -> void:
	var mounted := _mount(0, false)
	_assert_eq(_start_intent(mounted), UiIntentsScript.START_GAME, "START starts a new game without a save")
	Harness.publish_title_facts(60, true)
	_assert_eq(_start_intent(mounted), UiIntentsScript.CONTINUE_GAME, "START continues once a save appears")
	_dispose(mounted)


func _test_closed_menu_keeps_its_last_look() -> void:
	var mounted := _mount(0, false)
	var screen: Control = mounted["screen"]
	mounted["manager"].close()
	Harness.publish_title_facts(60, true)
	_assert_true(is_instance_valid(screen) and not screen.visible, "a property change must not show a closed menu")
	_assert_eq(_start_intent(mounted), UiIntentsScript.START_GAME, "a closed menu keeps what START raised when it closed")
	_dispose(mounted)


func _test_two_open_menus_follow_the_same_facts() -> void:
	var first := _mount(0, false)
	var second := _mount(0, false)
	Harness.publish_title_facts(60, true)
	_assert_eq(_start_intent(first), UiIntentsScript.CONTINUE_GAME, "the first menu's START continues")
	_assert_eq(_start_intent(second), UiIntentsScript.CONTINUE_GAME, "the second menu's START continues")
	_dispose(first)
	_dispose(second)


func _start_intent(mounted: Dictionary) -> String:
	var heard: Array[String] = []
	var listener := func(intent_name: String, _payload: Dictionary) -> void:
		heard.append(intent_name)
	mounted["bus"].intent_emitted.connect(listener)
	var start := Harness.find_node_by_name(mounted["screen"], "MainMenuStartButton") as BaseButton
	if start != null:
		start.pressed.emit()
	mounted["bus"].intent_emitted.disconnect(listener)
	return heard.back() if not heard.is_empty() else ""


## A main menu and the dialog on one layer, with the bus, the dialog manager and a bracketing theme bound like the host does.
func _mount_with_dialog(has_save: bool) -> Dictionary:
	RegistryScript.clear()
	BootScript.install()
	Harness.publish_title_facts(0, has_save)
	var theme: GameUiTheme = GameUiThemeScript.new()
	theme.configure({"locale_translate": func(source: String) -> String: return "[%s]" % source})
	RegistryScript.bind(ServiceKeysScript.UI_THEME, theme)
	var bus: GameEventBus = GameEventBusScript.new()
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, bus)
	var bucket := Node.new()
	bucket.name = "HoldMount"
	root.add_child(bucket)
	var canvas := CanvasLayer.new()
	bucket.add_child(canvas)
	var layer := Control.new()
	layer.name = "UIRoot"
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(layer)
	var dialog_manager: ScreenManager = ScreenManagerScript.new(bus, DialogScreenScript, bucket)
	bucket.add_child(dialog_manager)
	RegistryScript.bind(ServiceKeysScript.DIALOG, dialog_manager)
	var manager: ScreenManager = ScreenManagerScript.new(bus, MainMenuScreenScript, bucket)
	bucket.add_child(manager)
	var screen: Control = manager.open({})
	await process_frame
	return {"bucket": bucket, "layer": layer, "bus": bus, "manager": manager, "dialog_manager": dialog_manager, "screen": screen, "theme": theme}


func _dispose_all(mounted: Dictionary) -> void:
	# A mouse press left down would otherwise reach the next mount's START.
	var lift := InputEventMouseButton.new()
	lift.button_index = MOUSE_BUTTON_LEFT
	lift.pressed = false
	root.push_input(lift)
	_dispose(mounted)
	RegistryScript.clear()


func _listen(mounted: Dictionary) -> Array[String]:
	var heard: Array[String] = []
	mounted["bus"].intent_emitted.connect(func(intent_name: String, _payload: Dictionary) -> void: heard.append(intent_name))
	return heard


func _held_seconds() -> float:
	var manager := RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	return float(manager.model(PropertyKeysScript.START_HOLD_SECONDS).read())


func _start(mounted: Dictionary) -> BaseButton:
	return Harness.find_node_by_name(mounted["screen"], "MainMenuStartButton") as BaseButton


## The screen's frame step with a chosen delta, so a test holds START for an exact time without waiting.
func _tick(mounted: Dictionary, delta: float) -> void:
	(mounted["screen"] as Node)._process(delta)


func _mouse_start(mounted: Dictionary, pressed: bool) -> void:
	var at := _start(mounted).get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = at
	click.global_position = at
	click.pressed = pressed
	root.push_input(click)


func _confirm(source: String, pressed: bool) -> void:
	if source == "pad":
		var button := InputEventJoypadButton.new()
		button.button_index = JOY_BUTTON_A
		button.pressed = pressed
		root.push_input(button)
		return
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER if source == "enter" else KEY_SPACE
	key.physical_keycode = key.keycode
	key.pressed = pressed
	root.push_input(key)


func _press_escape() -> void:
	for pressed in [true, false]:
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.physical_keycode = KEY_ESCAPE
		escape.pressed = pressed
		root.push_input(escape)


func _hold_until_dialog(mounted: Dictionary) -> bool:
	_mouse_start(mounted, true)
	_tick(mounted, MainMenuScreenScript.HOLD_SECONDS + 0.01)
	_assert_true(_dialog_open(mounted), "holding START should open the restart dialog")
	return _dialog_open(mounted)


func _dialog_screen(mounted: Dictionary) -> Control:
	return Harness.find_node_by_name(mounted["bucket"], "DialogLayer") as Control


func _dialog_open(mounted: Dictionary) -> bool:
	var dialog := _dialog_screen(mounted)
	return dialog != null and dialog.is_visible_in_tree()


func _dialog_buttons(mounted: Dictionary) -> Array[Button]:
	var found: Array[Button] = []
	var row := Harness.find_node_by_name(_dialog_screen(mounted), "DialogButtonRow") if _dialog_screen(mounted) != null else null
	if row == null:
		return found
	for child in row.get_children():
		if child is Button and not child.is_queued_for_deletion():
			found.append(child as Button)
	return found


func _text(host: Node, node_name: String) -> String:
	var label := Harness.find_node_by_name(host, node_name) as Label
	return label.text if label != null else ""


func _mount(pollution_value: int, has_save: bool) -> Dictionary:
	Harness.publish_title_facts(pollution_value, has_save)
	var bucket := Node.new()
	bucket.name = "MenuMount"
	root.add_child(bucket)
	var host := Control.new()
	host.name = "UIRoot"
	bucket.add_child(host)
	var bus: GameEventBus = GameEventBusScript.new()
	var manager: ScreenManager = ScreenManagerScript.new(bus, MainMenuScreenScript, host)
	bucket.add_child(manager)
	var screen: Control = manager.open({})
	return {"bucket": bucket, "host": host, "bus": bus, "manager": manager, "screen": screen}


func _dispose(mounted: Dictionary) -> void:
	var bucket: Node = mounted.get("bucket")
	if is_instance_valid(bucket):
		bucket.free()


func _font_size(host: Node, node_name: String) -> int:
	var label := Harness.find_node_by_name(host, node_name) as Label
	return label.get_theme_font_size("font_size") if label != null else -1


func _assert_color(host: Node, node_name: String, rgb: Color, alpha: float, label: String) -> void:
	var rect := Harness.find_node_by_name(host, node_name) as ColorRect
	if rect == null:
		_failures.append("%s: missing %s" % [label, node_name])
		return
	_assert_eq(_rgb(rect.color), _rgb(rgb), "%s rgb" % label)
	_assert_true(is_equal_approx(rect.color.a, alpha), "%s alpha (expected %s, got %s)" % [label, alpha, rect.color.a])


func _assert_label_color(host: Node, node_name: String, rgb: Color, alpha: float, label: String) -> void:
	var text_label := Harness.find_node_by_name(host, node_name) as Label
	if text_label == null:
		_failures.append("%s: missing %s" % [label, node_name])
		return
	var color := text_label.get_theme_color("font_color")
	_assert_eq(_rgb(color), _rgb(rgb), "%s rgb" % label)
	_assert_true(is_equal_approx(color.a, alpha), "%s alpha (expected %s, got %s)" % [label, alpha, color.a])


func _rgb(color: Color) -> Color:
	return Color(color, 1.0)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
