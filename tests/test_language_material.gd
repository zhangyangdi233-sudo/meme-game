extends SceneTree
## Language material module: pickup BBCode marking, composer drop, and flight targets.
## Does not load the main scene.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const LanguageMaterialScript = preload("res://scripts/game/language_material.gd")
const ComposerDropAreaScript = preload("res://scripts/ui/composer_drop_area.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("language material tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_bbcode_marking()
	_test_composer_drop()
	_test_flight_targets()
	_test_social_panel_does_not_take_adapter_callables()


func _test_bbcode_marking() -> void:
	var pickable := "9cff24"
	var marked: String = LanguageMaterialScript.pickup_bbcode("门可以打开", "zh", [], pickable)
	_assert_true(marked.contains("[url=门]"), "Chinese pickup line should mark 门 as a clickable unit")
	_assert_true(marked.contains("[url=可]"), "Chinese pickup line should mark 可")
	_assert_true(marked.contains("[u][pulse"), "pickable units need underline + pulse affordances")

	var collected_marked: String = LanguageMaterialScript.pickup_bbcode("门可以打开", "zh", ["门"], pickable)
	_assert_true(not collected_marked.contains("[url=门]"), "a collected unit must stop being clickable")
	_assert_true(collected_marked.contains("[color=#8b8f84]门[/color]"), "a collected unit should stay as gray residue")

	_assert_eq_text(
		LanguageMaterialScript.escape_bbcode("[b]x[/b]"),
		"[lb]b[rb]x[lb]/b[rb]",
		"bbcode escaping must not cascade"
	)
	var bracketed: String = LanguageMaterialScript.pickup_bbcode("[b]", "zh", [], pickable)
	_assert_true(not bracketed.contains("[b]"), "literal brackets in source text must be escaped")
	_assert_true(bracketed.contains("[lb]"), "escaped left brackets should use [lb]")

	var english: String = LanguageMaterialScript.pickup_bbcode("The door", "en", [], pickable)
	_assert_true(english.contains("[url=the]"), "sentence-initial capitalized words must stay pickable")
	_assert_true(english.contains("[url=door]"), "English whole-word pickups should mark door")
	_assert_true(not english.contains("[url=doo]"), "English matching must respect word boundaries")
	_assert_true(english.contains("The"), "displayed English text must keep original capitalization")

	var japanese_lexical: String = LanguageMaterialScript.pickup_bbcode("そこにいる", "ja", [], pickable)
	_assert_true(japanese_lexical.contains("[url=いる]"), "standalone Japanese いる should stay pickable")

	var game := Harness.new_state()
	game.pick_social_char("floor_13", "门", "zh")
	var material = LanguageMaterialScript.new()
	material.configure({
		"game": func(): return game,
		"locale": func() -> String: return "zh",
	})
	var held_marked: String = LanguageMaterialScript.pickup_bbcode("门还在", "zh", game.get_collected_char_units("zh"), pickable)
	_assert_true(not held_marked.contains("[url=门]"), "marking should grey out the held units it is handed")
	_assert_eq_text(
		material.pickup_line("floor_13", "zh"),
		LanguageMaterialScript.pickup_line("floor_13", "zh"),
		"pickup lines stay on Language material, not a Content catalog lookup"
	)
	_assert_true(not material.pickup_comments("floor_13", "zh").is_empty(), "seeded comments stay on Language material")


func _test_composer_drop() -> void:
	var game := Harness.new_state()
	game.pick_social_char("floor_13", "门", "zh")
	game.pick_social_char("floor_13", "开", "zh")
	game.pick_social_char("floor_13", "打", "zh")

	var placed: Dictionary = LanguageMaterialScript.apply_drop(
		game,
		{"kind": "composer_unit", "id": "门"},
		0,
		"zh"
	)
	_assert_true(bool(placed.get("applied", false)), "dropping a collected unit should place it")
	_assert_eq_text(game.get_free_sentence_text("zh"), "门", "a unit drop should enter the sentence")

	LanguageMaterialScript.apply_drop(game, {"kind": "composer_unit", "id": "开"}, 1, "zh")
	LanguageMaterialScript.apply_drop(game, {"kind": "composer_unit", "id": "打"}, 1, "zh")
	_assert_eq_text(game.get_free_sentence_text("zh"), "门打开", "inserting before an index should land between tiles")

	var reordered: Dictionary = LanguageMaterialScript.apply_drop(
		game,
		{"kind": "composer_reorder", "id": "0"},
		3,
		"zh"
	)
	_assert_true(bool(reordered.get("applied", false)), "reordering a tile should apply")
	_assert_eq_text(game.get_free_sentence_text("zh"), "打开门", "reorder from a lower index should correct the destination")

	var blocked: Dictionary = LanguageMaterialScript.apply_drop(
		game,
		{"kind": "composer_unit", "id": "门"},
		0,
		"zh"
	)
	_assert_true(not bool(blocked.get("applied", false)), "already placed units cannot drop in twice")

	var unknown: Dictionary = LanguageMaterialScript.apply_drop(
		Harness.new_state(),
		{"kind": "composer_unit", "id": "门"},
		0,
		"zh"
	)
	_assert_true(not bool(unknown.get("applied", false)), "uncollected units must not enter the sentence")

	var drop_game := Harness.new_state()
	drop_game.pick_social_char("floor_13", "门", "zh")
	var area = ComposerDropAreaScript.new()
	var drop_applied: Array = [false]
	area.unit_dropped.connect(func(data: Dictionary) -> void:
		drop_applied[0] = bool(LanguageMaterialScript.apply_drop(drop_game, data, drop_game.get_free_sentence_units().size(), "zh").get("applied", false))
	)
	root.add_child(area)
	_assert_true(area._can_drop_data(Vector2.ZERO, {"kind": "composer_unit", "id": "门"}), "drop area should accept composer_unit")
	_assert_true(not area._can_drop_data(Vector2.ZERO, {"kind": "meme", "id": "x"}), "drop area should reject unrelated kinds")
	area._drop_data(Vector2.ZERO, {"kind": "composer_unit", "id": "门"})
	_assert_true(bool(drop_applied[0]), "drop-area signal should apply through Language material without a main scene")
	_assert_eq_text(drop_game.get_free_sentence_text("zh"), "门", "drop-area placement should mutate free sentence state")
	area.queue_free()

	var material = LanguageMaterialScript.new()
	var logs: Array[String] = []
	var actions: Array[int] = []
	material.configure({
		"game": func(): return game,
		"locale": func() -> String: return "zh",
	})
	material.log_requested.connect(func(text: String) -> void: logs.append(text))
	material.effective_action.connect(func(actions_before: int) -> void: actions.append(actions_before))
	material.remove_at(2)
	_assert_eq_text(game.get_free_sentence_text("zh"), "打开", "answer-tile remove should go through the module")
	_assert_true(actions.is_empty(), "removing a tile must not count as an effective action")
	material.submit()
	_assert_true(not actions.is_empty(), "submit should notify the adapter through effective_action")
	_assert_true(game.get_free_sentence_units().is_empty(), "submit should clear the composer")
	_assert_true(not logs.is_empty() and str(logs[logs.size() - 1]).begins_with("投稿已发出"), "submit should report a response tier")


func _test_flight_targets() -> void:
	_assert_eq_text(
		str(LanguageMaterialScript.notebook_flight_target(null)),
		str(Vector2(84.0, 64.0)),
		"a missing notebook window should fall back to the home target"
	)
	var window := Control.new()
	window.visible = true
	window.position = Vector2(40, 24)
	window.size = Vector2(200, 120)
	root.add_child(window)
	_assert_eq_text(
		str(LanguageMaterialScript.notebook_flight_target(window)),
		str(Vector2(96.0, 64.0)),
		"notebook flight target should track the window position"
	)
	var flow := Control.new()
	flow.position = Vector2(10, 20)
	flow.size = Vector2(100, 40)
	root.add_child(flow)
	_assert_eq_text(
		str(LanguageMaterialScript.composer_answer_target(flow)),
		str(Vector2(60.0, 40.0)),
		"composer flight target should land on the answer flow"
	)
	window.queue_free()
	flow.queue_free()


func _test_social_panel_does_not_take_adapter_callables() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/social_feed_panel.gd")
	_assert_true(source.length() > 0, "social panel source should be readable")
	for forbidden in [
		'deps.get("pickup_bbcode"',
		'deps.get("pickup_meta"',
		'deps.get("pickup_line"',
		'deps.get("pickup_comments"',
		'deps.get("composer_area_drop"',
		'deps.get("composer_tile_drop"',
		'deps.get("composer_answer_tapped"',
		'deps.get("composer_submit"',
	]:
		_assert_true(not source.contains(forbidden), "social panel must not ask the adapter for %s" % forbidden)
	_assert_true(source.contains("language_material") or source.contains("LanguageMaterial"), "social panel should use the Language material module")
	var adapter := FileAccess.get_file_as_string("res://scripts/babel_meme_game.gd")
	_assert_true(not adapter.contains('"pickup_bbcode":'), "adapter must not pack pickup_bbcode into social mount deps")
	_assert_true(not adapter.contains('"composer_area_drop":'), "adapter must not pack composer drop Callables into social mount deps")
	_assert_true(
		adapter.contains("language_material") or adapter.contains("LanguageMaterial"),
		"adapter should host the Language material module"
	)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq_text(value: String, expected: String, message: String) -> void:
	if value != expected:
		_failures.append("%s (got %s, expected %s)" % [message, value, expected])
