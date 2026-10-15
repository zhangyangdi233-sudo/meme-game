extends SceneTree

const State = preload("res://scripts/meme_game_state.gd")
const Director = preload("res://scripts/progression/basement_loop_director.gd")
var failures: Array[String] = []

func _init() -> void:
	var state = State.new()
	state.new_run()
	state.start_chapter1()
	_check(not bool(state.chapter1_progress.get("phone_collected", false)), "new chapter has no phone")
	_check(not Director.dispatch(state.chapter1_progress, "phone_collected", {"round_token": 0}).accepted, "opening cannot collect phone")
	state.notify_chapter1("narration_completed", {"sequence_id": "chapter1_opening"})
	state.notify_chapter1("opening_knock_completed", {"sequence_id": "chapter1_opening"})
	state.notify_chapter1("opening_door_opened")
	_check(not Director.dispatch(state.chapter1_progress, "phone_collected", {"round_token": 99}).accepted, "stale pickup rejected")
	var collected: Dictionary = state.notify_chapter1("phone_collected", {"round_token": 1})
	_check(collected.accepted, "physical pickup is accepted in basement")
	_check(bool(state.chapter1_progress.get("phone_collected", false)), "pickup is persistent")
	_check(not state.is_phone_app_unlocked("social") and not state.is_phone_app_unlocked("notebook"), "pickup alone grants no applications")
	_check(not state.notify_chapter1("phone_collected", {"round_token": 1}).accepted, "pickup cannot repeat")
	var restored = State.new()
	_check(restored.load_save_data(state.to_save_data()), "pickup save loads")
	_check(bool(restored.chapter1_progress.get("phone_collected", false)), "phone remains owned after continue")
	state.new_run()
	state.start_chapter1()
	_check(not bool(state.chapter1_progress.get("phone_collected", false)), "new game clears pickup")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("phone pickup revision tests passed")
	quit(0 if failures.is_empty() else 1)

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
