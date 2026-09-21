class_name LanguageSelectionPanel
extends Node
## Game-side language selection overlay: first-run picker and in-menu language switcher chrome.

signal language_selected(locale_code: String)

var _language_overlay: Control
var _language_overlay_first_run := false
var _soft_style_fn: Callable
var _theme_color_fn: Callable
var _ui_font_size_fn: Callable
var _language_selected_fn: Callable
var _refresh_localized_ui_fn: Callable
var _locales: Array = []


func build(parent: Control, first_run: bool = false, deps: Dictionary = {}) -> void:
	_apply_mount_deps(deps)
	if parent == null or not _soft_style_fn.is_valid() or not _theme_color_fn.is_valid():
		return
	if _language_overlay != null and is_instance_valid(_language_overlay):
		_language_overlay.queue_free()
	_language_overlay_first_run = first_run
	_language_overlay = Control.new()
	_language_overlay.name = "LanguageSelectionOverlay"
	_language_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_language_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_language_overlay.z_index = 190
	parent.add_child(_language_overlay)

	var blackout := ColorRect.new()
	blackout.name = "LanguageSelectionBackdrop"
	blackout.color = Color(_theme_color_fn.call("ink"), 0.92)
	blackout.set_anchors_preset(Control.PRESET_FULL_RECT)
	blackout.mouse_filter = Control.MOUSE_FILTER_STOP
	_language_overlay.add_child(blackout)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_language_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "LanguageSelectionPanel"
	panel.custom_minimum_size = Vector2(620, 390)
	panel.add_theme_stylebox_override("panel", _soft_style_fn.call(_theme_color_fn.call("surface"), _theme_color_fn.call("accent")))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	var eyebrow := Label.new()
	eyebrow.text = "BABEL PHONE  /  LANGUAGE"
	eyebrow.add_theme_font_size_override("font_size", _ui_font_size_fn.call(15))
	eyebrow.add_theme_color_override("font_color", _theme_color_fn.call("accent"))
	box.add_child(eyebrow)
	var title := Label.new()
	title.name = "LanguageSelectionTitle"
	title.text = "选择语言  /  言語を選択  /  CHOOSE LANGUAGE"
	title.add_theme_font_size_override("font_size", _ui_font_size_fn.call(27))
	title.add_theme_color_override("font_color", _theme_color_fn.call("ink"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var rule := HSeparator.new()
	box.add_child(rule)

	var choices := VBoxContainer.new()
	choices.name = "LanguageSelectionChoices"
	choices.add_theme_constant_override("separation", 10)
	box.add_child(choices)
	for locale_entry in _locales:
		var locale_code := str(locale_entry.get("code", ""))
		if locale_code.is_empty():
			continue
		var choice := Button.new()
		choice.name = "LanguageChoice%s" % locale_code.to_upper()
		choice.text = str(locale_entry.get("name", locale_code))
		choice.custom_minimum_size = Vector2(500, 58)
		choice.set_meta("skip_localization", true)
		choice.pressed.connect(_on_choice_pressed.bind(locale_code))
		choices.add_child(choice)

	if not first_run:
		var cancel := Button.new()
		cancel.name = "LanguageSelectionCancel"
		cancel.text = "返回"
		cancel.custom_minimum_size.y = 50
		cancel.pressed.connect(_on_cancel_pressed)
		box.add_child(cancel)
	if _refresh_localized_ui_fn.is_valid():
		_refresh_localized_ui_fn.call()


func get_overlay() -> Control:
	return _language_overlay


func close() -> bool:
	if _language_overlay_first_run and _language_selected_fn.is_valid() and not bool(_language_selected_fn.call()):
		return false
	if _language_overlay != null and is_instance_valid(_language_overlay):
		_language_overlay.queue_free()
	_language_overlay = null
	_language_overlay_first_run = false
	return true


func _apply_mount_deps(deps: Dictionary) -> void:
	if deps.is_empty():
		return
	_soft_style_fn = deps.get("soft_style", Callable())
	_theme_color_fn = deps.get("theme_color", Callable())
	_ui_font_size_fn = deps.get("ui_font_size", Callable())
	_language_selected_fn = deps.get("language_selected", Callable())
	_refresh_localized_ui_fn = deps.get("refresh_localized_ui", Callable())
	_locales = deps.get("locales", [])


func _on_choice_pressed(locale_code: String) -> void:
	language_selected.emit(locale_code)


func _on_cancel_pressed() -> void:
	close()
