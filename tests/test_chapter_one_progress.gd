extends SceneTree
## Chapter one's opening rules: the narration advances one line at a time, the knock waits for its line, and the
## door opens into the basement only after both. Pure rules on a progress dictionary, then the state that saves it.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const StateScript = preload("res://scripts/meme_game_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()


func _run() -> void:
	test_a_new_progress_starts_on_the_first_line()
	test_the_narration_advances_one_line_at_a_time()
	test_the_knock_waits_for_its_line()
	test_the_knock_is_heard_once()
	test_the_door_needs_the_narration_and_the_knock()
	test_the_door_opens_into_the_first_basement_round()
	test_a_broken_progress_falls_back_to_the_opening()
	test_a_basement_claim_without_the_door_is_refused()
	test_a_new_run_starts_the_opening()
	test_the_state_advances_and_refuses_through_the_rules()
	test_a_save_keeps_the_line_and_the_knock()
	test_a_save_made_before_chapter_one_stays_on_the_tower()
	test_skipping_chapter_one_lands_on_the_tower()
	test_the_exit_opens_only_after_a_delivery_with_this_rounds_post()
	test_leaving_through_the_exit_starts_the_next_round()
	test_the_fifth_exit_leads_to_the_crossroads()
	test_a_saved_delivery_is_kept_only_in_the_basement()
	test_the_debug_jump_lands_on_a_fresh_round()
	if _failures.is_empty():
		print("chapter one progress tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_a_new_progress_starts_on_the_first_line() -> void:
	var progress: Dictionary = ProgressScript.initial()
	_assert_eq(progress.get("phase"), ProgressScript.PHASE_OPENING, "a new progress should start in the opening")
	_assert_eq(progress.get("line_index"), 0, "a new progress should show the first line")
	_assert_true(ProgressScript.is_reading_narration(progress), "a new progress should be reading the narration")
	_assert_true(not ProgressScript.knock_due(progress), "the knock should not be due on the first line")
	_assert_true(not ProgressScript.door_ready(progress), "the door should not open on the first line")


func test_the_narration_advances_one_line_at_a_time() -> void:
	var progress: Dictionary = ProgressScript.initial()
	progress = ProgressScript.advance_narration(progress)
	_assert_eq(progress.get("line_index"), 1, "one advance should show the second line")
	for step in ProgressScript.OPENING_LINE_COUNT - 2:
		progress = ProgressScript.advance_narration(progress)
	_assert_eq(progress.get("line_index"), ProgressScript.OPENING_LINE_COUNT - 1, "the advances should reach the last line")
	_assert_true(ProgressScript.is_reading_narration(progress), "the last line should still be read")
	progress = ProgressScript.advance_narration(progress)
	_assert_true(bool(progress.get("narration_complete")), "advancing past the last line should complete the narration")
	_assert_true(not ProgressScript.is_reading_narration(progress), "a complete narration should no longer be read")
	var after := ProgressScript.advance_narration(progress)
	_assert_eq(after, progress, "a complete narration should not advance again")


func test_the_knock_waits_for_its_line() -> void:
	var progress: Dictionary = ProgressScript.initial()
	for step in ProgressScript.KNOCK_LINE_INDEX - 1:
		progress = ProgressScript.advance_narration(progress)
	_assert_true(not ProgressScript.knock_due(progress), "the knock should not be due the line before its own")
	_assert_eq(ProgressScript.complete_knock(progress), progress, "a knock before its line should be refused")
	progress = ProgressScript.advance_narration(progress)
	_assert_eq(progress.get("line_index"), ProgressScript.KNOCK_LINE_INDEX, "the narration should reach the knock line")
	_assert_true(ProgressScript.knock_due(progress), "the knock should be due on its line")


func test_the_knock_is_heard_once() -> void:
	var progress := _at_line(ProgressScript.KNOCK_LINE_INDEX)
	progress = ProgressScript.complete_knock(progress)
	_assert_true(bool(progress.get("knock_complete")), "a finished knock should be recorded")
	_assert_true(not ProgressScript.knock_due(progress), "a heard knock should not be due again")
	_assert_eq(ProgressScript.complete_knock(progress), progress, "a second knock should change nothing")


func test_the_door_needs_the_narration_and_the_knock() -> void:
	var knocked := ProgressScript.complete_knock(_at_line(ProgressScript.KNOCK_LINE_INDEX))
	_assert_true(not ProgressScript.door_ready(knocked), "the door should stay shut while the narration is read")
	_assert_eq(ProgressScript.open_door(knocked), knocked, "opening the door during the narration should be refused")
	var read := _at_line(ProgressScript.OPENING_LINE_COUNT - 1)
	read = ProgressScript.advance_narration(read)
	_assert_true(bool(read.get("narration_complete")), "the narration should be complete")
	_assert_true(ProgressScript.knock_due(read), "a narration read past the knock line should still owe the knock")
	_assert_true(not ProgressScript.door_ready(read), "the door should stay shut until the knock has finished")
	_assert_eq(ProgressScript.open_door(read), read, "opening the door before the knock finishes should be refused")
	var ready := ProgressScript.complete_knock(read)
	_assert_true(ProgressScript.door_ready(ready), "the door should open once the narration is read and the knock heard")


func test_the_door_opens_into_the_first_basement_round() -> void:
	var opened := ProgressScript.open_door(_ready_door())
	_assert_eq(opened.get("phase"), ProgressScript.PHASE_BASEMENT, "opening the door should enter the basement")
	_assert_eq(opened.get("round"), 1, "the basement should start on round one")
	_assert_true(not ProgressScript.door_ready(opened), "the opening door should not open twice")
	_assert_eq(ProgressScript.open_door(opened), opened, "a second door request should change nothing")
	_assert_true(not ProgressScript.is_reading_narration(opened), "the basement should not read the narration")


func test_a_broken_progress_falls_back_to_the_opening() -> void:
	_assert_eq(ProgressScript.normalize(null), ProgressScript.initial(), "a missing progress should be a new opening")
	_assert_eq(ProgressScript.normalize({"phase": "moon"}), ProgressScript.initial(), "an unknown phase should be a new opening")
	var beyond := ProgressScript.normalize({"phase": "opening", "line_index": 999})
	_assert_eq(beyond.get("line_index"), ProgressScript.OPENING_LINE_COUNT - 1, "a line past the end should clamp to the last line")
	var negative := ProgressScript.normalize({"phase": "opening", "line_index": -3})
	_assert_eq(negative.get("line_index"), 0, "a negative line should clamp to the first")
	var text_line := ProgressScript.normalize({"phase": "opening", "line_index": "5"})
	_assert_eq(text_line.get("line_index"), 0, "a line that is not a number should start over")
	var early_knock := ProgressScript.normalize({"phase": "opening", "line_index": 3, "knock_complete": true})
	_assert_true(not bool(early_knock.get("knock_complete")), "a knock claimed before its line should be dropped")
	var read := ProgressScript.normalize({"phase": "opening", "line_index": 2, "narration_complete": true})
	_assert_eq(read.get("line_index"), ProgressScript.OPENING_LINE_COUNT - 1, "a complete narration should rest on the last line")


func test_a_basement_claim_without_the_door_is_refused() -> void:
	var claimed := ProgressScript.normalize({"phase": "basement", "line_index": 4, "round": 1})
	_assert_eq(claimed.get("phase"), ProgressScript.PHASE_OPENING, "a basement without the narration and knock should go back to the opening")
	_assert_eq(claimed.get("line_index"), 4, "the line read so far should be kept")
	var earned := ProgressScript.normalize(ProgressScript.open_door(_ready_door()))
	_assert_eq(earned.get("phase"), ProgressScript.PHASE_BASEMENT, "an earned basement should be kept")
	var far := ProgressScript.normalize(_with(ProgressScript.open_door(_ready_door()), "round", 40))
	_assert_eq(far.get("round"), ProgressScript.BASEMENT_ROUND_COUNT, "a round past the last should clamp")


func test_a_new_run_starts_the_opening() -> void:
	var game := Harness.new_state()
	_assert_eq(game.chapter_one_progress, ProgressScript.initial(), "a new run should start the opening")
	_assert_true(PropertyKeysScript.is_run(PropertyKeysScript.CHAPTER_ONE_PROGRESS), "chapter one progress should be a run model")
	_assert_true(PropertyKeysScript.CHAPTER_ONE_PROGRESS in PropertyKeysScript.names_saved_as(PropertyKeysScript.SAVED_WITH_RUN), "chapter one progress should be saved with the run")


func test_the_state_advances_and_refuses_through_the_rules() -> void:
	var game := Harness.new_state()
	_assert_true(not game.complete_opening_knock(), "the state should refuse a knock before its line")
	_assert_true(not game.open_opening_door(), "the state should refuse the door on the first line")
	for step in ProgressScript.KNOCK_LINE_INDEX:
		_assert_true(game.advance_opening_narration(), "each advance should be accepted while reading")
	_assert_eq(int(game.chapter_one_progress.get("line_index")), ProgressScript.KNOCK_LINE_INDEX, "the state should reach the knock line")
	_assert_true(game.complete_opening_knock(), "the state should record the knock on its line")
	_assert_true(not game.complete_opening_knock(), "the state should refuse a second knock")
	while ProgressScript.is_reading_narration(game.chapter_one_progress):
		game.advance_opening_narration()
	_assert_true(not game.advance_opening_narration(), "a complete narration should refuse another advance")
	_assert_true(game.open_opening_door(), "the state should open the door after the narration and knock")
	_assert_eq(game.chapter_one_progress.get("phase"), ProgressScript.PHASE_BASEMENT, "the state should enter the basement")
	game.new_run()
	_assert_eq(game.chapter_one_progress, ProgressScript.initial(), "a new run should start the opening again")


func test_a_save_keeps_the_line_and_the_knock() -> void:
	var game := Harness.new_state()
	for step in ProgressScript.KNOCK_LINE_INDEX + 1:
		game.advance_opening_narration()
	game.complete_opening_knock()
	var saved: Dictionary = game.to_save_data()
	var restored := StateScript.new()
	_assert_true(restored.load_save_data(saved), "a save in the opening should load")
	_assert_eq(int(restored.chapter_one_progress.get("line_index")), ProgressScript.KNOCK_LINE_INDEX + 1, "loading should come back on the same line")
	_assert_true(bool(restored.chapter_one_progress.get("knock_complete")), "loading should remember the knock was heard")
	_assert_true(not ProgressScript.knock_due(restored.chapter_one_progress), "a heard knock should not be due after loading")


func test_a_save_made_before_chapter_one_stays_on_the_tower() -> void:
	var game := Harness.new_state()
	var saved: Dictionary = game.to_save_data()
	(saved["state"] as Dictionary).erase(PropertyKeysScript.CHAPTER_ONE_PROGRESS)
	var restored := StateScript.new()
	_assert_true(restored.load_save_data(saved), "a save without chapter one should still load")
	_assert_eq(restored.chapter_one_progress.get("phase"), ProgressScript.PHASE_TOWER, "a save made before chapter one should stay on the tower street")
	_assert_true(not ProgressScript.is_reading_narration(restored.chapter_one_progress), "the tower should not read the narration")


func test_skipping_chapter_one_lands_on_the_tower() -> void:
	var game := Harness.new_state()
	game.skip_chapter_one()
	_assert_eq(game.chapter_one_progress.get("phase"), ProgressScript.PHASE_TOWER, "skipping chapter one should land on the tower street")
	_assert_true(not game.advance_opening_narration(), "the tower should refuse the narration")
	_assert_true(not game.open_opening_door(), "the tower should refuse the opening door")


func test_the_exit_opens_only_after_a_delivery_with_this_rounds_post() -> void:
	var basement := ProgressScript.open_door(_ready_door())
	_assert_true(not ProgressScript.exit_open(basement), "a new round's exit should be shut")
	_assert_eq(ProgressScript.deliver(basement, false), basement, "a delivery without this round's post should be refused")
	var delivered := ProgressScript.deliver(basement, true)
	_assert_true(bool(delivered.get("delivered")), "a delivery with this round's post should be recorded")
	_assert_true(ProgressScript.exit_open(delivered), "a delivered round's exit should open")
	_assert_eq(ProgressScript.deliver(delivered, true), delivered, "a second delivery should change nothing")
	var opening := _ready_door()
	_assert_eq(ProgressScript.deliver(opening, true), opening, "the opening has no round to deliver")
	_assert_true(not ProgressScript.exit_open(ProgressScript.tower()), "the tower has no basement exit")


func test_leaving_through_the_exit_starts_the_next_round() -> void:
	var basement := ProgressScript.open_door(_ready_door())
	_assert_eq(ProgressScript.leave_round(basement), basement, "a shut exit should not be left through")
	var next := ProgressScript.leave_round(ProgressScript.deliver(basement, true))
	_assert_eq(next.get("phase"), ProgressScript.PHASE_BASEMENT, "the next round should still be the basement")
	_assert_eq(ProgressScript.round_of(next), 2, "leaving round one should start round two")
	_assert_true(not ProgressScript.exit_open(next), "the next round's exit should be shut again")


func test_the_fifth_exit_leads_to_the_crossroads() -> void:
	var progress := ProgressScript.open_door(_ready_door())
	for round_number in range(1, ProgressScript.BASEMENT_ROUND_COUNT):
		progress = ProgressScript.leave_round(ProgressScript.deliver(progress, true))
		_assert_eq(ProgressScript.round_of(progress), round_number + 1, "each exit should start the following round")
	_assert_eq(ProgressScript.leave_round(progress), progress, "the fifth round's shut exit should hold")
	var crossroads := ProgressScript.leave_round(ProgressScript.deliver(progress, true))
	_assert_eq(crossroads.get("phase"), ProgressScript.PHASE_TOWER, "the fifth exit should leave chapter one for the crossroads")
	_assert_eq(ProgressScript.round_of(crossroads), 0, "the crossroads has no basement round")


func test_a_saved_delivery_is_kept_only_in_the_basement() -> void:
	var delivered := ProgressScript.deliver(_with(ProgressScript.open_door(_ready_door()), "round", 3), true)
	var restored := ProgressScript.normalize(delivered.duplicate(true))
	_assert_eq(ProgressScript.round_of(restored), 3, "a saved round should come back")
	_assert_true(ProgressScript.exit_open(restored), "a saved delivery should keep the exit open")
	var unearned := ProgressScript.normalize(_with(_ready_door(), "delivered", true))
	_assert_true(not bool(unearned.get("delivered")), "a delivery claimed in the opening should be dropped")
	var text := ProgressScript.normalize(_with(ProgressScript.open_door(_ready_door()), "delivered", "yes"))
	_assert_true(not ProgressScript.exit_open(text), "a delivery that is not a bool should be dropped")


func test_the_debug_jump_lands_on_a_fresh_round() -> void:
	var jumped := ProgressScript.jump_to_round(ProgressScript.initial(), 4)
	_assert_eq(jumped.get("phase"), ProgressScript.PHASE_BASEMENT, "a jump should land in the basement")
	_assert_eq(ProgressScript.round_of(jumped), 4, "a jump should land on the asked round")
	_assert_true(not ProgressScript.exit_open(jumped), "a jumped round's exit should be shut")
	_assert_eq(ProgressScript.normalize(jumped), jumped, "a jumped round should survive a save")
	var delivered := ProgressScript.deliver(jumped, true)
	_assert_true(not ProgressScript.exit_open(ProgressScript.jump_to_round(delivered, 4)), "jumping to the same round should start it fresh")
	_assert_eq(ProgressScript.jump_to_round(jumped, 0), jumped, "a jump before round one should be refused")
	_assert_eq(ProgressScript.jump_to_round(jumped, ProgressScript.BASEMENT_ROUND_COUNT + 1), jumped, "a jump past the last round should be refused")


func _at_line(line_index: int) -> Dictionary:
	var progress: Dictionary = ProgressScript.initial()
	for step in line_index:
		progress = ProgressScript.advance_narration(progress)
	return progress


func _ready_door() -> Dictionary:
	var progress := _at_line(ProgressScript.KNOCK_LINE_INDEX)
	progress = ProgressScript.complete_knock(progress)
	while ProgressScript.is_reading_narration(progress):
		progress = ProgressScript.advance_narration(progress)
	return progress


func _with(progress: Dictionary, key: String, value: Variant) -> Dictionary:
	var changed := progress.duplicate(true)
	changed[key] = value
	return changed


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
