extends SceneTree

var _failures: Array[String] = []
var _state_script: Script


func _init() -> void:
	_run()


func _run() -> void:
	_state_script = load("res://scripts/meme_game_state.gd") as Script
	_assert_true(_state_script != null, "state script should load")
	if _state_script != null:
		test_pollution_is_the_only_gameplay_metric()
		test_hidden_floor_requires_eighty_and_complete_route_at_the_next_interaction()
	if _failures.is_empty():
		print("simplified language core tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_pollution_is_the_only_gameplay_metric() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	game.skip_chapter_one()
	_assert_true(not game.has_method("get_gameplay_metrics"), "no metric besides pollution should be exposed")
	var property_names: Array[String] = []
	for property: Dictionary in game.get_property_list():
		property_names.append(str(property.get("name", "")))
	for removed_name in ["heat", "clarity", "permanent_modifiers", "owned_tarot_ids", "pending_ascent_reward_choices", "money", "actions_remaining"]:
		_assert_true(removed_name not in property_names, "%s should be removed from live run state" % removed_name)
	for removed_method in ["get_daily_signal_contract", "get_active_tarot_combos", "choose_ascent_reward", "get_publish_result"]:
		_assert_true(not game.has_method(removed_method), "%s should be removed with the old scoring layers" % removed_method)


func test_hidden_floor_requires_eighty_and_complete_route_at_the_next_interaction() -> void:
	var incomplete: RefCounted = _state_script.new()
	incomplete.new_run()
	incomplete.skip_chapter_one()
	incomplete.tower_floor = 3
	incomplete.pollution = 80
	incomplete.floor3_task_complete = true
	incomplete.pick_social_char("floor_13", "门", "zh")
	_assert_eq(incomplete.tower_floor, 3, "80 pollution alone must not reveal the hidden floor")
	_assert_eq(incomplete.ending_route, "normal", "missing prerequisites must resolve to the normal ending")

	var complete: RefCounted = _state_script.new()
	complete.new_run()
	complete.skip_chapter_one()
	complete.tower_floor = 3
	complete.pollution = 80
	complete.floor3_task_complete = true
	for floor_number in [1, 2, 3]:
		complete.reveal_prerequisite_item_for_floor(floor_number)
		complete.collect_prerequisite_item(str(complete.get_prerequisite_item_for_floor(floor_number).get("id", "")))
	complete.pick_social_char("floor_13", "门", "zh")
	_assert_eq(complete.tower_floor, 4, "the complete 80-percent route should enter the hidden fourth floor")
	_assert_eq(complete.ending_route, "hidden", "the hidden floor should select the special ending route")


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
