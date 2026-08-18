extends SceneTree


var _failures: Array[String] = []
var _director_script: Script = null


func _init() -> void:
	_director_script = load("res://scripts/tutorial/tutorial_director.gd") as Script
	_assert_true(_director_script != null, "tutorial director script should load")
	if _director_script != null:
		test_steps_advance_only_in_authored_order()
		test_collect_word_requires_three_events()
		test_skip_finishes_without_mutating_input()
		test_replay_returns_to_first_step()
		test_old_progress_is_normalized_and_serializable()
	if _failures.is_empty():
		print("tutorial director tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_steps_advance_only_in_authored_order() -> void:
	var progress: Dictionary = _director_script.initial_progress()
	_assert_step(progress, "find_guide")
	var ignored: Dictionary = _director_script.notify(progress, &"social_opened")
	_assert_step(ignored, "find_guide")
	_assert_eq(ignored.get("event_counts", {}), {}, "out-of-order events should not count or skip instruction")

	progress = _director_script.notify(progress, &"guide_found")
	_assert_step(progress, "open_social")
	progress = _director_script.notify(progress, &"social_opened")
	_assert_step(progress, "open_post")
	progress = _director_script.notify(progress, &"post_opened")
	_assert_step(progress, "collect_words")
	progress = _director_script.notify(progress, &"collect_word", {"amount": 3})
	_assert_step(progress, "open_notebook")
	progress = _director_script.notify(progress, &"notebook_opened")
	_assert_step(progress, "compose_sentence")
	progress = _director_script.notify(progress, &"sentence_composed")
	_assert_step(progress, "publish_sentence")
	progress = _director_script.notify(progress, &"sentence_published")
	_assert_step(progress, "complete")
	_assert_true(bool(progress.get("is_complete", false)), "doctor conversation should complete the tutorial")
	_assert_eq((progress.get("completed_step_ids", []) as Array).size(), 7, "all action steps should be recorded")


func test_collect_word_requires_three_events() -> void:
	var progress := _progress_at_collect_words()
	progress = _director_script.notify(progress, &"collect_word")
	_assert_step(progress, "collect_words")
	_assert_eq(_event_count(progress, "collect_word"), 1, "the first collected word should be counted")
	_assert_eq(int(_director_script.current_step(progress).get("remaining_count", -1)), 2, "two more words should remain")

	progress = _director_script.notify(progress, &"collect_word")
	_assert_step(progress, "collect_words")
	_assert_eq(_event_count(progress, "collect_word"), 2, "the second collected word should be counted")

	progress = _director_script.notify(progress, &"collect_word")
	_assert_step(progress, "open_notebook")
	_assert_eq(_event_count(progress, "collect_word"), 3, "the third collected word should satisfy the step")


func test_skip_finishes_without_mutating_input() -> void:
	var progress: Dictionary = _director_script.initial_progress()
	progress = _director_script.notify(progress, &"guide_found")
	var before_skip := progress.duplicate(true)
	var skipped: Dictionary = _director_script.skip(progress)
	_assert_eq(progress, before_skip, "skip should return new progress instead of mutating the caller's dictionary")
	_assert_step(skipped, "complete")
	_assert_true(bool(skipped.get("skipped", false)), "skip should retain an explicit skipped marker")
	_assert_true(bool(skipped.get("is_complete", false)), "skipped tutorial should be terminal")
	_assert_eq(
		skipped.get("completed_step_ids", []),
		["find_guide"],
		"skip should preserve genuinely completed steps instead of fabricating completion"
	)


func test_replay_returns_to_first_step() -> void:
	var progress: Dictionary = _director_script.skip(_director_script.initial_progress())
	var replayed: Dictionary = _director_script.replay(progress)
	_assert_step(replayed, "find_guide")
	_assert_true(not bool(replayed.get("skipped", true)), "replay should clear the skipped marker")
	_assert_true(not bool(replayed.get("is_complete", true)), "replay should reactivate the tutorial")
	_assert_eq(replayed.get("completed_step_ids", []), [], "replay should clear completed steps")
	_assert_eq(replayed.get("event_counts", {}), {}, "replay should clear event counts")
	_assert_eq(int(replayed.get("replay_count", 0)), 1, "replay should increment its durable counter")
	var replayed_again: Dictionary = _director_script.replay(replayed)
	_assert_eq(int(replayed_again.get("replay_count", 0)), 2, "replay count should survive repeated practice runs")


func test_old_progress_is_normalized_and_serializable() -> void:
	var old_progress := {
		"step": "collect_words",
		"completed_steps": ["find_guide", "unknown_future_step"],
		"counts": {"collect_word": "2", "bad_count": -4},
		"replays": 2,
		"unrecognized_field": "discard me",
	}
	var normalized: Dictionary = _director_script.normalize_progress(old_progress)
	_assert_step(normalized, "collect_words")
	_assert_eq(
		normalized.get("completed_step_ids", []),
		["find_guide", "open_social", "open_post"],
		"a recognized old current step should infer the completed prefix"
	)
	_assert_eq(_event_count(normalized, "collect_word"), 2, "old event counts should load as integers")
	_assert_eq(_event_count(normalized, "bad_count"), 0, "negative old counters should clamp to zero")
	_assert_eq(int(normalized.get("replay_count", 0)), 2, "old replay counters should migrate")
	_assert_true(not normalized.has("unrecognized_field"), "normalization should emit only the stable schema")

	var encoded := JSON.stringify(normalized)
	var decoded: Variant = JSON.parse_string(encoded)
	_assert_true(decoded is Dictionary, "progress should survive JSON serialization")
	if decoded is Dictionary:
		var loaded: Dictionary = _director_script.normalize_progress(decoded as Dictionary)
		_assert_eq(loaded, normalized, "serialized progress should normalize back to the same data")
		loaded = _director_script.notify(loaded, &"collect_word")
		_assert_step(loaded, "open_notebook")

	var step: Dictionary = _director_script.current_step(normalized)
	_assert_true(not str(step.get("focus_target", "")).is_empty(), "current step should expose a focus target")
	_assert_true(not str(step.get("guide_line", "")).is_empty(), "current step should expose the guide line")
	_assert_true(not str(step.get("test_instruction", "")).is_empty(), "current step should expose an explicit playtest instruction")


func _progress_at_collect_words() -> Dictionary:
	var progress: Dictionary = _director_script.initial_progress()
	progress = _director_script.notify(progress, &"guide_found")
	progress = _director_script.notify(progress, &"social_opened")
	return _director_script.notify(progress, &"post_opened")


func _event_count(progress: Dictionary, event_id: String) -> int:
	var counts: Dictionary = progress.get("event_counts", {}) as Dictionary
	return int(counts.get(event_id, 0))


func _assert_step(progress: Dictionary, expected_step_id: String) -> void:
	var step: Dictionary = _director_script.current_step(progress)
	_assert_eq(str(step.get("id", "")), expected_step_id, "current tutorial step should be %s" % expected_step_id)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
