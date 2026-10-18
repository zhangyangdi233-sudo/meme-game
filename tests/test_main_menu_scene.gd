extends SceneTree
## Main menu layout scene: node contract, palette roles under both palettes, and isolation from the global UI theme walk.

const ScreenManagerScript = preload("res://scripts/ui/screen_manager.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const MainMenuScreenScript = preload("res://scripts/ui/main_menu_screen.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const Harness = preload("res://tests/harness/minimal_game_harness.gd")

const POLLUTED_STAGE := {"palette_key": "pollution_palette_5"}

var _failures: Array[String] = []


func _init() -> void:
	_run()
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
