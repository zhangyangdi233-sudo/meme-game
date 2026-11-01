extends SceneTree
## In a basement round a post is judged against that round's room: a red post changes the room and stays in the save,
## a green one leaves it alone, the next round starts over, and the exit still asks for a post and the NPC.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const GameLocaleScript = preload("res://scripts/localization/game_locale.gd")
const PolicyScript = preload("res://scripts/game/pollution_policy.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const RoomContentScript = preload("res://scripts/game/room_content.gd")
const StateScript = preload("res://scripts/meme_game_state.gd")

const RULE_ESCAPE_ROOMS := "res://tests/fixtures/rooms_rule_escape.json"

var _failures: Array[String] = []


func _init() -> void:
	test_a_red_post_changes_the_room()
	test_a_green_post_leaves_the_room_alone()
	test_the_change_survives_a_save()
	test_a_later_post_can_turn_the_change_around()
	test_a_polluted_subject_cannot_turn_the_change_around()
	test_the_next_round_starts_from_its_own_room()
	test_a_debug_jump_forgets_the_rooms_rules()
	test_a_rule_alone_does_not_open_the_exit()
	test_a_rule_escape_opens_the_exit()
	test_the_exit_stays_open_when_the_rule_is_taken_back()
	test_the_npc_after_a_rule_escape_changes_nothing()
	test_the_other_escape_still_works_in_a_room_with_two()
	test_a_rule_escape_survives_a_save()
	test_an_escape_holds_in_its_own_round_only()
	test_the_npc_asks_for_a_post_only_without_one()
	test_only_the_rooms_words_can_be_picked_up()
	test_the_tower_keeps_its_rules()
	if _failures.is_empty():
		print("room state tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_a_red_post_changes_the_room() -> void:
	var game := _basement()
	var before: float = game.room_world_state().get("brightness")
	var result: Dictionary = _post(game, ["灯", "亮"])
	_assert_eq(result.get("tier"), "rule", "灯亮 should be a rule in round one")
	_assert_eq(game.published_memes[0].get("tier"), "rule", "the post should record that it was red")
	_assert_true(float(game.room_world_state().get("brightness")) > before, "the room should be brighter")
	_assert_eq(game.get_world_rules().size(), 1, "the rule should show among the active rules")


func test_a_green_post_leaves_the_room_alone() -> void:
	var game := _basement()
	var before: Dictionary = game.room_world_state()
	var result: Dictionary = _post(game, ["我", "想", "回", "家"])
	_assert_eq(result.get("tier"), "misread", "an unknown sentence should be green")
	_assert_eq(game.room_world_state(), before, "the room should not change")
	_assert_eq(game.get_world_rules().size(), 0, "no rule should be recorded")


func test_the_change_survives_a_save() -> void:
	var game := _basement()
	_post(game, ["灯", "亮"])
	var saved: Dictionary = game.room_world_state()
	var loaded := StateScript.new()
	_assert_true(loaded.load_save_data(game.to_save_data()), "the save should load")
	_assert_eq(loaded.room_world_state(), saved, "the changed room should come back from the save")
	_assert_eq(saved.get("brightness"), 1.6, "the rule should have brightened the room")


func test_a_later_post_can_turn_the_change_around() -> void:
	var game := _basement()
	game.pollution_policy = PolicyScript.settings().merged({"subject_voids_rule": false}, true)
	_post(game, ["灯", "亮"])
	var lit: float = game.room_world_state().get("brightness")
	_post(game, ["灯", "不", "亮"])
	_assert_true(float(game.room_world_state().get("brightness")) < lit, "灯不亮 should darken the lit room")
	_assert_eq(game.get_world_rules().size(), 1, "both sentences should be one rule at its newest polarity")


func test_a_polluted_subject_cannot_turn_the_change_around() -> void:
	var game := _basement()
	_post(game, ["灯", "亮"])
	var lit: float = game.room_world_state().get("brightness")
	_assert_eq(_post(game, ["灯", "不", "亮"]).get("tier"), "misread", "the polluted subject should void 灯不亮")
	_assert_eq(game.room_world_state().get("brightness"), lit, "the room should stay as it was")


func test_the_next_round_starts_from_its_own_room() -> void:
	var game := _basement()
	_post(game, ["灯", "亮"])
	_finish_conversation(game)
	_assert_true(game.leave_basement_round(), "the delivered round should lead on")
	_assert_eq(game.room_world_state(), RoomContentScript.room(2).get("state"), "round two should stand in its own room")
	_assert_eq(game.get_world_rules().size(), 0, "a rule should hold in its own room only")


func test_a_debug_jump_forgets_the_rooms_rules() -> void:
	var game := _basement()
	_post(game, ["灯", "亮"])
	_assert_true(game.jump_to_basement_round(2), "the jump should start a round fresh")
	_assert_eq(game.get_world_rules().size(), 0, "a fresh round should have no rules")


func test_a_rule_alone_does_not_open_the_exit() -> void:
	var game := _basement()
	_post(game, ["灯", "亮"])
	_assert_true(not ProgressScript.exit_open(game.chapter_one_progress), "a rule should not open the exit")
	_finish_conversation(game)
	_assert_true(ProgressScript.exit_open(game.chapter_one_progress), "the post and the NPC should still open it")


func test_a_rule_escape_opens_the_exit() -> void:
	var game := _rule_escape_basement()
	_post(game, ["我", "想", "回", "家"])
	_assert_true(not ProgressScript.exit_open(game.chapter_one_progress), "a green post should open nothing")
	_post(game, ["灯", "亮"])
	_assert_true(not ProgressScript.exit_open(game.chapter_one_progress), "another rule should open nothing")
	_post(game, ["门", "可", "以", "打", "开"])
	_assert_true(ProgressScript.exit_open(game.chapter_one_progress), "the rule should open the exit without the NPC")


func test_the_exit_stays_open_when_the_rule_is_taken_back() -> void:
	var game := _rule_escape_basement()
	_post(game, ["门", "可", "以", "打", "开"])
	_post(game, ["门", "不", "可", "以", "打", "开"])
	_assert_true(ProgressScript.exit_open(game.chapter_one_progress), "an opened exit should not trap the player again")


func test_the_npc_after_a_rule_escape_changes_nothing() -> void:
	var game := _rule_escape_basement()
	_post(game, ["门", "可", "以", "打", "开"])
	_finish_conversation(game)
	_assert_true(ProgressScript.exit_open(game.chapter_one_progress), "the NPC afterwards should change nothing")


func test_the_other_escape_still_works_in_a_room_with_two() -> void:
	var game := _rule_escape_basement()
	_post(game, ["灯", "亮"])
	_finish_conversation(game)
	_assert_true(ProgressScript.exit_open(game.chapter_one_progress), "the post and the NPC should open the same room")


func test_a_rule_escape_survives_a_save() -> void:
	var game := _rule_escape_basement()
	_post(game, ["门", "可", "以", "打", "开"])
	var loaded := StateScript.new()
	loaded.room_data_path = RULE_ESCAPE_ROOMS
	_assert_true(loaded.load_save_data(game.to_save_data()), "the save should load")
	_assert_true(ProgressScript.exit_open(loaded.chapter_one_progress), "the opened exit should come back from the save")
	_assert_true(loaded.leave_basement_round(), "the loaded exit should lead on")


func test_an_escape_holds_in_its_own_round_only() -> void:
	var game := _rule_escape_basement()
	_post(game, ["门", "可", "以", "打", "开"])
	_assert_true(game.leave_basement_round(), "the opened exit should lead on")
	_assert_true(not ProgressScript.exit_open(game.chapter_one_progress), "round two should start shut")
	_post(game, ["灯", "亮"])
	_finish_conversation_with(game, 2)
	_assert_true(not ProgressScript.exit_open(game.chapter_one_progress), "a post and the NPC should not open a rule-only room")
	_post(game, ["地", "方", "存", "在"])
	_assert_true(ProgressScript.exit_open(game.chapter_one_progress), "round two should need its own sentence")


func test_the_npc_asks_for_a_post_only_without_one() -> void:
	var game := _rule_escape_basement()
	_post(game, ["门", "可", "以", "打", "开"])
	_assert_true(game.leave_basement_round(), "the opened exit should lead on")
	var no_post_line: String = GameLocaleScript.for_locale("zh").translate(StateScript.BASEMENT_NO_POST_LINE)
	_finish_conversation_with(game, 2)
	_assert_true(no_post_line in game.conversation_feedback, "without a post the NPC should send the player to the computer")
	_post(game, ["灯", "亮"])
	_finish_conversation_with(game, 2)
	_assert_true(no_post_line not in game.conversation_feedback, "after a post the NPC should not ask for one")


func test_only_the_rooms_words_can_be_picked_up() -> void:
	var game := _basement()
	_assert_true("灯" in game.get_pickup_unit_pool("zh"), "a room word should be on offer")
	_assert_true("家" not in game.get_pickup_unit_pool("zh"), "a word round one does not list should not be on offer")
	var post_with_home := _post_holding("家")
	var refused: Dictionary = game.pick_social_char(post_with_home, "家", "zh")
	_assert_eq(refused.get("reason"), "not-in-pool", "a word off the room's list should stay in the post")
	var picked: Dictionary = game.pick_social_char(_post_holding("灯"), "灯", "zh")
	_assert_true(bool(picked.get("picked", false)), "a room word should be picked up")


func test_the_tower_keeps_its_rules() -> void:
	var game := Harness.new_state()
	game.skip_chapter_one()
	_assert_eq(_post(game, ["门", "可", "以", "打", "开"]).get("tier"), "rule", "the tower should keep the old rule table")
	_assert_true(game.is_world_rule_active("door|can_open"), "the tower's door rule should hold")
	_assert_eq(game.room_world_state(), {}, "the tower has no room")
	_assert_true("家" in game.get_pickup_unit_pool("zh"), "the tower should keep the whole word pool")


func _basement() -> MemeGameState:
	var game := Harness.new_state()
	while game.advance_opening_narration():
		pass
	game.complete_opening_knock()
	game.open_opening_door()
	_assert_eq(ProgressScript.round_of(game.chapter_one_progress), 1, "setup should reach round one")
	return game


func _rule_escape_basement() -> MemeGameState:
	var game := _basement()
	game.room_data_path = RULE_ESCAPE_ROOMS
	return game


func _post(game: MemeGameState, units: Array) -> Dictionary:
	game.free_sentence_units = units
	return game.submit_free_sentence("zh")


func _finish_conversation(game: MemeGameState) -> void:
	_finish_conversation_with(game, 1)


func _finish_conversation_with(game: MemeGameState, round_number: int) -> void:
	_assert_true(game.start_typed_reality_conversation("basement_npc_%d" % round_number, "basement_npc", "护灯人"), "the NPC should talk")
	while true:
		while game.conversation_phase == "typing":
			game.advance_typed_reality_character()
		if not game.continue_typed_reality_conversation():
			return


func _post_holding(unit: String) -> String:
	var pool := preload("res://scripts/narrative/pickup_char_pool.gd")
	for post_id in pool.get_post_ids():
		if pool.is_unit_seeded_in_post(post_id, unit, "zh"):
			return post_id
	_failures.append("no post holds %s" % unit)
	return ""


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if str(actual) != str(expected):
		_failures.append("%s (got %s, expected %s)" % [message, actual, expected])
