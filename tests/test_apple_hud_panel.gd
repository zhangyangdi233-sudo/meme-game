extends SceneTree
## Left status column watches pollution on the property models; it shows no funds and no daily actions.

const BootScript = preload("res://scripts/game/property_boot.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const Harness = preload("res://tests/harness/minimal_game_harness.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _run()
	if _failures.is_empty():
		print("apple hud panel tests passed")
		RegistryScript.clear()
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		RegistryScript.clear()
		quit(1)


func _run() -> void:
	_test_shown_column_syncs_then_follows_writes()
	_test_the_column_shows_no_funds_or_actions()
	_test_the_rail_is_edged_by_the_hairline()
	await _test_hidden_and_freed_column_stops_listening()


func _test_shown_column_syncs_then_follows_writes() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as AppleHudPanel
	var pollution: ValuePropertyModel = mounted["pollution"]
	var pollution_icon := Harness.find_node_by_name(mounted["host"], "HUDPollutionIcon") as Button
	var rail: PanelContainer = panel.get_rail()
	_assert_eq(_listener_count(pollution), 0, "a mounted column should not listen before it is shown")
	panel.set_shown(true)
	panel.set_shown(true)
	_assert_eq(_listener_count(pollution), 1, "showing the column should register pollution once")
	var tooltip: Label = Harness.find_node_by_name(mounted["host"], "HUDTooltipLabel") as Label
	var pollution_position := pollution_icon.position
	var rail_left := rail.offset_left
	var rail_right := rail.offset_right
	pollution.write(12)
	pollution_icon.mouse_entered.emit()
	_assert_eq(tooltip.text, "污染 12%", "the pollution tooltip should show the model's pollution")
	pollution.write(40)
	_assert_eq(tooltip.text, "污染 40%", "an open pollution tooltip should follow the model")
	_assert_eq(pollution_icon.position, pollution_position, "the pollution icon position should stay put")
	_assert_eq(rail.offset_left, rail_left, "the rail's left edge should stay put")
	_assert_eq(rail.offset_right, rail_right, "the rail's right edge should stay put")
	_dispose(mounted)


func _test_the_column_shows_no_funds_or_actions() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as AppleHudPanel
	panel.set_shown(true)
	for node_name in ["HUDMoneyIcon", "HUDActionsLabel"]:
		_assert_true(Harness.find_node_by_name(mounted["host"], node_name) == null, "the column should not build %s" % node_name)
	_assert_true(not panel.has_method("get_actions_label"), "the column should offer no actions label")
	_assert_true(not Harness.collect_control_text(mounted["host"]).contains("今日行动"), "the column should not word daily actions")
	_dispose(mounted)


func _test_the_rail_is_edged_by_the_hairline() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as AppleHudPanel
	var theme := RegistryScript.resolve(ServiceKeysScript.UI_THEME) as GameUiTheme
	var border := (panel.get_rail().get_theme_stylebox("panel") as StyleBoxFlat).border_color
	_assert_eq(border, theme.hairline(), "the HUD rail should be edged by the hairline")
	_dispose(mounted)


func _test_hidden_and_freed_column_stops_listening() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as AppleHudPanel
	var pollution: ValuePropertyModel = mounted["pollution"]
	panel.set_shown(true)
	var pollution_icon := Harness.find_node_by_name(mounted["host"], "HUDPollutionIcon") as Button
	pollution_icon.mouse_entered.emit()
	var tooltip: Label = Harness.find_node_by_name(mounted["host"], "HUDTooltipLabel") as Label
	pollution.write(31)

	panel.set_shown(false)
	_assert_eq(_listener_count(pollution), 0, "hiding the column should drop the pollution listener")
	pollution.write(99)
	_assert_eq(tooltip.text, "污染 31%", "a hidden column should keep the last pollution text")

	panel.set_shown(true)
	_assert_eq(tooltip.text, "污染 99%", "showing the column again should sync the latest pollution")

	panel.queue_free()
	await process_frame
	_assert_eq(_listener_count(pollution), 0, "freeing the column should drop the pollution listener")
	var kept := tooltip.text
	pollution.write(4)
	_assert_eq(tooltip.text, kept, "a freed column should ignore later pollution writes")
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
	RegistryScript.bind(ServiceKeysScript.UI_THEME, GameUiThemeScript.new())
	panel.mount(host, {
		"rail_width": 158.0,
	})
	return {
		"host": host,
		"panel": panel,
		"pollution": manager.model(PropertyKeysScript.POLLUTION),
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
