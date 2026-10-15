extends SceneTree

const SCRIPT_PATH := "res://scripts/progression/floor_two_journey.gd"
var failures: Array[String] = []
var checks := 0


func _init() -> void:
	if not FileAccess.file_exists(SCRIPT_PATH):
		_check(false, "floor-two journey provides independent ordered task state")
	else:
		_test_journey(load(SCRIPT_PATH))
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("floor two journey tests passed (%d checks)" % checks)
	quit(0 if failures.is_empty() else 1)


func _test_journey(journey: Script) -> void:
	var initial: Dictionary = journey.normalize({})
	_check(initial == {"accepted": false, "visited_turn_ids": [], "map_unlocked": false, "exit_reached": false}, "a new journey starts with no earned progress")
	_check(journey.normalize(null) == initial and journey.normalize("invalid") == initial, "non-dictionary saves recover without granting progress")
	_check(journey.visit_turn(initial, "turn_1") == initial, "walking before accepting the task earns no checkpoint")
	_check(journey.finish_dialogue(initial, "floor2_cartographer") == initial, "cartographer cannot unlock a map before the task")
	_check(journey.finish_dialogue(initial, "unknown") == initial, "unrelated NPC cannot grant the task")
	var intro: Dictionary = journey.dialogue_for("floor2_wayfinder", initial)
	_check(initial == journey.normalize({}), "reading dialogue never mutates task state")
	_check(intro.choices.size() == 1 and not str(intro.choices[0].sentence).is_empty(), "wayfinder uses one fixed protagonist keyboard line")
	_check(journey.dialogue_for("unknown", initial).is_empty(), "unknown actors have no task dialogue")
	var accepted: Dictionary = journey.finish_dialogue(initial, "floor2_wayfinder")
	_check(accepted.accepted and accepted.visited_turn_ids.is_empty() and not accepted.map_unlocked, "finishing the first NPC accepts only the walking task")
	_check(not initial.accepted, "state transitions return copies rather than changing caller dictionaries")
	_check(journey.finish_dialogue(accepted, "floor2_wayfinder") == accepted, "acceptance is idempotent")
	_check(journey.visit_turn(accepted, "turn_2") == accepted, "second turn is rejected before the first")
	_check(journey.visit_turn(accepted, "turn_a") == accepted, "unknown checkpoint IDs cannot advance the ordered route")
	var first: Dictionary = journey.visit_turn(accepted, "turn_1")
	_check(first.visited_turn_ids == ["turn_1"] and accepted.visited_turn_ids.is_empty(), "first turn records its own progress without aliasing arrays")
	_check(journey.visit_turn(first, "turn_1") == first, "revisiting the first checkpoint is harmless")
	_check(journey.finish_dialogue(first, "floor2_cartographer") == first, "incomplete route cannot receive a map")
	var second: Dictionary = journey.visit_turn(first, "turn_2")
	_check(second.visited_turn_ids == ["turn_1", "turn_2"] and not second.map_unlocked, "walking both required turns does not silently grant the NPC reward")
	_check(journey.visit_turn(second, "turn_2") == second, "duplicate last checkpoint cannot add duplicate progress")
	var unlocked: Dictionary = journey.finish_dialogue(second, "floor2_cartographer")
	_check(unlocked.map_unlocked and not unlocked.exit_reached, "cartographer unlocks the map while leaving the remaining route unfinished")
	_check(journey.finish_dialogue(unlocked, "floor2_cartographer") == unlocked, "repeated reward dialogue is idempotent")
	_check(journey.finish_dialogue(unlocked, "floor2_wayfinder") == unlocked, "returning to the wayfinder never resets the journey")
	_check(journey.dialogue_for("floor2_cartographer", first).line != journey.dialogue_for("floor2_cartographer", second).line, "cartographer has a reminder before the route and a reward after it")
	_check(journey.dialogue_for("floor2_cartographer", unlocked).line != journey.dialogue_for("floor2_cartographer", second).line, "repeat dialogue does not offer the same gift again")
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
	_check(malformed == accepted, "out-of-order saved turns cannot unlock a reward")
	malformed = journey.normalize({"accepted": true, "visited_turn_ids": ["turn_1", "turn_1", "turn_2"], "map_unlocked": true})
	_check(malformed == first, "duplicate saved checkpoint does not fabricate the next turn")
	malformed = journey.normalize({"accepted": true, "visited_turn_ids": "turn_1", "map_unlocked": 1, "exit_reached": true})
	_check(malformed == accepted, "wrong field types remain bounded and unearned")
	var exited := unlocked.duplicate(true)
	exited.exit_reached = true
	_check(journey.normalize(exited).exit_reached, "actual exit completion can persist after earning the map")
	var no_map := second.duplicate(true)
	no_map.exit_reached = true
	_check(not journey.normalize(no_map).exit_reached, "an exit flag cannot bypass the map reward")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
