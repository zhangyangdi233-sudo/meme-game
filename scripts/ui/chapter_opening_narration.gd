extends Control
## A single manually advanced line over the existing ocean and white door.
## Pointer routing stays in the host so settings and cinematic locks agree.

const NarrationBlips = preload("res://scripts/audio/chapter_narration_blips.gd")

var line_number := 0
var line_label: Label
var hint_label: Label
var _copy_stack: VBoxContainer
var _blips: Node
var _audio_paused := false


func _ready() -> void:
	name = "ChapterOpeningNarration"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 70
	hide()
	_copy_stack = VBoxContainer.new()
	_copy_stack.name = "NarrationCopy"
	_copy_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_copy_stack.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_copy_stack.add_theme_constant_override("separation", 24)
	add_child(_copy_stack)
	line_label = _make_label("NarrationLine", 27)
	line_label.custom_minimum_size.y = 108
	line_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_copy_stack.add_child(line_label)
	hint_label = _make_label("NarrationClickHint", 18)
	hint_label.modulate.a = 0.62
	_copy_stack.add_child(hint_label)
	_blips = NarrationBlips.new()
	add_child(_blips)
	visibility_changed.connect(_sync_voice_visibility)
	resized.connect(_layout_copy)
	_layout_copy()


func show_line(number: int, text: String, hint: String) -> void:
	var changed := line_number != number or line_label.text != text
	line_number = number
	line_label.text = text
	hint_label.text = hint
	# The host refreshes this control each frame. Only a new line/language
	# starts a voice; showing the same line after settings never requeues it.
	if changed:
		_blips.stop()
		if is_visible_in_tree() and not _audio_paused:
			_blips.play_line(text)


func set_audio_paused(value: bool) -> void:
	_audio_paused = value
	if is_instance_valid(_blips):
		_blips.set_paused(value)


func _sync_voice_visibility() -> void:
	if not is_visible_in_tree() and is_instance_valid(_blips):
		_blips.stop()


func _exit_tree() -> void:
	if is_instance_valid(_blips):
		_blips.stop()


func _make_label(node_name: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.set_meta("skip_localization", true)
	label.set_meta("on_dark", true)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("fff1c9"))
	label.add_theme_color_override("font_shadow_color", Color(0.01, 0.02, 0.03, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 4)
	return label


func _layout_copy() -> void:
	if not is_instance_valid(_copy_stack):
		return
	var width := minf(1080.0, maxf(240.0, size.x * 0.86))
	_copy_stack.offset_left = -width * 0.5
	_copy_stack.offset_right = width * 0.5
	_copy_stack.offset_top = -minf(246.0, size.y * 0.40)
	_copy_stack.offset_bottom = -maxf(28.0, size.y * 0.05)
