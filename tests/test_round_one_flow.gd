extends SceneTree
## #125: basement round one played through in the main scene the way a player would, without a document: no NPC
## stands in the room; at the CRT the narrator says what to do next; the words of an exit rule can be picked off the
## terminal's feed; a post that misses says to try again; 门是出口 opens the exit; walking out starts round two.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const GuideScript = preload("res://scripts/game/basement_guide.gd")
const NarrativeCatalogScript = preload("res://scripts/game/narrative_session_catalog.gd")
const PostSlipScript = preload("res://scripts/ui/post_slip.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")
const SocialFeedPanelScript = preload("res://scripts/ui/social_feed_panel.gd")
const TEST_SAVE_PATH := "user://test_round_one_flow_save.dat"
const TEST_PREFERENCES_PATH := "user://test_round_one_flow_preferences.cfg"
## A green post first, then the exit rule.
const MISS := ["我"]
const EXIT_RULE := ["门", "是", "出", "口"]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	root.size = Vector2i(1600, 900)
	_remove_files()
	await _run()
	_remove_files()
	if _failures.is_empty():
		print("round one flow tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	var game_root = scene.instantiate()
	game_root._save_path = TEST_SAVE_PATH
	root.add_child(game_root)
	await process_frame
	game_root._locale.preferences_path = TEST_PREFERENCES_PATH
	game_root._locale.set_locale("zh")
	await _enter_round_one(game_root)
	await _test_round_one_is_escaped_by_an_exit_rule(game_root)
	game_root.queue_free()
	await process_frame


func _test_round_one_is_escaped_by_an_exit_rule(game_root) -> void:
	_assert_true(Harness.find_node_by_name(game_root, "BasementNPC") == null, "round one should stand no NPC")
	await _enter_terminal(game_root)
	var display := Harness.find_node_by_name(game_root, "CrtTerminalDisplay")
	_assert_eq(_guide_text(display), _narrated(GuideScript.STEP_PICK), "the narrator should start by asking for words")

	var picked := await _pick_off_the_feed(game_root, display, MISS + EXIT_RULE)
	_assert_eq(picked, MISS + EXIT_RULE, "every word of 门是出口 should be on offer in round one")
	(Harness.find_node_by_name(display, "TerminalAppNotebook") as Button).pressed.emit()
	await process_frame
	await process_frame
	_assert_eq(_guide_text(display), _narrated(GuideScript.STEP_COMPOSE), "held words should ask for a sentence")

	await _post(display, MISS)
	_assert_true(not ProgressScript.exit_open(game_root.game.chapter_one_progress), "a green post should leave the exit shut")
	var hint := Harness.find_node_by_name(display, "PostRetryHint") as Label
	_assert_true(hint != null and hint.is_visible_in_tree(), "a missed post should say to try again under the post button")
	_assert_eq(hint.text if hint != null else "", PostSlipScript.MISSED_LINE, "the slip should say nothing answered")
	_assert_eq(_guide_text(display), _narrated(GuideScript.STEP_MISSED), "the narrator should say to try again")

	await _post(display, EXIT_RULE)
	_assert_true(ProgressScript.exit_open(game_root.game.chapter_one_progress), "门是出口 should open round one")
	_assert_eq(_guide_text(display), _narrated(GuideScript.STEP_OPEN), "the narrator should send the player out")

	_push_key(game_root, KEY_TAB)
	await process_frame
	_assert_eq(str(game_root._reality_scene_adapter.interaction_outcome().get("kind")), "none", "Tab should leave the screen")
	for frame in 90:
		await process_frame
	await _walk_out(game_root)
	_assert_eq(ProgressScript.round_of(game_root.game.chapter_one_progress), 2, "walking out should start round two")


## A new run read to the end, knocked, and saved behind the white door continues in basement round one.
func _enter_round_one(game_root) -> void:
	game_root.new_game()
	await process_frame
	while game_root.game.advance_opening_narration():
		pass
	game_root.game.complete_opening_knock()
	game_root.game.open_opening_door()
	_assert_true(game_root._save_progress(), "setup should save the run in the basement")
	game_root.show_main_menu()
	await process_frame
	_assert_true(game_root.continue_game(), "setup should continue the basement save")
	await process_frame
	await process_frame
	_assert_eq(ProgressScript.round_of(game_root.game.chapter_one_progress), 1, "setup should stand in round one")


func _enter_terminal(game_root) -> void:
	var adapter = game_root._reality_scene_adapter
	adapter.player.position = adapter.chapter_terminal_position() + Vector3(0.0, 0.02, 0.0)
	adapter.player.velocity = Vector3.ZERO
	for frame in 10:
		await physics_frame
	_assert_eq(str(adapter.nearby_outcome().get("kind")), "terminal", "the CRT should answer in reach")
	_push_key(game_root, KEY_F)
	await process_frame
	await process_frame
	_assert_eq(str(adapter.interaction_outcome().get("kind")), "terminal", "F at the CRT should enter its screen")


## Opens the terminal feed's posts one by one and clicks each wanted word where a post offers it, as a player would.
## Answers the words picked, in the order wanted.
func _pick_off_the_feed(game_root, display: Node, wanted: Array) -> Array:
	var social := Harness.find_node_by_name(game_root, "TerminalSocialFeedPanel") as SocialFeedPanel
	var source := ServiceRegistryScript.resolve(ServiceKeysScript.SOCIAL_FEED_SOURCE) as SocialFeedSource
	for post_index in source.visible_post_indices([], SocialFeedPanelScript.DEFAULT_CHANNEL):
		social.open_post(post_index)
		await process_frame
		# A pick repaints the post, so its links are looked up again after each one.
		var clicked := true
		while clicked:
			clicked = false
			for text in display.find_children("*", "RichTextLabel", true, false):
				var label := text as RichTextLabel
				var unit: Variant = _offered(game_root, label, wanted)
				if unit != null:
					label.meta_clicked.emit(unit)
					await process_frame
					clicked = true
					break
	return wanted.filter(func(unit: String) -> bool: return game_root.game.is_social_char_collected(unit, "zh"))


func _offered(game_root, label: RichTextLabel, wanted: Array) -> Variant:
	for unit in wanted:
		if not game_root.game.is_social_char_collected(unit, "zh") and label.text.contains("[url=%s]" % unit):
			return unit
	return null


## Taps the words into the sentence on the terminal's notebook and posts it with the notebook's button.
func _post(display: Node, units: Array) -> void:
	var canvas := Harness.find_node_by_name(display, "NotebookWordCanvas") as WordPhysicsCanvas
	_assert_true(canvas != null, "the terminal's notebook should show its words")
	for unit in units:
		if canvas != null:
			canvas.tile_tapped.emit(unit)
		await process_frame
		await process_frame
		canvas = Harness.find_node_by_name(display, "NotebookWordCanvas") as WordPhysicsCanvas
	_assert_eq(_guide_text(display), _narrated(GuideScript.STEP_POST), "a sentence should ask to be posted")
	var craft := Harness.find_node_by_name(display, "NotebookCraftButton") as Button
	_assert_true(craft != null and not craft.disabled, "the terminal's notebook should offer the post")
	if craft != null:
		craft.pressed.emit()
	await process_frame
	await process_frame


func _guide_text(display: Node) -> String:
	var guide := Harness.find_node_by_name(display, "TerminalGuide") as Label
	_assert_true(guide != null and guide.visible, "the narrator should show on the terminal")
	return guide.text if guide != null else ""


func _narrated(step: String) -> String:
	return NarrativeCatalogScript.opening_speaker("zh") + NarrativeCatalogScript.basement_guide_line(1, step, "zh")


func _walk_out(game_root) -> void:
	var adapter = game_root._reality_scene_adapter
	var exit: Vector3 = adapter.chapter_exit_position()
	adapter.player.position = Vector3(exit.x + 0.7, 0.1, exit.z)
	adapter.player.velocity = Vector3.ZERO
	adapter.yaw = 90.0
	var before: Dictionary = game_root.game.chapter_one_progress
	Input.action_press("reality_forward")
	for frame in 120:
		await physics_frame
		if game_root.game.chapter_one_progress != before:
			break
	Input.action_release("reality_forward")
	# Walking out plays the exit transition every exit object shares before the next stage is built.
	for frame in 900:
		if str(adapter.interaction_outcome().get("kind")) != "exit":
			break
		await process_frame
	await process_frame


func _push_key(game_root, keycode: Key) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = keycode
		key.physical_keycode = keycode
		key.pressed = pressed
		game_root.get_viewport().push_input(key, true)


func _remove_files() -> void:
	for path in [TEST_SAVE_PATH, TEST_PREFERENCES_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
