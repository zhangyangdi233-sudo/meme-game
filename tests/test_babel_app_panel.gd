extends SceneTree
## Shown babel app watches the floor, money, and pollution models and repaints itself; hiding or freeing unregisters.

const BootScript = preload("res://scripts/game/property_boot.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const BabelAppPanelScript = preload("res://scripts/ui/babel_app_panel.gd")
const Harness = preload("res://tests/harness/minimal_game_harness.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_deferred")


func _run_deferred() -> void:
	await _run()
	if _failures.is_empty():
		print("babel app panel tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_showing_registers_once_and_follows_writes()
	_test_hiding_unregisters_and_showing_again_syncs()
	await _test_a_freed_panel_unregisters()


func _test_showing_registers_once_and_follows_writes() -> void:
	var mounted := _mount()
	var panel: BabelAppPanel = mounted["panel"]
	var floor_model: ValuePropertyModel = mounted["floor"]
	var money: ValuePropertyModel = mounted["money"]
	var pollution: ValuePropertyModel = mounted["pollution"]
	panel.render(mounted["body"])
	_assert_eq(_heading(mounted), "F1", "rendering should paint the floor from its model")
	_assert_eq(_listener_count(floor_model), 0, "a rendered babel app should not listen before it is shown")

	panel.set_shown(true)
	_assert_eq(_listener_count(floor_model), 1, "showing should register on the floor once")
	_assert_eq(_listener_count(money), 1, "showing should register on money once")
	_assert_eq(_listener_count(pollution), 1, "showing should register on pollution once")
	panel.set_shown(true)
	_assert_eq(_listener_count(floor_model), 1, "showing again should not register twice")

	floor_model.write(3)
	_assert_eq(_heading(mounted), "F3", "a floor write should repaint the heading by itself")
	money.write(42)
	_assert_true(_text(mounted).contains("资金 42"), "a money write should repaint the money line by itself")
	pollution.write(37)
	_assert_true(_text(mounted).contains("污染 37%"), "a pollution write should repaint the pollution line by itself")
	_dispose(mounted)


func _test_hiding_unregisters_and_showing_again_syncs() -> void:
	var mounted := _mount()
	var panel: BabelAppPanel = mounted["panel"]
	var floor_model: ValuePropertyModel = mounted["floor"]
	var money: ValuePropertyModel = mounted["money"]
	var pollution: ValuePropertyModel = mounted["pollution"]
	panel.render(mounted["body"])
	panel.set_shown(true)
	panel.set_shown(false)
	_assert_eq(_listener_count(floor_model), 0, "hiding should drop the floor listener")
	_assert_eq(_listener_count(money), 0, "hiding should drop the money listener")
	_assert_eq(_listener_count(pollution), 0, "hiding should drop the pollution listener")

	floor_model.write(2)
	_assert_eq(_heading(mounted), "F1", "a hidden babel app should not repaint on a write")
	panel.set_shown(true)
	_assert_eq(_heading(mounted), "F2", "showing again should sync a floor written while hidden")
	_dispose(mounted)


func _test_a_freed_panel_unregisters() -> void:
	var mounted := _mount()
	var panel: BabelAppPanel = mounted["panel"]
	var floor_model: ValuePropertyModel = mounted["floor"]
	panel.render(mounted["body"])
	panel.set_shown(true)
	panel.queue_free()
	await process_frame
	_assert_eq(_listener_count(floor_model), 0, "freeing the babel app should drop its listeners")
	floor_model.write(4)
	_dispose(mounted)


func _mount() -> Dictionary:
	RegistryScript.clear()
	BootScript.install()
	var manager: PropertyManager = RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	var body := VBoxContainer.new()
	body.name = "BabelBody"
	root.add_child(body)
	var panel: BabelAppPanel = BabelAppPanelScript.new()
	panel.name = "BabelAppPanelHost"
	root.add_child(panel)
	panel.configure({
		"label_factory": _label,
		"theme_color": func(_key: String) -> Color: return Color.WHITE,
		"clear_children": _clear,
		"event_log": func() -> Array: return [],
		"level_display_name": func(floor_number: int) -> String: return "F%d" % floor_number,
	})
	return {
		"panel": panel,
		"body": body,
		"floor": manager.model(PropertyKeysScript.TOWER_FLOOR),
		"money": manager.model(PropertyKeysScript.MONEY),
		"pollution": manager.model(PropertyKeysScript.POLLUTION),
	}


func _dispose(mounted: Dictionary) -> void:
	for key in ["panel", "body"]:
		var node: Variant = mounted[key]
		if is_instance_valid(node):
			(node as Node).free()
	RegistryScript.clear()


func _heading(mounted: Dictionary) -> String:
	var heading := Harness.find_node_by_name(mounted["body"], "BabelFloorHeading") as Label
	return heading.text if heading != null else ""


func _text(mounted: Dictionary) -> String:
	return Harness.collect_control_text(mounted["body"])


func _listener_count(model: PropertyModel) -> int:
	if model == null:
		return -1
	return model.changed.get_connections().size()


func _label(text: String, _size: int, _color: Color) -> Label:
	var label_node := Label.new()
	label_node.text = text
	return label_node


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.free()


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
