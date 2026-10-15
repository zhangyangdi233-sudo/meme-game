extends SceneTree

const State = preload("res://scripts/meme_game_state.gd")
const Director = preload("res://scripts/progression/basement_loop_director.gd")
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	root.visible = false
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1600, 900)
	var main = load("res://scenes/babel_meme_game.tscn").instantiate()
	main._save_path = "user://test_notebook_phone_flow.dat"
	main._locale.preferences_path = "user://test_notebook_phone_flow.cfg"
	main._locale.save_preferences(80, false, false, "computer")
	root.add_child(main)
	main._resolve_camera_consent(false)
	main._locale.set_locale("zh")
	main._begin_game_session(_state(), {}, false)
	await _frames()
	var actor = main._chapter_actor("chapter1_terminal")
	main._reality_player.global_position = actor.global_position + Vector3(0, -actor.global_position.y, 0.4)
	main._chapter_world_ready = true
	_check(main._begin_chapter_terminal(), "real CRT session starts")
	await _frames()
	main._on_pickup_unit_meta("门", "floor_13")
	main._on_pickup_unit_meta("开", "floor_13")
	main._pickup_flight_layer.finish_all_immediately()
	_check(main.game.is_social_char_collected("门", "zh"), "CRT click collects into shared state")
	main._on_chapter_terminal_app_pressed("notebook")
	await _frames()
	var crt_publisher := main._app_windows.social.find_child("ComposerAnswerPanel", true, false) as Control
	_check(crt_publisher != null, "CRT keeps its alternate publisher available")
	if crt_publisher != null:
		main._on_canvas_tile_dropped_outside("门", crt_publisher.get_global_rect().get_center())
		_check(main.game.get_free_sentence_text("zh") == "门", "CRT cross-pane drag remains compatible with the local notebook tray")
		main.game.free_sentence_clear()
	main._end_chapter_terminal(false)
	main.set_view_state("phone_down")
	main._on_app_pressed("notebook")
	await create_timer(0.65).timeout
	var window: Control = main._app_windows.notebook
	_check(window.find_children("*", "ScrollContainer", true, false).is_empty(), "phone notebook never requires a scroll container")
	var answer := window.find_child("ComposerAnswerPanel", true, false) as Control
	_check(answer != null, "selected words have a sentence area inside the notebook")
	var canvas = window.find_child("NotebookWordCanvas", true, false)
	_check(canvas.has_tile("门") and canvas.has_tile("开"), "CRT words remain available on the phone")
	_check(_inside(canvas.get_global_rect(), main._phone_panel.screen.get_global_rect()), "whole physical canvas fits the phone screen")
	canvas.tile_tapped.emit("门")
	await _frames()
	_check(main.game.get_free_sentence_text("zh") == "门", "tapping a physical word composes the sentence")
	var preview = window.find_child("ComposerPreviewLabel", true, false)
	_check(preview != null and preview.text == "门", "selected sentence is visible in notebook without switching app")
	answer = window.find_child("ComposerAnswerPanel", true, false)
	if answer != null:
		answer = window.find_child("ComposerAnswerPanel", true, false)
		main._on_canvas_tile_dropped_outside("开", answer.get_global_rect().get_center())
		await _frames()
		_check(main.game.get_free_sentence_text("zh") == "门开", "physical drag into the local sentence area appends a word")
		var tile = window.find_child("ComposerAnswerTile0", true, false)
		tile._drop_data(Vector2.ZERO, {"kind": "composer_reorder", "id": "1"})
		await _frames()
		_check(main.game.get_free_sentence_text("zh") == "开门", "sentence tile drag reorders in place")
		window.find_child("ComposerAnswerTile0", true, false).pressed.emit()
		await _frames()
		_check(main.game.get_free_sentence_text("zh") == "门", "clicking a sentence tile removes it")
		var submit = window.find_child("NotebookCraftButton", true, false)
		_check(submit.is_visible_in_tree() and not submit.disabled, "publish button stays visible and enabled with a sentence")
		submit.pressed.emit()
		await _frames()
		_check(main.game.published_memes[0].text == "门", "publishing inside notebook creates the shared post")
		var saved_post: Dictionary = main._load_save_payload()
		_check(saved_post.game.state.published_memes[0].text == "门", "publishing persists the post immediately for Continue")
		_check(main.game.active_app_window == "notebook" and window.is_visible_in_tree(), "publishing keeps notebook open")
		var feedback = window.find_child("NotebookPublishFeedback", true, false)
		_check(feedback != null and not feedback.text.is_empty(), "publish result is visible inside notebook")
	# Many selected words must stay accessible without a wheel or overflowing.
	for index in 70:
		var unit := "字%02d" % index
		main.game.collected_char_units.append({"unit": unit, "locale": "zh"})
		main.game.free_sentence_place(unit, "zh")
	main._render()
	await _frames()
	main.set_process(false)
	for viewport in [Vector2(1600, 900), Vector2(640, 720), Vector2(320, 240)]:
		main._phone_panel.configure(true, true, {"social": true, "notebook": true}, viewport, true)
		await create_timer(0.60).timeout
		var screen: Rect2 = main._phone_panel.screen.get_global_rect()
		for node_name in ["NotebookCanvasFrame", "NotebookWordCanvas", "ComposerAnswerPanel", "ComposerPreviewLabel", "NotebookCraftButton"]:
			var control := window.find_child(node_name, true, false) as Control
			_check(control != null and _inside(control.get_global_rect(), screen), "%s stays inside phone at %s" % [node_name, viewport])
		var tray := window.find_child("ComposerAnswerPanel", true, false) as Control
		var full_sentence := window.find_child("ComposerPreviewLabel", true, false) as Label
		if full_sentence != null:
			_check(full_sentence.text == main.game.get_free_sentence_text("zh") and full_sentence.get_line_count() * full_sentence.get_line_height() <= full_sentence.size.y + 1, "full long sentence wraps without clipped lines")
		if tray != null:
			for tile: Control in tray.find_children("ComposerAnswerTile*", "Button", true, false):
				_check(_inside(tile.get_global_rect(), tray.get_global_rect()), "long sentence tile %s fits at %s" % [tile.name, viewport])
	var saved_units: Array = main.game.get_free_sentence_units()
	_check(saved_units.size() == 70, "fixture has a fresh long draft after publishing the earlier sentence")
	_check(main._save_progress(), "shared notebook state saves")
	main.continue_game()
	await _frames()
	_check(main.game.is_social_char_collected("门", "zh") and main.game.is_social_char_collected("开", "zh"), "CRT words survive save and continue")
	_check(main.game.get_free_sentence_units() == saved_units, "unfinished phone sentence survives save and continue (%s -> %s)" % [saved_units.size(), main.game.get_free_sentence_units().size()])
	main._set_reality_mouse_look(false)
	main.free()
	await _frames()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("notebook phone flow tests passed (%d checks)" % checks)
	quit(0 if failures.is_empty() else 1)

func _state():
	var state = State.new()
	state.new_run()
	state.start_chapter1()
	state.notify_chapter1("narration_completed", {"sequence_id": "chapter1_opening"})
	state.notify_chapter1("opening_knock_completed", {"sequence_id": "chapter1_opening"})
	state.notify_chapter1("opening_door_opened")
	state.notify_chapter1("phone_collected", {"round_token": state.chapter1_progress.transition_serial})
	for visit in 3:
		var token: int = state.chapter1_progress.transition_serial
		state.notify_chapter1("entrance_threshold_crossed", {"round_token": token})
		state.notify_chapter1("npc_help_completed", {"round_token": token, "task_id": Director.TASK_IDS[visit], "npc_id": Director.NPC_IDS[visit]})
		if visit < 2:
			state.notify_chapter1("basement_exit_requested", {"round_token": token})
	return state

func _frames() -> void:
	for frame in 4:
		await process_frame

func _inside(inner: Rect2, outer: Rect2) -> bool:
	return inner.position.x >= outer.position.x - 0.75 and inner.position.y >= outer.position.y - 0.75 and inner.end.x <= outer.end.x + 0.75 and inner.end.y <= outer.end.y + 0.75

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
