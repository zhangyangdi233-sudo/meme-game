extends SceneTree
## 筆記本畫布只在要記住時寫入字的位置：靜止不寫、關閉寫一次、重開留在原位。

const PanelScript = preload("res://scripts/ui/notebook_app_panel.gd")
const StateScript = preload("res://scripts/meme_game_state.gd")
const Harness = preload("res://tests/harness/minimal_game_harness.gd")

var _failures: Array[String] = []
var _writes: Array = []
var _commits := 0


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _run()
	if _failures.is_empty():
		print("notebook canvas position tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	var game: MemeGameState = StateScript.new()
	game.new_run()
	var panel: NotebookAppPanel = PanelScript.new()
	panel.name = "NotebookAppPanel"
	root.add_child(panel)
	game.collected_char_units = [
		{"unit": "门", "locale": "zh", "source_post_id": "floor_13", "day": 1},
		{"unit": "开", "locale": "zh", "source_post_id": "floor_13", "day": 1},
	]
	panel.configure(_deps(game))
	panel.canvas_positions_committed.connect(func(positions: Dictionary) -> void:
		_commits += 1
		for unit in positions.keys():
			_writes.append({"unit": str(unit), "position": positions[unit]})
		game.set_char_canvas_positions(positions, "zh")
	)

	var app_body := VBoxContainer.new()
	app_body.name = "NotebookAppBody"
	app_body.size = Vector2(560, 640)
	root.add_child(app_body)
	panel.render(app_body, "frame")
	await process_frame

	var canvas := Harness.find_node_by_name(app_body, "NotebookWordCanvas") as WordPhysicsCanvas
	_assert_true(canvas != null, "the notebook should mount a word canvas")
	if canvas == null:
		return
	canvas.size = Vector2(520, 300)
	await process_frame

	for _step in 160:
		await physics_frame
	_assert_true(_writes.is_empty(), "an open notebook with no commit must not write canvas positions")
	_assert_true(game.char_canvas_positions.is_empty(), "idle frames must leave saved canvas positions untouched")

	var door_before: Vector2 = canvas.get_tile_position("门")
	var open_default: Vector2 = game.get_char_canvas_position("开", "zh")
	var moving := canvas.get_node_or_null("WordPhysicsRoot/WordBody_开") as RigidBody2D
	_assert_true(moving != null, "the second tile should have a body")
	if moving != null:
		moving.position = Vector2(300.0, 40.0)
		moving.linear_velocity = Vector2(320.0, 0.0)
	panel.commit_canvas_positions()
	_assert_eq(_commits, 1, "closing should write the canvas in one batch")
	_assert_eq(_writes.size(), 1, "closing should write each settled tile once")
	if _writes.size() == 1:
		_assert_eq(str(_writes[0]["unit"]), "门", "only the settled tile should be written")
		var written: Vector2 = _writes[0]["position"]
		_assert_true(written.distance_to(door_before) < 1.0, "the written position should be the tile's current resting place")
	_assert_true(
		game.get_char_canvas_position("开", "zh").distance_to(open_default) < 1.0,
		"a tile that is still moving should keep its previous position"
	)

	for _step in 20:
		await physics_frame
	_assert_eq(_writes.size(), 1, "idle frames after a close must not write again")

	if moving != null and is_instance_valid(moving):
		moving.linear_velocity = Vector2(320.0, 0.0)
	var live_door: Vector2 = canvas.get_tile_position("门")
	panel.render(app_body, "frame")
	await process_frame
	var reopened := Harness.find_node_by_name(app_body, "NotebookWordCanvas") as WordPhysicsCanvas
	_assert_true(reopened != null, "reopening the notebook should mount the canvas again")
	if reopened == null:
		return
	var door_after: Vector2 = reopened.get_tile_position("门")
	var open_after: Vector2 = reopened.get_tile_position("开")
	_assert_true(door_after.distance_to(live_door) < 1.0, "reopening should put the settled tile back where it was saved")
	_assert_true(door_after.distance_to(game.get_char_canvas_position("门", "zh")) < 1.0, "the reopened tile should match the position written for it")
	_assert_true(open_after.distance_to(open_default) < 1.0, "reopening should not keep a position that was still moving")
	_assert_eq(_write_count("门"), 2, "the redraw before reopen should write the settled tile one more time")
	_assert_eq(_write_count("开"), 0, "the moving tile should still not be written on reopen")

	app_body.queue_free()
	panel.queue_free()
	await process_frame


func _deps(game: MemeGameState) -> Dictionary:
	return {
		"panel_factory": func(): return PanelContainer.new(),
		"label_factory": func(text: String, _size: int, _color: Color) -> Label:
			var label := Label.new()
			label.text = text
			return label,
		"theme_color": func(_key: String) -> Color: return Color.WHITE,
		"clear_children": func(node: Node) -> void:
			for child in node.get_children():
				node.remove_child(child)
				child.queue_free(),
		"composer_tile_style": func(_kind: String): return StyleBoxFlat.new(),
		"fusion_slot_text": func(slot_id: String) -> String: return slot_id,
		"current_locale": func() -> String: return "zh",
		"free_sentence_units": func() -> Array: return [],
		"world_rules": func() -> Array: return [],
		"char_canvas_position": func(unit: String, locale_code: String) -> Vector2:
			return game.get_char_canvas_position(unit, locale_code),
		"can_spend_action": func() -> bool: return true,
		"fusion_ready": func() -> bool: return false,
	}


func _write_count(unit: String) -> int:
	var count := 0
	for entry in _writes:
		if str(entry.get("unit", "")) == unit:
			count += 1
	return count


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
