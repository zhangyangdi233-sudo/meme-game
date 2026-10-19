extends SceneTree
## Native renderer regression for Godot 4.6 light/geometry lifetime corruption.
## Run via tools/verify_crt_renderer_lifecycle.py; headless is deliberately invalid.

const State = preload("res://scripts/meme_game_state.gd")
const ExistingFlow = preload("res://tests/test_chapter_terminal_flow.gd")
var main: Node
var viewport: SubViewport
var failures: Array[String] = []
var checks := 0
var output := ""

func _init() -> void:
	root.visible = false
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("CRT renderer lifecycle requires native Forward+ or Compatibility; headless cannot validate light pairing")
		quit(1)
		return
	output = OS.get_environment("CRT_RENDER_OUTPUT")
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	main = load("res://scenes/babel_meme_game.tscn").instantiate()
	main._hand_tracking_receiver = ExistingFlow.FakeReceiver.new()
	main._save_path = "user://crt-renderer-lifecycle.dat"
	main._locale.preferences_path = "user://crt-renderer-lifecycle.cfg"
	var source := OS.get_environment("CRT_RENDER_SAVE_COPY")
	var payload: Dictionary
	if not source.is_empty():
		var source_file := FileAccess.open(source, FileAccess.READ)
		_check(source_file != null, "the optional user's save copy is read-only and accessible")
		if source_file == null:
			await _finish()
			return
		payload = source_file.get_var()
	else:
		var state := _fresh_state()
		state.chapter1_progress.crt_tutorial = {"focus_done": true, "focus_started": true, "focus_line": 7}
		payload = {"version": main.SAVE_FILE_VERSION, "game": state.to_save_data(), "world": {"route_key": "basement:0", "player_position": Vector3(-2.8, 1.42, 0.535)}}
	var save_file := FileAccess.open(main._save_path, FileAccess.WRITE)
	save_file.store_var(payload)
	save_file.close()
	viewport.add_child(main)
	main._resolve_camera_consent(false)
	main._locale.set_locale("zh")
	_check(main.continue_game(), "ordinary Continue loads the isolated saved first-basement game")
	await _frames(8)
	_check(main.game.chapter1_progress.crt_tutorial.focus_done and not main._crt_focus_tutorial_active(), "the user's completed narration does not replay after Continue")
	await _enter_terminal()
	_check(main._chapter_terminal_session.tutorial_active(), "Continue then real F still opens the unfinished first CRT lesson")
	await _capture("continue-crt.png")
	await _leave_terminal()
	print("CRT RENDER CHECKPOINT: continued-save F and Tab survived")

	# A clean first visit must render the actual light/mesh pairs before they are
	# released. The user's save already completed this part before the crash.
	main._begin_game_session(_fresh_state(), {}, false)
	await _frames(6)
	var original_layers: Dictionary = {}
	for mesh in main._reality_floor.get_crt_focus_visuals():
		original_layers[mesh] = mesh.layers
	main._reality_player.position = Vector3(-2.5, 1.45, 0.3)
	main._reality_player.velocity = Vector3.ZERO
	main._animate_world(0.016)
	main._update_crt_focus_tutorial(0.016)
	main._reality_player.position = Vector3(-2.5, 1.32, 0.6)
	main._animate_world(0.016)
	main._update_crt_focus_tutorial(0.016)
	await create_timer(1.0).timeout
	_check(main._crt_focus_tutorial_active(), "fresh physical stair crossing renders the focus scene")
	_check(main._reality_floor.find_child("CRTFirstVisitWhiteLightBeam", true, false) == null, "native focus shows no overhead light-beam geometry")
	for mesh in original_layers:
		_check(mesh.layers == original_layers[mesh], "native focus preserves every original CRT renderer layer")
	await _capture("fresh-focus.png")
	main._settings_open = true
	main._crt_focus_tutorial.cancel()
	await _frames(6)
	_check(_temporary_count() == 0, "cancel frees all focus mirrors and spotlight after rendered frames")
	_check(main._save_progress(), "cancelled first narration saves through the regular save path")
	main._settings_open = false
	_check(main.continue_game(), "ordinary Continue reloads a cancelled first narration")
	await create_timer(1.0).timeout
	_check(main._crt_focus_tutorial_active() and main.game.chapter1_progress.crt_tutorial.focus_line == 1, "reloaded narration resumes the saved line")
	_check(main._reality_floor.find_child("CRTFirstVisitWhiteLightBeam", true, false) == null, "resumed focus cannot recreate the removed white mist")
	var advance := InputEventMouseButton.new()
	advance.button_index = MOUSE_BUTTON_LEFT
	advance.pressed = true
	for line in 7:
		main._input(advance)
		await _frames(5)
	await create_timer(0.8).timeout
	_check(main.game.chapter1_progress.crt_tutorial.focus_done and not main._crt_focus_tutorial_active(), "seven real narration inputs restore the room and finish camera return")
	_check(_temporary_count() == 0, "completion releases every temporary focus object instead of leaking hidden lights")
	print("CRT RENDER CHECKPOINT: fresh focus, cancel, reload and completion survived")
	for cycle in 3:
		await _enter_terminal()
		await _frames(8)
		await _leave_terminal()
	_check(main._save_progress() and main.continue_game(), "Continue after repeated CRT visits rebuilds the world without stale light pairs")
	await _frames(8)
	_check(not main._crt_focus_tutorial_active(), "reloaded finished focus remains one-shot")
	await _enter_terminal()
	await _capture("after-focus-crt.png")
	await _leave_terminal()
	await _finish()

func _fresh_state() -> RefCounted:
	var state := State.new()
	state.new_run()
	state.start_chapter1()
	state.notify_chapter1("narration_completed", {"sequence_id": "chapter1_opening"})
	state.notify_chapter1("opening_knock_completed", {"sequence_id": "chapter1_opening"})
	state.notify_chapter1("opening_door_opened")
	state.notify_chapter1("entrance_threshold_crossed", {"round_token": 1})
	state.view_state = "npc_up"
	return state

func _enter_terminal() -> void:
	var actor: Area3D
	for candidate in main._reality_floor.get_interactable_actors():
		if candidate.get_meta("actor_type", "") == "chapter1_terminal":
			actor = candidate
	_check(actor != null, "the imported world exposes its physical CRT interaction actor")
	if actor == null:
		return
	main._set_reality_mouse_look(false)
	main._reality_player.global_position = actor.global_position + Vector3(0, 0.05, 0.3)
	main._reality_player.velocity = Vector3.ZERO
	main._reality_last_safe_position = main._reality_player.position
	main._animate_world(0.016)
	main._refresh_nearby_reality_actor()
	var event := InputEventKey.new()
	event.keycode = KEY_F
	event.physical_keycode = KEY_F
	event.pressed = true
	main._unhandled_input(event)
	await create_timer(0.95).timeout
	await _frames(5)
	_check(main._chapter_terminal_active(), "real F input opens CRT after a fully rendered world lifecycle")

func _leave_terminal() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_TAB
	event.physical_keycode = KEY_TAB
	event.pressed = true
	main._input(event)
	await create_timer(0.75).timeout
	await _frames(5)
	_check(not main._chapter_terminal_active(), "real Tab returns from CRT without native renderer corruption")

func _temporary_count() -> int:
	return main._reality_floor.find_children("CRTFocusMirror*", "MeshInstance3D", true, false).size() + main._reality_floor.find_children("CRTFirstVisitWhite*", "Node3D", true, false).size()

func _capture(filename: String) -> void:
	if output.is_empty():
		return
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join(filename))

func _frames(count: int) -> void:
	for index in count:
		await process_frame

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _finish() -> void:
	if is_instance_valid(main):
		main.free()
	if is_instance_valid(viewport):
		viewport.queue_free()
	await _frames(8)
	for message in failures:
		push_error(message)
	if failures.is_empty():
		print("CRT native renderer lifecycle passed (%d checks; Continue, focus, cancel/reload, F/Tab, full cleanup)" % checks)
	quit(0 if failures.is_empty() else 1)
