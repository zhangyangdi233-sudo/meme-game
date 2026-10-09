extends SceneTree
## Main menu layout scene: node contract, palette roles under both palettes, and isolation from the global UI theme walk.

const ScreenManagerScript = preload("res://scripts/ui/screen_manager.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const MainMenuScreenScript = preload("res://scripts/ui/main_menu_screen.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const UiPaletteScript = preload("res://scripts/ui/ui_palette.gd")
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
	_test_mount_tints_with_clean_palette()
	_test_mount_tints_with_polluted_palette()
	_test_open_menu_follows_pollution_and_save()
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
		"MainMenuGreenBackground",
		"MainMenuTextStack",
		"MainMenuChapter",
		"MainMenuTitle",
		"MainMenuSubtitle",
		"MainMenuButtons",
		"MainMenuContinueButton",
		"MainMenuStartButton",
		"MainMenuExitButton",
		"MainMenuLanguageButton",
		"MainMenuCornerMark",
		"MainMenuPosterStripe0",
		"MainMenuBlackCut6",
	]:
		_assert_true(Harness.find_node_by_name(host, node_name) != null, "main menu should keep node %s" % node_name)

	_assert_eq(_font_size(host, "MainMenuTitle"), 90, "title should render at 90")
	_assert_eq(_font_size(host, "MainMenuChapter"), 54, "chapter should render at 54")
	_assert_eq(_font_size(host, "MainMenuSubtitle"), 27, "subtitle should render at 27")

	var continue_button := Harness.find_node_by_name(host, "MainMenuContinueButton") as Button
	_assert_true(continue_button != null and continue_button.disabled, "continue should be disabled without a save")
	var exit_button := Harness.find_node_by_name(host, "MainMenuExitButton") as Button
	_assert_true(exit_button != null and bool(exit_button.get_meta("skip_localization", false)), "exit button should skip localization")

	mounted["manager"].close()
	_assert_true(is_instance_valid(layer) and not layer.visible, "closing the title should hide the same layer")
	_dispose(mounted)


func _test_mount_tints_with_clean_palette() -> void:
	var palette := UiPaletteScript.palette("palette_1")
	var mounted := _mount(0, true)
	var host: Control = mounted["host"]
	_assert_color(host, "MainMenuGreenBackground", UiPaletteScript.color(palette, "menu_bg"), 1.0, "clean background")
	_assert_label_color(host, "MainMenuTitle", UiPaletteScript.color(palette, "surface"), 1.0, "clean title")
	_assert_label_color(host, "MainMenuChapter", UiPaletteScript.color(palette, "surface"), 0.82, "clean chapter keeps its alpha")
	_assert_color(host, "MainMenuBlackCut0", UiPaletteScript.color(palette, "ink"), 1.0, "clean cut")
	var title := Harness.find_node_by_name(host, "MainMenuTitle") as Label
	_assert_eq(_rgb(title.get_theme_color("font_shadow_color")), _rgb(UiPaletteScript.color(palette, "ink")), "title shadow should use ink")

	var continue_button := Harness.find_node_by_name(host, "MainMenuContinueButton") as Button
	_assert_true(not continue_button.disabled, "continue should be enabled with a save")
	var normal := continue_button.get_theme_stylebox("normal") as StyleBoxFlat
	_assert_true(normal != null, "buttons should use the shared flat button style")
	if normal != null:
		_assert_eq(normal.bg_color, UiPaletteScript.color(palette, "surface"), "button normal style should use surface")
	_dispose(mounted)


func _test_mount_tints_with_polluted_palette() -> void:
	var palette := UiPaletteScript.palette("pollution_palette_5")
	var mounted := _mount(60, false)
	var host: Control = mounted["host"]
	_assert_color(host, "MainMenuGreenBackground", UiPaletteScript.color(palette, "menu_bg"), 1.0, "polluted background")
	_assert_label_color(host, "MainMenuSubtitle", UiPaletteScript.color(palette, "surface"), 0.78, "polluted subtitle keeps its alpha")
	_assert_color(host, "MainMenuPosterStripe0", UiPaletteScript.color(palette, "surface"), 0.96, "polluted even stripe keeps its alpha")
	_assert_color(host, "MainMenuPosterStripe1", UiPaletteScript.color(palette, "surface"), 0.0, "polluted odd stripe stays transparent")
	_dispose(mounted)


func _test_global_theme_walk_skips_menu() -> void:
	var mounted := _mount(0, false)
	var host: Control = mounted["host"]
	var ui_theme := GameUiThemeScript.new()
	ui_theme.apply_ui_theme(host, {})
	var palette := UiPaletteScript.palette("palette_1")
	_assert_label_color(host, "MainMenuTitle", UiPaletteScript.color(palette, "surface"), 1.0, "global theme walk must not repaint the title")
	_dispose(mounted)


func _test_misspelled_palette_role_is_reported() -> void:
	var mounted := _mount(0, false)
	var layer = mounted["screen"]
	_assert_true(layer.palette_role_errors().is_empty(), "shipped main menu should have no palette role errors")
	var title := Harness.find_node_by_name(layer, "MainMenuTitle")
	title.set_meta("palette_role", "surfce")
	var errors: PackedStringArray = layer.palette_role_errors()
	_assert_true(errors.size() == 1, "a misspelled role should be reported once")
	if errors.size() == 1:
		_assert_true(errors[0].contains("MainMenuTitle") and errors[0].contains("surfce"), "the report should name the node and the bad role")
	_dispose(mounted)


func _test_off_grid_font_size_is_reported() -> void:
	var mounted := _mount(0, false)
	var layer = mounted["screen"]
	_assert_true(layer.font_size_errors().is_empty(), "shipped main menu should have no font size errors")
	var title := Harness.find_node_by_name(layer, "MainMenuTitle") as Label
	title.add_theme_font_size_override("font_size", 95)
	var errors: PackedStringArray = layer.font_size_errors()
	_assert_true(errors.size() == 1, "an off-grid, over-cap size should be reported once")
	if errors.size() == 1:
		_assert_true(errors[0].contains("MainMenuTitle") and errors[0].contains("95"), "the report should name the node and the size")
	title.add_theme_font_size_override("font_size", 99)
	_assert_true(layer.font_size_errors().size() == 1, "an on-grid size above 90 should still be reported")
	title.add_theme_font_size_override("font_size", 50)
	_assert_true(layer.font_size_errors().size() == 1, "an off-grid size under the cap should be reported")
	_dispose(mounted)


func _test_open_menu_follows_pollution_and_save() -> void:
	var mounted := _mount(0, false)
	var host: Control = mounted["host"]
	var clean := UiPaletteScript.palette("palette_1")
	_assert_color(host, "MainMenuGreenBackground", UiPaletteScript.color(clean, "menu_bg"), 1.0, "open menu starts clean")
	var continue_button := Harness.find_node_by_name(host, "MainMenuContinueButton") as Button
	_assert_true(continue_button.disabled, "continue starts disabled")
	_assert_eq(continue_button.tooltip_text, "暂无自动存档", "continue starts without a save")

	Harness.publish_title_facts(60, true)
	var polluted := UiPaletteScript.palette("pollution_palette_5")
	_assert_color(host, "MainMenuGreenBackground", UiPaletteScript.color(polluted, "menu_bg"), 1.0, "open menu retints when pollution changes")
	_assert_true(not continue_button.disabled, "continue enables when a save appears")
	_assert_eq(continue_button.tooltip_text, "回到上次离开的位置", "continue explains the save")
	_dispose(mounted)


func _test_closed_menu_keeps_its_last_look() -> void:
	var mounted := _mount(0, false)
	var screen: Control = mounted["screen"]
	var background := Harness.find_node_by_name(screen, "MainMenuGreenBackground") as ColorRect
	var continue_button := Harness.find_node_by_name(screen, "MainMenuContinueButton") as Button
	var clean := background.color
	mounted["manager"].close()
	Harness.publish_title_facts(60, true)
	_assert_true(is_instance_valid(screen) and not screen.visible, "a property change must not show a closed menu")
	_assert_eq(Color(background.color, 1.0), Color(clean, 1.0), "a closed menu keeps its last background")
	_assert_true(continue_button != null and continue_button.disabled, "a closed menu keeps continue disabled")
	_assert_eq(continue_button.tooltip_text, "暂无自动存档", "a closed menu keeps the empty-save tooltip")
	_dispose(mounted)


func _test_two_open_menus_follow_the_same_facts() -> void:
	var first := _mount(0, false)
	var second := _mount(0, false)
	Harness.publish_title_facts(60, true)
	var polluted := UiPaletteScript.color(UiPaletteScript.palette("pollution_palette_5"), "menu_bg")
	_assert_color(first["host"], "MainMenuGreenBackground", polluted, 1.0, "first menu follows pollution")
	_assert_color(second["host"], "MainMenuGreenBackground", polluted, 1.0, "second menu follows pollution")
	var first_continue := Harness.find_node_by_name(first["host"], "MainMenuContinueButton") as Button
	var second_continue := Harness.find_node_by_name(second["host"], "MainMenuContinueButton") as Button
	_assert_true(not first_continue.disabled and not second_continue.disabled, "both menus enable continue")
	_dispose(first)
	_dispose(second)


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
	return {"bucket": bucket, "host": host, "manager": manager, "screen": screen}


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
