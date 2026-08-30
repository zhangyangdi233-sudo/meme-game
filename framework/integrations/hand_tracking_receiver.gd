class_name HandTrackingReceiver
extends RefCounted

signal frame_received(hands: Array, timestamp_msec: int)
signal status_changed(status: String)
signal source_ready(source: String, selected_index: int)

const DEFAULT_HOST := "127.0.0.1"
const DEFAULT_PORT := 7001
const PACKET_SCHEMA_VERSION := 1
const LOST_STREAM_TIMEOUT_MSEC := 900
const SIDECAR_SCRIPT_PATH := "res://framework/integrations/hand_tracking/hand_tracker.py"
const SIDECAR_MODEL_PATH := "res://framework/integrations/hand_tracking/models/hand_landmarker.task"
const SIDECAR_PYTHON_PATH := "res://framework/integrations/hand_tracking/.venv/bin/python"

var host := DEFAULT_HOST
var port := DEFAULT_PORT
var camera_index := 0
var camera_source := "computer"

var _udp := PacketPeerUDP.new()
var _enabled := false
var _bound := false
var _sidecar_pid := -1
var _last_packet_msec := 0
var _last_frame: Dictionary = {}
var _status := "摄像头未启用"
var _ready_source := ""
var _ready_index := -1


func start(launch_sidecar: bool = true) -> bool:
	if _enabled:
		return _bound
	_clear_ready_source()
	_enabled = true
	var bind_error := _udp.bind(port, host)
	if bind_error != OK:
		_enabled = false
		_set_status("手部追踪端口不可用")
		return false
	_bound = true
	_last_packet_msec = Time.get_ticks_msec()
	_set_status("正在启动手部追踪…")
	if launch_sidecar:
		_launch_sidecar()
	else:
		_set_status("等待手部进入画面")
	return true


func stop() -> void:
	if _sidecar_pid > 0:
		OS.kill(_sidecar_pid)
	_sidecar_pid = -1
	if _bound:
		_udp.close()
	_bound = false
	_enabled = false
	_last_frame.clear()
	_clear_ready_source()
	_set_status("摄像头未启用")


func poll() -> void:
	if not _enabled or not _bound:
		return
	var newest_packet: Variant = null
	while _udp.get_available_packet_count() > 0:
		var raw := _udp.get_packet()
		var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
		if parsed is Dictionary:
			newest_packet = parsed
	if newest_packet is Dictionary:
		ingest_packet(newest_packet)
	elif Time.get_ticks_msec() - _last_packet_msec > LOST_STREAM_TIMEOUT_MSEC:
		_set_status("等待手部追踪数据")


func ingest_packet(packet: Dictionary) -> bool:
	if int(packet.get("schema_version", -1)) != PACKET_SCHEMA_VERSION:
		_set_status("手部追踪数据版本不匹配")
		return false
	var raw_hands: Variant = packet.get("hands", [])
	if not raw_hands is Array:
		return false
	var hands: Array = []
	for raw_hand in raw_hands:
		if not raw_hand is Dictionary:
			continue
		var sanitized := _sanitize_hand(raw_hand)
		if not sanitized.is_empty():
			hands.append(sanitized)
		if hands.size() == 2:
			break
	var timestamp_msec := int(packet.get("timestamp_ms", Time.get_ticks_msec()))
	_last_packet_msec = Time.get_ticks_msec()
	_last_frame = {
		"timestamp_ms": timestamp_msec,
		"hands": hands,
		"mirrored": bool(packet.get("mirrored", true)),
		"status_code": str(packet.get("status_code", "")),
	}
	var status_code := str(packet.get("status_code", ""))
	var packet_source := str(packet.get("camera_source", camera_source))
	var selected_index := int(packet.get("selected_index", -1))
	if status_code.is_empty() and packet_source in ["computer", "phone"]:
		_mark_source_ready(packet_source, selected_index)
	match status_code:
		"camera_open_failed":
			_clear_ready_source()
			_set_status("摄像头不可用或权限被拒绝")
		"tracker_error":
			_clear_ready_source()
			_set_status("手部追踪程序发生错误")
		_:
			_set_status("已收到手部关键点" if not hands.is_empty() else "等待手部进入画面")
	frame_received.emit(hands, timestamp_msec)
	return true


func is_enabled() -> bool:
	return _enabled


func is_sidecar_running() -> bool:
	return _sidecar_pid > 0


func get_status() -> String:
	return _status


func get_last_frame() -> Dictionary:
	return _last_frame.duplicate(true)


func get_ready_source() -> String:
	return _ready_source


func get_ready_index() -> int:
	return _ready_index


func _sanitize_hand(raw_hand: Dictionary) -> Dictionary:
	var raw_landmarks: Variant = raw_hand.get("landmarks", [])
	if not raw_landmarks is Array or raw_landmarks.size() < 21:
		return {}
	var landmarks: Array = []
	for raw_landmark in raw_landmarks:
		if not raw_landmark is Dictionary:
			return {}
		landmarks.append({
			"x": clampf(float(raw_landmark.get("x", 0.0)), 0.0, 1.0),
			"y": clampf(float(raw_landmark.get("y", 0.0)), 0.0, 1.0),
			"z": float(raw_landmark.get("z", 0.0)),
		})
	return {
		"handedness": str(raw_hand.get("handedness", "Unknown")),
		"score": clampf(float(raw_hand.get("score", 0.0)), 0.0, 1.0),
		"landmarks": landmarks,
	}


func _launch_sidecar() -> void:
	var script_path := ProjectSettings.globalize_path(SIDECAR_SCRIPT_PATH)
	var model_path := ProjectSettings.globalize_path(SIDECAR_MODEL_PATH)
	if not FileAccess.file_exists(script_path):
		_set_status("缺少手部追踪程序")
		return
	if not FileAccess.file_exists(model_path):
		_set_status("缺少手部追踪模型")
		return
	var python_path := _resolve_python_path()
	if python_path.is_empty():
		_set_status("缺少 MediaPipe 环境")
		return
	var arguments := PackedStringArray([
		script_path,
		"--model", model_path,
		"--host", host,
		"--port", str(port),
		"--camera-source", camera_source,
		"--camera-index", str(camera_index),
		"--host-pid", str(OS.get_process_id()),
	])
	_sidecar_pid = OS.create_process(python_path, arguments, false)
	if _sidecar_pid <= 0:
		_sidecar_pid = -1
		_set_status("无法启动手部追踪程序")


func _resolve_python_path() -> String:
	var override_path := OS.get_environment("BABEL_HAND_TRACKER_PYTHON")
	if not override_path.is_empty() and FileAccess.file_exists(override_path):
		return override_path
	var local_python := ProjectSettings.globalize_path(SIDECAR_PYTHON_PATH)
	if FileAccess.file_exists(local_python):
		return local_python
	for candidate in ["/opt/homebrew/bin/python3", "/usr/local/bin/python3", "/usr/bin/python3"]:
		if FileAccess.file_exists(candidate):
			return candidate
	return ""


func _mark_source_ready(source: String, selected_index: int) -> void:
	if _ready_source == source and _ready_index == selected_index:
		return
	_ready_source = source
	_ready_index = selected_index
	source_ready.emit(_ready_source, _ready_index)


func _clear_ready_source() -> void:
	_ready_source = ""
	_ready_index = -1


func _set_status(value: String) -> void:
	if _status == value:
		return
	_status = value
	status_changed.emit(_status)
