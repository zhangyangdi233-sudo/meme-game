class_name PlaytestAssistPanel
extends Node
## Debug/playtest assist chrome. The host says whether it shows and supplies the route lines;
## while shown, the panel watches the tutorial progress and leads with the current step hint itself.

const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const PropertyWatchScript = preload("res://scripts/game/property_watch.gd")
const GuideLineScript = preload("res://scripts/tutorial/guide_line.gd")

var _overlay: PanelContainer
var _body_label: Label

var _label_factory: Callable
var _theme_color_fn: Callable
var _panel_factory: Callable

var _progress: Dictionary = {}
var _extra_lines: Array = []
var _watch: PropertyWatchScript = PropertyWatchScript.new(self, {
	PropertyKeysScript.TUTORIAL_PROGRESS: _on_progress,
})


func mount(parent: Control, deps: Dictionary = {}) -> void:
	_apply_mount_deps(deps)
	if parent == null or not _label_factory.is_valid() or not _theme_color_fn.is_valid():
		return
	_watch.stop()
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_build_overlay(parent)


func get_overlay() -> PanelContainer:
	return _overlay


func render(state: Dictionary) -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	_overlay.visible = bool(state.get("visible", false))
	if not _overlay.visible:
		_watch.stop()
		return
	_extra_lines = (state.get("lines", []) as Array).duplicate()
	_watch.start()
	_paint()


func _on_progress(value: Variant) -> void:
	_progress = value as Dictionary
	_paint()


func _paint() -> void:
	if _body_label == null or not is_instance_valid(_body_label):
		return
	var lines: Array = [GuideLineScript.test_instruction(_progress)]
	lines.append_array(_extra_lines)
	_body_label.text = "\n".join(lines)


func _apply_mount_deps(deps: Dictionary) -> void:
	if deps.is_empty():
		return
	_label_factory = deps.get("label_factory", Callable())
	_theme_color_fn = deps.get("theme_color", Callable())
	_panel_factory = deps.get("panel_factory", Callable())


func _build_overlay(parent: Control) -> void:
	_overlay = _panel_factory.call() as PanelContainer if _panel_factory.is_valid() else PanelContainer.new()
	_overlay.name = "PlaytestAssistPanel"
	_overlay.set_meta("dark_rail", true)
	_overlay.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_overlay.offset_left = -474.0
	_overlay.offset_top = 24.0
	_overlay.offset_right = -24.0
	_overlay.offset_bottom = 178.0
	_overlay.z_index = 44
	_overlay.visible = true
	parent.add_child(_overlay)
	var assist_box := VBoxContainer.new()
	assist_box.add_theme_constant_override("separation", 6)
	_overlay.add_child(assist_box)
	var title: Label = _label_factory.call("缝线布偶 / GUIDE", 13, _theme_color_fn.call("muted")) as Label
	title.set_meta("on_dark", true)
	assist_box.add_child(title)
	_body_label = _label_factory.call("", 15, _theme_color_fn.call("surface")) as Label
	_body_label.name = "PlaytestAssistLabel"
	_body_label.set_meta("on_dark", true)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	assist_box.add_child(_body_label)
