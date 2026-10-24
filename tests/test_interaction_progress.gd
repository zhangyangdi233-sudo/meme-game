extends SceneTree
## No daily actions, funds or day settlement: the run goes on until the ending, and the floor, floor-three and
## hidden-ending checks run when a valid interaction (a post, a finished conversation, a pickup) completes.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const ActionOutcomeScript = preload("res://scripts/game/action_outcome.gd")
const PickupCharPoolScript = preload("res://scripts/narrative/pickup_char_pool.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const StateScript = preload("res://scripts/meme_game_state.gd")

const REMOVED_FIELDS := ["money", "actions_remaining", "max_actions_per_day", "needs_day_settlement", "day_ended_reason"]

var _failures: Array[String] = []


func _init() -> void:
	_run()


func _run() -> void:
	test_a_run_holds_no_funds_actions_or_day_settlement()
	test_posts_are_not_limited()
	test_pickups_are_not_limited()
	test_conversations_are_not_limited()
	test_reaching_a_threshold_waits_for_the_next_interaction()
	test_a_pickup_advances_the_floor_once_the_threshold_is_reached()
	test_a_post_that_crosses_the_threshold_advances_when_it_completes()
	test_a_finished_conversation_advances_the_floor()
	test_leaving_a_conversation_unspoken_checks_nothing()
	test_a_world_item_pickup_checks_progress()
	test_floor_three_ends_the_tower_at_the_next_interaction()
	test_floor_three_with_every_item_enters_the_hidden_floor()
	test_floor_four_unlocks_the_hidden_ending_at_the_next_interaction()
	test_crossing_sixty_plays_the_flashback_and_the_run_goes_on()
	test_saves_carry_the_new_version()
	test_an_older_save_is_refused()
	if _failures.is_empty():
		print("interaction progress tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_a_run_holds_no_funds_actions_or_day_settlement() -> void:
	var game := _tower_state()
	var saved: Dictionary = game.to_save_data().get("state", {})
	for field_name in REMOVED_FIELDS:
		_assert_true(game.get(field_name) == null, "the state should not hold %s" % field_name)
		_assert_true(not PropertyKeysScript.is_run(field_name), "no run model should be named %s" % field_name)
		_assert_true(not saved.has(field_name), "the save should not carry %s" % field_name)
	for method_name in ["spend_action", "can_spend_action", "settle_day_if_needed", "fuse_memes", "publish_dialogue", "confirm_doctor_sentence"]:
		_assert_true(not game.has_method(method_name), "the state should not offer %s" % method_name)


func test_posts_are_not_limited() -> void:
	var game := _tower_state()
	for attempt in 12:
		game.pollution = 0
		game.free_sentence_units = ["灯"]
		var result: Dictionary = game.submit_free_sentence("zh")
		_assert_true(bool(result.get("submitted", false)), "post %d should go through" % (attempt + 1))
	_assert_eq(game.day, 1, "posting should never move the day on")


func test_pickups_are_not_limited() -> void:
	var game := _tower_state()
	var picked := 0
	for post_id in PickupCharPoolScript.get_post_ids():
		for unit in PickupCharPoolScript.get_post_units(str(post_id), "zh"):
			if game.is_social_char_collected(str(unit), "zh"):
				continue
			var result: Dictionary = game.pick_social_char(str(post_id), str(unit), "zh")
			_assert_true(bool(result.get("picked", false)), "picking %s should go through" % unit)
			picked += 1
	_assert_true(picked >= 8, "the fixture posts should offer many pickups (got %d)" % picked)


func test_conversations_are_not_limited() -> void:
	var game := _tower_state()
	for attempt in 8:
		_assert_true(game.start_typed_reality_conversation("floor1npc0", "npc", "迟到者"), "conversation %d should start" % (attempt + 1))
		_speak_first_choice(game)
		_assert_eq(game.conversation_phase, "result", "conversation %d should reach its result" % (attempt + 1))
		game.end_typed_reality_conversation()


func test_reaching_a_threshold_waits_for_the_next_interaction() -> void:
	var game := _tower_state()
	game.pollution = 25
	_assert_eq(game.tower_floor, 1, "raising pollution alone should not move the player")


func test_a_pickup_advances_the_floor_once_the_threshold_is_reached() -> void:
	var game := _tower_state()
	game.pollution = 25
	var result: Dictionary = game.pick_social_char("floor_13", "门", "zh")
	var outcome: ActionOutcomeScript = result.get("outcome")
	_assert_true(bool(result.get("picked", false)), "the pickup should go through")
	_assert_eq(game.tower_floor, 2, "the pickup should advance floor one at 25% pollution")
	_assert_true(outcome != null and outcome.floor_changed, "the pickup's outcome should report the new floor")

	var duplicate: Dictionary = game.pick_social_char("floor_13", "门", "zh")
	var refused: ActionOutcomeScript = duplicate.get("outcome")
	_assert_true(refused != null and not refused.succeeded and not refused.floor_changed, "a refused pickup should check nothing")


func test_a_post_that_crosses_the_threshold_advances_when_it_completes() -> void:
	var game := _tower_state()
	game.pollution = 24
	game.free_sentence_units = ["灯"]
	var result: Dictionary = game.submit_free_sentence("zh")
	var outcome: ActionOutcomeScript = result.get("outcome")
	_assert_true(game.pollution >= 25, "the post should raise pollution past the threshold")
	_assert_eq(game.tower_floor, 2, "the post should advance the floor once it completes")
	_assert_true(outcome != null and outcome.succeeded and outcome.floor_changed, "the post's outcome should report the new floor")

	game.free_sentence_units = []
	var empty: ActionOutcomeScript = game.submit_free_sentence("zh").get("outcome")
	_assert_true(empty != null and not empty.succeeded and not empty.floor_changed, "an empty post should check nothing")


func test_a_finished_conversation_advances_the_floor() -> void:
	var game := _tower_state()
	game.pollution = 25
	_assert_true(game.start_typed_reality_conversation("floor1npc0", "npc", "迟到者"), "the conversation should start")
	_speak_first_choice(game)
	_assert_eq(game.tower_floor, 1, "the floor should wait while the result is still on screen")
	var outcome: ActionOutcomeScript = game.end_typed_reality_conversation()
	_assert_eq(game.tower_floor, 2, "ending a spoken conversation should advance the floor")
	_assert_true(outcome.succeeded and outcome.floor_changed, "the conversation's outcome should report the new floor")
	_assert_eq(game.conversation_phase, "idle", "ending the conversation should reset it")


func test_leaving_a_conversation_unspoken_checks_nothing() -> void:
	var game := _tower_state()
	game.pollution = 25
	_assert_true(game.start_typed_reality_conversation("floor1npc0", "npc", "迟到者"), "the conversation should start")
	var outcome: ActionOutcomeScript = game.end_typed_reality_conversation()
	_assert_true(not outcome.succeeded and not outcome.floor_changed, "a conversation left before speaking is no interaction")
	_assert_eq(game.tower_floor, 1, "leaving without speaking should not move the player")
	_assert_eq(game.conversation_phase, "idle", "leaving should still reset the conversation")


func test_a_world_item_pickup_checks_progress() -> void:
	var game := _tower_state()
	var item: Dictionary = game.get_prerequisite_item_for_floor(1)
	game.reveal_prerequisite_item_for_floor(1)
	game.pollution = 25
	_assert_true(game.collect_world_item(item), "the revealed item should be picked up")
	_assert_eq(game.tower_floor, 2, "the item pickup should advance the floor")


func test_floor_three_ends_the_tower_at_the_next_interaction() -> void:
	var game := _tower_state()
	game.tower_floor = 3
	game.pollution = 80
	game.floor3_task_complete = true
	_assert_true(not game.ending_unlocked, "meeting the floor-three conditions alone should not end the run")
	game.pick_social_char("floor_13", "门", "zh")
	_assert_true(game.formal_floor_three_complete, "the pickup should run the floor-three check")
	_assert_true(game.ending_unlocked, "the floor-three check should unlock the normal ending")
	_assert_eq(game.ending_route, "normal", "without every item the route is the normal ending")


func test_floor_three_with_every_item_enters_the_hidden_floor() -> void:
	var game := _tower_state()
	for floor_number in [1, 2, 3]:
		game.reveal_prerequisite_item_for_floor(floor_number)
		game.collect_prerequisite_item(str(game.get_prerequisite_item_for_floor(floor_number).get("id", "")))
	game.tower_floor = 3
	game.pollution = 80
	game.floor3_task_complete = true
	var outcome: ActionOutcomeScript = game.pick_social_char("floor_13", "门", "zh").get("outcome")
	_assert_eq(game.tower_floor, 4, "every item should send the floor-three check to the hidden floor")
	_assert_eq(game.ending_route, "hidden", "the route should be the hidden one")
	_assert_true(not game.ending_unlocked, "entering the hidden floor should not end the run")
	_assert_true(outcome.floor_changed, "the outcome should report the hidden floor")


func test_floor_four_unlocks_the_hidden_ending_at_the_next_interaction() -> void:
	var game := _tower_state()
	game.tower_floor = 4
	game.ending_route = "hidden"
	game.free_sentence_units = ["出口", "存在"]
	game.submit_free_sentence("zh")
	_assert_true(game.floor4_task_complete, "the exit rule should complete the floor-four task")
	_assert_true(not game.ending_unlocked, "the exit appears first; the ending waits for the next interaction")
	game.pick_social_char("floor_13", "门", "zh")
	_assert_true(game.ending_unlocked, "the next interaction should unlock the hidden ending")


func test_crossing_sixty_plays_the_flashback_and_the_run_goes_on() -> void:
	var game := _tower_state()
	game.tower_floor = 3
	game.pollution = StateScript.POLLUTION_FLASHBACK_THRESHOLD - 1
	game.free_sentence_units = ["灯"]
	var outcome: ActionOutcomeScript = game.submit_free_sentence("zh").get("outcome")
	_assert_true(outcome.flashback, "crossing 60% should report the flashback")
	_assert_eq(outcome.settlement(), {"flashback": true}, "the beat should hold the flashback alone")
	_assert_eq(game.day, 1, "the flashback should not move the day on")
	_assert_true(not game.pollution_flashback_pending, "the outcome should take the pending flashback")
	game.free_sentence_units = ["灯"]
	var next: Dictionary = game.submit_free_sentence("zh")
	var next_outcome: ActionOutcomeScript = next.get("outcome")
	_assert_true(bool(next.get("submitted", false)), "the player should keep acting after the flashback")
	_assert_true(not next_outcome.flashback, "the flashback should play once")
	_assert_eq(next_outcome.settlement(), {}, "a later post should need no beat")


func test_saves_carry_the_new_version() -> void:
	var game := _tower_state()
	game.pollution = 41
	var save_data: Dictionary = game.to_save_data()
	_assert_eq(int(save_data.get("version", 0)), 6, "saves should use version six")
	var restored: RefCounted = StateScript.new()
	_assert_true(restored.load_save_data(save_data), "a version-six save should load")
	_assert_eq(restored.pollution, 41, "pollution should survive the round trip")


func test_an_older_save_is_refused() -> void:
	for version in [1, 4, 5]:
		var restored: RefCounted = StateScript.new()
		_assert_true(not restored.load_save_data({"version": version, "state": {"pollution": 30, "tower_floor": 2}}), "a version-%d save should be refused so the host starts a new run" % version)


## Picks the first choice and types it out to its result.
func _speak_first_choice(game: RefCounted) -> void:
	var choice_id := str(game.conversation_choices[0].get("id", ""))
	game.select_typed_reality_choice(choice_id)
	while game.conversation_phase == "typing":
		game.advance_typed_reality_character()


## The progress check climbs the tower only once chapter one is behind the run.
func _tower_state() -> MemeGameState:
	var game: MemeGameState = Harness.new_state()
	game.skip_chapter_one()
	return game


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
