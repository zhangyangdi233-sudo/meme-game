extends SceneTree

const OverlayScript = preload("res://framework/ui/hand_xray_overlay.gd")
const ReceiverScript = preload("res://framework/integrations/hand_tracking_receiver.gd")

class FakeHandTrackingReceiver:
	extends RefCounted

	var camera_source := "computer"
	var start_count := 0
	var stop_count := 0
	var _status := "摄像头未启用"

	func start(_launch_sidecar: bool = true) -> bool:
		start_count += 1
		_status = "等待手部进入画面"
		return true

	func stop() -> void:
		stop_count += 1
		_status = "摄像头未启用"

	func poll() -> void:
		pass

	func get_status() -> String:
		return _status


var _failures: Array[String] = []
var _received_hands: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_receiver_protocol()
	await _test_udp_bridge()
	await _test_xray_frame()
	if "--core-only" not in OS.get_cmdline_user_args():
		await _test_main_scene_surfaces()
	if _failures.is_empty():
		print("hand xray tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_receiver_protocol() -> void:
	var receiver = ReceiverScript.new()
	receiver.frame_received.connect(_capture_received_hands)
	var packet := {
		"schema_version": 1,
		"timestamp_ms": 1234,
		"mirrored": true,
		"camera_source": "phone",
		"selected_index": 2,
		"hands": _make_two_hands(),
	}
	_assert_true(receiver.ingest_packet(packet), "receiver should accept the versioned two-hand packet")
	_assert_eq(_received_hands.size(), 2, "receiver should emit two sanitized hands")
	_assert_eq(receiver.get_status(), "已收到手部关键点", "receiver should expose a gesture-neutral landmark state")
	_assert_eq(receiver.get_ready_source(), "phone", "receiver should report which requested camera source produced real frames")
	_assert_eq(receiver.get_ready_index(), 2, "receiver should report the concrete system camera index")
	_assert_true(receiver.ingest_packet({
		"schema_version": 1,
		"timestamp_ms": 1235,
		"status_code": "camera_open_failed",
		"hands": [],
	}), "receiver should accept a sidecar status packet")
	_assert_eq(receiver.get_status(), "摄像头不可用或权限被拒绝", "receiver should surface camera permission failure")
	_assert_eq(receiver.get_ready_source(), "", "a camera error should clear the previously ready source")
	_assert_true(not receiver.ingest_packet({"schema_version": 99, "hands": []}), "receiver should reject an unknown schema version")


func _test_udp_bridge() -> void:
	_received_hands.clear()
	var receiver = ReceiverScript.new()
	receiver.port = 17841
	receiver.frame_received.connect(_capture_received_hands)
	_assert_true(receiver.start(false), "receiver should bind its local UDP port without launching a camera process")
	var sender := PacketPeerUDP.new()
	sender.set_dest_address("127.0.0.1", receiver.port)
	var packet := {
		"schema_version": 1,
		"timestamp_ms": 2345,
		"mirrored": true,
		"hands": _make_two_hands(),
	}
	sender.put_packet(JSON.stringify(packet).to_utf8_buffer())
	for _frame in 4:
		await process_frame
		receiver.poll()
	_assert_eq(_received_hands.size(), 2, "Godot should receive the two-hand packet over the real localhost UDP bridge")
	receiver.stop()


func _test_xray_frame() -> void:
	var overlay = OverlayScript.new()
	overlay.name = "TestHandXRayOverlay"
	overlay.size = Vector2(1600, 900)
	root.add_child(overlay)
	var image := Image.create(1600, 900, false, Image.FORMAT_RGBA8)
	image.fill(Color("254625"))
	overlay.set_layer_texture(ImageTexture.create_from_image(image))
	overlay.set_tracking_enabled(true)
	_assert_true(overlay.ingest_hands(_make_two_hands()), "four fingertips from two hands should activate the X-ray frame")
	var frame: Rect2 = overlay.get_frame_rect_normalized()
	_assert_vector_close(frame.position, Vector2(0.22, 0.25), 0.001, "frame should start at the outermost fingertip")
	_assert_vector_close(frame.size, Vector2(0.56, 0.45), 0.001, "frame should span all four fingertips")
	_assert_true(overlay.is_frame_active(), "X-ray should be active when tracking and layer texture are both available")
	_assert_eq(overlay.get_frame_shape(), "rectangle", "two hands should retain the rectangular X-ray gesture")
	_assert_true(not overlay.ingest_hands([_make_hand("Right", Vector2(0.30, 0.70), Vector2(0.72, 0.24))]), "one hand must never activate the four-fingertip X-ray")
	_assert_true(not overlay.is_frame_active(), "losing either hand should close the X-ray instead of falling back to a three-finger shape")
	_assert_true(overlay.ingest_hands(_make_two_hands()), "the rectangular X-ray should reacquire once both hands return")
	_assert_eq(str(overlay.get_meta("frame_shape", "")), "rectangle", "runtime metadata should expose only the rectangular active shape")
	overlay.force_signal_glitch_for_test()
	_assert_true(bool(overlay.get_meta("signal_burst_active", false)), "the border effect should expose a deterministic test hook for its signal-interference burst")
	_assert_true(float(overlay.get_meta("signal_burst_strength", 0.0)) > 0.0, "forced signal interference should produce a nonzero, bounded distortion strength")
	overlay.expire_tracking_for_test()
	_assert_true(not overlay.is_frame_active(), "X-ray should close when tracking becomes stale")
	overlay.queue_free()
	await process_frame


func _test_main_scene_surfaces() -> void:
	var packed := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(packed != null, "main game scene should load")
	if packed == null:
		return
	var game_root = packed.instantiate()
	root.add_child(game_root)
	await process_frame
	_assert_true(game_root.get_script() != null, "main game script should compile before camera-source UI tests run")
	if game_root.get_script() == null:
		game_root.queue_free()
		await process_frame
		return
	game_root._build_camera_consent_overlay()
	await process_frame
	_assert_true(_find_node_by_name(game_root, "CameraConsentAllowButton") is Button, "pre-game screen should offer an explicit allow action")
	_assert_true(_find_node_by_name(game_root, "CameraConsentSkipButton") is Button, "pre-game screen should offer a no-camera path")
	var consent_source := _find_node_by_name(game_root, "CameraConsentSourceOption") as OptionButton
	_assert_true(consent_source != null and consent_source.item_count == 2, "pre-game screen should make computer-primary and phone-fallback sources explicit")
	game_root._resolve_camera_consent(false)
	game_root.new_game()
	await process_frame
	_assert_true(_find_node_by_name(game_root, "SettingsCameraAccessToggle") is CheckButton, "settings should expose camera access control")
	_assert_true(_find_node_by_name(game_root, "SettingsCameraStatus") is Label, "settings should report tracking status")
	var computer_button := _find_node_by_name(game_root, "SettingsOpenComputerCameraButton") as Button
	var phone_button := _find_node_by_name(game_root, "SettingsConnectPhoneCameraButton") as Button
	_assert_true(computer_button != null, "settings should expose one direct button for the computer camera X-ray path")
	_assert_true(phone_button != null, "settings should expose a second direct button for the phone fallback X-ray path")
	_assert_true(computer_button != null and phone_button != null and computer_button.button_group == phone_button.button_group, "camera source buttons should share one exclusive selection group")
	if game_root._hand_tracking_receiver != null:
		game_root._hand_tracking_receiver.stop()
	var fake_receiver := FakeHandTrackingReceiver.new()
	game_root._hand_tracking_receiver = fake_receiver
	if computer_button != null:
		computer_button.pressed.emit()
	_assert_eq(game_root._camera_source, "computer", "clicking the computer button should select the computer source")
	_assert_eq(fake_receiver.camera_source, "computer", "clicking the computer button should start the computer camera path")
	_assert_true(computer_button != null and computer_button.button_pressed, "clicking the computer button should turn that button green")
	_assert_true(phone_button != null and not phone_button.button_pressed, "computer selection should unpress the phone button")
	if phone_button != null:
		phone_button.pressed.emit()
	_assert_eq(game_root._camera_source, "phone", "clicking the phone button should select the phone source")
	_assert_eq(fake_receiver.camera_source, "phone", "clicking the phone button should start the phone camera path")
	_assert_true(phone_button != null and phone_button.button_pressed, "clicking the phone button should turn that button green")
	_assert_true(computer_button != null and not computer_button.button_pressed, "phone selection should unpress the computer button")
	var phone_overlay := _find_node_by_name(game_root, "PhoneCameraConnectionOverlay") as Control
	_assert_true(phone_overlay != null and phone_overlay.visible, "clicking the phone button should always open a connection-status window")
	_assert_eq(str(phone_overlay.get_meta("connection_state", "")), "searching", "the phone window should distinguish scanning from a real video connection")
	game_root._on_hand_tracking_status_changed("摄像头不可用或权限被拒绝")
	_assert_eq(str(phone_overlay.get_meta("connection_state", "")), "error", "a real camera failure should remain visible in the phone connection window")
	game_root._on_camera_source_ready("phone", 3)
	_assert_eq(str(phone_overlay.get_meta("connection_state", "")), "ready", "the phone window should change to ready only after real frames arrive")
	_assert_eq(int(phone_overlay.get_meta("selected_index", -1)), 3, "the phone window should expose the system camera index that produced frames")
	if computer_button != null:
		computer_button.pressed.emit()
	_assert_true(phone_overlay != null and not phone_overlay.visible, "switching back to the computer camera should close the phone connection window")
	var xray := _find_node_by_name(game_root, "HandXRayOverlay")
	_assert_true(xray != null, "the actual game UI should include the hand-driven X-ray layer")
	if xray != null:
		_assert_true(xray.get_meta("xray_mode", "") == "two_hand_thumb_index_bbox", "X-ray should support only the four-fingertip, two-hand rectangle gesture")
		_assert_true(xray.get_meta("rectangle_gesture", "") == "two_hand_thumb_index_bbox", "the four-fingertip gesture should have an explicit, testable activation contract")
		_assert_true(xray.get_meta("border_effect", "") == "signal_contamination_v2", "X-ray should use the more legible signal-contamination border")
		_assert_true(xray.get_meta("effect_scope", "") == "xray_window_only", "the horror effect should stay local to the X-ray window instead of degrading the whole screen")
		var effect_components: Array = xray.get_meta("effect_components", [])
		_assert_true(effect_components.has("acid_chromatic_split") and effect_components.has("broken_edge_packets"), "the border should visibly combine chromatic splitting with broken signal packets")
		_assert_true(float(xray.get_meta("max_tear_offset_px", 0.0)) >= 18.0, "the horizontal desync should be strong enough to read during play")
	game_root.queue_free()
	await process_frame


func _make_two_hands() -> Array:
	return [
		_make_hand("Left", Vector2(0.22, 0.70), Vector2(0.25, 0.25)),
		_make_hand("Right", Vector2(0.78, 0.70), Vector2(0.75, 0.25)),
	]


func _make_hand(handedness: String, thumb: Vector2, index_tip: Vector2) -> Dictionary:
	var landmarks: Array = []
	for _landmark_index in 21:
		landmarks.append({"x": 0.5, "y": 0.5, "z": 0.0})
	landmarks[4] = {"x": thumb.x, "y": thumb.y, "z": 0.0}
	landmarks[8] = {"x": index_tip.x, "y": index_tip.y, "z": 0.0}
	return {"handedness": handedness, "score": 0.99, "landmarks": landmarks}


func _capture_received_hands(hands: Array, _timestamp_msec: int) -> void:
	_received_hands = hands


func _find_node_by_name(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found := _find_node_by_name(child, target_name)
		if found != null:
			return found
	return null


func _assert_vector_close(actual: Vector2, expected: Vector2, tolerance: float, message: String) -> void:
	_assert_true(actual.distance_to(expected) <= tolerance, "%s (expected %s, got %s)" % [message, expected, actual])


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
