extends SceneTree
## Shown playtest panel watches the tutorial progress for its first line; the host supplies the other lines.

const BootScript = preload("res://scripts/game/property_boot.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const DirectorScript = preload("res://scripts/tutorial/tutorial_director.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	_test_visible_render_registers_and_leads_with_the_step_hint()
	_test_a_tutorial_write_repaints_without_the_host()
	_test_a_hidden_render_unregisters()
	await _test_a_freed_panel_unregisters()
	if _failures.is_empty():
		print("playtest assist panel tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_visible_render_registers_and_leads_with_the_step_hint() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as PlaytestAssistPanel
	var label := panel.get_overlay().find_child("PlaytestAssistLabel", true, false) as Label
	_assert_eq(_listener_count(mounted["progress"]), 0, "a mounted panel should not listen before it is shown")
	panel.render({"visible": true, "lines": ["extra one", "extra two"]})
	_assert_eq(_listener_count(mounted["progress"]), 1, "a visible render should register the tutorial once")
	panel.render({"visible": true, "lines": ["extra one", "extra two"]})
	_assert_eq(_listener_count(mounted["progress"]), 1, "rendering again should not register twice")
	_assert_eq(label.text, "测试提示：转动镜头并靠近缝线布偶。\nextra one\nextra two", "the step hint should lead the host lines")
	_dispose(mounted)


func _test_a_tutorial_write_repaints_without_the_host() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as PlaytestAssistPanel
	var label := panel.get_overlay().find_child("PlaytestAssistLabel", true, false) as Label
	panel.render({"visible": true, "lines": ["extra one"]})
	var progress: MapPropertyModel = mounted["progress"]
	progress.replace_all(DirectorScript.notify(progress.read(), &"guide_found"))
	_assert_eq(label.text, "测试提示：拿起手机并打开社交媒体 App。\nextra one", "a tutorial write should repaint the first line and keep the rest")
	_dispose(mounted)


func _test_a_hidden_render_unregisters() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as PlaytestAssistPanel
	var label := panel.get_overlay().find_child("PlaytestAssistLabel", true, false) as Label
	panel.render({"visible": true, "lines": []})
	panel.render({"visible": false, "lines": []})
	_assert_true(not panel.get_overlay().visible, "a hidden render should hide the panel")
	_assert_eq(_listener_count(mounted["progress"]), 0, "a hidden render should drop the tutorial listener")
	var progress: MapPropertyModel = mounted["progress"]
	progress.replace_all(DirectorScript.skip(progress.read()))
	_assert_eq(label.text, "测试提示：转动镜头并靠近缝线布偶。", "a hidden panel should ignore tutorial writes")
	panel.render({"visible": true, "lines": []})
	_assert_eq(label.text, "教程完成：继续正常游戏。", "showing again should sync the latest step")
	_dispose(mounted)


func _test_a_freed_panel_unregisters() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as PlaytestAssistPanel
	panel.render({"visible": true, "lines": []})
	panel.queue_free()
	await process_frame
	_assert_eq(_listener_count(mounted["progress"]), 0, "freeing the panel should drop the tutorial listener")
	(mounted["host"] as Node).free()
	RegistryScript.clear()


func _mount() -> Dictionary:
	RegistryScript.clear()
	BootScript.install()
	var manager: PropertyManager = RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	(manager.model(PropertyKeysScript.TUTORIAL_PROGRESS) as MapPropertyModel).replace_all(DirectorScript.initial_progress())
	var host := Control.new()
	root.add_child(host)
	var panel := PlaytestAssistPanel.new()
	root.add_child(panel)
	panel.mount(host, {"label_factory": _label, "theme_color": _theme_color})
	return {"host": host, "panel": panel, "progress": manager.model(PropertyKeysScript.TUTORIAL_PROGRESS)}


func _dispose(mounted: Dictionary) -> void:
	for key in ["panel", "host"]:
		var node: Node = mounted[key]
		if node != null and is_instance_valid(node):
			node.free()
	RegistryScript.clear()


func _listener_count(model: PropertyModel) -> int:
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
