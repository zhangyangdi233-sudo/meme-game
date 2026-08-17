extends SceneTree

var _failures: Array[String] = []
var _state_script: Script = null


func _init() -> void:
	_state_script = load("res://scripts/meme_game_state.gd") as Script
	_assert_true(_state_script != null, "meme game state script should exist")
	if _state_script != null:
		test_pollution_alone_controls_first_floor_threshold()
		test_sixty_percent_advances_only_from_a_safe_boundary()
		test_each_prerequisite_requires_a_clue_before_collection()
		test_clues_without_physical_items_do_not_unlock_the_hidden_floor()
		test_floor_three_without_hidden_route_enters_normal_ending()
		test_floor_three_with_hidden_route_enters_unregistered_floor_four()
		test_v5_save_round_trip_preserves_hidden_language_state()
		test_v1_floor_five_save_cannot_bypass_the_hidden_route()
		test_random_dialogue_garble_is_capped_and_preserves_punctuation()
		test_floor_transition_request_waits_for_an_explicit_boundary()
		test_effective_pollution_actions_queue_floor_transitions()
		test_history_is_view_only_authored_data_and_survives_save()
	if _failures.is_empty():
		print("language corruption state tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_pollution_alone_controls_first_floor_threshold() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	game.pollution = 24
	game.needs_day_settlement = true
	_assert_true(game.settle_day_if_needed(), "a requested day settlement should run")
	_assert_eq(game.tower_floor, 1, "24% pollution must not bypass the first threshold")

	game.pollution = 25
	game.needs_day_settlement = true
	_assert_true(game.settle_day_if_needed(), "the next requested day settlement should run")
	_assert_eq(game.tower_floor, 2, "25% pollution should advance floor one at a safe boundary")


func test_sixty_percent_advances_only_from_a_safe_boundary() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	game.tower_floor = 2
	game.pollution = 59
	_assert_eq(game.tower_floor, 2, "changing pollution during a scene must not move the player immediately")
	game.needs_day_settlement = true
	game.settle_day_if_needed()
	_assert_eq(game.tower_floor, 2, "59% pollution should remain on floor two")

	game.pollution = 60
	_assert_eq(game.tower_floor, 2, "reaching 60% must wait for a complete-scene boundary")
	game.needs_day_settlement = true
	game.settle_day_if_needed()
	_assert_eq(game.tower_floor, 3, "60% pollution should advance floor two at day settlement")


func test_each_prerequisite_requires_a_clue_before_collection() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	_assert_eq(game.get_prerequisite_item_ids().size(), 3, "the hidden route should contain one physical prerequisite per normal floor")
	for floor_number in [1, 2, 3]:
		var item: Dictionary = game.get_prerequisite_item_for_floor(floor_number)
		var item_id := str(item.get("id", ""))
		_assert_true(not item_id.is_empty(), "each floor should author a stable prerequisite ID")
		_assert_true(not game.collect_prerequisite_item(item_id), "an undisclosed prerequisite cannot be collected before the NPC clue")
		_assert_true(game.reveal_prerequisite_item_for_floor(floor_number), "the floor NPC should be able to reveal the physical item")
		_assert_true(game.collect_prerequisite_item(item_id), "the revealed physical item should be collectible once")
		_assert_true(not game.collect_prerequisite_item(item_id), "the same physical item cannot be collected twice")
	_assert_true(game.is_hidden_layer_unlocked(), "all three collected physical items should unlock the hidden route")


func test_clues_without_physical_items_do_not_unlock_the_hidden_floor() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	for floor_number in [1, 2, 3]:
		_assert_true(game.reveal_prerequisite_item_for_floor(floor_number), "each clue should be revealable once")
	_assert_true(not game.is_hidden_layer_unlocked(), "three spoken clues must not substitute for finding the three actual items")


func test_floor_three_without_hidden_route_enters_normal_ending() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	game.tower_floor = 3
	game.pollution = 80
	_assert_true(game.has_method("complete_floor_three"), "state should expose the formal floor-three ending boundary")
	if not game.has_method("complete_floor_three"):
		return
	_assert_eq(game.complete_floor_three(), "floor-three-task-incomplete", "the floor-three ultimate task must gate every ending")
	game.free_sentence_units = ["门", "可", "以", "打", "开"]
	game.submit_free_sentence("zh")
	_assert_true(game.floor3_task_complete, "the door rule should complete the floor-three ultimate task")
	_assert_eq(game.complete_floor_three(), "normal-ending", "80% pollution alone must not enter the hidden floor")
	_assert_eq(game.tower_floor, 3, "normal ending should not pretend the hidden floor was entered")
	_assert_true(game.ending_unlocked, "formal floor-three completion should unlock the normal ending")
	_assert_eq(game.ending_route, "normal", "the normal ending route should be explicit in save state")


func test_floor_three_with_hidden_route_enters_unregistered_floor_four() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	game.tower_floor = 3
	game.pollution = 80
	for floor_number in [1, 2, 3]:
		var item: Dictionary = game.get_prerequisite_item_for_floor(floor_number)
		game.reveal_prerequisite_item_for_floor(floor_number)
		game.collect_prerequisite_item(str(item.get("id", "")))
	game.floor3_task_complete = true
	_assert_eq(game.complete_floor_three(), "hidden-floor", "80% pollution plus all three physical items should enter floor four")
	_assert_eq(game.tower_floor, 4, "the preserved fourth floor should become the hidden unregistered floor")
	_assert_true(not game.ending_unlocked, "entering floor four should not render the normal ending")
	_assert_eq(game.ending_route, "hidden", "the hidden route should survive save and ending routing")


func test_v5_save_round_trip_preserves_hidden_language_state() -> void:
	var source: RefCounted = _state_script.new()
	source.new_run()
	source.pollution = 73
	source.reveal_prerequisite_item_for_floor(1)
	source.collect_prerequisite_item("artifact_named_lamp_tag")
	var save_data: Dictionary = source.to_save_data()
	_assert_eq(int(save_data.get("version", 0)), 5, "tutorial and language-bridge saves should use version five")

	var restored: RefCounted = _state_script.new()
	_assert_true(restored.load_save_data(save_data), "a version-five save should load")
	_assert_eq(restored.pollution, 73, "pollution should survive the version-five round trip")
	_assert_true("artifact_named_lamp_tag" in restored.revealed_prerequisite_item_ids, "the NPC clue should survive save restoration")
	_assert_true("artifact_named_lamp_tag" in restored.collected_prerequisite_item_ids, "the physical prerequisite should survive save restoration")


func test_v1_floor_five_save_cannot_bypass_the_hidden_route() -> void:
	var restored: RefCounted = _state_script.new()
	var legacy_save := {
		"version": 1,
		"state": {
			"tower_floor": 5,
			"pollution": 120,
			"owned_meme_frames": 2,
			"owned_communication_items": [{"id": "old_item", "charges": 3}],
		},
	}
	_assert_true(restored.load_save_data(legacy_save), "a version-one save should migrate instead of being rejected")
	_assert_eq(restored.tower_floor, 3, "an old floor-five save must return to floor three without hidden proof")
	_assert_eq(restored.pollution, 100, "migrated pollution should be clamped to the canonical range")
	_assert_eq(restored.owned_meme_frames, 2, "unspent meme frames should survive migration")
	_assert_true(not restored.is_hidden_layer_unlocked(), "old floor number and merchant data must not unlock floor four")
	_assert_true(not restored.has_method("get_daily_communication_item"), "removed merchant inventory should not remain active after migration")


func test_random_dialogue_garble_is_capped_and_preserves_punctuation() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	game.pollution = 100
	_assert_true(game.start_typed_reality_conversation("floor1npc0", "npc", "迟到者"), "an existing NPC conversation should start")
	var choice_id := str(game.conversation_choices[0].get("id", ""))
	_assert_true(game.select_typed_reality_choice(choice_id), "an existing response should enter typed delivery")
	while game.conversation_phase == "typing":
		game.advance_typed_reality_character()
	for unit in game.conversation_revealed_units:
		var clean_unit := str(unit.get("clean", ""))
		if bool(unit.get("corrupted", false)):
			_assert_true(int(unit.get("roll", 100)) < 65, "random corruption must use a hard 65% probability cap")
		if clean_unit in ["，", "。", "！", "？", ",", ".", "!", "?", "；", ";", "：", ":"]:
			_assert_true(not bool(unit.get("corrupted", false)), "punctuation must remain readable at 100% pollution")


func test_floor_transition_request_waits_for_an_explicit_boundary() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	game.pollution = 25
	_assert_true(game.has_method("request_floor_transition_for_pollution"), "state should separate threshold detection from scene changes")
	_assert_true(game.has_method("resolve_floor_transition_at_boundary"), "state should expose an explicit safe-boundary transition")
	if not game.has_method("request_floor_transition_for_pollution") or not game.has_method("resolve_floor_transition_at_boundary"):
		return
	_assert_eq(game.request_floor_transition_for_pollution(), 2, "25% should request floor two")
	_assert_eq(game.tower_floor, 1, "requesting a transition must not interrupt the current line")
	_assert_eq(game.resolve_floor_transition_at_boundary(), 2, "the next explicit boundary should apply the request")
	_assert_eq(game.tower_floor, 2, "the boundary should move the player exactly once")
	_assert_eq(game.pending_floor_transition, 0, "applying a transition should clear its pending target")


func test_effective_pollution_actions_queue_floor_transitions() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	game.pollution = 24
	game.completed_memes = [{
		"id": "threshold-sentence",
		"text": "屏幕替我说话。",
		"tags": ["空位"],
		"rarity": 1,
		"pollution_bias": 0,
		"fusion_level": 0,
	}]
	_assert_true(game.place_meme_in_blank("blank_1", "threshold-sentence"), "placing a composed sentence should remain free")
	_assert_true(game.confirm_dialogue(), "publishing should use the effective action flow")
	_assert_true(game.pollution >= 25, "publishing should raise pollution through the canonical path")
	_assert_eq(game.pending_floor_transition, 2, "crossing 25% during publication should queue level two")
	_assert_eq(game.tower_floor, 1, "the queued transition must wait for the UI or day boundary")


func test_history_is_view_only_authored_data_and_survives_save() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	_assert_true(game.has_method("record_history_line"), "state should accept authored view-only history lines")
	_assert_true(game.has_method("get_history_entries"), "state should expose history as a read-only copy")
	if not game.has_method("record_history_line") or not game.has_method("get_history_entries"):
		return
	_assert_true(game.record_history_line({
		"lineId": "shared_safe_doll",
		"originalSpeaker": "玩偶",
		"currentSpeaker": "医生",
		"originalText": "我只是想让你留在安全的地方。",
		"displayText": "我只是想让你留在{del}安全{/del}{ins}稳定{/ins}的地方。",
		"revisionStage": 2,
		"revisionMarkup": "replace",
	}), "a complete authored history line should be recorded")
	_assert_true(not game.record_history_line({"lineId": ""}), "history lines without a stable ID should be rejected")
	var view: Array = game.get_history_entries()
	_assert_eq(view.size(), 1, "history should contain the authored line once")
	view[0]["displayText"] = "tampered"
	_assert_true(str(game.get_history_entries()[0].get("displayText", "")) != "tampered", "the history viewer must not mutate saved history")

	var restored: RefCounted = _state_script.new()
	_assert_true(restored.load_save_data(game.to_save_data()), "history should participate in the normal save flow")
	_assert_eq(restored.get_history_entries().size(), 1, "authored history should survive save restoration")


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
