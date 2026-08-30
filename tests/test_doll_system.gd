extends SceneTree

const Harness = preload("res://tests/harness/minimal_game_harness.gd")

var _failures: Array[String] = []
var _state_script: Script
var _content_script: Script


func _init() -> void:
	_state_script = load("res://scripts/meme_game_state.gd") as Script
	_content_script = load("res://scripts/narrative/language_corruption_content.gd") as Script
	_assert_true(_state_script != null and _content_script != null, "doll system dependencies should load")
	if _state_script != null and _content_script != null:
		test_three_authored_doll_appearances_offer_tutorial_responses()
		test_doll_choice_guides_once_without_spending_an_action()
		test_pollution_locked_doll_choice_stays_unavailable_until_ready()
		test_ordinary_npc_never_grants_a_meme_frame()
		test_doll_state_round_trips_and_legacy_shop_state_is_normalized()
		test_notebook_craft_preserves_clean_sentence_from_collected_tokens()
	if _failures.is_empty():
		print("doll system tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_three_authored_doll_appearances_offer_tutorial_responses() -> void:
	var doll_ids: Array[String] = []
	for floor_number in [1, 2, 3]:
		var encounter: Dictionary = _content_script.get_doll_encounter_for_floor(floor_number)
		var doll_id := str(encounter.get("doll_id", ""))
		_assert_true(not doll_id.is_empty(), "floor %d should have a stable doll id" % floor_number)
		_assert_true(doll_id not in doll_ids, "doll ids should be unique across floors")
		doll_ids.append(doll_id)
		var turns: Array = encounter.get("turns", [])
		_assert_eq(turns.size(), 1, "each first-pass doll encounter should remain a compact one-turn discovery")
		if turns.is_empty():
			continue
		var choices: Array = (turns[0] as Dictionary).get("choices", [])
		_assert_eq(choices.size(), 3, "each guide appearance should offer three authored tutorial responses")
		for choice: Dictionary in choices:
			_assert_true(not str(choice.get("guide_feedback", "")).is_empty(), "every guide response should explain the next step")
			_assert_true(not choice.has("frame_id") and not choice.has("frame_label"), "guide responses must not retain obsolete frame rewards")
			_assert_true(not str(choice).contains("price"), "guide responses must not expose a shop price")


func test_doll_choice_guides_once_without_spending_an_action() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	var encounter: Dictionary = _content_script.get_doll_encounter_for_floor(1)
	var doll_id := str(encounter.get("doll_id", ""))
	var actions_before: int = game.actions_remaining
	_assert_true(game.start_typed_reality_conversation(doll_id, "doll", "缝线布偶"), "a discovered doll should start its authored conversation")
	var first_choice: Dictionary = game.get_typed_reality_choices()[0]
	var choice_id := str(first_choice.get("id", ""))
	_finish_typed_turn(game, choice_id)
	_assert_eq(game.actions_remaining, actions_before, "tutorial guidance should not consume one of five daily actions")
	_assert_eq(game.owned_meme_frames, 0, "the guide should not grant an obsolete frame")
	_assert_true(doll_id in game.claimed_doll_ids, "the doll should remember that its first guidance was heard")
	_assert_eq(str((game.doll_choice_results.get(doll_id, {}) as Dictionary).get("choice_id", "")), choice_id, "the selected intention should persist")
	_assert_true(bool(game.conversation_reward.get("guided", false)), "the result surface should expose successful guidance")
	_assert_eq(str(game.get_tutorial_step().get("id", "")), "open_social", "first guidance should advance onboarding to the phone")

	var repeat_actions: int = game.actions_remaining
	_assert_true(game.start_typed_reality_conversation(doll_id, "doll", "缝线布偶"), "a claimed guide doll should still be speakable")
	_finish_typed_turn(game, str(game.get_typed_reality_choices()[1].get("id", "")))
	_assert_eq(game.actions_remaining, repeat_actions, "repeated guidance should remain free")
	_assert_eq(game.owned_meme_frames, 0, "repeated guidance must not create frame stock")
	_assert_true(bool(game.conversation_reward.get("duplicate", false)), "repeat dialogue should be identified without replaying tutorial progress")


func test_pollution_locked_doll_choice_stays_unavailable_until_ready() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	game.tower_floor = 3
	game.pollution = 60
	var encounter: Dictionary = _content_script.get_doll_encounter_for_floor(3)
	var doll_id := str(encounter.get("doll_id", ""))
	_assert_true(game.start_typed_reality_conversation(doll_id, "doll", "缝线布偶"), "floor three doll should be available")
	var locked_choice: Dictionary = _choice_with_pollution_gate(game.get_typed_reality_choices())
	_assert_true(not locked_choice.is_empty(), "one floor-three guide response should require reading the polluted structure")
	_assert_true(bool(locked_choice.get("locked", false)), "the gated response should be visibly unavailable below its threshold")
	_assert_true(not game.select_typed_reality_choice(str(locked_choice.get("id", ""))), "a locked doll choice must not be selectable")

	game.reset_typed_reality_conversation()
	game.pollution = int(locked_choice.get("required_pollution_min", 70))
	_assert_true(game.start_typed_reality_conversation(doll_id, "doll", "缝线布偶"), "the same encounter should reopen after the threshold")
	var unlocked_choice: Dictionary = _choice_by_id(game.get_typed_reality_choices(), str(locked_choice.get("id", "")))
	_assert_true(not bool(unlocked_choice.get("locked", true)), "the authored polluted choice should unlock at the required pollution")
	_finish_typed_turn(game, str(unlocked_choice.get("id", "")))
	_assert_true(bool(game.conversation_reward.get("guided", false)), "the unlocked response should complete guidance without a frame reward")


func test_ordinary_npc_never_grants_a_meme_frame() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	_assert_true(game.start_typed_reality_conversation("floor1_npc0", "npc", "迟到者"), "ordinary NPC conversation should start")
	while true:
		var choices: Array = game.get_typed_reality_choices()
		_assert_true(not choices.is_empty(), "each ordinary NPC turn should keep an authored response")
		if choices.is_empty():
			break
		_finish_typed_turn(game, str(choices[0].get("id", "")))
		if not game.conversation_can_continue:
			break
		_assert_true(game.continue_typed_reality_conversation(), "ordinary NPC arc should continue without a reward roll")
	_assert_eq(game.owned_meme_frames, 0, "ordinary NPC completion must never grant a frame")
	_assert_true(game.conversation_reward.is_empty(), "ordinary NPC result should have no hidden reward payload")


func test_doll_state_round_trips_and_legacy_shop_state_is_normalized() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	var encounter: Dictionary = _content_script.get_doll_encounter_for_floor(2)
	var doll_id := str(encounter.get("doll_id", ""))
	game.tower_floor = 2
	game.pollution = 30
	_assert_true(game.start_typed_reality_conversation(doll_id, "doll", "缝线布偶"), "floor two doll should start")
	_finish_typed_turn(game, str(game.get_typed_reality_choices()[0].get("id", "")))
	var save_data: Dictionary = game.to_save_data()
	_assert_eq(int(save_data.get("version", 0)), 5, "the tutorial and language bridge should advance the state save version")
	var restored: RefCounted = _state_script.new()
	_assert_true(restored.load_save_data(save_data), "current doll save should load")
	_assert_eq(restored.claimed_doll_ids, game.claimed_doll_ids, "claimed dolls should survive save/load")
	_assert_eq(restored.doll_choice_results, game.doll_choice_results, "doll choices should survive save/load")
	_assert_true(restored.owned_meme_frame_ids.is_empty(), "current guide state should not create frame provenance")

	var legacy_state: Dictionary = save_data.get("state", {}).duplicate(true)
	legacy_state.erase("claimed_doll_ids")
	legacy_state.erase("doll_choice_results")
	legacy_state.erase("owned_meme_frame_ids")
	legacy_state["owned_meme_frames"] = 2
	legacy_state["active_app"] = "shop"
	legacy_state["active_app_window"] = "shop"
	legacy_state["daily_meme_frame_bought"] = true
	legacy_state["npc_meme_frame_reward_attempt_keys"] = ["1|npc0"]
	var legacy_save := {"version": 3, "state": legacy_state}
	var migrated: RefCounted = _state_script.new()
	_assert_true(migrated.load_save_data(legacy_save), "V3 shop-era save should migrate without losing legitimate frame stock")
	_assert_eq(migrated.active_app, "social", "removed shop app should normalize to social")
	_assert_eq(migrated.active_app_window, "social", "removed shop window should not restore as an invisible active window")
	_assert_eq(migrated.owned_meme_frame_ids.size(), 2, "legacy frame count should receive neutral provenance ids")
	_assert_true(not migrated.has_method("buy_daily_meme_frame"), "removed purchases must not remain callable after migration")
	_assert_true(not migrated.has_method("get_npc_meme_frame_reward_rules"), "ordinary NPC reward rules must be gone")


func test_notebook_craft_preserves_clean_sentence_from_collected_tokens() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	_assert_true(game.pick_token("doll-flow-post", Harness.craft_token("subject", "我", "subject", "本账号", "患者")), "test setup should add one subject")
	_assert_true(game.pick_token("doll-flow-post", Harness.craft_token("action", "看见", "action", "捕获", "报告")), "test setup should add one action")
	_assert_true(game.pick_token("doll-flow-post", Harness.craft_token("object", "塔", "object", "信号塔", "病区")), "test setup should add one object")
	_assert_true(game.place_token_in_slot("subject", "doll-flow-post-subject-1"), "subject should enter its sentence slot")
	_assert_true(game.place_token_in_slot("action", "doll-flow-post-action-1"), "action should enter its sentence slot")
	_assert_true(game.place_token_in_slot("object", "doll-flow-post-object-1"), "object should enter its sentence slot")
	var completed_before: int = game.completed_memes.size()
	_assert_true(game.confirm_craft(), "three collected words should craft one complete sentence")
	_assert_eq(game.completed_memes.size(), completed_before + 1, "crafting should add one completed meme")
	_assert_eq(str(game.completed_memes[0].get("clean_text", "")), "我看见塔。", "crafted data should preserve the clean sentence")


func _finish_typed_turn(game: RefCounted, choice_id: String) -> void:
	_assert_true(game.select_typed_reality_choice(choice_id), "authored choice should be selectable")
	while game.conversation_phase == "typing":
		game.advance_typed_reality_character()


func _choice_with_pollution_gate(choices: Array) -> Dictionary:
	for choice: Dictionary in choices:
		if int(choice.get("required_pollution_min", 0)) > 0:
			return choice
	return {}


func _choice_by_id(choices: Array, choice_id: String) -> Dictionary:
	for choice: Dictionary in choices:
		if str(choice.get("id", "")) == choice_id:
			return choice
	return {}


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
