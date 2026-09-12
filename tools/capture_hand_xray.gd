extends SceneTree

const HandTrackingStatusScript = preload("res://framework/integrations/hand_tracking_status.gd")

const PROJECT_DIR := "/Users/zhang/Documents/游戏/babel-meme-game"
const CONSENT_OUTPUT := PROJECT_DIR + "/tools/current_camera_consent.png"
const XRAY_OUTPUT := PROJECT_DIR + "/tools/current_hand_xray.png"
const SETTINGS_OUTPUT := PROJECT_DIR + "/tools/current_camera_settings.png"
const PHONE_SETTINGS_OUTPUT := PROJECT_DIR + "/tools/current_camera_settings_phone.png"
const PHONE_SEARCHING_OUTPUT := PROJECT_DIR + "/tools/current_phone_camera_connection_searching.png"
const PHONE_ERROR_OUTPUT := PROJECT_DIR + "/tools/current_phone_camera_connection_error.png"
const PHONE_READY_OUTPUT := PROJECT_DIR + "/tools/current_phone_camera_connection_ready.png"
const VIEW_SIZE := Vector2i(1600, 900)
const HEADLESS_CAPTURE_ERROR := "Screenshot capture requires a rendered display. Run this tool without --headless from a GUI session."


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = VIEW_SIZE
	if not _ensure_capture_supported():
		return
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	if scene == null:
		push_error("Unable to load main scene")
		quit(1)
		return
	var main = scene.instantiate()
	root.add_child(main)
	await _wait_frames(6)
	main._build_camera_consent_overlay()
	await _wait_frames(3)
	if not _save_viewport(CONSENT_OUTPUT):
		return

	main._resolve_camera_consent(false)
	main.new_game()
	main._skip_prologue()
	await _wait_frames(12)
	main.set_view_state("npc_up")
	await _wait_frames(50)
	main._set_camera_enabled(true, false)
	main._hand_xray_overlay.set_tracking_enabled(true)
	main._on_hand_tracking_frame(_make_two_hands(), Time.get_ticks_msec())
	main._update_visibility()
	await _wait_frames(3)
	main._hand_xray_overlay.force_signal_glitch_for_test()
	await _wait_frames(1)
	if not _save_viewport(XRAY_OUTPUT):
		return

	main._toggle_settings_window()
	await _wait_frames(4)
	main._camera_session.source = "computer"
	main._camera_access_toggle.set_pressed_no_signal(true)
	main._refresh_camera_source_buttons()
	await _wait_frames(2)
	if not _save_viewport(SETTINGS_OUTPUT):
		return
	main._camera_session.source = "phone"
	if main._camera_session != null:
		main._camera_session.tracking_status = HandTrackingStatusScript.Status.WAITING_FOR_DATA
		main._camera_session.ready_source = ""
		main._camera_session.ready_index = -1
	main._refresh_camera_source_buttons()
	main._refresh_camera_status_ui()
	await _wait_frames(2)
	if not _save_viewport(PHONE_SETTINGS_OUTPUT):
		return
	main._show_phone_camera_connection_overlay()
	await _wait_frames(6)
	if not _save_viewport(PHONE_SEARCHING_OUTPUT):
		return
	main._on_hand_tracking_status_changed(HandTrackingStatusScript.Status.PERMISSION_DENIED)
	await _wait_frames(20)
	if not _save_viewport(PHONE_ERROR_OUTPUT):
		return
	main._on_camera_source_ready("phone", 2)
	await _wait_frames(8)
	if not _save_viewport(PHONE_READY_OUTPUT):
		return
	print("saved hand X-ray and camera-source evidence")
	main.queue_free()
	await _wait_frames(3)
	quit(0)


func _make_two_hands() -> Array:
	return [
		_make_hand("Left", Vector2(0.21, 0.68), Vector2(0.27, 0.27)),
		_make_hand("Right", Vector2(0.79, 0.68), Vector2(0.73, 0.27)),
	]


func _make_hand(handedness: String, thumb: Vector2, index_tip: Vector2) -> Dictionary:
	var landmarks: Array = []
	for _index in 21:
		landmarks.append({"x": 0.5, "y": 0.5, "z": 0.0})
	landmarks[4] = {"x": thumb.x, "y": thumb.y, "z": 0.0}
	landmarks[8] = {"x": index_tip.x, "y": index_tip.y, "z": 0.0}
	return {"handedness": handedness, "score": 0.99, "landmarks": landmarks}


func _wait_frames(count: int) -> void:
	for _frame in count:
		await process_frame


func _save_viewport(path: String) -> bool:
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("Unable to read root viewport texture")
		quit(1)
		return false
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		push_error("Unable to read root viewport image")
		quit(1)
		return false
	var error := image.save_png(path)
	if error != OK:
		push_error("Unable to save screenshot: %s" % error)
		quit(1)
		return false
	return true


func _ensure_capture_supported() -> bool:
	var display_name := DisplayServer.get_name().to_lower()
	if display_name == "headless":
		push_error(HEADLESS_CAPTURE_ERROR)
		quit(2)
		return false
	return true
