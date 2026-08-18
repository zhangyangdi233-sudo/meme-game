extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _run()
	if _failures.is_empty():
		print("day transition tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "day transition test should load the main scene")
	if scene == null:
		return
	var game_root := scene.instantiate()
	root.add_child(game_root)
	game_root._locale.set_locale("zh")
	game_root.new_game()
	await process_frame

	var day_overlay := _find_node_by_name(game_root, "DayTransitionOverlay") as Control
	var area_label := _find_node_by_name(game_root, "FloorTransitionAreaLabel") as Label
	var danger_label := _find_node_by_name(game_root, "FloorTransitionDangerLabel") as Label
	var hint_label := _find_node_by_name(game_root, "FloorTransitionHintLabel") as Label
	var action_overlay := _find_node_by_name(game_root, "ActionSpendOverlay") as Control
	var flashback_overlay := _find_node_by_name(game_root, "PollutionFlashbackOverlay") as Control
	_assert_true(day_overlay != null and area_label != null and danger_label != null and hint_label != null, "scene should expose a three-field floor transition card")
	if day_overlay != null:
		var duration := float(day_overlay.get_meta("duration_seconds", 0.0))
		_assert_true(duration >= 3.0 and duration <= 5.0, "next-day overlay should last between three and five seconds")
		_assert_true(not day_overlay.visible, "next-day overlay should start hidden")
	if day_overlay != null and action_overlay != null and flashback_overlay != null:
		_assert_true(day_overlay.z_index > action_overlay.z_index, "next-day overlay should cover the action pulse")
		_assert_true(day_overlay.z_index < flashback_overlay.z_index, "pollution flashback should retain highest visual priority")

	game_root.game.actions_remaining = 1
	_assert_true(game_root.game.spend_action("transition-test"), "last daily action should be spendable")
	game_root._play_action_spend_animation(1, 0)
	game_root._finish_action_spend_animation()
	_assert_true(day_overlay != null and day_overlay.visible, "last action should start the next-day overlay after its inline pulse")
	_assert_true(game_root._input_locked, "next-day overlay should lock gameplay input")
	_assert_eq(game_root.game.day, 1, "day settlement should wait until the transition reaches its midpoint")
	_assert_eq(str(area_label.text), "第一层", "transition should use the requested level name without the old region prefix")
	_assert_eq(str(danger_label.text), "危险：B", "floor one transition should display danger rank B")
	_assert_true(str(hint_label.text).contains("《游戏与现实》"), "floor one transition should use the approved psychology title")
	game_root._commit_day_transition_settlement()
	_assert_eq(game_root.game.day, 2, "transition midpoint should commit the next day")
	_assert_eq(game_root.game.actions_remaining, 5, "committed next day should restore all five actions")
	_assert_eq(str(area_label.text), "第一层", "level naming should remain stable after the settlement midpoint")
	game_root._finish_day_transition()
	_assert_true(day_overlay != null and not day_overlay.visible, "finished next-day transition should hide its overlay")
	_assert_true(not game_root._input_locked, "finished next-day transition should restore input")

	game_root.new_game()
	await process_frame
	# 梗圆环已退役:任何页面、任何视角都不再出现,也不再有开合动效契约。
	var meme_bank := _find_node_by_name(game_root, "MemeBankPopup") as Control
	_assert_true(meme_bank != null and not meme_bank.visible, "the retired meme ring must stay hidden on the feed")
	_assert_true(not game_root._should_peek_meme_bank(), "the retired meme ring must not peek")
	_assert_true(not game_root._should_show_meme_bank(), "the meme ring visibility rule should always refuse")
	game_root._social_screen = "publish"
	game_root._open_app_windows["social"] = true
	game_root._render()
	_assert_true(meme_bank != null and not meme_bank.visible, "the retired meme ring must stay hidden on the publish page too")
	game_root.game.set_active_app("notebook")
	game_root._open_app_windows["social"] = false
	game_root._render()
	_assert_true(meme_bank != null and not meme_bank.visible, "the notebook must not bring the ring back either")
	game_root.set_view_state("npc_up")
	_assert_true(meme_bank != null and not meme_bank.visible, "reality walking should never show the ring")
	game_root.set_view_state("phone_down")
	game_root._social_screen = "home"
	game_root._render()

	game_root.new_game()
	await process_frame
	game_root.game.pollution = 60
	game_root.game.check_pollution_flashback(59)
	game_root._play_pollution_flashback()
	game_root._finish_pollution_flashback()
	day_overlay = _find_node_by_name(game_root, "DayTransitionOverlay") as Control
	_assert_eq(game_root.game.day, 2, "pollution flashback should still settle directly into the next day")
	_assert_true(day_overlay != null and not day_overlay.visible, "pollution flashback should not stack the normal three-second day overlay")

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


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
