extends SceneTree
## 瀑布流拾字系统回归测试:字池完整性(三语言)、主谓宾覆盖、
## 每日首拾计费、存档往返、帖内高亮/灰化、评论区、笔记本字库、飞行动画层。

const PoolScript = preload("res://scripts/narrative/pickup_char_pool.gd")
const StateScript = preload("res://scripts/meme_game_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _run()
	if _failures.is_empty():
		print("pickup char flow tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_pool_integrity()
	_test_state_flow()
	_test_flight_layer_determinism()
	await _test_ui_flow()


func _test_pool_integrity() -> void:
	for locale in ["zh", "ja", "en"]:
		var report: Dictionary = PoolScript.validate(locale)
		_assert_true(bool(report.get("ok", false)), "pickup pool for %s should validate; problems: %s" % [locale, "; ".join(report.get("problems", []))])
		var counts: Dictionary = PoolScript.role_word_counts(locale)
		_assert_true(int(counts.get("subject", 0)) >= 2, "%s pool should form at least 2 subject words" % locale)
		_assert_true(int(counts.get("verb", 0)) >= 2, "%s pool should form at least 2 verb words" % locale)
		_assert_true(int(counts.get("object", 0)) >= 2, "%s pool should form at least 2 object words" % locale)
		_assert_true(int(counts.get("negation", 0)) >= 1, "%s pool should include a negation word (文字游戏-style operator)" % locale)

	var zh_pool: Array = PoolScript.get_unit_pool("zh")
	_assert_true(zh_pool.size() >= 20 and zh_pool.size() <= 30, "zh pool should hold 20-30 single characters, got %d" % zh_pool.size())
	for required in ["门", "可", "以", "打", "开", "出", "口", "存", "在", "不", "没", "灯", "亮"]:
		_assert_true(required in zh_pool, "zh pool must cover rule-engine unit %s" % required)
	for unit_value in zh_pool:
		_assert_true(str(unit_value).length() == 1, "zh pickup units must be single characters, got %s" % unit_value)
	_assert_true(PoolScript.get_unit_pool("ja").size() >= 18, "ja pool should hold at least 18 lexical units")
	var en_pool: Array = PoolScript.get_unit_pool("en")
	_assert_true(en_pool.size() >= 20 and en_pool.size() <= 30, "en pool should hold 20-30 words")

	# 词典一致性:合词单位必须全部可拾取(validate 已覆盖),再抽查规则句所需词。
	var zh_dictionary: Dictionary = PoolScript.get_word_dictionary("zh")
	for required_word in ["门", "可以", "打开", "出口", "存在", "灯", "亮", "不", "没"]:
		_assert_true(zh_dictionary.has(required_word), "zh word dictionary must contain %s for the rule engine" % required_word)


func _test_state_flow() -> void:
	var game = StateScript.new()
	game.new_run()
	_assert_eq_int(game.actions_remaining, 5, "a new run should start with five actions")

	var first: Dictionary = game.pick_social_char("floor_13", "门", "zh")
	_assert_true(bool(first.get("picked", false)), "first pickup should succeed")
	_assert_true(bool(first.get("action_spent", false)), "the day's first pickup should cost one action")
	_assert_eq_int(game.actions_remaining, 4, "action count should drop to four")

	var second: Dictionary = game.pick_social_char("floor_13", "开", "zh")
	_assert_true(bool(second.get("picked", false)), "second pickup should succeed")
	_assert_true(not bool(second.get("action_spent", false)), "same-day follow-up pickups should be free")
	_assert_eq_int(game.actions_remaining, 4, "free pickups must not consume actions")

	var duplicate: Dictionary = game.pick_social_char("floor_13", "门", "zh")
	_assert_true(not bool(duplicate.get("picked", false)), "duplicate units should be rejected")
	_assert_eq_text(str(duplicate.get("reason", "")), "duplicate", "duplicate pickup should report the duplicate reason")

	var invalid: Dictionary = game.pick_social_char("floor_13", "龍", "zh")
	_assert_eq_text(str(invalid.get("reason", "")), "not-in-pool", "units outside the pool should be rejected")

	var wrong_post: Dictionary = game.pick_social_char("floor_13", "灯", "zh")
	_assert_eq_text(str(wrong_post.get("reason", "")), "not-in-post", "units not seeded in that post's content should be rejected")

	_assert_true(game.is_social_char_collected("门", "zh"), "collected units should be queryable")
	_assert_true("门" in game.get_collected_char_units("zh"), "collected list should include picked units")
	_assert_true(game.get_collected_char_units("en").is_empty(), "locales should not leak into each other")

	# 存档往返。
	var save_data: Dictionary = game.to_save_data()
	var restored = StateScript.new()
	_assert_true(restored.load_save_data(save_data), "save data should load")
	_assert_true(restored.is_social_char_collected("门", "zh"), "collected units should survive a save round-trip")
	_assert_true(restored.is_social_char_collected("开", "zh"), "all collected units should survive")
	_assert_eq_int(int(restored.last_char_pick_day), int(game.last_char_pick_day), "last pick day should survive the round-trip")

	# 次日首拾重新计费。
	game.needs_day_settlement = true
	game.settle_day_if_needed()
	var next_day: Dictionary = game.pick_social_char("self_call", "我", "zh")
	_assert_true(bool(next_day.get("picked", false)), "next-day pickup should succeed")
	_assert_true(bool(next_day.get("action_spent", false)), "a new day's first pickup should cost an action again")

	# 无行动时的首拾必须被拒绝。
	var drained = StateScript.new()
	drained.new_run()
	drained.actions_remaining = 0
	var blocked: Dictionary = drained.pick_social_char("floor_13", "门", "zh")
	_assert_true(not bool(blocked.get("picked", false)), "first pickup with no actions must fail")
	_assert_eq_text(str(blocked.get("reason", "")), "no-actions", "the refusal reason should be no-actions")

	# 首拾恰好花掉最后一次行动 → 应触发日结标记。
	var last_action = StateScript.new()
	last_action.new_run()
	last_action.actions_remaining = 1
	var final_pick: Dictionary = last_action.pick_social_char("floor_13", "门", "zh")
	_assert_true(bool(final_pick.get("picked", false)), "the last action should still allow a first pickup")
	_assert_eq_int(last_action.actions_remaining, 0, "the last action should be consumed")
	_assert_true(last_action.needs_day_settlement, "spending the final action on a pickup should schedule day settlement")


func _test_flight_layer_determinism() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/pickup_flight_layer.gd")
	_assert_true(source.length() > 0, "flight layer source should be readable")
	for forbidden in ["randf", "randi", "randomize("]:
		_assert_true(not source.contains(forbidden), "pickup flight layer must stay deterministic; found %s" % forbidden)


func _test_ui_flow() -> void:
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "pickup test should load the main scene")
	if scene == null:
		return
	var game_root := scene.instantiate()
	root.add_child(game_root)
	game_root._locale.set_locale("zh")
	game_root.new_game()
	await process_frame

	var flight_layer := _find_node_by_name(game_root, "PickupFlightLayer")
	_assert_true(flight_layer != null, "the pickup flight layer should exist in the scene")

	game_root._open_social_post(0)
	await process_frame
	var pickup_line := _find_node_by_name(game_root, "SocialPickupLineText") as RichTextLabel
	_assert_true(pickup_line != null, "post detail should show the seeded pickup line")
	if pickup_line != null:
		_assert_true(pickup_line.text.contains("[url=门]"), "the seeded 门 should render as a clickable unit")
	_assert_true(_find_node_by_name(game_root, "SocialCommentsHeader") != null, "post detail should show the anonymous comments header")
	_assert_true(_find_node_by_name(game_root, "SocialCommentText0") != null, "post detail should show at least one comment")
	_assert_true(_find_node_by_name(game_root, "SocialPickupCostHint") != null, "post detail should explain the first-pickup action cost")

	# bbcode 转义不再级联。
	_assert_eq_text(game_root._escape_bbcode("[b]x[/b]"), "[lb]b[rb]x[lb]/b[rb]", "bbcode escaping must not cascade")

	var actions_before: int = game_root.game.actions_remaining
	pickup_line.meta_clicked.emit("门")
	await process_frame
	_assert_true(game_root.game.is_social_char_collected("门", "zh"), "clicking a highlighted unit through the real meta signal should collect it")
	_assert_eq_int(game_root.game.actions_remaining, actions_before - 1, "the first pickup should cost one action")
	if flight_layer != null:
		_assert_true(bool(flight_layer.is_animating()), "a successful pickup should start the flight animation")
		flight_layer.finish_all_immediately()

	# 飞行目标必须锚定真实的笔记本窗口,并跟随窗口移动。
	game_root.game.set_active_app("notebook")
	game_root._render()
	await process_frame
	var target_before: Vector2 = game_root._notebook_flight_target()
	_assert_true(game_root._notebook_window_control() != null, "the notebook window control must resolve via its app: key")
	_assert_true(game_root._move_window_for_test("app:notebook", Vector2(40, 24)), "the notebook window should be movable in tests")
	var target_after: Vector2 = game_root._notebook_flight_target()
	_assert_true((target_after - target_before).is_equal_approx(Vector2(40, 24)), "the flight target must track the notebook window position")

	# 自然飞行完成:pickup_landed 信号必须发出,并触发笔记本受击。
	var landed_units: Array = []
	flight_layer.pickup_landed.connect(func(unit: String) -> void: landed_units.append(unit))
	game_root._on_pickup_unit_meta("开", "floor_13")
	var flight_budget := 100000
	while flight_budget > 0 and landed_units.is_empty():
		flight_budget -= 1
		await process_frame
	_assert_true(not landed_units.is_empty(), "a natural flight must emit pickup_landed")
	_assert_true(game_root._notebook_squash_tween != null, "landing must squash the notebook window")
	_assert_true(game_root.game.is_social_char_collected("开", "zh"), "the free same-day pickup should collect its unit")

	game_root._open_social_post(0)
	await process_frame
	pickup_line = _find_node_by_name(game_root, "SocialPickupLineText") as RichTextLabel
	if pickup_line != null:
		_assert_true(not pickup_line.text.contains("[url=门]"), "a collected unit must stop being clickable")
		_assert_true(pickup_line.text.contains("[color=#8b8f84]门[/color]"), "a collected unit should stay as a gray residue in the post")

	game_root.game.set_active_app("notebook")
	game_root._render()
	await process_frame
	var char_flow := _find_node_by_name(game_root, "NotebookCharFlow")
	_assert_true(char_flow != null, "the notebook should show the collected character bank")
	var tile_found := false
	if char_flow != null:
		for child in char_flow.get_children():
			if child is Button and (child as Button).text == "门":
				tile_found = true
	_assert_true(tile_found, "the collected 门 should appear as a notebook tile")

	# 英文与日文版本:埋字句存在且可拾取单位是完整单词/词汇单位。
	game_root._locale.set_locale("en")
	game_root._open_social_post(0)
	await process_frame
	var english_line := _find_node_by_name(game_root, "SocialPickupLineText") as RichTextLabel
	_assert_true(english_line != null and english_line.text.contains("[url=door]"), "the English line should offer whole-word pickups")
	if english_line != null:
		_assert_true(not english_line.text.contains("[url=doo]"), "English matching must respect word boundaries")
		_assert_true(english_line.text.contains("[url=the]The[/url]"), "sentence-initial capitalized words must stay pickable (case-insensitive matching)")
	var english_comment := _find_node_by_name(game_root, "SocialCommentText0") as RichTextLabel
	_assert_true(english_comment != null and english_comment.text.contains("[url="), "English comments should carry pickable units too")
	var english_pick: Dictionary = game_root.game.pick_social_char("floor_13", "door", "en")
	_assert_true(bool(english_pick.get("picked", false)), "English word pickup should work")

	game_root._locale.set_locale("ja")
	game_root._open_social_post(0)
	await process_frame
	var japanese_line := _find_node_by_name(game_root, "SocialPickupLineText") as RichTextLabel
	_assert_true(japanese_line != null and japanese_line.text.contains("[url=ドア]"), "the Japanese line should offer lexical-unit pickups")
	var japanese_comment := _find_node_by_name(game_root, "SocialCommentText0") as RichTextLabel
	_assert_true(japanese_comment != null and japanese_comment.text.contains("[url="), "Japanese comments should carry pickable units too")

	game_root._locale.set_locale("zh")
	game_root.queue_free()
	await process_frame


func _find_node_by_name(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var found := _find_node_by_name(child, node_name)
		if found != null:
			return found
	return null


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq_int(value: int, expected: int, message: String) -> void:
	if value != expected:
		_failures.append("%s (got %d, expected %d)" % [message, value, expected])


func _assert_eq_text(value: String, expected: String, message: String) -> void:
	if value != expected:
		_failures.append("%s (got %s, expected %s)" % [message, value, expected])
