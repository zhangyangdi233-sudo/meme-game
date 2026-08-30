extends SceneTree
## Social feed echo-comment UI for player-authored sentences (requires main scene adapter).

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const StateScript = preload("res://scripts/meme_game_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _test_ui()
	if _failures.is_empty():
		print("player echo quote UI tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _post_door_sentence(game: RefCounted) -> void:
	game.free_sentence_units = ["门", "可", "以", "打", "开"]
	game.submit_free_sentence("zh")


func _test_ui() -> void:
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	if scene == null:
		_failures.append("echo quote UI test should load the main scene")
		return
	var game_root := scene.instantiate()
	root.add_child(game_root)
	game_root._locale.set_locale("zh")
	game_root.new_game()
	await process_frame

	game_root._open_social_post(0)
	await process_frame
	_assert_true(Harness.find_node_by_name(game_root, "SocialEchoComment") == null, "no echo comment before the player has posted anything")

	_post_door_sentence(game_root.game)
	game_root.game.pollution = 10
	game_root._open_social_post(0)
	await process_frame
	var echo_text := Harness.find_node_by_name(game_root, "SocialEchoCommentText") as Label
	_assert_true(echo_text != null, "after posting, a stranger quotes the player")
	if echo_text != null:
		_assert_eq_text(echo_text.text, "门可以打开", "the first stage quotes the sentence exactly")
	_assert_true(Harness.find_node_by_name(game_root, "SocialEchoCommentMeta") != null, "the echo comment carries an anonymous handle and timestamp")

	game_root.game.pollution = 70
	game_root._open_social_post(0)
	await process_frame
	echo_text = Harness.find_node_by_name(game_root, "SocialEchoCommentText") as Label
	if echo_text != null:
		_assert_true(echo_text.text.contains("有人比你先写过这句"), "high pollution reattributes the player's own sentence")
	game_root.queue_free()
	await process_frame


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq_text(value: String, expected: String, message: String) -> void:
	if value != expected:
		_failures.append("%s (got %s, expected %s)" % [message, value, expected])
