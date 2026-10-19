extends SceneTree

# Real main-scene presentation in a private native SubViewport. Logical app
# focus is supplied to the hidden fixture; no OS input, focus or capture is used.
var main
var viewport: SubViewport
var output := "res://artifacts/floor-two-arrival-20261019"
var failures: Array[String] = []
var checks := 0
var captures: Array = []
var locked_position := Vector3.ZERO
var locked_camera := Transform3D.IDENTITY
var max_player_drift := 0.0
var max_camera_drift := 0.0
var camera_rotation_changed := false
var monitor_lock := false
var started_at := 0

func _init() -> void:
	root.visible = false
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Arrival capture needs native rendered frames")
		quit(2)
		return
	Engine.max_fps = 60
	if not OS.get_environment("APHASIA_CAPTURE_OUTPUT").is_empty():
		output = OS.get_environment("APHASIA_CAPTURE_OUTPUT")
	DirAccess.make_dir_recursive_absolute(output)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1440, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	main = load("res://scenes/babel_meme_game.tscn").instantiate()
	main._save_path = "user://arrival_capture.dat"
	main._locale.preferences_path = "user://arrival_capture.cfg"
	main._locale.set_locale("zh")
	main._locale.save_preferences(0, true, false, "computer")
	viewport.add_child(main)
	main._resolve_camera_consent(false)
	AudioServer.set_bus_mute(0, true)
	var state = load("res://scripts/meme_game_state.gd").new()
	state.new_run()
	state.chapter1_progress = {}
	state.tower_floor = 2
	state.set_view_state("npc_up")
	main._begin_game_session(state, {}, false)
	main._application_focused = true
	started_at = Time.get_ticks_msec()
	_check(not state.is_phone_app_unlocked("map"), "fresh second-floor save starts without map permission")
	if not await _wait_until(func(): return main._day_transition_overlay.visible and main._day_transition_overlay.modulate.a > 0.98, 5.0, "actual arrival title fades in"):
		await _finish()
		return
	await _capture("00-floor-title")
	if not await _wait_until(func(): return main._floor_two_map_unlock_active(), 6.0, "actual title completes before map introduction"):
		await _finish()
		return
	_check(not main._day_transition_overlay.visible, "the title is hidden before the phone introduction begins")
	locked_position = main._reality_player.position
	locked_camera = main._camera.global_transform
	monitor_lock = true
	Input.action_press("reality_forward")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(90, 30)
	viewport.push_input(motion)
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	viewport.push_input(tab)
	var icon: Button = main._phone_panel.app_buttons.map
	if not await _wait_until(func(): return main._phone_panel._slide_fraction > 0.999 and float(icon.get_meta("unlock_brightness", -1.0)) < 0.05, 2.0, "phone reaches the gray icon hold naturally"):
		await _finish()
		return
	_check(icon.visible and icon.disabled and not state.is_phone_app_unlocked("map"), "gray map icon is visible and remains locked")
	await _capture("01-map-gray")
	if not await _wait_until(func(): return float(icon.get_meta("unlock_brightness", -1.0)) >= 0.4 and float(icon.get_meta("unlock_brightness", -1.0)) <= 0.7, 2.0, "real frames reach partial icon brightening"):
		await _finish()
		return
	_check(icon.disabled and not state.is_phone_app_unlocked("map"), "partly brightened map still cannot open")
	await _capture("02-map-brightening")
	Input.action_release("reality_forward")
	if not await _wait_until(func(): return state.is_phone_app_unlocked("map"), 3.0, "real presentation completion grants map permission"):
		await _finish()
		return
	monitor_lock = false
	_check(not icon.disabled and not main._floor_two_map_unlock_active(), "finished icon is enabled and the input lock is released")
	_check(main.game.view_state == "phone_down" and main.game.active_app_window.is_empty() and main._phone_launcher_open, "finished presentation remains on the phone home screen")
	_check(max_player_drift < 0.00001 and max_camera_drift < 0.00001 and not camera_rotation_changed, "actual player and camera are fixed throughout gray and brightening stages despite move/look/Tab input")
	await _capture("03-map-ready-home")
	_check(bool(main._load_save_payload().game.state.floor_two_progress.map_intro_completed), "completion is saved by the real main scene")
	var walk_start: Vector3 = main._reality_player.position
	Input.action_press("reality_forward")
	for frame in 30:
		main._application_focused = true
		await physics_frame
	Input.action_release("reality_forward")
	var distance := Vector2(main._reality_player.position.x - walk_start.x, main._reality_player.position.z - walk_start.z).length()
	_check(distance > 0.5, "real movement resumes after completion with the phone home still open")
	_check(main.game.view_state == "phone_down", "resumed walking does not close the phone")
	captures.append({"after_unlock_walk_distance": distance})
	await _finish()

func _wait_until(predicate: Callable, seconds: float, message: String) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < deadline:
		main._application_focused = true
		await process_frame
		_measure_lock()
		if predicate.call():
			_check(true, message)
			return true
	_check(false, message)
	return false

func _measure_lock() -> void:
	if not monitor_lock or not main._floor_two_map_unlock_active():
		return
	max_player_drift = maxf(max_player_drift, main._reality_player.position.distance_to(locked_position))
	max_camera_drift = maxf(max_camera_drift, main._camera.global_position.distance_to(locked_camera.origin))
	camera_rotation_changed = camera_rotation_changed or not main._camera.global_basis.is_equal_approx(locked_camera.basis)

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	_measure_lock()
	var pixels := viewport.get_texture().get_image()
	_check(pixels.save_png(output.path_join(label + ".png")) == OK, "save native frame " + label)
	var icon: Button = main._phone_panel.app_buttons.map
	captures.append({"name": label, "time_ms": Time.get_ticks_msec() - started_at, "icon_disabled": icon.disabled, "brightness": icon.get_meta("unlock_brightness", -1.0), "icon_alpha": icon.get_theme_color("icon_disabled_color").a if icon.disabled else 1.0, "map_unlocked": main.game.is_phone_app_unlocked("map"), "phone_slide": main._phone_panel._slide_fraction, "player_position": str(main._reality_player.position), "camera_transform": str(main._camera.global_transform)})
	print("captured ", label)

func _finish() -> void:
	Input.action_release("reality_forward")
	var report := {"renderer": RenderingServer.get_current_rendering_method(), "display_server": DisplayServer.get_name(), "vhs_enabled": true, "hidden_fixture_logical_focus": true, "checks": checks, "failures": failures, "max_player_drift": max_player_drift, "max_camera_drift": max_camera_drift, "camera_rotation_changed": camera_rotation_changed, "captures": captures}
	FileAccess.open(output.path_join("report.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	if is_instance_valid(main):
		main._set_reality_mouse_look(false)
	viewport.free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("native floor two arrival %s: %d checks" % ["passed" if failures.is_empty() else "FAILED", checks])
	quit(0 if failures.is_empty() else 1)

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
