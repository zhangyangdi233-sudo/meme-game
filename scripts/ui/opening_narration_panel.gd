class_name OpeningNarrationPanel
extends Control
## Chapter one's opening narration over the world: two seconds of true black, then the current line behind its speaker
## tag, one at a time.
## It mounts the Layout scene `scenes/ui/opening_narration.tscn`.
## While in the tree it watches the chapter progress, the language and whether settings is open, and repaints itself.
## The line uses the language's formal font. A click on a shown line raises OPENING_NARRATION_ADVANCED for the host;
## during the black, while settings is open, or once the narration is read, a click raises nothing.
## The same narrator speaks round one's CRT focus cinematic, so the host mounts a second one for it
## (`configure_crt_focus`): no black, the `crt_focus` lines and hint of the catalog, the line the host shows
## (`show_crt_focus_line`), and a click raises CRT_FOCUS_ADVANCED instead.

const ChapterOneProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const NarrativeSessionCatalogScript = preload("res://scripts/game/narrative_session_catalog.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const PropertyWatchScript = preload("res://scripts/game/property_watch.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const NarrationBlipsScript = preload("res://scripts/audio/narration_blips.gd")

const BLACK_SECONDS := 2.0
const HINT_TEXT := "点击鼠标或触摸板继续"

var _black_left := BLACK_SECONDS
var _progress: Dictionary = ChapterOneProgressScript.initial()
var _locale := PropertyKeysScript.DEFAULT_LOCALE
var _settings_open := false
## The narrator's voice and the line it is on (index, locale, text): only a new line or language starts it, so a
## repaint of the same line (settings closing, the progress model re-told) never speaks it again.
var _blips: NarrationBlipsScript
var _voiced_line := ""
## Whether this panel speaks the CRT focus cinematic, and the line of it shown (-1 for none).
var _crt_focus := false
var _focus_line := -1
var _watch: PropertyWatchScript = PropertyWatchScript.new(self, {
	PropertyKeysScript.CHAPTER_ONE_PROGRESS: _on_progress,
	PropertyKeysScript.LOCALE: _on_locale,
	PropertyKeysScript.SETTINGS_OPEN: _on_settings_open,
})
@onready var _black := $OpeningBlack as ColorRect
@onready var _line := $OpeningNarrationColumn/OpeningNarrationLine as Label
@onready var _hint := $OpeningNarrationColumn/OpeningNarrationHint as Label


func _ready() -> void:
	# The old version voiced the narration with a blip per character; the owner missed it in the demo.
	_blips = NarrationBlipsScript.new()
	add_child(_blips)
	# Hiding the panel (the Session mode leaves the prologue) ends the voice with it.
	visibility_changed.connect(_on_visibility_changed)
	_watch.start()
	_repaint()


func _process(delta: float) -> void:
	if _black_left <= 0.0 or _settings_open:
		return
	_black_left -= maxf(delta, 0.0)
	if _black_left <= 0.0:
		_repaint()


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_stop_voice()


func _stop_voice() -> void:
	_voiced_line = ""
	if _blips != null:
		_blips.stop()


## Makes this panel the CRT focus cinematic's, before it enters the tree: the narrator is the opening's (the old
## version reused its opening narration control), so it shares the look, the font and the voice.
func configure_crt_focus() -> void:
	_crt_focus = true
	_black_left = 0.0


## The cinematic's line to show, or -1 for none (the view still turning, or turning back).
func show_crt_focus_line(line_index: int) -> void:
	if not _crt_focus or line_index == _focus_line:
		return
	_focus_line = line_index
	_repaint()


## A line of the narration is on screen and can be advanced.
func is_line_shown() -> bool:
	if _crt_focus:
		return _focus_line >= 0
	return _black_left <= 0.0 and ChapterOneProgressScript.is_reading_narration(_progress)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if _settings_open or not is_line_shown():
		return
	GameEventBus.raise(UiIntentsScript.CRT_FOCUS_ADVANCED if _crt_focus else UiIntentsScript.OPENING_NARRATION_ADVANCED)


func _on_progress(value: Variant) -> void:
	_progress = ChapterOneProgressScript.normalize(value)
	_repaint()


func _on_locale(value: Variant) -> void:
	_locale = str(value)
	_repaint()


func _on_settings_open(value: Variant) -> void:
	_settings_open = bool(value)
	# Open settings silences the voice for good: the rest of the line is not spoken after it closes.
	if _blips != null:
		_blips.set_paused(_settings_open)


func _repaint() -> void:
	if not is_node_ready():
		return
	_black.visible = _black_left > 0.0
	var shown := is_line_shown()
	_line.visible = shown
	_hint.visible = shown
	if not shown:
		_stop_voice()
		return
	var lines: Array = NarrativeSessionCatalogScript.crt_focus_lines(_locale) if _crt_focus else NarrativeSessionCatalogScript.opening_lines(_locale)
	var line_index := _focus_line if _crt_focus else int(_progress.get("line_index", 0))
	var speaker := NarrativeSessionCatalogScript.opening_speaker(_locale)
	var spoken := str(lines[line_index]) if line_index < lines.size() else ""
	_line.text = speaker + spoken if line_index < lines.size() else ""
	# The speaker tag is display only: the voice reads the line without it.
	var voiced_line := "%d|%s|%s" % [line_index, _locale, spoken]
	if voiced_line != _voiced_line:
		_voiced_line = voiced_line
		_blips.speak(spoken)
	var font := LocaleFont.font(_locale)
	_line.add_theme_font_override("font", font)
	_hint.add_theme_font_override("font", font)
	_hint.text = NarrativeSessionCatalogScript.crt_focus_hint(_locale) if _crt_focus else HINT_TEXT
	var theme := GameUiThemeScript.bound()
	if theme != null:
		# The cinematic's hint comes from the catalog in the chosen language already.
		if not _crt_focus:
			theme.set_localized_property(_hint, "text")
		for label in [_line, _hint]:
			(label as Label).add_theme_color_override("font_color", theme.theme_color("surface"))

