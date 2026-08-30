extends SceneTree

const CatalogScript = preload("res://scripts/game/narrative_session_catalog.gd")

var _failures: Array[String] = []


func _init() -> void:
	test_catalog_loads_and_validates()
	test_prologue_and_epilogue_locales()
	test_doctor_and_prerequisite_lookup()
	test_ending_choices_and_unknown_locale_fallback()
	test_defensive_copies()
	test_moved_copy_leaves_meme_game_state()
	if _failures.is_empty():
		print("narrative session catalog tests passed")
		quit(0)
	else:
		for failure in _failures:
			print("narrative session catalog test failure: %s" % failure)
			push_error(failure)
		quit(1)


func test_catalog_loads_and_validates() -> void:
	var validation: Dictionary = CatalogScript.validate()
	_assert_true(bool(validation.get("ok", false)), "catalog should validate: %s" % str(validation.get("problems", [])))


func test_prologue_and_epilogue_locales() -> void:
	var zh_prologue: Array = CatalogScript.prologue_lines("zh")
	_assert_eq(zh_prologue.size(), 7, "prologue should keep seven authored lines")
	_assert_eq(str(zh_prologue[0]), "（先确认一件事。你手里拿着什么？）", "zh prologue should keep the MemeGameState source line")
	var en_prologue: Array = CatalogScript.prologue_lines("en")
	_assert_eq(str(en_prologue[1]), "A phone. No signal. It was already lit when I woke up.", "en prologue should not go through the UI catalog")
	var ja_epilogue: Array = CatalogScript.epilogue_lines("ja")
	_assert_eq(ja_epilogue.size(), 5, "epilogue should keep five authored lines")
	_assert_eq(str(ja_epilogue[0]), "どの投稿も、賢者は最上階にいると言う。最上階には誰もいない。", "ja epilogue should use the catalog locale field")


func test_doctor_and_prerequisite_lookup() -> void:
	var doctor: Dictionary = CatalogScript.doctor_dialogue(1, "en")
	_assert_eq(str(doctor.get("id", "")), "doctor_floor_1", "doctor lookup should expose a stable id")
	_assert_eq(str(doctor.get("line", "")), "Say that line again. Do not explain it for me.", "doctor line should resolve from the content catalog")
	var item: Dictionary = CatalogScript.prerequisite_item(1, "en")
	_assert_eq(str(item.get("id", "")), "artifact_named_lamp_tag", "prerequisite lookup should keep the authored item id")
	_assert_eq(str(item.get("label", "")), "An Old Nameplate Marked 'Little Moon'", "prerequisite label should resolve from the content catalog")
	_assert_true(str(item.get("location_hint", "")).begins_with("Follow the main road."), "prerequisite hint should resolve from the content catalog")


func test_ending_choices_and_unknown_locale_fallback() -> void:
	var choices: Array = CatalogScript.ending_language_choices("en")
	_assert_eq(choices.size(), 4, "ending language should keep four authored choices")
	_assert_eq(str((choices[0] as Dictionary).get("id", "")), "blank", "first ending choice id should remain blank")
	_assert_eq(str((choices[0] as Dictionary).get("label", "")), "Blank", "ending labels should resolve from the content catalog")
	var fallback: Dictionary = CatalogScript.ending_language_choice("silence", "fr")
	_assert_eq(str(fallback.get("output", "")), "……", "unknown locales should fall back to zh")


func test_defensive_copies() -> void:
	var item_a: Dictionary = CatalogScript.prerequisite_item(2, "zh")
	var item_b: Dictionary = CatalogScript.prerequisite_item(2, "zh")
	item_a["label"] = "mutated"
	_assert_ne(str(item_b.get("label", "")), "mutated", "prerequisite lookups should return defensive copies")
	var lines_a: Array = CatalogScript.prologue_lines("zh")
	var lines_b: Array = CatalogScript.prologue_lines("zh")
	lines_a[0] = "mutated"
	_assert_ne(str(lines_b[0]), "mutated", "prologue lookups should return defensive copies")


func test_moved_copy_leaves_meme_game_state() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/meme_game_state.gd")
	for literal in [
		"（先确认一件事。你手里拿着什么？）",
		"把刚才那句再说一遍。不要替它解释。",
		"写着“小月亮”的旧名牌",
		"所有帖子都说智者住在顶楼。顶楼没有人。",
	]:
		_assert_true(not source.contains(literal), "MemeGameState should not keep moved content-catalog copy: %s" % literal)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func _assert_ne(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		_failures.append("%s (expected value different from %s)" % [message, str(expected)])
