extends SceneTree

const DIRECTOR_PATH := "res://scripts/progression/basement_loop_director.gd"
const StateScript = preload("res://scripts/meme_game_state.gd")
const TASK_IDS := ["basement_help_01", "basement_help_02", "basement_help_03", "basement_help_04", "basement_help_05"]
const ITEM_IDS := ["chapter1_gate_item_01", "chapter1_gate_item_02", "chapter1_gate_item_03"]
const APP_IDS := ["social", "notebook"]
var _failures: Array[String] = []
var _director: Script


func _init() -> void:
	if FileAccess.file_exists(DIRECTOR_PATH):
		_director = load(DIRECTOR_PATH) as Script
	_assert_true(_director != null, "chapter director should provide event-driven chapter progress")
	if _director != null:
		test_opening_requires_knock_then_opened_event()
		test_legacy_narration_progress_migrates_only_after_opening()
		test_five_visits_require_sealing_and_current_help()
		test_gate_requires_all_tasks_and_exact_apps()
		test_rewards_are_configurable_and_idempotent()
		test_corrupted_progress_never_grants_prerequisites()
		test_every_stage_survives_json_and_state_save()
		test_retired_tunnel_save_normalizes_to_ordinary_door()
	test_legacy_state_is_opt_in_and_independent()
	if _failures.is_empty():
		print("basement loop director tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_opening_requires_knock_then_opened_event() -> void:
	var progress: Dictionary = _director.initial_progress()
	_assert_eq(progress.get("phase"), "opening", "a new chapter should begin in the opening")
	_assert_eq(progress.get("round_index"), 0, "rounds should be zero based")
	_assert_eq(progress.get("transition_serial"), 0, "opening has no basement visit token")
	_assert_eq(progress.get("opening_knock_completed"), false, "a new opening must wait for its knock")
	_assert_rejected(progress, "opening_door_opened", {}, "opening cannot advance before its knock finishes")
	_assert_rejected(progress, "opening_door_crossed", {}, "walking through the doorway cannot advance the opening")
	_assert_rejected(progress, "opening_knock_completed", {}, "knock completion requires the opening sequence ID")
	_assert_rejected(progress, "opening_knock_completed", {"sequence_id": "unrelated_sequence"}, "another sequence cannot complete the opening knock")
	_assert_rejected(progress, "time_elapsed", {"seconds": 999}, "elapsed time alone cannot certify a completed knock")
	_assert_rejected(progress, "player_near_door", {}, "proximity cannot certify a completed knock")
	_assert_rejected(progress, "narration_completed", {"sequence_id": "unrelated_sequence"}, "unrelated narration remains rejected")
	progress = _accept(progress, "narration_completed", {"sequence_id": "chapter1_opening"}, "narration_completed")
	_assert_rejected(progress, "narration_completed", {"sequence_id": "chapter1_opening"}, "narration callbacks are idempotent")
	_assert_eq(progress.get("opening_knock_completed"), false, "narration does not finish the knock")
	_assert_rejected(progress, "opening_door_opened", {}, "narration cannot bypass the knock")
	_assert_rejected(progress, "opening_door_crossed", {}, "the old crossing event cannot bypass the new flow")
	progress = _accept(progress, "opening_knock_completed", {"sequence_id": "chapter1_opening"}, "opening_knock_completed")
	_assert_eq(progress.get("phase"), "opening", "a completed knock still waits for F and the opening animation")
	_assert_rejected(progress, "opening_knock_completed", {"sequence_id": "chapter1_opening"}, "knock completion is idempotent")
	_assert_rejected(progress, "opening_door_crossed", {}, "crossing is no longer the basement transition even after the knock")
	progress = _accept(progress, "opening_door_opened", {}, "enter_basement")
	_assert_eq(progress.get("phase"), "basement", "the completed door animation enters the first basement")
	_assert_eq(progress.get("transition_serial"), 1, "entering the basement creates its first token")
	_assert_rejected(progress, "opening_door_opened", {}, "duplicate opened callbacks cannot restart a visit")
	_assert_rejected(progress, "opening_knock_completed", {"sequence_id": "chapter1_opening"}, "knock callbacks cannot fire outside the opening")
	_assert_rejected(progress, "narration_completed", {"sequence_id": "chapter1_opening"}, "narration cannot fire outside the opening")
	var silent: Dictionary = _director.initial_progress()
	silent = _accept(silent, "opening_knock_completed", {"sequence_id": "chapter1_opening"}, "opening_knock_completed")
	silent = _accept(silent, "opening_door_opened", {}, "enter_basement")
	_assert_eq(silent.get("narrator_completed"), false, "entering the basement never fabricates narration completion")
	_assert_eq(silent.get("phase"), "basement", "the knock and door flow is independent of narration")


func test_legacy_narration_progress_migrates_only_after_opening() -> void:
	var legacy := {"phase": "basement", "round_index": 0, "narrator_completed": true, "entrance_locked": false}
	var normalized: Dictionary = _director.normalize_progress(legacy)
	_assert_eq(normalized.get("phase"), "basement", "an older basement save retains its reached stage")
	_assert_eq(normalized.get("opening_knock_completed"), true, "only a missing knock field in a completed legacy opening is migrated")
	_assert_eq(_director.normalize_progress(normalized), normalized, "legacy migration is stable after its first load")
	legacy.phase = "opening"
	normalized = _director.normalize_progress(legacy)
	_assert_eq(normalized.get("opening_knock_completed"), false, "old opening saves must still hear the knock")
	_assert_rejected(normalized, "opening_door_opened", {}, "old opening narration cannot unlock the door")
	legacy.phase = "basement"
	for explicit_value in [false, "true", 1, {"invalid": true}]:
		legacy.opening_knock_completed = explicit_value
		normalized = _director.normalize_progress(legacy)
		_assert_eq(normalized.get("phase"), "opening", "an explicit invalid or false knock field cannot fall back to narration")
		_assert_eq(normalized.get("opening_knock_completed"), false, "knock state accepts only boolean true")
	legacy.erase("opening_knock_completed")
	for invalid_narration in [false, "true", 1]:
		legacy.narrator_completed = invalid_narration
		normalized = _director.normalize_progress(legacy)
		_assert_eq(normalized.get("phase"), "opening", "legacy migration requires strictly boolean completed narration")


func test_five_visits_require_sealing_and_current_help() -> void:
	var progress := _basement_progress()
	for round_index in range(5):
		_assert_eq(progress.get("round_index"), round_index, "each accepted exit advances exactly one round")
		_assert_eq(progress.get("entrance_locked"), false, "a fresh visit leaves the entrance open until crossed")
		var token: int = progress.transition_serial
		var payload := _help_payload(progress)
		var current: Dictionary = _director.get_current_round(progress)
		_assert_eq(current.get("task_id"), TASK_IDS[round_index], "the current round exposes its stable task ID")
		_assert_eq(current.get("npc_id"), payload.npc_id, "the current round exposes its stable NPC ID")
		_assert_rejected(progress, "npc_help_completed", payload, "help cannot finish before the entrance seals")
		_assert_rejected(progress, "entrance_threshold_crossed", {}, "a threshold callback requires its visit token")
		_assert_rejected(progress, "entrance_threshold_crossed", {"round_token": token - 1}, "stale thresholds cannot seal a new visit")
		progress = _accept(progress, "entrance_threshold_crossed", {"round_token": token}, "entrance_locked")
		_assert_rejected(progress, "entrance_threshold_crossed", {"round_token": token}, "duplicate thresholds cannot transition twice")
		_assert_rejected(progress, "basement_exit_requested", {"round_token": token}, "the exit requires current NPC help")
		var wrong_task := payload.duplicate()
		wrong_task.task_id = TASK_IDS[(round_index + 1) % 5]
		_assert_rejected(progress, "npc_help_completed", wrong_task, "the wrong round's task cannot complete")
		var wrong_npc := payload.duplicate()
		wrong_npc.npc_id = "unrelated_npc"
		_assert_rejected(progress, "npc_help_completed", wrong_npc, "the wrong NPC cannot complete help")
		var stale_help := payload.duplicate()
		stale_help.round_token = token - 1
		_assert_rejected(progress, "npc_help_completed", stale_help, "stale help cannot complete another visit")
		progress = _accept(progress, "npc_help_completed", payload, "help_completed")
		_assert_rejected(progress, "npc_help_completed", payload, "duplicate help cannot duplicate completion or rewards")
		_assert_rejected(progress, "basement_exit_requested", {"round_token": token - 1}, "stale exits cannot advance")
		progress = _accept(progress, "basement_exit_requested", {"round_token": token}, "basement_loop" if round_index < 4 else "enter_crossroads")
		_assert_rejected(progress, "basement_exit_requested", {"round_token": token}, "duplicate exits cannot skip a round")
	_assert_eq(progress.get("phase"), "crossroads", "the fifth successful exit reaches the crossroads")
	_assert_eq(progress.get("round_index"), 4, "the fifth round remains the final round index")
	_assert_eq(progress.get("completed_task_ids"), TASK_IDS, "all five distinct helpers must be recorded")
	_assert_eq(progress.get("unlocked_app_ids"), APP_IDS, "development app permissions arrive on rounds one and three")
	_assert_eq(progress.get("gate_item_ids"), [], "new rewards no longer grant old gate items")
	_assert_eq(progress.get("transition_serial"), 6, "each scene transition invalidates old callbacks")
	_assert_eq(_director.get_current_round(progress), {}, "there is no active NPC outside the basement")


func test_gate_requires_all_tasks_and_exact_apps() -> void:
	var progress := _crossroads_progress()
	_assert_rejected(_basement_progress(), "crossroads_gate_requested", {}, "the gate cannot be used out of stage")
	for missing_app in APP_IDS:
		var incomplete := progress.duplicate(true)
		incomplete.unlocked_app_ids.erase(missing_app)
		incomplete.unlocked_app_ids.append("unrelated_app")
		incomplete.gate_item_ids = ITEM_IDS.duplicate()
		_assert_rejected(incomplete, "crossroads_gate_requested", {}, "old items or arbitrary app IDs cannot substitute for the two app permissions")
	var incomplete_tasks := progress.duplicate(true)
	incomplete_tasks.completed_task_ids.erase(TASK_IDS[2])
	_assert_rejected(incomplete_tasks, "crossroads_gate_requested", {}, "the gate also requires every helper")
	progress = _accept(progress, "crossroads_gate_requested", {}, "enter_tower")
	_assert_eq(progress.get("phase"), "tower", "all exact prerequisites unlock the tower")
	_assert_rejected(progress, "crossroads_gate_requested", {}, "the gate transition is idempotent")


func test_rewards_are_configurable_and_idempotent() -> void:
	var progress: Dictionary = _director.initial_progress()
	_assert_true(bool(progress.get("reward_config", {}).get("development_only", false)), "default reward mapping must be explicitly development-only")
	progress.reward_config = {"development_only": false, "task_app_unlocks": {"basement_help_02": APP_IDS.duplicate()}}
	progress = _accept(progress, "opening_knock_completed", {"sequence_id": "chapter1_opening"}, "opening_knock_completed")
	progress = _accept(progress, "opening_door_opened", {}, "enter_basement")
	progress = _complete_current_round(progress)
	_assert_eq(progress.unlocked_app_ids, [], "a configured unrewarded task grants nothing")
	progress = _accept(progress, "basement_exit_requested", {"round_token": progress.transition_serial}, "basement_loop")
	progress = _complete_current_round(progress)
	_assert_eq(progress.unlocked_app_ids, APP_IDS, "a configured task can award the specified app permissions")
	_assert_rejected(progress, "npc_help_completed", _help_payload(progress), "configured rewards are still granted only once")
	_assert_eq(_director.normalize_progress(JSON.parse_string(JSON.stringify(progress))), progress, "custom reward configuration survives JSON")


func test_corrupted_progress_never_grants_prerequisites() -> void:
	var corrupted := {"phase": "tower", "round_index": 400, "narrator_completed": "true", "entrance_locked": true, "completed_task_ids": TASK_IDS, "gate_item_ids": ITEM_IDS, "transition_serial": "7"}
	var normalized: Dictionary = _director.normalize_progress(corrupted)
	_assert_eq(normalized.phase, "opening", "a non-boolean legacy narrator flag cannot bypass the knock")
	_assert_eq(normalized.completed_task_ids, [], "normalization cannot infer completed tasks from a claimed phase")
	_assert_eq(normalized.gate_item_ids, [], "normalization cannot infer earned rewards from a claimed phase")
	var progress := _crossroads_progress()
	progress.phase = "tower"
	progress.unlocked_app_ids.erase(APP_IDS[1])
	normalized = _director.normalize_progress(progress)
	_assert_eq(normalized.phase, "crossroads", "a saved tower phase without every app permission falls back to the gate")
	_assert_true(APP_IDS[1] not in normalized.unlocked_app_ids, "normalization must not regenerate a missing new-format app permission")
	progress = _crossroads_progress()
	progress.completed_task_ids = [TASK_IDS[0], TASK_IDS[0], 7, TASK_IDS[2], "unknown_task"]
	progress.unlocked_app_ids = [APP_IDS[0], APP_IDS[0], APP_IDS[1], "unknown_app", 1]
	normalized = _director.normalize_progress(progress)
	_assert_eq(normalized.phase, "basement", "a broken completion prefix cannot remain at crossroads")
	_assert_eq(normalized.round_index, 1, "the first unfinished round must still be completed")
	_assert_eq(normalized.completed_task_ids, [TASK_IDS[0]], "unknown, duplicate and out-of-order completions are removed")
	_assert_eq(normalized.unlocked_app_ids, [APP_IDS[0]], "only app permissions supported by retained completion remain")
	for key in ["completed_task_ids", "unlocked_app_ids", "gate_item_ids", "reward_config", "round_index", "transition_serial", "phase", "entrance_locked", "narrator_completed", "opening_knock_completed"]:
		var invalid: Dictionary = _director.initial_progress()
		invalid[key] = {"not": "the expected type"}
		var safe: Dictionary = _director.normalize_progress(invalid)
		_assert_eq(safe.phase, "opening", "wrong field types should be normalized safely: %s" % key)
		_assert_eq(safe.completed_task_ids, [], "bad types cannot fabricate completion")
		_assert_eq(_director.normalize_progress(safe), safe, "normalization is stable for bad types")
	var unlocked := _complete_current_round(_basement_progress())
	unlocked.entrance_locked = false
	normalized = _director.normalize_progress(unlocked)
	_assert_eq(normalized.completed_task_ids, [], "help claimed before a sealed entrance is not retained")
	_assert_eq(normalized.gate_item_ids, [], "discarding unearned help also discards its reward")
	_assert_eq(normalized.unlocked_app_ids, [], "discarding unearned help also discards its app permission")


func test_every_stage_survives_json_and_state_save() -> void:
	var state = StateScript.new()
	if not state.has_method("start_chapter1"):
		_assert_true(false, "game state should expose chapter startup and save integration")
		return
	state.new_run()
	state.start_chapter1()
	_check_roundtrip(state)
	state.notify_chapter1("narration_completed", {"sequence_id": "chapter1_opening"})
	_check_roundtrip(state)
	_assert_eq(state.chapter1_progress.get("opening_knock_completed"), false, "saving narration retains the pending knock")
	state.notify_chapter1("opening_knock_completed", {"sequence_id": "chapter1_opening"})
	_check_roundtrip(state)
	state.notify_chapter1("opening_door_opened")
	_check_roundtrip(state)
	for _round in range(5):
		state.notify_chapter1("entrance_threshold_crossed", {"round_token": state.chapter1_progress.transition_serial})
		_check_roundtrip(state)
		state.notify_chapter1("npc_help_completed", _help_payload(state.chapter1_progress))
		_check_roundtrip(state)
		state.notify_chapter1("basement_exit_requested", {"round_token": state.chapter1_progress.transition_serial})
		_check_roundtrip(state)
	state.notify_chapter1("crossroads_gate_requested")
	_check_roundtrip(state)
	_assert_eq(state.chapter1_progress.phase, "tower", "restorable event flow reaches the tower")
	_assert_eq(state.collected_prerequisite_item_ids, [], "chapter rewards never change old tower prerequisite inventory")
	var saved: Dictionary = state.to_save_data()
	saved.state.chapter1_progress = "invalid chapter dictionary"
	var restored = StateScript.new()
	_assert_true(restored.load_save_data(saved), "a malformed chapter field should not break an otherwise valid legacy save")
	_assert_eq(restored.chapter1_progress, {}, "a non-dictionary chapter field becomes inactive legacy progress")
	state.chapter1_progress.unlocked_app_ids.clear()
	var normalized_save: Dictionary = state.to_save_data()
	_assert_eq(normalized_save.state.chapter1_progress.phase, "crossroads", "serialization also validates chapter state before persisting it")


func test_retired_tunnel_save_normalizes_to_ordinary_door() -> void:
	var old_tunnel := _complete_current_round(_basement_progress())
	old_tunnel.exit_tunnel_entered = true
	var normalized: Dictionary = _director.normalize_progress(old_tunnel)
	_assert_eq(normalized.exit_tunnel_entered, false, "old tunnel flag cannot restore a removed corridor")
	_assert_eq(normalized.completed_task_ids, old_tunnel.completed_task_ids, "retiring tunnel checkpoint preserves completed help")
	_assert_eq(normalized.transition_serial, old_tunnel.transition_serial, "migration never skips a visit")
	var next := _accept(normalized, "basement_exit_requested", {"round_token": normalized.transition_serial}, "basement_loop")
	_assert_eq(next.round_index, 1, "ordinary door advances directly without a tunnel checkpoint")


func test_legacy_state_is_opt_in_and_independent() -> void:
	var state = StateScript.new()
	state.new_run()
	_assert_true(state.has_method("start_chapter1") and state.has_method("notify_chapter1"), "game state should expose the opt-in chapter API")
	if not state.has_method("start_chapter1") or not state.has_method("notify_chapter1"):
		return
	_assert_eq(state.chapter1_progress, {}, "new_run preserves legacy behavior until chapter startup is requested")
	var inactive: Dictionary = state.notify_chapter1("narration_completed", {"sequence_id": "chapter1_opening"})
	_assert_true(not inactive.accepted, "chapter events cannot activate a legacy run")
	_assert_eq(state.chapter1_progress, {}, "rejected legacy chapter notifications preserve the inactive marker")
	for version in [1, 2, 3, 4, 5]:
		var save: Dictionary = state.to_save_data()
		save.version = version
		save.state.erase("chapter1_progress")
		var restored = StateScript.new()
		_assert_true(restored.load_save_data(save), "supported legacy saves remain loadable")
		_assert_eq(restored.chapter1_progress, {}, "missing chapter field remains legacy for save version %d" % version)
		_assert_eq(restored.to_save_data().version, 5, "chapter support does not change the existing save format version")
	state.collected_prerequisite_item_ids.assign(ITEM_IDS)
	state.start_chapter1()
	_assert_eq(state.chapter1_progress.gate_item_ids, [], "old inventory cannot satisfy new chapter prerequisites")
	_assert_eq(state.chapter1_progress.unlocked_app_ids, [], "old inventory cannot unlock new chapter apps")
	var before: Dictionary = state.chapter1_progress.duplicate(true)
	var result: Dictionary = state.notify_chapter1("crossroads_gate_requested")
	_assert_true(not result.accepted, "legacy inventory cannot bypass chapter progression")
	_assert_eq(state.chapter1_progress, before, "a rejected notification preserves valid chapter progress")
	result.progress.phase = "tower"
	_assert_eq(state.chapter1_progress, before, "returned progress must not alias the state's saved dictionary")
	state.new_run()
	_assert_eq(state.chapter1_progress, {}, "new_run clears previously active chapter progress")


func _check_roundtrip(state: RefCounted) -> void:
	var progress: Dictionary = state.chapter1_progress
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(progress))
	_assert_eq(_director.normalize_progress(decoded), progress, "every chapter stage should roundtrip through JSON")
	var saved: Dictionary = state.to_save_data()
	var restored = StateScript.new()
	_assert_true(restored.load_save_data(saved), "every chapter stage should load through game state")
	_assert_eq(restored.chapter1_progress, progress, "game save/load preserves every chapter stage")
	_assert_eq(restored.collected_prerequisite_item_ids, state.collected_prerequisite_item_ids, "chapter serialization preserves the separate old inventory")
	saved.state.chapter1_progress.phase = "modified_after_save"
	_assert_eq(state.chapter1_progress, progress, "saved progress does not alias live progress")


func _basement_progress() -> Dictionary:
	var progress: Dictionary = _director.initial_progress()
	progress = _accept(progress, "opening_knock_completed", {"sequence_id": "chapter1_opening"}, "opening_knock_completed")
	return _accept(progress, "opening_door_opened", {}, "enter_basement")


func _crossroads_progress() -> Dictionary:
	var progress := _basement_progress()
	for index in range(5):
		progress = _complete_current_round(progress)
		progress = _accept(progress, "basement_exit_requested", {"round_token": progress.transition_serial}, "basement_loop" if index < 4 else "enter_crossroads")
	return progress


func _complete_current_round(progress: Dictionary) -> Dictionary:
	var sealed := _accept(progress, "entrance_threshold_crossed", {"round_token": progress.transition_serial}, "entrance_locked")
	return _accept(sealed, "npc_help_completed", _help_payload(sealed), "help_completed")


func _help_payload(progress: Dictionary) -> Dictionary:
	return {"task_id": TASK_IDS[progress.round_index], "npc_id": "basement_npc_%02d" % (progress.round_index + 1), "round_token": progress.transition_serial}


func _accept(progress: Dictionary, event_id: String, payload: Dictionary, expected_transition: String) -> Dictionary:
	var before := progress.duplicate(true)
	var result: Dictionary = _director.dispatch(progress, event_id, payload)
	_assert_true(bool(result.get("accepted", false)), "%s should be accepted in the current stage" % event_id)
	_assert_eq(result.get("transition"), expected_transition, "%s should emit its documented transition" % event_id)
	_assert_eq(progress, before, "dispatch must not mutate its caller's progress")
	return result.get("progress", {})


func _assert_rejected(progress: Dictionary, event_id: String, payload: Dictionary, reason: String) -> void:
	var before := progress.duplicate(true)
	var result: Dictionary = _director.dispatch(progress, event_id, payload)
	_assert_true(not bool(result.get("accepted", true)), reason)
	_assert_eq(result.get("transition"), "", "rejected events must not request a transition")
	_assert_eq(result.get("progress"), _director.normalize_progress(progress), "rejected events return safe progress without granting advancement")
	_assert_eq(progress, before, "rejected events do not mutate their caller")


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
