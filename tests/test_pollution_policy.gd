extends SceneTree
## Word pollution in a basement run: a red post pollutes its subject and a green one nothing, skeleton words stay clean,
## a polluted subject voids its rule and its synonyms in every later post, and the save keeps it. Each of the policy's
## four defaults can be changed alone.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const PolicyScript = preload("res://scripts/game/pollution_policy.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const RoomContentScript = preload("res://scripts/game/room_content.gd")
const StateScript = preload("res://scripts/meme_game_state.gd")

const POLICY_ROOMS := "res://tests/fixtures/rooms_pollution.json"
const DOOR := ["门", "可", "以", "打", "开"]

var _failures: Array[String] = []


func _init() -> void:
	test_the_authored_policy_holds_the_four_defaults()
	test_a_red_post_pollutes_its_subject()
	test_a_green_post_pollutes_nothing()
	test_a_word_scattered_through_the_sentence_is_polluted()
	test_the_exit_open_stops_pollution()
	test_a_delivered_round_stops_pollution()
	test_the_post_that_opens_the_exit_still_pollutes()
	test_skeleton_words_are_never_polluted()
	test_a_polluted_rule_is_void_in_the_next_round()
	test_a_synonym_of_a_polluted_rule_is_void()
	test_a_synonym_in_another_language_is_void()
	test_a_synonym_a_later_room_adds_is_void_and_polluted()
	test_a_void_post_is_green_and_keeps_counting_as_a_post()
	test_a_polluted_word_can_still_go_in_a_sentence()
	test_the_sentence_preview_says_it_will_be_void()
	test_a_void_post_keeps_its_garbled_wording()
	test_the_ratio_can_replace_the_subject_rule()
	test_synonyms_can_stay_clean()
	test_the_exit_can_be_a_subject()
	test_a_room_cannot_author_a_barred_subject()
	test_the_exit_can_keep_polluting_after_it_opens()
	test_the_save_keeps_the_pollution()
	test_a_debug_jump_starts_clean()
	test_the_tower_pollutes_nothing()
	test_garbled_text_hides_the_word_and_repeats()
	if _failures.is_empty():
		print("pollution policy tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_the_authored_policy_holds_the_four_defaults() -> void:
	var policy: Dictionary = PolicyScript.settings()
	_assert_eq(policy.get("subject_voids_rule"), true, "a polluted subject should void its rule")
	_assert_eq(policy.get("pollute_synonyms"), true, "pollution should count by synonym group")
	_assert_eq(policy.get("barred_subjects"), ["exit"], "the exit should not be a subject")
	_assert_eq(policy.get("pollute_after_exit_opens"), false, "an open exit should stop pollution")
	for locale_code: String in RoomContentScript.SUPPORTED_LOCALES:
		_assert_true(not (policy["skeleton_words"] as Dictionary).get(locale_code, []).is_empty(), "%s should list skeleton words" % locale_code)


func test_a_red_post_pollutes_its_subject() -> void:
	var game := _rooms()
	_assert_eq(_post(game, ["灯", "亮"]).get("tier"), "rule", "灯亮 should be red")
	_assert_eq(game.get_polluted_units("zh"), ["灯"], "only the subject should be polluted")


func test_a_green_post_pollutes_nothing() -> void:
	var game := _rooms()
	_assert_eq(_post(game, ["我", "想", "回", "家"]).get("tier"), "misread", "the sentence should be green")
	_assert_eq(game.get_polluted_units("zh"), [], "a green post should pollute nothing")


func test_a_word_scattered_through_the_sentence_is_polluted() -> void:
	var game := _rooms()
	_assert_eq(_post(game, ["地", "存", "在", "方"]).get("tier"), "rule", "a loose match should still be red")
	_assert_eq(game.get_polluted_units("zh"), ["地", "方"], "every unit of the subject should be polluted")


func test_the_exit_open_stops_pollution() -> void:
	var game := _rooms()
	_post(game, DOOR)
	_assert_true(ProgressScript.exit_open(game.chapter_one_progress), "the door rule should open the exit")
	_assert_eq(_post(game, ["灯", "亮"]).get("tier"), "rule", "a post after the door opened can still be red")
	_assert_eq(game.get_polluted_units("zh"), ["门", "房"], "a red post after the door opened should pollute no new word")


func test_a_delivered_round_stops_pollution() -> void:
	var game := _rooms()
	_post(game, ["我", "想", "回", "家"])
	_finish_conversation(game)
	_assert_true(ProgressScript.exit_open(game.chapter_one_progress), "the NPC should open the exit")
	_post(game, ["灯", "亮"])
	_assert_eq(game.get_polluted_units("zh"), [], "the same goes for an exit the NPC opened")


func test_the_post_that_opens_the_exit_still_pollutes() -> void:
	var game := _rooms()
	_post(game, DOOR)
	_assert_eq(game.get_polluted_units("zh"), ["门", "房"], "the opening post should use up its subject")


func test_skeleton_words_are_never_polluted() -> void:
	var game := _rooms()
	game.pollution_policy = _policy({"barred_subjects": []})
	_assert_eq(_post(game, ["出", "口", "存", "在"]).get("tier"), "rule", "with the bar lifted the exit is a subject")
	_assert_eq(game.get_polluted_units("zh"), [], "a skeleton word should stay clean")
	_assert_eq(_post(game, ["可", "乐", "存", "在"]).get("tier"), "rule", "a subject may hold a skeleton unit")
	_assert_eq(game.get_polluted_units("zh"), ["乐"], "only the unit outside the skeleton should be polluted")


func test_a_polluted_rule_is_void_in_the_next_round() -> void:
	var game := _rooms()
	_post(game, DOOR)
	_assert_true(game.leave_basement_round(), "the exit should lead on")
	var result: Dictionary = _post(game, DOOR)
	_assert_eq(result.get("tier"), "misread", "last round's rule should be green here")
	_assert_true(bool(result.get("voided", false)), "the result should say pollution voided it")
	_assert_eq(game.get_world_rules().size(), 0, "a void rule should not be written")
	_assert_true(not ProgressScript.exit_open(game.chapter_one_progress), "a void rule should open nothing")


func test_a_synonym_of_a_polluted_rule_is_void() -> void:
	var game := _rooms()
	_post(game, DOOR)
	var result: Dictionary = _post(game, ["房", "门", "可", "以", "打", "开"])
	_assert_true(bool(result.get("voided", false)), "a synonym of a polluted subject should be void")


func test_a_synonym_in_another_language_is_void() -> void:
	var game := _rooms()
	_post(game, DOOR)
	game.free_sentence_units = ["door", "can", "open"]
	_assert_true(bool(game.submit_free_sentence("en").get("voided", false)), "changing the language should not revive a subject")
	_assert_true("door" in game.get_polluted_units("en"), "the English word should show polluted too")


func test_a_synonym_a_later_room_adds_is_void_and_polluted() -> void:
	var game := _rooms()
	_post(game, ["灯", "亮"])
	_post(game, DOOR)
	_assert_true(game.leave_basement_round(), "the exit should lead on")
	_assert_true("烛" in game.get_polluted_units("zh"), "a word this room adds to a polluted group should show polluted")
	_assert_true(bool(_post(game, ["烛", "亮"]).get("voided", false)), "and its rule should be void")


func test_a_void_post_is_green_and_keeps_counting_as_a_post() -> void:
	var game := _rooms()
	_post(game, DOOR)
	_assert_true(game.leave_basement_round(), "the exit should lead on")
	var pollution_before: int = game.pollution
	_post(game, DOOR)
	_assert_eq(game.published_memes[0].get("tier"), "misread", "the record should be green")
	_assert_eq(game.pollution - pollution_before, 2 + DOOR.size(), "the overall pollution should count it as a green post")
	_assert_true(game.has_posted_this_round(), "it is still a post of this round")


func test_a_polluted_word_can_still_go_in_a_sentence() -> void:
	var game := _rooms()
	game.pick_social_char(_post_holding("灯"), "灯", "zh")
	_post(game, ["灯", "亮"])
	_assert_true(game.free_sentence_place("灯", "zh"), "a polluted word should still be placed")
	_assert_eq(game.get_free_sentence_units(), ["灯"], "the sentence should hold it")


func test_the_sentence_preview_says_it_will_be_void() -> void:
	var game := _rooms()
	var room: Dictionary = RoomContentScript.room(1, POLICY_ROOMS)
	var voids := func(units: Array) -> bool: return PolicyScript.sentence_voids(units, "zh", room, game.polluted_words, game.pollution_policy)
	_assert_true(not voids.call([]), "an empty sentence should not warn")
	_assert_true(not voids.call(["灯", "亮"]), "a clean rule should not warn")
	_post(game, ["灯", "亮"])
	_assert_true(voids.call(["灯", "亮"]), "a polluted rule should warn before it is posted")
	_assert_true(not voids.call(["灯"]), "a sentence that is no rule has nothing to lose")


func test_a_void_post_keeps_its_garbled_wording() -> void:
	var game := _rooms()
	_post(game, ["灯", "亮"])
	_assert_eq(game.published_memes[0].get("shown_text"), "灯亮", "the post that polluted the word was still clean")
	_post(game, ["灯", "亮"])
	_assert_eq(game.published_memes[0].get("shown_text"), "%s亮" % PolicyScript.garbled("灯"), "a later post shows the word as garbled")


func test_the_ratio_can_replace_the_subject_rule() -> void:
	var game := _rooms()
	game.pollution_policy = _policy({"subject_voids_rule": false})
	_post(game, ["灯", "亮"])
	_post(game, ["地", "方", "存", "在"])
	_assert_true(not bool(_post(game, ["灯", "不", "亮"]).get("voided", false)), "one word in three stays under the ratio")
	_assert_true(not bool(_post(game, ["灯", "亮"]).get("voided", false)), "one word in two is not over it")
	_assert_true(bool(_post(game, ["地", "方", "在"]).get("voided", false)), "two words in three go over it")


func test_synonyms_can_stay_clean() -> void:
	var game := _rooms()
	game.pollution_policy = _policy({"pollute_synonyms": false})
	_post(game, DOOR)
	_assert_true(game.jump_to_basement_round(1), "back to the room")
	game.polluted_words = {"units": {"zh": ["门"]}}
	_assert_true(bool(_post(game, DOOR).get("voided", false)), "the word itself stays void")
	game.free_sentence_units = ["door", "can", "open"]
	_assert_true(not bool(game.submit_free_sentence("en").get("voided", false)), "only that word is polluted")


func test_the_exit_can_be_a_subject() -> void:
	var barred := _rooms()
	_assert_true(bool(_post(barred, ["出", "口", "存", "在"]).get("voided", false)), "the exit should not be a subject by default")
	var lifted := _rooms()
	lifted.pollution_policy = _policy({"barred_subjects": []})
	_assert_eq(_post(lifted, ["出", "口", "存", "在"]).get("tier"), "rule", "with the bar lifted the rule holds")
	_assert_eq(_post(lifted, ["出", "口", "存", "在"]).get("tier"), "rule", "and being skeleton it holds every time")


func test_a_room_cannot_author_a_barred_subject() -> void:
	var problems: Array[String] = RoomContentScript.problems_in(ContentJson.load_dictionary_cached(POLICY_ROOMS, "test"), 2)
	_assert_true(problems.any(func(problem: String) -> bool: return "barred" in problem), "the barred subject should be named: %s" % [problems])
	_assert_eq(RoomContentScript.problems_in(ContentJson.load_dictionary_cached(POLICY_ROOMS, "test"), 2, _policy({"barred_subjects": []})), [] as Array[String], "the bar lifted, nothing is wrong")
	_assert_true(RoomContentScript.validate().get("ok"), "the authored rooms should bar nothing: %s" % [RoomContentScript.validate().get("problems")])


func test_the_exit_can_keep_polluting_after_it_opens() -> void:
	var game := _rooms()
	game.pollution_policy = _policy({"pollute_after_exit_opens": true})
	_post(game, DOOR)
	_post(game, ["灯", "亮"])
	_assert_true("灯" in game.get_polluted_units("zh"), "with the stop lifted the later post pollutes too")


func test_the_save_keeps_the_pollution() -> void:
	var game := _rooms()
	_post(game, DOOR)
	var loaded := StateScript.new()
	loaded.room_data_path = POLICY_ROOMS
	_assert_true(loaded.load_save_data(game.to_save_data()), "the save should load")
	_assert_eq(loaded.get_polluted_units("zh"), ["门", "房"], "the polluted word should come back")
	_assert_true(loaded.leave_basement_round(), "the loaded exit should lead on")
	loaded.free_sentence_units = DOOR
	_assert_true(bool(loaded.submit_free_sentence("zh").get("voided", false)), "and the rule should stay void")
	var older: Dictionary = game.to_save_data()
	(older["state"] as Dictionary).erase("polluted_words")
	var from_older := StateScript.new()
	_assert_true(from_older.load_save_data(older), "a save without pollution should load")
	_assert_eq(from_older.polluted_words, {}, "and start clean")


func test_a_debug_jump_starts_clean() -> void:
	var game := _rooms()
	_post(game, ["灯", "亮"])
	_assert_true(game.jump_to_basement_round(2), "the jump should work")
	_assert_eq(game.get_polluted_units("zh"), [], "a fresh round should have no polluted word")


func test_the_tower_pollutes_nothing() -> void:
	var game := Harness.new_state()
	game.skip_chapter_one()
	_assert_eq(_post(game, DOOR).get("tier"), "rule", "the tower should keep its rule table")
	_assert_eq(_post(game, DOOR).get("tier"), "rule", "and its rules should hold every time")
	_assert_eq(game.get_polluted_units("zh"), [], "the tower pollutes no word")


func test_garbled_text_hides_the_word_and_repeats() -> void:
	var garbled: String = PolicyScript.garbled("door")
	_assert_true(garbled != "door" and garbled.length() == 4, "one glyph per letter: %s" % garbled)
	_assert_eq(PolicyScript.garbled("door"), garbled, "the same word should always look the same")
	_assert_eq(PolicyScript.shown_units(["灯", "亮"], ["灯"]), [PolicyScript.garbled("灯"), "亮"], "only polluted units are garbled")


## A basement round played on the test rooms: round one has a door rule that opens its exit.
func _rooms() -> MemeGameState:
	var game := Harness.new_state()
	while game.advance_opening_narration():
		pass
	game.complete_opening_knock()
	game.open_opening_door()
	game.room_data_path = POLICY_ROOMS
	_assert_eq(ProgressScript.round_of(game.chapter_one_progress), 1, "setup should reach round one")
	return game


func _policy(changes: Dictionary) -> Dictionary:
	return PolicyScript.settings().merged(changes, true)


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
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])
