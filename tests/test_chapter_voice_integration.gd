extends SceneTree

const State = preload("res://scripts/meme_game_state.gd")
const Director = preload("res://scripts/progression/basement_loop_director.gd")

var failures: Array[String] = []
var checks := 0
var main


func _init() -> void:
	root.visible = false
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1600, 900)
	main = load("res://scenes/babel_meme_game.tscn").instantiate()
	# Redirect both paths before _ready: no production progress or preferences.
	var stem := "user://aphasia-chapter-voice-%d" % OS.get_process_id()
	main._save_path = stem + ".dat"
	main._locale.preferences_path = stem + ".cfg"
	main._locale.select_language("zh")
	main._locale.save_preferences(50.0, false, false, "computer")
	root.add_child(main)
	main._resolve_camera_consent(false)
	# The completed first visit is a trusted fixture. All tested voice events
	# travel from the production world through Main's connected event handler.
	main._begin_game_session(_second_visit_state(), {}, false)
	main.set_process(false)
	main.set_physics_process(false)
	await _frames()
	var world = main._reality_floor
	var atmosphere = world.get_node("BasementAtmosphere")
	var whisper := atmosphere.get_node_or_null("BasementWhisper") as AudioStreamPlayer
	_check(main._chapter_world_ready and whisper != null and whisper.stream != null, "production second basement binds its whisper WAV")
	if whisper == null or whisper.stream == null:
		_finish()
		return
	_check(is_equal_approx(whisper.stream.get_length(), 8.0), "the production whisper asset is eight seconds long")
	main._animate_world(30.0)
	_check(not whisper.playing and not main.game.chapter1_progress.basement_whisper_played, "waiting on the entrance landing does not trigger or consume the whisper")
	# Cross the real first-stair trigger, with the player feet at the authored
	# stair height. This is the same swept route used by the chapter world test.
	main._reality_player.global_position = world.imported_root.to_global(Vector3(-2.5, 2.1, -0.9))
	main._animate_world(0.0)
	await _frames()
	_check(main.game.chapter1_progress.entrance_locked, "the real stair crossing seals and saves the second entrance")
	main._animate_world(2.4)
	_check(not whisper.playing, "whisper waits for the authored arrival delay")
	main._animate_world(0.2)
	await _frames()
	_check(whisper.playing and main.game.chapter1_progress.basement_whisper_played, "world start event reaches Main and consumes the whisper while audio is active")
	var saved: Dictionary = main._load_save_payload()
	_check(bool(saved.get("game", {}).get("state", {}).get("chapter1_progress", {}).get("basement_whisper_played", false)), "start automatically reaches the isolated disk save before audio completion")
	_check(not atmosphere._anomaly_cancelled, "progress synchronization keeps the current sound and flicker active")

	main.set_view_state("phone_down")
	await _check_paused(atmosphere, whisper, "phone")
	main.set_view_state("npc_up")
	_check_resumed(atmosphere, whisper, "putting the phone away")
	main._toggle_settings_window()
	_check(main._settings_open, "the ordinary settings handler opens settings")
	await _check_paused(atmosphere, whisper, "settings")
	main._close_settings_window()
	_check_resumed(atmosphere, whisper, "closing settings")
	main._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _check_paused(atmosphere, whisper, "focus loss")
	main._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check_resumed(atmosphere, whisper, "regaining focus")

	var terminal: Area3D = main._chapter_actor("chapter1_terminal")
	_check(terminal != null, "production basement supplies its terminal interaction")
	if terminal != null:
		main._reality_player.global_position = terminal.global_position + Vector3(0.0, 0.05, 0.35)
		_check(world.interact(terminal), "the terminal's world event enters the real CRT session")
		await _frames()
		_check(main._chapter_terminal_active(), "the terminal session is active")
		await _check_paused(atmosphere, whisper, "terminal")
		main._end_chapter_terminal()
		await create_timer(0.85).timeout
		_check(not main._chapter_terminal_active(), "the normal terminal exit restores exploration")
		_check_resumed(atmosphere, whisper, "leaving the terminal")

	main._animate_world(8.1)
	_check(not whisper.playing and atmosphere.lights_are_on(), "finishing the active interval stops audio and restores the room lights")
	main._animate_world(30.0)
	_check(not whisper.playing and atmosphere.lights_are_on(), "remaining in the room does not restart a finished whisper")

	# Start a separate fresh fixture, then leave during playback. The start
	# marker must survive both teardown and the actual Continue Game loader.
	main._begin_game_session(_second_visit_state(true), {}, false)
	await _frames()
	world = main._reality_floor
	atmosphere = world.get_node("BasementAtmosphere")
	whisper = atmosphere.get_node("BasementWhisper")
	main._animate_world(0.0)
	main._animate_world(2.6)
	await _frames()
	_check(whisper.playing and main.game.chapter1_progress.basement_whisper_played, "the interrupted-playback fixture starts through the ordinary event bridge")
	var whisper_id := whisper.get_instance_id()
	main.show_main_menu()
	await _frames()
	_check(not main._game_started and not is_instance_id_valid(whisper_id), "returning to the menu releases the active whisper player")
	_check(main.continue_game(), "Continue Game loads the saved interrupted second visit")
	await _frames()
	atmosphere = main._reality_floor.get_node("BasementAtmosphere")
	whisper = atmosphere.get_node("BasementWhisper")
	main._animate_world(0.0)
	main._animate_world(30.0)
	_check(main.game.chapter1_progress.basement_whisper_played, "continue preserves the consumed start marker")
	_check(not whisper.playing and atmosphere.lights_are_on(), "continue never replays interrupted audio or its paired flicker")
	_finish()


func _check_paused(atmosphere: Node, whisper: AudioStreamPlayer, reason: String) -> void:
	main._animate_world(0.0)
	await _frames()
	var elapsed: float = atmosphere._elapsed
	var lights_on: bool = atmosphere.lights_are_on()
	var playback_position := whisper.get_playback_position()
	_check(whisper.stream_paused, "%s pauses the voice stream" % reason)
	main._animate_world(20.0)
	await create_timer(0.12).timeout
	_check(is_equal_approx(atmosphere._elapsed, elapsed) and atmosphere.lights_are_on() == lights_on, "%s freezes both anomaly time and lamp state" % reason)
	_check(absf(whisper.get_playback_position() - playback_position) < 0.05, "%s does not consume the paused audio" % reason)


func _check_resumed(atmosphere: Node, whisper: AudioStreamPlayer, reason: String) -> void:
	main._animate_world(0.0)
	_check(whisper.playing and not whisper.stream_paused and not atmosphere._anomaly_cancelled, "%s resumes the same active sound and flicker" % reason)


func _second_visit_state(sealed: bool = false) -> MemeGameState:
	var state := State.new()
	state.new_run()
	state.start_chapter1()
	state.notify_chapter1("narration_completed", {"sequence_id": Director.OPENING_SEQUENCE_ID})
	state.notify_chapter1("opening_knock_completed", {"sequence_id": Director.OPENING_SEQUENCE_ID})
	state.notify_chapter1("opening_door_opened")
	state.notify_chapter1("phone_collected", {"round_token": 1})
	state.notify_chapter1("entrance_threshold_crossed", {"round_token": 1})
	state.notify_chapter1("npc_help_completed", {"round_token": 1, "task_id": "basement_help_01", "npc_id": "basement_npc_01"})
	state.notify_chapter1("basement_exit_requested", {"round_token": 1})
	if sealed:
		state.notify_chapter1("entrance_threshold_crossed", {"round_token": 2})
	state.view_state = "npc_up"
	state.active_app_window = ""
	return state


func _frames() -> void:
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _finish() -> void:
	main.free()
	for failure in failures:
		push_error(failure)
	print("chapter voice integration: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
