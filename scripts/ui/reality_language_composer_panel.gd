class_name RealityLanguageComposerPanel
extends Node
## Reality doctor lexeme puzzle: token bank, grammar slots, preview, and confirm chrome.

const DraggableButtonScript = preload("res://framework/ui/draggable_button.gd")
const DropButtonScript = preload("res://framework/ui/drop_button.gd")

signal token_pressed(token_id: String)
signal token_dropped(data: Dictionary, slot_id: String)
signal slot_pressed(slot_id: String)
signal confirm_pressed

var _frame: PanelContainer
var _token_flow: HFlowContainer
var _slot_row: HBoxContainer
var _preview: Label
var _confirm: Button

var _panel_factory: Callable
var _label_factory: Callable
var _theme_color_fn: Callable
var _clear_children_fn: Callable


func mount(parent: Control, deps: Dictionary) -> void:
	_apply_mount_deps(deps)
	_build_chrome(parent)


func render(state: Dictionary) -> void:
	if _frame == null or _token_flow == null or _slot_row == null:
		return
	if not _clear_children_fn.is_valid() or not _label_factory.is_valid() or not _theme_color_fn.is_valid():
		return
	_clear_children_fn.call(_token_flow)
	_clear_children_fn.call(_slot_row)
	var composing := bool(state.get("composing", false))
	_frame.visible = composing
	if not composing:
		return

	var options: Array = state.get("token_options", [])
	if options.is_empty():
		var empty_label := _label_factory.call(
			"还没有能带到医生面前的词。先在手机里发布一句完整的话。",
			14,
			_theme_color_fn.call("accent")
		) as Label
		empty_label.name = "RealityLanguageEmptyState"
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_token_flow.add_child(empty_label)
	for option_value in options:
		var option: Dictionary = option_value as Dictionary
		var token_id := str(option.get("id", ""))
		var button = DraggableButtonScript.new()
		button.name = "RealityLanguageToken_%s" % token_id
		button.text = str(option.get("display_text", option.get("text", "")))
		button.tooltip_text = "原词：%s\n手机里：%s" % [
			str(option.get("text", "")),
			str(option.get("phone_surface", option.get("text", ""))),
		]
		button.custom_minimum_size = Vector2(128.0, 48.0)
		button.clip_text = true
		button.set_drag_payload("language_token", token_id, button.text)
		button.pressed.connect(_on_token_pressed.bind(token_id))
		_token_flow.add_child(button)

	for slot_value in state.get("slots", []):
		var slot: Dictionary = slot_value as Dictionary
		var slot_id := str(slot.get("id", ""))
		var drop_slot = DropButtonScript.new()
		drop_slot.name = "RealityLanguageSlot%s" % slot_id.capitalize()
		drop_slot.text = "%s\n%s" % [
			str(slot.get("label", slot_id)),
			str(slot.get("filled_text", slot.get("placeholder", "等待词语"))),
		]
		drop_slot.custom_minimum_size = Vector2(150.0, 62.0)
		drop_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		drop_slot.configure_drop_target("language_token", slot_id)
		drop_slot.dropped.connect(_on_token_dropped)
		drop_slot.pressed.connect(_on_slot_pressed.bind(slot_id))
		_slot_row.add_child(drop_slot)

	var preview: Dictionary = state.get("preview", {}) as Dictionary
	if bool(preview.get("valid", false)):
		_preview.text = "原句：%s\n医生语言：%s" % [
			str(preview.get("clean_sentence", "")),
			str(preview.get("world_sentence", "")),
		]
	else:
		_preview.text = "句子尚未完整。需要对象、动作和去向。"
	_confirm.disabled = not bool(preview.get("valid", false)) or not bool(state.get("can_spend_action", false))


func update_visibility(interaction_visible: bool, phase: String, mode: String) -> void:
	if _frame == null:
		return
	_frame.visible = interaction_visible and phase == "composing" and mode == "lexeme"


func _apply_mount_deps(deps: Dictionary) -> void:
	if deps.is_empty():
		return
	_panel_factory = deps.get("panel_factory", Callable())
	_label_factory = deps.get("label_factory", Callable())
	_theme_color_fn = deps.get("theme_color", Callable())
	_clear_children_fn = deps.get("clear_children", Callable())


func _build_chrome(parent: Control) -> void:
	if _frame != null and is_instance_valid(_frame):
		return
	if parent == null or not _panel_factory.is_valid() or not _label_factory.is_valid() or not _theme_color_fn.is_valid():
		return

	_frame = _panel_factory.call() as PanelContainer
	_frame.name = "RealityLanguagePuzzleFrame"
	_frame.set_meta("soft_panel", true)
	_frame.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_frame.offset_left = 300.0
	_frame.offset_top = -520.0
	_frame.offset_right = -240.0
	_frame.offset_bottom = -190.0
	_frame.z_index = 16
	_frame.visible = false
	parent.add_child(_frame)

	var composer_box := VBoxContainer.new()
	composer_box.name = "RealityLanguagePuzzleContent"
	composer_box.add_theme_constant_override("separation", 10)
	_frame.add_child(composer_box)

	var heading := _label_factory.call("把发布过的词重新说给医生", 20, _theme_color_fn.call("ink")) as Label
	heading.name = "RealityLanguagePuzzleHeading"
	composer_box.add_child(heading)
	var hint := _label_factory.call("同一个词到了这里会换一种说法。拖拽词块，或先点词块再点句槽。", 14, _theme_color_fn.call("accent")) as Label
	hint.name = "RealityLanguagePuzzleHint"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	composer_box.add_child(hint)

	_token_flow = HFlowContainer.new()
	_token_flow.name = "RealityLanguageTokenFlow"
	_token_flow.custom_minimum_size.y = 76.0
	_token_flow.add_theme_constant_override("h_separation", 8)
	_token_flow.add_theme_constant_override("v_separation", 8)
	composer_box.add_child(_token_flow)

	_slot_row = HBoxContainer.new()
	_slot_row.name = "RealityLanguageSlots"
	_slot_row.add_theme_constant_override("separation", 8)
	composer_box.add_child(_slot_row)

	_preview = _label_factory.call("", 16, _theme_color_fn.call("ink")) as Label
	_preview.name = "RealityLanguagePreview"
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	composer_box.add_child(_preview)

	_confirm = Button.new()
	_confirm.name = "RealityLanguageConfirm"
	_confirm.text = "对医生说出口"
	_confirm.custom_minimum_size.y = 54.0
	_confirm.pressed.connect(_on_confirm_pressed)
	composer_box.add_child(_confirm)


func _on_token_pressed(token_id: String) -> void:
	token_pressed.emit(token_id)


func _on_token_dropped(data: Dictionary, slot_id: String) -> void:
	token_dropped.emit(data, slot_id)


func _on_slot_pressed(slot_id: String) -> void:
	slot_pressed.emit(slot_id)


func _on_confirm_pressed() -> void:
	confirm_pressed.emit()
