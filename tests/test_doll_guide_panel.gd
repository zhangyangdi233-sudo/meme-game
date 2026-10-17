extends SceneTree
## Shown doll guide watches the tutorial progress and the floor facts and words its own line.

const BootScript = preload("res://scripts/game/property_boot.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const DirectorScript = preload("res://scripts/tutorial/tutorial_director.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	_test_showing_registers_and_words_the_current_line()
	_test_writes_reword_the_line_while_shown()
	_test_hiding_unregisters_and_keeps_the_last_line()
	await _test_a_freed_guide_unregisters()
	if _failures.is_empty():
		print("doll guide panel tests passed")
		RegistryScript.clear()
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		RegistryScript.clear()
		quit(1)


func _test_showing_registers_and_words_the_current_line() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as DollGuidePanel
	var line := panel.get_overlay().find_child("DollGuideLine", true, false) as Label
	_assert_eq(_listener_count(mounted["progress"]), 0, "a mounted guide should not listen before it is shown")
	_assert_true(not panel.get_overlay().visible, "a mounted guide starts hidden")
	panel.set_shown(true)
	_assert_true(panel.get_overlay().visible, "showing the guide should show the window")
	_assert_eq(_listener_count(mounted["progress"]), 1, "showing the guide should register the tutorial once")
	_assert_eq(_listener_count(mounted["floor3"]), 1, "showing the guide should register the floor three task once")
	panel.set_shown(true)
	_assert_eq(_listener_count(mounted["progress"]), 1, "showing twice should not register twice")
	_assert_eq(line.text, "先找到我。别急着相信我。", "showing the guide should word the current step")
	_dispose(mounted)


func _test_writes_reword_the_line_while_shown() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as DollGuidePanel
	var line := panel.get_overlay().find_child("DollGuideLine", true, false) as Label
	panel.set_shown(true)
	var progress: MapPropertyModel = mounted["progress"]
	progress.replace_all(DirectorScript.notify(progress.read(), &"guide_found"))
	_assert_eq(line.text, "拿起手机，打开社交媒体。那里有人替你准备了词。", "a tutorial write should reword the line")

	progress.replace_all(DirectorScript.skip(progress.read()))
	_assert_eq(line.text, "你已经会自己走了。至少现在是。", "a finished tutorial should send the player on")
	(mounted["floor"] as ValuePropertyModel).write(3)
	_assert_eq(line.text, "门在等一句话。去笔记本里拼给它。", "arriving on floor three should reword the line")
	(mounted["floor3"] as ValuePropertyModel).write(true)
	_assert_eq(line.text, "门记得这句话。", "the door sentence should reword the line")
	(mounted["floor"] as ValuePropertyModel).write(4)
	_assert_eq(line.text, "出口还不存在。让它存在。", "arriving on floor four should reword the line")
	(mounted["floor4"] as ValuePropertyModel).write(true)
	_assert_eq(line.text, "出口存在了。这里不会记下我们。", "the exit should reword the line")
	_dispose(mounted)


func _test_hiding_unregisters_and_keeps_the_last_line() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as DollGuidePanel
	var line := panel.get_overlay().find_child("DollGuideLine", true, false) as Label
	panel.set_shown(true)
	panel.set_shown(false)
	_assert_true(not panel.get_overlay().visible, "hiding the guide should hide the window")
	_assert_eq(_listener_count(mounted["progress"]), 0, "hiding the guide should drop the tutorial listener")
	_assert_eq(_listener_count(mounted["floor4"]), 0, "hiding the guide should drop the floor four listener")
	var progress: MapPropertyModel = mounted["progress"]
	progress.replace_all(DirectorScript.skip(progress.read()))
	_assert_eq(line.text, "先找到我。别急着相信我。", "a hidden guide should ignore writes")
	panel.set_shown(true)
	_assert_eq(line.text, "你已经会自己走了。至少现在是。", "showing again should word the latest facts")
	_dispose(mounted)


func _test_a_freed_guide_unregisters() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as DollGuidePanel
	panel.set_shown(true)
	panel.queue_free()
	await process_frame
	_assert_eq(_listener_count(mounted["progress"]), 0, "freeing the guide should drop the tutorial listener")
	_assert_eq(_listener_count(mounted["floor"]), 0, "freeing the guide should drop the floor listener")
	(mounted["host"] as Node).free()
	RegistryScript.clear()


func _mount() -> Dictionary:
	RegistryScript.clear()
	BootScript.install()
	var manager: PropertyManager = RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	(manager.model(PropertyKeysScript.TUTORIAL_PROGRESS) as MapPropertyModel).replace_all(DirectorScript.initial_progress())
	var host := Control.new()
	root.add_child(host)
	var panel := DollGuidePanel.new()
	root.add_child(panel)
	RegistryScript.bind(ServiceKeysScript.UI_THEME, GameUiThemeScript.new())
	panel.mount(host, {})
	return {
		"host": host,
		"panel": panel,
		"progress": manager.model(PropertyKeysScript.TUTORIAL_PROGRESS),
		"floor": manager.model(PropertyKeysScript.TOWER_FLOOR),
		"floor3": manager.model(PropertyKeysScript.FLOOR3_TASK_COMPLETE),
		"floor4": manager.model(PropertyKeysScript.FLOOR4_TASK_COMPLETE),
	}


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
