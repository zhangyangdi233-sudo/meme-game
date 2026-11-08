extends SceneTree

const PollutionStageScript = preload("res://scripts/world/pollution_stage.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("pollution stage tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_music_db_curve()
	_test_menu_tiers()
	_test_palette_key()
	_test_corruption_fields()
	_test_corrupt_sentence_ui()
	_test_corrupt_sentence_reality()
	_test_vhs_fields()


func _test_music_db_curve() -> void:
	_assert_float_eq(_stage(0)["music_db"], -60.0, "quiet pollution should duck pollution ambience")
	_assert_float_eq(_stage(40)["music_db"], -60.0, "music threshold should stay quiet through 40")
	_assert_float_eq(_stage(41)["music_db"], -42.0, "music should enter the first ramp at 41")
	_assert_float_eq(_stage(60)["music_db"], -24.0, "music should finish the first ramp at 60")
	_assert_float_eq(_stage(80)["music_db"], -10.0, "music should finish the second ramp at 80")
	_assert_float_eq(_stage(100)["music_db"], -3.0, "max pollution should reach the loudest ambience target")


func _test_menu_tiers() -> void:
	_assert_eq(_stage(0)["menu_tier"], 0, "clean menu copy below 25")
	_assert_eq(_stage(24)["menu_tier"], 0, "menu tier should stay clean at 24")
	_assert_eq(_stage(25)["menu_tier"], 1, "menu tier should shift at 25")
	_assert_eq(_stage(59)["menu_tier"], 1, "menu tier should stay mid through 59")
	_assert_eq(_stage(60)["menu_tier"], 2, "menu tier should corrupt at 60")


func _test_palette_key() -> void:
	_assert_eq(_stage(59)["palette_key"], "palette_1", "palette should stay default below flashback threshold")
	_assert_eq(_stage(60)["palette_key"], "pollution_palette_5", "palette should swap at 60")


func _test_corruption_fields() -> void:
	_assert_false(bool(_stage(34)["corrupt_active"]), "text corruption should stay off below 35")
	_assert_true(bool(_stage(35)["corrupt_active"]), "text corruption should activate at 35")
	_assert_eq(_stage(60)["corrupt_interval"], 4, "corruption interval should follow pollution / 14")
	_assert_eq(_stage(35)["corrupt_interval"], 6, "ui corruption interval at 35 should use the 8/14 divisor")
	_assert_eq(PollutionStageScript._reality_corrupt_interval(35), 7, "reality interval at 35 intentionally uses 9/12 divisor")
	_assert_eq(_stage(60)["day"], 0, "day should default to zero when omitted")


func _test_corrupt_sentence_ui() -> void:
	var replacements := ["A", "B", "C", "D"]
	_assert_eq(
		PollutionStageScript.corrupt_sentence_ui("clean text", 34, 0, "zh", replacements),
		"clean text",
		"ui corruption should pass through below threshold",
	)
	_assert_eq(
		PollutionStageScript.corrupt_sentence_ui("一二三四五六", 60, 0, "zh", replacements),
		"A二三四A六",
		"ui corruption should replace every fourth CJK character at pollution 60",
	)
	_assert_eq(
		PollutionStageScript.corrupt_sentence_ui("one two three four five", 60, 0, "en", replacements),
		"A two three four A",
		"ui english corruption should replace whole words on the ui interval",
	)


func _test_corrupt_sentence_reality() -> void:
	_assert_eq(
		PollutionStageScript.corrupt_sentence_reality("doctor says hello", 34, 0),
		"doctor says hello",
		"reality corruption should pass through below threshold",
	)
	_assert_eq(
		PollutionStageScript.corrupt_sentence_reality("abcdefghij", 60, 0),
		"■bcd//fgh□j",
		"reality corruption should use sentence markers and the reality interval",
	)


func _test_vhs_fields() -> void:
	_assert_float_eq(_stage(0)["vhs_pollution"], 0.0, "vhs pollution ratio should start at zero")
	_assert_float_eq(_stage(100)["vhs_pollution"], 1.0, "vhs pollution ratio should cap at one")
	_assert_float_eq(_stage(60)["vhs_intensity"], 0.58 + minf(0.22, 60.0 * 0.0022), "vhs intensity should follow the continuous curve")


func _stage(pollution: int, day: int = 0) -> Dictionary:
	return PollutionStageScript.stage(pollution, day)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_false(value: bool, message: String) -> void:
	if value:
		_failures.append(message)


func _assert_float_eq(actual: float, expected: float, message: String) -> void:
	if absf(actual - expected) > 0.001:
		_failures.append("%s (expected %.3f, got %.3f)" % [message, expected, actual])
