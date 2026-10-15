extends SceneTree

const VIDEO = preload("res://scripts/world/chapter_video_screen.gd")
const ANOMALY_PATH := "res://scripts/world/basement_crt_anomaly.gd"
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var video := VIDEO.new()
	_check(video.has_method("set_signal_override") and video.has_method("clear_signal_override"), "primary CRT supports reversible signal override")
	video.free()
	_check(FileAccess.file_exists(ANOMALY_PATH), "fifth-visit CRT anomaly controller exists")
	if failures.is_empty():
		_test_sequence()
		_test_resume_consumed()
		await _test_supplied_video()
		await _test_world_persistence()
		await create_timer(0.1).timeout
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("basement CRT anomaly tests passed")
	quit(0 if failures.is_empty() else 1)

func _fixture(consumed: bool = false, actual_video: bool = false) -> Dictionary:
	var host := Node3D.new()
	root.add_child(host)
	var asset := Node3D.new()
	host.add_child(asset)
	var light := OmniLight3D.new()
	light.name = "RoomLamp"
	light.light_energy = 0.7
	host.add_child(light)
	var already_off := SpotLight3D.new()
	already_off.visible = false
	host.add_child(already_off)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_energy = 0.1
	host.add_child(environment)
	var bulb := MeshInstance3D.new()
	bulb.mesh = QuadMesh.new()
	var bulb_material := StandardMaterial3D.new()
	bulb_material.emission_enabled = true
	bulb_material.emission_energy_multiplier = 1.1
	bulb_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb_material.albedo_color = Color.WHITE
	bulb.material_override = bulb_material
	host.add_child(bulb)
	var mesh := MeshInstance3D.new()
	mesh.mesh = QuadMesh.new()
	host.add_child(mesh)
	var video := VIDEO.new()
	host.add_child(video)
	video.bind_screen(mesh)
	video.set_standby_color(Color.GREEN)
	var anomaly = load(ANOMALY_PATH).new()
	host.add_child(anomaly)
	anomaly.configure(host, asset, {"round_index": 4, "basement_crt_event_played": consumed}, "res://assets/video/basement_crt_loop.ogv" if actual_video else "")
	anomaly.bind_primary_screen(video)
	return {"host": host, "anomaly": anomaly, "light": light, "off": already_off, "environment": environment, "video": video, "mesh": mesh, "bulb": bulb_material}

func _test_sequence() -> void:
	var f := _fixture()
	var anomaly = f.anomaly
	var started := [0]
	anomaly.started.connect(func(): started[0] += 1)
	_check(anomaly.get_monitor_count() == 12, "fifth room contains twelve thick CRT monitors")
	_check(anomaly.get_wall_monitor_count() == 4, "four CRT cases are embedded in walls")
	anomaly.update_visit(10.0, false, Vector3.ZERO)
	_check(started[0] == 0, "center cannot trigger before entrance is locked")
	anomaly.update_visit(10.0, true, Vector3(2, 0, 0))
	_check(started[0] == 0, "room edge does not trigger the center event")
	anomaly.update_visit(0.0, true, Vector3.ZERO)
	_check(started[0] == 1 and anomaly.event_phase() == "black", "first center arrival starts the blackout exactly once")
	_check(not f.light.visible and not f.off.visible, "all existing room lights are disabled")
	_check(f.environment.environment.ambient_light_energy == 0.0, "ambient fill is removed during blackout")
	_check(f.bulb.emission_energy_multiplier == 0.0 and f.bulb.albedo_color == Color.BLACK, "emissive and unshaded bulb surfaces both go dark")
	_check(f.mesh.get_surface_override_material(0).albedo_color == Color.BLACK, "primary CRT goes fully black")
	anomaly.update_visit(1.99, true, Vector3.ZERO)
	_check(anomaly.event_phase() == "black" and not anomaly.is_static_playing(), "first two seconds remain silent and black")
	anomaly.set_paused(true)
	anomaly.update_visit(60.0, true, Vector3.ZERO)
	_check(anomaly.event_phase() == "black", "pause freezes event time")
	anomaly.set_paused(false)
	anomaly.update_visit(0.01, true, Vector3.ZERO)
	_check(anomaly.event_phase() == "red" and anomaly.is_static_playing(), "red screens and snow audio start together at two seconds")
	_check(f.mesh.get_surface_override_material(0).albedo_color.r > 0.9, "primary CRT joins the solid red signal")
	_check(anomaly.active_red_light_count() == 12, "every added screen illuminates the room in red")
	anomaly.set_paused(true)
	_check(anomaly.get_node("TVStatic").stream_paused, "menu pause suspends noise immediately")
	anomaly.update_visit(60.0, true, Vector3.ZERO)
	anomaly.set_paused(false)
	anomaly.update_visit(5.99, true, Vector3.ZERO)
	_check(anomaly.event_phase() == "red" and anomaly.is_static_playing(), "red lasts the full six seconds")
	anomaly.update_visit(0.011, true, Vector3.ZERO)
	_check(anomaly.event_phase() == "recovery_black" and not anomaly.is_static_playing(), "six-second red ends with a silent black flash")
	anomaly.update_visit(0.20, true, Vector3.ZERO)
	_check(anomaly.event_phase() == "complete" and f.light.visible and not f.off.visible, "recovery restores each original light state")
	_check(is_equal_approx(f.environment.environment.ambient_light_energy, 0.1), "ambient fill restores after the event")
	_check(is_equal_approx(f.bulb.emission_energy_multiplier, 1.1) and f.bulb.albedo_color == Color.WHITE, "bulb emission and albedo restore exactly")
	_check(f.mesh.get_surface_override_material(0).albedo_color == Color.GREEN, "primary CRT restores its prior display")
	anomaly.update_visit(100.0, true, Vector3.ZERO)
	_check(started[0] == 1, "remaining in the center never repeats the sequence")
	f.host.free()

func _test_world_persistence() -> void:
	var director = load("res://scripts/progression/basement_loop_director.gd")
	var state = load("res://scripts/meme_game_state.gd").new()
	state.new_run()
	state.start_chapter1()
	var progress: Dictionary = director.initial_progress(false)
	progress.merge({"phase": "basement", "round_index": 4, "transition_serial": 5, "narrator_completed": true, "opening_knock_completed": true, "opening_line_number": 30, "entrance_locked": true, "completed_task_ids": director.TASK_IDS.slice(0, 4)}, true)
	state.chapter1_progress = director.normalize_progress(progress)
	_check(not state.notify_chapter1("basement_crt_event_started", {"round_token": 4}).accepted, "stale room callbacks cannot consume CRT event")
	var world = load("res://scripts/world/chapter_world.gd").new()
	root.add_child(world)
	_check(world.configure_stage(state.chapter1_progress, {}), "production fifth-room scene configures")
	var event_count := [0]
	world.event_requested.connect(func(event: String, payload: Dictionary):
		if event == "basement_crt_event_started":
			event_count[0] += 1
			state.notify_chapter1(event, payload)
			world.sync_progress(state.chapter1_progress)
	)
	world.update_authored_events(0.0, world.imported_root.to_global(Vector3(2, 0, 0)), Vector3.FORWARD)
	world.update_authored_events(0.0, world.imported_root.to_global(Vector3.ZERO), Vector3.FORWARD)
	_check(event_count[0] == 1 and state.chapter1_progress.basement_crt_event_played, "actual center movement emits and persists the once-only event at start")
	_check(world.find_child("CRTAnomaly", true, false).event_phase() == "black", "synchronous progress save does not cancel the running blackout")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(state.to_save_data()))
	world.free()
	var restored = load("res://scripts/meme_game_state.gd").new()
	_check(restored.load_save_data(saved), "a save made during blackout loads through the normal save envelope")
	world = load("res://scripts/world/chapter_world.gd").new()
	root.add_child(world)
	_check(world.configure_stage(restored.chapter1_progress, {}), "saved fifth room restores")
	world.update_authored_events(0.0, world.imported_root.to_global(Vector3.ZERO), Vector3.FORWARD)
	world.update_authored_events(20.0, world.imported_root.to_global(Vector3.ZERO), Vector3.FORWARD)
	_check(world.find_child("CRTAnomaly", true, false).event_phase() == "complete", "continuing a mid-event save restores normal room without replaying")
	_check(not restored.notify_chapter1("basement_crt_event_started", {"round_token": 5}).accepted, "persisted event rejects duplicate start callbacks")
	world.free()
	# Leaving in the middle of red must not leave external light/material owners altered.
	var f := _fixture()
	f.anomaly.update_visit(0.0, true, Vector3.ZERO)
	f.anomaly.update_visit(2.0, true, Vector3.ZERO)
	await create_timer(0.05).timeout
	f.anomaly.cancel()
	_check(f.light.visible and not f.anomaly.is_static_playing(), "scene transition cancellation restores external state and stops sound")
	_check(f.mesh.get_surface_override_material(0).albedo_color == Color.GREEN, "cancellation restores the primary screen")
	f.host.free()

func _test_resume_consumed() -> void:
	var f := _fixture(true)
	f.anomaly.update_visit(20.0, true, Vector3.ZERO)
	_check(f.anomaly.event_phase() == "complete" and f.light.visible, "restoring a consumed marker never replays the event")
	f.host.free()

func _test_supplied_video() -> void:
	var f := _fixture(true, true)
	_check(f.anomaly.get_meta("video_source_available", false), "user-supplied MP4 has a playable Theora derivative")
	await create_timer(0.15).timeout
	var positions: Array[float] = []
	for player: VideoStreamPlayer in f.anomaly.find_children("VideoPlayer", "VideoStreamPlayer", true, false):
		_check(player.is_playing() and player.loop, "each CRT actually decodes and loops the supplied video")
		_check(player.get_stream_length() > 35.0 and player.get_stream_length() < 36.0, "full source video duration survives conversion")
		_check(player.volume_db <= -80.0, "all twelve video tracks are silent")
		positions.append(player.stream_position)
	_check(positions.size() == 12 and positions[11] - positions[0] > 18.0, "real Theora decoders seek to different offsets")
	var primary_player := f.video.get_node("VideoViewport/VideoPlayer") as VideoStreamPlayer
	_check(primary_player.is_playing() and primary_player.loop and primary_player.stream_position > 20.0, "main teaching CRT also loops the same video with its own offset")
	var gui_material := StandardMaterial3D.new()
	gui_material.albedo_color = Color.BLUE
	_check(f.video.attach_display(f.host, gui_material), "interactive terminal can borrow ambient video surface")
	_check(f.mesh.get_surface_override_material(0) == gui_material, "interactive terminal UI takes precedence over background video")
	f.video.detach_display(f.host)
	_check(f.mesh.get_surface_override_material(0) != gui_material and primary_player.is_playing(), "leaving terminal restores video without stopping playback")
	f.video.set_signal_override(Color.BLACK)
	f.video.attach_display(f.host, gui_material)
	f.video.detach_display(f.host)
	_check(f.mesh.get_surface_override_material(0).albedo_color == Color.BLACK, "closing terminal during blackout cannot expose the background video")
	f.video.clear_signal_override()
	f.anomaly.set_paused(true)
	var paused_position: float = f.anomaly.find_children("VideoPlayer", "VideoStreamPlayer", true, false)[0].stream_position
	await create_timer(0.1).timeout
	_check(is_equal_approx(f.anomaly.find_children("VideoPlayer", "VideoStreamPlayer", true, false)[0].stream_position, paused_position), "real looping videos freeze during pause")
	f.anomaly.set_paused(false)
	f.host.free()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
