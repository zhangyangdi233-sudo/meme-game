extends SceneTree
## RealityLanguageComposerPanel: named chrome, compose render, and token/slot intents.

const PanelScript = preload("res://scripts/ui/reality_language_composer_panel.gd")
const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")

var _failures: Array[String] = []
var _heard: Array = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _run()
	if _failures.is_empty():
		print("reality language composer panel tests passed")
		RegistryScript.clear()
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		RegistryScript.clear()
		quit(1)


func _run() -> void:
	RegistryScript.clear()
	var bus: GameEventBus = GameEventBusScript.new()
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, bus)
	bus.intent_emitted.connect(func(intent_name: String, payload: Dictionary) -> void: _heard.append([intent_name, payload]))
	var host := Control.new()
	host.name = "ComposerHost"
	host.size = Vector2(1600, 900)
	root.add_child(host)

	var panel = PanelScript.new()
	panel.name = "RealityLanguageComposerPanel"
	root.add_child(panel)
	RegistryScript.bind(ServiceKeysScript.UI_THEME, GameUiThemeScript.new())
	panel.mount(host, {
		"clear_children": _clear,
	})
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
	_assert_eq(_heard, [[UiIntentsScript.COMPOSER_TOKEN_PRESSED, {UiIntentsScript.KEY_TOKEN_ID: "subject-1"}]], "token press should raise its intent with the token id")
	_heard.clear()
	if subject_slot != null:
		subject_slot.pressed.emit()
	_assert_eq(_heard, [[UiIntentsScript.COMPOSER_SLOT_PRESSED, {UiIntentsScript.KEY_SLOT_ID: "subject"}]], "slot press should raise its intent with the slot id")
	_heard.clear()
	if subject_slot != null:
		subject_slot.dropped.emit({"kind": "language_token", "id": "subject-1"}, "subject")
	_assert_eq(_heard, [[UiIntentsScript.COMPOSER_TOKEN_DROPPED, {UiIntentsScript.KEY_DATA: {"kind": "language_token", "id": "subject-1"}, UiIntentsScript.KEY_SLOT_ID: "subject"}]], "slot drop should raise its intent with the drag data and slot id")
	_heard.clear()
	if confirm != null:
		confirm.pressed.emit()
	_assert_eq(_heard, [[UiIntentsScript.COMPOSER_CONFIRM_PRESSED, {}]], "confirm should raise its intent with an empty payload")

	panel.update_visibility(false, "composing", "lexeme")
	_assert_true(frame != null and not frame.visible, "update_visibility should hide the frame off the reality layer")
	panel.update_visibility(true, "composing", "lexeme")
	_assert_true(frame != null and frame.visible, "update_visibility should show composing lexeme on the reality layer")

	# Rebinds the theme at pollution stage 5, so it runs last.
	_test_token_drag_preview_follows_the_pollution_palette(panel, host)

	host.queue_free()
	panel.queue_free()
	RegistryScript.clear()
	await process_frame


func _test_token_drag_preview_follows_the_pollution_palette(panel: Node, host: Control) -> void:
	Harness.bind_ui_theme("pollution_palette_5")
	panel.render({
		"composing": true,
		"token_options": [{"id": "subject-1", "display_text": "患者", "text": "我", "phone_surface": "我"}],
		"slots": [],
		"preview": {"valid": false},
		"can_spend_action": true,
	})
	var token_button := _find_node_by_name(host, "RealityLanguageToken_subject-1") as DraggableButton
	_assert_true(token_button != null, "a polluted render should still create the token button")
	if token_button == null:
		return
	var preview := token_button.build_drag_preview()
	_assert_eq(preview.get_theme_color("font_color"), UiPalette.color(UiPalette.POLLUTION_PALETTE_5, "accent"), "dragging a token at pollution stage 5 should preview it in that palette's accent")
	preview.free()


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
