extends SceneTree

const Journey = preload("res://scripts/progression/floor_two_journey.gd")
const Evidence = preload("res://scripts/world/floor_two_xray_observation.gd")
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var main = load("res://scenes/babel_meme_game.tscn").instantiate()
	main._save_path = "user://test_floor_two_phone_xray.dat"
	main._locale.preferences_path = "user://test_floor_two_phone_xray.cfg"
	main._locale.save_preferences(80, false, false, "computer")
	root.add_child(main)
	main._resolve_camera_consent(false)
	var state = load("res://scripts/meme_game_state.gd").new()
	state.new_run()
	state.chapter1_progress = {}
	state.tower_floor = 2
	# This spatial-input fixture starts after the dedicated arrival cinematic.
	state.floor_two_progress = Journey.complete_map_intro({})
	for id in Journey.TURN_IDS:
		state.floor_two_progress = Journey.visit_turn(state.floor_two_progress, id)
	main._begin_game_session(state, {}, false)
	await _frames(8)
	main._open_phone_launcher()
	main._on_app_pressed("map")
	await create_timer(0.5).timeout
	_check(main._floor_two_phone_walk_active(), "floor two phone permits locomotion")
	_check(main._cinematic_top_bar.visible and main._cinematic_bottom_bar.visible, "opening the phone preserves both cinematic bars")
	_check(main._phone_panel.z_index > main._cinematic_top_bar.z_index and main._phone_panel.z_index > main._cinematic_bottom_bar.z_index, "phone is drawn in front of the cinematic frame")
	_check(main._cinematic_top_bar.z_index > main._hand_xray_overlay.z_index, "world X-ray cannot erase the cinematic frame")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = Vector2(20, 200)
	main._input(right)
	_check(main._phone_world_look_active and main._reality_mouse_look_enabled, "right button outside phone temporarily captures look")
	var yaw: float = main._reality_yaw
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(24, 0)
	main._input(motion)
	_check(not is_equal_approx(yaw, main._reality_yaw), "phone remains open while captured mouse turns camera")
	main._reality_yaw = yaw
	right.pressed = false
	main._input(right)
	_check(not main._phone_world_look_active and not main._reality_mouse_look_enabled, "right release restores phone interaction immediately")
	right.pressed = true
	right.position = main._phone_panel.get_global_rect().get_center()
	main._input(right)
	_check(not main._phone_world_look_active, "right click on phone never steals app input")
	var before: Vector3 = main._reality_player.position
	Input.action_press("reality_forward")
	await _frames(24)
	Input.action_release("reality_forward")
	_check(main._reality_player.position.distance_to(before) > 0.8, "actual CharacterBody moves with phone map open")
	var edit := LineEdit.new()
	main._ui_root.add_child(edit)
	edit.grab_focus()
	main._reality_player.velocity = Vector3.ZERO
	before = main._reality_player.position
	Input.action_press("reality_forward")
	await _frames(10)
	Input.action_release("reality_forward")
	_check(Vector2(main._reality_player.position.x, main._reality_player.position.z).distance_to(Vector2(before.x, before.z)) < 0.01, "focused text input blocks walking")
	edit.free()
	main._settings_open = true
	main._reality_player.velocity = Vector3.ZERO
	before = main._reality_player.position
	Input.action_press("reality_forward")
	await _frames(10)
	Input.action_release("reality_forward")
	_check(main._reality_player.position.distance_to(before) < 0.02, "settings remain modal with phone open")
	main._settings_open = false
	main.set_process(false)
	main.set_physics_process(false)
	state.set_view_state("npc_up")
	main._render()
	var layout: Dictionary = main._floor_two_lesson_layout
	_check(not main._try_floor_two_exit() and state.tower_floor == 2, "map alone cannot bypass X-ray lesson")
	main._reality_player.position = layout.exit_position
	main._refresh_nearby_reality_actor()
	_check(main._nearby_reality_actor == null, "unseen exit has no ordinary interaction prompt")
	main._camera_enabled = true # Test the existing frame receiver; no hardware starts.
	main._hand_xray_overlay.set_tracking_enabled(true)
	main._sync_chapter_xray_view()
	_check((main._camera.cull_mask & (1 << 19)) == 0, "ordinary camera excludes true exit")
	var xray_camera: Camera3D = main._chapter_xray_view.get_node("XRayViewport/XRayCamera")
	_check((xray_camera.cull_mask & (1 << 18)) == 0 and (xray_camera.cull_mask & (1 << 19)) != 0, "X-ray camera swaps only the differing layer")
	for target: Dictionary in layout.xray_targets:
		var point: Vector3 = target.position
		main._reality_player.position = point + Vector3(0, -1.45, 6)
		main._camera.global_position = point + Vector3(0, 0.2, 6)
		main._camera.look_at(point)
		await physics_frame
		var prior: int = state.floor_two_progress.xray_observed_ids.size()
		main._hand_xray_overlay.ingest_hands([])
		main._update_floor_two_xray_observation()
		_check(state.floor_two_progress.xray_observed_ids.size() == prior, "%s needs a valid two-hand frame" % target.id)
		var small := Rect2(0, 0, 0.1, 0.1)
		_check(Evidence.visible_targets(layout, main._camera, main._reality_player.position, small, main._viewport_size()).is_empty(), "%s outside the finger frame cannot count" % target.id)
		var screen: Vector2 = main._viewport_size()
		_check(Evidence.visible_targets(layout, main._camera, main._reality_player.position, Rect2(0, 0, 1, 1), screen, Rect2(Vector2.ZERO, screen)).is_empty(), "%s behind a UI panel cannot count" % target.id)
		main._hand_xray_overlay.ingest_hands(_hands())
		main._sync_chapter_xray_view()
		main._update_floor_two_xray_observation()
		_check(state.floor_two_progress.xray_observed_ids.size() == prior + 1, "%s real scene projection/ray advances discovery" % target.id)
	_check(Journey.can_exit(state.floor_two_progress), "three actual spatial observations unlock the exit")
	var saved: Dictionary = state.to_save_data()
	_check(saved.state.floor_two_progress.xray_observed_ids == Journey.XRAY_OBSERVATION_IDS, "spatial discoveries persist")
	main._open_phone_launcher()
	main._on_app_pressed("map")
	await _frames(3)
	main._update_floor_two_exploration(0)
	var page = main._phone_map_page
	_check(page._walkable != page._xray_walkable, "phone receives two slightly different maps")
	var map_rect: Rect2 = page._map_global_rect()
	var normalized := Rect2(map_rect.position / main._viewport_size(), map_rect.size * 0.5 / main._viewport_size())
	page.set_xray_frame(normalized, main._viewport_size(), true)
	var clip: Rect2 = page._local_xray_clip()
	_check(clip.size.is_equal_approx(page._map_rect.size * 0.5), "phone gesture window uses global-to-local coordinates")
	page.set_xray_frame(normalized, main._viewport_size(), false)
	_check(not page._local_xray_clip().has_area(), "lost gesture removes the second map immediately")
	var full_frame := Rect2(map_rect.position / main._viewport_size(), map_rect.size / main._viewport_size())
	page.set_xray_frame(full_frame, main._viewport_size(), true)
	_check("exit" in page.observed_xray_targets(layout, main._reality_player.position), "nearby explored white exit can also be discovered through the phone's X-ray map")
	_check(page.observed_xray_targets(layout, layout.spawn).is_empty(), "viewing a distant map area cannot skip spatial teaching")
	if OS.get_environment("APHASIA_CAPTURE_PHONE_XRAY") == "1" and DisplayServer.get_name() != "headless":
		var output := "res://artifacts/phone-xray-20261019"
		DirAccess.make_dir_recursive_absolute(output)
		# Render fixture reveals the authored route, without changing production saves.
		for point: Vector3 in layout.primary_route:
			main._floor_two_map_state.reveal_at(point)
		page.configure(main._floor_two_map_snapshot(), "zh")
		main._hand_xray_overlay.set_tracking_enabled(false)
		main._sync_chapter_xray_view()
		page.set_xray_frame(Rect2(), main._viewport_size(), false)
		for frame in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var normal_image := root.get_texture().get_image()
		normal_image.save_png(output + "/phone-normal.png")
		_check(normal_image.get_pixel(20, 20).get_luminance() < 0.04 and normal_image.get_pixel(20, normal_image.get_height() - 20).get_luminance() < 0.04, "actual phone-open image retains top and bottom black bars")
		var phone_overlap := Vector2i(main._phone_panel.get_global_transform() * Vector2(30, 25))
		_check(main._cinematic_top_bar.get_global_rect().has_point(Vector2(phone_overlap)), "phone test sample overlaps the actual top letterbox region")
		_check(normal_image.get_pixelv(phone_overlap).get_luminance() > 0.5, "actual phone screen remains visible in front of the top black bar")
		main._hand_xray_overlay.set_tracking_enabled(true)
		main._hand_xray_overlay.ingest_hands(_hands(full_frame))
		main._sync_chapter_xray_view()
		page.set_xray_frame(full_frame, main._viewport_size(), true)
		for frame in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var xray_image := root.get_texture().get_image()
		xray_image.save_png(output + "/phone-xray.png")
		var exit_pixel := Vector2i(page.get_global_transform() * (page._map_rect.position + page._exit_uv * page._map_rect.size))
		_check(xray_image.get_pixelv(exit_pixel).get_luminance() > 0.95, "actual rendered white exit stays visible above the nearby position marker")
		_check(normal_image.get_pixelv(exit_pixel) != xray_image.get_pixelv(exit_pixel), "ordinary phone rendering hides the white exit clue")
	main._camera_enabled = false
	main.free()
	for failure in failures:
		push_error(failure)
	print("floor two phone X-ray: %d checks, %d failures (synthetic landmarks; no camera activated)" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _hands(bounds: Rect2 = Rect2(0.15, 0.2, 0.7, 0.6)) -> Array:
	var hands: Array = []
	for x in [bounds.position.x, bounds.end.x]:
		var points: Array = []
		for index in 21:
			points.append({"x": x, "y": 0.5, "z": 0.0})
		points[4].y = bounds.end.y
		points[8].y = bounds.position.y
		hands.append({"landmarks": points})
	return hands

func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
