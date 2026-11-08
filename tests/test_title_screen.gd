extends SceneTree
## Title screen manager: first open attaches to the existing UI layer, buttons raise intents, hide then open reuses the instance.

const ScreenManagerScript = preload("res://scripts/ui/screen_manager.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const MainMenuScreenScript = preload("res://scripts/ui/main_menu_screen.gd")
const UiPaletteScript = preload("res://scripts/ui/ui_palette.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
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
	_test_buttons_raise_their_intents()
	_test_start_follows_the_save()
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


func _test_buttons_raise_their_intents() -> void:
	var mounted := _mount(0, false)
	var heard: Array[String] = []
	var payloads: Array[Dictionary] = []
	mounted["bus"].intent_emitted.connect(func(intent_name: String, payload: Dictionary) -> void:
		heard.append(intent_name)
		payloads.append(payload)
	)
	for pair in [
		["MainMenuStartButton", UiIntentsScript.START_GAME],
		["MainMenuExitButton", UiIntentsScript.EXIT_GAME],
		["MainMenuLanguageButton", UiIntentsScript.LANGUAGE_PICKER],
	]:
		var button := Harness.find_node_by_name(mounted["screen"], pair[0]) as BaseButton
		_assert_true(button != null and not button.disabled, "%s should be pressable" % pair[0])
		if button != null:
			button.pressed.emit()
			_assert_eq(heard.back() if not heard.is_empty() else "", pair[1], "%s should raise %s" % [pair[0], pair[1]])
	_assert_eq(heard.size(), 3, "the three buttons should raise one intent each")
	_assert_true(payloads.all(func(payload: Dictionary) -> bool: return payload.is_empty()), "main menu intents carry no answer")
	_dispose(mounted)


func _test_start_follows_the_save() -> void:
	var mounted := _mount(0, true)
	var heard: Array[String] = []
	mounted["bus"].intent_emitted.connect(func(intent_name: String, _payload: Dictionary) -> void:
		heard.append(intent_name)
	)
	var start := Harness.find_node_by_name(mounted["screen"], "MainMenuStartButton") as BaseButton
	start.pressed.emit()
	_assert_eq(heard, [UiIntentsScript.CONTINUE_GAME] as Array[String], "START with a save should continue")
	Harness.publish_title_facts(0, false)
	start.pressed.emit()
	_assert_eq(heard.back(), UiIntentsScript.START_GAME, "START should start a new game once the save is gone")
	Harness.publish_title_facts(0, true)
	start.pressed.emit()
	_assert_eq(heard.back(), UiIntentsScript.CONTINUE_GAME, "START should continue again once a save appears while open")
	_assert_true(Harness.find_node_by_name(mounted["screen"], "MainMenuContinueButton") == null, "the old continue button should be gone")
	_dispose(mounted)


func _test_hide_then_open_reuses_the_screen_and_refreshes_it() -> void:
	var mounted := _mount(0, false)
	var screen: Control = mounted["screen"]
	var screen_id := screen.get_instance_id()
	_assert_eq(_start_intent(mounted), UiIntentsScript.START_GAME, "START should start a new game without a save")

	mounted["manager"].close()
	_assert_true(is_instance_valid(screen) and not screen.visible, "closing the title should hide the same screen")

	Harness.publish_title_facts(60, true)
	var reopened: Control = mounted["manager"].open({})
	_assert_true(reopened == screen and screen.get_instance_id() == screen_id, "reopening should reuse the hidden screen")
	_assert_true(screen.visible and screen.get_parent() == mounted["layer"], "reopening should show the menu on the same UI layer")
	_assert_eq(_start_intent(mounted), UiIntentsScript.CONTINUE_GAME, "reopening should let START continue when a save exists")
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
	_assert_eq(_start_intent(mounted), UiIntentsScript.CONTINUE_GAME, "the kept menu should refresh START from the new open")
	_dispose(mounted)


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
