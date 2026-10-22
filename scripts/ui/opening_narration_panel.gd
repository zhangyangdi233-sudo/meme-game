class_name OpeningNarrationPanel
extends Control
## Chapter one's opening narration over the world: two seconds of true black, then the current line, one at a time.
## It mounts the Layout scene `scenes/ui/opening_narration.tscn`.
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
const HINT_TEXT := "点击鼠标或触摸板继续"

var _black_left := BLACK_SECONDS
var _progress: Dictionary = ChapterOneProgressScript.initial()
var _locale := PropertyKeysScript.DEFAULT_LOCALE
var _settings_open := false
var _watch: PropertyWatchScript = PropertyWatchScript.new(self, {
	PropertyKeysScript.CHAPTER_ONE_PROGRESS: _on_progress,
	PropertyKeysScript.LOCALE: _on_locale,
	PropertyKeysScript.SETTINGS_OPEN: _on_settings_open,
})
@onready var _black := $OpeningBlack as ColorRect
@onready var _line := $OpeningNarrationColumn/OpeningNarrationLine as Label
@onready var _hint := $OpeningNarrationColumn/OpeningNarrationHint as Label


func _ready() -> void:
	_watch.start()
	_repaint()


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
	if not is_node_ready():
		return
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

