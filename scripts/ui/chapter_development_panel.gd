extends PanelContainer

## Explicit development controls. Production task/narration systems use the same
## event bridge; this panel never advances progress by time or player movement.
signal event_requested(event_id: String, payload: Dictionary)

var _enabled := false
var _progress: Dictionary = {}
var _help_available := false
var _status: Label
var _narration: Button
var _help: Button


func configure(enabled: bool) -> void:
	_enabled = enabled and OS.is_debug_build()
	visible = _enabled
	if not _enabled or _status != null:
		return
	name = "ChapterDevelopmentPanel"
	z_index = 20
	position = Vector2(24, 24)
	custom_minimum_size = Vector2(380, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var title := Label.new()
	title.name = "ChapterDevelopmentTitle"
	title.text = "DEVELOPMENT VALIDATION / NOT STORY"
	title.add_theme_color_override("font_color", Color(1.0, 0.77, 0.35))
	column.add_child(title)
	_status = Label.new()
	_status.name = "ChapterDevelopmentStatus"
	column.add_child(_status)
	_narration = Button.new()
	_narration.name = "ChapterDevNarration"
	_narration.text = "DEV: emit narration completed"
	_narration.pressed.connect(_request_narration)
	column.add_child(_narration)
	_help = Button.new()
	_help.name = "ChapterDevHelp"
	_help.text = "DEV: complete nearby NPC task"
	_help.pressed.connect(_request_help)
	column.add_child(_help)
	_refresh()


func show_progress(progress: Dictionary) -> void:
	if _progress.get("transition_serial", -1) != progress.get("transition_serial", -1):
		_help_available = false
	_progress = progress.duplicate(true)
	_refresh()


func set_help_available(available: bool) -> void:
	_help_available = available
	_refresh()


func _refresh() -> void:
	if _status == null:
		return
	var phase := str(_progress.get("phase", ""))
	var visit := int(_progress.get("round_index", 0)) + 1
	var items: Array = _progress.get("unlocked_app_ids", [])
	_status.text = "Phase: %s\nVisit: %d / 5    Phone apps: %d / 3\nEsc / F10: settings    F: interact\nF9: hide/show panel" % [phase, visit, items.size()]
	_narration.disabled = not _enabled or phase != "opening" or bool(_progress.get("narrator_completed", false))
	var task_id := "basement_help_%02d" % visit
	_help.disabled = not _enabled or phase != "basement" or not _help_available or not bool(_progress.get("entrance_locked", false)) or task_id in _progress.get("completed_task_ids", [])


func _request_narration() -> void:
	if not _enabled or _narration == null or _narration.disabled:
		return
	event_requested.emit("narration_completed", {"sequence_id": "chapter1_opening"})


func _request_help() -> void:
	if not _enabled or _help == null or _help.disabled:
		return
	var visit := int(_progress.get("round_index", 0)) + 1
	event_requested.emit("npc_help_completed", {
		"npc_id": "basement_npc_%02d" % visit,
		"task_id": "basement_help_%02d" % visit,
		"round_token": int(_progress.get("transition_serial", -1)),
	})
