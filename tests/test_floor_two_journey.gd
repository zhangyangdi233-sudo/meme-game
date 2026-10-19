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
	_check(initial == {"version": 2, "accepted": false, "visited_turn_ids": [], "map_unlocked": false, "map_intro_completed": false, "note_read": false, "xray_observed_ids": [], "exit_reached": false}, "a new journey starts with a pending map introduction and unread note")
	_check(journey.has_method("needs_map_intro") and journey.has_method("complete_map_intro") and journey.has_method("mark_note_read"), "map introduction and independent note transitions are available")
	if not journey.has_method("needs_map_intro"):
		return
	_check(journey.normalize(null) == initial and journey.normalize("invalid") == initial, "non-dictionary saves recover without granting progress")
	_check(journey.needs_map_intro(initial), "fresh and interrupted introductions remain pending")
	_check(journey.visit_turn(initial, "turn_1") == initial, "walking before the introduction earns no checkpoint")
	for actor in ["floor2_wayfinder", "floor2_cartographer", "unknown"]:
		_check(journey.finish_dialogue(initial, actor) == initial, "legacy NPC callback is a harmless compatibility no-op: " + actor)
	var unlocked: Dictionary = journey.complete_map_intro(initial)
	_check(unlocked.map_unlocked and unlocked.map_intro_completed and not unlocked.accepted, "only the completed introduction grants the map without inventing NPC acceptance")
	_check(not journey.needs_map_intro(unlocked), "a completed introduction cannot replay")
	_check(not initial.map_unlocked and not initial.map_intro_completed, "granting the map returns a copy without mutating caller state")
	_check(journey.complete_map_intro(unlocked) == unlocked, "map completion is idempotent")
	var legacy: Dictionary = journey.normalize({"accepted": true})
	_check(legacy.accepted and legacy.map_unlocked and legacy.map_intro_completed and not journey.needs_map_intro(legacy), "old accepted-only saves retain their earned map and skip the new introduction")
	_check(journey.normalize({"accepted": true, "map_unlocked": false}) == legacy, "old explicit locked flags retain the prior accepted-save migration")
	_check(not journey.normalize({"version": 2, "accepted": true}).map_unlocked, "a versioned acceptance flag cannot masquerade as an old reward")
	_check(not journey.normalize({"version": "2", "accepted": true, "map_unlocked": true}).map_unlocked, "a malformed version cannot use legacy reward migration")
	_check(journey.visit_turn(unlocked, "turn_2") == unlocked, "second turn is rejected before the first")
	_check(journey.visit_turn(unlocked, "turn_a") == unlocked, "unknown checkpoint IDs cannot advance the ordered route")
	var first: Dictionary = journey.visit_turn(unlocked, "turn_1")
	_check(first.visited_turn_ids == ["turn_1"] and unlocked.visited_turn_ids.is_empty(), "first turn records progress without an NPC or array alias")
	_check(journey.visit_turn(first, "turn_1") == first, "revisiting the first checkpoint is harmless")
	var second: Dictionary = journey.visit_turn(first, "turn_2")
	_check(second.visited_turn_ids == ["turn_1", "turn_2"] and second.map_unlocked, "optional turn records preserve the map earned by the introduction")
	_check(journey.visit_turn(second, "turn_2") == second, "duplicate last checkpoint cannot add duplicate progress")
	var note: Dictionary = journey.mark_note_read(initial)
	_check(note.note_read and not note.map_unlocked and not note.accepted and note.xray_observed_ids.is_empty(), "reading the note is independent of map access, NPC acceptance and Xray observations")
	_check(not initial.note_read and journey.mark_note_read(note) == note, "note reading is immutable and idempotent")
	_check(journey.complete_map_intro(note).note_read and journey.mark_note_read(unlocked).map_unlocked, "map and note transitions preserve each other's progress in either order")
	for progress in [initial, legacy, first, second, unlocked, note]:
		_check(journey.normalize(JSON.parse_string(JSON.stringify(progress))) == progress, "each legitimate stage survives JSON save/load")
		_check(journey.finish_dialogue(progress, "floor2_wayfinder") == progress, "legacy callbacks preserve every legitimate state")
	for raw in [
		{"accepted": false, "visited_turn_ids": ["turn_1", "turn_2"], "map_unlocked": true, "exit_reached": true},
		{"accepted": "yes", "visited_turn_ids": ["turn_1", "turn_2"], "map_unlocked": true},
		{"map_unlocked": true, "exit_reached": true},
		{"version": 2, "map_unlocked": true, "map_intro_completed": "yes", "note_read": 1},
	]:
		_check(journey.normalize(raw) == initial, "claimed later flags and wrong types cannot invent a map introduction")
	var malformed: Dictionary = journey.normalize({"accepted": true, "visited_turn_ids": ["turn_2", "turn_1"], "map_unlocked": true, "exit_reached": true})
	_check(malformed == legacy, "out-of-order saved turns are discarded without revoking a valid legacy map")
	malformed = journey.normalize({"accepted": true, "visited_turn_ids": ["turn_1", "turn_1", "turn_2"], "map_unlocked": true})
	_check(malformed.visited_turn_ids == ["turn_1"], "duplicate saved checkpoint does not fabricate the next turn")
	malformed = journey.normalize({"accepted": true, "visited_turn_ids": "turn_1", "map_unlocked": 1, "exit_reached": true})
	_check(malformed == legacy, "wrong field types remain bounded and unearned")
	var exited := unlocked.duplicate(true)
	exited.exit_reached = true
	_check(not journey.normalize(exited).exit_reached, "map access alone cannot reveal the exit")
	_check(journey.record_xray_observation(initial, "xray_intro") == initial, "a still-gray map cannot record Xray rewards")
	_check(journey.record_xray_observation(unlocked, "exit") == unlocked, "out-of-order Xray observations cannot bypass the lesson")
	for id in journey.XRAY_OBSERVATION_IDS:
		exited = journey.record_xray_observation(exited, id)
	exited.exit_reached = true
	_check(journey.normalize(exited).exit_reached and journey.can_exit(exited), "actual exit completion persists after all three discoveries")
	_check(exited.visited_turn_ids.is_empty() and not exited.accepted, "the new route never requires removed NPCs or optional turns")
	_check(journey.mark_note_read(exited).xray_observed_ids == exited.xray_observed_ids, "reading the note never resets a completed observation route")


func _test_state_reward() -> void:
	var journey: Script = load(SCRIPT_PATH)
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
	_check(not state.finish_floor_two_dialogue() and not state.is_phone_app_unlocked("map"), "even a completed obsolete NPC callback cannot grant map access")
	if not journey.has_method("complete_map_intro"):
		return
	state.floor_two_progress = journey.complete_map_intro(state.floor_two_progress)
	_check(state.can_use_app("map", "phone") and not state.can_use_app("map", "terminal"), "the introduction opens only the phone map and preserves CRT permissions")
	_check(not state.floor_two_progress.accepted and not state.try_exit_floor_two(), "the introduction grants only map access, never NPC history or the exit")
	var restored = load("res://scripts/meme_game_state.gd").new()
	_check(restored.load_save_data(state.to_save_data()) and restored.is_phone_app_unlocked("map") and not journey.needs_map_intro(restored.floor_two_progress), "actual State save/load retains completion without replaying the introduction")
	_check(restored.load_save_data({"version": 5, "state": {"tower_floor": 2, "floor_two_progress": {"accepted": true}}}) and restored.is_phone_app_unlocked("map"), "legacy accepted-only State saves migrate to the early reward")
	_check(restored.load_save_data({"version": 5, "state": {"tower_floor": 2, "floor_two_progress": {"map_unlocked": true}}}) and not restored.is_phone_app_unlocked("map"), "forged map-only State saves still cannot invent first NPC completion")
	state.floor_two_progress = journey.mark_note_read(state.floor_two_progress)
	state.new_run()
	_check(journey.needs_map_intro(state.floor_two_progress) and not state.floor_two_progress.note_read and not state.is_phone_app_unlocked("map"), "New Game resets map presentation and note state together")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
