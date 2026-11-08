extends SceneTree

var _failures: Array[String] = []
var _state_script: Script
var _content_script: Script


func _init() -> void:
	_state_script = load("res://scripts/meme_game_state.gd") as Script
	_content_script = load("res://scripts/narrative/language_corruption_content.gd") as Script
	_assert_true(_state_script != null and _content_script != null, "key NPC test dependencies should load")
	if _state_script != null and _content_script != null:
		test_every_floor_has_two_authored_questions()
		test_wrong_answer_does_not_reveal_the_item()
		test_two_correct_answers_reveal_one_reachable_prerequisite()
	if _failures.is_empty():
		print("key NPC prerequisite flow tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_every_floor_has_two_authored_questions() -> void:
	for floor_number in [1, 2, 3]:
		var dialogue: Dictionary = _content_script.get_key_npc_dialogue_for_floor(floor_number)
		var turns: Array = dialogue.get("turns", [])
		_assert_eq(turns.size(), 2, "floor %d key NPC should ask exactly two questions" % floor_number)
		_assert_true(not str(dialogue.get("actor_label", "")).is_empty(), "floor %d key NPC needs a world label" % floor_number)
		_assert_true(not str(dialogue.get("success_line", "")).is_empty(), "floor %d needs an authored clue reveal line" % floor_number)
		for turn: Dictionary in turns:
			var choices: Array = turn.get("choices", [])
			_assert_eq(choices.size(), 3, "each key question should present three intentions")
			var correct_count := 0
			for choice: Dictionary in choices:
				if bool(choice.get("correct", false)):
					correct_count += 1
			_assert_eq(correct_count, 1, "each key question should have one authored correct answer")


func test_wrong_answer_does_not_reveal_the_item() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	game.tower_floor = 1
	var item_id := str(game.get_prerequisite_item_for_floor(1).get("id", ""))
	_assert_true(game.start_typed_reality_conversation("key_npc_1", "key_npc", "护灯人"), "key NPC conversation should start")
	var first_choices: Array = game.get_typed_reality_choices()
	var wrong_id := _choice_id_by_correctness(first_choices, false)
	_finish_typed_turn(game, wrong_id)
	_assert_true(game.continue_typed_reality_conversation(), "a wrong first answer should still allow the second question")
	var second_choices: Array = game.get_typed_reality_choices()
	_finish_typed_turn(game, _choice_id_by_correctness(second_choices, true))
	_assert_true(not game.is_prerequisite_item_revealed(item_id), "one wrong answer must keep the item hidden")
	_assert_true(str(game.conversation_feedback).contains("没有说出地点"), "failed attempt should give clear authored feedback without exposing the clue")


func test_two_correct_answers_reveal_one_reachable_prerequisite() -> void:
	for floor_number in [1, 2, 3]:
		var game: RefCounted = _state_script.new()
		game.new_run()
		game.tower_floor = floor_number
		var item: Dictionary = game.get_prerequisite_item_for_floor(floor_number)
		var item_id := str(item.get("id", ""))
		_assert_true(game.start_typed_reality_conversation("key_npc_%d" % floor_number, "key_npc", "关键住户"), "floor %d key NPC conversation should start" % floor_number)
		_finish_typed_turn(game, _choice_id_by_correctness(game.get_typed_reality_choices(), true))
		_assert_true(game.continue_typed_reality_conversation(), "floor %d should continue to the second question" % floor_number)
		_finish_typed_turn(game, _choice_id_by_correctness(game.get_typed_reality_choices(), true))
		_assert_true(game.is_prerequisite_item_revealed(item_id), "two correct answers should reveal floor %d's physical item" % floor_number)
		_assert_eq(game.reality_dialogue_count, 1, "the complete two-question exchange should count one dialogue")
		_assert_true(str(game.conversation_feedback).contains(str(item.get("location_hint", ""))), "success feedback should tell the player where to search")
		var progress: Dictionary = game.get_key_clue_progress(floor_number)
		_assert_true(bool(progress.get("solved", false)), "the solved key conversation should persist")
		_assert_true(game.collect_prerequisite_item(item_id), "the revealed item should remain a separate physical collection step")


func _finish_typed_turn(game: RefCounted, choice_id: String) -> void:
	_assert_true(not choice_id.is_empty(), "test should find an authored choice")
	_assert_true(game.select_typed_reality_choice(choice_id), "authored key choice should be selectable")
	while game.conversation_phase == "typing":
		game.advance_typed_reality_character()


func _choice_id_by_correctness(choices: Array, wanted: bool) -> String:
	for choice: Dictionary in choices:
		if bool(choice.get("correct", false)) == wanted:
			return str(choice.get("id", ""))
	return ""


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
