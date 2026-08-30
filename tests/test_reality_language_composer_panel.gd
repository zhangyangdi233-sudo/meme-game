extends SceneTree
## RealityLanguageComposerPanel: named chrome, compose render, and token/slot intents.

const PanelScript = preload("res://scripts/ui/reality_language_composer_panel.gd")

var _failures: Array[String] = []
var _token_presses: Array = []
var _token_drops: Array = []
var _slot_presses: Array = []
var _confirm_presses: Array = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _run()
	if _failures.is_empty():
		print("reality language composer panel tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	var host := Control.new()
	host.name = "ComposerHost"
	host.size = Vector2(1600, 900)
	root.add_child(host)

	var panel = PanelScript.new()
	panel.name = "RealityLanguageComposerPanel"
	root.add_child(panel)
	panel.mount(host, {
		"panel_factory": _panel,
		"label_factory": _label,
		"theme_color": _theme_color,
		"clear_children": _clear,
	})
	panel.token_pressed.connect(func(token_id: String) -> void: _token_presses.append(token_id))
	panel.token_dropped.connect(func(data: Dictionary, slot_id: String) -> void:
		_token_drops.append({"data": data, "slot_id": slot_id})
	)
	panel.slot_pressed.connect(func(slot_id: String) -> void: _slot_presses.append(slot_id))
	panel.confirm_pressed.connect(func() -> void: _confirm_presses.append(true))
	await process_frame

	var frame := _find_node_by_name(host, "RealityLanguagePuzzleFrame") as PanelContainer
	var token_flow := _find_node_by_name(host, "RealityLanguageTokenFlow") as HFlowContainer
	var slots := _find_node_by_name(host, "RealityLanguageSlots") as HBoxContainer
	var confirm := _find_node_by_name(host, "RealityLanguageConfirm") as Button
	_assert_true(frame != null, "mount should expose RealityLanguagePuzzleFrame")
	_assert_true(token_flow != null, "mount should expose RealityLanguageTokenFlow")
	_assert_true(slots != null, "mount should expose RealityLanguageSlots")
	_assert_true(confirm != null, "mount should expose RealityLanguageConfirm")
	_assert_true(frame != null and not frame.visible, "composer should start hidden")

	panel.render({
		"composing": false,
		"token_options": [],
		"slots": [],
		"preview": {},
		"can_spend_action": true,
	})
	_assert_true(frame != null and not frame.visible, "idle render should keep the composer hidden")

	panel.render({
		"composing": true,
		"token_options": [],
		"slots": [
			{"id": "subject", "label": "谁 / 什么", "placeholder": "放入主语", "filled_text": "放入主语"},
		],
		"preview": {"valid": false},
		"can_spend_action": true,
	})
	await process_frame
	_assert_true(frame != null and frame.visible, "composing render should show the puzzle frame")
	var empty_state := _find_node_by_name(host, "RealityLanguageEmptyState") as Label
	_assert_true(empty_state != null, "empty token options should show RealityLanguageEmptyState")
	var preview := _find_node_by_name(host, "RealityLanguagePreview") as Label
	_assert_true(preview != null and preview.text.contains("句子尚未完整"), "invalid preview should say the sentence is incomplete")
	_assert_true(confirm != null and confirm.disabled, "invalid preview should disable confirm")

	panel.render({
		"composing": true,
		"token_options": [
			{
				"id": "subject-1",
				"display_text": "患者",
				"text": "我",
				"phone_surface": "我",
			},
		],
		"slots": [
			{"id": "subject", "label": "谁 / 什么", "placeholder": "放入主语", "filled_text": "患者"},
			{"id": "action", "label": "发生了什么", "placeholder": "放入动作", "filled_text": "放入动作"},
			{"id": "object", "label": "对谁 / 在哪里", "placeholder": "放入落点", "filled_text": "放入落点"},
		],
		"preview": {
			"valid": true,
			"clean_sentence": "我看见塔。",
			"world_sentence": "患者报告病区。",
		},
		"can_spend_action": true,
	})
	await process_frame
	var token_button := _find_node_by_name(host, "RealityLanguageToken_subject-1") as Button
	var subject_slot := _find_node_by_name(host, "RealityLanguageSlotSubject") as Button
	_assert_true(token_button != null, "token options should create RealityLanguageToken_* buttons")
	_assert_true(subject_slot != null, "slots should keep RealityLanguageSlotSubject")
	_assert_true(preview != null and preview.text.contains("患者报告病区。"), "valid preview should show the doctor sentence")
	_assert_true(confirm != null and not confirm.disabled, "a valid spendable sentence should enable confirm")

	if token_button != null:
		token_button.pressed.emit()
	_assert_eq(_token_presses, ["subject-1"], "token press should emit token_pressed")
	if subject_slot != null:
		subject_slot.pressed.emit()
		subject_slot.dropped.emit({"kind": "language_token", "id": "subject-1"}, "subject")
	_assert_eq(_slot_presses, ["subject"], "slot press should emit slot_pressed")
	_assert_true(_token_drops.size() == 1, "slot drop should emit token_dropped once")
	if _token_drops.size() == 1:
		_assert_eq(str(_token_drops[0].get("slot_id", "")), "subject", "token_dropped should carry the slot id")
		_assert_eq(str((_token_drops[0].get("data", {}) as Dictionary).get("id", "")), "subject-1", "token_dropped should carry the token id")
	if confirm != null:
		confirm.pressed.emit()
	_assert_eq(_confirm_presses, [true], "confirm should emit confirm_pressed")

	panel.update_visibility(false, "composing", "lexeme")
	_assert_true(frame != null and not frame.visible, "update_visibility should hide the frame off the reality layer")
	panel.update_visibility(true, "composing", "lexeme")
	_assert_true(frame != null and frame.visible, "update_visibility should show composing lexeme on the reality layer")

	host.queue_free()
	panel.queue_free()
	await process_frame


func _panel() -> PanelContainer:
	return PanelContainer.new()


func _label(text: String, _size: int, _color: Color) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _theme_color(_key: String) -> Color:
	return Color.WHITE


func _clear(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _find_node_by_name(node: Node, target_name: String) -> Node:
	if node == null:
		return null
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found := _find_node_by_name(child, target_name)
		if found != null:
			return found
	return null


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
