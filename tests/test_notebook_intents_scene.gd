extends SceneTree
## Routing smoke: in the main scene, the host hands notebook intents to the notebook handler and presents the
## result. What each intent does is covered by test_notebook_intent_handler.

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
		game_root._skip_chapter_one()
		await process_frame
		_test_bank_tap_and_craft_intents_build_and_post_a_sentence(game_root)
		game_root.queue_free()
		await process_frame

	if _failures.is_empty():
		print("notebook intents scene tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_bank_tap_and_craft_intents_build_and_post_a_sentence(game_root: Node) -> void:
	game_root.game.pick_social_char("floor_13", "门", "zh")
	game_root.game.pick_social_char("floor_13", "开", "zh")
	GameEventBus.raise(UiIntentsScript.NOTEBOOK_COMPOSER_BANK_TAPPED, {UiIntentsScript.KEY_UNIT: "门"})
	GameEventBus.raise(UiIntentsScript.NOTEBOOK_COMPOSER_BANK_TAPPED, {UiIntentsScript.KEY_UNIT: "开"})
	_assert_eq(game_root.game.get_free_sentence_text("zh"), "门开", "the host should route bank taps to the notebook handler")
	GameEventBus.raise(UiIntentsScript.NOTEBOOK_CRAFT_REQUESTED)
	_assert_true(game_root.game.get_free_sentence_units().is_empty(), "the host should route a craft and present its submit")


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
