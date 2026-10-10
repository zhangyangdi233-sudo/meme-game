extends SceneTree
## Shown conversation panel watches the conversation progress models and repaints itself.

const BootScript = preload("res://scripts/game/property_boot.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const Harness = preload("res://tests/harness/minimal_game_harness.gd")

var _failures: Array[String] = []
var _pressed: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _run()
	if _failures.is_empty():
		print("reality conversation panel tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_showing_registers_and_syncs_the_current_progress()
	_test_changing_a_value_repaints_the_panel()
	_test_a_press_reaches_the_flow_and_the_choice_row_follows_the_models()
	_test_hiding_unregisters_and_later_writes_are_ignored()
	_test_a_freed_panel_unregisters()
	_test_rendering_repaints_what_the_models_cannot_tell()


func _test_showing_registers_and_syncs_the_current_progress() -> void:
	var mounted := _mount()
	var panel: RealityConversationPanel = mounted["panel"]
	var phase: PropertyModel = _model(PropertyKeysScript.CONVERSATION_PHASE)
	_model(PropertyKeysScript.CONVERSATION_ACTOR_LABEL).write("Lena")
	_model(PropertyKeysScript.CONVERSATION_PROMPT).write("hello there")
	phase.write("choosing")
	_assert_eq(_listener_count(phase), 0, "a mounted panel should not listen before it is shown")

	panel.set_shown(true)
	_assert_eq(_listener_count(phase), 1, "showing the panel should register once")
	panel.set_shown(true)
	_assert_eq(_listener_count(phase), 1, "showing again should not register twice")
	_assert_true(_subtitle_text(mounted).contains("Lena") and _subtitle_text(mounted).contains("hello there"), "showing should sync the actor and prompt at once")
	_assert_true(_node(mounted, "RealitySubtitlePanel").visible, "a shown panel should show the subtitle")
	_assert_true(_node(mounted, "RealityResponseChoices").visible, "choosing should show the choice row")
	_assert_true(not _node(mounted, "RealityTypingLine").visible, "choosing should not show the typing line")
	_dispose(mounted)


func _test_changing_a_value_repaints_the_panel() -> void:
	var mounted := _mount()
	var panel: RealityConversationPanel = mounted["panel"]
	_model(PropertyKeysScript.CONVERSATION_ACTOR_LABEL).write("Lena")
	_model(PropertyKeysScript.CONVERSATION_PHASE).write("choosing")
	panel.set_shown(true)

	_model(PropertyKeysScript.CONVERSATION_PROMPT).write("a new line")
	_assert_true(_subtitle_text(mounted).contains("a new line"), "a prompt change should repaint the subtitle")

	_model(PropertyKeysScript.CONVERSATION_PHASE).write("typing")
	_assert_true(_node(mounted, "RealityTypingLine").visible, "typing should show the typing line")
	_assert_true(not _node(mounted, "RealityResponseChoices").visible, "typing should hide the choice row")
	_model(PropertyKeysScript.CONVERSATION_REVEAL_INDEX).write(3)
	_assert_true((_node(mounted, "RealityTypingProgress") as Label).text.contains("3 / 9"), "the reveal index should repaint the progress")

	_model(PropertyKeysScript.CONVERSATION_FEEDBACK).write("well said")
	_model(PropertyKeysScript.CONVERSATION_CAN_CONTINUE).write(true)
	_model(PropertyKeysScript.CONVERSATION_PHASE).write("result")
	_assert_true(_subtitle_text(mounted).contains("well said"), "feedback should repaint the subtitle")
	_assert_eq((_node(mounted, "RealityConversationContinue") as Button).text, "继续交谈", "a result that can go on should offer to continue")
	_model(PropertyKeysScript.CONVERSATION_CAN_CONTINUE).write(false)
	_assert_eq((_node(mounted, "RealityConversationContinue") as Button).text, "结束", "a result that cannot go on should offer to end")
	_dispose(mounted)


func _test_a_press_reaches_the_flow_and_the_choice_row_follows_the_models() -> void:
	var mounted := _mount()
	var panel: RealityConversationPanel = mounted["panel"]
	_pressed.clear()
	panel.choice_pressed.connect(func(choice_id: String) -> void: _pressed.append(choice_id))
	(_model(PropertyKeysScript.CONVERSATION_CHOICES) as ListPropertyModel).replace_all([
		{"id": "first", "summary": "First"},
		{"id": "second", "summary": "Second", "locked": true},
	])
	_model(PropertyKeysScript.CONVERSATION_PHASE).write("choosing")
	panel.set_shown(true)

	var row := _node(mounted, "RealityResponseChoices")
	_assert_eq(row.get_child_count(), 2, "every choice in the model should become a button")
	var first := row.get_child(0) as Button
	var second := row.get_child(1) as Button
	_assert_eq(first.text, "First", "a button should carry the choice summary")
	_assert_true(second.disabled, "a locked choice should be disabled")
	first.pressed.emit()
	_assert_eq(_pressed, ["first"], "pressing a choice should send its id to the flow")

	(_model(PropertyKeysScript.CONVERSATION_CHOICES) as ListPropertyModel).replace_all([{"id": "third", "summary": "Third"}])
	_assert_eq(row.get_child_count(), 1, "a changed choice list should rebuild the row")
	_dispose(mounted)


func _test_hiding_unregisters_and_later_writes_are_ignored() -> void:
	var mounted := _mount()
	var panel: RealityConversationPanel = mounted["panel"]
	var phase: PropertyModel = _model(PropertyKeysScript.CONVERSATION_PHASE)
	_model(PropertyKeysScript.CONVERSATION_PROMPT).write("before hiding")
	panel.set_shown(true)
	panel.set_shown(false)
	_assert_eq(_listener_count(phase), 0, "hiding the panel should unregister")
	_assert_true(not _node(mounted, "RealitySubtitlePanel").visible, "a hidden panel should hide the subtitle")
	_assert_true(not _node(mounted, "RealityResponseChoices").visible, "a hidden panel should hide the choice row")

	_model(PropertyKeysScript.CONVERSATION_PROMPT).write("after hiding")
	phase.write("typing")
	_assert_true(not _subtitle_text(mounted).contains("after hiding"), "a hidden panel should not repaint on a later write")
	_assert_true(not _node(mounted, "RealityTypingLine").visible, "a hidden panel should stay hidden when the phase changes")

	panel.set_shown(true)
	_assert_eq(_listener_count(phase), 1, "showing again should register again")
	_assert_true(_subtitle_text(mounted).contains("after hiding"), "showing again should catch up with what was missed")
	_dispose(mounted)


func _test_a_freed_panel_unregisters() -> void:
	var mounted := _mount()
	var panel: RealityConversationPanel = mounted["panel"]
	var phase: PropertyModel = _model(PropertyKeysScript.CONVERSATION_PHASE)
	panel.set_shown(true)
	panel.free()
	mounted["panel"] = null
	_assert_eq(_listener_count(phase), 0, "a freed panel should unregister")
	_dispose(mounted)


func _test_rendering_repaints_what_the_models_cannot_tell() -> void:
	var mounted := _mount()
	var panel: RealityConversationPanel = mounted["panel"]
	panel.render()
	_assert_true(not _node(mounted, "RealitySubtitlePanel").visible, "rendering a panel that is not shown should not open it")

	_model(PropertyKeysScript.CONVERSATION_PHASE).write("idle")
	panel.set_shown(true)
	_assert_true(_subtitle_text(mounted).contains("fallback name") and _subtitle_text(mounted).contains("day line"), "an idle model should fall back to the day line and the nearby name")
	mounted["state"]["day_line"] = "later day line"
	panel.render()
	_assert_true(_subtitle_text(mounted).contains("later day line"), "rendering should pick up what the flow knows and the models do not")
	_dispose(mounted)


func _mount() -> Dictionary:
	RegistryScript.clear()
	BootScript.install()
	var host := Control.new()
	host.name = "ConversationHost"
	host.size = Vector2(1600, 900)
	root.add_child(host)
	var panel := RealityConversationPanel.new()
	panel.name = "RealityConversationPanelHost"
	root.add_child(panel)
	var state := {"day_line": "day line"}
	panel.mount(host, {
		"label_factory": _label,
		"theme_color": _theme_color,
		"ui_font_size": func(size: int) -> int: return size,
		"viewport_size": func() -> Vector2: return Vector2(1600, 900),
		"install_rich_text_effect": func(_label_node: RichTextLabel, _effect: String) -> void: pass,
		"set_dialogue_text": func(label_node: RichTextLabel, value: String) -> void: label_node.text = value,
		"set_richer_bbcode": func(label_node: RichTextLabel, value: String) -> void: label_node.text = value,
		"clear_children": _clear,
		"day_line": func() -> String: return str(state["day_line"]),
		"fallback_actor_name": func() -> String: return "fallback name",
		"last_spoken_sentence": func() -> String: return "",
		"npc_understanding": func() -> int: return 100,
		"hover_choice_id": func() -> String: return "",
		"hover_choice_preview": func() -> String: return "",
		"playtest_assist_enabled": func() -> bool: return false,
		"typed_bbcode": func() -> String: return "typed",
		"typing_unit_count": func() -> int: return 9,
	})
	return {"host": host, "panel": panel, "state": state}


func _dispose(mounted: Dictionary) -> void:
	var panel: Node = mounted["panel"]
	if panel != null and is_instance_valid(panel):
		panel.free()
	var host: Node = mounted["host"]
	if host != null and is_instance_valid(host):
		host.free()
	RegistryScript.clear()


func _model(property_name: String) -> PropertyModel:
	var manager: PropertyManager = RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	return manager.model(property_name)


func _node(mounted: Dictionary, node_name: String) -> Control:
	return Harness.find_node_by_name(mounted["host"], node_name) as Control


func _subtitle_text(mounted: Dictionary) -> String:
	var label_node := _node(mounted, "RealitySubtitleLabel") as RichTextLabel
	return label_node.text if label_node != null else ""


func _listener_count(model: PropertyModel) -> int:
	if model == null:
		return -1
	return model.changed.get_connections().size()


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.free()


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
