extends SceneTree
## Day-transition overlay, meme-bank retirement, and adapter signal wiring (main scene).

const Harness = preload("res://tests/harness/minimal_game_harness.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _run()
	if _failures.is_empty():
		print("day transition scene tests passed")
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

	var day_overlay := Harness.find_node_by_name(game_root, "DayTransitionOverlay") as Control
	var area_label := Harness.find_node_by_name(game_root, "FloorTransitionAreaLabel") as Label
	var danger_label := Harness.find_node_by_name(game_root, "FloorTransitionDangerLabel") as Label
	var hint_label := Harness.find_node_by_name(game_root, "FloorTransitionHintLabel") as Label
	var action_overlay := Harness.find_node_by_name(game_root, "ActionSpendOverlay") as Control
	var flashback_overlay := Harness.find_node_by_name(game_root, "PollutionFlashbackOverlay") as Control
	_assert_true(day_overlay != null and area_label != null and danger_label != null and hint_label != null, "scene should expose a three-field floor transition card")
	if day_overlay != null:
		var duration := float(day_overlay.get_meta("duration_seconds", 0.0))
		_assert_true(duration >= 3.0 and duration <= 5.0, "next-day overlay should last between three and five seconds")
		_assert_true(not day_overlay.visible, "next-day overlay should start hidden")
	if day_overlay != null and action_overlay != null and flashback_overlay != null:
		_assert_true(day_overlay.z_index > action_overlay.z_index, "next-day overlay should cover the action pulse")
		_assert_true(day_overlay.z_index < flashback_overlay.z_index, "pollution flashback should retain highest visual priority")

	_assert_true(
		game_root.game.day_progress_changed.is_connected(game_root._on_day_progress_changed),
		"adapter should listen for day progress changes"
	)
	var progress_hits: Array[int] = [0]
	game_root.game.day_progress_changed.connect(func(_snapshot: Dictionary) -> void: progress_hits[0] += 1)
	game_root.game.change_pollution(12)
	_assert_eq(progress_hits[0], 1, "pollution change should emit day_progress_changed on the live adapter")
	var progress: Dictionary = game_root.game.get_day_progress_snapshot()
	_assert_eq(int(progress.get("pollution", -1)), 12, "adapter state should expose the pollution snapshot")

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
	_assert_true(Harness.find_node_by_name(game_root, "MemeBankPopup") == null, "the retired meme ring must not be mounted on the feed")
	_assert_true(Harness.find_node_by_name(game_root, "MemeBankPanel") == null, "the retired meme ring panel must not hang into the adapter")
	_assert_true(Harness.find_node_by_name(game_root, "MemeBankRadialRing") == null, "the retired radial selector must not exist in the scene")
	game_root._social_screen = "publish"
	game_root._open_app_windows["social"] = true
	game_root._render()
	_assert_true(Harness.find_node_by_name(game_root, "MemeBankPopup") == null, "the retired meme ring must not appear on the publish page")
	game_root.game.set_active_app("notebook")
	game_root._open_app_windows["social"] = false
	game_root._render()
	_assert_true(Harness.find_node_by_name(game_root, "MemeBankPopup") == null, "the notebook must not bring the ring back")
	game_root.set_view_state("npc_up")
	_assert_true(Harness.find_node_by_name(game_root, "MemeBankPopup") == null, "reality walking should never show the ring")
	game_root.set_view_state("phone_down")
	game_root._social_screen = "home"
	game_root._render()

	game_root.new_game()
	await process_frame
	game_root.game.pollution = 60
	game_root.game.check_pollution_flashback(59)
	game_root._play_pollution_flashback()
	game_root._finish_pollution_flashback()
	day_overlay = Harness.find_node_by_name(game_root, "DayTransitionOverlay") as Control
	_assert_eq(game_root.game.day, 2, "pollution flashback should still settle directly into the next day")
	_assert_true(day_overlay != null and not day_overlay.visible, "pollution flashback should not stack the normal three-second day overlay")

	game_root.queue_free()
	await process_frame


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
