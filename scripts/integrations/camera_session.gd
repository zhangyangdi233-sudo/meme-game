extends Node
class_name CameraSession
## Hand-tracking camera source, X-ray overlay, and tracking status for the main scene adapter.
## Settings UI wiring and locale persistence stay in babel_meme_game.gd.

const HandTrackingReceiverScript = preload("res://framework/integrations/hand_tracking_receiver.gd")
const HandXRayOverlayScript = preload("res://framework/ui/hand_xray_overlay.gd")

signal tracking_ui_changed()

var enabled := false
var source := "computer"
var tracking_status := "摄像头未启用"
var ready_source := ""
var ready_index := -1

var hand_xray_overlay: Control
var second_layer_texture: Texture2D

var access_toggle: CheckButton
var computer_button: Button
var phone_button: Button
var status_label: Label
var consent_source_option: OptionButton

var hand_tracking_receiver
var _host: Node


func attach_to(host: Node) -> void:
	_host = host
	name = "CameraSession"
	host.add_child(self)


func ensure_receiver() -> void:
	if hand_tracking_receiver != null:
		return
	hand_tracking_receiver = HandTrackingReceiverScript.new()
	hand_tracking_receiver.camera_source = source
	hand_tracking_receiver.frame_received.connect(_on_hand_tracking_frame)
	hand_tracking_receiver.status_changed.connect(_on_hand_tracking_status_changed)
	hand_tracking_receiver.source_ready.connect(_on_camera_source_ready)


func poll_receiver() -> void:
	if hand_tracking_receiver != null:
		hand_tracking_receiver.poll()


func stop_receiver() -> void:
	if hand_tracking_receiver != null:
		hand_tracking_receiver.stop()


func reset_session() -> void:
	hand_xray_overlay = null
	second_layer_texture = null
	ready_source = ""
	ready_index = -1


func set_enabled(value: bool, deps: Dictionary, persist: bool = true) -> void:
	enabled = value
	ready_source = ""
	ready_index = -1
	ensure_receiver()
	hand_tracking_receiver.camera_source = source
	if value:
		hand_tracking_receiver.start(true)
		tracking_status = hand_tracking_receiver.get_status()
	else:
		hand_tracking_receiver.stop()
		tracking_status = "摄像头未启用"
	if access_toggle != null:
		access_toggle.set_pressed_no_signal(value)
	if hand_xray_overlay != null:
		hand_xray_overlay.set_tracking_enabled(value)
	refresh_source_buttons()
	refresh_status_ui(deps)
	if value and source == "phone":
		var on_phone: Callable = deps.get("on_phone_source_enabled", Callable())
		if on_phone.is_valid():
			on_phone.call()
	elif not value:
		var on_disabled: Callable = deps.get("on_camera_disabled", Callable())
		if on_disabled.is_valid():
			on_disabled.call()
	var refresh_phone: Callable = deps.get("refresh_phone_connection_ui", Callable())
	if refresh_phone.is_valid():
		refresh_phone.call()
	if persist:
		var persist_fn: Callable = deps.get("persist_preferences", Callable())
		if persist_fn.is_valid():
			persist_fn.call()


func set_source(value: String, deps: Dictionary, persist: bool = true) -> void:
	var normalized := value if value in ["computer", "phone"] else "computer"
	var changed := source != normalized
	source = normalized
	if changed:
		ready_source = ""
		ready_index = -1
	ensure_receiver()
	hand_tracking_receiver.camera_source = source
	if changed and enabled:
		hand_tracking_receiver.stop()
		hand_tracking_receiver.start(true)
		tracking_status = hand_tracking_receiver.get_status()
	sync_source_options()
	refresh_source_buttons()
	refresh_status_ui(deps)
	if source == "computer":
		var hide_phone: Callable = deps.get("hide_phone_connection_overlay", Callable())
		if hide_phone.is_valid():
			hide_phone.call()
	elif enabled:
		var show_phone: Callable = deps.get("on_phone_source_enabled", Callable())
		if show_phone.is_valid():
			show_phone.call()
	var refresh_phone: Callable = deps.get("refresh_phone_connection_ui", Callable())
	if refresh_phone.is_valid():
		refresh_phone.call()
	if persist:
		var persist_fn: Callable = deps.get("persist_preferences", Callable())
		if persist_fn.is_valid():
			persist_fn.call()


func activate_source(normalized_source: String, deps: Dictionary) -> void:
	var normalized := normalized_source if normalized_source in ["computer", "phone"] else "computer"
	if enabled:
		set_enabled(false, deps, false)
	set_source(normalized, deps, false)
	set_enabled(true, deps, true)
	if normalized == "phone":
		var show_phone: Callable = deps.get("on_phone_source_enabled", Callable())
		if show_phone.is_valid():
			show_phone.call()
	else:
		var hide_phone: Callable = deps.get("hide_phone_connection_overlay", Callable())
		if hide_phone.is_valid():
			hide_phone.call()


func populate_source_option(option: OptionButton, deps: Dictionary) -> void:
	if option == null:
		return
	option.clear()
	var translate: Callable = deps.get("locale_translate", Callable())
	for entry in [
		{"id": "computer", "label": "电脑摄像头（默认）"},
		{"id": "phone", "label": "手机摄像头（备用）"},
	]:
		option.add_item(translate.call(str(entry["label"])) if translate.is_valid() else str(entry["label"]))
		var item_index := option.item_count - 1
		option.set_item_metadata(item_index, entry["id"])
		if str(entry["id"]) == source:
			option.select(item_index)


func sync_source_options() -> void:
	for option in [consent_source_option]:
		if option == null:
			continue
		for item_index in option.item_count:
			if str(option.get_item_metadata(item_index)) == source:
				option.select(item_index)
				break


func refresh_source_option_labels(deps: Dictionary) -> void:
	var translate: Callable = deps.get("locale_translate", Callable())
	for option in [consent_source_option]:
		if option == null or option.item_count < 2:
			continue
		option.set_item_text(0, translate.call("电脑摄像头（默认）") if translate.is_valid() else "电脑摄像头（默认）")
		option.set_item_text(1, translate.call("手机摄像头（备用）") if translate.is_valid() else "手机摄像头（备用）")


func refresh_source_buttons() -> void:
	if computer_button != null:
		computer_button.set_pressed_no_signal(enabled and source == "computer")
		computer_button.set_meta("camera_source_selected", enabled and source == "computer")
		computer_button.set_meta("camera_source_ready", ready_source == "computer")
	if phone_button != null:
		phone_button.set_pressed_no_signal(enabled and source == "phone")
		phone_button.set_meta("camera_source_selected", enabled and source == "phone")
		phone_button.set_meta("camera_source_ready", ready_source == "phone")


func refresh_status_ui(deps: Dictionary) -> void:
	if status_label != null:
		status_label.text = tracking_status
		var localize: Callable = deps.get("set_localized_property", Callable())
		if localize.is_valid():
			localize.call(status_label, "text")


func capture_phone_layer_for_xray(deps: Dictionary) -> bool:
	var game_started := bool(deps.get("game_started", false))
	if not game_started or _host == null or _host.get_viewport() == null or DisplayServer.get_name().to_lower() == "headless":
		return false
	var viewport_texture := _host.get_viewport().get_texture()
	if viewport_texture == null:
		return false
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		return false
	second_layer_texture = ImageTexture.create_from_image(image)
	if hand_xray_overlay != null:
		hand_xray_overlay.set_layer_texture(second_layer_texture)
	return true


func build_hand_xray_overlay(deps: Dictionary) -> void:
	var ui_root: Control = deps.get("ui_root")
	if ui_root == null:
		return
	hand_xray_overlay = HandXRayOverlayScript.new()
	hand_xray_overlay.name = "HandXRayOverlay"
	hand_xray_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	hand_xray_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_xray_overlay.z_index = 9
	ui_root.add_child(hand_xray_overlay)
	var initial_texture: Texture2D = second_layer_texture
	var backdrop: TextureRect = deps.get("phone_down_backdrop_image")
	if initial_texture == null and backdrop != null:
		initial_texture = backdrop.texture
	hand_xray_overlay.set_layer_texture(initial_texture)
	hand_xray_overlay.set_tracking_enabled(enabled)


func connection_view() -> Dictionary:
	return {
		"camera_enabled": enabled,
		"camera_source": source,
		"camera_ready_source": ready_source,
		"camera_ready_index": ready_index,
		"camera_tracking_status": tracking_status,
	}


func _on_hand_tracking_frame(hands: Array, _timestamp_msec: int) -> void:
	var frame_locked := false
	if hand_xray_overlay != null:
		frame_locked = hand_xray_overlay.ingest_hands(hands, Time.get_ticks_msec())
	var receiver_status: String = str(hand_tracking_receiver.get_status()) if hand_tracking_receiver != null else ""
	if frame_locked:
		tracking_status = "已锁定指尖窗口"
	elif receiver_status in ["摄像头不可用或权限被拒绝", "手部追踪程序发生错误"]:
		tracking_status = receiver_status
	else:
		tracking_status = "等待双手四指框选"
	tracking_ui_changed.emit()


func _on_hand_tracking_status_changed(status: String) -> void:
	tracking_status = status
	if status in ["摄像头不可用或权限被拒绝", "手部追踪程序发生错误", "无法启动手部追踪程序"]:
		ready_source = ""
		ready_index = -1
	tracking_ui_changed.emit()


func _on_camera_source_ready(new_source: String, selected_index: int) -> void:
	if new_source not in ["computer", "phone"]:
		return
	ready_source = new_source
	ready_index = selected_index
	tracking_ui_changed.emit()
