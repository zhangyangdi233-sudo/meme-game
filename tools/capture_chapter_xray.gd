extends SceneTree
## Render the real settings-button/hand-handler path without opening camera hardware.

const OUTPUT := "D:/aphasia/outputs/basement_integration_audit"
const State := preload("res://scripts/meme_game_state.gd")
const XRAY_LAYER := 1 << 19

class CaptureReceiver:
	extends RefCounted
	var camera_source := "computer"
	func start(_launch_sidecar: bool = true) -> bool:
		return true
	func stop() -> void:
		pass
	func poll() -> void:
		pass
	func get_status() -> String:
		return "等待手部进入画面"

var viewport: SubViewport
var main
var captures: Array = []
var feed_hands := false


func _init() -> void:
	root.visible = false
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("X-ray capture requires a real renderer")
		quit(2)
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	main = load("res://scenes/babel_meme_game.tscn").instantiate()
	main._hand_tracking_receiver = CaptureReceiver.new()
	main._save_path = OUTPUT.path_join("capture_xray_save.dat")
	viewport.add_child(main)
	main._resolve_camera_consent(false)
	main._locale.set_locale("zh")
	main._vhs_enabled = false
	var state := State.new()
	state.new_run()
	state.start_chapter1()
	state.view_state = "npc_up"
	state.active_app_window = ""
	state.notify_chapter1("opening_knock_completed", {"sequence_id": "chapter1_opening"})
	state.notify_chapter1("opening_door_opened", {})
	main._begin_game_session(state, {}, false)
	main._set_reality_mouse_look(false)
	if not main._chapter_world_ready:
		push_error("Chapter X-ray scene failed to bind")
		quit(1)
		return
	var marker: Node3D = main._reality_floor.find_child("XRAY_EXIT_GUIDE_02*", true, false)
	if marker == null:
		push_error("Authored XRAY_EXIT_GUIDE_02 missing")
		quit(1)
		return
	var meshes := _marked_meshes(marker)
	if meshes.is_empty():
		push_error("Authored X-ray marker has no geometry")
		quit(1)
		return
	var mesh: MeshInstance3D = meshes[0]
	var center := mesh.to_global(mesh.get_aabb().get_center())
	var inward := Vector3(-center.x, 0, -center.z).normalized()
	var feet := center + inward * 2.2
	feet.y = 0.03
	main._reality_player.position = feet
	main._reality_player.velocity = Vector3.ZERO
	var direction := (center - feet - Vector3(0, 1.56, 0)).normalized()
	main._reality_yaw = rad_to_deg(atan2(-direction.x, -direction.z))
	main._reality_pitch = rad_to_deg(asin(direction.y))
	# Freeze the same settled first-person camera for pixel comparisons; actual
	# camera UI and hand handlers remain live and explicitly synchronize the view.
	main._animate_world(1.0)
	main.set_process(false)
	main.set_physics_process(false)
	var normal := await _capture("chapter1_xray_01_normal.png")
	var marker_rect := _projected_bounds(mesh).grow(4.0)
	main._toggle_settings_window()
	var camera_button := main.find_child("SettingsOpenComputerCameraButton", true, false) as Button
	if camera_button == null:
		push_error("Actual settings camera button is missing")
		quit(1)
		return
	camera_button.pressed.emit()
	main._toggle_settings_window()
	main._set_reality_mouse_look(false)
	feed_hands = true
	var active := await _capture("chapter1_xray_02_active.png")
	var active_window: bool = main._hand_xray_overlay.is_frame_active()
	var frame: Rect2 = main._hand_xray_overlay.get_frame_rect_normalized()
	feed_hands = false
	main._toggle_settings_window()
	main._camera_access_toggle.toggled.emit(false)
	main._toggle_settings_window()
	main._set_reality_mouse_look(false)
	var disabled := await _capture("chapter1_xray_03_disabled.png")
	var marker_data: Array = []
	var seen: Dictionary = {}
	for guide in main._reality_floor.find_children("XRAY_EXIT_GUIDE_*", "Node3D", true, false):
		for geometry in _marked_meshes(guide):
			if seen.has(geometry.get_instance_id()):
				continue
			seen[geometry.get_instance_id()] = true
			marker_data.append({"name": geometry.name, "layers": geometry.layers, "casts_shadow": geometry.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF})
	var difference := _outside_difference(normal, active, frame)
	var normal_red := _red_pixels(normal, marker_rect)
	var active_red := _red_pixels(active, marker_rect)
	var disabled_red := _red_pixels(disabled, marker_rect)
	var failures: Array[String] = []
	for capture in captures:
		if capture.error != OK:
			failures.append("Screenshot save failed: %s" % capture.file)
	if not active_window or main._hand_xray_overlay.is_frame_active():
		failures.append("Actual camera controls did not activate/deactivate X-ray")
	if marker_data.size() != 3:
		failures.append("Expected exactly three authored paint meshes")
	for geometry in marker_data:
		if geometry.layers != XRAY_LAYER or geometry.casts_shadow:
			failures.append("An authored mark is not isolated from ordinary rendering")
	if (main._camera.cull_mask & XRAY_LAYER) != 0:
		failures.append("Ordinary camera includes the hidden mark layer")
	if active_red < 100 or normal_red > active_red / 10 or disabled_red > active_red / 10:
		failures.append("Red arrow pixels must appear only in active X-ray, not normal/disabled views")
	if difference.changed_samples_above_3pct > 10:
		failures.append("X-ray changed ordinary pixels beyond the existing frame border")
	var file := FileAccess.open(OUTPUT.path_join("chapter1_xray_capture_results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"renderer": RenderingServer.get_video_adapter_name(),
		"captures": captures,
		"marker": marker.name,
		"marker_center": str(center),
		"camera_feet": str(feet),
		"main_camera_excludes_marks": (main._camera.cull_mask & XRAY_LAYER) == 0,
		"active_window": active_window,
		"disabled_window": not main._hand_xray_overlay.is_frame_active(),
		"frame_normalized": str(frame),
		"outside_window_diff": difference,
		"arrow_pixel_check": {"region": str(marker_rect), "normal_red_pixels": normal_red, "active_red_pixels": active_red, "disabled_red_pixels": disabled_red},
		"marker_meshes": marker_data,
		"failures": failures,
		"scope": "Actual settings controls and hand-frame handler with synthetic landmarks/fake hardware receiver; no physical camera test.",
	}, "\t"))
	file.close()
	main.queue_free()
	await process_frame
	viewport.queue_free()
	await process_frame
	if failures.is_empty():
		print("chapter X-ray render captures passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _marked_meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_marked_meshes(child))
	return found


func _capture(filename: String) -> Image:
	for frame in 18:
		if feed_hands:
			main._on_hand_tracking_frame(_hands(), Time.get_ticks_msec())
		main._sync_chapter_xray_view()
		await process_frame
		RenderingServer.force_draw()
	var picture := viewport.get_texture().get_image()
	var error := picture.save_png(OUTPUT.path_join(filename))
	captures.append({"file": filename, "error": error})
	print("XRAY_CAPTURE: ", filename, " error=", error)
	return picture


func _hands() -> Array:
	var result: Array = []
	for side in [0.19, 0.81]:
		var landmarks: Array = []
		for index in 21:
			landmarks.append({"x": side, "y": 0.5, "z": 0.0})
		landmarks[4].y = 0.80
		landmarks[8].y = 0.20
		result.append({"landmarks": landmarks, "score": 0.99})
	return result


func _projected_bounds(mesh: MeshInstance3D) -> Rect2:
	var bounds := mesh.get_aabb()
	var region := Rect2(main._camera.unproject_position(mesh.to_global(bounds.get_endpoint(0))), Vector2.ZERO)
	for corner in range(1, 8):
		region = region.expand(main._camera.unproject_position(mesh.to_global(bounds.get_endpoint(corner))))
	return region


func _red_pixels(picture: Image, region: Rect2) -> int:
	var count := 0
	var bounds := region.intersection(Rect2(Vector2.ZERO, Vector2(picture.get_size())))
	for y in range(int(bounds.position.y), int(bounds.end.y)):
		for x in range(int(bounds.position.x), int(bounds.end.x)):
			var color := picture.get_pixel(x, y)
			if color.r > 0.18 and color.r > color.g * 1.8 and color.r > color.b * 1.8:
				count += 1
	return count


func _outside_difference(a: Image, b: Image, normalized: Rect2) -> Dictionary:
	# Border interference extends beyond the gesture frame; exclude its 42 px band.
	var frame := Rect2(normalized.position * Vector2(a.get_size()), normalized.size * Vector2(a.get_size())).grow(42.0)
	var changed := 0
	var sampled := 0
	for y in range(0, a.get_height(), 3):
		for x in range(0, a.get_width(), 3):
			if frame.has_point(Vector2(x, y)):
				continue
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			sampled += 1
			if maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b))) > 0.03:
				changed += 1
	return {"changed_samples_above_3pct": changed, "total_samples": sampled, "border_exclusion_px": 42}
