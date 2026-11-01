extends SceneTree
## Shown notebook watches the held-word, sentence and world-rule models; it has no fusion tab.
## Hiding writes canvas positions once and unregisters.

const BootScript = preload("res://scripts/game/property_boot.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const PolicyScript = preload("res://scripts/game/pollution_policy.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
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
		RegistryScript.clear()
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		RegistryScript.clear()
		quit(1)


func _run() -> void:
	_test_showing_registers_once_and_syncs_at_once()
	await _test_a_new_held_word_repaints_the_shown_canvas()
	await _test_a_host_redraw_in_the_same_frame_paints_once()
	_test_the_notebook_has_no_fusion_tab()
	await _test_hiding_writes_positions_once_and_unregisters()
	_test_a_freed_panel_unregisters()
	await _test_showing_before_any_render_paints_nothing()
	_test_the_craft_button_raises_its_intent()
	_test_canvas_tiles_carry_their_answers()
	await _test_a_placed_word_ghosts_its_tile_and_enables_posting()
	await _test_a_new_world_rule_appears_by_itself()
	await _test_the_last_post_shows_red_or_green()
	await _test_a_polluted_word_shows_as_red_garble()
	await _test_a_void_sentence_warns_above_the_post_button()
	_test_a_room_rule_shows_its_authored_wording()
	_test_hiding_unregisters_from_the_sentence_and_rules()


func _test_showing_registers_once_and_syncs_at_once() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	var chars: ListPropertyModel = mounted["chars"]
	chars.add(_held("门"))
	panel.render(mounted["body"])
	_assert_eq(_listener_count(chars), 0, "a rendered notebook should not listen before it is shown")
	_assert_eq(_tile_units(mounted), ["门"], "rendering should paint the held words from the model")

	chars.add(_held("开"))
	_assert_eq(_tile_units(mounted), ["门"], "a hidden notebook should not repaint on a write")
	panel.set_shown(true)
	_assert_eq(_listener_count(chars), 1, "showing should register on the held words")
	_assert_eq(_listener_count(mounted["memes"]), 0, "the notebook should not watch the finished memes")
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


## The fusion tab and its old-meme slots are gone; the notebook shows its one page.
func _test_the_notebook_has_no_fusion_tab() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	panel.render(mounted["body"])
	panel.set_shown(true)
	_assert_true(not panel.has_method("select_tab"), "the notebook should have no tabs to select")
	for node_name in ["NotebookFusionButton", "FusionSlotLeft", "FusionSlotRight", "NotebookFusionSlots"]:
		_assert_true(not _has(mounted, node_name), "the notebook should not build %s" % node_name)
	_assert_true(_has(mounted, "NotebookCraftButton"), "the notebook should keep its post button")
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


func _test_the_last_post_shows_red_or_green() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	var published: ListPropertyModel = (RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager).model(PropertyKeysScript.PUBLISHED_MEMES)
	panel.render(mounted["body"])
	panel.set_shown(true)
	_assert_true(not _has(mounted, "LastPostSlip"), "no post should show no slip")
	published.insert_at(0, {"kind": "free_sentence", "text": "我想回家", "tier": "misread"})
	await process_frame
	var slip := Harness.find_node_by_name(mounted["body"], "LastPostSlip") as Label
	_assert_true(slip != null and slip.text.contains("我想回家"), "a post should show by itself")
	var theme := RegistryScript.resolve(ServiceKeysScript.UI_THEME) as GameUiTheme
	_assert_eq(slip.get_theme_color("font_color"), theme.theme_color("accent"), "a post that changed nothing should be green")
	published.insert_at(0, {"kind": "free_sentence", "text": "灯亮", "tier": "rule"})
	await process_frame
	slip = Harness.find_node_by_name(mounted["body"], "LastPostSlip") as Label
	_assert_true(slip.text.contains("灯亮"), "the newest post should show")
	_assert_eq(slip.get_theme_color("font_color"), theme.theme_color("error"), "a post the world obeyed should be red")
	var craft := Harness.find_node_by_name(mounted["body"], "NotebookCraftButton")
	_assert_true(slip.get_index() > craft.get_index(), "the slip should sit under the post button")
	var progress: MapPropertyModel = (RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager).model(PropertyKeysScript.CHAPTER_ONE_PROGRESS)
	progress.replace_all(ProgressScript.jump_to_round(ProgressScript.initial(), 2))
	await process_frame
	_assert_true(not _has(mounted, "LastPostSlip"), "a new round should not show an earlier round's post")
	_dispose(mounted)


func _test_a_polluted_word_shows_as_red_garble() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	var manager := RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	(manager.model(PropertyKeysScript.COLLECTED_CHAR_UNITS) as ListPropertyModel).add({"unit": "灯", "locale": "zh"})
	(manager.model(PropertyKeysScript.COLLECTED_CHAR_UNITS) as ListPropertyModel).add({"unit": "亮", "locale": "zh"})
	panel.render(mounted["body"])
	panel.set_shown(true)
	(manager.model(PropertyKeysScript.POLLUTED_WORDS) as MapPropertyModel).replace_all({"units": {"zh": ["灯"]}})
	await process_frame
	var polluted := Harness.find_node_by_name(mounted["body"], "WordBody_灯")
	var clean := Harness.find_node_by_name(mounted["body"], "WordBody_亮")
	var theme := RegistryScript.resolve(ServiceKeysScript.UI_THEME) as GameUiTheme
	theme.apply_ui_theme(mounted["body"])
	_assert_eq((polluted.get_node("TileLabel") as Label).text, PolicyScript.garbled("灯"), "the polluted word should show garbled by itself")
	_assert_eq((polluted.get_node("TileLabel") as Label).get_theme_color("font_color"), theme.theme_color("error"), "and red")
	_assert_eq(polluted.get_meta("word_unit"), "灯", "the tile should still carry the word")
	_assert_eq((clean.get_node("TileLabel") as Label).text, "亮", "a clean word should stay readable")
	_dispose(mounted)


func _test_a_void_sentence_warns_above_the_post_button() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	var manager := RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	(manager.model(PropertyKeysScript.CHAPTER_ONE_PROGRESS) as MapPropertyModel).replace_all(ProgressScript.jump_to_round(ProgressScript.initial(), 1))
	(manager.model(PropertyKeysScript.FREE_SENTENCE_UNITS) as ListPropertyModel).replace_all(["灯", "亮"])
	panel.render(mounted["body"])
	panel.set_shown(true)
	_assert_true(not _has(mounted, "SentenceVoidWarning"), "a clean rule should not warn")
	(manager.model(PropertyKeysScript.POLLUTED_WORDS) as MapPropertyModel).replace_all({"subjects": ["light"], "units": {"zh": ["灯"]}})
	await process_frame
	var warning := Harness.find_node_by_name(mounted["body"], "SentenceVoidWarning")
	var craft := Harness.find_node_by_name(mounted["body"], "NotebookCraftButton") as Button
	_assert_true(warning != null and warning.get_index() < craft.get_index(), "a void sentence should warn above the post button")
	_assert_true(not craft.disabled, "it can still be posted")
	_dispose(mounted)


func _test_a_room_rule_shows_its_authored_wording() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	var rules: MapPropertyModel = mounted["rules"]
	rules.add("light|lit", {"negated": true, "source_text": "不灯亮", "locale": "zh", "day": 1, "floor": 1, "round": 1})
	panel.render(mounted["body"])
	panel.set_shown(true)
	var list := Harness.find_node_by_name(mounted["body"], "ComposerRulesList")
	var label := list.get_child(0) as Label
	_assert_eq(label.text, "· 灯不亮", "a room's rule should read as its room words it")
	_dispose(mounted)


func _test_hiding_unregisters_from_the_sentence_and_rules() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	panel.render(mounted["body"])
	panel.set_shown(true)
	for key in ["units", "rules"]:
		_assert_eq(_listener_count(mounted[key]), 1, "showing should register on %s" % key)
	panel.set_shown(false)
	for key in ["units", "rules"]:
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
	panel.render(mounted["body"])
	panel.set_shown(true)
	panel.free()
	mounted["panel"] = null
	_assert_eq(_listener_count(chars), 0, "a freed notebook should unregister from the held words")
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


func _test_the_craft_button_raises_its_intent() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	panel.render(mounted["body"])
	_heard.clear()
	(Harness.find_node_by_name(mounted["body"], "NotebookCraftButton") as Button).pressed.emit()
	_assert_eq(_heard, [[UiIntentsScript.NOTEBOOK_CRAFT_REQUESTED, {}]], "the craft button should raise its intent")
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
	}


## Each paint clears the body once, so that call counts paints.
func _deps(frame_paints: Array) -> Dictionary:
	if not RegistryScript.has(ServiceKeysScript.UI_THEME):
		RegistryScript.bind(ServiceKeysScript.UI_THEME, GameUiThemeScript.new())
	return {
		"clear_children": func(node: Node) -> void:
			frame_paints[0] += 1
			for child in node.get_children():
				node.remove_child(child)
				child.queue_free(),
		"current_locale": func() -> String: return "zh",
		"char_canvas_position": func(_unit: String, _locale_code: String) -> Vector2: return Vector2(10.0, 10.0),
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
