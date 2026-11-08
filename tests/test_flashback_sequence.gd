extends SceneTree
## 60% 污染闪回时间线回归测试:相位表连续性、WCAG 闪烁预算、确定性(无随机)。
## 主场景 overlay 契约见 test_flashback_sequence_scene.gd。

var _failures: Array[String] = []


func _init() -> void:
	_check_timeline_data()
	_check_determinism_source()
	if _failures.is_empty():
		print("flashback sequence tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check_timeline_data() -> void:
	var director_script := load("res://scripts/ui/pollution_flashback_director.gd") as GDScript
	_assert_true(director_script != null, "flashback director script should load")
	if director_script == null:
		return
	var phases: Array = director_script.PHASES
	_assert_true(phases.size() == 9, "flashback should keep the eight-beat structure plus freeze (9 phases)")

	var cursor := 0.0
	for phase in phases:
		_assert_near(float(phase["start"]), cursor, 0.001, "phase %s should start where the previous one ends" % phase["id"])
		var duration := float(phase["duration"])
		_assert_true(duration >= 0.12, "phase %s should last at least 120ms so it stays readable, not subliminal" % phase["id"])
		cursor += duration
	_assert_near(cursor, float(director_script.TOTAL_DURATION), 0.001, "TOTAL_DURATION should equal the sum of phase durations")
	_assert_true(cursor >= 3.0 and cursor <= 4.5, "flashback should run between 3.0 and 4.5 seconds")

	var flip_times: Array[float] = []
	for index in range(1, phases.size()):
		if int(phases[index]["luminance"]) != int(phases[index - 1]["luminance"]):
			flip_times.append(float(phases[index]["start"]))
	var worst := 0
	for anchor in flip_times:
		var count := 0
		for other in flip_times:
			if other - anchor >= 0.0 and other - anchor < 1.0:
				count += 1
		worst = maxi(worst, count)
	_assert_true(worst <= 3, "any rolling 1s window should contain at most 3 luminance flips (WCAG 2.2), got %d" % worst)
	_assert_true(int(director_script.max_luminance_flips_in_window(1.0)) <= 3, "director helper should agree the flash budget holds")

	for phase in phases:
		if str(phase["id"]).begins_with("black_gap"):
			_assert_true(float(phase["duration"]) >= 0.15, "black gaps should be reading punctuation (>=150ms), not strobe")

	var card_flash := float(director_script.UNREGISTERED_CARD_FLASH)
	_assert_true(card_flash >= 0.06 and card_flash <= 0.2, "unregistered card flash should stay between 60ms and 200ms")


func _check_determinism_source() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/pollution_flashback_director.gd")
	_assert_true(source.length() > 0, "director source should be readable")
	for forbidden in ["randf", "randi", "randomize(", "shuffle("]:
		_assert_true(not source.contains(forbidden), "flashback director must be deterministic; found forbidden call: %s" % forbidden)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_near(value: float, expected: float, tolerance: float, message: String) -> void:
	if absf(value - expected) > tolerance:
		_failures.append("%s (got %f, expected %f)" % [message, value, expected])
