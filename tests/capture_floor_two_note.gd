extends SceneTree
## Actual production world and F pickup, captured without opening a visible window.
const State = preload("res://scripts/meme_game_state.gd")
const ExistingFlow = preload("res://tests/test_chapter_terminal_flow.gd")
var output := ""
var viewport: SubViewport

func _init() -> void:
	root.visible = false
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("note captures require an actual renderer")
		quit(1)
		return
	output = OS.get_environment("FLOOR_NOTE_OUTPUT")
	if output.is_empty():
		push_error("FLOOR_NOTE_OUTPUT must name an isolated capture directory")
		quit(1)
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var main = load("res://scenes/babel_meme_game.tscn").instantiate()
	main._hand_tracking_receiver = ExistingFlow.FakeReceiver.new()
	main._save_path = "user://floor-two-note-capture.dat"
	main._locale.preferences_path = "user://floor-two-note-capture.cfg"
	viewport.add_child(main)
	main._resolve_camera_consent(false)
	var state := State.new()
	state.new_run()
	state.tower_floor = 2
	# The player reaches this street after the phone's introductory map reveal.
	state.floor_two_progress = preload("res://scripts/progression/floor_two_journey.gd").complete_map_intro({})
	state.set_view_state("npc_up")
	main._locale.set_locale("zh")
	main._begin_game_session(state, {}, false)
	main._set_reality_mouse_look(false)
	await create_timer(2.9).timeout
	await _frames(3)
	main.set_process(false)
	main.set_physics_process(false)
	var note: Area3D = main._reality_floor.find_child("FloorTwoNote", true, false)
	if note == null:
		push_error("production floor two must contain the actual note")
		quit(1)
		return
	main._reality_player.global_position = note.global_position + Vector3(0, 0, 1.2)
	main._camera.global_position = main._reality_player.global_position + Vector3(0, 1.56, 0)
	main._camera.look_at(note.global_position)
	main._refresh_nearby_reality_actor()
	await _save("world-note")
	main._application_focused = true
	var interact := InputEventKey.new()
	interact.keycode = KEY_F
	interact.physical_keycode = KEY_F
	interact.pressed = true
	main._unhandled_input(interact)
	if not main._floor_two_note_active():
		push_error("actual F failed to open the production note")
		quit(1)
		return
	await _save("inspect-zh")
	for locale in ["en", "ja"]:
		main._floor_two_note_view.open(locale)
		await _save("inspect-" + locale)
	viewport.size = Vector2i(800, 600)
	main._floor_two_note_view.open("zh")
	await _save("inspect-zh-800x600")
	var paper = main._floor_two_note_view.get_node("NotePaper")
	var report := {
		"renderer": RenderingServer.get_current_rendering_method(),
		"display_server": DisplayServer.get_name(),
		"actor": str(note.get_meta("actor_id")),
		"font_800x600": paper.handwriting_font_size(),
		"paper_size_800x600": str(paper.size),
		"original": paper.ORIGINAL_TEXT,
	}
	FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	main._floor_two_note_view.close()
	main._set_reality_mouse_look(false)
	main.free()
	viewport.free()
	await _frames(5)
	print("floor two note native capture passed")
	quit()

func _save(stem: String) -> void:
	await _frames(5)
	var result := viewport.get_texture().get_image().save_png(output.path_join(stem + ".png"))
	assert(result == OK)

func _frames(count: int) -> void:
	for index in count:
		await process_frame
		RenderingServer.force_draw()
