extends SceneTree
## Narrative beat: action spend, day transition, and flashback are one sequence.
## The host passes a settlement result and whether the ending is unlocked.

const NarrativeBeatScript = preload("res://scripts/game/narrative_beat.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_chains_without_flashing_gameplay()
	_test_ending_unlock_replaces_gameplay_exit()
	_test_action_spend_alone_exits_to_gameplay()
	_test_empty_settlement_stays_out_of_narrative()
	_test_host_does_not_split_refresh_audio_and_transitions()
	if _failures.is_empty():
		print("narrative beat tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_chains_without_flashing_gameplay() -> void:
	var beat = NarrativeBeatScript.new()
	beat.play(_full_settlement(), false)
	_assert_eq(beat.current_segment(), "action_spend", "a spent action opens the beat on the action pulse")
	_assert_eq(_modes(beat), "narrative", "the beat should enter narrative once")
	beat.advance()
	_assert_eq(beat.current_segment(), "day_transition", "the day transition follows the action pulse")
	_assert_eq(_modes(beat), "narrative", "the day transition should not leave narrative")
	beat.advance()
	_assert_eq(beat.current_segment(), "flashback", "the flashback follows the day transition when the settlement asks for it")
	_assert_eq(_modes(beat), "narrative", "the flashback should not leave narrative")
	beat.advance()
	_assert_true(beat.is_finished(), "the beat should finish after the flashback")
	_assert_eq(beat.exit_mode(), "gameplay", "a continuing run should exit to gameplay")
	_assert_eq(_modes(beat), "narrative,gameplay", "gameplay should appear only as the exit")


func _test_ending_unlock_replaces_gameplay_exit() -> void:
	var beat = NarrativeBeatScript.new()
	beat.play(_full_settlement(), false)
	beat.advance()
	beat.advance()
	_assert_eq(beat.current_segment(), "flashback", "ending unlock is decided before the last segment exits")
	beat.note_ending_unlocked(true)
	beat.advance()
	_assert_eq(beat.exit_mode(), "ending", "an unlocked ending should be the exit")
	_assert_eq(_modes(beat), "narrative,ending", "the beat should not request gameplay before the ending")

	var already = NarrativeBeatScript.new()
	already.play({"day_transition": true, "flashback": true}, true)
	_assert_eq(already.current_segment(), "day_transition", "a settlement without a spent action should skip the action pulse")
	already.advance()
	_assert_eq(already.current_segment(), "flashback", "flashback should still follow the day transition")
	already.advance()
	_assert_eq(_modes(already), "narrative,ending", "an ending already unlocked at the start should skip gameplay")


func _test_action_spend_alone_exits_to_gameplay() -> void:
	var beat = NarrativeBeatScript.new()
	beat.play({"actions_before": 4, "actions_after": 3}, false)
	_assert_eq(beat.current_segment(), "action_spend", "an action that does not end the day should only pulse")
	beat.advance()
	_assert_true(beat.is_finished(), "the pulse should be the whole beat")
	_assert_eq(_modes(beat), "narrative,gameplay", "the pulse should return to gameplay")


func _test_empty_settlement_stays_out_of_narrative() -> void:
	var beat = NarrativeBeatScript.new()
	beat.play({}, false)
	_assert_true(beat.is_finished(), "an empty settlement should not start a beat")
	_assert_eq(beat.current_segment(), "", "an empty settlement has no segment")
	_assert_eq(_modes(beat), "", "an empty settlement should not request a Session mode")


func _test_host_does_not_split_refresh_audio_and_transitions() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/babel_meme_game.gd")
	var deps := _function_body(source, "_narrative_overlay_deps")
	_assert_true(not deps.is_empty(), "the host should still bind the narrative overlay")
	for forbidden in [
		"\"render\"",
		"\"sync_audio_state\"",
		"\"request_gameplay_from_narrative\"",
		"\"on_day_settled\"",
		"\"on_flashback_settled\"",
		"\"play_action_tick\"",
		"\"play_flashback_audio\"",
		"\"stop_flashback_audio\"",
		"\"duck_ambience\"",
		"\"consume_pollution_flashback\"",
	]:
		_assert_true(
			not deps.contains(forbidden),
			"narrative overlay deps should not chain %s" % forbidden
		)
	var after_action := _function_body(source, "_after_effective_action")
	_assert_true(after_action.contains("play_beat"), "spending an action should start one narrative beat")
	_assert_true(
		not after_action.contains("play_pollution_flashback") and not after_action.contains("play_action_spend_animation"),
		"the host should not pick the flashback or the action pulse itself"
	)


func _full_settlement() -> Dictionary:
	return {
		"actions_before": 1,
		"actions_after": 0,
		"day_transition": true,
		"flashback": true,
	}


func _modes(beat) -> String:
	return ",".join(beat.mode_requests())


func _function_body(source: String, func_name: String) -> String:
	var header := "func %s" % func_name
	var start := source.find(header)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + header.length())
	if next < 0:
		return source.substr(start)
	return source.substr(start, next - start)


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
