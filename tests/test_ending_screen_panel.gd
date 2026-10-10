extends SceneTree
## Ending screen watches the chosen ending language on its property model.

const BootScript = preload("res://scripts/game/property_boot.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const Harness = preload("res://tests/harness/minimal_game_harness.gd")

const OUTPUT_TEXT := "ending-output-sentinel"

var _failures: Array[String] = []
var _selected_ids: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _run()
	if _failures.is_empty():
		print("ending screen panel tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_open_screen_registers_and_syncs_the_current_choice()
	await _test_choosing_swaps_choices_for_the_result()
	_test_screen_opened_after_a_choice_shows_the_result()
	await _test_closing_stops_listening()
	_test_a_mounted_screen_is_not_opened_by_a_write()


func _test_open_screen_registers_and_syncs_the_current_choice() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as EndingScreenPanel
	var choice: ValuePropertyModel = mounted["choice"]
	_assert_eq(_listener_count(choice), 0, "a mounted screen should not listen before it opens")

	panel.render()
	_assert_eq(_listener_count(choice), 1, "opening the screen should register once")
	panel.render()
	_assert_eq(_listener_count(choice), 1, "rendering again should not register twice")
	_assert_true(Harness.find_node_by_name(mounted["host"], "EndingLanguageChoices") != null, "an open screen without a choice should show the choices")
	_assert_true(Harness.find_node_by_name(mounted["host"], "EndingLanguageResult") == null, "an open screen without a choice should not show a result")
	_dispose(mounted)


func _test_choosing_swaps_choices_for_the_result() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as EndingScreenPanel
	var choice: ValuePropertyModel = mounted["choice"]
	panel.render()
	_selected_ids.clear()
	panel.ending_language_selected.connect(func(choice_id: String) -> void:
		_selected_ids.append(choice_id)
		choice.write(choice_id)
	)

	var button := Harness.find_node_by_name(mounted["host"], "EndingLanguageChoice_blank") as Button
	_assert_true(button != null, "the choices should include blank")
	if button != null:
		button.pressed.emit()
	await process_frame
	_assert_eq(_selected_ids, ["blank"], "pressing a choice should send the chosen id")

	_assert_true(Harness.find_node_by_name(mounted["host"], "EndingLanguageChoices") == null, "a chosen language should remove the choices")
	var result := Harness.find_node_by_name(mounted["host"], "EndingLanguageResult") as Label
	_assert_true(result != null, "a chosen language should show the result")
	if result != null:
		_assert_true(result.text.contains(OUTPUT_TEXT), "the result should carry the language output")
	_assert_eq(_listener_count(choice), 1, "repainting should keep one registration")
	_dispose(mounted)


func _test_screen_opened_after_a_choice_shows_the_result() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as EndingScreenPanel
	var choice: ValuePropertyModel = mounted["choice"]
	choice.write("blank")
	panel.render()
	_assert_true(Harness.find_node_by_name(mounted["host"], "EndingLanguageResult") != null, "opening with a saved choice should show the result at once")
	_assert_true(Harness.find_node_by_name(mounted["host"], "EndingLanguageChoices") == null, "opening with a saved choice should not offer the choices again")
	_dispose(mounted)


func _test_closing_stops_listening() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as EndingScreenPanel
	var choice: ValuePropertyModel = mounted["choice"]
	panel.render()
	panel.unmount()
	await process_frame
	_assert_eq(_listener_count(choice), 0, "closing the screen should unregister")
	_assert_true(Harness.find_node_by_name(mounted["host"], "EndingScreen") == null, "closing the screen should remove it")
	choice.write("blank")
	await process_frame
	_assert_true(Harness.find_node_by_name(mounted["host"], "EndingScreen") == null, "a closed screen should not repaint on a later write")
	_dispose(mounted)

	var freed := _mount()
	var freed_panel := freed["panel"] as EndingScreenPanel
	var freed_choice: ValuePropertyModel = freed["choice"]
	freed_panel.render()
	freed_panel.free()
	freed["panel"] = null
	_assert_eq(_listener_count(freed_choice), 0, "a freed screen should unregister")
	_dispose(freed)


func _test_a_mounted_screen_is_not_opened_by_a_write() -> void:
	var mounted := _mount()
	var choice: ValuePropertyModel = mounted["choice"]
	choice.write("blank")
	_assert_true(Harness.find_node_by_name(mounted["host"], "EndingScreen") == null, "a model write should not open a screen the flow has not opened")
	_dispose(mounted)


func _mount() -> Dictionary:
	RegistryScript.clear()
	BootScript.install()
	var manager: PropertyManager = RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	var host := Control.new()
	host.name = "EndingHost"
	host.size = Vector2(1600, 900)
	root.add_child(host)
	var panel := EndingScreenPanel.new()
	panel.name = "EndingScreenPanelHost"
	root.add_child(panel)
	panel.mount(host, {
		"label_factory": _label,
		"theme_color": _theme_color,
		"restart": func() -> void: pass,
		"epilogue_lines": func() -> Array: return ["line one", "line two"],
		"language_choices": func() -> Array: return [
			{"id": "blank", "label": "Blank"},
			{"id": "silence", "label": "Silence"},
		],
		"language_output": func() -> String: return OUTPUT_TEXT,
		"relationship_residue": func() -> int: return 12,
		"relationship_state_label": func() -> String: return "label",
	})
	return {
		"host": host,
		"panel": panel,
		"choice": manager.model(PropertyKeysScript.ENDING_LANGUAGE_CHOICE),
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
