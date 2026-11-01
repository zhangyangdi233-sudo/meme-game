extends SceneTree
## The phone is a thing found in the basement: a new run has none and cannot raise one, picking it up in the basement
## gives it once, and with it the social feed and the notebook. The map stays locked and no delivery unlocks anything.
## Owning the phone and the unlocked apps are saved apart; a save keeps both.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const StateScript = preload("res://scripts/meme_game_state.gd")

const BASEMENT_NPC_LABELS := ["护灯人", "迟到者", "回声住户", "抄写员", "无名信徒"]

var _failures: Array[String] = []


func _init() -> void:
	test_a_new_run_has_no_phone_and_no_apps()
	test_the_phone_cannot_be_raised_before_it_is_picked_up()
	test_the_phone_is_picked_up_once_in_the_basement()
	test_apps_open_no_window_before_the_phone_is_picked_up()
	test_picking_up_the_phone_gives_the_social_feed_and_the_notebook()
	test_the_map_stays_locked_and_never_comes_to_the_front()
	test_a_delivery_unlocks_nothing()
	test_a_save_keeps_the_phone_and_the_unlocked_apps_apart()
	test_a_save_without_the_phone_loads_with_it_put_away()
	test_a_saved_phone_has_its_apps_whatever_the_save_names()
	test_a_saved_locked_app_is_never_in_front()
	test_an_older_save_gets_what_its_progress_earned()
	test_skipping_chapter_one_hands_over_the_phone_and_its_apps()
	test_jumping_to_a_round_hands_over_what_earlier_rounds_earned()
	test_the_fifth_exit_hands_over_the_phone_and_its_apps()
	if _failures.is_empty():
		print("phone pickup tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_a_new_run_has_no_phone_and_no_apps() -> void:
	var game: MemeGameState = Harness.new_state()
	_assert_true(not game.phone_owned, "a new run should not own the phone")
	_assert_eq(game.unlocked_apps, [], "a new run should have no unlocked app")
	for app_id in StateScript.PHONE_APPS:
		_assert_true(not game.is_app_unlocked(app_id), "%s should start locked" % app_id)
	_assert_true(not game.is_app_window_open("social"), "a new run should open no app window")


func test_the_phone_cannot_be_raised_before_it_is_picked_up() -> void:
	var game: MemeGameState = _basement_game(1)
	game.set_view_state("npc_up")
	_assert_true(not game.set_view_state("phone_down"), "the phone should not be raised before it is picked up")
	_assert_eq(game.view_state, "npc_up", "the view should stay on the room")
	_assert_true(not game.phone_open, "the phone should stay closed")


func test_the_phone_is_picked_up_once_in_the_basement() -> void:
	var opening: MemeGameState = Harness.new_state()
	_assert_true(not opening.pick_up_phone(), "there is no phone to pick up in the opening")
	_assert_true(not opening.phone_owned, "the opening should leave the phone where it is")
	var game: MemeGameState = _basement_game(1)
	game.set_view_state("npc_up")
	_assert_true(game.pick_up_phone(), "the phone should be picked up in the basement")
	_assert_true(game.phone_owned, "the picked-up phone should be owned")
	_assert_true(not game.pick_up_phone(), "the phone should be picked up only once")
	_assert_true(game.set_view_state("phone_down"), "the owned phone should be raised")
	_assert_eq(game.view_state, "phone_down", "the raised phone should show")


func test_apps_open_no_window_before_the_phone_is_picked_up() -> void:
	var game: MemeGameState = _basement_game(1)
	game.set_view_state("npc_up")
	game.set_active_app("social")
	game.open_app_window("notebook")
	_assert_eq(game.open_app_windows, [], "no app should open before the phone is picked up")
	_assert_eq(game.active_app_window, "", "no app should be in front before the phone is picked up")


func test_picking_up_the_phone_gives_the_social_feed_and_the_notebook() -> void:
	var game: MemeGameState = _basement_game(1)
	game.set_view_state("npc_up")
	_assert_true(game.pick_up_phone(), "the phone should be picked up")
	_assert_eq(game.unlocked_apps, StateScript.PHONE_APPS, "the phone should come with its apps")
	game.set_view_state("phone_down")
	_assert_true(game.is_app_window_open("social"), "the raised phone should open the social feed")
	game.set_active_app("notebook")
	_assert_true(game.is_app_window_open("notebook"), "the notebook should open")
	_assert_eq(game.active_app_window, "notebook", "the chosen app should be in front")


func test_the_map_stays_locked_and_never_comes_to_the_front() -> void:
	var game: MemeGameState = _basement_game(1)
	game.set_view_state("npc_up")
	game.pick_up_phone()
	game.set_view_state("phone_down")
	_assert_true(not game.is_app_unlocked("map"), "the map should stay locked with the phone in hand")
	game.set_active_app("map")
	game.open_app_window("map")
	_assert_true(not game.is_app_window_open("map"), "the locked map should open no window")
	_assert_true(game.active_app != "map", "the locked map should not be chosen")
	_assert_true(game.active_app_window != "map", "the locked map should not be in front")


func test_a_delivery_unlocks_nothing() -> void:
	var game: MemeGameState = _basement_game(1)
	game.pick_up_phone()
	for round_number in range(1, ProgressScript.BASEMENT_ROUND_COUNT + 1):
		_deliver(game)
		_assert_eq(game.unlocked_apps, StateScript.PHONE_APPS, "delivering round %d should leave the apps as they were" % round_number)
		game.end_typed_reality_conversation()
		game.set_view_state("npc_up")
		if round_number < ProgressScript.BASEMENT_ROUND_COUNT:
			_assert_true(game.leave_basement_round(), "round %d should follow" % (round_number + 1))
	var without_phone: MemeGameState = _basement_game(1)
	_deliver(without_phone)
	_assert_eq(without_phone.unlocked_apps, [], "a delivery should not hand out apps to a run without the phone")


func test_a_save_keeps_the_phone_and_the_unlocked_apps_apart() -> void:
	var game: MemeGameState = _basement_game(1)
	game.pick_up_phone()
	var save := game.to_save_data()
	var state_data: Dictionary = save["state"]
	_assert_eq(state_data.get(PropertyKeysScript.PHONE_OWNED), true, "the save should record owning the phone")
	_assert_eq(state_data.get(PropertyKeysScript.UNLOCKED_APPS), StateScript.PHONE_APPS, "the save should record the unlocked apps apart")
	var restored := StateScript.new()
	_assert_true(restored.load_save_data(save), "the save should load")
	_assert_true(restored.phone_owned, "loading should keep the phone")
	_assert_eq(restored.unlocked_apps, StateScript.PHONE_APPS, "loading should keep the unlocked apps")
	_assert_true(not restored.pick_up_phone(), "a loaded phone should not be picked up again")
	restored.new_run()
	_assert_true(not restored.phone_owned, "a new run should take the phone away")
	_assert_eq(restored.unlocked_apps, [], "a new run should lock the apps again")


func test_a_save_without_the_phone_loads_with_it_put_away() -> void:
	var game: MemeGameState = _basement_game(1)
	game.set_view_state("npc_up")
	var save := game.to_save_data()
	(save["state"] as Dictionary)[PropertyKeysScript.VIEW_STATE] = "phone_down"
	var restored := StateScript.new()
	_assert_true(restored.load_save_data(save), "the save should load")
	_assert_true(not restored.phone_owned, "a phone left on the table should stay there")
	_assert_eq(restored.view_state, "npc_up", "a run without the phone should look at the room")
	_assert_eq(restored.unlocked_apps, [], "a phone left on the table should leave its apps locked")
	_assert_true(restored.pick_up_phone(), "the phone left on the table should still be picked up")
	_assert_eq(restored.unlocked_apps, StateScript.PHONE_APPS, "picking it up after loading should give its apps")


## A run saved while the deliveries unlocked the apps may name only some of them; unknown names and the locked map go.
func test_a_saved_phone_has_its_apps_whatever_the_save_names() -> void:
	var game: MemeGameState = _basement_game(1)
	game.pick_up_phone()
	for saved_apps in [[], ["social"], ["babel", 3, "map", "social", "social"]]:
		var save := game.to_save_data()
		(save["state"] as Dictionary)[PropertyKeysScript.UNLOCKED_APPS] = saved_apps
		var restored := StateScript.new()
		_assert_true(restored.load_save_data(save), "the save should load")
		_assert_eq(restored.unlocked_apps, StateScript.PHONE_APPS, "a saved phone should have its apps with %s saved" % str(saved_apps))


func test_a_saved_locked_app_is_never_in_front() -> void:
	var game: MemeGameState = _basement_game(1)
	game.pick_up_phone()
	game.set_view_state("phone_down")
	var save := game.to_save_data()
	var state_data: Dictionary = save["state"]
	state_data[PropertyKeysScript.ACTIVE_APP] = "map"
	state_data[PropertyKeysScript.ACTIVE_APP_WINDOW] = "map"
	state_data[PropertyKeysScript.OPEN_APP_WINDOWS] = ["map"]
	var restored := StateScript.new()
	_assert_true(restored.load_save_data(save), "the save should load")
	_assert_eq(restored.view_state, "phone_down", "the owned phone should come back raised")
	_assert_true(restored.active_app != "map", "the locked map should not come back chosen")
	_assert_true(restored.active_app_window != "map", "the locked map should not come back in front")
	_assert_true(not restored.is_app_window_open("map"), "the locked map's window should stay closed")


func test_an_older_save_gets_what_its_progress_earned() -> void:
	var cases := [
		{"round": 1, "owned": false, "apps": []},
		{"round": 2, "owned": true, "apps": StateScript.PHONE_APPS},
		{"round": 4, "owned": true, "apps": StateScript.PHONE_APPS},
	]
	for case: Dictionary in cases:
		var game: MemeGameState = _basement_game(int(case["round"]))
		var save := _without_phone_fields(game.to_save_data())
		var restored := StateScript.new()
		_assert_true(restored.load_save_data(save), "an older round %d save should load" % case["round"])
		_assert_eq(restored.phone_owned, case["owned"], "an older round %d save should own what it earned" % case["round"])
		_assert_eq(restored.unlocked_apps, case["apps"], "an older round %d save should have the apps of its phone" % case["round"])
	var tower: MemeGameState = Harness.new_state()
	tower.skip_chapter_one()
	var restored_tower := StateScript.new()
	restored_tower.load_save_data(_without_phone_fields(tower.to_save_data()))
	_assert_true(restored_tower.phone_owned, "an older tower save should own the phone")
	_assert_eq(restored_tower.unlocked_apps, StateScript.PHONE_APPS, "an older tower save should have the phone's apps")


func test_skipping_chapter_one_hands_over_the_phone_and_its_apps() -> void:
	var game: MemeGameState = Harness.new_state()
	game.skip_chapter_one()
	_assert_true(game.phone_owned, "the tower street should be played with the phone")
	_assert_eq(game.unlocked_apps, StateScript.PHONE_APPS, "the tower street should have the phone's apps")
	_assert_true(game.set_view_state("phone_down"), "the phone should be raised on the tower street")
	_assert_true(game.is_app_window_open("social"), "the social feed should open on the tower street")


func test_jumping_to_a_round_hands_over_what_earlier_rounds_earned() -> void:
	var game: MemeGameState = Harness.new_state()
	game.jump_to_basement_round(1)
	_assert_true(not game.phone_owned, "round one should start with the phone on the table")
	_assert_eq(game.unlocked_apps, [], "round one should start with its apps locked")
	game.jump_to_basement_round(2)
	_assert_true(game.phone_owned, "round two should start with the phone")
	_assert_eq(game.unlocked_apps, StateScript.PHONE_APPS, "round two should start with the phone's apps")
	game.jump_to_basement_round(1)
	_assert_true(not game.phone_owned, "jumping back to round one should put the phone back on the table")
	_assert_eq(game.unlocked_apps, [], "jumping back to round one should lock the apps again")


func test_the_fifth_exit_hands_over_the_phone_and_its_apps() -> void:
	var game: MemeGameState = _basement_game(1)
	game.jump_to_basement_round(5)
	_deliver(game)
	game.end_typed_reality_conversation()
	game.phone_owned = false
	_assert_true(game.leave_basement_round(), "the fifth exit should be left through")
	_assert_true(game.phone_owned, "the passage should be walked with the phone")
	_assert_eq(game.unlocked_apps, StateScript.PHONE_APPS, "the passage should have the phone's apps")
	var restored := StateScript.new()
	_assert_true(restored.load_save_data(game.to_save_data()), "a save in the passage should load")
	_assert_true(restored.phone_owned, "a save in the passage should keep the phone")
	_assert_eq(restored.unlocked_apps, StateScript.PHONE_APPS, "a save in the passage should keep the phone's apps")
	_assert_true(game.cross_passage(), "the passage should be crossed")
	restored = StateScript.new()
	_assert_true(restored.load_save_data(game.to_save_data()), "a save at the demo's end should load")
	_assert_eq(restored.unlocked_apps, StateScript.PHONE_APPS, "a save at the demo's end should keep the phone's apps")


func _deliver(game: MemeGameState) -> void:
	game.free_sentence_units = ["灯"]
	_assert_true(bool(game.submit_free_sentence("zh").get("submitted")), "setup should post a sentence")
	var round_number := ProgressScript.round_of(game.chapter_one_progress)
	game.start_typed_reality_conversation("basement_npc_%d" % round_number, "basement_npc", BASEMENT_NPC_LABELS[round_number - 1])
	while true:
		while game.conversation_phase == "typing":
			game.advance_typed_reality_character()
		if not game.continue_typed_reality_conversation():
			break
	_assert_true(ProgressScript.exit_open(game.chapter_one_progress), "setup should deliver round %d" % round_number)


func _without_phone_fields(save: Dictionary) -> Dictionary:
	var state_data: Dictionary = save["state"]
	state_data.erase(PropertyKeysScript.PHONE_OWNED)
	state_data.erase(PropertyKeysScript.UNLOCKED_APPS)
	return save


func _basement_game(round_number: int) -> MemeGameState:
	var game: MemeGameState = Harness.new_state()
	game.jump_to_basement_round(round_number)
	return game


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
