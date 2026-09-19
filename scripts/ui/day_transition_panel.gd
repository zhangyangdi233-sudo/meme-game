class_name DayTransitionPanel
extends Node
## Game-side day transition overlay: floor card chrome and copy refresh.

const LanguageCorruptionContentScript = preload("res://scripts/narrative/language_corruption_content.gd")

var _overlay: Control
var _day_label: Label
var _meta_label: Label
var _hint_label: Label
var _rule: ColorRect

var _label_factory: Callable
var _theme_color_fn: Callable
var _level_display_name_fn: Callable


func mount(parent: Control, deps: Dictionary = {}) -> void:
	_apply_mount_deps(deps)
	if parent == null or not _label_factory.is_valid() or not _theme_color_fn.is_valid():
		return
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_build_overlay(parent)


func get_overlay() -> Control:
	return _overlay


func get_day_label() -> Label:
	return _day_label


func get_meta_label() -> Label:
	return _meta_label


func get_hint_label() -> Label:
	return _hint_label


func get_rule() -> ColorRect:
	return _rule


func refresh_copy(floor_number: int) -> void:
	if _day_label == null or _meta_label == null or _hint_label == null:
		return
	var displayed_floor := clampi(floor_number, 1, 4)
	var card: Dictionary = LanguageCorruptionContentScript.get_floor_card_display(displayed_floor)
	_day_label.text = str(_level_display_name_fn.call(displayed_floor)) if _level_display_name_fn.is_valid() else ""
	_meta_label.text = "危险：%s" % str(card.get("危险", ""))
	_hint_label.text = "提示：%s" % str(card.get("提示", ""))


func prepare_show() -> void:
	if _overlay == null:
		return
	_overlay.visible = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.modulate = Color(1, 1, 1, 0)
	_day_label.scale = Vector2(0.86, 0.86)
	_rule.scale = Vector2(0.04, 1.0)


func hide_overlay() -> void:
	if _overlay == null:
		return
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.modulate = Color.WHITE


func _apply_mount_deps(deps: Dictionary) -> void:
	if deps.is_empty():
		return
	_label_factory = deps.get("label_factory", Callable())
	_theme_color_fn = deps.get("theme_color", Callable())
	_level_display_name_fn = deps.get("level_display_name", Callable())


func _build_overlay(parent: Control) -> void:
	_overlay = Control.new()
	_overlay.name = "DayTransitionOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	_overlay.z_index = 95
	_overlay.set_meta("duration_seconds", 3.6)
	parent.add_child(_overlay)

	var background := ColorRect.new()
	background.name = "DayTransitionBlack"
	background.color = Color("050705")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(background)

	_rule = ColorRect.new()
	_rule.name = "DayTransitionRule"
	_rule.color = _theme_color_fn.call("flash_text")
	_rule.set_anchors_preset(Control.PRESET_CENTER)
	_rule.offset_left = -620
	_rule.offset_top = -8
	_rule.offset_right = 620
	_rule.offset_bottom = 8
	_rule.pivot_offset = Vector2(620, 8)
	_rule.rotation = deg_to_rad(-5.0)
	_overlay.add_child(_rule)

	_day_label = _label_factory.call("第一层", 58, _theme_color_fn.call("surface")) as Label
	_day_label.name = "FloorTransitionAreaLabel"
	_day_label.set_meta("on_dark", true)
	_day_label.set_anchors_preset(Control.PRESET_CENTER)
	_day_label.offset_left = -520
	_day_label.offset_top = -190
	_day_label.offset_right = 520
	_day_label.offset_bottom = -70
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_day_label.pivot_offset = Vector2(520, 70)
	_overlay.add_child(_day_label)

	_meta_label = _label_factory.call("危险：B", 28, _theme_color_fn.call("flash_text")) as Label
	_meta_label.name = "FloorTransitionDangerLabel"
	_meta_label.set_meta("on_dark", true)
	_meta_label.set_anchors_preset(Control.PRESET_CENTER)
	_meta_label.offset_left = -440
	_meta_label.offset_top = -16
	_meta_label.offset_right = 440
	_meta_label.offset_bottom = 42
	_meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meta_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay.add_child(_meta_label)

	_hint_label = _label_factory.call("提示：《游戏与现实》", 22, _theme_color_fn.call("muted")) as Label
	_hint_label.name = "FloorTransitionHintLabel"
	_hint_label.set_meta("on_dark", true)
	_hint_label.set_anchors_preset(Control.PRESET_CENTER)
	_hint_label.offset_left = -520
	_hint_label.offset_top = 62
	_hint_label.offset_right = 520
	_hint_label.offset_bottom = 132
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay.add_child(_hint_label)
