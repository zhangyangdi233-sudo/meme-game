extends SceneTree

const Director = preload("res://scripts/progression/basement_loop_director.gd")
const State = preload("res://scripts/meme_game_state.gd")
var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	_test_tunnel_entry_requires_completed_current_visit()
	_test_five_tunnels_preserve_visit_until_door_transition()
	_test_tunnel_save_and_old_save_compatibility()
	_test_invalid_tunnel_claims_are_removed()
	if _failures.is_empty():
		print("basement tunnel progress: %d checks passed" % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("basement tunnel progress: %d failures / %d checks" % [_failures.size(), _checks])
		quit(1)


func _test_tunnel_entry_requires_completed_current_visit() -> void:
	var opening := Director.initial_progress()
	_check(opening.get("exit_tunnel_entered") == false, "new progress explicitly starts outside the exit tunnel")
	_reject(opening, "basement_tunnel_entered", {"round_token": 0}, "opening cannot enter a basement tunnel")
	var progress := _basement()
	_reject(progress, "basement_tunnel_entered", {"round_token": 1}, "an unsealed basement cannot enter its tunnel")
	progress = _accept(progress, "entrance_threshold_crossed", {"round_token": 1})
	_reject(progress, "basement_tunnel_entered", {"round_token": 1}, "a sealed basement still requires the current help task")
	progress = _accept(progress, "npc_help_completed", _help(progress))
	_reject(progress, "basement_exit_requested", {"round_token": 1}, "completed help cannot skip walking into the tunnel")
	for invalid_token in [null, 0, 2, "1", 1.5, true]:
		_reject(progress, "basement_tunnel_entered", {"round_token": invalid_token}, "tunnel entry rejects a missing, stale or malformed token: %s" % str(invalid_token))
	var entered := _accept(progress, "basement_tunnel_entered", {"round_token": 1.0}, "basement_tunnel_entered")
	_check(entered.get("exit_tunnel_entered") == true, "validated tunnel entry is recorded")
	_check(progress.get("exit_tunnel_entered", false) == false, "dispatch does not mutate the caller's progress")
	_reject(entered, "basement_tunnel_entered", {"round_token": 1}, "duplicate tunnel threshold callbacks are idempotent")
	_reject(entered, "basement_exit_requested", {"round_token": 0}, "an old white-door completion cannot advance the current visit")
	_reject(entered, "time_elapsed", {"seconds": 999}, "elapsed time in the tunnel never advances a round")
	_reject(entered, "player_near_door", {"round_token": 1}, "approaching the white door never advances a round")


func _test_five_tunnels_preserve_visit_until_door_transition() -> void:
	var progress := _basement()
	for index in range(5):
		progress = _complete(progress)
		var before := progress.duplicate(true)
		var token: int = progress.transition_serial
		progress = _accept(progress, "basement_tunnel_entered", {"round_token": token}, "basement_tunnel_entered")
		_check(progress.get("phase") == "basement" and progress.round_index == index and progress.transition_serial == token, "round %d tunnel entry keeps the same world route and event token" % (index + 1))
		_check(progress.entrance_locked and progress.completed_task_ids == before.completed_task_ids and progress.unlocked_app_ids == before.unlocked_app_ids, "round %d tunnel entry preserves tasks, apps and the sealed entrance" % (index + 1))
		_check(Director.get_current_round(progress) == Director.get_current_round(before), "the same current visit remains addressable while walking in the tunnel")
		_check(Director.normalize_progress(progress) == progress, "entered tunnel progress is stable under normalization")
		progress = _accept(progress, "basement_exit_requested", {"round_token": token}, "basement_loop" if index < 4 else "enter_crossroads")
		_check(progress.get("exit_tunnel_entered") == false, "every successful white-door transition clears the previous tunnel flag")
		_check(progress.transition_serial == token + 1, "only the completed white-door transition invalidates the visit token")
		_reject(progress, "basement_exit_requested", {"round_token": token}, "repeated white-door completion cannot skip the following visit")
		_reject(progress, "basement_tunnel_entered", {"round_token": token}, "an old tunnel threshold cannot mark the next visit")
		if index < 4:
			_check(progress.phase == "basement" and progress.round_index == index + 1 and not progress.entrance_locked, "the next basement starts with its own open entrance")
		else:
			_check(progress.phase == "crossroads" and progress.round_index == 4, "the fifth white door reaches the existing crossroads")
	_check(progress.completed_task_ids == Director.TASK_IDS and progress.unlocked_app_ids == Director.REQUIRED_APP_IDS, "all five tunnel transitions preserve the original earned app rewards")
	progress = _accept(progress, "crossroads_gate_requested", {}, "enter_tower")
	_check(progress.transition_serial == 7 and progress.get("exit_tunnel_entered") == false, "the existing final gate and serial sequence stay unchanged")


func _test_tunnel_save_and_old_save_compatibility() -> void:
	var state = State.new()
	state.new_run()
	state.chapter1_progress = _complete(_basement())
	var before: Dictionary = state.chapter1_progress.duplicate(true)
	_check(state.notify_chapter1("basement_tunnel_entered", {"round_token": 1}).accepted, "game state accepts the actual tunnel threshold event")
	var save: Dictionary = JSON.parse_string(JSON.stringify(state.to_save_data()))
	_check(save.state.chapter1_progress.get("exit_tunnel_entered") == true, "the ordinary save envelope persists being inside the tunnel")
	var restored = State.new()
	_check(restored.load_save_data(save), "an in-tunnel save loads through the normal state API")
	_check(restored.chapter1_progress == state.chapter1_progress, "JSON load retains the same round, token, rewards and tunnel progress")
	_check(restored.spend_action("tunnel-phone-practice") and restored.actions_remaining == state.actions_remaining, "walking in the tunnel keeps the chapter practice action budget")
	_check(restored.notify_chapter1("basement_exit_requested", {"round_token": 1}).accepted, "a loaded tunnel can complete its pending white-door transition")
	_check(restored.chapter1_progress.round_index == 1 and restored.chapter1_progress.get("exit_tunnel_entered") == false, "resuming a tunnel advances exactly once and resets the flag")
	var legacy_save := save.duplicate(true)
	legacy_save.state.chapter1_progress.erase("exit_tunnel_entered")
	var legacy = State.new()
	_check(legacy.load_save_data(legacy_save), "pre-tunnel chapter saves remain loadable")
	_check(legacy.chapter1_progress.get("exit_tunnel_entered") == false, "a missing legacy field never claims tunnel entry")
	_check(legacy.chapter1_progress.completed_task_ids == before.completed_task_ids and legacy.chapter1_progress.unlocked_app_ids == before.unlocked_app_ids, "old saves preserve already completed help and earned apps")
	_check(not legacy.notify_chapter1("basement_exit_requested", {"round_token": 1}).accepted, "an old save must first walk into the new tunnel")
	_check(legacy.notify_chapter1("basement_tunnel_entered", {"round_token": 1}).accepted and legacy.notify_chapter1("basement_exit_requested", {"round_token": 1}).accepted, "the old save can still take the complete new route")
	var ordinary = State.new()
	ordinary.new_run()
	_check(not ordinary.notify_chapter1("basement_tunnel_entered", {"round_token": 1}).accepted and ordinary.chapter1_progress.is_empty(), "tunnel events cannot activate ordinary legacy play")


func _test_invalid_tunnel_claims_are_removed() -> void:
	var valid := _complete(_basement())
	valid.exit_tunnel_entered = true
	_check(Director.normalize_progress(valid).get("exit_tunnel_entered") == true, "only a completed sealed basement can retain the saved tunnel flag")
	for invalid_value in [false, 1, "true", [], {"value": true}, null]:
		var invalid := valid.duplicate(true)
		invalid.exit_tunnel_entered = invalid_value
		_check(Director.normalize_progress(invalid).get("exit_tunnel_entered") == false, "the tunnel flag requires literal boolean true: %s" % str(invalid_value))
	for field in ["entrance_locked", "completed_task_ids", "opening_knock_completed", "phase"]:
		var invalid := valid.duplicate(true)
		match field:
			"entrance_locked": invalid.entrance_locked = false
			"completed_task_ids": invalid.completed_task_ids = []
			"opening_knock_completed": invalid.opening_knock_completed = false
			"phase": invalid.phase = "opening"
		var normalized := Director.normalize_progress(invalid)
		_check(normalized.get("exit_tunnel_entered") == false, "a tunnel claim cannot supply missing prerequisites: %s" % field)
		_check(Director.normalize_progress(normalized) == normalized, "rejecting a forged tunnel claim is stable on the next load")
	for phase in ["crossroads", "tower"]:
		var outside := valid.duplicate(true)
		outside.phase = phase
		outside.round_index = 4
		outside.completed_task_ids = Director.TASK_IDS.duplicate()
		outside.unlocked_app_ids = Director.REQUIRED_APP_IDS.duplicate()
		var normalized := Director.normalize_progress(outside)
		_check(normalized.phase == phase and normalized.get("exit_tunnel_entered") == false, "already reached %s saves retain their stage without leaking the tunnel flag" % phase)


func _basement() -> Dictionary:
	var progress := _accept(Director.initial_progress(), "opening_knock_completed", {"sequence_id": Director.OPENING_SEQUENCE_ID})
	return _accept(progress, "opening_door_opened")


func _complete(progress: Dictionary) -> Dictionary:
	progress = _accept(progress, "entrance_threshold_crossed", {"round_token": progress.transition_serial})
	return _accept(progress, "npc_help_completed", _help(progress))


func _help(progress: Dictionary) -> Dictionary:
	var current := Director.get_current_round(progress)
	return {"round_token": progress.transition_serial, "task_id": current.task_id, "npc_id": current.npc_id}


func _accept(progress: Dictionary, event_id: String, payload: Dictionary = {}, transition: String = "") -> Dictionary:
	var result := Director.dispatch(progress, event_id, payload)
	_check(result.accepted, "expected accepted event: %s" % event_id)
	if not transition.is_empty():
		_check(result.transition == transition, "event %s reports its exact transition" % event_id)
	return result.progress


func _reject(progress: Dictionary, event_id: String, payload: Dictionary, message: String) -> void:
	var result := Director.dispatch(progress, event_id, payload)
	_check(not result.accepted and result.transition.is_empty(), message)
	_check(result.progress == Director.normalize_progress(progress), "rejected %s preserves normalized progress" % event_id)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
