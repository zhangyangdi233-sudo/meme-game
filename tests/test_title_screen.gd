extends SceneTree
## Title screen manager: first open attaches to the existing UI layer, buttons raise intents, hide then open reuses the instance.

const ScreenManagerScript = preload("res://scripts/ui/screen_manager.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const MainMenuScreenScript = preload("res://scripts/ui/main_menu_screen.gd")
const UiPaletteScript = preload("res://scripts/ui/ui_palette.gd")
const Harness = preload("res://tests/harness/minimal_game_harness.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("title screen tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_first_open_attaches_without_clearing_the_layer()
	_test_buttons_raise_the_four_intents()
	_test_hide_then_open_reuses_the_screen_and_refreshes_it()
	_test_same_screen_survives_a_new_ui_layer()


func _test_first_open_attaches_without_clearing_the_layer() -> void:
	var mounted := _mount(0, false)
	var layer: Control = mounted["layer"]
	var sibling: Control = mounted["sibling"]
	var screen: Control = mounted["screen"]
	_assert_true(screen != null and screen.name == "MainMenuLayer", "first open should create the main menu")
	_assert_true(screen.get_parent() == layer, "first open should attach the menu to the existing UI layer")
	_assert_true(is_instance_valid(sibling) and sibling.get_parent() == layer and sibling.visible, "opening the menu should leave other layer children in place")
	_assert_eq(_count_named(mounted["host"], "MainMenuLayer"), 1, "first open should add one menu")

	var again: Control = mounted["manager"].open({})
	_assert_true(again == screen, "opening again should not create a second menu")
	_assert_eq(_count_named(mounted["host"], "MainMenuLayer"), 1, "a second open should keep a single menu")
	_dispose(mounted)


func _test_buttons_raise_the_four_intents() -> void:
	var mounted := _mount(0, true)
	var heard: Array[String] = []
	mounted["bus"].intent_emitted.connect(func(intent_name: String) -> void:
		heard.append(intent_name)
	)
	for pair in [
		["MainMenuStartButton", "start_game"],
		["MainMenuContinueButton", "continue_game"],
		["MainMenuExitButton", "exit_game"],
		["MainMenuLanguageButton", "language_picker"],
	]:
		var button := Harness.find_node_by_name(mounted["screen"], pair[0]) as Button
		_assert_true(button != null and not button.disabled, "%s should be pressable" % pair[0])
		if button != null:
			button.pressed.emit()
			_assert_eq(heard.back() if not heard.is_empty() else "", pair[1], "%s should raise %s" % [pair[0], pair[1]])
	_assert_eq(heard.size(), 4, "the four buttons should raise one intent each")
	_dispose(mounted)


func _test_hide_then_open_reuses_the_screen_and_refreshes_it() -> void:
	var mounted := _mount(0, false)
	var screen: Control = mounted["screen"]
	var screen_id := screen.get_instance_id()
	var continue_button := Harness.find_node_by_name(screen, "MainMenuContinueButton") as Button
	_assert_true(continue_button != null and continue_button.disabled, "continue should start disabled without a save")
	_assert_eq(continue_button.tooltip_text, "暂无自动存档", "continue should explain the missing save")
	_assert_color(screen, "MainMenuGreenBackground", UiPaletteScript.color(UiPaletteScript.palette("palette_1"), "menu_bg"))

	mounted["manager"].close()
	_assert_true(is_instance_valid(screen) and not screen.visible, "closing the title should hide the same screen")

	Harness.publish_title_facts(60, true)
	var polluted := UiPaletteScript.palette("pollution_palette_5")
	var reopened: Control = mounted["manager"].open({})
	_assert_true(reopened == screen and screen.get_instance_id() == screen_id, "reopening should reuse the hidden screen")
	_assert_true(screen.visible and screen.get_parent() == mounted["layer"], "reopening should show the menu on the same UI layer")
	_assert_true(not continue_button.disabled, "reopening should enable continue when a save exists")
	_assert_eq(continue_button.tooltip_text, "回到上次离开的位置", "reopening should describe the saved return")
	_assert_color(screen, "MainMenuGreenBackground", UiPaletteScript.color(polluted, "menu_bg"))
	_assert_true(mounted["sibling"].visible, "reopening should not hide other screens")
	_dispose(mounted)


func _test_same_screen_survives_a_new_ui_layer() -> void:
	var mounted := _mount(0, false)
	var screen: Control = mounted["screen"]
	var screen_id := screen.get_instance_id()
	mounted["manager"].close()
	(mounted["layer"] as Node).free()
	var replacement := Control.new()
	replacement.name = "UIRoot"
	(mounted["host"] as Node).add_child(replacement)
	var reopened: Control = mounted["manager"].open({})
	_assert_true(reopened == screen and screen.get_instance_id() == screen_id, "a new UI layer should still show the hidden menu")
	_assert_true(screen.visible and screen.get_parent() == replacement, "the hidden menu should attach to the replacement UI layer")

	mounted["manager"].retain()
	replacement.free()
	var rebuilt := Control.new()
	rebuilt.name = "UIRoot"
	(mounted["host"] as Node).add_child(rebuilt)
	Harness.publish_title_facts(0, true)
	var kept: Control = mounted["manager"].open({})
	_assert_true(kept == screen and screen.get_instance_id() == screen_id, "rebuilding the UI layer should keep the open menu")
	_assert_true(screen.visible and screen.get_parent() == rebuilt, "the kept menu should attach to the rebuilt UI layer")
	var continue_button := Harness.find_node_by_name(screen, "MainMenuContinueButton") as Button
	_assert_true(continue_button != null and not continue_button.disabled, "the kept menu should refresh continue from the new open")
	_dispose(mounted)


func _mount(pollution_value: int, has_save: bool) -> Dictionary:
	Harness.publish_title_facts(pollution_value, has_save)
	var host := Node.new()
	host.name = "LayerHost"
	root.add_child(host)
	var layer := Control.new()
	layer.name = "UIRoot"
	host.add_child(layer)
	var sibling := Control.new()
	sibling.name = "UiLayerSibling"
	layer.add_child(sibling)
	var bus: GameEventBus = GameEventBusScript.new()
	var manager: ScreenManager = ScreenManagerScript.new(bus, MainMenuScreenScript, host)
	root.add_child(manager)
	var screen: Control = manager.open({})
	return {
		"host": host,
		"layer": layer,
		"sibling": sibling,
		"bus": bus,
		"manager": manager,
		"screen": screen,
	}


func _dispose(mounted: Dictionary) -> void:
	var manager: Node = mounted["manager"]
	if is_instance_valid(manager):
		manager.free()
	var host: Node = mounted["host"]
	if is_instance_valid(host):
		host.free()


func _count_named(node: Node, target_name: String) -> int:
	if node == null:
		return 0
	var count := 1 if node.name == target_name else 0
	for child in node.get_children():
		count += _count_named(child, target_name)
	return count


func _assert_color(host: Node, node_name: String, rgb: Color) -> void:
	var rect := Harness.find_node_by_name(host, node_name) as ColorRect
	if rect == null:
		_failures.append("missing %s" % node_name)
		return
	_assert_eq(Color(rect.color, 1.0), Color(rgb, 1.0), "%s rgb" % node_name)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
