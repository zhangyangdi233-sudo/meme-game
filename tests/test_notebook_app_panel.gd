extends SceneTree
## Shown notebook watches the held-word, finished-meme, sentence, world-rule and fusion-slot models;
## hiding writes canvas positions once and unregisters.

const BootScript = preload("res://scripts/game/property_boot.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const Harness = preload("res://tests/harness/minimal_game_harness.gd")

var _failures: Array[String] = []
var _heard: Array = []


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
	_test_selecting_a_tab_repaints_the_notebook_by_itself()
	_test_reset_view_returns_to_the_frame_tab()
	_test_selecting_a_tab_raises_its_intent_once()
	_test_craft_and_fusion_buttons_raise_their_intents()
	_test_canvas_tiles_carry_their_answers()
	_test_fusion_slots_carry_their_answers()
	await _test_a_placed_word_ghosts_its_tile_and_enables_posting()
	await _test_a_new_world_rule_appears_by_itself()
	await _test_filled_fusion_slots_name_their_memes_and_enable_fusing()
	_test_hiding_unregisters_from_the_sentence_rules_and_slots()


func _test_showing_registers_once_and_syncs_at_once() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	var chars: ListPropertyModel = mounted["chars"]
	var memes: ListPropertyModel = mounted["memes"]
	chars.add(_held("门"))
	panel.render(mounted["body"])
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
	panel.render(mounted["body"])
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
	panel.render(mounted["body"])
	panel.set_shown(true)
	mounted["frame_paints"][0] = 0
	chars.add(_held("门"))
	chars.add(_held("开"))
	panel.render(mounted["body"])
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
	panel.render(mounted["body"])
	panel.set_shown(true)
	var canvas := _canvas(mounted)
	memes.add({"id": "meme-1", "title": "左梗"})
	await process_frame
	_assert_true(_canvas(mounted) == canvas, "a new meme should not redraw the word canvas")

	panel.select_tab("fusion")
	(mounted["slots"] as MapPropertyModel).replace_all({"left": "meme-3"})
	await process_frame
	_assert_eq(_button_text(mounted, "FusionSlotLeft"), "等待完整梗", "a slot holding an unknown meme should say it is waiting")
	memes.add({"id": "meme-3", "title": "右梗"})
	await process_frame
	_assert_eq(_button_text(mounted, "FusionSlotLeft"), "右梗", "a new meme should repaint the fusion slots by itself")
	_dispose(mounted)


func _test_a_placed_word_ghosts_its_tile_and_enables_posting() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	var chars: ListPropertyModel = mounted["chars"]
	var units: ListPropertyModel = mounted["units"]
	chars.add(_held("门"))
	panel.render(mounted["body"])
	panel.set_shown(true)
	_assert_true(_button_disabled(mounted, "NotebookCraftButton"), "an empty sentence should not post")
	_assert_true(not _is_ghost(mounted, "门"), "a word not in the sentence should be a normal tile")
	units.add("门")
	await process_frame
	_assert_true(_is_ghost(mounted, "门"), "a word placed in the sentence should ghost its tile by itself")
	_assert_true(not _button_disabled(mounted, "NotebookCraftButton"), "a sentence with a word should post")
	_dispose(mounted)


func _test_a_new_world_rule_appears_by_itself() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	var rules: MapPropertyModel = mounted["rules"]
	panel.render(mounted["body"])
	panel.set_shown(true)
	_assert_true(not _has(mounted, "ComposerRulesList"), "no rule should show no rules list")
	rules.add("door|can_open", {"negated": false, "source_text": "门可以打开", "locale": "zh", "day": 1, "floor": 3})
	await process_frame
	var list := Harness.find_node_by_name(mounted["body"], "ComposerRulesList")
	_assert_true(list != null and list.get_child_count() == 1, "a new rule should appear in the shown notebook by itself")
	_dispose(mounted)


func _test_filled_fusion_slots_name_their_memes_and_enable_fusing() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	var memes: ListPropertyModel = mounted["memes"]
	var slots: MapPropertyModel = mounted["slots"]
	memes.replace_all([{"id": "a", "title": "左梗"}, {"id": "b", "text": "右"}])
	panel.render(mounted["body"])
	panel.select_tab("fusion")
	panel.set_shown(true)
	_assert_eq(_button_text(mounted, "FusionSlotLeft"), "旧梗 A", "an empty left slot should show its placeholder")
	_assert_eq(_button_text(mounted, "FusionSlotRight"), "旧梗 B", "an empty right slot should show its placeholder")
	_assert_true(_button_disabled(mounted, "NotebookFusionButton"), "empty slots should not fuse")
	slots.add("left", "a")
	await process_frame
	_assert_eq(_button_text(mounted, "FusionSlotLeft"), "左梗", "a filled slot should show the meme title by itself")
	_assert_true(_button_disabled(mounted, "NotebookFusionButton"), "one filled slot should not fuse")
	slots.add("right", "b")
	await process_frame
	_assert_eq(_button_text(mounted, "FusionSlotRight"), "右", "a meme without a title should show its text")
	_assert_true(not _button_disabled(mounted, "NotebookFusionButton"), "two filled slots should fuse")
	slots.replace_all({})
	await process_frame
	_assert_eq(_button_text(mounted, "FusionSlotLeft"), "旧梗 A", "emptied slots should show their placeholders again")
	_dispose(mounted)


func _test_hiding_unregisters_from_the_sentence_rules_and_slots() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	panel.render(mounted["body"])
	panel.set_shown(true)
	for key in ["units", "rules", "slots"]:
		_assert_eq(_listener_count(mounted[key]), 1, "showing should register on %s" % key)
	panel.set_shown(false)
	for key in ["units", "rules", "slots"]:
		_assert_eq(_listener_count(mounted[key]), 0, "hiding should unregister from %s" % key)
	_dispose(mounted)


## A tile already placed in the sentence is drawn faded.
func _is_ghost(mounted: Dictionary, unit: String) -> bool:
	var body := Harness.find_node_by_name(mounted["body"], "WordBody_%s" % unit) as CanvasItem
	return body != null and body.modulate.a < 1.0


func _button_text(mounted: Dictionary, node_name: String) -> String:
	var button := Harness.find_node_by_name(mounted["body"], node_name) as Button
	return button.text if button != null else "<missing %s>" % node_name


func _button_disabled(mounted: Dictionary, node_name: String) -> bool:
	var button := Harness.find_node_by_name(mounted["body"], node_name) as Button
	return button == null or button.disabled


func _test_hiding_writes_positions_once_and_unregisters() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	var chars: ListPropertyModel = mounted["chars"]
	var memes: ListPropertyModel = mounted["memes"]
	chars.add(_held("门"))
	chars.add(_held("开"))
	panel.render(mounted["body"])
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
	panel.render(mounted["body"])
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


func _test_selecting_a_tab_repaints_the_notebook_by_itself() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	panel.render(mounted["body"])
	panel.set_shown(true)
	_assert_true(_has(mounted, "NotebookCraftButton"), "a fresh notebook should open on the frame tab")
	panel.select_tab("fusion")
	_assert_true(_has(mounted, "NotebookFusionButton"), "selecting the fusion tab should repaint the notebook without the host")
	_assert_true(not _has(mounted, "NotebookCraftButton"), "the fusion tab should replace the frame tab")
	panel.select_tab("nowhere")
	_assert_true(_has(mounted, "NotebookFusionButton"), "an unknown tab should leave the notebook alone")
	panel.render(mounted["body"])
	_assert_true(_has(mounted, "NotebookFusionButton"), "a host redraw should keep the selected tab")
	_dispose(mounted)


func _test_selecting_a_tab_raises_its_intent_once() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	panel.render(mounted["body"])
	_heard.clear()
	panel.select_tab("fusion")
	_assert_eq(_heard, [[UiIntentsScript.NOTEBOOK_TAB_CHANGED, {UiIntentsScript.KEY_TAB_ID: "fusion"}]], "selecting a tab should tell the host which tab")
	_heard.clear()
	panel.select_tab("nowhere")
	_assert_eq(_heard, [], "an unknown tab should tell the host nothing")
	_dispose(mounted)


func _test_craft_and_fusion_buttons_raise_their_intents() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	panel.render(mounted["body"])
	_heard.clear()
	(Harness.find_node_by_name(mounted["body"], "NotebookCraftButton") as Button).pressed.emit()
	_assert_eq(_heard, [[UiIntentsScript.NOTEBOOK_CRAFT_REQUESTED, {}]], "the craft button should raise its intent")
	panel.select_tab("fusion")
	_heard.clear()
	(Harness.find_node_by_name(mounted["body"], "NotebookFusionButton") as Button).pressed.emit()
	_assert_eq(_heard, [[UiIntentsScript.NOTEBOOK_FUSION_REQUESTED, {}]], "the fusion button should raise its intent")
	_dispose(mounted)


func _test_canvas_tiles_carry_their_answers() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	panel.render(mounted["body"])
	var canvas := _canvas(mounted)
	_heard.clear()
	canvas.tile_dropped_outside.emit("门", Vector2(120.0, 80.0))
	_assert_eq(_heard, [[UiIntentsScript.NOTEBOOK_CANVAS_TILE_DROPPED_OUTSIDE, {UiIntentsScript.KEY_UNIT: "门", UiIntentsScript.KEY_RELEASE_GLOBAL: Vector2(120.0, 80.0)}]], "a tile dropped off the canvas should carry its unit and release point")
	_heard.clear()
	canvas.tile_tapped.emit("开")
	_assert_eq(_heard, [[UiIntentsScript.NOTEBOOK_COMPOSER_BANK_TAPPED, {UiIntentsScript.KEY_UNIT: "开"}]], "a tapped tile should carry its unit")
	_dispose(mounted)


func _test_fusion_slots_carry_their_answers() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	panel.render(mounted["body"])
	panel.select_tab("fusion")
	var dropped := {"kind": "meme", "id": "meme-1"}
	_heard.clear()
	(Harness.find_node_by_name(mounted["body"], "FusionSlotRight") as DropButton).dropped.emit(dropped, "right")
	_assert_eq(_heard, [[UiIntentsScript.NOTEBOOK_FUSION_MEME_DROPPED, {UiIntentsScript.KEY_DATA: dropped, UiIntentsScript.KEY_SLOT_ID: "right"}]], "a meme dropped on a slot should carry the whole drag data and the slot")
	_heard.clear()
	(Harness.find_node_by_name(mounted["body"], "FusionSlotLeft") as Button).pressed.emit()
	_assert_eq(_heard, [[UiIntentsScript.NOTEBOOK_FUSION_SLOT_PRESSED, {UiIntentsScript.KEY_SLOT_ID: "left"}]], "a pressed slot should carry its id")
	_dispose(mounted)


func _test_reset_view_returns_to_the_frame_tab() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	panel.render(mounted["body"])
	panel.select_tab("fusion")
	panel.reset_view()
	panel.render(mounted["body"])
	_assert_true(_has(mounted, "NotebookCraftButton"), "a new run should open the notebook on the frame tab")
	_dispose(mounted)


func _has(mounted: Dictionary, node_name: String) -> bool:
	return Harness.find_node_by_name(mounted["body"], node_name) != null


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
	_heard.clear()
	var bus: GameEventBus = GameEventBusScript.new()
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, bus)
	bus.intent_emitted.connect(func(intent_name: String, payload: Dictionary) -> void: _heard.append([intent_name, payload]))
	var commits: Array = []
	var frame_paints: Array = [0]
	panel.configure(_deps(frame_paints))
	bus.intent_emitted.connect(func(intent_name: String, payload: Dictionary) -> void:
		if intent_name == UiIntentsScript.NOTEBOOK_CANVAS_POSITIONS_COMMITTED:
			commits.append(payload.get(UiIntentsScript.KEY_TILE_POSITIONS))
	)
	return {
		"body": body,
		"panel": panel,
		"commits": commits,
		"frame_paints": frame_paints,
		"chars": manager.model(PropertyKeysScript.COLLECTED_CHAR_UNITS),
		"memes": manager.model(PropertyKeysScript.COMPLETED_MEMES),
		"units": manager.model(PropertyKeysScript.FREE_SENTENCE_UNITS),
		"rules": manager.model(PropertyKeysScript.WORLD_RULES),
		"slots": manager.model(PropertyKeysScript.FUSION_SLOTS),
	}


## Each paint asks once whether an action can be spent, so that call counts paints.
func _deps(frame_paints: Array) -> Dictionary:
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
		"current_locale": func() -> String: return "zh",
		"char_canvas_position": func(_unit: String, _locale_code: String) -> Vector2: return Vector2(10.0, 10.0),
		"can_spend_action": func() -> bool:
			frame_paints[0] += 1
			return true,
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
