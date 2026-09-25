extends SceneTree
## Floor composer decides who stands on a tower floor. The roster is data only.

const FloorComposerScript = preload("res://scripts/world/floor_composer.gd")
const LanguageCorruptionContentScript = preload("res://scripts/narrative/language_corruption_content.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("floor composer tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_roster_entries_hold_only_id_and_kind()
	_test_floor_one_matches_current_population()
	_test_population_shrinks_and_floor_four_is_empty()
	_test_doll_id_comes_from_catalog()
	_test_pedestrian_ids_keep_floor_and_sequence()
	_test_catalog_display_names_sit_beside_the_roster()
	_test_host_does_not_call_floor_composer()


func _test_roster_entries_hold_only_id_and_kind() -> void:
	var composed: Dictionary = FloorComposerScript.compose({"tower_floor": 1, "day": 2})
	var roster: Array = composed.get("roster", [])
	_assert_true(not roster.is_empty(), "floor one should list the people who stand on the street")
	for person in roster:
		var record: Dictionary = person
		var keys := record.keys()
		keys.sort()
		_assert_eq(keys, ["id", "kind"], "each roster record should hold only id and kind")
		_assert_true(str(record.get("kind", "")) in ["key_npc", "npc", "doll"], "kind should be key_npc, npc, or doll")


func _test_floor_one_matches_current_population() -> void:
	var composed: Dictionary = FloorComposerScript.compose({"tower_floor": 1})
	var counts := _count_kinds(composed.get("roster", []))
	_assert_eq(int(counts.get("key_npc", 0)), 1, "floor one should keep its key resident")
	_assert_eq(int(counts.get("npc", 0)), 4, "floor one should keep four pedestrians")
	_assert_eq(int(counts.get("doll", 0)), 1, "floor one should keep its doll")


func _test_population_shrinks_and_floor_four_is_empty() -> void:
	var expected_npc_counts := [4, 3, 2, 0]
	for floor_index in expected_npc_counts.size():
		var floor_number := floor_index + 1
		var composed: Dictionary = FloorComposerScript.compose({"tower_floor": floor_number})
		var counts := _count_kinds(composed.get("roster", []))
		_assert_eq(int(counts.get("npc", 0)), expected_npc_counts[floor_index], "pedestrian count should follow the reduced floor sequence")
		var expects_residents := floor_number <= 3
		_assert_eq(int(counts.get("key_npc", 0)), 1 if expects_residents else 0, "key residents stay on the first three floors")
		_assert_eq(int(counts.get("doll", 0)), 1 if expects_residents else 0, "dolls stay on the first three floors")


func _test_doll_id_comes_from_catalog() -> void:
	for floor_number in [1, 2, 3]:
		var encounter: Dictionary = LanguageCorruptionContentScript.get_doll_encounter_for_floor(floor_number)
		var composed: Dictionary = FloorComposerScript.compose({"tower_floor": floor_number})
		var doll_id := ""
		for person in composed.get("roster", []):
			var record: Dictionary = person
			if str(record.get("kind", "")) == "doll":
				doll_id = str(record.get("id", ""))
		_assert_eq(doll_id, str(encounter.get("doll_id", "")), "doll id should come from the content catalog")


func _test_pedestrian_ids_keep_floor_and_sequence() -> void:
	var composed: Dictionary = FloorComposerScript.compose({"tower_floor": 2})
	var pedestrian_ids: Array[String] = []
	for person in composed.get("roster", []):
		var record: Dictionary = person
		if str(record.get("kind", "")) == "npc":
			pedestrian_ids.append(str(record.get("id", "")))
	_assert_eq(pedestrian_ids, ["npc_2_npc0", "npc_2_npc1", "npc_2_npc2"], "pedestrian ids should keep the floor and sequence")


func _test_catalog_display_names_sit_beside_the_roster() -> void:
	var composed: Dictionary = FloorComposerScript.compose({"tower_floor": 1})
	var roster: Array = composed.get("roster", [])
	for person in roster:
		var record: Dictionary = person
		_assert_true(not record.has("display_name") and not record.has("texture"), "images and display names stay out of the roster")
	var display_names: Dictionary = composed.get("display_names", {})
	var dialogue: Dictionary = LanguageCorruptionContentScript.get_key_npc_dialogue_for_floor(1)
	var encounter: Dictionary = LanguageCorruptionContentScript.get_doll_encounter_for_floor(1)
	_assert_eq(str(display_names.get("key_npc_1_keynpc", "")), str(dialogue.get("actor_label", "")), "the key resident name should be looked up beside the roster")
	_assert_eq(str(display_names.get(str(encounter.get("doll_id", "")), "")), str(encounter.get("actor_label", "")), "the doll name should be looked up beside the roster")
	_assert_eq(str(display_names.get("npc_1_npc0", "")), "迟到者", "pedestrian names should sit beside the roster")


func _test_host_does_not_call_floor_composer() -> void:
	var host_source := FileAccess.get_file_as_string("res://scripts/babel_meme_game.gd")
	_assert_true(not host_source.contains("floor_composer"), "the host should not call the Floor composer")
	_assert_true(host_source.contains("nearby_outcome") and host_source.contains("pose"), "the host should keep interaction outcome and look pose")


func _count_kinds(roster: Array) -> Dictionary:
	var counts := {"key_npc": 0, "npc": 0, "doll": 0}
	for person in roster:
		var kind := str((person as Dictionary).get("kind", ""))
		counts[kind] = int(counts.get(kind, 0)) + 1
	return counts


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
