extends SceneTree
## In the main scene, the host's handler routes the social feed's intents to the state and the language material.

const UiIntentsScript = preload("res://scripts/ui_intents.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	root.size = Vector2i(1600, 900)
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "the main scene should load")
	if scene != null:
		var game_root := scene.instantiate()
		root.add_child(game_root)
		game_root._locale.set_locale("zh")
		game_root.new_game()
		game_root._skip_prologue()
		await process_frame
		_test_like_and_follow_write_the_state(game_root)
		_test_pickup_and_composer_intents_build_and_post_a_sentence(game_root)
		_test_close_intent_closes_the_social_window(game_root)
		game_root.queue_free()
		await process_frame

	if _failures.is_empty():
		print("social intents scene tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_like_and_follow_write_the_state(game_root: Node) -> void:
	GameEventBus.raise(UiIntentsScript.SOCIAL_LIKE_PRESSED, {UiIntentsScript.KEY_POST_ID: "floor_13"})
	_assert_true(game_root.game.is_social_post_liked("floor_13"), "a like intent should like the post")
	GameEventBus.raise(UiIntentsScript.SOCIAL_LIKE_PRESSED, {UiIntentsScript.KEY_POST_ID: "floor_13"})
	_assert_true(not game_root.game.is_social_post_liked("floor_13"), "a second like intent should unlike it")
	GameEventBus.raise(UiIntentsScript.SOCIAL_FOLLOW_PRESSED, {UiIntentsScript.KEY_AUTHOR_ID: "floor_13"})
	_assert_true(game_root.game.is_social_following("floor_13"), "a follow intent should follow the author")


func _test_pickup_and_composer_intents_build_and_post_a_sentence(game_root: Node) -> void:
	GameEventBus.raise(UiIntentsScript.SOCIAL_PICKUP_UNIT_CLICKED, {UiIntentsScript.KEY_META: "门", UiIntentsScript.KEY_POST_ID: "floor_13"})
	GameEventBus.raise(UiIntentsScript.SOCIAL_PICKUP_UNIT_CLICKED, {UiIntentsScript.KEY_META: "开", UiIntentsScript.KEY_POST_ID: "floor_13"})
	_assert_true(game_root.game.is_social_char_collected("门", "zh"), "a pickup intent should collect the word")
	GameEventBus.raise(UiIntentsScript.SOCIAL_COMPOSER_AREA_DROPPED, {UiIntentsScript.KEY_DATA: {"kind": "composer_unit", "id": "门"}})
	_assert_eq(game_root.game.get_free_sentence_text("zh"), "门", "an area drop intent should place the dragged word")
	GameEventBus.raise(UiIntentsScript.SOCIAL_COMPOSER_TILE_DROPPED, {UiIntentsScript.KEY_DATA: {"kind": "composer_unit", "id": "开"}, UiIntentsScript.KEY_BEFORE_INDEX: 0})
	_assert_eq(game_root.game.get_free_sentence_text("zh"), "开门", "a tile drop intent should place the word before the tile")
	GameEventBus.raise(UiIntentsScript.SOCIAL_COMPOSER_ANSWER_TAPPED, {UiIntentsScript.KEY_UNIT_INDEX: 0})
	_assert_eq(game_root.game.get_free_sentence_text("zh"), "门", "an answer tap intent should remove that tile")
	GameEventBus.raise(UiIntentsScript.SOCIAL_COMPOSER_SUBMIT_REQUESTED)
	_assert_true(game_root.game.get_free_sentence_units().is_empty(), "a submit intent should post the sentence")


func _test_close_intent_closes_the_social_window(game_root: Node) -> void:
	game_root._on_app_pressed("social")
	_assert_true(game_root.game.is_app_window_open("social"), "the social app should be open before the close intent")
	GameEventBus.raise(UiIntentsScript.SOCIAL_CLOSE_REQUESTED)
	_assert_true(not game_root.game.is_app_window_open("social"), "a close intent should close the social window")


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
