extends SceneTree
## Historical filename retained. Captures the final CRT-only focus without mist.
## Run with an isolated APPDATA and log file using a native renderer.
## No OS input or user save access; all input is scoped to this test scene.

const State = preload("res://scripts/meme_game_state.gd")
const ExistingFlow = preload("res://tests/test_chapter_terminal_flow.gd")
var output := "res://artifacts/crt-no-beam-20261019"
var viewport: SubViewport
var main: Node
var measurements: Array[Dictionary] = []
var failures: Array[String] = []

func _init() -> void:
	root.visible = false
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("CRT-only focus capture requires actual rendered pixels")
		quit(2)
		return
	output = output.path_join(RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for sample in [{"name": "stair-center", "x": -2.5}, {"name": "stair-left", "x": -2.85}, {"name": "stair-right", "x": -2.15}]:
		await _shot(sample)
	var report := FileAccess.open(output.path_join("measurements.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(measurements, "\t"))
	viewport.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("CRT-only focus captures passed (%d angles, %s)" % [measurements.size(), RenderingServer.get_current_rendering_method()])
	quit(0 if failures.is_empty() else 1)

func _shot(sample: Dictionary) -> void:
	main = load("res://scenes/babel_meme_game.tscn").instantiate()
	main._hand_tracking_receiver = ExistingFlow.FakeReceiver.new()
	main._save_path = "user://soft-light-capture.dat"
	main._locale.preferences_path = "user://soft-light-capture.cfg"
	viewport.add_child(main)
	main._resolve_camera_consent(false)
	main._locale.set_locale("zh")
	main._on_vhs_toggled(true)
	var state := State.new()
	state.new_run()
	state.start_chapter1()
	state.notify_chapter1("narration_completed", {"sequence_id": "chapter1_opening"})
	state.notify_chapter1("opening_knock_completed", {"sequence_id": "chapter1_opening"})
	state.notify_chapter1("opening_door_opened")
	state.notify_chapter1("entrance_threshold_crossed", {"round_token": 1})
	state.view_state = "npc_up"
	main._begin_game_session(state, {}, false)
	main._set_reality_mouse_look(false)
	await _frames(4)
	main._reality_player.position = Vector3(float(sample.x), 1.45, 0.3)
	main._reality_player.velocity = Vector3.ZERO
	main._animate_world(0.016)
	main._update_crt_focus_tutorial(0.016)
	main._reality_player.position = Vector3(float(sample.x), 1.32, 0.6)
	main._animate_world(0.016)
	main._update_crt_focus_tutorial(0.016)
	await create_timer(1.15).timeout
	await _frames(5)
	if not main._crt_focus_tutorial_active():
		push_error("Real stair trigger did not start focus at %s" % sample.name)
		quit(1)
		return
	main.set_process(false)
	main.set_physics_process(false)
	await _capture(str(sample.name) + "-production-vhs.png")
	main._on_vhs_toggled(false)
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var beam: MeshInstance3D = main._reality_floor.find_child("CRTFirstVisitWhiteLightBeam", true, false)
	if beam != null:
		failures.append("%s: removed overhead white mist must not have a scene instance" % sample.name)
	var screen_region := _projected_bounds(main._reality_floor.get_screen_mesh())
	var crt_region := screen_region
	for mesh in main._reality_floor.get_crt_focus_visuals():
		crt_region = crt_region.merge(_projected_bounds(mesh))
	var above_region := Rect2(Vector2(crt_region.get_center().x - 180.0, crt_region.position.y - 200.0), Vector2(360.0, 176.0))
	var image := await _capture(str(sample.name) + "-crt-only.png")
	var background := image.get_pixel(0, 0)
	var overhead_peak := 0.0
	var overhead_background_delta := 0.0
	for y in range(maxi(0, floori(above_region.position.y)), mini(image.get_height(), ceili(above_region.end.y))):
		for x in range(maxi(0, floori(above_region.position.x)), mini(image.get_width(), ceili(above_region.end.x))):
			var pixel := image.get_pixel(x, y)
			overhead_peak = maxf(overhead_peak, maxf(pixel.r, maxf(pixel.g, pixel.b)))
			overhead_background_delta = maxf(overhead_background_delta, maxf(absf(pixel.r - background.r), maxf(absf(pixel.g - background.g), absf(pixel.b - background.b))))
	# The existing screen tint lifts black by 2–3/255. Require the entire old
	# beam region to match that same dark background, with no local white glow.
	if overhead_peak > 0.02 or overhead_background_delta > 0.004:
		failures.append("%s: pixels above the CRT must match the dark background without a visible beam (delta=%f)" % [sample.name, overhead_background_delta])
	measurements.append({"name": sample.name, "camera": str(main._camera.global_transform), "screen_rect": str(screen_region), "crt_rect": str(crt_region), "overhead_rect": str(above_region), "overhead_peak": overhead_peak, "background_color": str(background), "overhead_background_delta": overhead_background_delta, "beam_instance_absent": beam == null})
	main.queue_free()
	await _frames(5)

func _projected_bounds(mesh: MeshInstance3D) -> Rect2:
	var box := mesh.get_aabb()
	var result := Rect2(main._camera.unproject_position(mesh.to_global(box.position)), Vector2.ZERO)
	for x in [0, 1]:
		for y in [0, 1]:
			for z in [0, 1]:
				result = result.expand(main._camera.unproject_position(mesh.to_global(box.position + box.size * Vector3(x, y, z))))
	return result

func _capture(filename: String) -> Image:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.save_png(output.path_join(filename))
	return image

func _frames(count: int) -> void:
	for index in count:
		await process_frame
