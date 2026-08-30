class_name CameraConsentPanel
extends Node
## Game-side camera consent overlay: privacy copy, source picker, and allow/skip chrome.

signal consent_resolved(allowed: bool)
signal source_selected(index: int)

var _overlay: Control
var _source_option: OptionButton

var _label_factory: Callable
var _theme_color_fn: Callable
var _soft_style_fn: Callable
var _populate_camera_source_option_fn: Callable
var _camera_enabled := false
var _apply_ui_theme_fn: Callable
var _refresh_localized_ui_fn: Callable


func build(parent: Control, deps: Dictionary = {}) -> void:
	_apply_mount_deps(deps)
	if parent == null or not _label_factory.is_valid() or not _theme_color_fn.is_valid():
		return
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_build_overlay(parent)
	if _apply_ui_theme_fn.is_valid():
		_apply_ui_theme_fn.call()
	if _refresh_localized_ui_fn.is_valid():
		_refresh_localized_ui_fn.call()


func get_overlay() -> Control:
	return _overlay


func get_source_option() -> OptionButton:
	return _source_option


func close() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_source_option = null


func _apply_mount_deps(deps: Dictionary) -> void:
	if deps.is_empty():
		return
	_label_factory = deps.get("label_factory", Callable())
	_theme_color_fn = deps.get("theme_color", Callable())
	_soft_style_fn = deps.get("soft_style", Callable())
	_populate_camera_source_option_fn = deps.get("populate_camera_source_option", Callable())
	_camera_enabled = bool(deps.get("camera_enabled", false))
	_apply_ui_theme_fn = deps.get("apply_ui_theme", Callable())
	_refresh_localized_ui_fn = deps.get("refresh_localized_ui", Callable())


func _build_overlay(parent: Control) -> void:
	_overlay = Control.new()
	_overlay.name = "CameraConsentOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.z_index = 210
	parent.add_child(_overlay)

	var blackout := ColorRect.new()
	blackout.name = "CameraConsentBackdrop"
	blackout.color = Color(_theme_color_fn.call("ink"), 0.94)
	blackout.set_anchors_preset(Control.PRESET_FULL_RECT)
	blackout.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(blackout)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "CameraConsentPanel"
	panel.custom_minimum_size = Vector2(720, 520)
	panel.add_theme_stylebox_override("panel", _soft_style_fn.call(_theme_color_fn.call("surface"), _theme_color_fn.call("accent")))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	var eyebrow := _label_factory.call("LOCAL VISION  /  FOUR FINGERTIPS", 15, _theme_color_fn.call("accent")) as Label
	eyebrow.name = "CameraConsentEyebrow"
	box.add_child(eyebrow)
	var title := _label_factory.call("摄像头与 X-RAY", 30, _theme_color_fn.call("ink")) as Label
	title.name = "CameraConsentTitle"
	box.add_child(title)
	var consent_copy := _label_factory.call(
		"用双手拇指与食指的四个指尖框出矩形区域，区域内会显示手机层。视频只在本机用于关键点计算，不写入存档。",
		18,
		_theme_color_fn.call("ink"),
	) as Label
	consent_copy.name = "CameraConsentPrivacyCopy"
	consent_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	consent_copy.custom_minimum_size.y = 110
	box.add_child(consent_copy)
	var source_guidance := _label_factory.call("默认使用电脑摄像头；手机只作为没有电脑镜头时的备用。", 15, _theme_color_fn.call("accent")) as Label
	source_guidance.name = "CameraConsentSourceGuidance"
	box.add_child(source_guidance)
	var source_label := _label_factory.call("摄像头来源", 16, _theme_color_fn.call("ink")) as Label
	box.add_child(source_label)
	_source_option = OptionButton.new()
	_source_option.name = "CameraConsentSourceOption"
	_source_option.set_meta("skip_localization", true)
	_source_option.custom_minimum_size = Vector2(440, 52)
	if _populate_camera_source_option_fn.is_valid():
		_populate_camera_source_option_fn.call(_source_option)
	_source_option.item_selected.connect(_on_source_option_selected)
	box.add_child(_source_option)
	var previous_choice := _label_factory.call(
		"上次设置为允许；本次仍需要你确认。" if _camera_enabled else "镜头默认关闭，点击允许后才会启动。",
		15,
		_theme_color_fn.call("accent"),
	) as Label
	previous_choice.name = "CameraConsentPreviousChoice"
	box.add_child(previous_choice)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14)
	box.add_child(actions)
	var allow_button := Button.new()
	allow_button.name = "CameraConsentAllowButton"
	allow_button.text = "允许并打开摄像头"
	allow_button.custom_minimum_size = Vector2(260, 58)
	allow_button.pressed.connect(_on_allow_pressed)
	actions.add_child(allow_button)
	var skip_button := Button.new()
	skip_button.name = "CameraConsentSkipButton"
	skip_button.text = "暂不使用"
	skip_button.custom_minimum_size = Vector2(190, 58)
	skip_button.pressed.connect(_on_skip_pressed)
	actions.add_child(skip_button)


func _on_allow_pressed() -> void:
	consent_resolved.emit(true)


func _on_skip_pressed() -> void:
	consent_resolved.emit(false)


func _on_source_option_selected(index: int) -> void:
	source_selected.emit(index)
