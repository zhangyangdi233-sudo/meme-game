extends SceneTree

const State = preload("res://scripts/meme_game_state.gd")
const Director = preload("res://scripts/progression/basement_loop_director.gd")
const APPS := ["social", "notebook", "babel"]
const OLD_ITEMS := ["chapter1_gate_item_01", "chapter1_gate_item_02", "chapter1_gate_item_03"]
var failures: Array[String] = []


func _init() -> void:
	_test_default_rewards_and_gate()
	_test_custom_rewards_and_legacy_migration()
	var state = State.new()
	_check(state.has_method("is_phone_app_unlocked") and state.has_method("can_use_app"), "state must expose phone and terminal app permissions")
	if state.has_method("is_phone_app_unlocked") and state.has_method("can_use_app"):
		_test_phone_entry_and_terminal_scope()
		_test_save_permissions_and_hidden_inventory_are_independent()
	_test_basement_practice_does_not_exhaust_actions()
	_test_basement_pollution_preserves_day_budget()
	_test_crossroads_practice_preserves_day_budget()
	_test_old_chapter_budget_migration()
	_check(state.has_method("has_current_chapter_submission"), "state must query a persisted submission for the current chapter task")
	if state.has_method("has_current_chapter_submission"):
		_test_submission_belongs_to_current_visit_and_survives_save()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("chapter app permission tests passed")
	quit(0 if failures.is_empty() else 1)


func _test_default_rewards_and_gate() -> void:
	var progress := _basement()
	_check(progress.get("unlocked_app_ids", []) == [], "the phone starts with no unlocked chapter apps")
	for index in range(5):
		var expected_reward: Array = [APPS[index / 2]] if index % 2 == 0 else []
		_check(Director.get_current_round(progress).get("reward_app_ids", []) == expected_reward, "round %d exposes its configured app reward" % (index + 1))
		progress = _event(progress, "entrance_threshold_crossed", {"round_token": progress.transition_serial})
		var payload := _help(progress)
		progress = _event(progress, "npc_help_completed", payload)
		var expected_apps: Array = APPS.slice(0, index / 2 + 1)
		_check(progress.get("unlocked_app_ids", []) == expected_apps, "rounds one, three and five unlock social, notebook and babel")
		_check(progress.get("gate_item_ids", []) == [], "new help completion must no longer issue old gate items")
		_check(not Director.dispatch(progress, "npc_help_completed", payload).accepted, "duplicate help cannot issue permissions twice")
		_check(not Director.dispatch(progress, "crossroads_gate_requested").accepted, "all five visits are required even when apps have already unlocked")
		var old_token: int = progress.transition_serial
		progress = _event(progress, "basement_tunnel_entered", {"round_token": old_token})
		progress = _event(progress, "basement_exit_requested", {"round_token": old_token})
		_check(not Director.dispatch(progress, "npc_help_completed", payload).accepted, "a stale help callback cannot unlock a new visit")
	_check(progress.phase == "crossroads", "five visits still lead to the crossroads")
	for app_id in APPS:
		var missing := progress.duplicate(true)
		var claimed: Array = missing.get("unlocked_app_ids", []).duplicate()
		claimed.erase(app_id)
		missing.unlocked_app_ids = claimed
		missing.gate_item_ids = OLD_ITEMS.duplicate()
		_check(not Director.dispatch(missing, "crossroads_gate_requested").accepted, "legacy gate items cannot replace a missing app permission")
	_check(Director.dispatch(progress, "crossroads_gate_requested").accepted, "all apps and all five tasks unlock the far gate")


func _test_custom_rewards_and_legacy_migration() -> void:
	var progress := Director.initial_progress()
	progress.reward_config = {"development_only": false, "task_app_unlocks": {"basement_help_02": ["babel", "social", "notebook", "social", "unknown"]}}
	progress = _event(progress, "opening_knock_completed", {"sequence_id": "chapter1_opening"})
	progress = _event(progress, "opening_door_opened")
	progress = _complete(progress)
	_check(progress.get("unlocked_app_ids", []) == [], "a custom mapping removes the default first-round reward")
	progress = _event(progress, "basement_tunnel_entered", {"round_token": progress.transition_serial})
	progress = _event(progress, "basement_exit_requested", {"round_token": progress.transition_serial})
	progress = _complete(progress)
	_check(progress.get("unlocked_app_ids", []) == APPS, "custom rewards support all known app IDs and deduplicate")
	_check(Director.normalize_progress(JSON.parse_string(JSON.stringify(progress))) == progress, "custom app mapping roundtrips through JSON")
	var forged := _basement()
	forged.unlocked_app_ids = APPS.duplicate()
	forged.gate_item_ids = OLD_ITEMS.duplicate()
	_check(Director.normalize_progress(forged).get("unlocked_app_ids", []) == [], "raw permissions and old items cannot grant unearned apps")
	var old := _crossroads()
	old.erase("unlocked_app_ids")
	old.reward_config = {"development_only": true, "task_rewards": {"basement_help_01": [OLD_ITEMS[0]], "basement_help_03": [OLD_ITEMS[1]], "basement_help_05": [OLD_ITEMS[2]]}}
	old.gate_item_ids = []
	var migrated := Director.normalize_progress(old)
	_check(migrated.get("unlocked_app_ids", []) == APPS, "old completed tasks migrate default app entitlements even without old items")
	_check(migrated.reward_config.get("task_app_unlocks", {}).get("basement_help_03", []) == ["notebook"], "legacy migration records the explicit default app mapping")
	old.completed_task_ids = ["basement_help_01", "basement_help_03", "basement_help_05"]
	old.gate_item_ids = OLD_ITEMS.duplicate()
	migrated = Director.normalize_progress(old)
	_check(migrated.completed_task_ids == ["basement_help_01"] and migrated.get("unlocked_app_ids", []) == ["social"], "legacy migration uses only the verified contiguous completion prefix")
	_check(not Director.dispatch(old, "crossroads_gate_requested").accepted, "missing old tasks cannot be hidden by legacy gate items")
	old.completed_task_ids = []
	_check(Director.normalize_progress(old).get("unlocked_app_ids", []) == [], "old item-only saves do not migrate app permission")
	var explicit_empty := _crossroads()
	explicit_empty.unlocked_app_ids = []
	_check(Director.normalize_progress(explicit_empty).get("unlocked_app_ids", []) == [], "new-format missing permissions are not silently reminted")


func _test_phone_entry_and_terminal_scope() -> void:
	var state = State.new()
	state.new_run()
	for app_id in APPS:
		_check(state.is_phone_app_unlocked(app_id) and bool(state.call("set_active_app", app_id)), "legacy runs keep every supported phone app")
	_check(not state.can_use_app("social", "terminal"), "legacy runs do not acquire a basement terminal context")
	state.start_chapter1()
	_check(state.active_app_window.is_empty(), "chapter startup clears a previously open locked app")
	for app_id in APPS:
		_check(not state.is_phone_app_unlocked(app_id), "new chapter phone apps start locked")
		_check(not bool(state.call("set_active_app", app_id)), "direct phone selection cannot bypass app locks")
		_check(not state.can_use_app(app_id, "terminal"), "opening has no terminal permissions")
	state.active_app = "notebook"
	state.set_view_state("npc_up")
	state.set_view_state("phone_down")
	_check(state.active_app_window.is_empty(), "raising the phone cannot automatically reopen a locked active app")
	state.chapter1_progress = _basement()
	for app_id in APPS:
		_check(state.can_use_app(app_id, "terminal"), "basement terminal grants temporary access to all three apps")
		_check(bool(state.call("set_active_app", app_id, "terminal")), "terminal selection is accepted inside the basement")
		_check(state.active_app_window.is_empty() and not state.is_phone_app_unlocked(app_id), "terminal selection must not open or unlock a phone window")
	_check(not state.can_use_app("unknown", "terminal") and not state.can_use_app("social", "unknown"), "unknown apps and contexts are denied")
	state.chapter1_progress = _complete(state.chapter1_progress)
	_check(bool(state.call("set_active_app", "social")) and state.active_app_window == "social", "earned permission enables direct phone selection")
	_check(not bool(state.call("set_active_app", "notebook")) and state.active_app_window == "social", "a denied selection preserves the permitted phone window")
	state.chapter1_progress = _crossroads()
	_check(not state.can_use_app("social", "terminal"), "terminal-only access ends on leaving the basement")
	state.chapter1_progress = _event(state.chapter1_progress, "crossroads_gate_requested")
	_check(not state.can_use_app("social", "terminal") and state.is_phone_app_unlocked("social"), "tower keeps earned phone access without terminal permission")


func _test_save_permissions_and_hidden_inventory_are_independent() -> void:
	var state = State.new()
	state.new_run()
	state.collected_prerequisite_item_ids.assign(state.get_prerequisite_item_ids())
	var hidden_items: Array = state.collected_prerequisite_item_ids.duplicate()
	state.start_chapter1()
	state.chapter1_progress = _complete(_basement())
	state.notebook_tokens = [{"id": "shared-word", "text": "门", "grammar_roles": ["subject"]}]
	state.collected_char_units = [{"unit": "门", "locale": "zh", "day": 1, "source_post_id": "floor_13"}]
	var saved: Dictionary = state.to_save_data()
	saved.state.active_app = "babel"
	saved.state.active_app_window = "babel"
	saved.state.chapter1_progress.unlocked_app_ids = ["social", "social", "babel", 5, "unknown"]
	var restored = State.new()
	_check(restored.load_save_data(saved), "permission state remains compatible with the existing save format")
	_check(restored.chapter1_progress.unlocked_app_ids == ["social"], "save normalization removes duplicate and unearned permissions")
	_check(restored.active_app_window.is_empty(), "loading clears a locked app window")
	_check(restored.collected_prerequisite_item_ids == hidden_items, "app rewards do not mutate old hidden-ending inventory")
	_check(restored.collected_char_units == state.collected_char_units and restored.notebook_tokens.size() == 1, "phone and terminal retain the one shared saved word inventory")
	_check(not restored.is_phone_app_unlocked("babel"), "old hidden items cannot unlock phone apps")
	state.active_app_window = "babel"
	_check(state.to_save_data().state.active_app_window == "", "serialization must not persist a locked phone window")


func _test_basement_practice_does_not_exhaust_actions() -> void:
	var state = State.new()
	state.new_run()
	state.start_chapter1()
	state.chapter1_progress = _basement()
	var initial_actions: int = state.actions_remaining
	var picked: Dictionary = state.pick_social_char("floor_13", "门", "zh")
	_check(picked.picked and not picked.action_spent, "basement pickup succeeds without charging the daily budget")
	for visit in range(5):
		for attempt in range(2):
			_check(state.free_sentence_place("门"), "shared collected words remain available for repeated practice")
			_check(state.submit_free_sentence().submitted, "practice submissions must remain possible through all five visits")
		_check(state.chapter1_progress.completed_task_ids.size() == visit, "practice action counts must not complete NPC help")
		_check(state.actions_remaining == initial_actions and not state.needs_day_settlement, "basement practice preserves the normal daily action budget")
		state.chapter1_progress = _complete(state.chapter1_progress)
		state.chapter1_progress = _event(state.chapter1_progress, "basement_tunnel_entered", {"round_token": state.chapter1_progress.transition_serial})
		state.chapter1_progress = _event(state.chapter1_progress, "basement_exit_requested", {"round_token": state.chapter1_progress.transition_serial})
	_check(state.published_memes.size() == 10 and state.collected_char_units.size() == 1, "practice keeps normal shared publication and collection records")
	_check(state.spend_action("crossroads-practice") and state.actions_remaining == initial_actions, "the tutorial budget stays free through the crossroads")
	state.chapter1_progress = _basement()
	state.actions_remaining = 0
	state.needs_day_settlement = false
	_check(state.can_spend_action(), "an exhausted legacy budget must not block basement practice")
	state.last_char_pick_day = 0
	_check(state.pick_social_char("floor_13", "开").picked, "first-pick early validation must use the basement action rule")
	_check(state.free_sentence_place("开") and state.submit_free_sentence().submitted, "submission early validation must use the basement action rule")
	_check(state.actions_remaining == 0 and not state.needs_day_settlement, "zero-budget practice must not schedule a day settlement")
	state.needs_day_settlement = true
	state.day_ended_reason = "prior-record"
	_check(state.spend_action("practice-retry") and state.needs_day_settlement and state.day_ended_reason == "prior-record", "practice does not erase an existing pending settlement record")
	state.chapter1_progress = _event(_crossroads(), "crossroads_gate_requested")
	_check(not state.can_spend_action() and not state.spend_action("tower-action"), "tower restores legacy exhausted-budget behavior")


func _test_basement_pollution_preserves_day_budget() -> void:
	var state = State.new()
	state.new_run()
	state.chapter1_progress = _basement()
	state.pollution = 59
	state.change_pollution(1)
	_check(state.pollution == 60, "basement practice retains the normal shared pollution metric")
	_check(state.actions_remaining == 5 and not state.needs_day_settlement and state.day_ended_reason.is_empty(), "crossing sixty during practice cannot consume the normal day budget or force settlement")
	_check(not state.pollution_flashback_pending and not state.pollution_flashback_seen, "basement practice cannot queue a delayed forced-day flashback or consume its ordinary-route trigger")
	state.actions_remaining = 2
	state.needs_day_settlement = true
	state.day_ended_reason = "prior-record"
	state.pollution = 59
	state.change_pollution(1)
	_check(state.actions_remaining == 2 and state.needs_day_settlement and state.day_ended_reason == "prior-record", "basement pollution preserves an already pending day record")
	state.chapter1_progress = _event(_crossroads(), "crossroads_gate_requested")
	state.needs_day_settlement = false
	state.pollution = 59
	state.change_pollution(1)
	_check(state.actions_remaining == 0 and state.needs_day_settlement and state.day_ended_reason == "pollution-flashback", "the same crossing in the tower retains ordinary forced settlement")
	_check(state.pollution_flashback_pending and state.pollution_flashback_seen, "tower pollution still queues its existing once-per-run flashback")


func _test_crossroads_practice_preserves_day_budget() -> void:
	var state = State.new()
	state.new_run()
	state.chapter1_progress = _crossroads()
	var original_day: int = state.day
	_check(state.pick_social_char("floor_13", "门").picked, "crossroads uses the same shared word inventory")
	for retry in range(25):
		_check(state.free_sentence_place("门") and state.submit_free_sentence().submitted, "crossroads repeat %d remains available before entering the tower" % (retry + 1))
	_check(state.actions_remaining == 5 and state.day == original_day and not state.needs_day_settlement and not state.pollution_flashback_pending, "crossroads repeated phone practice preserves day and budget without queuing a forced settlement")
	_check(state.pollution >= State.POLLUTION_FLASHBACK_THRESHOLD, "crossroads practice test genuinely passes the ordinary pollution threshold")
	_check(not state.can_use_app("social", "terminal") and not state.has_current_chapter_submission(), "extending the free budget does not extend terminal scope or NPC submission proof outside basement")
	var record: Dictionary = state.sentence_records.back()
	_check(not record.has("chapter_task_id") and not record.has("chapter_round_token"), "crossroads phone submissions do not receive basement task provenance")
	_check(state.notify_chapter1("crossroads_gate_requested").accepted, "earned permissions still open the tower after repeated crossroads practice")
	_check(state.day == original_day and state.actions_remaining == 5, "opening the tower gate never advances the day or alters the preserved budget")
	_check(state.spend_action("tower-action") and state.actions_remaining == 4, "ordinary action charging resumes only inside the tower")


func _test_old_chapter_budget_migration() -> void:
	for phase in ["basement", "crossroads"]:
		var source = State.new()
		source.new_run()
		source.chapter1_progress = _complete(_basement()) if phase == "basement" else _crossroads()
		source.day = 4
		source.pollution = 77
		source.actions_remaining = 0
		source.needs_day_settlement = true
		source.day_ended_reason = "pollution-flashback"
		source.pollution_flashback_pending = true
		source.pollution_flashback_seen = true
		var old_save: Dictionary = JSON.parse_string(JSON.stringify(source.to_save_data()))
		var raw: Dictionary = old_save.state.chapter1_progress
		raw.erase("unlocked_app_ids")
		raw.reward_config.erase("task_app_unlocks")
		var expected_progress := Director.normalize_progress(raw)
		var restored = State.new()
		_check(restored.load_save_data(old_save), "old %s chapter save loads through its ordinary serialized envelope" % phase)
		_check(restored.day == 4 and restored.tower_floor == source.tower_floor and restored.actions_remaining == 5, "old exhausted %s chapter recovers its normal budget without advancing day or tower" % phase)
		_check(not restored.needs_day_settlement and restored.day_ended_reason.is_empty() and not restored.pollution_flashback_pending, "old %s tutorial pending settlement and flashback are cleared by compatibility migration" % phase)
		_check(restored.pollution == 77 and restored.pollution_flashback_seen and restored.chapter1_progress == expected_progress, "budget migration preserves shared pollution, seen flashback and exactly the earned normalized chapter rewards")
		var again = State.new()
		again.load_save_data(restored.to_save_data())
		_check(again.actions_remaining == 5 and again.day == 4 and again.chapter1_progress == restored.chapter1_progress, "budget compatibility migration is stable after a new-schema save and reload")
		var new_schema = State.new()
		new_schema.load_save_data(source.to_save_data())
		_check(new_schema.actions_remaining == 0 and new_schema.needs_day_settlement and new_schema.pollution_flashback_pending, "explicit exhausted new-schema state is preserved rather than silently refilled")
		for changed_field in ["unlocked_app_ids", "task_app_unlocks", "phase", "needs_day_settlement", "actions_remaining"]:
			var excluded := old_save.duplicate(true)
			match changed_field:
				"unlocked_app_ids":
					excluded.state.chapter1_progress.unlocked_app_ids = []
				"task_app_unlocks":
					excluded.state.chapter1_progress.reward_config.task_app_unlocks = Director.DEFAULT_TASK_APP_UNLOCKS.duplicate(true)
				"phase":
					excluded.state.chapter1_progress.phase = "opening"
				"needs_day_settlement":
					excluded.state.needs_day_settlement = false
				"actions_remaining":
					excluded.state.actions_remaining = 2
			var untouched = State.new()
			untouched.load_save_data(excluded)
			_check(untouched.actions_remaining == excluded.state.actions_remaining and untouched.needs_day_settlement == excluded.state.needs_day_settlement and untouched.pollution_flashback_pending, "budget migration excludes saves outside its explicit boundary: %s" % changed_field)
		old_save.state.max_actions_per_day = 7
		var custom_budget = State.new()
		custom_budget.load_save_data(old_save)
		_check(custom_budget.actions_remaining == 7, "old chapter migration restores the saved normal daily maximum rather than a hard-coded five")
	var ordinary = State.new()
	ordinary.new_run()
	ordinary.actions_remaining = 0
	ordinary.needs_day_settlement = true
	ordinary.day_ended_reason = "free-sentence-publish"
	var legacy = State.new()
	legacy.load_save_data(ordinary.to_save_data())
	_check(legacy.actions_remaining == 0 and legacy.needs_day_settlement and legacy.day_ended_reason == "free-sentence-publish", "ordinary legacy saves retain their real day settlement unchanged")
	ordinary.chapter1_progress = _event(_crossroads(), "crossroads_gate_requested")
	ordinary.tower_floor = 2
	var old_tower := ordinary.to_save_data()
	old_tower.state.chapter1_progress.erase("unlocked_app_ids")
	old_tower.state.chapter1_progress.reward_config.erase("task_app_unlocks")
	legacy.load_save_data(old_tower)
	_check(legacy.actions_remaining == 0 and legacy.needs_day_settlement and legacy.tower_floor == 2 and legacy.chapter1_progress.phase == "tower", "old-schema chapter saves already in the tower retain ordinary exhausted-budget behavior")


func _test_submission_belongs_to_current_visit_and_survives_save() -> void:
	var state = State.new()
	state.new_run()
	state.start_chapter1()
	state.chapter1_progress = _basement()
	_check(not bool(state.call("has_current_chapter_submission")), "a new visit has no completed expression to deliver")
	_check(not state.submit_free_sentence().submitted, "an empty expression is not a successful submission")
	state.pick_social_char("floor_13", "门")
	state.free_sentence_place("门")
	_check(not bool(state.call("has_current_chapter_submission")), "placing a word alone does not count as submitting")
	_check(state.submit_free_sentence().submitted, "a collected nonempty expression can be submitted")
	_check(bool(state.call("has_current_chapter_submission")), "the current valid submission can be handed to its NPC")
	var record: Dictionary = state.sentence_records.back()
	_check(record.get("chapter_task_id") == "basement_help_01" and record.get("chapter_round_token") == 1, "the shared submission record captures the task and original visit token")
	var restored = State.new()
	_check(restored.load_save_data(JSON.parse_string(JSON.stringify(state.to_save_data()))), "submission state roundtrips through an actual JSON save")
	_check(bool(restored.call("has_current_chapter_submission")), "continuing a save retains the current expression for delivery")
	state.chapter1_progress = _complete(state.chapter1_progress)
	state.chapter1_progress = _event(state.chapter1_progress, "basement_tunnel_entered", {"round_token": state.chapter1_progress.transition_serial})
	state.chapter1_progress = _event(state.chapter1_progress, "basement_exit_requested", {"round_token": state.chapter1_progress.transition_serial})
	_check(not bool(state.call("has_current_chapter_submission")), "the previous visit's submission cannot satisfy the new NPC")
	for invalid in [
		{"kind": "free_sentence", "text": "门", "units": ["门"], "chapter_task_id": "basement_help_02", "chapter_round_token": "2"},
		{"kind": "free_sentence", "text": " ", "units": ["门"], "chapter_task_id": "basement_help_02", "chapter_round_token": 2},
		{"kind": "free_sentence", "text": "门", "units": [], "chapter_task_id": "basement_help_02", "chapter_round_token": 2},
		{"kind": "draft", "text": "门", "units": ["门"], "chapter_task_id": "basement_help_02", "chapter_round_token": 2},
	]:
		state.sentence_records.append(invalid)
		_check(not bool(state.call("has_current_chapter_submission")), "a malformed or unsubmitted record cannot satisfy the current task")
	state.free_sentence_place("门")
	_check(state.submit_free_sentence().submitted and bool(state.call("has_current_chapter_submission")), "the same shared word can form a new valid submission in the next visit")
	state.chapter1_progress = {}
	state.free_sentence_place("门")
	state.submit_free_sentence()
	var legacy_record: Dictionary = state.sentence_records.back()
	_check(not legacy_record.has("chapter_task_id") and not legacy_record.has("chapter_round_token"), "ordinary submissions do not acquire chapter task metadata")
	_check(not bool(state.call("has_current_chapter_submission")), "legacy routes cannot report a current chapter submission")


func _basement() -> Dictionary:
	var progress := Director.initial_progress()
	progress = _event(progress, "opening_knock_completed", {"sequence_id": "chapter1_opening"})
	return _event(progress, "opening_door_opened")


func _crossroads() -> Dictionary:
	var progress := _basement()
	for index in range(5):
		progress = _complete(progress)
		progress = _event(progress, "basement_tunnel_entered", {"round_token": progress.transition_serial})
		progress = _event(progress, "basement_exit_requested", {"round_token": progress.transition_serial})
	return progress


func _complete(progress: Dictionary) -> Dictionary:
	progress = _event(progress, "entrance_threshold_crossed", {"round_token": progress.transition_serial})
	return _event(progress, "npc_help_completed", _help(progress))


func _help(progress: Dictionary) -> Dictionary:
	var visit: int = progress.round_index + 1
	return {"round_token": progress.transition_serial, "task_id": "basement_help_%02d" % visit, "npc_id": "basement_npc_%02d" % visit}


func _event(progress: Dictionary, event_id: String, payload: Dictionary = {}) -> Dictionary:
	var result := Director.dispatch(progress, event_id, payload)
	_check(result.accepted, "expected valid event: %s" % event_id)
	return result.progress


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
