extends SceneTree
## Locale font: the formal typeface each game language uses where the pixel font is not (Dialog, hold to restart hint).

const LocaleFontScript = preload("res://scripts/ui/locale_font.gd")
const FONT_DIR := "res://assets/fonts/"

var _failures: Array[String] = []


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("locale font tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_each_language_gets_its_own_face()
	_test_english_is_the_bold_instance()
	_test_an_unknown_locale_falls_back_to_simplified_chinese()
	_test_the_same_font_comes_back_for_the_same_locale()
	_test_licenses_and_provenance_ship_with_the_fonts()


func _test_each_language_gets_its_own_face() -> void:
	# The static Noto CJK files carry the weight in their family name; Medium is weight 500.
	var expected := {
		"en": ["Roboto Condensed", 0],
		"zh": ["Noto Sans SC Medium", 500],
		"ja": ["Noto Sans JP Medium", 500],
	}
	for locale in expected:
		var font: Font = LocaleFontScript.font(locale)
		_assert_true(font != null, "%s should have a font" % locale)
		if font == null:
			continue
		_assert_eq(font.get_font_name(), expected[locale][0], "%s should use %s" % [locale, expected[locale][0]])
		if int(expected[locale][1]) > 0:
			_assert_eq(font.get_font_weight(), expected[locale][1], "%s should use the Medium weight" % locale)


func _test_english_is_the_bold_instance() -> void:
	var font := LocaleFontScript.font("en") as FontVariation
	_assert_true(font != null, "English should be an instance of the Roboto Condensed weight axis")
	if font == null:
		return
	_assert_eq(font.variation_opentype.get(TextServerManager.get_primary_interface().name_to_tag("wght")), 700, "English should be set to the Bold weight")


func _test_an_unknown_locale_falls_back_to_simplified_chinese() -> void:
	_assert_true(LocaleFontScript.font("fr") == LocaleFontScript.font("zh"), "an unknown locale should use the default language's font")


func _test_the_same_font_comes_back_for_the_same_locale() -> void:
	_assert_true(LocaleFontScript.font("ja") == LocaleFontScript.font("ja"), "a language's font should be built once and reused")
	_assert_true(LocaleFontScript.font("ja") != LocaleFontScript.font("zh"), "Chinese and Japanese should not share a face")


func _test_licenses_and_provenance_ship_with_the_fonts() -> void:
	for license in ["RobotoCondensed-OFL.txt", "NotoSansCJK-OFL.txt"]:
		var path: String = FONT_DIR + license
		_assert_true(FileAccess.file_exists(path), "%s should ship with the fonts" % license)
		if FileAccess.file_exists(path):
			_assert_true(FileAccess.get_file_as_string(path).contains("SIL Open Font License"), "%s should hold the OFL text" % license)
	var provenance := FileAccess.get_file_as_string(FONT_DIR + "FONT_PROVENANCE.md")
	for name in ["Roboto Condensed", "Noto Sans SC", "Noto Sans JP", "RobotoCondensed-OFL.txt", "NotoSansCJK-OFL.txt"]:
		_assert_true(provenance.contains(name), "the font provenance should record %s" % name)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
