extends SceneTree
## The portal at state level (planner's design, 2026-10-31): walking into the portal fixed in a basement round leaves
## that round for the white door's passage, which leads to the next round; a run does it once, the save keeps that, a
## new run forgets it, and a round left this way leaves nothing of its own behind.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const StateScript = preload("res://scripts/meme_game_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	test_the_portal_leads_through_the_passage_into_the_next_round()
	test_a_run_walks_through_its_portal_once()
	test_the_save_keeps_the_passage_and_the_used_portal()
	test_a_new_run_and_a_jump_give_the_portal_back()
	test_the_portal_takes_the_rounds_rules_with_it()
	if _failures.is_empty():
		print("portal state tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_the_portal_leads_through_the_passage_into_the_next_round() -> void:
	var game: MemeGameState = _round(2)
	_assert_true(not game.portal_used, "a run should start with its portal unused")
	_assert_true(game.leave_basement_round_by_portal(), "the portal should leave the round")
	_assert_eq(ProgressScript.phase_of(game.chapter_one_progress), ProgressScript.PHASE_PASSAGE, "the portal should lead into the passage")
	_assert_true(game.portal_used, "walking through should use the portal up")
	_assert_true(game.cross_passage(), "the white door should lead on")
	_assert_eq(ProgressScript.round_of(game.chapter_one_progress), 3, "the white door should open on the next round")
	_assert_eq(game.basement_exits(), [], "the round reached should start with no exit")


func test_a_run_walks_through_its_portal_once() -> void:
	var game: MemeGameState = _round(2)
	game.leave_basement_round_by_portal()
	game.cross_passage()
	var third: Dictionary = game.chapter_one_progress
	_assert_true(not game.leave_basement_round_by_portal(), "a used-up portal should lead nowhere")
	_assert_eq(game.chapter_one_progress, third, "a used-up portal should leave the round as it is")
	var opening: MemeGameState = Harness.new_state()
	_assert_true(not opening.leave_basement_round_by_portal(), "there is no portal out of the opening")
	_assert_true(not opening.portal_used, "a portal that led nowhere should not be used up")


func test_the_save_keeps_the_passage_and_the_used_portal() -> void:
	var game: MemeGameState = _round(4)
	game.leave_basement_round_by_portal()
	var restored := StateScript.new()
	_assert_true(restored.load_save_data(game.to_save_data()), "the save should load")
	_assert_eq(ProgressScript.phase_of(restored.chapter_one_progress), ProgressScript.PHASE_PASSAGE, "the save should come back in the passage")
	_assert_eq(ProgressScript.passage_round(restored.chapter_one_progress), 5, "the save should remember the round the passage leads to")
	_assert_true(restored.portal_used, "the save should remember the portal is used up")
	_assert_true(restored.cross_passage(), "the restored passage should lead on")
	_assert_eq(ProgressScript.round_of(restored.chapter_one_progress), 5, "the restored passage should open on the next round")
	var older: Dictionary = game.to_save_data().duplicate(true)
	(older["state"] as Dictionary).erase("portal_used")
	var from_older := StateScript.new()
	_assert_true(from_older.load_save_data(older), "a save from before the portal should still load")
	_assert_true(not from_older.portal_used, "a save from before the portal should have it unused")


func test_a_new_run_and_a_jump_give_the_portal_back() -> void:
	var game: MemeGameState = _round(1)
	game.leave_basement_round_by_portal()
	game.new_run()
	_assert_true(not game.portal_used, "a new run should have its portal again")
	var jumped: MemeGameState = _round(2)
	jumped.leave_basement_round_by_portal()
	jumped.jump_to_basement_round(3)
	_assert_true(not jumped.portal_used, "a debug jump should give the portal back")


func test_the_portal_takes_the_rounds_rules_with_it() -> void:
	var game: MemeGameState = _round(2)
	game.free_sentence_units = ["电视", "是", "出", "口"]
	game.submit_free_sentence("zh")
	var held_before: int = game.world_rules.size()
	_assert_true(game.leave_basement_round_by_portal(), "the portal should leave a round that has rules of its own")
	_assert_true(game.world_rules.size() <= held_before, "leaving through the portal should add no rule")
	for rule_key: Variant in game.world_rules:
		_assert_true(int((game.world_rules[rule_key] as Dictionary).get("round", 0)) == 0, "no rule of the round left should stay: %s" % str(rule_key))


func _round(round_number: int) -> MemeGameState:
	var game: MemeGameState = Harness.new_state()
	game.jump_to_basement_round(round_number)
	return game


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
