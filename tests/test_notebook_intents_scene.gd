extends SceneTree
## In the main scene, the host's handler routes the notebook's intents to the state and the language material.

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
		_test_bank_tap_and_craft_intents_build_and_post_a_sentence(game_root)
		_test_committed_positions_are_written_to_the_state(game_root)
		_test_fusion_intents_fill_the_slots_and_fuse(game_root)
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
	_assert_eq(game_root.game.get_free_sentence_text("zh"), "门开", "bank tap intents should build the sentence in order")
	GameEventBus.raise(UiIntentsScript.NOTEBOOK_CRAFT_REQUESTED)
	_assert_true(game_root.game.get_free_sentence_units().is_empty(), "a craft intent should post the sentence")


func _test_committed_positions_are_written_to_the_state(game_root: Node) -> void:
	GameEventBus.raise(UiIntentsScript.NOTEBOOK_CANVAS_POSITIONS_COMMITTED, {UiIntentsScript.KEY_TILE_POSITIONS: {"门": Vector2(42.0, 24.0)}})
	_assert_eq(game_root.game.get_char_canvas_position("门", "zh"), Vector2(42.0, 24.0), "a commit intent should write the resting position")


func _test_fusion_intents_fill_the_slots_and_fuse(game_root: Node) -> void:
	game_root.game.completed_memes = [
		{"id": "meme-left", "title": "左梗", "text": "左", "tags": [], "rarity": 1, "pollution_bias": 1, "fusion_level": 0, "unit_count": 1},
		{"id": "meme-right", "title": "右梗", "text": "右", "tags": [], "rarity": 1, "pollution_bias": 1, "fusion_level": 0, "unit_count": 1},
	]
	game_root.game.fusion_slots = {}
	GameEventBus.raise(UiIntentsScript.NOTEBOOK_FUSION_MEME_DROPPED, {UiIntentsScript.KEY_DATA: {"kind": "meme", "id": "meme-left"}, UiIntentsScript.KEY_SLOT_ID: "left"})
	_assert_eq(str(game_root.game.fusion_slots.get("left", "")), "meme-left", "a drop intent should put the meme in the slot")
	GameEventBus.raise(UiIntentsScript.NOTEBOOK_FUSION_SLOT_PRESSED, {UiIntentsScript.KEY_SLOT_ID: "right"})
	_assert_true(not game_root.game.fusion_slots.has("right"), "a slot press intent should refuse the meme already in the other slot")
	GameEventBus.raise(UiIntentsScript.NOTEBOOK_FUSION_MEME_DROPPED, {UiIntentsScript.KEY_DATA: {"kind": "meme", "id": "meme-right"}, UiIntentsScript.KEY_SLOT_ID: "right"})
	GameEventBus.raise(UiIntentsScript.NOTEBOOK_FUSION_REQUESTED)
	_assert_eq(game_root.game.completed_memes.size(), 3, "a fusion intent should fuse the two memes")


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
