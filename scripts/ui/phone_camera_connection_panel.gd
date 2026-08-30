class_name PhoneCameraConnectionPanel
extends Node
## Game-side phone camera connection overlay: status copy, retry/continue/disable chrome.

signal retry_requested
signal continue_requested
signal disable_requested

const TRACKING_ERROR_STATUSES := [
	"手部追踪端口不可用",
	"手部追踪数据版本不匹配",
	"缺少手部追踪程序",
	"缺少手部追踪模型",
	"缺少 MediaPipe 环境",
	"无法启动手部追踪程序",
	"摄像头不可用或权限被拒绝",
	"手部追踪程序发生错误",
]

var _overlay: Control
var _panel: PanelContainer
var _status_label: Label
var _detail_label: Label
var _retry_button: Button
var _continue_button: Button

var _label_factory: Callable
var _theme_color_fn: Callable
var _soft_style_fn: Callable
var _panel_factory: Callable
var _set_localized_property_fn: Callable


func build(parent: Control, deps: Dictionary = {}) -> void:
	_apply_mount_deps(deps)
	if parent == null or not _label_factory.is_valid() or not _theme_color_fn.is_valid():
		return
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_build_overlay(parent)


func get_overlay() -> Control:
	return _overlay


func show_overlay() -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	_overlay.visible = true
	_overlay.move_to_front()


func hide_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.visible = false


func refresh(view: Dictionary) -> void:
	if _overlay == null or _status_label == null or _detail_label == null:
		return
	var camera_enabled := bool(view.get("camera_enabled", false))
	var camera_source := str(view.get("camera_source", "computer"))
	var camera_ready_source := str(view.get("camera_ready_source", ""))
	var camera_ready_index := int(view.get("camera_ready_index", -1))
	var camera_tracking_status := str(view.get("camera_tracking_status", ""))

	var state := "off"
	var status_text := "手机镜头未启用"
	var detail_text := "返回设置，点击“连接手机摄像头并开启 X-ray”后再试。"
	if camera_enabled and camera_source == "phone":
		if camera_ready_source == "phone":
			state = "ready"
			status_text = "手机镜头已连入"
			detail_text = "已从系统摄像头编号 %d 收到画面。放下游戏内手机，用双手拇指与食指的四个指尖框出矩形。" % camera_ready_index
		elif _tracking_has_error(camera_tracking_status):
			state = "error"
			status_text = "手机镜头连接失败"
			detail_text = "没有收到手机画面：%s。请解锁手机，确认系统摄像头权限，再重新扫描。" % camera_tracking_status
		else:
			state = "searching"
			status_text = "正在寻找手机镜头…"
			detail_text = "当前测试版会在系统摄像头列表中寻找 Continuity Camera 或虚拟摄像头。请先解锁手机，并允许电脑把它作为摄像头。"

	_overlay.set_meta("connection_state", state)
	_overlay.set_meta("camera_source", camera_source)
	_overlay.set_meta("selected_index", camera_ready_index)
	_status_label.text = status_text
	_detail_label.text = detail_text
	if _set_localized_property_fn.is_valid():
		_set_localized_property_fn.call(_status_label, "text")
		_set_localized_property_fn.call(_detail_label, "text")
	if _panel != null and _soft_style_fn.is_valid() and _theme_color_fn.is_valid():
		var border_color: Color = _theme_color_fn.call("muted")
		if state == "ready":
			border_color = _theme_color_fn.call("accent")
		elif state == "error":
			border_color = Color("9f493f")
		_panel.add_theme_stylebox_override(
			"panel",
			_soft_style_fn.call(_theme_color_fn.call("surface"), border_color)
		)
	if _retry_button != null:
		_retry_button.disabled = not camera_enabled or camera_source != "phone"
	if _continue_button != null:
		_continue_button.text = "进入 X-ray 玩法" if state == "ready" else "继续游戏"
		if _set_localized_property_fn.is_valid():
			_set_localized_property_fn.call(_continue_button, "text")


func close() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_panel = null
	_status_label = null
	_detail_label = null
	_retry_button = null
	_continue_button = null


func _apply_mount_deps(deps: Dictionary) -> void:
	if deps.is_empty():
		return
	_label_factory = deps.get("label_factory", Callable())
	_theme_color_fn = deps.get("theme_color", Callable())
	_soft_style_fn = deps.get("soft_style", Callable())
	_panel_factory = deps.get("panel_factory", Callable())
	_set_localized_property_fn = deps.get("set_localized_property", Callable())


func _build_overlay(parent: Control) -> void:
	_overlay = Control.new()
	_overlay.name = "PhoneCameraConnectionOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.z_index = 205
	_overlay.visible = false
	parent.add_child(_overlay)

	var blackout := ColorRect.new()
	blackout.name = "PhoneCameraConnectionBackdrop"
	blackout.color = Color(0.01, 0.025, 0.015, 0.82)
	blackout.set_anchors_preset(Control.PRESET_FULL_RECT)
	blackout.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(blackout)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 24.0
	center.offset_top = 24.0
	center.offset_right = -24.0
	center.offset_bottom = -24.0
	_overlay.add_child(center)

	if _panel_factory.is_valid():
		_panel = _panel_factory.call() as PanelContainer
	else:
		_panel = PanelContainer.new()
	_panel.name = "PhoneCameraConnectionPanel"
	_panel.custom_minimum_size = Vector2(680.0, 460.0)
	center.add_child(_panel)

	var box := VBoxContainer.new()
	box.name = "PhoneCameraConnectionContent"
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)

	var eyebrow := _label_factory.call("REMOTE LENS  /  LOCAL PROCESSING", 14, _theme_color_fn.call("accent")) as Label
	eyebrow.name = "PhoneCameraConnectionEyebrow"
	box.add_child(eyebrow)
	var title := _label_factory.call("手机镜头连接", 30, _theme_color_fn.call("ink")) as Label
	title.name = "PhoneCameraConnectionTitle"
	box.add_child(title)

	_status_label = _label_factory.call("正在寻找手机镜头…", 21, _theme_color_fn.call("accent")) as Label
	_status_label.name = "PhoneCameraConnectionStatus"
	box.add_child(_status_label)
	_detail_label = _label_factory.call("", 16, _theme_color_fn.call("ink")) as Label
	_detail_label.name = "PhoneCameraConnectionDetail"
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.custom_minimum_size.y = 128.0
	box.add_child(_detail_label)

	var privacy_note := _label_factory.call("画面只交给本机 MediaPipe 计算关键点；游戏不保存视频。", 14, _theme_color_fn.call("accent")) as Label
	privacy_note.name = "PhoneCameraConnectionPrivacyNote"
	privacy_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(privacy_note)

	var actions := HBoxContainer.new()
	actions.name = "PhoneCameraConnectionActions"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	box.add_child(actions)

	_retry_button = Button.new()
	_retry_button.name = "PhoneCameraConnectionRetryButton"
	_retry_button.text = "重新扫描手机镜头"
	_retry_button.custom_minimum_size = Vector2(210.0, 54.0)
	_retry_button.pressed.connect(_on_retry_pressed)
	actions.add_child(_retry_button)

	_continue_button = Button.new()
	_continue_button.name = "PhoneCameraConnectionContinueButton"
	_continue_button.text = "继续游戏"
	_continue_button.custom_minimum_size = Vector2(150.0, 54.0)
	_continue_button.pressed.connect(_on_continue_pressed)
	actions.add_child(_continue_button)

	var disable_button := Button.new()
	disable_button.name = "PhoneCameraConnectionDisableButton"
	disable_button.text = "关闭摄像头"
	disable_button.custom_minimum_size = Vector2(150.0, 54.0)
	disable_button.pressed.connect(_on_disable_pressed)
	actions.add_child(disable_button)


func _tracking_has_error(status: String) -> bool:
	return status in TRACKING_ERROR_STATUSES


func _on_retry_pressed() -> void:
	retry_requested.emit()


func _on_continue_pressed() -> void:
	continue_requested.emit()


func _on_disable_pressed() -> void:
	disable_requested.emit()
