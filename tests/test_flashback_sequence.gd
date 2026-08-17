extends SceneTree
## 60% 污染闪回时间线回归测试:相位表连续性、WCAG 闪烁预算、
## 关键句保护、确定性(无随机)、与主场景的行为契约。

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _run()
	if _failures.is_empty():
		print("flashback sequence tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_check_timeline_data()
	_check_determinism_source()
	await _check_scene_contract()


func _check_timeline_data() -> void:
	var director_script := load("res://scripts/ui/pollution_flashback_director.gd") as GDScript
	_assert_true(director_script != null, "flashback director script should load")
	if director_script == null:
		return
	var phases: Array = director_script.PHASES
	_assert_true(phases.size() == 9, "flashback should keep the eight-beat structure plus freeze (9 phases)")

	var cursor := 0.0
	for phase in phases:
		_assert_near(float(phase["start"]), cursor, 0.001, "phase %s should start where the previous one ends" % phase["id"])
		var duration := float(phase["duration"])
		_assert_true(duration >= 0.12, "phase %s should last at least 120ms so it stays readable, not subliminal" % phase["id"])
		cursor += duration
	_assert_near(cursor, float(director_script.TOTAL_DURATION), 0.001, "TOTAL_DURATION should equal the sum of phase durations")
	_assert_true(cursor >= 3.0 and cursor <= 4.5, "flashback should run between 3.0 and 4.5 seconds")

	# 独立重算 WCAG 闪烁预算:任意 1 秒滚动窗口内明暗切换 ≤3。
	var flip_times: Array[float] = []
	for index in range(1, phases.size()):
		if int(phases[index]["luminance"]) != int(phases[index - 1]["luminance"]):
			flip_times.append(float(phases[index]["start"]))
	var worst := 0
	for anchor in flip_times:
		var count := 0
		for other in flip_times:
			if other - anchor >= 0.0 and other - anchor < 1.0:
				count += 1
		worst = maxi(worst, count)
	_assert_true(worst <= 3, "any rolling 1s window should contain at most 3 luminance flips (WCAG 2.2), got %d" % worst)
	_assert_true(int(director_script.max_luminance_flips_in_window(1.0)) <= 3, "director helper should agree the flash budget holds")

	# 黑帧是阅读标点:两段黑帧都要 >=150ms。
	for phase in phases:
		if str(phase["id"]).begins_with("black_gap"):
			_assert_true(float(phase["duration"]) >= 0.15, "black gaps should be reading punctuation (>=150ms), not strobe")

	# 未记录卡片短闪必须能被读到但不镶死:60-200ms。
	var card_flash := float(director_script.UNREGISTERED_CARD_FLASH)
	_assert_true(card_flash >= 0.06 and card_flash <= 0.2, "unregistered card flash should stay between 60ms and 200ms")


func _check_determinism_source() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/pollution_flashback_director.gd")
	_assert_true(source.length() > 0, "director source should be readable")
	for forbidden in ["randf", "randi", "randomize(", "shuffle("]:
		_assert_true(not source.contains(forbidden), "flashback director must be deterministic; found forbidden call: %s" % forbidden)


func _check_scene_contract() -> void:
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "flashback test should load the main scene")
	if scene == null:
		return
	var game_root := scene.instantiate()
	root.add_child(game_root)
	game_root._locale.set_locale("zh")
	game_root.new_game()
	await process_frame

	var overlay := _find_node_by_name(game_root, "PollutionFlashbackOverlay") as Control
	_assert_true(overlay != null, "flashback overlay node should keep its registered name")
	if overlay == null:
		game_root.queue_free()
		await process_frame
		return
	_assert_true(overlay.z_index == 100, "flashback overlay should keep highest visual priority")
	_assert_true(not overlay.visible, "flashback overlay should start hidden")

	var doll_sentence := _find_node_by_name(overlay, "FlashbackKeySentenceDoll") as Label
	var doctor_sentence := _find_node_by_name(overlay, "FlashbackKeySentenceDoctor") as Label
	_assert_true(doll_sentence != null and doctor_sentence != null, "both scene phases should carry the protected key sentence")
	if doll_sentence != null and doctor_sentence != null:
		_assert_eq_text(doll_sentence.text, doctor_sentence.text, "doll and doctor must speak the exact same sentence (attribution changes, words do not)")
		_assert_eq_text(doll_sentence.text, "我只是想让你留在安全的地方。", "the shared safe-place sentence must survive verbatim")
		_assert_true(doll_sentence.position == doctor_sentence.position or doll_sentence.get_combined_minimum_size() == doctor_sentence.get_combined_minimum_size(), "the key sentence should stay pinned while the scene shifts")

	var doll_plate := _find_node_by_name(overlay, "FlashbackSpeakerPlateDoll") as Label
	var doctor_plate := _find_node_by_name(overlay, "FlashbackSpeakerPlateDoctor") as Label
	_assert_true(doll_plate != null and doctor_plate != null, "speaker plates should exist for both scenes")
	if doll_plate != null and doctor_plate != null:
		_assert_true(doll_plate.text != doctor_plate.text, "only the speaker metadata may change between the two scenes")

	var second_sentence := _find_node_by_name(overlay, "FlashbackSecondSentenceLabel") as Label
	_assert_true(second_sentence != null, "residue return should pre-plant the second shared sentence")
	if second_sentence != null:
		_assert_true("你不需要再听见那个声" == second_sentence.text, "second sentence should arrive with its final unit cut")

	var attribution := _find_node_by_name(overlay, "FlashbackAttributionCard") as RichTextLabel
	_assert_true(attribution != null, "attribution phase should show the strike/underline swap")
	if attribution != null:
		_assert_true(attribution.text.contains("[s]玩偶[/s]"), "doll attribution should be struck through")
		_assert_true(attribution.text.contains("[u]医生[/u]"), "doctor attribution should be underlined")

	var middle_square := _find_node_by_name(overlay, "FlashbackEmptySquare1") as Panel
	var side_square := _find_node_by_name(overlay, "FlashbackEmptySquare0") as Panel
	_assert_true(middle_square != null and side_square != null, "empty frames should draw three squares")
	if middle_square != null and side_square != null:
		var middle_style := middle_square.get_theme_stylebox("panel") as StyleBoxFlat
		var side_style := side_square.get_theme_stylebox("panel") as StyleBoxFlat
		_assert_true(middle_style != null and middle_style.border_width_bottom == 0, "the middle square should miss one edge")
		_assert_true(side_style != null and side_style.border_width_bottom > 0, "outer squares should keep all edges")

	var unregistered := _find_node_by_name(overlay, "FlashbackUnregisteredCard") as Label
	_assert_true(unregistered != null and unregistered.text.contains("未记录"), "the layer-4 pre-memory card should read 区域：未记录")
	_assert_true(unregistered != null and not unregistered.visible, "unregistered card should stay hidden until its beat")

	for echo_index in 3:
		var echo_row := _find_node_by_name(overlay, "FlashbackEchoRow%d" % echo_index) as Label
		_assert_true(echo_row != null, "triple echo row %d should exist" % echo_index)
		if echo_row != null:
			_assert_true(not echo_row.text.contains(["我只是想让你", "留在", "安全的地方。"][echo_index]), "echo row %d should be missing its assigned segment" % echo_index)

	# 行为契约:60% 触发 → 播放 → 立即完成 → 直接日结,不叠加三秒日过场。
	game_root.game.pollution = 60
	game_root.game.check_pollution_flashback(59)
	game_root._play_pollution_flashback()
	await process_frame
	_assert_true(overlay.visible, "playing the flashback should reveal the overlay")
	_assert_true(game_root._input_locked, "flashback should lock gameplay input")
	var freeze_phase := _find_node_by_name(overlay, "FlashbackPhaseFreeze") as Control
	_assert_true(freeze_phase != null and freeze_phase.visible, "the sequence should open on the frozen current frame")
	game_root._finish_pollution_flashback()
	_assert_eq_int(game_root.game.day, 2, "finishing the flashback should settle straight into the next day")
	_assert_true(not overlay.visible, "finishing should hide the overlay")
	_assert_true(not game_root._input_locked, "finishing should unlock input")

	# 中途打断安全:再次播放后立刻停止不应崩溃或残留可见相位。
	game_root._play_pollution_flashback()
	await process_frame
	game_root._finish_pollution_flashback()
	_assert_true(not overlay.visible, "an interrupted flashback should still clean up")

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


func _assert_near(value: float, expected: float, tolerance: float, message: String) -> void:
	if absf(value - expected) > tolerance:
		_failures.append("%s (got %f, expected %f)" % [message, value, expected])


func _assert_eq_int(value: int, expected: int, message: String) -> void:
	if value != expected:
		_failures.append("%s (got %d, expected %d)" % [message, value, expected])


func _assert_eq_text(value: String, expected: String, message: String) -> void:
	if value != expected:
		_failures.append("%s (got %s, expected %s)" % [message, value, expected])
