extends SceneTree
## A run that chose Japanese from the start reads Japanese where the player posts and where they are prompted (planner,
## 2026-11-20: "I chose Japanese but other languages show up from time to time"). The texts that fell back to their
## Chinese source were the ones nobody localized after a repaint: the notebook's post button once a word was put into
## the sentence, the terminal's own copies of the notebook and the feed, and the prompt under the crosshair. A language
## change in settings reaches the terminal's feed too.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const TEST_SAVE_PATH := "user://test_japanese_run_scene_save.dat"
const TEST_PREFERENCES_PATH := "user://test_japanese_run_scene_preferences.cfg"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	root.size = Vector2i(1600, 900)
	_remove_files()
	await _run()
	_remove_files()
	if _failures.is_empty():
		print("japanese run scene tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	var game_root = scene.instantiate()
	game_root._save_path = TEST_SAVE_PATH
	root.add_child(game_root)
	await process_frame
	game_root._locale.preferences_path = TEST_PREFERENCES_PATH
	game_root._on_language_selected("ja")
	await _enter_the_basement(game_root)
	await _test_the_prompt_under_the_crosshair_is_japanese(game_root)
	await _test_the_terminals_notebook_and_feed_are_japanese(game_root)
	await _test_the_phones_post_button_stays_japanese_with_a_word_in_the_sentence(game_root)
	await _test_a_language_change_reaches_the_terminals_feed(game_root)
	game_root.queue_free()
	await process_frame


## A new run read to the end, knocked, and saved behind the white door continues in basement round one.
func _enter_the_basement(game_root) -> void:
	game_root.new_game()
	await process_frame
	while game_root.game.advance_opening_narration():
		pass
	game_root.game.complete_opening_knock()
	game_root.game.open_opening_door()
	_assert_true(game_root._save_progress(), "setup should save the run in the basement")
	game_root.show_main_menu()
	await process_frame
	_assert_true(game_root.continue_game(), "setup should continue the basement save")
	await process_frame
	await process_frame
	_assert_true(Harness.find_node_by_name(game_root, "BasementRoom") != null, "setup should stand in the basement")


func _test_the_prompt_under_the_crosshair_is_japanese(game_root) -> void:
	await _stand_at_the_crt(game_root)
	var prompt := Harness.find_node_by_name(game_root, "WorldPrompt") as Label
	_assert_eq(prompt.text, "F  端末を使う", "walking up to the CRT should prompt in Japanese")


func _test_the_terminals_notebook_and_feed_are_japanese(game_root) -> void:
	_push_key(game_root, KEY_F)
	await process_frame
	await process_frame
	var display := Harness.find_node_by_name(game_root, "CrtTerminalDisplay")
	_assert_true(display != null, "the terminal should be entered")
	if display == null:
		return
	_assert_eq(_text(display, "SocialNavHome"), "ホーム", "the terminal's feed should word its navigation in Japanese")
	_assert_eq(_text(display, "SocialNavCreate"), "投稿", "the terminal's feed should word its post tab in Japanese")
	_assert_eq(_text(display, "SocialChannelTabdiscover"), "おすすめ", "the terminal's feed should word its channels in Japanese")
	_assert_eq(_text(display, "SocialPostFollowButton0"), "フォロー", "the terminal's cards should word their follow button in Japanese")
	var terminal_social := Harness.find_node_by_name(game_root, "TerminalSocialFeedPanel") as SocialFeedPanel
	terminal_social.open_post(0)
	await process_frame
	_assert_eq(_text(display, "SocialDetailFollowButton"), "フォロー", "a post opened on the terminal should word its follow button in Japanese")
	(Harness.find_node_by_name(display, "TerminalAppNotebook") as Button).pressed.emit()
	await process_frame
	await process_frame
	_assert_eq(_text(display, "NotebookCraftButton"), "投稿", "the terminal's notebook should word its post button in Japanese")
	# A word put into the sentence repaints the notebook by itself.
	game_root.game.free_sentence_units = ["ドア"]
	await process_frame
	await process_frame
	_assert_eq(_text(display, "NotebookCraftButton"), "投稿", "the terminal's post button should stay Japanese once a word is in the sentence")
	game_root.game.free_sentence_units = []
	await process_frame
	_push_key(game_root, KEY_TAB)
	await process_frame


func _test_the_phones_post_button_stays_japanese_with_a_word_in_the_sentence(game_root) -> void:
	game_root.set_view_state("phone_down")
	game_root.game.open_app_window("notebook")
	game_root._render()
	await process_frame
	await process_frame
	var button := _phone_node(game_root, "NotebookCraftButton") as Button
	_assert_true(button != null and button.text == "投稿", "the phone's notebook should word its post button in Japanese")
	game_root.game.free_sentence_units = ["ドア"]
	await process_frame
	await process_frame
	button = _phone_node(game_root, "NotebookCraftButton") as Button
	_assert_true(button != null and button.text == "投稿", "the phone's post button should stay Japanese once a word is in the sentence: %s" % (button.text if button != null else "none"))
	game_root.game.free_sentence_units = []
	game_root.set_view_state("npc_up")
	await process_frame


func _test_a_language_change_reaches_the_terminals_feed(game_root) -> void:
	GameEventBus.raise(UiIntentsScript.LANGUAGE_SELECTED, {UiIntentsScript.KEY_LOCALE: "zh"})
	await process_frame
	await _stand_at_the_crt(game_root)
	_assert_eq((Harness.find_node_by_name(game_root, "WorldPrompt") as Label).text, "F  使用终端", "the prompt should follow the language back")
	_push_key(game_root, KEY_F)
	await process_frame
	await process_frame
	var display := Harness.find_node_by_name(game_root, "CrtTerminalDisplay")
	(Harness.find_node_by_name(display, "TerminalAppSocial") as Button).pressed.emit()
	await process_frame
	await process_frame
	_assert_eq(_text(display, "SocialNavHome"), "首页", "the terminal's feed should be drawn again in the language chosen in settings")
	_push_key(game_root, KEY_TAB)
	await process_frame


func _stand_at_the_crt(game_root) -> void:
	var adapter = game_root._reality_scene_adapter
	var reach: Vector3 = adapter.chapter_terminal_position()
	# Away first, so coming into reach changes the nearby target and sets the prompt.
	adapter.player.position = Vector3(-1.0, 0.02, 1.5)
	adapter.player.velocity = Vector3.ZERO
	for frame in 6:
		await physics_frame
	adapter.player.position = reach + Vector3(0.0, 0.02, 0.0)
	adapter.player.velocity = Vector3.ZERO
	for frame in 10:
		await physics_frame
	await process_frame


func _text(under: Node, node_name: String) -> String:
	var node := Harness.find_node_by_name(under, node_name)
	return str(node.get("text")) if node != null else "<no %s>" % node_name


## The node of that name outside the terminal's display: the phone's copy.
func _phone_node(game_root, node_name: String) -> Node:
	var display := Harness.find_node_by_name(game_root, "CrtTerminalDisplay")
	for node in game_root.find_children(node_name, "", true, false):
		if display == null or not display.is_ancestor_of(node):
			return node
	return null


func _push_key(game_root, keycode: Key) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = keycode
		key.physical_keycode = keycode
		key.pressed = pressed
		game_root.get_viewport().push_input(key, true)


func _remove_files() -> void:
	for path in [TEST_SAVE_PATH, TEST_PREFERENCES_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
