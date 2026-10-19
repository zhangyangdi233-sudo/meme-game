extends SceneTree

const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")

var _failures: Array[String] = []
var _state_script: Script = null


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
	test_navigation_and_actions_never_end_the_day()
	test_social_follow_and_like_toggles_are_persistent()
	test_social_engagement_lives_in_the_models()
	test_phone_shell_state_lives_in_models()
	test_autoplay_lives_in_the_run_model()
	test_reality_conversation_snapshot_reads_the_models()
	test_day_progress_lives_in_models()
	test_floor_transition_writes_the_floor_model()
	test_day_progress_survives_save_and_resets_on_new_run()
	test_inventory_snapshot_without_a_change_signal()
	test_progression_snapshot_and_models()
	test_pick_token_adds_notebook_token()
	test_japanese_pickup_preserves_complete_token()
	test_complete_sentence_craft_uses_authored_phone_surfaces()
	test_floor_ascent_does_not_create_inherited_language_rules()
	test_typed_reality_reveals_one_character_and_never_grants_frames()
	test_first_crossing_sixty_triggers_flashback_without_ending_the_day()
	test_flashback_trigger_is_once_per_run()


func test_navigation_and_actions_never_end_the_day() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	game.set_phone_open(true)
	game.set_active_app("social")
	for index in 8:
		game.free_sentence_units = ["灯"]
		_assert_true(bool(game.submit_free_sentence("zh").get("submitted", false)), "post %d should go through" % (index + 1))
	_assert_eq(game.day, 1, "acting should never move the day on")


func test_social_follow_and_like_toggles_are_persistent() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	_assert_true(game.toggle_social_follow("塔下夜巡"), "following should enter run state")
	_assert_true(game.toggle_social_like("missing_window"), "liking should enter run state")
	var restored: RefCounted = _state_script.new()
	_assert_true(restored.load_save_data(game.to_save_data()), "the save should load")
	_assert_true(restored.is_social_following("塔下夜巡"), "follow state should survive the save")
	_assert_true(restored.is_social_post_liked("missing_window"), "like state should survive the save")


func test_social_engagement_lives_in_the_models() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	_assert_true(game.toggle_social_follow("author-a"), "follow should activate")
	_assert_true(game.is_social_following("author-a"), "a followed author should read as followed")
	_assert_true(game.toggle_social_like("post-1"), "like should activate")
	_assert_true(game.is_social_post_liked("post-1"), "a liked post should read as liked")
	_assert_true(not game.toggle_social_follow("  "), "a blank handle should not be followed")
	_assert_true(not game.toggle_social_like(""), "a blank post should not be liked")

	var followed_copy: Array = game.get_social_followed_handles()
	followed_copy.append("alias-test")
	_assert_true(not game.is_social_following("alias-test"), "the followed list read out must be a copy")

	var migrated: Array[String] = ["author-b"]
	game.replace_social_followed_handles(migrated)
	_assert_true(game.is_social_following("author-b"), "bulk replace should update follow state")
	_assert_true(not game.is_social_following("author-a"), "bulk replace should drop prior follows")
	_assert_true(not game.toggle_social_follow("author-b"), "toggling a followed author should unfollow")
	_assert_true(not game.is_social_following("author-b"), "an unfollowed author should no longer read as followed")
	_assert_true(not game.toggle_social_like("post-1"), "toggling a liked post should unlike")
	_assert_true(not game.is_social_post_liked("post-1"), "an unliked post should no longer read as liked")


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

	game.close_app_window("babel")
	_assert_eq(str(game.active_app_window), "social", "closing the foreground window should fall back to the remaining open one")
	_assert_true(not game.is_app_window_open("babel"), "a closed window should not read as open")

	game.close_app_window("social")
	game.set_active_app("social")
	game.set_active_app("notebook")
	game.close_app_window("notebook")
	_assert_true(game.is_app_window_open("social"), "closing one window should keep the others open")
	_assert_true(not game.is_app_window_open("notebook"), "closing a window should drop it from the open list")
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
	_assert_true(loaded.load_save_data({"version": _state_script.SAVE_DATA_VERSION, "state": old_state}), "a save without the phone fields should load")
	_assert_true(not bool(loaded.phone_open), "a save put down without a phone field should load with the phone closed")
	_assert_true(str(loaded.active_app_window).is_empty(), "a save put down should load without a foreground app")

	game.set_phone_open(false)
	_assert_true(not bool(game.phone_open), "closing the phone should write the model")
	_assert_true(str(game.active_app_window).is_empty(), "closing phone should clear foreground window")


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

	_assert_true(game.start_typed_reality_conversation("doctor_floor1", "doctor", "医生"), "an unknown actor type should start as an ordinary NPC")
	_assert_eq(str(game.get_reality_conversation_snapshot().get("actor_type", "")), "npc", "the doctor is gone from the world, so it reads as an NPC")
	_assert_eq(str(game.get_reality_conversation_snapshot().get("mode", "")), "authored", "no conversation composes lexemes any more")

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



func _conversation_model(property_name: String) -> PropertyModel:
	var manager: PropertyManager = RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	return manager.model(property_name)


func test_day_progress_lives_in_models() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	_assert_true(not game.has_signal("day_progress_changed"), "the day progress signal should be gone")
	for field_name in ["day", "tower_floor", "pending_floor_transition"]:
		_assert_true(PropertyKeysScript.is_run(field_name), "%s should be a run model" % field_name)
		_assert_true(not _state_script.SAVE_FIELD_NAMES.has(field_name), "%s should be saved from its model, not the field list" % field_name)

	var initial: Dictionary = game.get_day_progress_snapshot()
	_assert_eq(int(initial.get("day", -1)), 1, "new run should start on day one")
	_assert_eq(int(initial.get("pollution", -1)), 0, "new run should start at zero pollution")
	_assert_eq(int(initial.get("tower_floor", -1)), 1, "new run should start on floor one")
	_assert_true(not initial.has("needs_day_settlement") and not initial.has("day_ended_reason"), "the snapshot should carry no day settlement")
	_assert_eq(int(initial.get("pending_floor_transition", -1)), 0, "new run should have no pending floor transition")

	game.change_pollution(10)
	_assert_eq(_conversation_model(PropertyKeysScript.POLLUTION).read(), 10, "pollution should live in its model")
	initial["pollution"] = 99
	_assert_eq(game.pollution, 10, "snapshot must be a copy, not live state")

	game.change_pollution(15)
	_assert_eq(_conversation_model(PropertyKeysScript.PENDING_FLOOR_TRANSITION).read(), 2, "floor-one threshold should queue floor two in its model")
	_assert_eq(_conversation_model(PropertyKeysScript.TOWER_FLOOR).read(), 1, "pollution alone must not move tower floor immediately")

	game.change_pollution(35)
	_assert_eq(game.pollution, 60, "pollution should add up")
	_assert_true(game.pollution_flashback_pending, "the flashback crossing should queue the flashback")

	game.resolve_floor_transition_at_boundary()
	_assert_eq(_conversation_model(PropertyKeysScript.DAY).read(), 1, "nothing should move the day model")
	_assert_eq(_conversation_model(PropertyKeysScript.TOWER_FLOOR).read(), 2, "the progress check should advance the queued floor")
	_assert_eq(_conversation_model(PropertyKeysScript.PENDING_FLOOR_TRANSITION).read(), 0, "the queued floor should clear once taken")

	game.day = 0
	game.tower_floor = 9
	_assert_eq(game.day, 1, "the day model should not go below one")
	_assert_eq(game.tower_floor, 4, "the floor model should not go above four")


func test_floor_transition_writes_the_floor_model() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	var seen_floors: Array = []
	var listener := func(value: Variant) -> void: seen_floors.append(value)
	_conversation_model(PropertyKeysScript.TOWER_FLOOR).register(listener)
	game.pollution = 25
	_assert_eq(game.resolve_floor_transition_at_boundary(), 2, "pollution boundary should advance the floor")
	_assert_eq(seen_floors, [1, 2], "floor transition should tell the floor listener once")
	_assert_eq(game.resolve_floor_transition_at_boundary(), 2, "repeat boundary call should not advance again")
	_assert_eq(seen_floors, [1, 2], "a no-op floor transition should not write the floor")
	_conversation_model(PropertyKeysScript.TOWER_FLOOR).unregister(listener)


func test_day_progress_survives_save_and_resets_on_new_run() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	game.day = 6
	game.tower_floor = 3
	game.pending_floor_transition = 4
	var saved: Dictionary = game.to_save_data()
	var state_data: Dictionary = saved.get("state", {})
	_assert_eq(int(state_data.get("day", -1)), 6, "the save should carry the day from its model")

	game.new_run()
	_assert_eq(game.day, 1, "new run should reset the day")
	_assert_eq(game.tower_floor, 1, "new run should reset the floor")
	_assert_eq(game.pending_floor_transition, 0, "new run should clear the queued floor")

	var restored: RefCounted = _state_script.new()
	_assert_true(restored.load_save_data(saved), "the save should load")
	_assert_eq(restored.day, 6, "loading should restore the day")
	_assert_eq(restored.tower_floor, 3, "loading should restore the floor")
	_assert_eq(restored.pending_floor_transition, 4, "loading should restore the queued floor")


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
	_assert_true(not snapshot.has("fusion_slots"), "the snapshot should carry no fusion slots")


func test_progression_snapshot_and_models() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	var initial: Dictionary = game.get_progression_snapshot()
	_assert_true(not bool(initial.get("ending_unlocked", true)), "new run should start without an unlocked ending")
	_assert_true(not bool(initial.get("floor3_task_complete", true)), "new run should start with floor-three task incomplete")
	_assert_true(not bool(initial.get("floor4_task_complete", true)), "new run should start with floor-four task incomplete")

	game.tower_floor = 3
	game.free_sentence_units = ["门", "可", "以", "打", "开"]
	game.submit_free_sentence("zh")
	_assert_true(bool(game.get_progression_snapshot().get("floor3_task_complete", false)), "snapshot should reflect the latched task")

	game.pollution = 80
	_assert_eq(game.complete_floor_three(), "normal-ending", "formal floor-three completion should resolve the normal route")
	_assert_true(bool(game.get_progression_snapshot().get("ending_unlocked", false)), "normal ending should unlock")
	_assert_eq(game.ending_route, "normal", "normal route should be recorded")

	_assert_true(game.choose_ending_language("blank"), "ending language choice should succeed once")
	_assert_eq(game.ending_language_choice, "blank", "the chosen language should read back from the model")

	game.new_run()
	game.tower_floor = 4
	game.ending_route = "hidden"
	game.floor4_task_complete = true
	game.ending_unlocked = false
	game.pick_social_char("floor_13", "门", "zh")
	_assert_true(bool(game.get_progression_snapshot().get("ending_unlocked", false)), "snapshot should reflect hidden ending unlock")


func test_pick_token_adds_notebook_token() -> void:
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
	var preview: Dictionary = game.get_craft_sentence_preview("phone")
	_assert_eq(str(preview.get("clean_sentence", "")), "我看见塔。", "the notebook should retain the player's clean sentence")
	_assert_eq(str(preview.get("world_sentence", "")), "本账号捕获信号塔。", "the phone preview should use authored social-media surfaces")
	_assert_true(game.confirm_craft(), "a complete three-part sentence should craft")
	_assert_eq(str(game.completed_memes[0].get("text", "")), "本账号捕获信号塔。", "crafted phone sentence should preserve its authored world surface")
	_assert_eq(str(game.completed_memes[0].get("clean_text", "")), "我看见塔。", "crafted data should preserve the player's original sentence")
	_assert_eq(game.owned_meme_frames, 0, "sentence crafting should not require or consume a doll frame")


func test_floor_ascent_does_not_create_inherited_language_rules() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	game.published_memes = [_completed_sentence_meme()]
	game.pollution = 25
	_assert_eq(game.resolve_floor_transition_at_boundary(), 2, "pollution boundary should still advance the floor")
	_assert_true(not game.has_method("register_legacy_rule_for_ascent"), "floor ascent should no longer register inherited sentence rules")


func test_typed_reality_reveals_one_character_and_never_grants_frames() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	_assert_true(game.start_typed_reality_conversation("floor1npc0", "npc", "迟到者"), "ordinary NPC dialogue should start")
	var choice_id := str(game.get_typed_reality_choices()[0].get("id", ""))
	_assert_true(game.select_typed_reality_choice(choice_id), "response should enter per-character delivery")
	var first_result: Dictionary = game.advance_typed_reality_character()
	_assert_true(bool(first_result.get("advanced", false)), "one key should reveal one character")
	while game.conversation_phase == "typing":
		game.advance_typed_reality_character()
	_assert_eq(game.reality_dialogue_count, 1, "completing the spoken turn should count one dialogue")
	_assert_eq(game.owned_meme_frames, 0, "ordinary NPC dialogue must never grant a meme frame")
	_assert_true(game.conversation_reward.is_empty(), "ordinary NPC result should have no reward payload")


func test_first_crossing_sixty_triggers_flashback_without_ending_the_day() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	game.pollution = 59
	game.change_pollution(1)
	_assert_true(game.pollution_flashback_pending, "first 60% crossing should queue the flashback")
	_assert_true(game.pollution_flashback_seen, "first crossing should be remembered for the run")
	_assert_true(game.consume_pollution_flashback(), "pending flashback should be consumable once")
	_assert_eq(game.day, 1, "the flashback should not move the day on")


func test_flashback_trigger_is_once_per_run() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	game.pollution = 60
	_assert_true(game.check_pollution_flashback(59), "first threshold crossing should trigger")
	_assert_true(game.consume_pollution_flashback(), "first trigger should be consumable")
	game.pollution = 72
	_assert_true(not game.check_pollution_flashback(61), "later growth above 60 should not retrigger")


func _complete_note_tokens() -> Array:
	return [
		_note_token("subject-1", "我", "speaker.self", ["subject"], "本账号", "患者", "你"),
		_note_token("action-1", "看见", "perceive.see", ["action"], "捕获", "报告", "记得"),
		_note_token("object-1", "塔", "place.tower", ["object"], "信号塔", "病区", "出口"),
	]


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
