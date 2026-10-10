extends SceneTree
## Left status column watches money and remaining actions on the property models.

const BootScript = preload("res://scripts/game/property_boot.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const Harness = preload("res://tests/harness/minimal_game_harness.gd")

const FULL_ACTIONS := "今日行动\n● ● ● ● ●"
const THREE_ACTIONS := "今日行动\n● ● ● ○ ○"
const ONE_ACTION := "今日行动\n● ○ ○ ○ ○"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _run()
	if _failures.is_empty():
		print("apple hud panel tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_shown_column_syncs_then_follows_writes()
	await _test_hidden_and_freed_column_stops_listening()


func _test_shown_column_syncs_then_follows_writes() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as AppleHudPanel
	var money: ValuePropertyModel = mounted["money"]
	var actions: ValuePropertyModel = mounted["actions"]
	var actions_label: Label = panel.get_actions_label()
	var money_icon := Harness.find_node_by_name(mounted["host"], "HUDMoneyIcon") as Button
	var pollution_icon := Harness.find_node_by_name(mounted["host"], "HUDPollutionIcon") as Button
	var rail: PanelContainer = panel.get_rail()
	_assert_eq(_listener_count(money), 0, "a mounted column should not listen before it is shown")
	_assert_eq(actions_label.text, "", "a hidden column should not paint actions yet")

	panel.set_shown(true)
	_assert_eq(_listener_count(money), 1, "showing the column should register money once")
	_assert_eq(_listener_count(actions), 1, "showing the column should register remaining actions once")
	panel.set_shown(true)
	_assert_eq(_listener_count(money), 1, "showing the column again should not register twice")
	_assert_eq(actions_label.text, FULL_ACTIONS, "showing the column should paint the current actions")
	money_icon.mouse_entered.emit()
	var tooltip: Label = Harness.find_node_by_name(mounted["host"], "HUDTooltipLabel") as Label
	_assert_eq(tooltip.text, "资金 18", "showing the column should sync the current money")

	var icon_size := money_icon.custom_minimum_size
	var icon_position := money_icon.position
	var pollution_position := pollution_icon.position
	var rail_left := rail.offset_left
	var rail_right := rail.offset_right
	money.write(31)
	actions.write(3)
	_assert_eq(tooltip.text, "资金 31", "an open money tooltip should follow the model")
	_assert_eq(actions_label.text, THREE_ACTIONS, "the action dots should follow remaining actions")
	_assert_eq(money_icon.custom_minimum_size, icon_size, "the money icon size should stay put")
	_assert_eq(money_icon.position, icon_position, "the money icon position should stay put")
	_assert_eq(pollution_icon.position, pollution_position, "the pollution icon position should stay put")
	_assert_eq(rail.offset_left, rail_left, "the rail's left edge should stay put")
	_assert_eq(rail.offset_right, rail_right, "the rail's right edge should stay put")
	_assert_true(str(actions_label.text).contains("●") and str(actions_label.text).contains("○"), "action marks should stay filled and empty dots")

	panel.render({
		"pollution": 12,
		"tooltips": {"pollution": "污染 12%", "settings": "设置"},
	})
	_assert_eq(actions_label.text, THREE_ACTIONS, "a pushed pollution snapshot should not rewrite actions")
	_assert_eq(tooltip.text, "资金 31", "a pushed pollution snapshot should not rewrite money")
	_dispose(mounted)


func _test_hidden_and_freed_column_stops_listening() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as AppleHudPanel
	var money: ValuePropertyModel = mounted["money"]
	var actions: ValuePropertyModel = mounted["actions"]
	panel.set_shown(true)
	var actions_label: Label = panel.get_actions_label()
	var money_icon := Harness.find_node_by_name(mounted["host"], "HUDMoneyIcon") as Button
	money_icon.mouse_entered.emit()
	var tooltip: Label = Harness.find_node_by_name(mounted["host"], "HUDTooltipLabel") as Label
	money.write(31)
	actions.write(3)

	panel.set_shown(false)
	_assert_eq(_listener_count(money), 0, "hiding the column should drop the money listener")
	_assert_eq(_listener_count(actions), 0, "hiding the column should drop the actions listener")
	money.write(99)
	actions.write(1)
	_assert_eq(actions_label.text, THREE_ACTIONS, "a hidden column should keep the last action dots")
	_assert_eq(tooltip.text, "资金 31", "a hidden column should keep the last money text")

	panel.set_shown(true)
	_assert_eq(actions_label.text, ONE_ACTION, "showing the column again should sync the latest actions")
	_assert_eq(tooltip.text, "资金 99", "showing the column again should sync the latest money")

	panel.queue_free()
	await process_frame
	_assert_eq(_listener_count(money), 0, "freeing the column should drop the money listener")
	_assert_eq(_listener_count(actions), 0, "freeing the column should drop the actions listener")
	var kept_actions := actions_label.text
	var kept_money := tooltip.text
	money.write(4)
	actions.write(0)
	_assert_eq(actions_label.text, kept_actions, "a freed column should ignore later action writes")
	_assert_eq(tooltip.text, kept_money, "a freed column should ignore later money writes")
	mounted["host"].queue_free()


func _mount() -> Dictionary:
	RegistryScript.clear()
	BootScript.install()
	var manager: PropertyManager = RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	var host := Control.new()
	host.name = "HudHost"
	host.size = Vector2(1600, 900)
	root.add_child(host)
	var panel := AppleHudPanel.new()
	panel.name = "AppleHudPanelHost"
	root.add_child(panel)
	panel.mount(host, {
		"panel_factory": _panel,
		"label_factory": _label,
		"theme_color": _theme_color,
		"style_factory": _style,
		"rail_width": 158.0,
		"max_actions": func() -> int: return 5,
	})
	return {
		"host": host,
		"panel": panel,
		"money": manager.model(PropertyKeysScript.MONEY),
		"actions": manager.model(PropertyKeysScript.ACTIONS_REMAINING),
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


func _panel() -> PanelContainer:
	return PanelContainer.new()


func _label(text: String, _size: int, _color: Color) -> Label:
	var label_node := Label.new()
	label_node.text = text
	return label_node


func _theme_color(_key: String) -> Color:
	return Color("F5F7F2")


func _style(_bg: Color, _border: Color) -> StyleBoxFlat:
	return StyleBoxFlat.new()


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
