extends SceneTree

const LanguageBridgeScript = preload("res://scripts/narrative/language_bridge.gd")

var _failures: Array[String] = []
var _state_script: Script = null
var _engagement_signal_count := 0
var _last_engagement_snapshot: Dictionary = {}
var _phone_shell_signal_count := 0
var _last_phone_shell_snapshot: Dictionary = {}


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
	test_phone_shell_snapshot_and_signal()
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


func test_phone_shell_snapshot_and_signal() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()
	_phone_shell_signal_count = 0
	_last_phone_shell_snapshot = {}
	game.phone_shell_changed.connect(_capture_phone_shell)

	var initial: Dictionary = game.get_phone_shell_snapshot()
	_assert_eq(str(initial.get("view_state", "")), "phone_down", "new run should start phone-down")
	_assert_eq(str(initial.get("active_app", "")), "social", "new run should default to social app")
	_assert_eq(str(initial.get("active_app_window", "")), "social", "phone-down should expose default app window")
	_assert_true(bool(initial.get("phone_visible", false)), "phone should be visible at start")
	_assert_true(bool(initial.get("phone_open", false)), "phone should be open at start")

	game.set_active_app("babel")
	_assert_eq(_phone_shell_signal_count, 1, "active app toggle should emit once")
	_assert_eq(str(_last_phone_shell_snapshot.get("active_app", "")), "babel", "signal should carry active app")
	_assert_eq(str(_last_phone_shell_snapshot.get("active_app_window", "")), "babel", "phone-down should sync foreground window")
	var app_change: Dictionary = _last_phone_shell_snapshot.get("change", {})
	_assert_eq(str(app_change.get("kind", "")), "active_app", "change kind should be active_app")
	_assert_eq(str(app_change.get("target_id", "")), "babel", "change target should be app id")
	_assert_true(bool(app_change.get("active", false)), "opening an app should be active")

	game.close_app_window("babel", [] as Array[String])
	_assert_eq(_phone_shell_signal_count, 2, "closing foreground app should emit")
	_assert_true(str(_last_phone_shell_snapshot.get("active_app_window", "")).is_empty(), "close should clear foreground window")
	var close_change: Dictionary = _last_phone_shell_snapshot.get("change", {})
	_assert_eq(str(close_change.get("kind", "")), "close_app", "change kind should be close_app")
	_assert_true(not bool(close_change.get("active", true)), "close should mark inactive")

	game.set_active_app("social")
	game.set_active_app("notebook")
	game.close_app_window("notebook", ["social"] as Array[String])
	_assert_eq(str(_last_phone_shell_snapshot.get("active_app", "")), "social", "close should fall back to remaining open app")
	_assert_eq(str(_last_phone_shell_snapshot.get("active_app_window", "")), "social", "foreground should follow remaining open app")

	_assert_true(game.set_view_state("npc_up"), "npc_up should be accepted")
	_assert_eq(_phone_shell_signal_count, 6, "view_state toggle should emit")
	_assert_eq(str(_last_phone_shell_snapshot.get("view_state", "")), "npc_up", "signal should carry npc_up")
	_assert_true(str(_last_phone_shell_snapshot.get("active_app_window", "")).is_empty(), "npc_up should hide app window")
	_assert_true(not bool(_last_phone_shell_snapshot.get("phone_visible", true)), "npc_up should hide phone chrome")
	var view_change: Dictionary = _last_phone_shell_snapshot.get("change", {})
	_assert_eq(str(view_change.get("kind", "")), "view_state", "change kind should be view_state")
	_assert_true(not bool(view_change.get("active", true)), "npc_up should not be phone-down active")

	_assert_true(game.set_view_state("phone_down"), "phone_down should restore")
	_assert_eq(str(_last_phone_shell_snapshot.get("view_state", "")), "phone_down", "signal should restore phone_down")
	_assert_eq(str(_last_phone_shell_snapshot.get("active_app_window", "")), "social", "phone_down should restore foreground from active_app")

	var snapshot: Dictionary = game.get_phone_shell_snapshot()
	_assert_eq(str(snapshot.get("view_state", "")), "phone_down", "snapshot should reflect phone_down")
	snapshot["view_state"] = "npc_up"
	_assert_eq(str(game.view_state), "phone_down", "snapshot must be a copy, not live state")

	game.set_phone_open(false)
	_assert_eq(_phone_shell_signal_count, 8, "phone close should emit")
	var phone_change: Dictionary = _last_phone_shell_snapshot.get("change", {})
	_assert_eq(str(phone_change.get("kind", "")), "phone_open", "change kind should be phone_open")
	_assert_true(not bool(_last_phone_shell_snapshot.get("phone_open", true)), "phone_open snapshot should reflect closed")
	_assert_true(str(_last_phone_shell_snapshot.get("active_app_window", "")).is_empty(), "closing phone should clear foreground window")


func _capture_phone_shell(snapshot: Dictionary) -> void:
	_phone_shell_signal_count += 1
	_last_phone_shell_snapshot = snapshot


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
