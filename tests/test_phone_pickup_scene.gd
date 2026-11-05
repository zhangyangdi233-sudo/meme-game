extends SceneTree
## In the main scene the phone lies on the basement's table: before it is picked up Tab raises nothing and no edge tab
## shows; F at the table picks it up, and then Tab or the tab on the right edge slide the phone in and out. The social
## feed and the notebook open from then on, the map stays locked and a delivery changes nothing. A save keeps the phone
## and its apps and lays no second phone on the table.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const TEST_SAVE_PATH := "user://test_phone_pickup_scene_save.dat"
const TEST_PREFERENCES_PATH := "user://test_phone_pickup_scene_preferences.cfg"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	root.size = Vector2i(1600, 900)
	_remove_files()
	await _run()
	_remove_files()
	if _failures.is_empty():
		print("phone pickup scene tests passed")
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
	game_root.new_game()
	await process_frame
	await _jump_to_round(game_root, 1)
	await _test_tab_raises_nothing_before_the_phone_is_picked_up(game_root)
	await _test_a_save_before_the_pickup_leaves_the_phone_on_the_table(game_root)
	await _test_f_at_the_table_picks_up_the_phone(game_root)
	await _test_tab_and_the_edge_tab_slide_the_phone_in_and_out(game_root)
	await _test_the_phone_opens_its_apps_and_keeps_the_map_locked(game_root)
	await _test_a_save_keeps_the_phone_and_its_apps_without_a_second_phone(game_root)
	game_root.queue_free()
	await process_frame


func _test_tab_raises_nothing_before_the_phone_is_picked_up(game_root) -> void:
	_assert_true(not game_root.game.phone_owned, "round one should start without the phone")
	_assert_eq(str(game_root.game.view_state), "npc_up", "round one should look at the room")
	_push_key(game_root, KEY_TAB)
	await process_frame
	_assert_eq(str(game_root.game.view_state), "npc_up", "Tab should not raise a phone that was never picked up")
	var edge_tab := Harness.find_node_by_name(game_root, "PhoneViewToggleButton") as Control
	_assert_true(edge_tab == null or not edge_tab.is_visible_in_tree(), "no edge tab should show before the phone is picked up")
	var popup := Harness.find_node_by_name(game_root, "PhonePopup") as Control
	_assert_true(popup == null or not popup.is_visible_in_tree(), "no phone should show before it is picked up")


func _test_a_save_before_the_pickup_leaves_the_phone_on_the_table(game_root) -> void:
	await _save_and_continue(game_root)
	_assert_true(not game_root.game.phone_owned, "a save before the pickup should come back without the phone")
	_assert_true(game_root._reality_scene_adapter.chapter_phone_position() != Vector3.ZERO, "the phone should still lie on the table")
	_push_key(game_root, KEY_TAB)
	await process_frame
	_assert_eq(str(game_root.game.view_state), "npc_up", "Tab should still raise nothing after loading")


func _test_f_at_the_table_picks_up_the_phone(game_root) -> void:
	var adapter = game_root._reality_scene_adapter
	var phone: Vector3 = adapter.chapter_phone_position()
	_assert_true(phone != Vector3.ZERO, "the phone should lie on round one's table")
	adapter.player.position = Vector3(phone.x, 0.1, phone.z + 0.8)
	adapter.player.velocity = Vector3.ZERO
	for frame in 6:
		await physics_frame
	await process_frame
	_assert_eq(str(adapter.nearby_outcome().get("kind")), "phone", "the phone should answer in reach")
	var prompt := Harness.find_node_by_name(game_root, "WorldPrompt") as Label
	_assert_true(prompt != null and prompt.visible and prompt.text.contains("拾取手机"), "the prompt should offer to pick the phone up")
	_push_key(game_root, KEY_F)
	await process_frame
	_assert_true(game_root.game.phone_owned, "F at the table should pick up the phone")
	_assert_true(Harness.find_node_by_name(game_root, "BasementPhone") == null, "the picked-up phone should leave the table")
	_assert_eq(str(game_root.game.view_state), "npc_up", "picking up the phone should not raise it yet")
	var edge_tab := Harness.find_node_by_name(game_root, "PhoneViewToggleButton") as Control
	_assert_true(edge_tab != null and edge_tab.is_visible_in_tree(), "the edge tab should show once the phone is owned")
	if edge_tab != null:
		var screen := Vector2(root.size)
		_assert_true(edge_tab.get_global_rect().end.x >= screen.x - 1.0, "the edge tab should stick out of the right edge")
		_assert_true(edge_tab.get_global_rect().size.x < 60.0, "the edge tab should be a narrow tab")


func _test_tab_and_the_edge_tab_slide_the_phone_in_and_out(game_root) -> void:
	_push_key(game_root, KEY_TAB)
	await process_frame
	_assert_eq(str(game_root.game.view_state), "phone_down", "Tab should raise the owned phone")
	var popup := Harness.find_node_by_name(game_root, "PhonePopup") as Control
	_assert_true(popup != null and popup.is_visible_in_tree(), "the raised phone should show")
	_push_key(game_root, KEY_TAB)
	await process_frame
	_assert_eq(str(game_root.game.view_state), "npc_up", "Tab again should put the phone away")
	var edge_tab := Harness.find_node_by_name(game_root, "PhoneViewToggleButton") as Button
	_assert_true(edge_tab != null, "the edge tab should exist")
	if edge_tab == null:
		return
	await _click(game_root, edge_tab.get_global_rect().get_center())
	_assert_eq(str(game_root.game.view_state), "phone_down", "clicking the edge tab should raise the phone")
	_assert_true(edge_tab.is_visible_in_tree(), "the edge tab should stay while the phone is up")
	await _click(game_root, edge_tab.get_global_rect().get_center())
	_assert_eq(str(game_root.game.view_state), "npc_up", "clicking the edge tab again should put the phone away")


func _test_the_phone_opens_its_apps_and_keeps_the_map_locked(game_root) -> void:
	game_root.set_view_state("phone_down")
	await process_frame
	var social_icon := Harness.find_node_by_name(game_root, "PhoneAppIconSocial") as Button
	var notebook_icon := Harness.find_node_by_name(game_root, "PhoneAppIconNotebook") as Button
	var map_icon := Harness.find_node_by_name(game_root, "PhoneAppIconMap") as Button
	_assert_true(social_icon != null and not social_icon.disabled, "the social feed's icon should be pressable with the phone")
	_assert_true(notebook_icon != null and not notebook_icon.disabled, "the notebook's icon should be pressable with the phone")
	_assert_true(map_icon != null and map_icon.disabled, "the map's icon should show locked")
	social_icon.pressed.emit()
	await process_frame
	var social_window := Harness.find_node_by_name(game_root, "SocialAppWindow") as Control
	_assert_true(social_window != null and social_window.is_visible_in_tree(), "the social feed should open")
	notebook_icon.pressed.emit()
	await process_frame
	_assert_true(game_root.game.is_app_window_open("notebook"), "the notebook should open")
	var front: String = game_root.game.active_app_window
	GameEventBus.raise(UiIntentsScript.APP_ICON_PRESSED, {UiIntentsScript.KEY_APP_ID: "map"})
	await process_frame
	_assert_true(not game_root.game.is_app_window_open("map"), "the locked map should not open")
	_assert_eq(game_root.game.active_app_window, front, "pressing the locked map should leave the front app in front")
	game_root.set_view_state("npc_up")
	var apps_before: Array = game_root.game.unlocked_apps
	await _deliver(game_root)
	_assert_eq(game_root.game.unlocked_apps, apps_before, "a delivery should unlock nothing")


func _test_a_save_keeps_the_phone_and_its_apps_without_a_second_phone(game_root) -> void:
	var apps_before: Array = game_root.game.unlocked_apps
	await _save_and_continue(game_root)
	_assert_true(game_root.game.phone_owned, "loading should keep the phone")
	_assert_eq(game_root.game.unlocked_apps, apps_before, "loading should keep the unlocked apps")
	_assert_true(Harness.find_node_by_name(game_root, "BasementRoom") != null, "loading should come back in the basement")
	_assert_eq(game_root._reality_scene_adapter.chapter_phone_position(), Vector3.ZERO, "loading should lay no second phone on the table")
	_assert_true(Harness.find_node_by_name(game_root, "BasementPhone") == null, "no second phone should be in the room")
	_push_key(game_root, KEY_TAB)
	await process_frame
	_assert_eq(str(game_root.game.view_state), "phone_down", "the loaded phone should be raised with Tab")
	game_root.set_view_state("npc_up")
	await _jump_to_round(game_root, 4)
	_assert_eq(game_root._reality_scene_adapter.chapter_phone_position(), Vector3.ZERO, "the next rounds should lay no phone on the table")


func _save_and_continue(game_root) -> void:
	_assert_true(game_root._save_progress(), "the run should save")
	game_root.show_main_menu()
	await process_frame
	_assert_true(game_root.continue_game(), "the save should continue")
	await process_frame
	await process_frame


func _jump_to_round(game_root, round_number: int) -> void:
	GameEventBus.raise(UiIntentsScript.CHAPTER_ROUND_JUMP_REQUESTED, {UiIntentsScript.KEY_INDEX: round_number})
	await process_frame
	await process_frame
	_assert_eq(ProgressScript.round_of(game_root.game.chapter_one_progress), round_number, "setup should jump to round %d" % round_number)


## Delivers the round the way it opens: round one by posting an exit rule; a round that stands an NPC by a post and
## the NPC's conversation played out.
func _deliver(game_root) -> void:
	var by_rule: bool = not game_root.game.basement_npc_stands()
	game_root.game.free_sentence_units = ["门", "是", "出", "口"] if by_rule else ["灯"]
	_assert_true(bool(game_root.game.submit_free_sentence("zh").get("submitted")), "setup should post a sentence")
	if by_rule:
		_assert_true(ProgressScript.exit_open(game_root.game.chapter_one_progress), "setup should deliver the round")
		return
	var adapter = game_root._reality_scene_adapter
	var npc: Vector3 = adapter.chapter_npc_position()
	adapter.player.position = Vector3(npc.x, 0.1, npc.z + 1.2)
	adapter.player.velocity = Vector3.ZERO
	for frame in 6:
		await physics_frame
	await process_frame
	_push_key(game_root, KEY_F)
	await process_frame
	var guard := 0
	while game_root._reality_interaction_is_active() and guard < 20:
		var typed := 0
		while game_root.game.conversation_phase == "typing" and typed < 200:
			_push_key(game_root, KEY_J)
			typed += 1
		await process_frame
		game_root._process(30.0)
		await process_frame
		guard += 1
	_assert_true(ProgressScript.exit_open(game_root.game.chapter_one_progress), "setup should deliver the round")


func _click(game_root, position: Vector2) -> void:
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = position
		click.global_position = position
		click.pressed = pressed
		game_root.get_viewport().push_input(click)
	await process_frame


func _push_key(game_root, keycode: Key) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = keycode
		key.physical_keycode = keycode
		var text := OS.get_keycode_string(keycode)
		key.unicode = text.to_lower().unicode_at(0) if text.length() == 1 else 0
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
