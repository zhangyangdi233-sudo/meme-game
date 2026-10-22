class_name OpeningNarrationPanel
extends Control
## Chapter one's opening narration over the world: two seconds of true black, then the current line, one at a time.
## While in the tree it watches the chapter progress, the language and whether settings is open, and repaints itself.
## The line uses the language's formal font. A click on a shown line raises OPENING_NARRATION_ADVANCED for the host;
## during the black, while settings is open, or once the narration is read, a click raises nothing.

const ChapterOneProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const NarrativeSessionCatalogScript = preload("res://scripts/game/narrative_session_catalog.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const PropertyWatchScript = preload("res://scripts/game/property_watch.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")

const BLACK_SECONDS := 2.0
const LINE_FONT_SIZE := 30
const HINT_FONT_SIZE := 16
const HINT_TEXT := "点击鼠标或触摸板继续"

var _black: ColorRect
var _line: Label
var _hint: Label
var _black_left := BLACK_SECONDS
var _progress: Dictionary = ChapterOneProgressScript.initial()
var _locale := PropertyKeysScript.DEFAULT_LOCALE
var _settings_open := false
var _watch: PropertyWatchScript = PropertyWatchScript.new(self, {
	PropertyKeysScript.CHAPTER_ONE_PROGRESS: _on_progress,
	PropertyKeysScript.LOCALE: _on_locale,
	PropertyKeysScript.SETTINGS_OPEN: _on_settings_open,
})


func _init() -> void:
	name = "OpeningNarrationPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_black = ColorRect.new()
	_black.name = "OpeningBlack"
	_black.color = UiPalette.VOID
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	var column := VBoxContainer.new()
	column.name = "OpeningNarrationColumn"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	column.offset_left = -540.0
	column.offset_right = 540.0
	column.offset_top = -230.0
	column.offset_bottom = -48.0
	column.add_theme_constant_override("separation", 20)
	add_child(column)
	_line = _make_label("OpeningNarrationLine", LINE_FONT_SIZE)
	_line.custom_minimum_size.y = 108.0
	_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	column.add_child(_line)
	_hint = _make_label("OpeningNarrationHint", HINT_FONT_SIZE)
	# The hint is UI chrome and goes through the UI catalog.
	_hint.remove_meta("skip_localization")
	_hint.modulate.a = 0.62
	column.add_child(_hint)
	_repaint()


func _enter_tree() -> void:
	_watch.start()


func _process(delta: float) -> void:
	if _black_left <= 0.0 or _settings_open:
		return
	_black_left -= maxf(delta, 0.0)
	if _black_left <= 0.0:
		_repaint()


## A line of the narration is on screen and can be advanced.
func is_line_shown() -> bool:
	return _black_left <= 0.0 and ChapterOneProgressScript.is_reading_narration(_progress)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if _settings_open or not is_line_shown():
		return
	GameEventBus.raise(UiIntentsScript.OPENING_NARRATION_ADVANCED)


func _on_progress(value: Variant) -> void:
	_progress = ChapterOneProgressScript.normalize(value)
	_repaint()


func _on_locale(value: Variant) -> void:
	_locale = str(value)
	_repaint()


func _on_settings_open(value: Variant) -> void:
	_settings_open = bool(value)


func _repaint() -> void:
	_black.visible = _black_left > 0.0
	var shown := is_line_shown()
	_line.visible = shown
	_hint.visible = shown
	if not shown:
		return
	var lines: Array = NarrativeSessionCatalogScript.opening_lines(_locale)
	var line_index := int(_progress.get("line_index", 0))
	_line.text = str(lines[line_index]) if line_index < lines.size() else ""
	var font := LocaleFont.font(_locale)
	_line.add_theme_font_override("font", font)
	_hint.add_theme_font_override("font", font)
	_hint.text = HINT_TEXT
	var theme := GameUiThemeScript.bound()
	if theme != null:
		theme.set_localized_property(_hint, "text")
		for label in [_line, _hint]:
			(label as Label).add_theme_color_override("font_color", theme.theme_color("surface"))


func _make_label(node_name: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# The line is language material from the narrative catalog; the theme walk must not translate or restyle it.
	label.set_meta("skip_localization", true)
	label.set_meta("on_dark", true)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_shadow_color", UiPalette.OUTLINE)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label
