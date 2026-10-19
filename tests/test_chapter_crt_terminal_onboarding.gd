extends SceneTree
## No signal/callback shortcut: all lesson actions travel through the real
## camera -> authored CRT triangle -> SubViewport -> original app callbacks.

const State = preload("res://scripts/meme_game_state.gd")
const ExistingFlow = preload("res://tests/test_chapter_terminal_flow.gd")
const TutorialState = preload("res://scripts/tutorial/chapter_crt_tutorial_state.gd")
const DEFAULT_OUTPUT := "res://artifacts/crt-onboarding-20261019"
var output := DEFAULT_OUTPUT
var main: Node
var viewport: SubViewport
var failures: Array[String] = []
var checks := 0
var locale := "zh"

func _init() -> void:
	root.visible = false
	# This native capture intentionally has no foreground Window. Emulate the
	# host's focus state while all CRT actions still use its real input route.
	process_frame.connect(func():
		if is_instance_valid(main):
			main._application_focused = true
	)
	_run.call_deferred()

func _run() -> void:
	if not OS.get_environment("CRT_TEST_OUTPUT").is_empty():
		output = OS.get_environment("CRT_TEST_OUTPUT")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	if OS.get_environment("CRT_TEST_LOCALE") in ["en", "ja"]:
		locale = OS.get_environment("CRT_TEST_LOCALE")
	var units := TutorialState.teaching_units(locale)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	main = load("res://scenes/babel_meme_game.tscn").instantiate()
	main._hand_tracking_receiver = ExistingFlow.FakeReceiver.new()
	main._save_path = "user://crt-onboarding-test.dat"
	main._locale.preferences_path = "user://crt-onboarding-preferences.cfg"
	viewport.add_child(main)
	main._resolve_camera_consent(false)
	main._locale.set_locale(locale)
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
	_check(main._chapter_world_ready, "actual first-basement world is ready")
	main._reality_player.position = Vector3(-2.5, 1.45, 0.3)
	main._reality_player.velocity = Vector3.ZERO
	main._animate_world(0.016)
	main._update_crt_focus_tutorial(0.016)
	main._reality_player.position = Vector3(-2.5, 1.32, 0.6)
	main._animate_world(0.016)
	main._update_crt_focus_tutorial(0.016)
	_check(main._crt_focus_tutorial_active(), "real main update starts the stair focus cinematic")
	await create_timer(0.95).timeout
	await _frames(3)
	await _capture_focus("stair-01-black-crt.png")
	var advance := InputEventMouseButton.new()
	advance.button_index = MOUSE_BUTTON_LEFT
	advance.pressed = true
	for line in 7:
		main._input(advance)
		await _frames(2)
	await create_timer(0.75).timeout
	_check(not main._crt_focus_tutorial_active() and main.game.chapter1_progress.crt_tutorial.focus_done, "seven real main narration inputs finish and release the view")
	await _capture_focus("stair-02-restored.png")
	var actor: Area3D
	for candidate in main._reality_floor.get_interactable_actors():
		if candidate.get_meta("actor_type", "") == "chapter1_terminal":
			actor = candidate
	_check(actor != null, "authored CRT has its genuine interaction actor")
	if actor == null:
		await _finish()
		return
	main._reality_player.global_position = actor.global_position + Vector3(0, 0.05, 0.3)
	main._reality_player.velocity = Vector3.ZERO
	main._reality_last_safe_position = main._reality_player.position
	main._animate_world(1.0)
	main._refresh_nearby_reality_actor()
	var interact := InputEventKey.new()
	interact.keycode = KEY_F
	interact.physical_keycode = KEY_F
	interact.pressed = true
	main._unhandled_input(interact)
	await create_timer(0.95).timeout
	await _frames(6)
	_check(main._chapter_terminal_active(), "real F input enters physical CRT")
	if not main._chapter_terminal_active():
		await _finish()
		return
	_check(_session().tutorial_active(), "first CRT visit starts its guarded lesson")
	await _check_guide_layout("post")
	await _capture("terminal-01-single-post.png")
	main._open_social_post(0)
	_check(not main._social_detail_open, "direct callback cannot bypass the real input transaction")
	await _click_control("SocialPostPoster1")
	_check(not main._social_detail_open, "gray post cannot be opened through real screen input")
	await _click_control("SocialPostPoster0")
	_check(main._social_detail_open and _phase() == "collect", "only highlighted post opens and advances the lesson")
	await _check_guide_layout("collect")
	await _capture("terminal-02-three-words.png")
	for unit in units:
		var picked := await _pick(unit)
		_check(picked and main.game.is_social_char_collected(unit, locale), "real text hover/click picks %s" % unit)
		if not picked:
			await _capture("terminal-failed-pick.png")
			await _finish()
			return
		if unit == units[0]:
			var tab := InputEventKey.new()
			tab.keycode = KEY_TAB
			tab.pressed = true
			main._input(tab)
			await create_timer(0.75).timeout
			_check(not main._chapter_terminal_active() and _phase() == "collect", "Tab cancels presentation without discarding partial teaching progress")
			_check(main._save_progress() and main.continue_game(), "partial lesson survives the ordinary save and continue loader")
			await _frames(5)
			main._set_reality_mouse_look(false)
			main._refresh_nearby_reality_actor()
			main._unhandled_input(interact)
			await create_timer(0.95).timeout
			await _frames(6)
			_check(main._chapter_terminal_active() and _phase() == "collect" and main.game.chapter1_progress.crt_tutorial.collected == [units[0]], "re-entering CRT resumes the same post and remaining two units")
	_check(_phase() == "compose", "all three real pickups unlock only drag composition")
	await _check_guide_layout("compose")
	await _capture("terminal-03-drag-words.png")
	var body := _word_body(units[0])
	_check(body != null, "shared notebook owns a physics tile for the first picked character")
	if body == null:
		await _finish()
		return
	_motion(body.global_position)
	_button(body.global_position, true)
	var cancel_key := InputEventKey.new()
	cancel_key.keycode = KEY_TAB
	cancel_key.pressed = true
	main._input(cancel_key)
	await create_timer(0.75).timeout
	_check(not main._chapter_terminal_active() and main.game.get_free_sentence_units().is_empty() and _phase() == "compose", "Tab while holding a word cannot synthesize a placement or lose collected progress")
	main._refresh_nearby_reality_actor()
	main._unhandled_input(interact)
	await create_timer(0.95).timeout
	await _frames(6)
	_check(main._chapter_terminal_active() and _phase() == "compose", "cancelled drag resumes at composition without a held input")
	body = _word_body(units[0])
	await _click(body.global_position)
	_check(main.game.get_free_sentence_units().is_empty(), "clicking a word cannot substitute for the required drag")
	for unit in units:
		body = _word_body(unit)
		if body == null:
			_check(false, "all picked words retain real physics bodies")
			break
		var source := body.global_position
		var target := _content().find_child("ComposerAnswerPanel", true, false) as Control
		await _drag(source, target.get_global_rect().get_center())
		_check(unit in main.game.get_free_sentence_units(), "physical drag delivers %s into the real sentence" % unit)
	_check(_phase() == "publish", "three genuine drags unlock Publish")
	await _check_guide_layout("publish")
	await _capture("terminal-04-publish.png")
	var before: int = main.game.published_memes.size()
	await _click_control("NotebookCraftButton")
	_check(main.game.published_memes.size() == before + 1 and _phase() == "complete", "real publish click creates exactly one shared publication and completes lesson")
	var publication: Dictionary = main.game.published_memes[0]
	_check(publication.get("text") == {"zh": "门打开", "en": "door can open", "ja": "ドアはひらく"}[locale], "tutorial publishes a natural positive sentence in the selected language")
	_check(publication.get("tier") == "rule" and publication.get("rule_key") == "door|can_open" and not publication.get("negated", true), "all three locales publish the same positive door-opening rule")
	_check(publication.get("units") == units and publication.get("content_locale") == locale, "publication preserves the three genuinely collected and dragged locale units")
	_check(publication.get("chapter_task_id") == "basement_help_01" and publication.get("chapter_round_token") == main.game.chapter1_progress.transition_serial, "tutorial publication belongs to this first-basement task and current visit token")
	_check(main.game.has_current_chapter_submission(), "tutorial publication satisfies the genuine NPC current-task submission gate")
	_check(not _session().tutorial_active() and _content().find_child("CRTTutorialOverlay", true, false) == null, "completion removes input shield and restores normal content")
	await create_timer(0.3).timeout
	await _capture("terminal-05-publication-feedback.png", 0.0)
	await create_timer(2.4).timeout
	_check(not main._social_detail_open and main._social_screen == "home" and main._social_channel == "discover", "publication feedback returns to the discover feed automatically")
	var rule_text := _content().find_child("SocialRuleText-1", true, false) as Control
	_check(rule_text != null and rule_text.is_visible_in_tree(), "completed lesson leaves the current rule visible in the feed")
	await _capture("terminal-06-current-rule.png")
	await _click_control("SocialPostPoster1")
	_check(main._social_detail_post_index == 1, "other posts work normally after teaching finishes")
	await _capture("terminal-07-unlocked.png")
	await _finish()

func _phase() -> String:
	return str(main.game.chapter1_progress.get("crt_tutorial", {}).get("lesson_phase", "post"))

func _session() -> Node:
	return main._chapter_terminal_session

func _content() -> Control:
	return _session().get_terminal().get_content_root()

func _word_body(unit: String) -> RigidBody2D:
	for candidate in _content().find_children("*", "RigidBody2D", true, false):
		if str(candidate.get_meta("word_unit", "")) == unit:
			return candidate
	return null

func _check_guide_layout(phase: String) -> void:
	await _frames(3)
	var overlay := _content().find_child("CRTTutorialOverlay", true, false) as Control
	var label := _content().find_child("CRTTutorialInstruction", true, false) as Label
	_check(overlay != null and label != null, "%s has its visible instruction label" % phase)
	if overlay == null or label == null:
		return
	var painted := label.get_global_rect().grow(label.get_theme_constant("outline_size"))
	var local_painted := Rect2(painted.position - overlay.global_position, painted.size)
	var clear := true
	for hole: Rect2 in overlay.get("holes"):
		clear = clear and not local_painted.intersects(hole.grow(4.0))
	_check(clear, "%s instruction including its outline stays outside every interaction hole" % phase)
	_check(_content().get_global_rect().encloses(painted), "%s instruction fits entirely inside the CRT" % phase)
	_check(label.get_minimum_size().y <= label.size.y and label.get_visible_line_count() == label.get_line_count(), "%s translation is fully visible without clipping" % phase)
	_check(label.get_theme_font_size("font_size") >= 48, "%s instruction remains large and readable" % phase)
	var clear_of_body := true
	var covered_text: Array[String] = []
	for body: Label in _content().find_children("*", "Label", true, false):
		if body == label or not body.is_visible_in_tree() or body.text.strip_edges().is_empty():
			continue
		# The opaque post-detail window covers the feed beneath it.
		var social_app: Control = main._app_windows.social
		if main._social_detail_open and social_app.is_ancestor_of(body):
			continue
		var text_rect := body.get_global_rect()
		var text_height := body.get_minimum_size().y
		if body.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
			text_rect.position.y += (text_rect.size.y - text_height) * 0.5
		elif body.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
			text_rect.position.y += text_rect.size.y - text_height
		text_rect.size.y = text_height
		var ancestor := body.get_parent()
		while ancestor != null and ancestor != _content():
			if ancestor is Control and ancestor.clip_contents:
				text_rect = text_rect.intersection(ancestor.get_global_rect())
			ancestor = ancestor.get_parent()
		if text_rect.has_area() and painted.intersects(text_rect.grow(4.0)):
			clear_of_body = false
			covered_text.append("%s %s" % [body.name, text_rect])
	_check(clear_of_body, "%s instruction avoids app text, including dimmed labels: %s" % [phase, covered_text])
	var correct_side := painted.end.x < 792.0 if phase == "compose" else painted.position.x > 808.0
	_check(correct_side, "%s instruction uses the inactive side instead of covering the work area" % phase)
	if phase == "publish":
		var publish := _content().find_child("NotebookCraftButton", true, false) as Control
		_check(painted.position.y > publish.get_global_rect().end.y + 80.0, "publish instruction sits in the lower right dark area below the button")
	var report := {"phase": phase, "locale": locale, "text": label.text, "bounds_with_outline": str(painted), "font_size": label.get_theme_font_size("font_size"), "line_count": label.get_line_count(), "covered_text": covered_text}
	var report_file := FileAccess.open(output.path_join(locale + "-" + phase + "-layout.json"), FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(JSON.stringify(report, "\t"))

func _pick(unit: String) -> bool:
	for rich: RichTextLabel in _content().find_children("*", "RichTextLabel", true, false):
		if not ("[url=%s]" % unit) in rich.text:
			continue
		var parent := rich.get_parent()
		while parent != _content() and parent != null:
			if parent is ScrollContainer:
				parent.ensure_control_visible(rich)
				break
			parent = parent.get_parent()
		await _frames(4)
		var hovered := [""]
		rich.meta_hover_started.connect(func(meta): hovered[0] = str(meta))
		rich.meta_hover_ended.connect(func(_meta): hovered[0] = "")
		var bounds := rich.get_global_rect().intersection(Rect2(16, 90, 776, 1070))
		for y in range(int(bounds.position.y) + 3, int(bounds.end.y), 6):
			for x in range(int(bounds.position.x) + 3, int(bounds.end.x), 6):
				_motion(Vector2(x, y))
				if hovered[0] == unit:
					await _click(Vector2(x, y))
					return unit in main.game.chapter1_progress.crt_tutorial.collected
	return false

func _click_control(node_name: String) -> void:
	var control := _content().find_child(node_name, true, false) as Control
	_check(control != null, "real control exists: %s" % node_name)
	if control != null:
		await _click(control.get_global_rect().get_center())

func _click(pixel: Vector2) -> void:
	_motion(pixel)
	_button(pixel, true)
	_button(pixel, false)
	await _frames(5)

func _drag(from: Vector2, to: Vector2) -> void:
	_motion(from)
	_button(from, true)
	for step in range(1, 10):
		_motion(from.lerp(to, float(step) / 9.0), true)
		await _frames(1)
	_button(to, false)
	await _frames(8)

func _motion(pixel: Vector2, held: bool = false) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _window_point(pixel)
	motion.global_position = motion.position
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	_session().route_input(motion, main._camera)

func _button(pixel: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = _window_point(pixel)
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.pressed = down
	_session().route_input(event, main._camera)

func _window_point(pixel: Vector2) -> Vector2:
	var uv := pixel / Vector2(1600, 1200)
	var terminal: Node = _session().get_terminal()
	var mesh: MeshInstance3D = terminal.get("_mesh")
	for triangle: Dictionary in terminal.get("_triangles"):
		var edge_b: Vector2 = triangle.uv_b - triangle.uv_a
		var edge_c: Vector2 = triangle.uv_c - triangle.uv_a
		var offset: Vector2 = uv - triangle.uv_a
		var determinant := edge_b.cross(edge_c)
		var u := offset.cross(edge_c) / determinant
		var v := edge_b.cross(offset) / determinant
		if u >= -0.00001 and v >= -0.00001 and u + v <= 1.00001:
			var point: Vector3 = triangle.a + (triangle.b - triangle.a) * u + (triangle.c - triangle.a) * v
			return main._camera.unproject_position(mesh.to_global(point))
	return Vector2(-100, -100)

func _capture(filename: String, settle_delay: float = 0.6) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if settle_delay > 0.0:
		await create_timer(settle_delay).timeout
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join(locale + "-" + filename))
	_session().get_terminal().get_display_viewport().get_texture().get_image().save_png(output.path_join(locale + "-" + filename.replace(".png", "-screen.png")))

func _capture_focus(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join(locale + "-" + filename))

func _frames(count: int) -> void:
	for index in count:
		await process_frame

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _finish() -> void:
	if main._chapter_terminal_active():
		var leave := InputEventKey.new()
		leave.keycode = KEY_TAB
		leave.pressed = true
		main._input(leave)
		await create_timer(0.75).timeout
		await _frames(3)
	main.free()
	viewport.queue_free()
	await _frames(3)
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("CRT terminal onboarding passed (%d checks; physical CRT UV clicks, text links, three physics drags and publish)" % checks)
	quit(0 if failures.is_empty() else 1)
