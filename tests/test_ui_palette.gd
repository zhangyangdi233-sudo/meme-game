extends SceneTree
## UiPalette answers every role from the palette it is given; a gap or an unknown role is reported, never guessed.

const PaletteErrorLog = preload("res://tests/harness/palette_error_log.gd")
const EXPECTED_ROLES := ["accent", "bg", "flash_text", "ink", "muted", "surface", "text"]
const LAYOUT_SCENES := [
	"res://scenes/ui/main_menu.tscn",
	"res://scenes/ui/dialog.tscn",
	"res://scenes/ui/dialog_debug_panel.tscn",
]

var _failures: Array[String] = []
var _errors := PaletteErrorLog.new()


func _init() -> void:
	OS.add_logger(_errors)
	_test_a_complete_palette_answers_without_errors()
	_test_a_missing_role_is_reported_and_falls_back_to_palette_1()
	_test_an_unknown_role_is_reported()
	_test_both_palettes_define_the_same_roles()
	_test_layout_scenes_use_only_known_roles()
	_test_void_and_outline_are_fixed_colors_not_roles()
	OS.remove_logger(_errors)
	if _failures.is_empty():
		print("ui palette tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_a_complete_palette_answers_without_errors() -> void:
	_assert_eq(UiPalette.color(UiPalette.POLLUTION_PALETTE_5, "accent"), Color("2F6B1F"), "a complete palette should answer its own role")
	_assert_eq(UiPalette.color(UiPalette.PALETTE_1, "flash_text"), Color("9CFF24"), "palette 1 should answer its own role")
	_assert_eq(_errors.take(), [], "a complete palette should report nothing")


func _test_both_palettes_define_the_same_roles() -> void:
	for palette in [UiPalette.PALETTE_1, UiPalette.POLLUTION_PALETTE_5]:
		var roles: Array = palette.keys()
		roles.erase("name")
		roles.sort()
		_assert_eq(roles, EXPECTED_ROLES, "%s should define exactly the expected roles" % palette["name"])


func _test_layout_scenes_use_only_known_roles() -> void:
	for path in LAYOUT_SCENES:
		var root := (load(path) as PackedScene).instantiate()
		_assert_true(root is PaletteSceneRoot, "%s should have a PaletteSceneRoot root" % path)
		if root is PaletteSceneRoot:
			_assert_eq((root as PaletteSceneRoot).palette_role_errors(), PackedStringArray(), "%s should only name palette roles" % path)
		root.free()


func _test_void_and_outline_are_fixed_colors_not_roles() -> void:
	_assert_eq(UiPalette.VOID, Color("000000"), "VOID should be true black")
	_assert_eq(UiPalette.OUTLINE, Color("050705"), "OUTLINE should be the near-black outline")
	for constant_name in ["VOID", "OUTLINE", "void", "outline"]:
		_assert_true(not UiPalette.has_role(constant_name), "%s should not be a palette role" % constant_name)


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
