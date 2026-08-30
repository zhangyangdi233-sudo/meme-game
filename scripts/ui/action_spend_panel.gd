class_name ActionSpendPanel
extends Node
## Inline HUD pulse and center action text for spending a daily action.

var _overlay: Control
var _spend_label: Label
var _tween: Tween
var _after_actions := -1

var _hud_actions_label: Label
var _action_text_fn: Callable
var _theme_color_fn: Callable
var _ui_font_size_fn: Callable
var _on_animation_finished: Callable


func mount(parent: Control, deps: Dictionary = {}) -> void:
	_apply_mount_deps(deps)
	if parent == null or not _theme_color_fn.is_valid() or not _ui_font_size_fn.is_valid():
		return
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_build_overlay(parent)


func get_overlay() -> Control:
	return _overlay


func get_spend_label() -> Label:
	return _spend_label


func play(before_actions: int, after_actions: int) -> void:
	if _hud_actions_label == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_after_actions = after_actions
	_hud_actions_label.text = _action_text_fn.call(before_actions) if _action_text_fn.is_valid() else ""
	_hud_actions_label.scale = Vector2.ONE
	_hud_actions_label.pivot_offset = _hud_actions_label.size * 0.5
	if _overlay != null:
		_overlay.visible = false

	_tween = create_tween()
	_tween.tween_property(_hud_actions_label, "scale", Vector2(1.07, 1.07), 0.08).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_apply_center_text.bind(after_actions))
	_tween.tween_property(_hud_actions_label, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_emit_animation_finished)


func finish() -> int:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	if _overlay != null:
		_overlay.visible = false
	if _spend_label != null:
		_spend_label.scale = Vector2.ONE
	if _hud_actions_label != null:
		_hud_actions_label.scale = Vector2.ONE
	var result := _after_actions
	_after_actions = -1
	return result


func reset_state() -> void:
	finish()


func update_hud_label_ref(hud_actions_label: Label) -> void:
	_hud_actions_label = hud_actions_label


func _apply_mount_deps(deps: Dictionary) -> void:
	if deps.is_empty():
		return
	_hud_actions_label = deps.get("hud_actions_label", null) as Label
	_action_text_fn = deps.get("action_text", Callable())
	_theme_color_fn = deps.get("theme_color", Callable())
	_ui_font_size_fn = deps.get("ui_font_size", Callable())
	_on_animation_finished = deps.get("on_animation_finished", Callable())


func _build_overlay(parent: Control) -> void:
	_overlay = Control.new()
	_overlay.name = "ActionSpendOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	_overlay.z_index = 90
	parent.add_child(_overlay)

	_spend_label = Label.new()
	_spend_label.name = "ActionSpendLabel"
	_spend_label.set_meta("action_overlay_text", false)
	_spend_label.set_meta("action_animation_mode", "inline_pulse")
	_spend_label.visible = false
	_spend_label.add_theme_font_size_override("font_size", _ui_font_size_fn.call(20))
	_spend_label.add_theme_color_override("font_color", _theme_color_fn.call("muted"))
	_spend_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spend_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay.add_child(_spend_label)


func _apply_center_text(after_actions: int) -> void:
	if _hud_actions_label != null and _action_text_fn.is_valid():
		_hud_actions_label.text = _action_text_fn.call(after_actions)
	if _spend_label != null and _action_text_fn.is_valid():
		_spend_label.text = _action_text_fn.call(after_actions)


func _emit_animation_finished() -> void:
	if _on_animation_finished.is_valid():
		_on_animation_finished.call()
