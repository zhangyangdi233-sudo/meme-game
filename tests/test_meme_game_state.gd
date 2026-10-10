extends SceneTree

const LanguageBridgeScript = preload("res://scripts/narrative/language_bridge.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")

var _failures: Array[String] = []
var _state_script: Script = null
var _engagement_signal_count := 0
var _last_engagement_snapshot: Dictionary = {}
var _action_economy_signal_count := 0
var _last_action_economy_snapshot: Dictionary = {}
var _day_progress_signal_count := 0
var _last_day_progress_snapshot: Dictionary = {}
var _progression_signal_count := 0
var _last_progression_snapshot: Dictionary = {}


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("meme_game_state tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_state_script = load("res://scripts/meme_game_state.gd") as Script
	_assert_true(_state_script != null, "meme game state script should exist")
	if _state_script == null:
		return
	test_navigation_is_free_and_five_actions_mark_day_end()
	test_social_follow_and_like_toggles_are_free_and_persistent()
	test_social_engagement_snapshot_and_signal()
	test_phone_shell_state_lives_in_models()
	test_action_economy_snapshot_and_signal()
	test_autoplay_lives_in_the_run_model()
	test_reality_conversation_snapshot_reads_the_models()
	test_day_progress_snapshot_and_signal()
	test_day_progress_settle_day_signal()
	test_day_progress_floor_transition_signal()
	test_inventory_snapshot_without_a_change_signal()
	test_progression_snapshot_and_signal()
	test_pick_token_costs_action_and_adds_notebook_token()
	test_japanese_pickup_preserves_complete_token()
	test_complete_sentence_craft_uses_authored_phone_surfaces()
	test_publish_updates_money_and_pollution_only()
	test_floor_ascent_does_not_create_inherited_language_rules()
	test_doctor_only_accepts_words_published_in_phone_world()
	test_doctor_sentence_uses_authored_surfaces_and_adds_pollution()
	test_typed_reality_reveals_one_character_and_never_grants_frames()
	test_first_crossing_sixty_triggers_flashback_and_forces_day_end()
	test_flashback_trigger_is_once_per_run()
	test_gameplay_metrics_are_limited_to_money_and_pollution()


func test_navigation_is_free_and_five_actions_mark_day_end() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	game.set_phone_open(true)
	game.set_active_app("social")
	_assert_eq(game.actions_remaining, 5, "navigation should not spend actions")
	for index in 5:
		_assert_true(game.spend_action("test-%d" % index), "each available action should be spendable")
	_assert_eq(game.actions_remaining, 0, "five actions should deplete the day")
	_assert_true(game.needs_day_settlement, "depleted actions should request day settlement")
	_assert_true(game.settle_day_if_needed(), "the exhausted day should settle")
	_assert_eq(game.day, 2, "settlement should advance to day two")
	_assert_eq(game.actions_remaining, 5, "settlement should restore five actions")


func test_social_follow_and_like_toggles_are_free_and_persistent() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	var actions_before: int = game.actions_remaining
	_assert_true(game.toggle_social_follow("塔下夜巡"), "following should enter run state")
	_assert_true(game.toggle_social_like("missing_window"), "liking should enter run state")
	_assert_eq(game.actions_remaining, actions_before, "social browsing controls should remain free")
	game.needs_day_settlement = true
	game.settle_day_if_needed()
	_assert_true(game.is_social_following("塔下夜巡"), "follow state should survive day settlement")
	_assert_true(game.is_social_post_liked("missing_window"), "like state should survive day settlement")


func test_social_engagement_snapshot_and_signal() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	_engagement_signal_count = 0
	_last_engagement_snapshot = {}
	game.social_engagement_changed.connect(_capture_social_engagement)
	_assert_true(game.toggle_social_follow("author-a"), "follow should activate")
	_assert_eq(_engagement_signal_count, 1, "follow toggle should emit once")
	_assert_true("author-a" in _last_engagement_snapshot.get("followed_handles", []), "signal snapshot should list followed handle")
	var follow_change: Dictionary = _last_engagement_snapshot.get("change", {})
	_assert_eq(str(follow_change.get("kind", "")), "follow", "change kind should be follow")
	_assert_true(bool(follow_change.get("active", false)), "follow should be active in change metadata")

	_assert_true(game.toggle_social_like("post-1"), "like should activate")
	_assert_eq(_engagement_signal_count, 2, "like toggle should emit again")
	var like_change: Dictionary = _last_engagement_snapshot.get("change", {})
	_assert_eq(str(like_change.get("kind", "")), "like", "change kind should be like")
	_assert_true("post-1" in _last_engagement_snapshot.get("liked_post_ids", []), "signal snapshot should list liked post")

	var snapshot: Dictionary = game.get_social_engagement_snapshot()
	_assert_true("author-a" in snapshot.get("followed_handles", []), "snapshot should include followed handle")
	_assert_true("post-1" in snapshot.get("liked_post_ids", []), "snapshot should include liked post")
	var followed_copy: Array = snapshot.get("followed_handles", [])
	followed_copy.append("alias-test")
	_assert_true("alias-test" not in game.social_followed_handles, "snapshot arrays must be copies")

	var migrated: Array[String] = ["author-b"]
	game.replace_social_followed_handles(migrated)
	_assert_eq(_engagement_signal_count, 3, "bulk replace should emit")
	_assert_true(game.is_social_following("author-b"), "bulk replace should update follow state")
	_assert_true(not game.is_social_following("author-a"), "bulk replace should drop prior follows")


func _capture_social_engagement(snapshot: Dictionary) -> void:
	_engagement_signal_count += 1
	_last_engagement_snapshot = snapshot


func test_phone_shell_state_lives_in_models() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()

	var initial: Dictionary = game.get_phone_shell_snapshot()
	_assert_eq(str(initial.get("view_state", "")), "phone_down", "new run should start phone-down")
	_assert_eq(initial.keys(), ["view_state"], "the phone snapshot should carry only the view, not a second copy of the models")
	_assert_eq(str(game.active_app), "social", "new run should default to social app")
	_assert_eq(str(game.active_app_window), "social", "phone-down should expose default app window")
	_assert_true(bool(game.phone_open), "phone should be open at start")

	game.set_active_app("babel")
	_assert_eq(str(game.active_app), "babel", "choosing an app should change the current app")
	_assert_eq(str(game.active_app_window), "babel", "phone-down should sync foreground window")

	game.close_app_window("babel", [] as Array[String])
	_assert_true(str(game.active_app_window).is_empty(), "close should clear foreground window")

	game.set_active_app("social")
	game.set_active_app("notebook")
	game.close_app_window("notebook", ["social"] as Array[String])
	_assert_eq(str(game.active_app), "social", "close should fall back to remaining open app")
	_assert_eq(str(game.active_app_window), "social", "foreground should follow remaining open app")

	_assert_true(game.set_view_state("npc_up"), "npc_up should be accepted")
	_assert_eq(str(game.get_phone_shell_snapshot().get("view_state", "")), "npc_up", "snapshot should carry npc_up")
	_assert_true(str(game.active_app_window).is_empty(), "npc_up should hide app window")
	_assert_true(not bool(game.phone_open), "npc_up should close the phone")

	_assert_true(game.set_view_state("phone_down"), "phone_down should restore")
	_assert_true(bool(game.phone_open), "phone_down should open the phone again")
	_assert_eq(str(game.active_app_window), "social", "phone_down should restore foreground from active_app")

	var snapshot: Dictionary = game.get_phone_shell_snapshot()
	snapshot["view_state"] = "npc_up"
	_assert_eq(str(game.view_state), "phone_down", "snapshot must be a copy, not live state")

	var put_down = _state_script.new()
	put_down.new_run()
	put_down.set_view_state("npc_up")
	var old_state: Dictionary = put_down.to_save_data().get("state", {})
	old_state.erase("phone_open")
	old_state.erase("active_app_window")
	var loaded = _state_script.new()
	_assert_true(loaded.load_save_data({"version": _state_script.SAVE_DATA_VERSION, "state": old_state}), "an older save should load")
	_assert_true(not bool(loaded.phone_open), "a save put down without a phone field should load with the phone closed")
	_assert_true(str(loaded.active_app_window).is_empty(), "a save put down should load without a foreground app")

	game.set_phone_open(false)
	_assert_true(not bool(game.phone_open), "closing the phone should write the model")
	_assert_true(str(game.active_app_window).is_empty(), "closing phone should clear foreground window")


func test_action_economy_snapshot_and_signal() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	_action_economy_signal_count = 0
	_last_action_economy_snapshot = {}
	game.action_economy_changed.connect(_capture_action_economy)

	var initial: Dictionary = game.get_action_economy_snapshot()
	_assert_eq(int(initial.get("actions_remaining", -1)), 5, "new run should start with five actions")
	_assert_eq(int(initial.get("max_actions_per_day", -1)), 5, "new run should cap at five actions per day")
	_assert_true(not bool(initial.get("needs_day_settlement", true)), "new run should not need settlement")
	_assert_eq(str(initial.get("day_ended_reason", "unset")), "", "new run should have no day-end reason")

	_assert_true(game.spend_action("test-spend"), "first spend should succeed")
	_assert_eq(_action_economy_signal_count, 1, "successful spend should emit once")
	_assert_eq(int(_last_action_economy_snapshot.get("actions_remaining", -1)), 4, "signal snapshot should reflect remaining actions")
	var spend_change: Dictionary = _last_action_economy_snapshot.get("change", {})
	_assert_eq(str(spend_change.get("kind", "")), "spend", "change kind should be spend")
	_assert_eq(str(spend_change.get("target_id", "")), "test-spend", "change target should be action type")
	_assert_true(bool(spend_change.get("active", false)), "spend should be active in change metadata")

	initial["actions_remaining"] = 99
	_assert_eq(game.actions_remaining, 4, "snapshot must be a copy, not live state")

	for index in 4:
		_assert_true(game.spend_action("drain-%d" % index), "remaining actions should be spendable")
	_assert_eq(_action_economy_signal_count, 5, "each successful spend should emit")
	_assert_eq(game.actions_remaining, 0, "five spends should deplete the day")
	_assert_true(bool(_last_action_economy_snapshot.get("needs_day_settlement", false)), "last spend should mark day settlement")
	_assert_eq(str(_last_action_economy_snapshot.get("day_ended_reason", "")), "drain-3", "last spend should preserve action type as day-end reason")

	_action_economy_signal_count = 0
	_assert_true(not game.spend_action("blocked"), "spend at zero should fail")
	_assert_eq(_action_economy_signal_count, 0, "failed spend should not emit")


func _capture_action_economy(snapshot: Dictionary) -> void:
	_action_economy_signal_count += 1
	_last_action_economy_snapshot = snapshot


func test_autoplay_lives_in_the_run_model() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	var manager := ServiceRegistry.resolve(ServiceKeys.PROPERTY_MANAGER) as PropertyManager
	var autoplay := manager.model(PropertyKeys.AUTOPLAY_ENABLED)
	var seen: Array = []
	var listener := func(value: Variant) -> void: seen.append(value)
	autoplay.register(listener)
	_assert_eq(seen, [false], "new run should start with autoplay off")
	_assert_true(not game.has_signal("settings_changed"), "the old settings signal should be gone")
	_assert_true(not ("autoplay_enabled" in game), "autoplay should not keep a field on the state")

	game.set_autoplay_enabled(true)
	game.set_autoplay_enabled(true)
	game.set_autoplay_enabled(false)
	_assert_eq(seen, [false, true, false], "autoplay intents should write the model once per change")
	autoplay.unregister(listener)

	_assert_true(not game.exit_prompt_seen, "new run should start without exit prompt seen")
	game.mark_exit_prompt_seen()
	game.mark_exit_prompt_seen()
	_assert_true(game.exit_prompt_seen, "marking the exit prompt should stick")


func test_reality_conversation_snapshot_reads_the_models() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()

	var idle: Dictionary = game.get_reality_conversation_snapshot()
	_assert_eq(str(idle.get("phase", "")), "idle", "new run should start with idle conversation")
	_assert_eq(str(idle.get("mode", "")), "authored", "idle conversation should default to authored mode")
	_assert_eq(str(idle.get("actor_type", "")), "npc", "idle conversation should default to npc actor type")
	_assert_eq(str(idle.get("actor_label", "unset")), "", "idle conversation should have no actor label")
	_assert_eq(str(idle.get("prompt", "unset")), "", "idle conversation should have no prompt")
	_assert_eq(str(idle.get("result_line", "unset")), "", "idle conversation should have no result line")
	_assert_eq((idle.get("choices", ["x"]) as Array).size(), 0, "idle conversation should have no choices")
	_assert_true(not bool(idle.get("can_continue", true)), "idle conversation should not continue")
	_assert_eq(str(idle.get("feedback", "unset")), "", "idle conversation should have no feedback")
	_assert_eq(int(idle.get("reveal_index", -1)), 0, "idle conversation should start at reveal index 0")
	_assert_true(not idle.has("turns"), "display snapshot must not expose the turn engine")
	_assert_true(not idle.has("history"), "display snapshot must not expose conversation history")
	_assert_true(not idle.has("actor_id"), "display snapshot must not expose actor id")
	_assert_true(not idle.has("change"), "display snapshot should not carry a change record any more")

	_assert_true(game.start_typed_reality_conversation("floor1npc0", "npc", "迟到者"), "npc conversation should start")
	var started: Dictionary = game.get_reality_conversation_snapshot()
	_assert_eq(str(started.get("phase", "")), "choosing", "snapshot should enter choosing")
	_assert_eq(str(started.get("mode", "")), "authored", "npc conversation should be authored")
	_assert_eq(str(started.get("actor_type", "")), "npc", "snapshot should carry npc type")
	_assert_eq(str(started.get("actor_label", "")), "迟到者", "snapshot should carry actor label")
	_assert_eq(str(started.get("prompt", "")), "这张票印的是明天。可车刚走。你能陪我等下一班吗？", "snapshot should carry the authored prompt")
	_assert_eq(str(started.get("result_line", "")), "迟到者把票折回掌心，往旁边让出半个座位。", "snapshot should carry the authored result line")
	_assert_eq((started.get("choices", []) as Array).size(), 3, "snapshot should include authored choices")
	_assert_eq(_conversation_model(PropertyKeysScript.CONVERSATION_PHASE).read(), "choosing", "the phase should live in its model")
	_assert_eq((_conversation_model(PropertyKeysScript.CONVERSATION_CHOICES).read() as Array).size(), 3, "the choices should live in their model")

	var snapshot: Dictionary = game.get_reality_conversation_snapshot()
	snapshot["prompt"] = "mutated"
	_assert_eq(game.conversation_prompt, "这张票印的是明天。可车刚走。你能陪我等下一班吗？", "snapshot strings must be copies")
	var choices_copy: Array = snapshot.get("choices", [])
	choices_copy.append({"id": "alias-test"})
	_assert_eq(game.get_typed_reality_choices().size(), 3, "snapshot choice arrays must be copies")

	game.reset_typed_reality_conversation()
	_assert_eq(str(game.get_reality_conversation_snapshot().get("phase", "")), "idle", "reset should return to idle")
	_assert_eq(_conversation_model(PropertyKeysScript.CONVERSATION_PHASE).read(), "idle", "reset should write the phase model back")
	_assert_eq((_conversation_model(PropertyKeysScript.CONVERSATION_CHOICES).read() as Array).size(), 0, "reset should empty the choices model")

	_assert_true(game.start_typed_reality_conversation("doctor_floor1", "doctor", "医生"), "doctor conversation should start")
	game.configure_conversation_locale("en")
	var localized: Dictionary = game.get_reality_conversation_snapshot()
	_assert_eq(str(localized.get("actor_label", "")), "Doctor", "locale intent should localize actor label in the snapshot")
	_assert_eq(
		str(localized.get("prompt", "")),
		"Say that line again. Do not explain it for me.",
		"locale intent should localize prompt in the snapshot"
	)
	_assert_eq(
		str(localized.get("result_line", "")),
		"The doctor writes it down. The character count does not match what you said.",
		"locale intent should localize result line in the snapshot"
	)
	_assert_eq(str(localized.get("phase", "")), "composing", "doctor conversation should stay in composing")
	_assert_eq(str(localized.get("mode", "")), "lexeme", "doctor conversation should stay in lexeme mode")

	_assert_true(game.start_typed_reality_conversation("floor1npc0", "npc", "迟到者"), "npc conversation should restart for intents")
	var npc_choice_id := str(game.get_typed_reality_choices()[0].get("id", ""))
	_assert_true(game.select_typed_reality_choice(npc_choice_id), "select intent should succeed")
	var selected: Dictionary = game.get_reality_conversation_snapshot()
	_assert_eq(str(selected.get("phase", "")), "typing", "select should enter typing")
	_assert_eq(int(selected.get("reveal_index", -1)), 0, "select should reset reveal index")

	var advance_result: Dictionary = game.advance_typed_reality_character()
	_assert_true(bool(advance_result.get("advanced", false)), "advance intent should reveal one character")
	var advanced: Dictionary = game.get_reality_conversation_snapshot()
	_assert_eq(int(advanced.get("reveal_index", -1)), 1, "advance should carry the reveal index")
	_assert_eq((advanced.get("revealed_units", []) as Array).size(), 1, "advance should include revealed units")
	_assert_eq(_conversation_model(PropertyKeysScript.CONVERSATION_REVEAL_INDEX).read(), 1, "the reveal index should live in its model")
	_assert_eq((_conversation_model(PropertyKeysScript.CONVERSATION_REVEALED_UNITS).read() as Array).size(), 1, "the revealed units should live in their model")

	while str(game.conversation_phase) == "typing":
		game.advance_typed_reality_character()
	var finished: Dictionary = game.get_reality_conversation_snapshot()
	_assert_eq(str(finished.get("phase", "")), "result", "final advance should land in result")
	if bool(finished.get("can_continue", false)):
		_assert_true(game.continue_typed_reality_conversation(), "continue intent should advance to next turn")
		_assert_eq(str(game.get_reality_conversation_snapshot().get("phase", "")), "choosing", "continue should return to choosing")

	game.reset_typed_reality_conversation()
	game.actions_remaining = 0
	_assert_true(not game.start_typed_reality_conversation("floor1npc0", "npc", "迟到者"), "conversation should not start without actions")
	_assert_eq(str(game.get_reality_conversation_snapshot().get("phase", "")), "idle", "a failed start should leave the conversation idle")


func _conversation_model(property_name: String) -> PropertyModel:
	var manager: PropertyManager = RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	return manager.model(property_name)


func test_day_progress_snapshot_and_signal() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	_day_progress_signal_count = 0
	_last_day_progress_snapshot = {}
	game.day_progress_changed.connect(_capture_day_progress)

	var initial: Dictionary = game.get_day_progress_snapshot()
	_assert_eq(int(initial.get("day", -1)), 1, "new run should start on day one")
	_assert_eq(int(initial.get("pollution", -1)), 0, "new run should start at zero pollution")
	_assert_eq(int(initial.get("tower_floor", -1)), 1, "new run should start on floor one")
	_assert_true(not bool(initial.get("needs_day_settlement", true)), "new run should not need settlement")
	_assert_eq(str(initial.get("day_ended_reason", "unset")), "", "new run should have no day-end reason")
	_assert_eq(int(initial.get("pending_floor_transition", -1)), 0, "new run should have no pending floor transition")

	game.change_pollution(10)
	_assert_eq(_day_progress_signal_count, 1, "pollution change should emit once")
	_assert_eq(int(_last_day_progress_snapshot.get("pollution", -1)), 10, "signal snapshot should reflect pollution")
	var pollution_change: Dictionary = _last_day_progress_snapshot.get("change", {})
	_assert_eq(str(pollution_change.get("kind", "")), "pollution", "change kind should be pollution")
	_assert_eq(str(pollution_change.get("target_id", "")), "10", "change target should be the delta argument")
	_assert_true(bool(pollution_change.get("active", false)), "positive pollution delta should be active")

	initial["pollution"] = 99
	_assert_eq(game.pollution, 10, "snapshot must be a copy, not live state")

	_day_progress_signal_count = 0
	game.change_pollution(0)
	_assert_eq(_day_progress_signal_count, 0, "zero delta should not emit")

	game.change_pollution(15)
	_assert_eq(int(_last_day_progress_snapshot.get("pending_floor_transition", -1)), 2, "floor-one threshold should queue floor two")
	_assert_eq(int(_last_day_progress_snapshot.get("tower_floor", -1)), 1, "pollution alone must not move tower floor immediately")

	game.change_pollution(35)
	_assert_eq(int(_last_day_progress_snapshot.get("pollution", -1)), 60, "pollution should clamp at 100")
	_assert_true(bool(_last_day_progress_snapshot.get("needs_day_settlement", false)), "flashback crossing should mark day settlement")
	_assert_eq(str(_last_day_progress_snapshot.get("day_ended_reason", "")), "pollution-flashback", "flashback should preserve its cause")

	_day_progress_signal_count = 0
	for index in 5:
		game.spend_action("settle-%d" % index)
	game.settle_day_if_needed()
	_assert_eq(_day_progress_signal_count, 2, "settlement with pending floor transition should emit floor_transition then settle_day")
	var settle_change: Dictionary = _last_day_progress_snapshot.get("change", {})
	_assert_eq(str(settle_change.get("kind", "")), "settle_day", "last settlement signal should be settle_day")
	_assert_eq(str(settle_change.get("target_id", "")), "2", "settle_day target should be the new day number")
	_assert_eq(int(_last_day_progress_snapshot.get("day", -1)), 2, "settle snapshot should reflect the new day")
	_assert_eq(int(_last_day_progress_snapshot.get("tower_floor", -1)), 2, "settle snapshot should include floor advanced at boundary")


func test_day_progress_settle_day_signal() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	_day_progress_signal_count = 0
	_last_day_progress_snapshot = {}
	game.day_progress_changed.connect(_capture_day_progress)
	game.needs_day_settlement = true
	game.day_ended_reason = "actions-depleted"
	_assert_true(game.settle_day_if_needed(), "requested settlement should run")
	_assert_eq(_day_progress_signal_count, 1, "settle_day should emit once when no floor transition occurs")
	var settle_change: Dictionary = _last_day_progress_snapshot.get("change", {})
	_assert_eq(str(settle_change.get("kind", "")), "settle_day", "change kind should be settle_day")
	_assert_eq(str(settle_change.get("target_id", "")), "2", "settle_day target should be the new day number")
	_assert_true(bool(settle_change.get("active", false)), "settle_day should be active")
	_assert_eq(int(_last_day_progress_snapshot.get("day", -1)), 2, "snapshot should reflect day two after settlement")
	_assert_true(not bool(_last_day_progress_snapshot.get("needs_day_settlement", true)), "settlement should clear needs_day_settlement")


func test_day_progress_floor_transition_signal() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	_day_progress_signal_count = 0
	_last_day_progress_snapshot = {}
	game.day_progress_changed.connect(_capture_day_progress)
	game.pollution = 25
	_assert_eq(game.resolve_floor_transition_at_boundary(), 2, "pollution boundary should advance the floor")
	_assert_eq(_day_progress_signal_count, 1, "floor transition should emit once")
	var floor_change: Dictionary = _last_day_progress_snapshot.get("change", {})
	_assert_eq(str(floor_change.get("kind", "")), "floor_transition", "change kind should be floor_transition")
	_assert_eq(str(floor_change.get("target_id", "")), "2", "floor_transition target should be the new floor")
	_assert_true(bool(floor_change.get("active", false)), "floor_transition should be active")
	_assert_eq(int(_last_day_progress_snapshot.get("tower_floor", -1)), 2, "snapshot should reflect floor two")
	_day_progress_signal_count = 0
	_assert_eq(game.resolve_floor_transition_at_boundary(), 2, "repeat boundary call should not advance again")
	_assert_eq(_day_progress_signal_count, 0, "no-op floor transition should not emit")


func _capture_day_progress(snapshot: Dictionary) -> void:
	_day_progress_signal_count += 1
	_last_day_progress_snapshot = snapshot


func test_inventory_snapshot_without_a_change_signal() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	_assert_true(not game.has_signal("inventory_changed"), "held words and memes live in models, so the inventory change signal should be gone")

	var initial: Dictionary = game.get_inventory_snapshot()
	_assert_eq((initial.get("completed_memes", ["x"]) as Array).size(), 0, "new run should start with no completed memes")
	_assert_eq(int(initial.get("notebook_token_count", -1)), 0, "new run should start with no notebook tokens")
	_assert_true((initial.get("draft_slots", {"x": "y"}) as Dictionary).is_empty(), "new run should start with empty draft slots")
	_assert_true((initial.get("craft_slot_fills", {"x": "y"}) as Dictionary).is_empty(), "new run should start with empty craft slot fills")

	game.notebook_tokens = _complete_note_tokens()
	_assert_true(game.place_token_in_slot("subject", "subject-1"), "subject token should enter craft slot")
	_assert_true(game.place_token_in_slot("action", "action-1"), "action token should enter craft slot")
	_assert_true(game.place_token_in_slot("object", "object-1"), "object token should enter craft slot")

	var arranged: Dictionary = game.get_inventory_snapshot()
	_assert_eq(int(arranged.get("notebook_token_count", -1)), 3, "snapshot should count notebook tokens")
	_assert_eq(str((arranged.get("draft_slots", {}) as Dictionary).get("subject", "")), "subject-1", "snapshot should carry draft slot ids")
	_assert_eq(str((arranged.get("craft_slot_fills", {}) as Dictionary).get("subject", "")), "我", "snapshot should summarize filled slot text")

	_assert_true(game.confirm_craft(), "confirm craft should succeed")
	var snapshot: Dictionary = game.get_inventory_snapshot()
	_assert_eq((snapshot.get("completed_memes", []) as Array).size(), 1, "snapshot should list one completed meme")
	_assert_eq(str((snapshot.get("completed_memes", [])[0] as Dictionary).get("text", "")), "本账号捕获信号塔。", "snapshot should preserve crafted meme text")
	_assert_true((snapshot.get("draft_slots", {"x": "y"}) as Dictionary).is_empty(), "snapshot should clear draft slots after craft")
	var memes_copy: Array = snapshot.get("completed_memes", [])
	memes_copy.append({"id": "alias-test"})
	_assert_eq(game.completed_memes.size(), 1, "snapshot meme arrays must be copies")
	var draft_slots_copy: Dictionary = snapshot.get("draft_slots", {})
	draft_slots_copy["subject"] = "alias-test"
	_assert_true(not game.draft_slots.has("subject"), "snapshot draft slot maps must be copies")
	_assert_true(not game.confirm_craft(), "incomplete craft should fail")

	game.new_run()
	game.completed_memes = [
		{"id": "meme-left", "title": "左梗", "text": "左", "tags": [], "rarity": 1, "pollution_bias": 1, "fusion_level": 0, "unit_count": 1},
		{"id": "meme-right", "title": "右梗", "text": "右", "tags": [], "rarity": 1, "pollution_bias": 1, "fusion_level": 0, "unit_count": 1},
	]
	game.fusion_slots.clear()
	_assert_true(game.place_meme_in_fusion_slot("left", "meme-left"), "left meme should enter fusion slot")
	_assert_true(game.place_meme_in_fusion_slot("right", "meme-right"), "right meme should enter fusion slot")
	_assert_true(game.confirm_meme_fusion(), "fusion should succeed")
	var fused: Dictionary = game.get_inventory_snapshot()
	_assert_eq((fused.get("completed_memes", []) as Array).size(), 3, "fusion snapshot should list the fused meme")
	_assert_true((fused.get("fusion_slots", {"x": "y"}) as Dictionary).is_empty(), "fusion snapshot should clear fusion slots after confirm")


func test_progression_snapshot_and_signal() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	_progression_signal_count = 0
	_last_progression_snapshot = {}
	game.progression_changed.connect(_capture_progression)

	var initial: Dictionary = game.get_progression_snapshot()
	_assert_true(not bool(initial.get("ending_unlocked", true)), "new run should start without an unlocked ending")
	_assert_true(not bool(initial.get("floor3_task_complete", true)), "new run should start with floor-three task incomplete")
	_assert_true(not bool(initial.get("floor4_task_complete", true)), "new run should start with floor-four task incomplete")

	game.tower_floor = 3
	game.free_sentence_units = ["门", "可", "以", "打", "开"]
	game.submit_free_sentence("zh")
	_assert_eq(_progression_signal_count, 1, "floor-three task latch should emit once")
	var floor3_change: Dictionary = _last_progression_snapshot.get("change", {})
	_assert_eq(str(floor3_change.get("kind", "")), "floor3_task", "change kind should be floor3_task")
	_assert_true(bool(_last_progression_snapshot.get("floor3_task_complete", false)), "snapshot should reflect the latched task")

	game.pollution = 80
	_progression_signal_count = 0
	_assert_eq(game.complete_floor_three(), "normal-ending", "formal floor-three completion should resolve the normal route")
	_assert_eq(_progression_signal_count, 1, "complete_floor_three should emit once")
	var ending_change: Dictionary = _last_progression_snapshot.get("change", {})
	_assert_eq(str(ending_change.get("kind", "")), "complete_floor_three", "change kind should be complete_floor_three")
	_assert_eq(str(ending_change.get("target_id", "")), "normal-ending", "normal route should be reported in change metadata")
	_assert_true(bool(_last_progression_snapshot.get("ending_unlocked", false)), "normal ending should unlock")

	_progression_signal_count = 0
	_assert_true(game.choose_ending_language("blank"), "ending language choice should succeed once")
	_assert_eq(_progression_signal_count, 0, "choose_ending_language should not emit; the screen watches the model")
	_assert_eq(game.ending_language_choice, "blank", "the chosen language should read back from the model")

	game.new_run()
	game.tower_floor = 4
	game.ending_route = "hidden"
	game.floor4_task_complete = true
	game.ending_unlocked = false
	_progression_signal_count = 0
	game._resolve_tower_step()
	_assert_eq(_progression_signal_count, 1, "hidden ending unlock at day boundary should emit once")
	var unlock_change: Dictionary = _last_progression_snapshot.get("change", {})
	_assert_eq(str(unlock_change.get("kind", "")), "ending_unlock", "change kind should be ending_unlock")
	_assert_true(bool(_last_progression_snapshot.get("ending_unlocked", false)), "snapshot should reflect hidden ending unlock")


func _capture_progression(snapshot: Dictionary) -> void:
	_progression_signal_count += 1
	_last_progression_snapshot = snapshot


func test_pick_token_costs_action_and_adds_notebook_token() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	_assert_true(game.pick_token("p1", {
		"id": "t1",
		"text": "末班电梯",
		"lexeme_id": "subject.last_lift",
		"grammar_roles": ["subject"],
		"phone_surface": "末班电梯账号",
		"doctor_surface": "反复梦见电梯的患者",
		"doll_surface": "回家的电梯",
		"tags": ["巴别塔"],
		"rarity": 2,
	}), "a new Chinese token should be pickable")
	_assert_eq(game.actions_remaining, 4, "picking a token should spend one action")
	_assert_eq(game.notebook_tokens.size(), 1, "picked token should enter the notebook")
	_assert_eq(str(game.notebook_tokens[0].get("text", "")), "末班电梯", "Chinese pickup should preserve the authored phrase")
	_assert_eq(str(game.notebook_tokens[0].get("lexeme_id", "")), "subject.last_lift", "pickup should preserve a stable lexeme id")
	_assert_eq(game.pollution, 0, "collecting vocabulary should not pollute the player before it is used")


func test_japanese_pickup_preserves_complete_token() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	_assert_true(game.pick_token("ja-existence", {
		"id": "existence", "text": "  「存在」。 ", "content_locale": "ja", "tags": ["空位"], "rarity": 1,
	}), "Japanese existence token should be pickable")
	_assert_eq(str(game.notebook_tokens[0].get("text", "")), "「存在」。", "Japanese pickup should preserve the complete authored selection")
	_assert_true(game.pick_token("ja-elevator", {
		"id": "elevator", "text": "『エレベーター』", "content_locale": "ja", "tags": ["巴别塔"], "rarity": 1,
	}), "Japanese elevator token should be pickable")
	_assert_eq(str(game.notebook_tokens[1].get("text", "")), "『エレベーター』", "Japanese kana selection should remain intact")


func test_complete_sentence_craft_uses_authored_phone_surfaces() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	game.notebook_tokens = _complete_note_tokens()
	_assert_eq(game.get_craft_slots().size(), 3, "the notebook should expose subject, action, and object slots")
	_assert_true(game.place_token_in_slot("subject", "subject-1"), "a subject word should enter the subject slot")
	_assert_true(game.place_token_in_slot("action", "action-1"), "an action word should enter the action slot")
	_assert_true(game.place_token_in_slot("object", "object-1"), "an object word should enter the object slot")
	_assert_eq(game.actions_remaining, 5, "arranging sentence words should remain free")
	var preview: Dictionary = game.get_craft_sentence_preview("phone")
	_assert_eq(str(preview.get("clean_sentence", "")), "我看见塔。", "the notebook should retain the player's clean sentence")
	_assert_eq(str(preview.get("world_sentence", "")), "本账号捕获信号塔。", "the phone preview should use authored social-media surfaces")
	_assert_true(game.confirm_craft(), "a complete three-part sentence should craft")
	_assert_eq(game.actions_remaining, 4, "confirming craft should spend one action")
	_assert_eq(str(game.completed_memes[0].get("text", "")), "本账号捕获信号塔。", "crafted phone sentence should preserve its authored world surface")
	_assert_eq(str(game.completed_memes[0].get("clean_text", "")), "我看见塔。", "crafted data should preserve the player's original sentence")
	_assert_eq(game.owned_meme_frames, 0, "sentence crafting should not require or consume a doll frame")


func test_publish_updates_money_and_pollution_only() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	game.notebook_tokens = _complete_note_tokens()
	var meme := _completed_sentence_meme()
	game.completed_memes = [meme]
	var expected: Dictionary = game.get_publish_result(meme)
	var money_before: int = game.money
	var pollution_before: int = game.pollution
	_assert_true(game.place_meme_in_blank("blank_1", "m-publish"), "placing a meme should be free")
	_assert_true(game.confirm_dialogue(), "the placed meme should publish")
	_assert_eq(game.money, money_before + int(expected.get("money_gain", 0)), "publishing should add the previewed money")
	_assert_eq(game.pollution, pollution_before + int(expected.get("pollution_gain", 0)), "publishing should add the previewed pollution")
	_assert_eq(game.published_memes.size(), 1, "publication should leave one floor record")
	_assert_eq(int(game.published_memes[0].get("money_gain", 0)), int(expected.get("money_gain", 0)), "record should preserve the money calculation")
	for token: Dictionary in game.notebook_tokens:
		_assert_true("phone" in token.get("used_worlds", []), "publishing should mark every sentence word as used by the phone world")


func test_floor_ascent_does_not_create_inherited_language_rules() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	game.published_memes = [_completed_sentence_meme()]
	game.pollution = 25
	_assert_eq(game.resolve_floor_transition_at_boundary(), 2, "pollution boundary should still advance the floor")
	_assert_true(not game.has_method("register_legacy_rule_for_ascent"), "floor ascent should no longer register inherited sentence rules")
	_assert_true(not game.has_method("get_required_legacy_tiles"), "doctor dialogue should no longer expose legacy tiles")


func test_doctor_only_accepts_words_published_in_phone_world() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	game.notebook_tokens = _complete_note_tokens()
	_assert_true(game.get_language_token_options("doctor").is_empty(), "unpublished notebook words should not be available to the doctor")
	game.notebook_tokens = LanguageBridgeScript.mark_tokens_used(
		game.notebook_tokens,
		["subject-1", "action-1", "object-1"],
		"phone"
	)
	_assert_eq(game.get_language_token_options("doctor").size(), 3, "published words should cross into the doctor world")
	_assert_true(game.start_typed_reality_conversation("doctor_floor1", "doctor", "医生"), "doctor conversation should enter lexeme composition")
	_assert_true(not game.place_language_token("subject", "object-1", "doctor"), "a word cannot enter the wrong grammar slot")


func test_doctor_sentence_uses_authored_surfaces_and_adds_pollution() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	game.notebook_tokens = _published_note_tokens()
	_assert_true(game.start_typed_reality_conversation("doctor_floor1", "doctor", "医生"), "doctor conversation should start")
	_assert_true(game.place_language_token("subject", "subject-1", "doctor"), "doctor subject should be placeable")
	_assert_true(game.place_language_token("action", "action-1", "doctor"), "doctor action should be placeable")
	_assert_true(game.place_language_token("object", "object-1", "doctor"), "doctor object should be placeable")
	_assert_eq(game.actions_remaining, 5, "arranging doctor words should remain free")
	var preview: Dictionary = game.get_language_sentence_preview("doctor")
	_assert_eq(str(preview.get("clean_sentence", "")), "我看见塔。", "doctor bridge should preserve the original player sentence")
	_assert_eq(str(preview.get("world_sentence", "")), "患者报告病区。", "doctor bridge should use authored clinical surfaces")
	var money_before: int = game.money
	var pollution_before: int = game.pollution
	_assert_true(game.confirm_doctor_sentence(), "a complete doctor sentence should resolve")
	_assert_eq(game.actions_remaining, 4, "speaking to the doctor should spend exactly one action")
	_assert_eq(game.money, money_before, "doctor dialogue should never grant or remove money")
	_assert_true(game.pollution > pollution_before, "using phone words with the doctor should increase pollution")
	_assert_eq(game.reality_phase, "reality_result", "doctor confirmation should expose the reality result")
	_assert_eq(game.sentence_records.size(), 1, "doctor speech should leave one auditable sentence record")
	_assert_eq(str(game.sentence_records[0].get("world_sentence", "")), "患者报告病区。", "sentence record should retain the authored doctor wording")


func test_typed_reality_reveals_one_character_and_never_grants_frames() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	_assert_true(game.start_typed_reality_conversation("floor1npc0", "npc", "迟到者"), "ordinary NPC dialogue should start")
	var choice_id := str(game.get_typed_reality_choices()[0].get("id", ""))
	_assert_true(game.select_typed_reality_choice(choice_id), "response should enter per-character delivery")
	var first_result: Dictionary = game.advance_typed_reality_character()
	_assert_true(bool(first_result.get("advanced", false)), "one key should reveal one character")
	_assert_eq(game.actions_remaining, 5, "partial delivery should remain free")
	while game.conversation_phase == "typing":
		game.advance_typed_reality_character()
	_assert_eq(game.actions_remaining, 4, "completing the spoken turn should spend one action")
	_assert_eq(game.owned_meme_frames, 0, "ordinary NPC dialogue must never grant a meme frame")
	_assert_true(game.conversation_reward.is_empty(), "ordinary NPC result should have no reward payload")


func test_first_crossing_sixty_triggers_flashback_and_forces_day_end() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	game.pollution = 59
	game.change_pollution(1)
	_assert_true(game.pollution_flashback_pending, "first 60% crossing should queue the flashback")
	_assert_true(game.pollution_flashback_seen, "first crossing should be remembered for the run")
	_assert_eq(game.actions_remaining, 0, "flashback should consume the rest of the day")
	_assert_true(game.needs_day_settlement, "flashback should request day settlement")
	_assert_eq(game.day_ended_reason, "pollution-flashback", "forced settlement should preserve its cause")
	_assert_true(game.consume_pollution_flashback(), "pending flashback should be consumable once")
	_assert_true(game.settle_day_if_needed(), "flashback day should settle after the sequence")
	_assert_eq(game.day, 2, "flashback should advance to the next day")


func test_flashback_trigger_is_once_per_run() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	game.pollution = 60
	_assert_true(game.check_pollution_flashback(59), "first threshold crossing should trigger")
	_assert_true(game.consume_pollution_flashback(), "first trigger should be consumable")
	game.actions_remaining = 4
	game.needs_day_settlement = false
	game.pollution = 72
	_assert_true(not game.check_pollution_flashback(61), "later growth above 60 should not retrigger")
	_assert_eq(game.actions_remaining, 4, "later pollution growth should not erase remaining actions")


func test_gameplay_metrics_are_limited_to_money_and_pollution() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	var metrics: Dictionary = game.get_gameplay_metrics()
	_assert_eq(metrics.size(), 2, "core gameplay should expose only two numeric metrics")
	_assert_true(metrics.has("money") and metrics.has("pollution"), "the two metrics should be money and pollution")


func _complete_note_tokens() -> Array:
	return [
		_note_token("subject-1", "我", "speaker.self", ["subject"], "本账号", "患者", "你"),
		_note_token("action-1", "看见", "perceive.see", ["action"], "捕获", "报告", "记得"),
		_note_token("object-1", "塔", "place.tower", ["object"], "信号塔", "病区", "出口"),
	]


func _published_note_tokens() -> Array:
	var tokens := _complete_note_tokens()
	for token: Dictionary in tokens:
		token["used_worlds"] = ["phone"]
		token["pollution_stage"] = 1
	return tokens


func _note_token(
	token_id: String,
	text: String,
	lexeme_id: String,
	roles: Array,
	phone_surface: String,
	doctor_surface: String,
	doll_surface: String
) -> Dictionary:
	return {
		"id": token_id,
		"text": text,
		"lexeme_id": lexeme_id,
		"grammar_roles": roles,
		"phone_surface": phone_surface,
		"doctor_surface": doctor_surface,
		"doll_surface": doll_surface,
		"tags": ["test"],
		"rarity": 1,
		"pollution_stage": 0,
		"used_worlds": [],
	}


func _completed_sentence_meme() -> Dictionary:
	return {
		"id": "m-publish",
		"text": "本账号捕获信号塔。",
		"clean_text": "我看见塔。",
		"token_ids": ["subject-1", "action-1", "object-1"],
		"lexeme_ids": ["speaker.self", "perceive.see", "place.tower"],
		"tags": ["test"],
		"rarity": 2,
		"pollution_bias": 1,
		"fusion_level": 0,
	}


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s. Expected %s, got %s" % [message, str(expected), str(actual)])
