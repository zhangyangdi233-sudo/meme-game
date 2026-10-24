extends SceneTree
## The basement NPC conversation is one fixed route: no choices, the player types the authored line one unit per key,
## the NPC's reply follows, and the last reply ends it. Finishing it with this round's post delivers the round and
## opens the exit; without one the NPC sends the player back to the computer. Pollution garbles the typed line but
## never interrupts.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const ContentScript = preload("res://scripts/narrative/language_corruption_content.gd")
const StateScript = preload("res://scripts/meme_game_state.gd")

const BASEMENT_NPC_LABELS := ["护灯人", "迟到者", "回声住户", "抄写员", "无名信徒"]

var _failures: Array[String] = []


func _init() -> void:
	test_each_round_has_its_own_npc_route()
	test_a_basement_conversation_has_no_choices_and_types_the_authored_line()
	test_the_reply_follows_and_the_next_turn_types_at_once()
	test_pollution_garbles_the_line_but_never_interrupts()
	test_finishing_with_this_rounds_post_opens_the_exit()
	test_finishing_without_a_post_sends_the_player_back_to_the_computer()
	test_an_earlier_rounds_post_does_not_deliver_this_round()
	test_the_typing_hint_is_shown_until_a_first_line_is_typed()
	test_a_save_comes_back_on_the_same_round_and_delivery()
	test_leaving_through_the_open_exit_starts_the_next_round()
	test_basement_posts_do_not_move_the_tower_floor()
	if _failures.is_empty():
		print("basement conversation tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_each_round_has_its_own_npc_route() -> void:
	for round_number in range(1, ProgressScript.BASEMENT_ROUND_COUNT + 1):
		var route: Dictionary = ContentScript.get_basement_route(round_number)
		_assert_eq(str(route.get("actor_label", "")), BASEMENT_NPC_LABELS[round_number - 1], "round %d should be played with its NPC" % round_number)
		var turns: Array = route.get("turns", [])
		_assert_true(not turns.is_empty(), "round %d should have turns" % round_number)
		for turn: Dictionary in turns:
			_assert_true(not str(turn.get("line", "")).is_empty(), "every turn should open with the NPC's line")
			_assert_true(not str(turn.get("sentence", "")).is_empty(), "every turn should give the player one line to type")
			_assert_true(not str(turn.get("result", "")).is_empty(), "every turn should end with the NPC's reply")
	var first: Dictionary = (ContentScript.get_basement_route(1).get("turns", []) as Array)[0]
	_assert_eq(str(first.get("sentence", "")), "她叫它小月亮。", "the lamp keeper's route should keep the line that names the lamp")
	_assert_true(ContentScript.get_basement_route(0).is_empty(), "there is no round zero")
	_assert_true(ContentScript.get_basement_route(6).is_empty(), "there is no sixth round")


func test_a_basement_conversation_has_no_choices_and_types_the_authored_line() -> void:
	var game: MemeGameState = _basement_game(1)
	_assert_true(_start(game), "the round's NPC conversation should start")
	_assert_eq(game.conversation_phase, "typing", "the player's turn should start at once")
	_assert_eq(game.conversation_mode, "linear", "a basement conversation should follow its one route")
	_assert_true(game.get_typed_reality_choices().is_empty(), "a basement conversation should offer no choices")
	_assert_eq(game.conversation_prompt, "先别往灯上看。你听见她怎么叫那盏灯了吗？", "the NPC's first line should show")
	_assert_eq(game.get_typed_reality_unrevealed_suffix(), "她叫它小月亮。", "the authored line should wait to be typed")
	var first: Dictionary = game.advance_typed_reality_character()
	_assert_true(bool(first.get("advanced")), "a key should type one unit")
	_assert_eq(game.get_typed_reality_spoken_sentence(), "她", "the first unit should be typed")


func test_the_reply_follows_and_the_next_turn_types_at_once() -> void:
	var game: MemeGameState = _basement_game(2)
	_start(game)
	var route_turns: Array = ContentScript.get_basement_route(2).get("turns", [])
	var finished := _type_turn(game)
	_assert_true(bool(finished.get("completed")), "typing every unit should finish the turn")
	_assert_eq(game.conversation_phase, "result", "the NPC's reply should follow the typed line")
	_assert_eq(game.conversation_feedback, str((route_turns[0] as Dictionary).get("result")), "the reply should be the turn's authored result")
	_assert_true(game.conversation_can_continue, "a route with more turns should continue")
	_assert_true(game.continue_typed_reality_conversation(), "the next turn should load")
	_assert_eq(game.conversation_phase, "typing", "the next turn should start typing at once")
	_assert_true(game.get_typed_reality_choices().is_empty(), "the next turn should offer no choices either")
	_assert_eq(game.get_typed_reality_unrevealed_suffix(), str((route_turns[1] as Dictionary).get("sentence")), "the next authored line should wait to be typed")


func test_pollution_garbles_the_line_but_never_interrupts() -> void:
	var game: MemeGameState = _basement_game(3)
	game.pollution = 100
	_start(game)
	var garbled := false
	while true:
		_type_turn(game)
		_assert_true(not game.conversation_interrupted, "pollution should never interrupt a basement conversation")
		if game.get_typed_reality_spoken_sentence() != game.conversation_clean_sentence:
			garbled = true
		if not game.conversation_can_continue:
			break
		game.continue_typed_reality_conversation()
	_assert_true(garbled, "full pollution should garble what the player typed")
	_assert_true(game.conversation_completed, "the last reply should complete the conversation")


func test_finishing_with_this_rounds_post_opens_the_exit() -> void:
	var game: MemeGameState = _basement_game(1)
	_post(game)
	_start(game)
	_finish_conversation(game)
	_assert_true(ProgressScript.exit_open(game.chapter_one_progress), "finishing with this round's post should open the exit")


func test_finishing_without_a_post_sends_the_player_back_to_the_computer() -> void:
	var game: MemeGameState = _basement_game(1)
	_start(game)
	_finish_conversation(game)
	_assert_true(not ProgressScript.exit_open(game.chapter_one_progress), "finishing without a post should keep the exit shut")
	_assert_true(game.conversation_feedback.ends_with(StateScript.BASEMENT_NO_POST_LINE), "the NPC should send the player back to the computer")
	game.end_typed_reality_conversation()
	_post(game)
	_start(game)
	_finish_conversation(game)
	_assert_true(ProgressScript.exit_open(game.chapter_one_progress), "talking again after posting should open the exit")


func test_an_earlier_rounds_post_does_not_deliver_this_round() -> void:
	var game: MemeGameState = _basement_game(1)
	_post(game)
	game.jump_to_basement_round(2)
	_start(game)
	_finish_conversation(game)
	_assert_true(not ProgressScript.exit_open(game.chapter_one_progress), "round one's post should not deliver round two")


func test_the_typing_hint_is_shown_until_a_first_line_is_typed() -> void:
	var game: MemeGameState = _basement_game(1)
	_assert_true(not game.typing_hint_seen, "a new run should still show the typing hint")
	_start(game)
	game.advance_typed_reality_character()
	_assert_true(not game.typing_hint_seen, "the hint should stay while the first line is being typed")
	_type_turn(game)
	_assert_true(game.typing_hint_seen, "typing a whole line should retire the hint")
	var restored := StateScript.new()
	_assert_true(restored.load_save_data(game.to_save_data()), "the save should load")
	_assert_true(restored.typing_hint_seen, "a retired hint should stay retired after loading")
	restored.new_run()
	_assert_true(not restored.typing_hint_seen, "a new run should show the hint again")


func test_a_save_comes_back_on_the_same_round_and_delivery() -> void:
	var game: MemeGameState = _basement_game(3)
	_post(game)
	_start(game)
	_finish_conversation(game)
	var restored := StateScript.new()
	_assert_true(restored.load_save_data(game.to_save_data()), "a basement save should load")
	_assert_eq(ProgressScript.round_of(restored.chapter_one_progress), 3, "loading should come back on round three")
	_assert_true(ProgressScript.exit_open(restored.chapter_one_progress), "loading should keep the delivered round's exit open")
	var undelivered: MemeGameState = _basement_game(4)
	var restored_undelivered := StateScript.new()
	restored_undelivered.load_save_data(undelivered.to_save_data())
	_assert_eq(ProgressScript.round_of(restored_undelivered.chapter_one_progress), 4, "an undelivered round should come back too")
	_assert_true(not ProgressScript.exit_open(restored_undelivered.chapter_one_progress), "an undelivered round's exit should stay shut after loading")


func test_leaving_through_the_open_exit_starts_the_next_round() -> void:
	var game: MemeGameState = _basement_game(1)
	_assert_true(not game.leave_basement_round(), "a shut exit should not be left through")
	_post(game)
	_start(game)
	_finish_conversation(game)
	game.end_typed_reality_conversation()
	_assert_true(game.leave_basement_round(), "the open exit should be left through")
	_assert_eq(ProgressScript.round_of(game.chapter_one_progress), 2, "leaving should start round two")
	game.jump_to_basement_round(5)
	_post(game)
	_start(game)
	_finish_conversation(game)
	_assert_true(game.leave_basement_round(), "the fifth round's open exit should be left through")
	_assert_eq(str(game.chapter_one_progress.get("phase")), ProgressScript.PHASE_TOWER, "the fifth exit should lead to the crossroads")
	_assert_eq(game.tower_floor, 1, "the crossroads is the tower's first floor")


func test_basement_posts_do_not_move_the_tower_floor() -> void:
	var game: MemeGameState = _basement_game(2)
	game.pollution = 40
	_post(game)
	_assert_eq(game.tower_floor, 1, "a basement post should not climb the tower")
	game.jump_to_basement_round(5)
	_post(game)
	_start(game)
	_finish_conversation(game)
	game.end_typed_reality_conversation()
	_assert_eq(game.tower_floor, 1, "a basement conversation should not climb the tower")


func _type_turn(game: MemeGameState) -> Dictionary:
	var result: Dictionary = {}
	while game.conversation_phase == "typing":
		result = game.advance_typed_reality_character()
	return result


func _finish_conversation(game: MemeGameState) -> void:
	while true:
		_type_turn(game)
		if not game.continue_typed_reality_conversation():
			return


func _post(game: MemeGameState) -> void:
	game.free_sentence_units = ["灯"]
	_assert_true(bool(game.submit_free_sentence("zh").get("submitted")), "setup should post a sentence")


func _basement_game(round_number: int) -> MemeGameState:
	var game: MemeGameState = Harness.new_state()
	game.jump_to_basement_round(round_number)
	return game


func _start(game: MemeGameState) -> bool:
	var round_number := ProgressScript.round_of(game.chapter_one_progress)
	return game.start_typed_reality_conversation("basement_npc_%d" % round_number, "basement_npc", BASEMENT_NPC_LABELS[round_number - 1])


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
