extends SceneTree
## Main-scene flashback overlay contract: layout, playback, and natural timeline completion.

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _check_scene_contract()
	if _failures.is_empty():
		print("flashback sequence scene tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


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
	_assert_true(overlay.z_index == 100, "flashback overlay should keep its registered z-index (100, above the day transition overlay)")
	_assert_true(not overlay.visible, "flashback overlay should start hidden")

	var doll_sentence := _find_node_by_name(overlay, "FlashbackKeySentenceDoll") as Label
	var doctor_sentence := _find_node_by_name(overlay, "FlashbackKeySentenceDoctor") as Label
	_assert_true(doll_sentence != null and doctor_sentence != null, "both scene phases should carry the protected key sentence")
	if doll_sentence != null and doctor_sentence != null:
		_assert_eq_text(doll_sentence.text, doctor_sentence.text, "doll and doctor must speak the exact same sentence (attribution changes, words do not)")
		_assert_eq_text(doll_sentence.text, "我只是想让你留在安全的地方。", "the shared safe-place sentence must survive verbatim")
		var pinned := (
			doll_sentence.offset_left == doctor_sentence.offset_left
			and doll_sentence.offset_right == doctor_sentence.offset_right
			and doll_sentence.offset_top == doctor_sentence.offset_top
			and doll_sentence.offset_bottom == doctor_sentence.offset_bottom
			and doll_sentence.anchor_left == doctor_sentence.anchor_left
			and doll_sentence.anchor_top == doctor_sentence.anchor_top
		)
		_assert_true(pinned, "the key sentence must stay pinned to identical anchors/offsets while the scenery shifts")
		var doll_phase := _find_node_by_name(overlay, "FlashbackPhaseDollScene")
		var doctor_phase := _find_node_by_name(overlay, "FlashbackPhaseDoctorScene")
		_assert_true(doll_phase != null and doctor_phase != null, "both scene phase roots should exist")
		if doll_phase == null or doctor_phase == null:
			game_root.queue_free()
			await process_frame
			return
		var doll_scenery := doll_phase.find_child("SceneryRoot", true, false) as Control
		var doctor_scenery := doctor_phase.find_child("SceneryRoot", true, false) as Control
		_assert_true(doll_scenery != null and doctor_scenery != null, "both scenes should carry a scenery root")
		if doll_scenery != null and doctor_scenery != null:
			_assert_near(doctor_scenery.position.x - doll_scenery.position.x, 12.0, 0.01, "the doctor scenery should shift exactly 12px, applied once")
			var doll_chair := doll_scenery.find_child("ChairSeat", true, false) as Control
			var doctor_chair := doctor_scenery.find_child("ChairSeat", true, false) as Control
			if doll_chair != null and doctor_chair != null:
				_assert_true(doll_chair.position == doctor_chair.position, "chair local position must match so the 12px offset is not applied twice")

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

	var echo_segments: Array[String] = ["我只是想让你", "留在", "安全的地方。"]
	_assert_eq_text("".join(echo_segments), "我只是想让你留在安全的地方。", "echo segments must reassemble the exact key sentence")
	for echo_index in 3:
		var echo_row := _find_node_by_name(overlay, "FlashbackEchoRow%d" % echo_index) as Label
		_assert_true(echo_row != null, "triple echo row %d should exist" % echo_index)
		if echo_row != null:
			_assert_true(not echo_row.text.contains(echo_segments[echo_index]), "echo row %d should be missing its assigned segment" % echo_index)
			for other_index in 3:
				if other_index != echo_index:
					_assert_true(echo_row.text.contains(echo_segments[other_index]), "echo row %d should still carry segment %d" % [echo_index, other_index])

	game_root.game.pollution = 60
	game_root.game.check_pollution_flashback(59)
	game_root._narrative_director.play_pollution_flashback()
	await process_frame
	_assert_true(overlay.visible, "playing the flashback should reveal the overlay")
	_assert_true(game_root._input_locked, "flashback should lock gameplay input")
	var freeze_phase := _find_node_by_name(overlay, "FlashbackPhaseFreeze") as Control
	_assert_true(freeze_phase != null and freeze_phase.visible, "the sequence should open on the frozen current frame")
	game_root._narrative_director.finish_pollution_flashback()
	_assert_eq_int(game_root.game.day, 2, "finishing the flashback should settle straight into the next day")
	_assert_true(not overlay.visible, "finishing should hide the overlay")
	_assert_true(not game_root._input_locked, "finishing should unlock input")

	game_root._narrative_director.finish_pollution_flashback()
	_assert_eq_int(game_root.game.day, 2, "a second finish call must not settle a second day")

	game_root._narrative_director.play_pollution_flashback()
	await process_frame
	game_root._narrative_director.finish_pollution_flashback()
	_assert_true(not overlay.visible, "an interrupted flashback should still clean up")

	game_root.game.pollution = 60
	game_root.game.pollution_flashback_seen = false
	game_root.game.check_pollution_flashback(59)
	var day_before: int = game_root.game.day
	game_root._narrative_director.play_pollution_flashback()
	var director_script := load("res://scripts/ui/pollution_flashback_director.gd") as GDScript
	var expected_order: Array[String] = []
	for phase in director_script.PHASES:
		expected_order.append(str(phase["id"]))
	await process_frame
	var phase_nodes := {}
	for phase_id in expected_order:
		phase_nodes[phase_id] = _find_node_by_name(overlay, "FlashbackPhase" + phase_id.to_pascal_case()) as Control
		_assert_true(phase_nodes[phase_id] != null, "rebuilt overlay should still expose phase node for %s" % phase_id)
	var seen_order: Array[String] = []
	var deadline_msec := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline_msec:
		for phase_id in expected_order:
			var phase_node := phase_nodes.get(phase_id) as Control
			if phase_node != null and is_instance_valid(phase_node) and phase_node.visible and (seen_order.is_empty() or seen_order[seen_order.size() - 1] != phase_id):
				seen_order.append(phase_id)
		if game_root.game.day == day_before + 1 and not overlay.visible:
			break
		await process_frame
	_assert_true(game_root.game.day == day_before + 1, "pollution flashback must finish within 15 seconds")
	_assert_eq_int(game_root.game.day, day_before + 1, "the natural timeline completion must settle the day through sequence_finished")
	_assert_true(not overlay.visible, "the natural completion must hide the overlay by itself")
	_assert_true(not game_root._input_locked, "the natural completion must unlock input")
	_assert_eq_text(",".join(seen_order), ",".join(expected_order), "phases must appear exactly in PHASES order during a natural run")

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
