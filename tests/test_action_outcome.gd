extends SceneTree

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const ActionOutcomeScript = preload("res://scripts/game/action_outcome.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()


func _run() -> void:
	test_publish_without_placed_meme_spends_nothing()
	test_publish_reports_spent_action_and_funds()
	test_publish_on_last_action_reports_day_transition()
	test_publish_crossing_flashback_threshold_reports_flashback()
	test_publish_without_actions_left_spends_nothing()
	test_fusion_reports_fused_meme_and_spent_action()
	test_fusion_of_unready_slots_spends_nothing()
	test_fusion_of_already_fused_pair_spends_nothing()
	if _failures.is_empty():
		print("action outcome tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_publish_without_placed_meme_spends_nothing() -> void:
	var game := Harness.new_state()
	var actions_before: int = game.actions_remaining
	var outcome: ActionOutcomeScript = game.publish_dialogue()
	_assert_true(not outcome.succeeded, "publishing an empty blank should fail")
	_assert_true(not outcome.spent_action, "a failed publish should not spend an action")
	_assert_eq(outcome.feedback_key, "publish_empty", "a failed publish should name the empty feedback")
	_assert_eq(outcome.settlement(), {}, "a failed publish should need no settlement")
	_assert_eq(game.actions_remaining, actions_before, "the action count should stay the same")


func test_publish_reports_spent_action_and_funds() -> void:
	var game := _ready_to_publish()
	var expected: Dictionary = game.get_publish_result(_meme())
	var money_before: int = game.money
	var pollution_before: int = game.pollution
	var actions_before: int = game.actions_remaining
	var outcome: ActionOutcomeScript = game.publish_dialogue()
	_assert_true(outcome.succeeded, "a placed meme should publish")
	_assert_true(outcome.spent_action, "publishing should spend an action")
	_assert_eq(outcome.feedback_key, "publish_done", "a publish should name the done feedback")
	_assert_eq(game.money, money_before + int(expected.get("money_gain", 0)), "publishing should add the previewed money")
	_assert_eq(game.pollution, pollution_before + int(expected.get("pollution_gain", 0)), "publishing should add the previewed pollution")
	_assert_eq(outcome.settlement(), {
		"day_transition": false,
		"flashback": false,
		"actions_before": actions_before,
		"actions_after": actions_before - 1,
	}, "the settlement should carry the spent action and no flashback or day change")


func test_publish_on_last_action_reports_day_transition() -> void:
	var game := _ready_to_publish()
	game.actions_remaining = 1
	var outcome: ActionOutcomeScript = game.publish_dialogue()
	_assert_true(outcome.day_transition, "the last action should end the day")
	_assert_eq(outcome.settlement().get("actions_after", -1), 0, "the settlement should show no actions left")
	_assert_true(not outcome.flashback, "no flashback below the threshold")


func test_publish_crossing_flashback_threshold_reports_flashback() -> void:
	var game := _ready_to_publish()
	var gain := int(game.get_publish_result(_meme()).get("pollution_gain", 0))
	_assert_true(gain > 0, "the fixture meme should add pollution")
	game.pollution = game.POLLUTION_FLASHBACK_THRESHOLD - 1
	var outcome: ActionOutcomeScript = game.publish_dialogue()
	_assert_true(outcome.flashback, "crossing the threshold should report a flashback")
	_assert_true(outcome.day_transition, "a flashback should end the day")
	_assert_eq(outcome.settlement().get("flashback", false), true, "the settlement should carry the flashback")


func test_publish_without_actions_left_spends_nothing() -> void:
	var game := _ready_to_publish()
	var money_before: int = game.money
	game.actions_remaining = 0
	var outcome: ActionOutcomeScript = game.publish_dialogue()
	_assert_true(not outcome.succeeded, "publishing with no actions left should fail")
	_assert_eq(outcome.feedback_key, ActionOutcomeScript.PUBLISH_NO_ACTION, "it should name the no-action feedback")
	_assert_eq(outcome.settlement(), {}, "a failed publish should need no settlement")
	_assert_eq(game.money, money_before, "a failed publish should add no money")


func test_fusion_reports_fused_meme_and_spent_action() -> void:
	var game := _ready_to_fuse()
	var actions_before: int = game.actions_remaining
	var outcome: ActionOutcomeScript = game.fuse_memes()
	var fused: Dictionary = game.completed_memes[0]
	_assert_true(outcome.succeeded, "two different memes should fuse")
	_assert_true(outcome.spent_action, "fusing should spend an action")
	_assert_eq(outcome.feedback_key, ActionOutcomeScript.FUSION_DONE, "a fusion should name the done feedback")
	_assert_eq(outcome.selected_meme_id, str(fused.get("id", "")), "the fused meme should become the selection")
	_assert_eq(outcome.feedback_detail, str(fused.get("title", "")), "the feedback should carry the fused title")
	_assert_eq(outcome.settlement(), {
		"day_transition": false,
		"flashback": false,
		"actions_before": actions_before,
		"actions_after": actions_before - 1,
	}, "the settlement should carry the spent action")


func test_fusion_of_unready_slots_spends_nothing() -> void:
	var game := _ready_to_fuse()
	game.fusion_slots = {"left": "meme-left"}
	var actions_before: int = game.actions_remaining
	var outcome: ActionOutcomeScript = game.fuse_memes()
	_assert_true(not outcome.succeeded, "one slot should not fuse")
	_assert_true(not outcome.spent_action, "a failed fusion should not spend an action")
	_assert_eq(outcome.feedback_key, ActionOutcomeScript.FUSION_REJECTED, "a failed fusion should name the rejected feedback")
	_assert_eq(outcome.settlement(), {}, "a failed fusion should need no settlement")
	_assert_eq(game.actions_remaining, actions_before, "the action count should stay the same")


func test_fusion_of_already_fused_pair_spends_nothing() -> void:
	var game := _ready_to_fuse()
	_assert_true(game.fuse_memes().succeeded, "the first fusion should work")
	game.place_meme_in_fusion_slot("left", "meme-left")
	game.place_meme_in_fusion_slot("right", "meme-right")
	var actions_before: int = game.actions_remaining
	var outcome: ActionOutcomeScript = game.fuse_memes()
	_assert_true(not outcome.succeeded, "the same pair should not fuse twice")
	_assert_eq(outcome.feedback_key, ActionOutcomeScript.FUSION_REJECTED, "a repeated pair should name the rejected feedback")
	_assert_eq(game.actions_remaining, actions_before, "a repeated pair should not spend an action")


func _ready_to_fuse() -> RefCounted:
	var game := Harness.new_state()
	game.completed_memes = [
		{"id": "meme-left", "title": "左梗", "text": "左", "tags": [], "rarity": 1, "pollution_bias": 1, "fusion_level": 0, "unit_count": 1},
		{"id": "meme-right", "title": "右梗", "text": "右", "tags": [], "rarity": 1, "pollution_bias": 1, "fusion_level": 0, "unit_count": 1},
	]
	game.fusion_slots = {}
	game.place_meme_in_fusion_slot("left", "meme-left")
	game.place_meme_in_fusion_slot("right", "meme-right")
	return game


func _ready_to_publish() -> RefCounted:
	var game := Harness.new_state()
	game.notebook_tokens = [
		_note_token("subject-1", "我", "speaker.self", ["subject"], "本账号", "患者", "你"),
		_note_token("action-1", "看见", "perceive.see", ["action"], "捕获", "报告", "记得"),
		_note_token("object-1", "塔", "place.tower", ["object"], "信号塔", "病区", "出口"),
	]
	game.completed_memes = [_meme()]
	game.place_meme_in_blank("blank_1", "m-publish")
	return game


func _note_token(token_id: String, text: String, lexeme_id: String, roles: Array, phone_surface: String, doctor_surface: String, doll_surface: String) -> Dictionary:
	return {
		"id": token_id,
		"text": text,
		"lexeme_id": lexeme_id,
		"grammar_roles": roles,
		"phone_surface": phone_surface,
		"doctor_surface": doctor_surface,
		"doll_surface": doll_surface,
		"tags": ["test"],
		"rarity": 1,
		"pollution_stage": 0,
		"used_worlds": [],
	}


func _meme() -> Dictionary:
	return {
		"id": "m-publish",
		"text": "本账号捕获信号塔。",
		"clean_text": "我看见塔。",
		"token_ids": ["subject-1", "action-1", "object-1"],
		"lexeme_ids": ["speaker.self", "perceive.see", "place.tower"],
		"tags": ["test"],
		"rarity": 2,
		"pollution_bias": 1,
		"fusion_level": 0,
	}


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s. Expected %s, got %s" % [message, str(expected), str(actual)])
