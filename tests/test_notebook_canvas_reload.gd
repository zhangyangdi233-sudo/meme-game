extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1600, 900)
	var main = load("res://scenes/babel_meme_game.tscn").instantiate()
	main._save_path = "res://artifacts/test_notebook_canvas_reload.dat"
	main._locale.preferences_path = "res://artifacts/test_notebook_canvas_reload.cfg"
	root.add_child(main)
	var state = load("res://scripts/meme_game_state.gd").new()
	state.new_run()
	state.start_chapter1()
	state.notify_chapter1("opening_knock_completed", {"sequence_id": "chapter1_opening"})
	state.notify_chapter1("opening_door_opened")
	state.collected_char_units.append({"unit": "门", "locale": "zh"})
	main._locale.set_locale("zh")
	main._begin_game_session(state, {}, false)
	await process_frame
	await process_frame
	var actor = main._chapter_actor("chapter1_terminal")
	main._reality_player.global_position = actor.global_position + Vector3(0, -actor.global_position.y, 0.4)
	main._chapter_world_ready = true
	_check(main._begin_chapter_terminal(), "actual CRT session starts")
	await process_frame
	await process_frame
	var content = main._chapter_terminal_session.get_terminal().get_content_root()
	var canvas = content.find_child("NotebookWordCanvas", true, false)
	var body = canvas.get_node("WordPhysicsRoot/WordBody_门")
	canvas._begin_drag(body.position, canvas.global_position + body.position)
	var point: Vector2 = Vector2(canvas.size.x - 40, 120)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = canvas.global_position + point
	canvas._gui_input(motion)
	canvas._end_drag(motion.global_position)
	var release: Vector2 = canvas.get_tile_position("门")
	_check(release.x > 600, "fixture places the word in the CRT's extra width")
	_check(main.game.get_char_canvas_position("门", "zh").is_equal_approx(release), "state saves the actual release point beyond 520px")
	main._render()
	await process_frame
	await process_frame
	canvas = content.find_child("NotebookWordCanvas", true, false)
	_check(absf(canvas.get_tile_position("门").x - release.x) < 2, "rebuilding the same CRT preserves the right-side release point")
	main._end_chapter_terminal(false)
	main.game.chapter1_progress = {}
	main.set_view_state("phone_down")
	main._on_app_pressed("notebook")
	await process_frame
	await process_frame
	canvas = main._ui_root.find_child("NotebookWordCanvas", true, false)
	body = canvas.get_node("WordPhysicsRoot/WordBody_门")
	var tile_size: Vector2 = body.get_meta("tile_size")
	var phone_position: Vector2 = canvas.get_tile_position("门")
	_check(phone_position.x >= 0 and phone_position.x + tile_size.x <= canvas.size.x + 2, "a smaller phone notebook fits the complete word inside its actual bounds")
	main._set_reality_mouse_look(false)
	main.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("notebook canvas reload tests passed")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
