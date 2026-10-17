class_name CameraConsentPanel
extends Node
## Game-side camera consent overlay: privacy copy, source picker, and allow/skip chrome.

const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")

var _overlay: Control
var _source_option: OptionButton

var _populate_camera_source_option_fn: Callable
var _camera_enabled := false
var _apply_ui_theme_fn: Callable
var _refresh_localized_ui_fn: Callable


func build(parent: Control, deps: Dictionary = {}) -> void:
	_apply_mount_deps(deps)
	if parent == null or _theme() == null:
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
	blackout.color = Color(_theme().theme_color("ink"), 0.94)
	blackout.set_anchors_preset(Control.PRESET_FULL_RECT)
	blackout.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(blackout)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "CameraConsentPanel"
	panel.custom_minimum_size = Vector2(720, 520)
	panel.add_theme_stylebox_override("panel", _theme().soft_style(_theme().theme_color("surface"), _theme().theme_color("accent")))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	var eyebrow := _theme().label("LOCAL VISION  /  FOUR FINGERTIPS", 15, _theme().theme_color("accent")) as Label
	eyebrow.name = "CameraConsentEyebrow"
	box.add_child(eyebrow)
	var title := _theme().label("摄像头与 X-RAY", 30, _theme().theme_color("ink")) as Label
	title.name = "CameraConsentTitle"
	box.add_child(title)
	var consent_copy := _theme().label(
		"用双手拇指与食指的四个指尖框出矩形区域，区域内会显示手机层。视频只在本机用于关键点计算，不写入存档。",
		18,
		_theme().theme_color("ink"),
	) as Label
	consent_copy.name = "CameraConsentPrivacyCopy"
	consent_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	consent_copy.custom_minimum_size.y = 110
	box.add_child(consent_copy)
	var source_guidance := _theme().label("默认使用电脑摄像头；手机只作为没有电脑镜头时的备用。", 15, _theme().theme_color("accent")) as Label
	source_guidance.name = "CameraConsentSourceGuidance"
	box.add_child(source_guidance)
	var source_label := _theme().label("摄像头来源", 16, _theme().theme_color("ink")) as Label
	box.add_child(source_label)
	_source_option = OptionButton.new()
	_source_option.name = "CameraConsentSourceOption"
	_source_option.set_meta("skip_localization", true)
	_source_option.custom_minimum_size = Vector2(440, 52)
	if _populate_camera_source_option_fn.is_valid():
		_populate_camera_source_option_fn.call(_source_option)
	_source_option.item_selected.connect(_on_source_option_selected)
	box.add_child(_source_option)
	var previous_choice := _theme().label(
		"上次设置为允许；本次仍需要你确认。" if _camera_enabled else "镜头默认关闭，点击允许后才会启动。",
		15,
		_theme().theme_color("accent"),
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
	GameEventBus.raise(UiIntentsScript.CAMERA_CONSENT_RESOLVED, {UiIntentsScript.KEY_ALLOWED: true})


func _on_skip_pressed() -> void:
	GameEventBus.raise(UiIntentsScript.CAMERA_CONSENT_RESOLVED, {UiIntentsScript.KEY_ALLOWED: false})


func _on_source_option_selected(index: int) -> void:
	GameEventBus.raise(UiIntentsScript.CAMERA_SOURCE_SELECTED, {UiIntentsScript.KEY_INDEX: index})


## The UI theme bound by the host; panels resolve it instead of taking theme callables.
func _theme() -> GameUiTheme:
	return ServiceRegistryScript.resolve(ServiceKeysScript.UI_THEME) as GameUiTheme
