extends SceneTree
## Surface refresh isolation: Session mode owns visibility; ending chrome has its own path; feed likes do not re-run ending or Reality HUD.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const SocialFeedContentScript = preload("res://scripts/game/social_feed_content.gd")

const HUD_SENTINEL := "HUD_SENTINEL_SURFACE_REFRESH"
const ENDING_SENTINEL := "ENDING_SENTINEL_SURFACE_REFRESH"
const WORLD_PROMPT_SENTINEL := "WORLD_PROMPT_SENTINEL_SURFACE_REFRESH"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	root.size = Vector2i(1600, 900)
	await _test_session_mode_hides_play_chrome_on_ending()
	await _test_like_does_not_rerun_ending_or_hud()
	await _test_ending_language_refreshes_ending_not_hud()
	if _failures.is_empty():
		print("surface refresh UI tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_session_mode_hides_play_chrome_on_ending() -> void:
	var game_root := await _boot_gameplay()
	if game_root == null:
		return

	var toggle := Harness.find_node_by_name(game_root, "PhoneViewToggleButton") as Button
	_assert_eq(game_root.session_mode(), "gameplay", "skipped prologue should be gameplay")
	_assert_true(toggle != null and toggle.visible, "gameplay should show the phone view toggle")

	_unlock_ending(game_root)
	await process_frame

	_assert_eq(game_root.session_mode(), "ending", "unlocking the ending should set Session mode to ending")
	var ending := Harness.find_node_by_name(game_root, "EndingScreen") as Control
	_assert_true(ending != null and ending.visible, "ending Session mode should show ending chrome")
	toggle = Harness.find_node_by_name(game_root, "PhoneViewToggleButton") as Button
	_assert_true(toggle != null, "ending chrome should hide play chrome, not destroy it")
	if toggle != null:
		_assert_true(not toggle.visible, "ending Session mode should hide the phone view toggle")

	game_root.queue_free()
	await process_frame


func _test_like_does_not_rerun_ending_or_hud() -> void:
	var game_root := await _boot_gameplay()
	if game_root == null:
		return

	var hud: Variant = _stamp_hud(game_root)
	var prompt: Variant = _stamp_world_prompt(game_root)
	_unlock_ending(game_root)
	await process_frame

	var body := Harness.find_node_by_name(game_root, "EndingBody") as Label
	_assert_true(body != null, "unlocking the ending should paint the ending screen")
	if body != null:
		body.text = ENDING_SENTINEL
	_assert_hud_untouched(hud, "entering the ending")
	_assert_prompt_untouched(prompt, "entering the ending")

	var post: Dictionary = SocialFeedContentScript.post_for_index(0, game_root._social_content_deps())
	game_root._on_social_like_pressed(str(post.get("id", "")))
	await process_frame

	body = Harness.find_node_by_name(game_root, "EndingBody") as Label
	_assert_true(body != null and is_instance_valid(body), "liking a post should leave the ending screen in place")
	if body != null and is_instance_valid(body):
		_assert_eq(body.text, ENDING_SENTINEL, "liking a post should not re-run the ending screen")
	_assert_hud_untouched(hud, "liking a post during the ending")
	_assert_prompt_untouched(prompt, "liking a post during the ending")

	game_root.queue_free()
	await process_frame


func _test_ending_language_refreshes_ending_not_hud() -> void:
	var game_root := await _boot_gameplay()
	if game_root == null:
		return

	var hud: Variant = _stamp_hud(game_root)
	var prompt: Variant = _stamp_world_prompt(game_root)
	_unlock_ending(game_root)
	await process_frame

	var choices: Array = game_root.game.get_ending_language_choices("zh")
	_assert_true(not choices.is_empty(), "ending chrome should expose a language choice")
	var choice_id := str((choices[0] as Dictionary).get("id", ""))
	_assert_true(not choice_id.is_empty(), "ending language choice should have an id")
	game_root._on_ending_language_selected(choice_id)
	await process_frame

	var result := Harness.find_node_by_name(game_root, "EndingLanguageResult") as Label
	_assert_true(result != null and result.visible, "choosing an ending language should refresh ending chrome")
	_assert_hud_untouched(hud, "choosing an ending language")
	_assert_prompt_untouched(prompt, "choosing an ending language")

	game_root.queue_free()
	await process_frame


func _boot_gameplay() -> Node:
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "surface refresh should load the main scene")
	if scene == null:
		return null
	var game_root := scene.instantiate()
	root.add_child(game_root)
	game_root._locale.set_locale("zh")
	game_root.new_game()
	game_root._skip_prologue()
	await process_frame
	return game_root


func _unlock_ending(game_root: Node) -> void:
	game_root.game.ending_unlocked = true
	game_root._request_ending_if_unlocked()
	game_root._refresh_ending()


func _stamp_hud(game_root: Node) -> Variant:
	var hud := game_root._hud_actions_label_ref() as Label
	_assert_true(hud != null, "Reality HUD should expose an actions label")
	if hud != null:
		hud.text = HUD_SENTINEL
	return hud


func _stamp_world_prompt(game_root: Node) -> Variant:
	var prompt := Harness.find_node_by_name(game_root, "WorldPrompt") as Label
	_assert_true(prompt != null, "Reality HUD should expose a world prompt")
	if prompt != null:
		prompt.text = WORLD_PROMPT_SENTINEL
	return prompt


func _assert_hud_untouched(hud: Variant, action: String) -> void:
	_assert_true(
		hud is Label and is_instance_valid(hud),
		"%s should leave the Reality HUD node in place" % action
	)
	if hud is Label and is_instance_valid(hud):
		_assert_eq((hud as Label).text, HUD_SENTINEL, "%s should not re-run Reality HUD content" % action)


func _assert_prompt_untouched(prompt: Variant, action: String) -> void:
	_assert_true(
		prompt is Label and is_instance_valid(prompt),
		"%s should leave the world prompt in place" % action
	)
	if prompt is Label and is_instance_valid(prompt):
		_assert_eq((prompt as Label).text, WORLD_PROMPT_SENTINEL, "%s should not re-run Reality HUD content" % action)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(value: Variant, expected: Variant, message: String) -> void:
	if value != expected:
		_failures.append("%s (got %s, expected %s)" % [message, str(value), str(expected)])
