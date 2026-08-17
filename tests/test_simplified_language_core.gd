extends SceneTree

var _failures: Array[String] = []
var _state_script: Script


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	_state_script = load("res://scripts/meme_game_state.gd") as Script
	_assert_true(_state_script != null, "state script should load")
	if _state_script != null:
		test_only_money_and_pollution_are_gameplay_metrics()
		test_publish_result_is_plain_money_and_pollution()
		test_hidden_floor_requires_eighty_and_complete_route_at_day_boundary()
	await test_removed_systems_are_absent_from_runtime_ui()
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


func test_removed_systems_are_absent_from_runtime_ui() -> void:
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "main scene should load")
	if scene == null:
		return
	var root := scene.instantiate()
	get_root().add_child(root)
	await process_frame
	root._locale.set_locale("zh")
	root.new_game()
	root.game.set_active_app("babel")
	root._render()
	var all_text := _collect_control_text(root)
	for removed_copy in ["塔罗", "牌型", "整数倍率", "传播基础", "BABEL-LINK 98", "输入四位缓存编号"]:
		_assert_true(not all_text.contains(removed_copy), "runtime UI should not contain removed copy: %s" % removed_copy)
	for hidden_route_copy in ["已找到的异物", "地点已被说出"]:
		_assert_true(not all_text.contains(hidden_route_copy), "Tower App must not reveal hidden-floor checklist copy: %s" % hidden_route_copy)
	_assert_true(_find_node_by_name(root, "SocialPublishContractPanel") == null, "the card-hand panel should be gone")
	_assert_true(_find_node_by_name(root, "OldWebArchiveCodeInput") == null, "the archive code puzzle should be gone")
	root.game.set_active_app("social")
	root._set_social_screen("publish")
	root._render()
	var publish_text := _collect_control_text(root)
	_assert_true(publish_text.contains("资金") and publish_text.contains("污染"), "the publish screen should preview the two remaining outcomes")
	root.free()


func _collect_control_text(root: Node) -> String:
	var result := ""
	if root is Label or root is Button or root is RichTextLabel or root is LineEdit:
		result += str(root.get("text")) + "\n"
	for child in root.get_children():
		result += _collect_control_text(child)
	return result


func _find_node_by_name(root: Node, wanted_name: String) -> Node:
	if root.name == wanted_name:
		return root
	for child in root.get_children():
		var found := _find_node_by_name(child, wanted_name)
		if found != null:
			return found
	return null


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
