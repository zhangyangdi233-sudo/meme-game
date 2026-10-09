extends SceneTree

const State = preload("res://scripts/meme_game_state.gd")
const Loop = preload("res://scripts/progression/basement_loop_director.gd")
var failures: Array[String] = []

func _init() -> void:
	var state = State.new()
	state.new_run()
	state.set_char_canvas_position("门", Vector2(669, 93))
	check(state.get_char_canvas_position("门") == Vector2(669, 93), "wide CRT canvas position survives state storage")
	state.actions_remaining = 0
	for index in 12:
		check(state.spend_action("publish"), "actions remain unlimited")
	check(not state.needs_day_settlement, "no day settlement queued")
	check(not state.can_use_app("babel"), "retired app cannot open")
	state.free_sentence_units.assign(["门", "可以", "打开"])
	var before: int = state.money
	var result: Dictionary = state.submit_free_sentence()
	check(result.submitted, "publishing works without budget")
	check(state.money == before and result.money_gain == 0, "publishing has no money reward")
	check(state.pollution > 0, "pollution remains active in background")
	state.change_pollution(70)
	check(not state.needs_day_settlement, "pollution does not resurrect daily budget")
	state.pollution_flashback_pending = false
	check(state.settle_day_if_needed() and state.tower_floor == 2, "background pollution advances floor without daily actions")
	state.active_app = "babel"
	state.active_app_window = "babel"
	state.money = 100
	state.actions_remaining = 0
	state.needs_day_settlement = true
	var saved := state.to_save_data()
	var loaded = State.new()
	check(loaded.load_save_data(saved), "legacy-shaped resource save loads")
	check(loaded.active_app == "social" and loaded.money == 0 and not loaded.needs_day_settlement and loaded.can_spend_action(), "old save migrates removed app and budgets")
	var progress: Dictionary = Loop.initial_progress()
	progress = Loop.dispatch(progress, "opening_knock_completed", {"sequence_id": Loop.OPENING_SEQUENCE_ID}).progress
	progress = Loop.dispatch(progress, "opening_door_opened").progress
	for index in 5:
		var token: int = progress.transition_serial
		progress = Loop.dispatch(progress, "entrance_threshold_crossed", {"round_token": token}).progress
		check(not Loop.dispatch(progress, "basement_exit_requested", {"round_token": token}).accepted, "unfinished help blocks ordinary door")
		var current: Dictionary = Loop.get_current_round(progress)
		progress = Loop.dispatch(progress, "npc_help_completed", {"round_token": token, "task_id": current.task_id, "npc_id": current.npc_id}).progress
		var exit_result: Dictionary = Loop.dispatch(progress, "basement_exit_requested", {"round_token": token})
		check(exit_result.accepted, "normal exit needs no obsolete tunnel checkpoint")
		progress = exit_result.progress
		progress = Loop.normalize_progress(progress)
	check(progress.phase == "crossroads", "five completed visits reach crossroads")
	check(progress.unlocked_app_ids == ["social", "notebook"], "only two phone apps earned")
	check(Loop.dispatch(progress, "crossroads_gate_requested").accepted, "two apps and five tasks unlock gate")
	if failures.is_empty():
		print("revision progression passed")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
