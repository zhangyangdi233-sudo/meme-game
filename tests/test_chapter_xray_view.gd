extends SceneTree

const VIEW_PATH := "res://scripts/world/chapter_xray_view.gd"
const MARKER_LAYER := 1 << 19
const State := preload("res://scripts/meme_game_state.gd")

class FakeReceiver:
	extends RefCounted
	signal frame_received(hands: Array, timestamp_msec: int)
	signal status_changed(status: String)
	signal source_ready(source: String, selected_index: int)
	var camera_source := "computer"
	var start_count := 0
	var stop_count := 0
	func start(_launch_sidecar: bool = true) -> bool:
		start_count += 1
		return true
	func stop() -> void:
		stop_count += 1
	func poll() -> void:
		pass
	func get_status() -> String:
		return "等待手部进入画面"

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(FileAccess.file_exists(VIEW_PATH), "chapter X-ray must provide a live world viewport component")
	if FileAccess.file_exists(VIEW_PATH):
		await _test_shared_world_camera_sync()
	await _test_actual_ui_drives_chapter_window()
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("chapter X-ray view tests passed (%d checks; fake receiver, no physical camera activated)" % _checks)
	quit(0 if _failures.is_empty() else 1)


func _test_shared_world_camera_sync() -> void:
	var script := load(VIEW_PATH) as Script
	_check(script != null and script.can_instantiate(), "X-ray component compiles")
	if script == null or not script.can_instantiate():
		return
	var source := Camera3D.new()
	root.add_child(source)
	source.cull_mask = 5
	source.position = Vector3(2, 3, -4)
	source.rotation_degrees = Vector3(-12, 31, 0)
	source.fov = 71.0
	source.near = 0.17
	source.far = 340.0
	source.h_offset = 0.13
	source.v_offset = -0.08
	var view: Node = script.new()
	root.add_child(view)
	view.bind_camera(source)
	view.update_view(false, Vector2i(1280, 720))
	var viewport := view.get_node("XRayViewport") as SubViewport
	var camera := viewport.get_node("XRayCamera") as Camera3D
	_check(viewport.world_3d == source.get_world_3d() and not viewport.own_world_3d, "X-ray viewport shares the live gameplay World3D without copying geometry")
	_check(viewport.size == Vector2i(1280, 720), "X-ray viewport matches gameplay dimensions")
	_check(not view.is_rendering() and viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "bound viewport starts disabled until the real hand window is active")
	_check(camera.cull_mask == (5 | MARKER_LAYER), "X-ray camera includes normal geometry plus marker layer")
	_check(source.cull_mask == 5, "X-ray camera never adds the marker layer to the normal camera")
	_check(camera.global_transform.is_equal_approx(source.global_transform), "X-ray camera matches source transform")
	_check(is_equal_approx(camera.fov, source.fov) and is_equal_approx(camera.near, source.near) and is_equal_approx(camera.far, source.far), "X-ray perspective and clipping planes match the source")
	_check(is_equal_approx(camera.h_offset, source.h_offset) and is_equal_approx(camera.v_offset, source.v_offset), "camera lens offsets stay aligned with the hand window")
	_check(view.get_texture() == viewport.get_texture(), "overlay receives the live viewport texture")
	view.update_view(true, Vector2i(1600, 900))
	_check(view.is_rendering() and viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "active window explicitly enables its render target")
	source.projection = Camera3D.PROJECTION_ORTHOGONAL
	source.size = 6.2
	source.keep_aspect = Camera3D.KEEP_WIDTH
	source.frustum_offset = Vector2(0.3, -0.1)
	view.update_view(true, Vector2i(900, 1200))
	_check(camera.projection == source.projection and is_equal_approx(camera.size, source.size) and camera.keep_aspect == source.keep_aspect and camera.frustum_offset == source.frustum_offset, "projection, aspect, size, and frustum settings synchronize on change")
	_check(viewport.size == Vector2i(900, 1200), "resizing keeps live X-ray sampling aligned")
	source.free()
	view.update_view(true, Vector2i(900, 1200))
	_check(not view.is_rendering(), "loss of source camera disables rendering instead of leaving a stale live view")
	view.free()


func _test_actual_ui_drives_chapter_window() -> void:
	var main = load("res://scenes/babel_meme_game.tscn").instantiate()
	var receiver := FakeReceiver.new()
	main._hand_tracking_receiver = receiver
	receiver.frame_received.connect(main._on_hand_tracking_frame)
	receiver.status_changed.connect(main._on_hand_tracking_status_changed)
	receiver.source_ready.connect(main._on_camera_source_ready)
	main._save_path = "user://test_chapter_xray.dat"
	root.add_child(main)
	main._resolve_camera_consent(false)
	main._begin_game_session(_basement_state(), {}, false)
	main._set_reality_mouse_look(false)
	await process_frame
	_check((main._camera.cull_mask & MARKER_LAYER) == 0, "actual naked-eye camera permanently excludes all X-ray-only markers")
	var view: Node = main.get_node_or_null("ChapterXRayView")
	_check(view != null, "actual basement session binds a live X-ray viewport to its existing hand overlay")
	if view == null:
		main.free()
		return
	var overlay: Control = main._hand_xray_overlay
	var viewport := view.get_node("XRayViewport") as SubViewport
	var xray_camera := viewport.get_node("XRayCamera") as Camera3D
	var authored_marks: Array[Node] = main._reality_floor.find_children("XRAY_EXIT_GUIDE_*_Paint", "MeshInstance3D", true, false)
	_check(authored_marks.size() == 3, "current imported basement provides exactly three authored arrow paint meshes")
	var preview: Node = main._reality_floor.get_node_or_null("NextBasementThroughDoor")
	_check(preview != null, "ordinary door has a destination preview")
	if preview != null:
		_check(preview.find_children("XRAY_EXIT_GUIDE_*_Paint", "MeshInstance3D", true, false).is_empty(), "next-room preview cannot duplicate current room's authored X-ray arrows")
		var preview_marker_count := 0
		for geometry: GeometryInstance3D in preview.find_children("*", "GeometryInstance3D", true, false):
			if (geometry.layers & MARKER_LAYER) != 0:
				preview_marker_count += 1
		_check(preview_marker_count == 0, "preview geometry cannot render future clues through the current X-ray camera")
	for mark: MeshInstance3D in authored_marks:
		_check(mark.layers == MARKER_LAYER and (mark.layers & main._camera.cull_mask) == 0 and (mark.layers & xray_camera.cull_mask) != 0, "%s is excluded by the actual normal camera and included only by the actual X-ray camera" % mark.name)
	_check(not view.is_rendering(), "loading a basement starts with hidden X-ray markers")
	_check(overlay.get("_layer_texture") == view.get_texture(), "chapter uses live world texture rather than the legacy phone screenshot")
	var computer := main.find_child("SettingsOpenComputerCameraButton", true, false) as Button
	var phone := main.find_child("SettingsConnectPhoneCameraButton", true, false) as Button
	var toggle := main.find_child("SettingsCameraAccessToggle", true, false) as CheckButton
	_check(computer != null and phone != null and toggle != null, "real settings surfaces expose camera activation and shutdown")
	main._toggle_settings_window()
	computer.pressed.emit()
	_check(receiver.start_count == 1 and main._camera_enabled, "actual computer camera button reaches receiver startup")
	receiver.frame_received.emit(_hands(), Time.get_ticks_msec())
	_check(not view.is_rendering(), "settings keep X-ray hidden even after a valid hand packet")
	main._close_settings_window()
	receiver.frame_received.emit([], Time.get_ticks_msec())
	_check(not view.is_rendering(), "ordinary camera with no two-hand gesture must not reveal arrows")
	receiver.frame_received.emit(_hands(), Time.get_ticks_msec())
	_check(overlay.is_frame_active() and overlay.visible and view.is_rendering(), "real handler activates the live world view only inside the existing fingertip window")
	_check(viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "active hand frame renders the second view")
	_check((main._camera.cull_mask & MARKER_LAYER) == 0, "activating X-ray never exposes markers in the naked-eye camera")
	overlay.expire_tracking_for_test()
	await process_frame
	await process_frame
	_check(not view.is_rendering() and not overlay.is_frame_active(), "420 ms tracking expiry disables X-ray without waiting for another packet")
	receiver.frame_received.emit(_hands(), Time.get_ticks_msec())
	main.set_view_state("phone_down")
	_check(not view.is_rendering() and not overlay.visible, "opening normal phone UI immediately hides and disables X-ray")
	main.set_view_state("npc_up")
	receiver.frame_received.emit(_hands(), Time.get_ticks_msec())
	_check(overlay.get("_layer_texture") == view.get_texture() and view.is_rendering(), "returning to basement restores live X-ray even after legacy screenshot capture path")
	main._input_locked = true
	await process_frame
	_check(not view.is_rendering() and not overlay.visible, "chapter transition lock prevents stale arrows showing during a cutscene")
	main._input_locked = false
	receiver.frame_received.emit(_hands(), Time.get_ticks_msec())
	phone.pressed.emit()
	_check(receiver.camera_source == "phone" and receiver.start_count == 2, "actual phone-source button uses the same camera bridge")
	_check(not view.is_rendering(), "changing camera source drops the previous source's hand window")
	main._hide_phone_camera_connection_overlay()
	receiver.source_ready.emit("phone", 2)
	receiver.frame_received.emit(_hands(), Time.get_ticks_msec())
	_check(view.is_rendering(), "phone fallback's actual frame handler can activate the same X-ray path")
	receiver.status_changed.emit("摄像头不可用或权限被拒绝")
	_check(not view.is_rendering(), "camera failure immediately clears its previous active X-ray window")
	receiver.frame_received.emit(_hands(), Time.get_ticks_msec())
	toggle.toggled.emit(false)
	_check(not main._camera_enabled and not view.is_rendering() and not overlay.is_frame_active(), "actual camera permission toggle shuts off the hand window and rendering")
	computer.pressed.emit()
	receiver.frame_received.emit(_hands(), Time.get_ticks_msec())
	_check(view.is_rendering(), "re-enabled camera requires and accepts a fresh gesture")
	var old_view_id: int = view.get_instance_id()
	var saved: Dictionary = main.game.to_save_data()
	var restored := State.new()
	restored.load_save_data(saved)
	main._begin_game_session(restored, {}, false)
	main._set_reality_mouse_look(false)
	await process_frame
	view = main.get_node_or_null("ChapterXRayView")
	_check(not is_instance_id_valid(old_view_id) and view != null and not view.is_rendering(), "reloading frees the old view and cannot restore an active frame from saved progress")
	_check((main._camera.cull_mask & MARKER_LAYER) == 0, "rebuilt primary camera still excludes X-ray markers")
	receiver.frame_received.emit(_hands(), Time.get_ticks_msec())
	_check(view.is_rendering(), "restored basement can activate only through fresh live frame handling")
	main.game.chapter1_progress.phase = "crossroads"
	main._render()
	_check(main.get_node_or_null("ChapterXRayView") == null, "leaving basement releases its second render view")
	_check(not main._hand_xray_overlay.is_frame_active(), "leaving basement clears the old hand frame before legacy texture restoration")
	main.free()
	await process_frame


func _basement_state() -> MemeGameState:
	var state := State.new()
	state.new_run()
	state.start_chapter1()
	state.notify_chapter1("opening_knock_completed", {"sequence_id": "chapter1_opening"})
	state.notify_chapter1("opening_door_opened")
	state.view_state = "npc_up"
	state.active_app_window = ""
	return state


func _hands() -> Array:
	return [_hand(Vector2(0.22, 0.70), Vector2(0.25, 0.25)), _hand(Vector2(0.78, 0.70), Vector2(0.75, 0.25))]


func _hand(thumb: Vector2, finger: Vector2) -> Dictionary:
	var points: Array = []
	for index in 21:
		points.append({"x": 0.5, "y": 0.5, "z": 0.0})
	points[4] = {"x": thumb.x, "y": thumb.y, "z": 0.0}
	points[8] = {"x": finger.x, "y": finger.y, "z": 0.0}
	return {"landmarks": points}


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
