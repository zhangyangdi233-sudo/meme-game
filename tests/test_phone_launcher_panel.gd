extends SceneTree
## Phone launcher watches whether the phone is open and which app is in front on their property models.

const BootScript = preload("res://scripts/game/property_boot.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("phone launcher panel tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_showing_registers_once_and_syncs_both_models()
	_test_opening_and_closing_the_phone_updates_the_popup()
	_test_choosing_an_app_raises_its_window()
	_test_hiding_unregisters_and_later_writes_are_ignored()
	_test_mounting_again_while_shown_keeps_one_registration()
	_test_a_freed_panel_unregisters()
	_test_a_mounted_panel_is_not_opened_by_a_write()


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
	_assert_true(not panel.get_phone_panel().visible, "closing the phone should hide the popup by itself")
	_assert_true(not panel.get_phone_content().visible, "closing the phone should hide the popup content by itself")
	_assert_true(not is_equal_approx(panel.get_phone_panel().offset_top, open_top), "closing the phone should fold the popup")

	open.write(true)
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
	var babel := panel.get_app_window("babel")
	var notebook := panel.get_app_window("notebook")
	_assert_eq(host.get_child(host.get_child_count() - 1), notebook, "the notebook window should be last before any raise")

	window.write("babel")
	_assert_eq(host.get_child(host.get_child_count() - 1), babel, "choosing babel should raise its window by itself")
	window.write("notebook")
	_assert_eq(host.get_child(host.get_child_count() - 1), notebook, "choosing notebook should raise its window by itself")
	window.write("")
	window.write("social")
	_assert_eq(host.get_child(host.get_child_count() - 1), notebook, "an app the launcher does not own should not move its windows")
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
	var deps := {
		"panel_factory": func() -> PanelContainer: return PanelContainer.new(),
		"label_factory": _label,
		"theme_color": _theme_color,
		"viewport_size": func() -> Vector2: return Vector2(1600, 900),
	}
	panel.mount(host, deps)
	return {
		"deps": deps,
		"host": host,
		"panel": panel,
		"open": manager.model(PropertyKeysScript.PHONE_OPEN),
		"window": manager.model(PropertyKeysScript.ACTIVE_APP_WINDOW),
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
