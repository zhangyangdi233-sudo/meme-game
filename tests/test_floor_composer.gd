extends SceneTree
## Floor composer decides who stands on a tower floor. The roster is id + kind only.

const FloorComposerScript = preload("res://scripts/game/floor_composer.gd")
const ContentScript = preload("res://scripts/narrative/language_corruption_content.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_floor_one_matches_previous_cast()
	_test_higher_floors_shrink_the_cast()
	_test_roster_entries_hold_only_id_and_kind()
	_test_display_names_sit_beside_the_roster()
	_test_hidden_floor_has_nobody()
	_test_prerequisite_item_is_one_id_and_kind()
	_test_hidden_floor_item_list_is_empty()
	_test_street_props_stay_off_the_item_list()
	if _failures.is_empty():
		print("floor composer tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_floor_one_matches_previous_cast() -> void:
	var composed := FloorComposerScript.compose({"day_progress": {"tower_floor": 1, "day": 1}})
	var people: Array = composed.get("people", [])
	_assert_eq(people.size(), 6, "floor one should keep the key resident, the doll, and four pedestrians")
	_assert_person(people, 0, "key_npc_1_keynpc", "key_npc")
	_assert_person(people, 1, "doll_small_moon", "doll")
	_assert_person(people, 2, "npc_1_npc0", "npc")
	_assert_person(people, 3, "npc_1_npc1", "npc")
	_assert_person(people, 4, "npc_1_npc2", "npc")
	_assert_person(people, 5, "npc_1_npc3", "npc")
	var names: Dictionary = composed.get("display_names", {})
	_assert_eq(str(names.get("key_npc_1_keynpc", "")), "护灯人", "key resident name should come from the content catalog")
	_assert_eq(str(names.get("doll_small_moon", "")), "缝线布偶", "doll name should come from the content catalog")
	_assert_eq(str(names.get("npc_1_npc0", "")), "迟到者", "first pedestrian should keep the existing label")
	_assert_eq(str(names.get("npc_1_npc3", "")), "无名信徒", "fourth pedestrian should keep the existing label")


func _test_higher_floors_shrink_the_cast() -> void:
	var floor_two: Array = FloorComposerScript.compose({"day_progress": {"tower_floor": 2}}).get("people", [])
	_assert_eq(_ids_of_kind(floor_two, "npc").size(), 3, "floor two should keep three pedestrians")
	_assert_eq(_ids_of_kind(floor_two, "doll"), ["doll_window_memory"], "floor two doll id should come from the catalog")
	_assert_eq(_ids_of_kind(floor_two, "key_npc"), ["key_npc_2_keynpc"], "floor two should keep one key resident")
	var floor_three: Array = FloorComposerScript.compose({"day_progress": {"tower_floor": 3}}).get("people", [])
	_assert_eq(_ids_of_kind(floor_three, "npc").size(), 2, "floor three should keep two pedestrians")
	_assert_eq(str(_ids_of_kind(floor_three, "doll")[0]), str(ContentScript.get_doll_encounter_for_floor(3).get("doll_id", "")), "floor three doll id should match the catalog doll_id")
	_assert_eq(_ids_of_kind(floor_three, "npc"), ["npc_3_npc0", "npc_3_npc1"], "pedestrian ids should keep the floor and sequence form")


func _test_roster_entries_hold_only_id_and_kind() -> void:
	var people: Array = FloorComposerScript.compose({"day_progress": {"tower_floor": 1}}).get("people", [])
	for person in people:
		var entry: Dictionary = person
		var keys: Array = entry.keys()
		keys.sort()
		_assert_eq(keys, ["id", "kind"], "a roster entry should hold only id and kind")
		_assert_true(str(entry.get("kind", "")) in ["key_npc", "npc", "doll"], "kind should be key_npc, npc, or doll")


func _test_display_names_sit_beside_the_roster() -> void:
	var composed := FloorComposerScript.compose({"day_progress": {"tower_floor": 2}})
	var people: Array = composed.get("people", [])
	for person in people:
		_assert_true(not (person as Dictionary).has("display_name"), "display names should not live inside the roster")
		_assert_true(not (person as Dictionary).has("texture"), "images should not live inside the roster")
	var names: Dictionary = composed.get("display_names", {})
	_assert_eq(str(names.get("key_npc_2_keynpc", "")), "两醒者", "the composer should look up the key resident label")
	for person in people:
		_assert_true(names.has(str((person as Dictionary).get("id", ""))), "each person should have a display name beside the roster")


func _test_prerequisite_item_is_one_id_and_kind() -> void:
	var composed := FloorComposerScript.compose({"day_progress": {"tower_floor": 1}, "locale": "zh"})
	var items: Array = composed.get("items", [])
	_assert_eq(items.size(), 1, "floor one should list one prerequisite item")
	var entry: Dictionary = items[0]
	var keys: Array = entry.keys()
	keys.sort()
	_assert_eq(keys, ["id", "kind"], "an item entry should hold only id and kind")
	_assert_eq(str(entry.get("id", "")), "artifact_named_lamp_tag", "floor one item id should come from the catalog")
	_assert_eq(str(entry.get("kind", "")), "prerequisite", "the pickup should be a prerequisite")
	_assert_true(not entry.has("label"), "the display name should not live inside the item list")
	_assert_true(not entry.has("texture"), "images should not live inside the item list")
	var names: Dictionary = composed.get("display_names", {})
	_assert_eq(str(names.get("artifact_named_lamp_tag", "")), "写着“小月亮”的旧名牌", "the item label should sit beside the list")
	var floor_two: Array = FloorComposerScript.compose({"day_progress": {"tower_floor": 2}, "locale": "en"}).get("items", [])
	_assert_eq(str((floor_two[0] as Dictionary).get("id", "")), "artifact_reversed_tape", "floor two should keep its catalog item")
	var floor_three: Array = FloorComposerScript.compose({"day_progress": {"tower_floor": 3}}).get("items", [])
	_assert_eq(str((floor_three[0] as Dictionary).get("id", "")), "artifact_missing_subject_page", "floor three should keep its catalog item")


func _test_hidden_floor_item_list_is_empty() -> void:
	var items: Array = FloorComposerScript.compose({"day_progress": {"tower_floor": 4, "day": 9}}).get("items", [])
	_assert_eq(items.size(), 0, "hidden floor four should place no prerequisite item")


func _test_street_props_stay_off_the_item_list() -> void:
	var items: Array = FloorComposerScript.compose({"day_progress": {"tower_floor": 3}}).get("items", [])
	for item_data in items:
		var kind := str((item_data as Dictionary).get("kind", ""))
		_assert_true(kind == "prerequisite", "street props should not enter the item list")
		var item_id := str((item_data as Dictionary).get("id", ""))
		_assert_true(item_id != "water_cooler" and item_id != "street_lamp", "street furniture should stay part of the street")


func _test_hidden_floor_has_nobody() -> void:
	var composed := FloorComposerScript.compose({"day_progress": {"tower_floor": 4, "day": 9}})
	_assert_eq((composed.get("people", []) as Array).size(), 0, "hidden floor four should place nobody")
	_assert_eq((composed.get("display_names", {}) as Dictionary).size(), 0, "hidden floor four should have no display names")


func _ids_of_kind(people: Array, kind: String) -> Array:
	var ids: Array = []
	for person in people:
		if str((person as Dictionary).get("kind", "")) == kind:
			ids.append(str((person as Dictionary).get("id", "")))
	return ids


func _assert_person(people: Array, index: int, id: String, kind: String) -> void:
	if index >= people.size():
		_failures.append("missing person %s" % id)
		return
	var entry: Dictionary = people[index]
	_assert_eq(str(entry.get("id", "")), id, "person %d id" % index)
	_assert_eq(str(entry.get("kind", "")), kind, "person %d kind" % index)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
