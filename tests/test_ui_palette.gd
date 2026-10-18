extends SceneTree
## UiPalette answers every role from the palette it is given; a gap or an unknown role is reported, never guessed.

const PaletteErrorLog = preload("res://tests/harness/palette_error_log.gd")

var _failures: Array[String] = []
var _errors := PaletteErrorLog.new()


func _init() -> void:
	OS.add_logger(_errors)
	_test_a_complete_palette_answers_without_errors()
	_test_a_missing_role_is_reported_and_falls_back_to_palette_1()
	_test_an_unknown_role_is_reported()
	OS.remove_logger(_errors)
	if _failures.is_empty():
		print("ui palette tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_a_complete_palette_answers_without_errors() -> void:
	_assert_eq(UiPalette.color(UiPalette.POLLUTION_PALETTE_5, "danger_stripe"), Color("0D1009"), "a complete palette should answer its own role")
	_assert_eq(UiPalette.color(UiPalette.PALETTE_1, "menu_bg"), Color("5DAE6B"), "palette 1 should answer its own role")
	_assert_eq(_errors.take(), [], "a complete palette should report nothing")


func _test_a_missing_role_is_reported_and_falls_back_to_palette_1() -> void:
	var partial := UiPalette.POLLUTION_PALETTE_5.duplicate()
	partial.erase("flash_text")
	_assert_eq(UiPalette.color(partial, "flash_text"), Color("9CFF24"), "a missing role should fall back to the same role in palette 1")
	var errors := _errors.take()
	_assert_eq(errors.size(), 1, "a missing role should be reported once")
	if errors.size() == 1:
		_assert_true(errors[0].contains("flash_text") and errors[0].contains("pollution_palette_5"), "the report should name the role and the palette: %s" % errors[0])
	_assert_eq(UiPalette.color({}, "ink"), Color("10140F"), "an empty palette should fall back to palette 1")
	_assert_eq(_errors.take().size(), 1, "an empty palette should report the missing role")


func _test_an_unknown_role_is_reported() -> void:
	UiPalette.color(UiPalette.PALETTE_1, "fixture_metal")
	var errors := _errors.take()
	_assert_eq(errors.size(), 1, "an unknown role should be reported once")
	if errors.size() == 1:
		_assert_true(errors[0].contains("fixture_metal"), "the report should name the unknown role: %s" % errors[0])
	UiPalette.color(UiPalette.PALETTE_1, "name")
	_assert_eq(_errors.take().size(), 1, "the palette name is not a color role")


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
