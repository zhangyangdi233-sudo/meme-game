extends SceneTree
## 自由造句台 + 世界规则 + 终极任务 + 玩偶引导的回归测试。

const StateScript = preload("res://scripts/meme_game_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _run()
	if _failures.is_empty():
		print("sentence composer tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_composer_state()
	_test_rule_application_and_tasks()
	_test_save_round_trip()
	await _test_ui_flow()


func _collect_door_sentence_units(game) -> void:
	game.pick_social_char("floor_13", "门", "zh")
	game.pick_social_char("floor_13", "开", "zh")
	game.pick_social_char("floor_13", "打", "zh")
	game.pick_social_char("access_record", "可", "zh")
	game.pick_social_char("access_record", "以", "zh")


func _test_composer_state() -> void:
	var game = StateScript.new()
	game.new_run()
	_assert_true(not game.free_sentence_place("门", "zh"), "uncollected units must not enter the sentence")
	_collect_door_sentence_units(game)
	_assert_true(game.free_sentence_place("门", "zh"), "collected units should be placeable")
	_assert_true(not game.free_sentence_place("门", "zh"), "the same unit cannot be placed twice (bank ghost)")
	_assert_true(game.free_sentence_place("开", "zh"), "a second unit should be placeable")
	_assert_eq_text(game.get_free_sentence_text("zh"), "门开", "Chinese sentences join without separators")
	_assert_true(game.free_sentence_remove(1), "answer tiles can be removed by index")
	_assert_eq_text(game.get_free_sentence_text("zh"), "门", "removal should reflow the sentence")
	game.free_sentence_clear()
	_assert_true(game.get_free_sentence_units().is_empty(), "clear should empty the sentence")

	var empty_submit: Dictionary = game.submit_free_sentence("zh")
	_assert_eq_text(str(empty_submit.get("reason", "")), "empty", "submitting an empty sentence should be refused")

	for unit in ["门", "可", "以", "打", "开"]:
		game.free_sentence_place(unit, "zh")
	var actions_before: int = game.actions_remaining
	var money_before: int = game.money
	var pollution_before: int = game.pollution
	var submit: Dictionary = game.submit_free_sentence("zh")
	_assert_true(bool(submit.get("submitted", false)), "a one-or-more unit sentence can always be posted")
	_assert_eq_text(str(submit.get("tier", "")), "rule", "门可以打开 should land as a rule")
	_assert_eq_int(game.actions_remaining, actions_before - 1, "posting costs exactly one action")
	_assert_true(game.money > money_before, "posting should pay out funds")
	_assert_true(game.pollution > pollution_before, "posting should raise pollution")
	_assert_true(game.get_free_sentence_units().is_empty(), "posting should clear the composer")
	_assert_true(game.is_world_rule_active("door|can_open"), "the door rule should enter the world rule table")
	_assert_true(not game.published_memes.is_empty() and str((game.published_memes[0] as Dictionary).get("kind", "")) == "free_sentence", "the post should enter the published feed records")

	var no_actions = StateScript.new()
	no_actions.new_run()
	no_actions.pick_social_char("floor_13", "门", "zh")
	no_actions.free_sentence_place("门", "zh")
	no_actions.actions_remaining = 0
	var blocked: Dictionary = no_actions.submit_free_sentence("zh")
	_assert_eq_text(str(blocked.get("reason", "")), "no-actions", "posting without actions must be refused")


func _test_rule_application_and_tasks() -> void:
	# 第三层:门规则即终极任务;未完成前任何结局都被门挡住。
	var game = StateScript.new()
	game.new_run()
	game.tower_floor = 3
	game.pollution = 80
	_assert_eq_text(game.complete_floor_three(), "floor-three-task-incomplete", "floor three must refuse to end before the door rule")
	game.free_sentence_units = ["门", "可", "以", "打", "开"]
	var submit: Dictionary = game.submit_free_sentence("zh")
	_assert_true(bool(submit.get("floor3_task_completed", false)), "the door rule on floor three should complete the ultimate task")
	_assert_true(game.floor3_task_complete, "the task latch should persist")
	_assert_eq_text(game.complete_floor_three(), "normal-ending", "after the door opens the normal ending should resolve")

	# 提前写规则:第一层写下门规则,到第三层时兑现。
	var early = StateScript.new()
	early.new_run()
	early.free_sentence_units = ["门", "可", "以", "打", "开"]
	early.submit_free_sentence("zh")
	_assert_true(not early.floor3_task_complete, "the door rule cannot complete a task before floor three")
	early.pollution = 30
	early.tower_floor = 1
	early.request_floor_transition_for_pollution()
	early.resolve_floor_transition_at_boundary()
	_assert_eq_int(early.tower_floor, 2, "pollution should carry the run to floor two")
	early.pollution = 65
	early.request_floor_transition_for_pollution()
	early.resolve_floor_transition_at_boundary()
	_assert_eq_int(early.tower_floor, 3, "pollution should carry the run to floor three")
	_assert_true(early.floor3_task_complete, "arriving on floor three should redeem the earlier door rule")

	# 否定不解锁;之后的正例解锁;解锁后再否定不收回(任务锁存)。
	var negated = StateScript.new()
	negated.new_run()
	negated.tower_floor = 3
	negated.free_sentence_units = ["门", "不", "可", "以", "打", "开"]
	negated.submit_free_sentence("zh")
	_assert_true(not negated.floor3_task_complete, "a negated door rule must not open the door")
	_assert_true(not negated.is_world_rule_active("door|can_open"), "negated rules are inactive")
	negated.free_sentence_units = ["门", "可", "以", "打", "开"]
	negated.submit_free_sentence("zh")
	_assert_true(negated.floor3_task_complete, "a later positive rule should open the door")
	negated.free_sentence_units = ["门", "不", "可", "以", "打", "开"]
	negated.submit_free_sentence("zh")
	_assert_true(negated.floor3_task_complete, "achieved tasks stay latched even if the rule is later negated")

	# 第四层:出口存在 = 终极任务完成,但隐藏结局只在日结边界解锁(先看见出口出现)。
	var hidden = StateScript.new()
	hidden.new_run()
	hidden.tower_floor = 4
	hidden.ending_route = "hidden"
	_assert_true(not hidden.ending_unlocked, "the hidden floor should start without an unlocked ending")
	hidden.free_sentence_units = ["出", "口", "存", "在"]
	var exit_submit: Dictionary = hidden.submit_free_sentence("zh")
	_assert_true(bool(exit_submit.get("floor4_task_completed", false)), "出口存在 should complete the floor-four ultimate task")
	_assert_true(hidden.floor4_task_complete, "the floor-four task should latch")
	_assert_true(not hidden.ending_unlocked, "the hidden ending must wait for the day boundary so the player sees the exit appear")
	hidden.needs_day_settlement = true
	hidden.settle_day_if_needed()
	_assert_true(hidden.ending_unlocked, "the day boundary should unlock the hidden ending")

	# 重复投稿同一规则不得再次报告任务完成。
	var repeat = StateScript.new()
	repeat.new_run()
	repeat.tower_floor = 3
	repeat.free_sentence_units = ["门", "可", "以", "打", "开"]
	var first_submit: Dictionary = repeat.submit_free_sentence("zh")
	_assert_true(bool(first_submit.get("floor3_task_completed", false)), "the first door rule should report task completion")
	repeat.free_sentence_units = ["门", "可", "以", "打", "开"]
	var second_submit: Dictionary = repeat.submit_free_sentence("zh")
	_assert_true(not bool(second_submit.get("floor3_task_completed", false)), "repeat submissions must not re-announce the opened door")

	# 英文与日文的提交路径同样命中规则表。
	var english = StateScript.new()
	english.new_run()
	english.free_sentence_units = ["the", "door", "can", "be", "opened"]
	_assert_eq_text(str(english.submit_free_sentence("en").get("rule_key", "")), "door|can_open", "the English door sentence should post as a rule")
	var japanese = StateScript.new()
	japanese.new_run()
	japanese.free_sentence_units = ["ドア", "ひらく"]
	_assert_eq_text(str(japanese.submit_free_sentence("ja").get("rule_key", "")), "door|can_open", "the Japanese door sentence should post as a rule")

	# 拖拽 API:插入位置与重排。
	var dragger = StateScript.new()
	dragger.new_run()
	dragger.pick_social_char("floor_13", "门", "zh")
	dragger.pick_social_char("floor_13", "开", "zh")
	dragger.pick_social_char("floor_13", "打", "zh")
	dragger.free_sentence_place("门", "zh")
	dragger.free_sentence_place("开", "zh")
	_assert_true(dragger.free_sentence_place_at("打", 1, "zh"), "drag placement should insert at an index")
	_assert_eq_text(dragger.get_free_sentence_text("zh"), "门打开", "insertion should land between the tiles")
	_assert_true(dragger.free_sentence_move(0, 2), "reorder should move a tile")
	_assert_eq_text(dragger.get_free_sentence_text("zh"), "打开门", "reorder should produce the dragged order")
	_assert_true(not dragger.free_sentence_place_at("门", 0, "zh"), "already placed units cannot be inserted twice")


func _test_save_round_trip() -> void:
	var game = StateScript.new()
	game.new_run()
	_collect_door_sentence_units(game)
	game.free_sentence_place("门", "zh")
	game.free_sentence_place("开", "zh")
	game.tower_floor = 3
	game.floor3_task_complete = true
	game.world_rules["door|can_open"] = {"negated": false, "source_text": "门可以打开", "locale": "zh", "day": 1, "floor": 3}
	var restored = StateScript.new()
	_assert_true(restored.load_save_data(game.to_save_data()), "composer save data should load")
	_assert_eq_text(restored.get_free_sentence_text("zh"), "门开", "the in-progress sentence should survive a save")
	_assert_true(restored.is_world_rule_active("door|can_open"), "world rules should survive a save")
	_assert_true(restored.floor3_task_complete, "ultimate task latches should survive a save")


func _test_ui_flow() -> void:
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "composer test should load the main scene")
	if scene == null:
		return
	var game_root := scene.instantiate()
	root.add_child(game_root)
	game_root._locale.set_locale("zh")
	game_root.new_game()
	await process_frame

	# 玩偶引导:常驻、可拖、可折叠、文本非空。
	var doll_panel := _find_node_by_name(game_root, "DollGuideOverlay") as PanelContainer
	_assert_true(doll_panel != null and doll_panel.visible, "the doll guide should stay in view from the start")
	var doll_line := _find_node_by_name(game_root, "DollGuideLine") as Label
	_assert_true(doll_line != null and not doll_line.text.is_empty(), "the doll should always have a guide line")
	_assert_true(game_root._move_window_for_test("doll_guide", Vector2(12, -8)), "the doll guide should be draggable")
	var doll_body := _find_node_by_name(game_root, "DollGuideBody") as Container
	game_root._toggle_doll_guide_collapsed()
	_assert_true(doll_body != null and not doll_body.visible, "collapsing should hide the doll body")
	game_root._toggle_doll_guide_collapsed()
	_assert_true(doll_body != null and doll_body.visible, "unfolding should restore the doll body")
	var doll_close := _find_node_by_name(game_root, "DollGuideCloseButton")
	_assert_true(doll_close == null, "the doll guide must not have a close button")

	# 派蒙式跟随伙伴:手机视图隐藏,现实视图悬浮跟随,交互/对话时连气泡一起隐身。
	game_root._update_doll_companion(0.016)
	var companion := _find_node_by_name(game_root, "DollCompanionBody") as Node3D
	_assert_true(companion != null, "the 3D doll companion body should exist")
	_assert_true(companion != null and not companion.visible, "the companion should stay hidden while the phone is up")
	game_root.set_view_state("npc_up")
	game_root._update_doll_companion(0.016)
	_assert_true(companion != null and companion.visible, "the companion should float beside the player in reality view")
	game_root._reality_interaction_active = true
	game_root._update_doll_companion(0.016)
	game_root._update_doll_guide()
	_assert_true(companion != null and not companion.visible, "the companion should vanish during NPC interactions")
	_assert_true(not doll_panel.visible, "the guide bubble should vanish during NPC interactions too")
	game_root._reality_interaction_active = false
	game_root.set_view_state("phone_down")
	game_root._update_doll_guide()
	_assert_true(doll_panel.visible, "the guide bubble should return after the interaction ends")

	# 一步一步教:多次数步骤显示进度计数。
	game_root.game.replay_tutorial()
	game_root.game.notify_tutorial("guide_found")
	game_root.game.notify_tutorial("social_opened")
	game_root.game.notify_tutorial("post_opened")
	game_root.game.notify_tutorial("collect_word")
	var progress_line: String = game_root._doll_guide_current_line()
	_assert_true(progress_line.ends_with("(1/3)"), "multi-count tutorial steps should show step progress, got: %s" % progress_line)

	# 造句台:空句禁投,入句/撤回/投稿全链路。
	game_root.game.set_active_app("notebook")
	game_root._render()
	await process_frame
	_assert_true(_find_node_by_name(game_root, "ComposerAnswerPanel") != null, "the notebook should host the composer answer panel")
	var submit_button := _find_node_by_name(game_root, "NotebookCraftButton") as Button
	_assert_true(submit_button != null and submit_button.disabled, "an empty sentence must disable the post button")
	_assert_true(_find_node_by_name(game_root, "ComposerAnswerPlaceholder") != null, "an empty sentence should show the placeholder")

	game_root.game.pick_social_char("floor_13", "门", "zh")
	game_root.game.pick_social_char("floor_13", "开", "zh")
	game_root._render()
	await process_frame
	game_root._on_composer_bank_tapped("门")
	game_root._on_composer_bank_tapped("开")
	await process_frame
	_assert_eq_text(game_root.game.get_free_sentence_text("zh"), "门开", "bank taps should build the sentence in order")
	var answer_tile := _find_node_by_name(game_root, "ComposerAnswerTile0") as Button
	_assert_true(answer_tile != null and answer_tile.text == "门", "placed units should render as answer tiles")
	var ghost_found := false
	var char_flow := _find_node_by_name(game_root, "NotebookCharFlow")
	if char_flow != null:
		for child in char_flow.get_children():
			if child is Button and (child as Button).text == "门" and (child as Button).disabled:
				ghost_found = true
	_assert_true(ghost_found, "a placed unit should ghost its bank slot without reflow")
	submit_button = _find_node_by_name(game_root, "NotebookCraftButton") as Button
	_assert_true(submit_button != null and not submit_button.disabled, "a non-empty sentence should enable the post button")

	game_root._on_composer_answer_tapped(1)
	await process_frame
	_assert_eq_text(game_root.game.get_free_sentence_text("zh"), "门", "tapping an answer tile should remove it")

	game_root._on_composer_submit_pressed()
	await process_frame
	_assert_true(game_root.game.get_free_sentence_units().is_empty(), "posting should clear the composer")
	_assert_true(game_root.log_text.begins_with("投稿已发出"), "posting should report one of the three response tiers")

	# 无行动时投稿按钮必须置灰。
	var saved_actions: int = game_root.game.actions_remaining
	game_root.game.actions_remaining = 0
	game_root.game.needs_day_settlement = false
	game_root.game.pick_social_char("floor_13", "出", "zh")
	game_root.game.free_sentence_place("出", "zh")
	game_root._render()
	await process_frame
	var drained_button := _find_node_by_name(game_root, "NotebookCraftButton") as Button
	_assert_true(drained_button != null and drained_button.disabled, "no actions must gray out the post button")
	game_root.game.actions_remaining = saved_actions
	game_root.game.free_sentence_clear()

	# 第三层门道具:任务前封门可见且有碰撞,任务后门开框亮、碰撞解除。
	game_root.game.tower_floor = 3
	game_root._rebuild_reality_floor()
	game_root._render()
	await process_frame
	var sealed_door := _find_node_by_name(game_root, "FloorThreeSealedDoor") as StaticBody3D
	var open_frame := _find_node_by_name(game_root, "FloorThreeDoorOpenFrame") as MeshInstance3D
	_assert_true(sealed_door != null and sealed_door.visible, "floor three should show the sealed door before the task")
	var door_collision: CollisionShape3D = null
	if sealed_door != null:
		door_collision = sealed_door.get_node_or_null("DoorCollision") as CollisionShape3D
	_assert_true(door_collision != null and not door_collision.disabled, "the sealed door must physically block the player")
	_assert_true(open_frame != null and not open_frame.visible, "the open frame should wait for the rule")
	# 真实路径:在第三层投出门规则(而非直接改旗标)。
	game_root.game.free_sentence_units = ["门", "可", "以", "打", "开"]
	game_root.game.submit_free_sentence("zh")
	game_root._render()
	_assert_true(game_root.game.floor3_task_complete, "the posted door rule should complete the floor-three task")
	_assert_true(not sealed_door.visible, "completing the task should retire the sealed door")
	_assert_true(door_collision != null and door_collision.disabled, "the opened door must stop blocking")
	_assert_true(open_frame.visible, "completing the task should reveal the open door frame")
	var rules_list := _find_node_by_name(game_root, "ComposerRulesList")
	if rules_list == null:
		game_root.game.set_active_app("notebook")
		game_root._render()
		await process_frame
		rules_list = _find_node_by_name(game_root, "ComposerRulesList")
	_assert_true(rules_list != null and rules_list.get_child_count() > 0, "active rules should render in the notebook list")

	# 第四层出口道具:真实路径——拼出「出口存在」后出口出现,且不立即切结局。
	game_root.game.tower_floor = 4
	game_root.game.ending_route = "hidden"
	game_root.game.ending_unlocked = false
	game_root._rebuild_reality_floor()
	game_root._render()
	await process_frame
	var exit_frame := _find_node_by_name(game_root, "FloorFourExitFrame") as MeshInstance3D
	_assert_true(exit_frame != null and not exit_frame.visible, "the floor-four exit should not exist before its rule")
	game_root.game.pick_social_char("station_lit", "口", "zh")
	game_root.game.pick_social_char("station_lit", "在", "zh")
	game_root.game.pick_social_char("station_lit", "存", "zh")
	game_root.game.free_sentence_units = ["出", "口", "存", "在"]
	game_root.game.submit_free_sentence("zh")
	game_root._render()
	await process_frame
	_assert_true(game_root.game.floor4_task_complete, "出口存在 should latch the floor-four task")
	_assert_true(exit_frame.visible, "the exit frame should appear the moment the rule holds")
	_assert_true(not game_root.game.ending_unlocked, "the ending must not swallow the exit's appearance")

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
