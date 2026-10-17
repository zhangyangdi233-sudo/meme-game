extends SceneTree
## Language material module: pickup BBCode marking, composer drop, and flight targets.
## Does not load the main scene.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const LanguageMaterialScript = preload("res://scripts/game/language_material.gd")
const ComposerDropAreaScript = preload("res://scripts/ui/composer_drop_area.gd")
const ActionOutcomeScript = preload("res://scripts/game/action_outcome.gd")
const PropertyBootScript = preload("res://scripts/game/property_boot.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")

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
	_test_material_raises_no_redraw_requests()
	_test_pickup_returns_outcome()
	_test_signals_retired()


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

	var material = LanguageMaterialScript.new()
	material.configure({
		"game": func(): return game,
		"locale": func() -> String: return "zh",
	})
	var actions_left: int = game.actions_remaining
	_assert_true(material.remove_at(2), "answer-tile remove should go through the module")
	_assert_eq_text(game.get_free_sentence_text("zh"), "打开", "answer-tile remove should go through the module")
	_assert_true(game.actions_remaining == actions_left, "removing a tile must not spend an action")
	var submitted = material.submit()
	_assert_true(submitted is ActionOutcomeScript, "submit should return an action outcome")
	_assert_true(submitted.succeeded and submitted.spent_action, "a posted sentence should be a spent, successful action")
	_assert_true(submitted.settlement().has("actions_after"), "submit should hand the host the spent-action settlement")
	_assert_true(game.get_free_sentence_units().is_empty(), "submit should clear the composer")
	_assert_true(_feedback_text().begins_with("投稿已发出"), "submit should write a response tier into the feedback model")
	var empty = material.submit()
	_assert_true(empty is ActionOutcomeScript and not empty.succeeded and not empty.spent_action, "an empty submit should fail without spending")
	_assert_eq_text(_feedback_text(), "句子还空着。", "an empty submit should say the sentence is empty")

	# Fresh states share the same models, so these run after the sentence above is done.
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


## Screens watch the free sentence and the notebook models; the material only changes the state.
func _test_material_raises_no_redraw_requests() -> void:
	var material = LanguageMaterialScript.new()
	_assert_true(not material.has_signal("ui_refresh_requested"), "language material should not ask the host to redraw the phone shell")
	_assert_true(not material.has_signal("status_refresh_requested"), "language material should not ask the host to redraw the status line")


func _test_pickup_returns_outcome() -> void:
	var game := Harness.new_state()
	var material = LanguageMaterialScript.new()
	material.configure({
		"game": func(): return game,
		"locale": func() -> String: return "zh",
	})
	var first = material.pick_from_post("门", "floor_13")
	_assert_true(first is ActionOutcomeScript, "pickup should return an action outcome")
	_assert_true(first.succeeded and first.spent_action, "the day's first pickup should succeed and spend an action")
	_assert_true(first.settlement().has("actions_after"), "the first pickup should carry the spent-action settlement")
	_assert_eq_text(_feedback_text(), "一个字进入了笔记本。", "a pickup should write into the feedback model")
	var second = material.pick_from_post("开", "floor_13")
	_assert_true(second.succeeded and not second.spent_action, "later pickups that day should succeed for free")
	var duplicate = material.pick_from_post("门", "floor_13")
	_assert_true(not duplicate.succeeded and not duplicate.spent_action, "a duplicate pickup should fail without spending")
	_assert_eq_text(_feedback_text(), "这个字已经在笔记本里了。", "a duplicate pickup should say so in the feedback model")
	var no_game = LanguageMaterialScript.new().pick_from_post("门", "floor_13")
	_assert_true(no_game is ActionOutcomeScript and not no_game.succeeded, "pickup without a game should return a failed outcome")


## The host reads the returned outcome and the feedback model, not material signals.
func _test_signals_retired() -> void:
	var material = LanguageMaterialScript.new()
	_assert_true(not material.has_signal("effective_action"), "language material should not raise effective_action")
	_assert_true(not material.has_signal("log_requested"), "language material should not raise log_requested")
	var source := FileAccess.get_file_as_string("res://scripts/game/language_material.gd")
	_assert_true(not source.contains("actions_before"), "language material should not snapshot actions_before itself")
	var adapter := FileAccess.get_file_as_string("res://scripts/babel_meme_game.gd")
	_assert_true(not adapter.contains("effective_action"), "adapter should not wire effective_action")
	_assert_true(not adapter.contains("log_requested"), "adapter should not wire log_requested")


func _feedback_text() -> String:
	PropertyBootScript.install()
	var manager := ServiceRegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	return str(manager.model(PropertyKeysScript.FEEDBACK_TEXT).read())


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq_text(value: String, expected: String, message: String) -> void:
	if value != expected:
		_failures.append("%s (got %s, expected %s)" % [message, value, expected])
