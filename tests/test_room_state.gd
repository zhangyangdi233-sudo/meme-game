extends SceneTree
## In a basement round a post is judged against that round's room: a red post changes the room and stays in the save,
## a green one leaves it alone, the next round starts over, and the exit still asks for a post and the NPC.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const RoomContentScript = preload("res://scripts/game/room_content.gd")
const StateScript = preload("res://scripts/meme_game_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	test_a_red_post_changes_the_room()
	test_a_green_post_leaves_the_room_alone()
	test_the_change_survives_a_save()
	test_a_later_post_can_turn_the_change_around()
	test_the_next_round_starts_from_its_own_room()
	test_a_debug_jump_forgets_the_rooms_rules()
	test_a_rule_alone_does_not_open_the_exit()
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
	_post(game, ["出", "口", "存", "在"])
	var saved: Dictionary = game.room_world_state()
	var loaded := StateScript.new()
	_assert_true(loaded.load_save_data(game.to_save_data()), "the save should load")
	_assert_eq(loaded.room_world_state(), saved, "the changed room should come back from the save")
	_assert_eq((saved.get("objects") as Dictionary).get("exit_lamp"), true, "the exit rule should have brought the lamp")


func test_a_later_post_can_turn_the_change_around() -> void:
	var game := _basement()
	_post(game, ["灯", "亮"])
	var lit: float = game.room_world_state().get("brightness")
	_post(game, ["灯", "不", "亮"])
	_assert_true(float(game.room_world_state().get("brightness")) < lit, "灯不亮 should darken the lit room")
	_assert_eq(game.get_world_rules().size(), 1, "both sentences should be one rule at its newest polarity")


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


func _post(game: MemeGameState, units: Array) -> Dictionary:
	game.free_sentence_units = units
	return game.submit_free_sentence("zh")


func _finish_conversation(game: MemeGameState) -> void:
	_assert_true(game.start_typed_reality_conversation("basement_npc_1", "basement_npc", "护灯人"), "the NPC should talk")
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
