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
	await _test_canvas_tiles_carry_their_answers()
	await _test_a_placed_word_leaves_the_pile_and_comes_back()
	await _test_posting_returns_every_used_word()
	await _test_a_returning_word_yields_its_spot_to_a_resting_one()
	await _test_a_drop_on_the_scrolled_out_sentence_misses()
	_test_words_sit_above_the_sentence_on_a_draggable_split()
	await _test_the_split_keeps_its_place_across_repaints()
	_test_the_sentence_raises_its_intents()
	_test_the_hint_says_where_words_go()
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


func _test_a_placed_word_leaves_the_pile_and_comes_back() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	var chars: ListPropertyModel = mounted["chars"]
	var units: ListPropertyModel = mounted["units"]
	chars.add(_held("门"))
	chars.add(_held("开"))
	panel.render(mounted["body"])
	panel.set_shown(true)
	_assert_true(_button_disabled(mounted, "NotebookCraftButton"), "an empty sentence should not post")
	_assert_true(_has(mounted, "ComposerAnswerPlaceholder"), "an empty sentence should show its placeholder")
	units.add("门")
	await process_frame
	_assert_eq(_tile_units(mounted), ["开"], "a word placed in the sentence should leave the pile")
	_assert_eq(_button_text(mounted, "ComposerAnswerTile0"), "门", "the placed word should show in the sentence")
	_assert_eq(_label_text(mounted, "ComposerPreviewLabel"), "门", "the preview should read the sentence")
	_assert_true(not _button_disabled(mounted, "NotebookCraftButton"), "a sentence with a word should post")
	units.remove_at(0)
	await process_frame
	_assert_eq(_tile_units(mounted), ["门", "开"], "a word taken out of the sentence should come back to the pile")
	_assert_true(not _has(mounted, "ComposerAnswerTile0"), "the sentence should be empty again")
	_dispose(mounted)


func _test_posting_returns_every_used_word() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	var chars: ListPropertyModel = mounted["chars"]
	var units: ListPropertyModel = mounted["units"]
	chars.add(_held("门"))
	chars.add(_held("开"))
	units.replace_all(["门", "开"])
	panel.render(mounted["body"])
	panel.set_shown(true)
	_assert_eq(_tile_units(mounted), [], "a full sentence should leave nothing in the pile")
	units.replace_all([])
	await process_frame
	_assert_eq(_tile_units(mounted), ["门", "开"], "an emptied sentence should give every word back")
	_dispose(mounted)


## A word that settled into the spot of a word now in the sentence keeps it; the word coming back goes beside it.
func _test_a_returning_word_yields_its_spot_to_a_resting_one() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	var chars: ListPropertyModel = mounted["chars"]
	var units: ListPropertyModel = mounted["units"]
	chars.add(_held("门"))
	chars.add(_held("开"))
	units.replace_all(["门"])
	panel.render(mounted["body"])
	panel.set_shown(true)
	var resting := _canvas(mounted).get_tile_position("开")
	units.replace_all([])
	await process_frame
	var canvas := _canvas(mounted)
	_assert_true(canvas.get_tile_position("开").is_equal_approx(resting), "the resting word should keep its spot, got %s not %s" % [canvas.get_tile_position("开"), resting])
	_assert_true(not canvas.get_tile_position("门").is_equal_approx(resting), "the returning word should go beside it")
	_dispose(mounted)


## A tile let go over a part of the sentence scrolled out of view does not land in the sentence.
func _test_a_drop_on_the_scrolled_out_sentence_misses() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	var rules: MapPropertyModel = mounted["rules"]
	for index in 14:
		rules.add("rule%d|on" % index, {"negated": false, "source_text": "规则%d" % index, "locale": "zh", "day": 1, "floor": 3})
	panel.render(mounted["body"])
	await process_frame
	var scroll := Harness.find_node_by_name(mounted["body"], "NotebookSentenceScroll") as ScrollContainer
	scroll.scroll_vertical = 10000
	await process_frame
	var answer := Harness.find_node_by_name(mounted["body"], "ComposerAnswerPanel") as Control
	var hidden_point := answer.get_global_rect().get_center()
	_assert_true(not scroll.get_global_rect().has_point(hidden_point), "the setup should scroll the sentence out of view")
	_heard.clear()
	_canvas(mounted).tile_dropped_outside.emit("打", hidden_point)
	_assert_eq(_heard, [], "a tile let go over the hidden sentence should stay in the pile")
	_dispose(mounted)


func _test_words_sit_above_the_sentence_on_a_draggable_split() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	panel.render(mounted["body"])
	var split := Harness.find_node_by_name(mounted["body"], "NotebookSplit") as VSplitContainer
	_assert_true(split != null, "the notebook should split words and sentence")
	if split == null:
		_dispose(mounted)
		return
	_assert_true(split.dragging_enabled, "the split should be draggable")
	var words := split.get_child(0)
	var sentence := split.get_child(1)
	_assert_true(Harness.find_node_by_name(words, "NotebookWordCanvas") != null, "the pile should sit in the upper part")
	for node_name in ["ComposerAnswerPanel", "NotebookCraftButton"]:
		_assert_true(Harness.find_node_by_name(sentence, node_name) != null, "%s should sit in the lower part" % node_name)
	_dispose(mounted)


func _test_the_split_keeps_its_place_across_repaints() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	panel.render(mounted["body"])
	panel.set_shown(true)
	var split := Harness.find_node_by_name(mounted["body"], "NotebookSplit") as VSplitContainer
	split.split_offset = -90
	split.dragged.emit(-90)
	(mounted["chars"] as ListPropertyModel).add(_held("门"))
	await process_frame
	var repainted := Harness.find_node_by_name(mounted["body"], "NotebookSplit") as VSplitContainer
	_assert_true(repainted != split, "a new word should repaint the page")
	_assert_eq(repainted.split_offset, -90, "a repaint should keep where the player dragged the split")
	_dispose(mounted)


func _test_the_sentence_raises_its_intents() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	(mounted["units"] as ListPropertyModel).replace_all(["门", "开"])
	panel.render(mounted["body"])
	var dropped := {"kind": "composer_unit", "id": "打"}
	_heard.clear()
	(Harness.find_node_by_name(mounted["body"], "ComposerAnswerPanel") as ComposerDropArea).unit_dropped.emit(dropped)
	_assert_eq(_heard, [[UiIntentsScript.NOTEBOOK_SENTENCE_AREA_DROPPED, {UiIntentsScript.KEY_DATA: dropped}]], "a drop on the sentence should raise the whole drag data")
	_heard.clear()
	(Harness.find_node_by_name(mounted["body"], "ComposerAnswerTile0") as ComposerAnswerTile).unit_dropped_before.emit(dropped, 1)
	_assert_eq(_heard, [[UiIntentsScript.NOTEBOOK_SENTENCE_TILE_DROPPED, {UiIntentsScript.KEY_DATA: dropped, UiIntentsScript.KEY_BEFORE_INDEX: 1}]], "a drop on a sentence word should raise the drag data and the index")
	_heard.clear()
	(Harness.find_node_by_name(mounted["body"], "ComposerAnswerTile1") as Button).pressed.emit()
	_assert_eq(_heard, [[UiIntentsScript.NOTEBOOK_SENTENCE_TILE_TAPPED, {UiIntentsScript.KEY_UNIT_INDEX: 1}]], "tapping a sentence word should raise its index")
	_dispose(mounted)


func _test_the_hint_says_where_words_go() -> void:
	var mounted := _mount()
	(mounted["panel"] as NotebookAppPanel).render(mounted["body"])
	var text := Harness.collect_control_text(mounted["body"])
	_assert_true(text.contains("点字放进下方的句子;从句子拿掉的字会回到这里。"), "the hint should say tapping puts a word in the sentence below: %s" % text)
	_assert_true(not text.contains("发布页"), "the notebook should no longer send the player to the publish page")
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
	(manager.model(PropertyKeysScript.WORLD_RULES) as MapPropertyModel).add("light|lit", {"round": 0, "source_text": "灯亮"})
	await process_frame
	var rules_text := Harness.collect_control_text(mounted["body"])
	_assert_true(PolicyScript.garbled("灯") in rules_text and "灯亮" not in rules_text, "the rules list should garble the word too: %s" % rules_text)
	_dispose(mounted)


func _test_a_void_sentence_warns_above_the_post_button() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as NotebookAppPanel
	var manager := RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	(manager.model(PropertyKeysScript.CHAPTER_ONE_PROGRESS) as MapPropertyModel).replace_all(ProgressScript.jump_to_round(ProgressScript.initial(), 1))
	(manager.model(PropertyKeysScript.FREE_SENTENCE_UNITS) as ListPropertyModel).replace_all(["房", "间", "亮"])
	panel.render(mounted["body"])
	panel.set_shown(true)
	_assert_true(not _has(mounted, "SentenceVoidWarning"), "a clean rule should not warn")
	(manager.model(PropertyKeysScript.POLLUTED_WORDS) as MapPropertyModel).replace_all({"subjects": ["room"], "units": {"zh": ["房", "间"]}})
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
	rules.add("room|lit", {"negated": true, "source_text": "不房间亮", "locale": "zh", "day": 1, "floor": 1, "round": 1})
	panel.render(mounted["body"])
	panel.set_shown(true)
	var list := Harness.find_node_by_name(mounted["body"], "ComposerRulesList")
	var label := list.get_child(0) as Label
	_assert_eq(label.text, "· 房间不亮", "a room's rule should read as its room words it")
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


func _label_text(mounted: Dictionary, node_name: String) -> String:
	var label := Harness.find_node_by_name(mounted["body"], node_name) as Label
	return label.text if label != null else "<missing %s>" % node_name


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
	panel.commit_canvas_positions()
	_assert_eq(commits.size(), 0, "tiles not yet through a physics step should not be written")
	await physics_frame

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
	(mounted["units"] as ListPropertyModel).replace_all(["门", "开"])
	panel.render(mounted["body"])
	await process_frame
	var canvas := _canvas(mounted)
	_heard.clear()
	canvas.tile_tapped.emit("打")
	_assert_eq(_heard, [[UiIntentsScript.NOTEBOOK_COMPOSER_BANK_TAPPED, {UiIntentsScript.KEY_UNIT: "打"}]], "a tapped tile should carry its unit")
	var answer := Harness.find_node_by_name(mounted["body"], "ComposerAnswerPanel") as Control
	var second := Harness.find_node_by_name(mounted["body"], "ComposerAnswerTile1") as Control
	var placed := {"kind": "composer_unit", "id": "打"}
	_heard.clear()
	canvas.tile_dropped_outside.emit("打", second.get_global_rect().get_center())
	_assert_eq(_heard, [[UiIntentsScript.NOTEBOOK_SENTENCE_TILE_DROPPED, {UiIntentsScript.KEY_DATA: placed, UiIntentsScript.KEY_BEFORE_INDEX: 1}]], "a tile dropped on a sentence word should go before it")
	_heard.clear()
	canvas.tile_dropped_outside.emit("打", answer.get_global_rect().end - Vector2(4.0, 4.0))
	_assert_eq(_heard, [[UiIntentsScript.NOTEBOOK_SENTENCE_AREA_DROPPED, {UiIntentsScript.KEY_DATA: placed}]], "a tile dropped on the sentence should join its end")
	_heard.clear()
	canvas.tile_dropped_outside.emit("打", Vector2(-500.0, -500.0))
	_assert_eq(_heard, [], "a tile dropped anywhere else should stay in the pile")
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
