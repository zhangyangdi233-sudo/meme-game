class_name SettingsHistoryPanel
extends Node
## Game-side history window: build, toggle, and render dialogue history entries.

var _history_window: PanelContainer
var _history_content: VBoxContainer
var _history_open := false
var _panel_factory: Callable
var _label_factory: Callable
var _theme_color_fn: Callable
var _ui_font_size_fn: Callable
var _register_draggable: Callable
var _on_close: Callable


func mount(parent: Control, deps: Dictionary) -> void:
	_panel_factory = deps.get("panel_factory", Callable())
	_label_factory = deps.get("label_factory", Callable())
	_theme_color_fn = deps.get("theme_color", Callable())
	_ui_font_size_fn = deps.get("ui_font_size", Callable())
	_register_draggable = deps.get("register_draggable", Callable())
	_on_close = deps.get("on_close", Callable())
	_build_history_window(parent)


func is_open() -> bool:
	return _history_open


func get_history_window() -> Control:
	return _history_window


func toggle(entries: Array) -> void:
	if _history_window == null:
		return
	_history_open = not _history_open
	_history_window.visible = _history_open
	if _history_open:
		refresh_history(entries)
		_history_window.move_to_front()


func close() -> void:
	_history_open = false
	if _history_window != null:
		_history_window.visible = false


func refresh_history(entries: Array) -> void:
	if _history_content == null:
		return
	for child in _history_content.get_children():
		child.queue_free()
	if entries.is_empty():
		var empty := _label_factory.call("还没有能被记住的话。", 17, _theme_color_fn.call("ink")) as Label
		empty.name = "HistoryEmptyState"
		_history_content.add_child(empty)
		return
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var line := RichTextLabel.new()
		line.name = "HistoryEntry%d" % index
		line.bbcode_enabled = true
		line.fit_content = true
		line.scroll_active = false
		line.custom_minimum_size = Vector2(500, 70)
		line.add_theme_font_size_override("normal_font_size", _ui_font_size_fn.call(17))
		line.add_theme_color_override("default_color", _theme_color_fn.call("ink"))
		var speaker := str(entry.get("currentSpeaker", entry.get("originalSpeaker", "")))
		var display_text := str(entry.get("displayText", entry.get("originalText", "")))
		line.text = "[b]%s[/b]\n%s" % [_escape_history_bbcode(speaker), _history_markup_to_bbcode(display_text)]
		_history_content.add_child(line)


func _build_history_window(parent: Control) -> void:
	if _history_window != null:
		return
	_history_window = _panel_factory.call() as PanelContainer
	_history_window.name = "HistoryWindow"
	_history_window.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_history_window.offset_left = 570
	_history_window.offset_top = 110
	_history_window.offset_right = 1160
	_history_window.offset_bottom = 760
	_history_window.z_index = 32
	_history_window.visible = false
	parent.add_child(_history_window)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	_history_window.add_child(outer)
	var title_bar := HBoxContainer.new()
	title_bar.name = "HistoryTitleBar"
	title_bar.custom_minimum_size.y = 54
	outer.add_child(title_bar)
	_register_draggable.call(_history_window, "history", title_bar)
	var title := _label_factory.call("历史记录", 23, _theme_color_fn.call("accent")) as Label
	title.name = "HistoryWindowHandle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.set_meta("skip_localization", true)
	title_bar.add_child(title)
	_register_draggable.call(_history_window, "history", title)
	var close_button := Button.new()
	close_button.name = "HistoryCloseButton"
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(56, 56)
	close_button.pressed.connect(_on_close_button_pressed)
	title_bar.add_child(close_button)

	var scroll := ScrollContainer.new()
	scroll.name = "HistoryScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	_history_content = VBoxContainer.new()
	_history_content.name = "HistoryContent"
	_history_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_history_content)


func _on_close_button_pressed() -> void:
	if _on_close.is_valid():
		_on_close.call()


func _escape_history_bbcode(value: String) -> String:
	return value.replace("[", "[lb]").replace("]", "[rb]")


func _history_markup_to_bbcode(value: String) -> String:
	var escaped := _escape_history_bbcode(value)
	return escaped.replace("{del}", "[s]").replace("{/del}", "[/s]").replace("{ins}", "[u]").replace("{/ins}", "[/u]")
