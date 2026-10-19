extends Control
## No global input or mouse capture changes here: main routes F / Enter / Esc.

signal closed

const Paper = preload("res://scripts/ui/floor_two_note_paper.gd")
const UI_FONT = preload("res://assets/fonts/BoutiqueBitmap9x9.ttf")
var active := false
var _paper: Control
var _translation: Label
var _close_button: Button

func _ready() -> void:
	name = "FloorTwoNoteView"
	set_meta("floor_two_note_theme", true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 80
	var shade := ColorRect.new()
	shade.name = "NoteShade"
	shade.color = Color(0.012, 0.014, 0.020, 0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_paper = Paper.new()
	_paper.name = "NotePaper"
	add_child(_paper)
	_translation = Label.new()
	_translation.name = "NoteTranslation"
	_translation.set_meta("skip_localization", true)
	_translation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_translation.add_theme_font_override("font", UI_FONT)
	_translation.add_theme_font_size_override("font_size", 18)
	_translation.add_theme_color_override("font_color", Color("d5c9b7"))
	_translation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_translation.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_translation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_translation)
	_close_button = Button.new()
	_close_button.name = "NoteCloseButton"
	_close_button.set_meta("skip_localization", true)
	_close_button.add_theme_font_override("font", UI_FONT)
	_close_button.add_theme_font_size_override("font_size", 18)
	_close_button.add_theme_color_override("font_color", Color("ded2bd"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("242528")
	style.border_color = Color("756d61")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	_close_button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("39383a")
	_close_button.add_theme_stylebox_override("hover", hover)
	_close_button.add_theme_stylebox_override("pressed", hover)
	_close_button.pressed.connect(close)
	add_child(_close_button)
	resized.connect(layout_contents)
	visible = false
	layout_contents()

func open(locale: String = "zh") -> void:
	_translation.text = {
		"en": "Walls are no longer walls. Paths are no longer paths.",
		"ja": "壁はもはや壁ではなく、道はもはや道ではない。",
	}.get(locale, "")
	_translation.visible = not _translation.text.is_empty()
	_close_button.text = {"en": "Close  ·  F / Enter / Esc", "ja": "閉じる  ·  F / Enter / Esc"}.get(locale, "关闭  ·  F / Enter / Esc")
	active = true
	visible = true
	layout_contents()

func close() -> void:
	if not active:
		return
	cancel()
	closed.emit()

func cancel() -> void:
	active = false
	visible = false

func layout_contents() -> void:
	if not is_instance_valid(_paper):
		return
	var width := minf(920.0, minf(size.x * 0.82, maxf(1, size.y - 160.0) * 1.6))
	_paper.size = Vector2(width, width / 1.6)
	_paper.position = Vector2((size.x - width) * 0.5, maxf(16, (size.y - _paper.size.y - 120) * 0.5))
	_translation.position = Vector2(size.x * 0.08, _paper.position.y + _paper.size.y + 12)
	_translation.size = Vector2(size.x * 0.84, 50)
	_close_button.size = Vector2(minf(360, size.x * 0.8), 44)
	_close_button.position = Vector2((size.x - _close_button.size.x) * 0.5, minf(size.y - 60, _translation.position.y + 60))
