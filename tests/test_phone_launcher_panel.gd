extends SceneTree
## Phone launcher watches whether the phone is open and which app is in front on their property models.

const BootScript = preload("res://scripts/game/property_boot.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("phone launcher panel tests passed")
		RegistryScript.clear()
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		RegistryScript.clear()
		quit(1)


func _run() -> void:
	_test_showing_registers_once_and_syncs_both_models()
	_test_opening_and_closing_the_phone_updates_the_popup()
	_test_choosing_an_app_raises_its_window()
	_test_social_notebook_and_map_are_offered()
	_test_hiding_unregisters_and_later_writes_are_ignored()
	_test_mounting_again_while_shown_keeps_one_registration()
	_test_a_freed_panel_unregisters()
	_test_a_mounted_panel_is_not_opened_by_a_write()
	_test_locked_apps_do_nothing_until_unlocked()
	_test_the_phone_slides_in_and_out_from_the_right()


func _test_showing_registers_once_and_syncs_both_models() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as PhoneLauncherPanel
	var open: ValuePropertyModel = mounted["open"]
	var window: ValuePropertyModel = mounted["window"]
	_assert_eq(_listener_count(open), 0, "a mounted panel should not listen before it is shown")
	_assert_eq(_listener_count(window), 0, "a mounted panel should not listen to the foreground before it is shown")

	open.write(false)
	panel.set_shown(true)
	_assert_eq(_listener_count(open), 1, "showing should register on the phone model")
	_assert_eq(_listener_count(window), 1, "showing should register on the foreground model")
	_assert_true(not panel.get_phone_panel().visible, "showing should sync a closed phone at once")
	panel.set_shown(true)
	_assert_eq(_listener_count(open), 1, "showing again should not register twice")
	_assert_eq(_listener_count(window), 1, "showing again should not register the foreground twice")
	_dispose(mounted)


func _test_opening_and_closing_the_phone_updates_the_popup() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as PhoneLauncherPanel
	var open: ValuePropertyModel = mounted["open"]
	panel.set_shown(true)
	_assert_true(panel.get_phone_panel().visible, "an open phone should show the popup")
	_assert_true(panel.get_phone_content().visible, "an open phone should show the popup content")

	var open_top: float = panel.get_phone_panel().offset_top
	open.write(false)
	panel._process(1.0)
	_assert_true(not panel.get_phone_panel().visible, "closing the phone should hide the popup by itself")
	_assert_true(not panel.get_phone_content().visible, "closing the phone should hide the popup content by itself")
	_assert_true(not is_equal_approx(panel.get_phone_panel().offset_top, open_top), "closing the phone should fold the popup")

	open.write(true)
	panel._process(1.0)
	_assert_true(panel.get_phone_panel().visible, "opening the phone should show the popup by itself")
	_assert_true(panel.get_phone_content().visible, "opening the phone should show the popup content by itself")
	_assert_true(is_equal_approx(panel.get_phone_panel().offset_top, open_top), "opening the phone should unfold the popup")
	_dispose(mounted)


func _test_choosing_an_app_raises_its_window() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as PhoneLauncherPanel
	var window: ValuePropertyModel = mounted["window"]
	var host := mounted["host"] as Control
	panel.set_shown(true)
	var notebook := panel.get_app_window("notebook")
	var other := Control.new()
	host.add_child(other)
	_assert_eq(host.get_child(host.get_child_count() - 1), other, "another window should be last before any raise")

	window.write("notebook")
	_assert_eq(host.get_child(host.get_child_count() - 1), notebook, "choosing notebook should raise its window by itself")
	window.write("")
	window.write("social")
	_assert_eq(host.get_child(host.get_child_count() - 1), notebook, "an app the launcher does not own should not move its windows")
	_dispose(mounted)


## The phone offers the social app and the notebook; the tower app is gone.
func _test_social_notebook_and_map_are_offered() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as PhoneLauncherPanel
	var host := mounted["host"] as Control
	var icons: Array[String] = []
	for node in host.find_children("PhoneAppIcon*", "Button", true, false):
		icons.append(str(node.name))
	_assert_eq(icons, ["PhoneAppIconSocial", "PhoneAppIconNotebook", "PhoneAppIconMap"], "the launcher should offer social media, the notebook and the map")
	_assert_true(panel.get_app_window("babel") == null, "the launcher should build no tower app window")
	_assert_true(host.find_child("BabelAppWindow", true, false) == null, "no tower app window should be in the tree")
	_dispose(mounted)


func _test_hiding_unregisters_and_later_writes_are_ignored() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as PhoneLauncherPanel
	var open: ValuePropertyModel = mounted["open"]
	var window: ValuePropertyModel = mounted["window"]
	panel.set_shown(true)
	panel.set_shown(false)
	_assert_eq(_listener_count(open), 0, "hiding should unregister from the phone model")
	_assert_eq(_listener_count(window), 0, "hiding should unregister from the foreground model")
	_assert_true(not panel.get_phone_panel().visible, "hiding should hide the popup")

	open.write(false)
	open.write(true)
	_assert_true(not panel.get_phone_panel().visible, "a hidden panel should not reappear on a later write")

	panel.set_shown(true)
	_assert_true(panel.get_phone_panel().visible, "showing again should sync the current phone state")
	_assert_eq(_listener_count(open), 1, "showing again should register again")
	_dispose(mounted)


func _test_mounting_again_while_shown_keeps_one_registration() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as PhoneLauncherPanel
	var open: ValuePropertyModel = mounted["open"]
	var window: ValuePropertyModel = mounted["window"]
	panel.set_shown(true)
	panel.get_phone_panel().free()
	panel.mount(mounted["host"], mounted["deps"])
	_assert_eq(_listener_count(open), 1, "mounting again while shown should keep one phone registration")
	_assert_eq(_listener_count(window), 1, "mounting again while shown should keep one foreground registration")
	_assert_true(panel.get_phone_panel().visible, "a rebuilt popup should sync the open phone at once")
	open.write(false)
	panel._process(1.0)
	_assert_true(not panel.get_phone_panel().visible, "a rebuilt popup should follow the model")
	_dispose(mounted)


func _test_a_freed_panel_unregisters() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as PhoneLauncherPanel
	var open: ValuePropertyModel = mounted["open"]
	var window: ValuePropertyModel = mounted["window"]
	panel.set_shown(true)
	panel.free()
	mounted["panel"] = null
	_assert_eq(_listener_count(open), 0, "a freed panel should unregister from the phone model")
	_assert_eq(_listener_count(window), 0, "a freed panel should unregister from the foreground model")
	_dispose(mounted)


func _test_a_mounted_panel_is_not_opened_by_a_write() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as PhoneLauncherPanel
	var open: ValuePropertyModel = mounted["open"]
	panel.get_phone_panel().visible = false
	open.write(false)
	open.write(true)
	_assert_true(not panel.get_phone_panel().visible, "a model write should not open a phone the play chrome has not shown")
	_dispose(mounted)


## A locked app's icon is disabled and a press raises nothing; the models unlock it. The map's icon shows locked too.
func _test_locked_apps_do_nothing_until_unlocked() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as PhoneLauncherPanel
	var host := mounted["host"] as Control
	var unlocked: ListPropertyModel = mounted["unlocked"]
	var heard: Array = []
	var listener := func(intent: String, payload: Dictionary) -> void: heard.append([intent, payload])
	var bus := GameEventBusScript.new()
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, bus)
	bus.intent_emitted.connect(listener)
	panel.set_shown(true)
	var social := host.find_child("PhoneAppIconSocial", true, false) as Button
	var notebook := host.find_child("PhoneAppIconNotebook", true, false) as Button
	var map := host.find_child("PhoneAppIconMap", true, false) as Button
	_assert_true(social.disabled and notebook.disabled, "both icons should start locked")
	_assert_true(map != null and map.disabled, "the map's icon should show locked")
	social.pressed.emit()
	notebook.pressed.emit()
	if map != null:
		map.pressed.emit()
	_assert_eq(heard, [], "a locked icon should raise nothing")
	unlocked.add("social")
	_assert_true(not social.disabled, "the unlocked social feed's icon should be pressable")
	_assert_true(notebook.disabled, "the notebook should stay locked")
	social.pressed.emit()
	notebook.pressed.emit()
	_assert_eq(heard, [[UiIntentsScript.APP_ICON_PRESSED, {UiIntentsScript.KEY_APP_ID: "social"}]], "only the unlocked icon should raise its app")
	unlocked.add("notebook")
	_assert_true(not notebook.disabled, "the unlocked notebook's icon should be pressable")
	panel.set_shown(false)
	unlocked.replace_all([])
	_assert_true(not notebook.disabled, "a hidden launcher should not follow the model")
	panel.set_shown(true)
	_assert_true(social.disabled and notebook.disabled, "showing again should sync the locks")
	_dispose(mounted)


## The phone slides in from the right edge when it opens and slides back out before it hides; showing the launcher
## places it at once.
func _test_the_phone_slides_in_and_out_from_the_right() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as PhoneLauncherPanel
	var open: ValuePropertyModel = mounted["open"]
	panel.set_shown(true)
	var popup := panel.get_phone_panel()
	var rest_left := popup.offset_left
	var rest_right := popup.offset_right
	open.write(false)
	_assert_true(popup.visible, "a closing phone should stay on screen while it slides out")
	panel._process(0.1)
	_assert_true(popup.offset_left > rest_left and popup.visible, "a closing phone should move toward the right edge")
	panel._process(1.0)
	_assert_true(not popup.visible, "a phone that slid out should hide")
	open.write(true)
	_assert_true(popup.visible, "an opening phone should show at once")
	_assert_true(popup.offset_left >= rest_right, "an opening phone should start off the right edge")
	panel._process(0.1)
	_assert_true(popup.offset_left > rest_left and popup.offset_left < rest_right, "an opening phone should slide in")
	_assert_eq(popup.mouse_behavior_recursive, Control.MOUSE_BEHAVIOR_DISABLED, "a sliding phone should take no clicks")
	panel._process(1.0)
	_assert_true(is_equal_approx(popup.offset_left, rest_left), "an opened phone should rest where it was")
	_assert_true(is_equal_approx(popup.offset_right, rest_right), "an opened phone should rest at its right margin")
	_assert_eq(popup.mouse_behavior_recursive, Control.MOUSE_BEHAVIOR_INHERITED, "a resting phone should take clicks again")
	_dispose(mounted)


func _mount() -> Dictionary:
	RegistryScript.clear()
	BootScript.install()
	var manager: PropertyManager = RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	var host := Control.new()
	host.name = "PhoneHost"
	host.size = Vector2(1600, 900)
	root.add_child(host)
	var panel := PhoneLauncherPanel.new()
	panel.name = "PhoneLauncherPanelHost"
	root.add_child(panel)
	RegistryScript.bind(ServiceKeysScript.UI_THEME, GameUiThemeScript.new())
	var deps := {
		"viewport_size": func() -> Vector2: return Vector2(1600, 900),
	}
	panel.mount(host, deps)
	return {
		"deps": deps,
		"host": host,
		"panel": panel,
		"open": manager.model(PropertyKeysScript.PHONE_OPEN),
		"window": manager.model(PropertyKeysScript.ACTIVE_APP_WINDOW),
		"unlocked": manager.model(PropertyKeysScript.UNLOCKED_APPS),
	}


func _dispose(mounted: Dictionary) -> void:
	var panel: Node = mounted["panel"]
	if panel != null and is_instance_valid(panel):
		panel.free()
	var host: Node = mounted["host"]
	if host != null and is_instance_valid(host):
		host.free()
	RegistryScript.clear()


func _listener_count(model: PropertyModel) -> int:
	if model == null:
		return -1
	return model.changed.get_connections().size()


func _label(text: String, _size: int, _color: Color) -> Label:
	var label_node := Label.new()
	label_node.text = text
	return label_node


func _theme_color(_key: String) -> Color:
	return Color("F5F7F2")


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
