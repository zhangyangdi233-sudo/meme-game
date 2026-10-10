extends SceneTree
## LanguageSelectionPanel: an open picker watches the language model and marks the current choice; closing stops.

const PanelScript = preload("res://scripts/ui/language_selection_panel.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const BootScript = preload("res://scripts/game/property_boot.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")

const LOCALES := [
	{"code": "zh", "name": "中文"},
	{"code": "ja", "name": "日本語"},
	{"code": "en", "name": "English"},
]

var _failures: Array[String] = []
var _selected: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _run()
	if _failures.is_empty():
		print("language selection panel tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	RegistryScript.clear()
	BootScript.install()
	var locale := _model(PropertyKeysScript.LOCALE)
	locale.write("ja")

	var host := Control.new()
	host.size = Vector2(1600, 900)
	root.add_child(host)
	var panel := PanelScript.new() as LanguageSelectionPanel
	root.add_child(panel)
	panel.language_selected.connect(func(code: String) -> void: _selected.append(code))

	panel.build(host, false, _deps())
	_assert_eq(_marked(panel), ["ja"], "building the picker should mark the current language")

	locale.write("en")
	_assert_eq(_marked(panel), ["en"], "an open picker should follow language writes")
	_assert_true(_selected.is_empty(), "following the model should not emit a selection")

	var choice := _choice(panel, "zh")
	if choice != null:
		choice.pressed.emit()
	_assert_eq(_selected, ["zh"], "pressing a choice should still emit the locale code")
	_assert_eq(_marked(panel), ["en"], "pressing a choice should not move the mark until the model changes")

	panel.build(host, false, _deps())
	locale.write("zh")
	_assert_eq(_marked(panel), ["zh"], "rebuilding should watch the language once for the new overlay")

	var closed_overlay: Control = panel.get_overlay()
	_assert_true(panel.close(), "a non-first-run picker should close")
	locale.write("ja")
	_assert_eq(_marked_in(closed_overlay), ["zh"], "a closed picker should stop receiving the language")

	panel.build(host, false, _deps())
	_assert_eq(_marked(panel), ["ja"], "reopening the picker should sync again")
	panel.queue_free()
	await process_frame
	locale.write("en")
	_assert_true(_model_listener_count(locale) == 0, "a freed picker should unregister")

	host.queue_free()
	await process_frame


func _deps() -> Dictionary:
	return {
		"soft_style": func(_bg: Color, _border: Color) -> StyleBoxFlat: return StyleBoxFlat.new(),
		"theme_color": func(_key: String) -> Color: return Color.WHITE,
		"ui_font_size": func(requested: int) -> int: return requested,
		"locales": LOCALES,
	}


func _marked(panel: LanguageSelectionPanel) -> Array:
	var overlay: Control = panel.get_overlay()
	if overlay == null:
		return []
	return _marked_in(overlay)


func _marked_in(overlay: Control) -> Array:
	var marked: Array = []
	for entry in LOCALES:
		var code := str(entry["code"])
		var button := overlay.find_child("LanguageChoice%s" % code.to_upper(), true, false) as Button
		if button != null and button.button_pressed:
			marked.append(code)
	return marked


func _choice(panel: LanguageSelectionPanel, code: String) -> Button:
	var overlay: Control = panel.get_overlay()
	if overlay == null:
		return null
	return overlay.find_child("LanguageChoice%s" % code.to_upper(), true, false) as Button


func _model_listener_count(model: PropertyModel) -> int:
	return model.changed.get_connections().size()


func _model(property_name: String) -> ValuePropertyModel:
	var manager := RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	return manager.model(property_name) as ValuePropertyModel


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
