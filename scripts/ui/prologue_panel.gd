class_name ProloguePanel
extends Node
## Game-side prologue overlay: transmission lines, counter, and continue/skip chrome.

signal prologue_finished

var _prologue_overlay: Control
var _prologue_line_label: Label
var _prologue_counter_label: Label
var _prologue_continue_button: Button
var _prologue_index := 0
var _prologue_lines: Array = []

var _label_factory: Callable
var _theme_color_fn: Callable


func mount(parent: Control, deps: Dictionary = {}) -> void:
	_apply_mount_deps(deps)
	if parent == null or not _label_factory.is_valid() or not _theme_color_fn.is_valid():
		return
	if _prologue_overlay != null and is_instance_valid(_prologue_overlay):
		_prologue_overlay.queue_free()
	_prologue_index = 0
	_build_prologue_overlay(parent)


func get_overlay() -> Control:
	return _prologue_overlay


func advance() -> void:
	if _prologue_overlay == null or not _prologue_overlay.visible:
		return
	if _prologue_index < _prologue_lines.size() - 1:
		_prologue_index += 1
		_render_prologue_line()
		return
	_finish_prologue()


func skip() -> void:
	if _prologue_overlay == null:
		return
	_prologue_index = _prologue_lines.size() - 1
	_finish_prologue()


func _apply_mount_deps(deps: Dictionary) -> void:
	if deps.is_empty():
		return
	_label_factory = deps.get("label_factory", Callable())
	_theme_color_fn = deps.get("theme_color", Callable())
	var lines: Variant = deps.get("prologue_lines", [])
	if lines is Array:
		_prologue_lines = lines


func _build_prologue_overlay(parent: Control) -> void:
	_prologue_overlay = Control.new()
	_prologue_overlay.name = "PrologueOverlay"
	_prologue_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_prologue_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_prologue_overlay.z_index = 80
	parent.add_child(_prologue_overlay)

	var black := ColorRect.new()
	black.name = "PrologueBlack"
	black.color = Color("060806")
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	_prologue_overlay.add_child(black)

	var signal_rule := ColorRect.new()
	signal_rule.name = "PrologueSignalRule"
	signal_rule.color = _theme_color_fn.call("flash_text")
	signal_rule.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	signal_rule.offset_left = 78
	signal_rule.offset_right = 90
	_prologue_overlay.add_child(signal_rule)

	var copy_column := VBoxContainer.new()
	copy_column.name = "PrologueCopyColumn"
	copy_column.set_anchors_preset(Control.PRESET_CENTER)
	copy_column.offset_left = -540
	copy_column.offset_top = -210
	copy_column.offset_right = 540
	copy_column.offset_bottom = 230
	copy_column.add_theme_constant_override("separation", 22)
	_prologue_overlay.add_child(copy_column)

	var signal_header := _label_factory.call(
		"NO SIGNAL  /  DAY 01  /  PRIVATE FREQUENCY",
		15,
		_theme_color_fn.call("flash_text"),
	) as Label
	signal_header.name = "PrologueSignalHeader"
	signal_header.set_meta("on_dark", true)
	copy_column.add_child(signal_header)

	_prologue_counter_label = _label_factory.call("", 14, _theme_color_fn.call("muted")) as Label
	_prologue_counter_label.name = "PrologueCounter"
	_prologue_counter_label.set_meta("on_dark", true)
	copy_column.add_child(_prologue_counter_label)

	_prologue_line_label = _label_factory.call("", 34, _theme_color_fn.call("surface")) as Label
	_prologue_line_label.name = "PrologueLine"
	_prologue_line_label.custom_minimum_size.y = 190
	_prologue_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prologue_line_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prologue_line_label.set_meta("on_dark", true)
	copy_column.add_child(_prologue_line_label)

	_prologue_continue_button = Button.new()
	_prologue_continue_button.name = "PrologueContinueButton"
	_prologue_continue_button.custom_minimum_size = Vector2(190, 56)
	_prologue_continue_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_prologue_continue_button.pressed.connect(advance)
	copy_column.add_child(_prologue_continue_button)
	_render_prologue_line()


func _render_prologue_line() -> void:
	if _prologue_line_label == null or _prologue_lines.is_empty():
		return
	_prologue_index = clampi(_prologue_index, 0, _prologue_lines.size() - 1)
	_prologue_line_label.text = str(_prologue_lines[_prologue_index])
	_prologue_counter_label.text = "TRANSMISSION %02d / %02d" % [_prologue_index + 1, _prologue_lines.size()]
	_prologue_continue_button.text = "进入第一天" if _prologue_index == _prologue_lines.size() - 1 else "继续"


func _finish_prologue() -> void:
	_prologue_overlay.visible = false
	prologue_finished.emit()
