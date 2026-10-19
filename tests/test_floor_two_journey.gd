extends SceneTree

const SCRIPT_PATH := "res://scripts/progression/floor_two_journey.gd"
var failures: Array[String] = []
var checks := 0


func _init() -> void:
	if not FileAccess.file_exists(SCRIPT_PATH):
		_check(false, "floor-two journey provides independent ordered task state")
	else:
		_test_journey(load(SCRIPT_PATH))
		_test_state_reward()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("floor two journey tests passed (%d checks)" % checks)
	quit(0 if failures.is_empty() else 1)


func _test_journey(journey: Script) -> void:
	var initial: Dictionary = journey.normalize({})
	_check(initial == {"accepted": false, "visited_turn_ids": [], "map_unlocked": false, "xray_observed_ids": [], "exit_reached": false}, "a new journey starts with no earned progress")
	_check(journey.normalize(null) == initial and journey.normalize("invalid") == initial, "non-dictionary saves recover without granting progress")
	_check(journey.visit_turn(initial, "turn_1") == initial, "walking before accepting the task earns no checkpoint")
	_check(journey.finish_dialogue(initial, "floor2_cartographer") == initial, "cartographer cannot unlock a map before the task")
	_check(journey.finish_dialogue(initial, "unknown") == initial, "unrelated NPC cannot grant the task")
	var intro: Dictionary = journey.dialogue_for("floor2_wayfinder", initial)
	_check(initial == journey.normalize({}), "reading dialogue never mutates task state")
	_check(intro.choices.size() == 1 and not str(intro.choices[0].sentence).is_empty(), "wayfinder uses one fixed protagonist keyboard line")
	_check(journey.dialogue_for("unknown", initial).is_empty(), "unknown actors have no task dialogue")
	var accepted: Dictionary = journey.finish_dialogue(initial, "floor2_wayfinder")
	_check(accepted.accepted and accepted.visited_turn_ids.is_empty() and accepted.map_unlocked, "finishing the first NPC immediately grants the map without walking turns")
	_check(journey.normalize({"accepted": true}) == accepted, "old saves with the first conversation complete receive the map")
	_check(journey.normalize({"accepted": true, "map_unlocked": false}) == accepted, "old explicit locked flags do not undo the completed first conversation")
	_check(not initial.accepted, "state transitions return copies rather than changing caller dictionaries")
	_check(journey.finish_dialogue(accepted, "floor2_wayfinder") == accepted, "acceptance is idempotent")
	_check(journey.visit_turn(accepted, "turn_2") == accepted, "second turn is rejected before the first")
	_check(journey.visit_turn(accepted, "turn_a") == accepted, "unknown checkpoint IDs cannot advance the ordered route")
	var first: Dictionary = journey.visit_turn(accepted, "turn_1")
	_check(first.visited_turn_ids == ["turn_1"] and accepted.visited_turn_ids.is_empty(), "first turn records its own progress without aliasing arrays")
	_check(journey.visit_turn(first, "turn_1") == first, "revisiting the first checkpoint is harmless")
	_check(journey.finish_dialogue(first, "floor2_cartographer") == first, "cartographer is guidance only and does not grant another reward")
	var second: Dictionary = journey.visit_turn(first, "turn_2")
	_check(second.visited_turn_ids == ["turn_1", "turn_2"] and second.map_unlocked, "optional turn records preserve the map already granted by the first NPC")
	_check(journey.visit_turn(second, "turn_2") == second, "duplicate last checkpoint cannot add duplicate progress")
	var unlocked: Dictionary = journey.finish_dialogue(second, "floor2_cartographer")
	_check(unlocked == second and not unlocked.exit_reached, "cartographer cannot bypass Xray discovery or change the earned map")
	_check(journey.finish_dialogue(unlocked, "floor2_cartographer") == unlocked, "repeated reward dialogue is idempotent")
	_check(journey.finish_dialogue(unlocked, "floor2_wayfinder") == unlocked, "returning to the wayfinder never resets the journey")
	_check(journey.dialogue_for("floor2_cartographer", accepted).line == journey.dialogue_for("floor2_cartographer", second).line, "cartographer gives the same short Xray hint regardless of optional turns")
	_check(journey.dialogue_for("floor2_cartographer", initial).line != journey.dialogue_for("floor2_cartographer", accepted).line, "early cartographer points to the first NPC before the map is earned")
	for progress in [initial, accepted, first, second, unlocked]:
		_check(journey.normalize(JSON.parse_string(JSON.stringify(progress))) == progress, "each legitimate stage survives JSON save/load")
		for actor in ["floor2_wayfinder", "floor2_cartographer"]:
			var dialogue: Dictionary = journey.dialogue_for(actor, progress)
			_check(dialogue.choices.size() == 1 and not str(dialogue.line).is_empty() and not str(dialogue.result).is_empty(), "each task state has a complete single-route dialogue")
	for raw in [
		{"accepted": false, "visited_turn_ids": ["turn_1", "turn_2"], "map_unlocked": true, "exit_reached": true},
		{"accepted": "yes", "visited_turn_ids": ["turn_1", "turn_2"], "map_unlocked": true},
		{"map_unlocked": true, "exit_reached": true},
	]:
		_check(journey.normalize(raw) == initial, "claimed later flags cannot invent missing acceptance")
	var malformed: Dictionary = journey.normalize({"accepted": true, "visited_turn_ids": ["turn_2", "turn_1"], "map_unlocked": true, "exit_reached": true})
	_check(malformed == accepted, "out-of-order saved turns are discarded without revoking first-conversation reward")
	malformed = journey.normalize({"accepted": true, "visited_turn_ids": ["turn_1", "turn_1", "turn_2"], "map_unlocked": true})
	_check(malformed == first, "duplicate saved checkpoint does not fabricate the next turn")
	malformed = journey.normalize({"accepted": true, "visited_turn_ids": "turn_1", "map_unlocked": 1, "exit_reached": true})
	_check(malformed == accepted, "wrong field types remain bounded and unearned")
	var exited := unlocked.duplicate(true)
	exited.exit_reached = true
	_check(not journey.normalize(exited).exit_reached, "old map-only progress cannot reveal the exit in the expanded lesson")
	for id in journey.XRAY_OBSERVATION_IDS:
		exited = journey.record_xray_observation(exited, id)
	exited.exit_reached = true
	_check(journey.normalize(exited).exit_reached and journey.can_exit(exited), "actual exit completion persists after all three discoveries")
	var no_map := second.duplicate(true)
	no_map.exit_reached = true
	_check(not journey.normalize(no_map).exit_reached, "an exit flag cannot bypass the three Xray observations")
	var discovered := accepted.duplicate(true)
	for id in journey.XRAY_OBSERVATION_IDS:
		discovered = journey.record_xray_observation(discovered, id)
	_check(discovered.visited_turn_ids.is_empty() and journey.can_exit(discovered), "first conversation plus three observations can finish without the old turns or cartographer reward")
	_check(journey.normalize(discovered) == discovered, "new minimal completion survives save normalization")


func _test_state_reward() -> void:
	var state = load("res://scripts/meme_game_state.gd").new()
	state.new_run()
	state.chapter1_progress = {}
	state.tower_floor = 2
	state.conversation_actor_id = "floor2_wayfinder"
	state.conversation_phase = "typing"
	state.conversation_completed = false
	_check(not state.finish_floor_two_dialogue() and not state.is_phone_app_unlocked("map"), "State refuses map reward before the actual dialogue completes")
	state.conversation_phase = "result"
	state.conversation_completed = true
	_check(state.finish_floor_two_dialogue() and state.is_phone_app_unlocked("map"), "State grants the app at the first completed dialogue callback")
	_check(state.can_use_app("map", "phone") and not state.can_use_app("map", "terminal"), "the first reward opens the phone app without changing CRT permissions")
	_check(state.floor_two_progress.visited_turn_ids.is_empty() and not state.try_exit_floor_two(), "first dialogue grants only map access, never the exit")
	var restored = load("res://scripts/meme_game_state.gd").new()
	_check(restored.load_save_data(state.to_save_data()) and restored.is_phone_app_unlocked("map"), "actual State save/load retains the early reward")
	_check(restored.load_save_data({"version": 5, "state": {"tower_floor": 2, "floor_two_progress": {"accepted": true}}}) and restored.is_phone_app_unlocked("map"), "legacy accepted-only State saves migrate to the early reward")
	_check(restored.load_save_data({"version": 5, "state": {"tower_floor": 2, "floor_two_progress": {"map_unlocked": true}}}) and not restored.is_phone_app_unlocked("map"), "forged map-only State saves still cannot invent first NPC completion")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
