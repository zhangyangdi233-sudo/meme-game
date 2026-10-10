extends SceneTree
## Shown notebook watches the held-word and finished-meme models; hiding writes canvas positions once and unregisters.

const BootScript = preload("res://scripts/game/property_boot.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const Harness = preload("res://tests/harness/minimal_game_harness.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_deferred")


func _run_deferred() -> void:
	await _run()
	if _failures.is_empty():
		print("notebook app panel tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_showing_registers_once_and_syncs_at_once()
	await _test_a_new_held_word_repaints_the_shown_canvas()
	await _test_a_host_redraw_in_the_same_frame_paints_once()
	await _test_a_new_meme_repaints_only_the_fusion_tab()
	await _test_hiding_writes_positions_once_and_unregisters()
	_test_a_freed_panel_unregisters()
	await _test_showing_before_any_render_paints_nothing()


func _test_showing_registers_once_and_syncs_at_once() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	var chars: ListPropertyModel = mounted["chars"]
	var memes: ListPropertyModel = mounted["memes"]
	chars.add(_held("门"))
	panel.render(mounted["body"], "frame")
	_assert_eq(_listener_count(chars), 0, "a rendered notebook should not listen before it is shown")
	_assert_eq(_listener_count(memes), 0, "a rendered notebook should not listen to memes before it is shown")
	_assert_eq(_tile_units(mounted), ["门"], "rendering should paint the held words from the model")

	chars.add(_held("开"))
	_assert_eq(_tile_units(mounted), ["门"], "a hidden notebook should not repaint on a write")
	panel.set_shown(true)
	_assert_eq(_listener_count(chars), 1, "showing should register on the held words")
	_assert_eq(_listener_count(memes), 1, "showing should register on the memes")
	_assert_eq(_tile_units(mounted), ["门", "开"], "showing should sync a word written while hidden at once")
	var canvas := _canvas(mounted)
	panel.set_shown(true)
	_assert_eq(_listener_count(chars), 1, "showing again should not register twice")
	_assert_true(_canvas(mounted) == canvas, "showing again with nothing new should not repaint")
	_dispose(mounted)


func _test_a_new_held_word_repaints_the_shown_canvas() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	var chars: ListPropertyModel = mounted["chars"]
	panel.render(mounted["body"], "frame")
	panel.set_shown(true)
	_assert_eq(_tile_units(mounted), [], "an empty notebook should paint no tiles")
	chars.add(_held("门"))
	await process_frame
	_assert_eq(_tile_units(mounted), ["门"], "a held word added while shown should appear by itself")
	chars.add({"unit": "door", "locale": "en"})
	await process_frame
	_assert_eq(_tile_units(mounted), ["门"], "a word from another language should not appear on this canvas")
	_dispose(mounted)


func _test_a_host_redraw_in_the_same_frame_paints_once() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	var chars: ListPropertyModel = mounted["chars"]
	panel.render(mounted["body"], "frame")
	panel.set_shown(true)
	mounted["frame_paints"][0] = 0
	chars.add(_held("门"))
	chars.add(_held("开"))
	panel.render(mounted["body"], "frame")
	var redrawn := _canvas(mounted)
	await process_frame
	_assert_eq(int(mounted["frame_paints"][0]), 1, "two writes and a host redraw in one frame should paint the page once")
	_assert_true(_canvas(mounted) == redrawn, "a host redraw in the same frame should leave nothing to repaint")
	_assert_eq(_tile_units(mounted), ["门", "开"], "the host redraw should already show both words")
	_dispose(mounted)


func _test_a_new_meme_repaints_only_the_fusion_tab() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	var memes: ListPropertyModel = mounted["memes"]
	panel.render(mounted["body"], "frame")
	panel.set_shown(true)
	var canvas := _canvas(mounted)
	memes.add({"id": "meme-1", "title": "左梗"})
	await process_frame
	_assert_true(_canvas(mounted) == canvas, "a new meme should not redraw the word canvas")

	panel.render(mounted["body"], "fusion")
	var slot_reads := int(mounted["slot_reads"][0])
	memes.add({"id": "meme-2", "title": "右梗"})
	await process_frame
	_assert_eq(int(mounted["slot_reads"][0]), slot_reads + 2, "a new meme should repaint both fusion slots by itself")
	_dispose(mounted)


func _test_hiding_writes_positions_once_and_unregisters() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	var chars: ListPropertyModel = mounted["chars"]
	var memes: ListPropertyModel = mounted["memes"]
	chars.add(_held("门"))
	chars.add(_held("开"))
	panel.render(mounted["body"], "frame")
	panel.set_shown(true)
	var commits: Array = mounted["commits"]
	commits.clear()

	panel.set_shown(false)
	_assert_eq(commits.size(), 1, "hiding should write the canvas positions in one batch")
	if commits.size() == 1:
		var written: Dictionary = commits[0]
		_assert_eq(written.keys().size(), 2, "the batch should carry every resting tile")
	_assert_eq(_listener_count(chars), 0, "hiding should unregister from the held words")
	_assert_eq(_listener_count(memes), 0, "hiding should unregister from the memes")

	panel.set_shown(false)
	_assert_eq(commits.size(), 1, "hiding again should not write again")
	chars.add(_held("打"))
	await process_frame
	_assert_eq(_tile_units(mounted), ["门", "开"], "a hidden notebook should ignore later writes")
	_dispose(mounted)


func _test_a_freed_panel_unregisters() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	var chars: ListPropertyModel = mounted["chars"]
	var memes: ListPropertyModel = mounted["memes"]
	panel.render(mounted["body"], "frame")
	panel.set_shown(true)
	panel.free()
	mounted["panel"] = null
	_assert_eq(_listener_count(chars), 0, "a freed notebook should unregister from the held words")
	_assert_eq(_listener_count(memes), 0, "a freed notebook should unregister from the memes")
	_dispose(mounted)


func _test_showing_before_any_render_paints_nothing() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	var chars: ListPropertyModel = mounted["chars"]
	panel.set_shown(true)
	chars.add(_held("门"))
	await process_frame
	_assert_eq((mounted["body"] as Node).get_child_count(), 0, "a notebook without a body should not paint")
	_assert_eq(_listener_count(chars), 1, "a shown notebook should still listen before its first render")
	_dispose(mounted)


func _mount() -> Dictionary:
	RegistryScript.clear()
	BootScript.install()
	var manager: PropertyManager = RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	var body := VBoxContainer.new()
	body.name = "NotebookAppBody"
	body.size = Vector2(560, 640)
	root.add_child(body)
	var panel := NotebookAppPanel.new()
	panel.name = "NotebookAppPanel"
	root.add_child(panel)
	var commits: Array = []
	var slot_reads: Array = [0]
	var frame_paints: Array = [0]
	panel.configure(_deps(slot_reads, frame_paints))
	panel.canvas_positions_committed.connect(func(positions: Dictionary) -> void:
		commits.append(positions)
	)
	return {
		"body": body,
		"panel": panel,
		"commits": commits,
		"slot_reads": slot_reads,
		"frame_paints": frame_paints,
		"chars": manager.model(PropertyKeysScript.COLLECTED_CHAR_UNITS),
		"memes": manager.model(PropertyKeysScript.COMPLETED_MEMES),
	}


func _deps(slot_reads: Array, frame_paints: Array) -> Dictionary:
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
		"fusion_slot_text": func(slot_id: String) -> String:
			slot_reads[0] += 1
			return slot_id,
		"current_locale": func() -> String: return "zh",
		"free_sentence_units": func() -> Array: return [],
		"world_rules": func() -> Array:
			frame_paints[0] += 1
			return [],
		"char_canvas_position": func(_unit: String, _locale_code: String) -> Vector2: return Vector2(10.0, 10.0),
		"can_spend_action": func() -> bool: return true,
		"fusion_ready": func() -> bool: return false,
	}


func _held(unit: String) -> Dictionary:
	return {"unit": unit, "locale": "zh", "source_post_id": "floor_13", "day": 1}


func _canvas(mounted: Dictionary) -> WordPhysicsCanvas:
	return Harness.find_node_by_name(mounted["body"], "NotebookWordCanvas") as WordPhysicsCanvas


func _tile_units(mounted: Dictionary) -> Array:
	var canvas := _canvas(mounted)
	var units: Array = []
	if canvas == null:
		return units
	for unit in ["门", "开", "打", "door"]:
		if canvas.has_tile(unit):
			units.append(unit)
	return units


func _dispose(mounted: Dictionary) -> void:
	var panel: Node = mounted["panel"]
	if panel != null and is_instance_valid(panel):
		panel.free()
	var body: Node = mounted["body"]
	if body != null and is_instance_valid(body):
		body.free()
	RegistryScript.clear()


func _listener_count(model: PropertyModel) -> int:
	if model == null:
		return -1
	return model.changed.get_connections().size()


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
