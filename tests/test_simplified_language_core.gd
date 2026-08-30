extends SceneTree

var _failures: Array[String] = []
var _state_script: Script


func _init() -> void:
	_run()


func _run() -> void:
	_state_script = load("res://scripts/meme_game_state.gd") as Script
	_assert_true(_state_script != null, "state script should load")
	if _state_script != null:
		test_only_money_and_pollution_are_gameplay_metrics()
		test_publish_result_is_plain_money_and_pollution()
		test_hidden_floor_requires_eighty_and_complete_route_at_day_boundary()
	if _failures.is_empty():
		print("simplified language core tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_only_money_and_pollution_are_gameplay_metrics() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	_assert_eq(game.get_gameplay_metrics().keys(), ["money", "pollution"], "only money and pollution should be exposed as gameplay metrics")
	var property_names: Array[String] = []
	for property: Dictionary in game.get_property_list():
		property_names.append(str(property.get("name", "")))
	for removed_name in ["heat", "clarity", "permanent_modifiers", "owned_tarot_ids", "pending_ascent_reward_choices"]:
		_assert_true(removed_name not in property_names, "%s should be removed from live run state" % removed_name)
	for removed_method in ["get_daily_signal_contract", "get_active_tarot_combos", "choose_ascent_reward"]:
		_assert_true(not game.has_method(removed_method), "%s should be removed with the old card-scoring layer" % removed_method)


func test_publish_result_is_plain_money_and_pollution() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	var meme := {
		"id": "plain-result",
		"title": "明天没有站名",
		"text": "明天没有站名",
		"tags": ["空位"],
		"rarity": 2,
		"pollution_bias": 1,
		"fusion_level": 0,
	}
	var preview: Dictionary = game.get_publish_result(meme)
	var keys: Array = preview.keys()
	keys.sort()
	_assert_eq(keys, ["money_gain", "pollution_gain"], "publish preview should contain exactly the two readable outcomes")
	_assert_true(int(preview.get("money_gain", 0)) > 0, "publishing should explain how money is earned")
	_assert_true(int(preview.get("pollution_gain", 0)) > 0, "publishing should expose pollution growth before confirmation")
	var money_before: int = game.money
	var pollution_before: int = game.pollution
	game.completed_memes = [meme]
	game.place_meme_in_blank("blank_1", "plain-result")
	_assert_true(game.confirm_dialogue(), "a complete meme should publish")
	_assert_eq(game.money, money_before + int(preview["money_gain"]), "publication should add exactly the previewed money")
	_assert_eq(game.pollution, pollution_before + int(preview["pollution_gain"]), "publication should add exactly the previewed pollution")
	_assert_eq(game.last_publish_result, preview, "the last result should remain readable without a score breakdown")
	var record: Dictionary = game.published_memes[0]
	_assert_true(not record.has("score") and not record.has("score_breakdown") and not record.has("heat_gain"), "published records should not retain hidden Balatro-style values")


func test_hidden_floor_requires_eighty_and_complete_route_at_day_boundary() -> void:
	var incomplete: RefCounted = _state_script.new()
	incomplete.new_run()
	incomplete.tower_floor = 3
	incomplete.pollution = 80
	incomplete.floor3_task_complete = true
	incomplete.actions_remaining = 0
	incomplete.needs_day_settlement = true
	_assert_true(incomplete.settle_day_if_needed(), "the third-floor day should settle")
	_assert_eq(incomplete.tower_floor, 3, "80 pollution alone must not reveal the hidden floor")
	_assert_eq(incomplete.ending_route, "normal", "missing prerequisites must resolve to the normal ending")

	var complete: RefCounted = _state_script.new()
	complete.new_run()
	complete.tower_floor = 3
	complete.pollution = 80
	complete.floor3_task_complete = true
	for floor_number in [1, 2, 3]:
		complete.reveal_prerequisite_item_for_floor(floor_number)
		complete.collect_prerequisite_item(str(complete.get_prerequisite_item_for_floor(floor_number).get("id", "")))
	complete.actions_remaining = 0
	complete.needs_day_settlement = true
	_assert_true(complete.settle_day_if_needed(), "a fully prepared third-floor day should settle")
	_assert_eq(complete.tower_floor, 4, "the complete 80-percent route should enter the hidden fourth floor on the next day")
	_assert_eq(complete.ending_route, "hidden", "the hidden floor should select the special ending route")


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
