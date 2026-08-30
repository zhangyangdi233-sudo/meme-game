class_name NarrativeSessionCatalog
extends RefCounted
## Loads authored session narrative (prologue, epilogue, doctor, prerequisites, ending)
## from JSON. Callers look up by id and locale; JSON is read only through ContentJson.

const ContentJsonScript = preload("res://framework/content_json.gd")
const CATALOG_PATH := "res://content/narrative_session.json"
const SUPPORTED_LOCALES := ["zh", "ja", "en"]


static func load_catalog(path: String = CATALOG_PATH) -> Dictionary:
	var catalog: Dictionary = ContentJsonScript.load_dictionary_cached(path, "NarrativeSessionCatalog")
	if catalog.is_empty():
		return {
			"_path": path,
			"prologue": [],
			"epilogue": [],
			"doctor": [],
			"prerequisite_items": [],
			"ending_language_choices": [],
		}
	catalog["_path"] = path
	return catalog


static func prologue_lines(locale_code: String = "zh", path: String = CATALOG_PATH) -> Array:
	return _localized_line_list(load_catalog(path).get("prologue", []), locale_code)


static func epilogue_lines(locale_code: String = "zh", path: String = CATALOG_PATH) -> Array:
	return _localized_line_list(load_catalog(path).get("epilogue", []), locale_code)


static func doctor_dialogue(floor_number: int, locale_code: String = "zh", path: String = CATALOG_PATH) -> Dictionary:
	var wanted_floor := clampi(floor_number, 1, 4)
	for entry_data in load_catalog(path).get("doctor", []):
		if not entry_data is Dictionary:
			continue
		var entry: Dictionary = entry_data
		if int(entry.get("floor", 0)) != wanted_floor:
			continue
		return {
			"id": str(entry.get("id", "")),
			"line": _text(entry.get("line", {}), locale_code),
			"result": _text(entry.get("result", {}), locale_code),
		}
	if wanted_floor != 1:
		return doctor_dialogue(1, locale_code, path)
	return {}


static func prerequisite_item(floor_number: int, locale_code: String = "zh", path: String = CATALOG_PATH) -> Dictionary:
	var wanted_floor := clampi(floor_number, 1, 3)
	for entry_data in load_catalog(path).get("prerequisite_items", []):
		if not entry_data is Dictionary:
			continue
		var entry: Dictionary = entry_data
		if int(entry.get("floor", 0)) != wanted_floor:
			continue
		return {
			"id": str(entry.get("id", "")),
			"label": _text(entry.get("label", {}), locale_code),
			"location_hint": _text(entry.get("location_hint", {}), locale_code),
		}
	return {}


static func prerequisite_item_ids(path: String = CATALOG_PATH) -> Array[String]:
	var ids: Array[String] = []
	for entry_data in load_catalog(path).get("prerequisite_items", []):
		if not entry_data is Dictionary:
			continue
		var item_id := str((entry_data as Dictionary).get("id", ""))
		if not item_id.is_empty():
			ids.append(item_id)
	return ids


static func ending_language_choices(locale_code: String = "zh", path: String = CATALOG_PATH) -> Array:
	var choices: Array = []
	for entry_data in load_catalog(path).get("ending_language_choices", []):
		if not entry_data is Dictionary:
			continue
		var localized := _localized_ending_choice(entry_data, locale_code)
		if not str(localized.get("id", "")).is_empty():
			choices.append(localized)
	return choices


static func ending_language_choice(choice_id: String, locale_code: String = "zh", path: String = CATALOG_PATH) -> Dictionary:
	var wanted_id := choice_id.strip_edges()
	if wanted_id.is_empty():
		return {}
	for entry_data in load_catalog(path).get("ending_language_choices", []):
		if not entry_data is Dictionary:
			continue
		if str((entry_data as Dictionary).get("id", "")) != wanted_id:
			continue
		return _localized_ending_choice(entry_data, locale_code)
	return {}


static func has_ending_language_choice(choice_id: String, path: String = CATALOG_PATH) -> bool:
	return not ending_language_choice(choice_id, "zh", path).is_empty()


static func validate(path: String = CATALOG_PATH) -> Dictionary:
	var problems: Array[String] = []
	var catalog := load_catalog(path)
	_validate_line_list(catalog.get("prologue", []), "prologue", 7, problems)
	_validate_line_list(catalog.get("epilogue", []), "epilogue", 5, problems)
	var doctor_floors: Array[int] = []
	for entry_data in catalog.get("doctor", []):
		if not entry_data is Dictionary:
			problems.append("doctor entry is not an object")
			continue
		var entry: Dictionary = entry_data
		var doctor_id := str(entry.get("id", ""))
		var floor_number := int(entry.get("floor", 0))
		if doctor_id.is_empty():
			problems.append("doctor entry missing id")
		if floor_number < 1 or floor_number > 4:
			problems.append("doctor %s has invalid floor" % doctor_id)
		elif floor_number in doctor_floors:
			problems.append("duplicate doctor floor: %d" % floor_number)
		else:
			doctor_floors.append(floor_number)
		_validate_localized_field(entry.get("line", {}), "doctor %s line" % doctor_id, problems)
		_validate_localized_field(entry.get("result", {}), "doctor %s result" % doctor_id, problems)
	if doctor_floors.size() != 4:
		problems.append("doctor catalog should contain four floors")
	var item_floors: Array[int] = []
	var item_ids: Array[String] = []
	for entry_data in catalog.get("prerequisite_items", []):
		if not entry_data is Dictionary:
			problems.append("prerequisite entry is not an object")
			continue
		var entry: Dictionary = entry_data
		var item_id := str(entry.get("id", ""))
		var floor_number := int(entry.get("floor", 0))
		if item_id.is_empty():
			problems.append("prerequisite entry missing id")
		elif item_id in item_ids:
			problems.append("duplicate prerequisite id: %s" % item_id)
		else:
			item_ids.append(item_id)
		if floor_number < 1 or floor_number > 3:
			problems.append("prerequisite %s has invalid floor" % item_id)
		elif floor_number in item_floors:
			problems.append("duplicate prerequisite floor: %d" % floor_number)
		else:
			item_floors.append(floor_number)
		_validate_localized_field(entry.get("label", {}), "prerequisite %s label" % item_id, problems)
		_validate_localized_field(entry.get("location_hint", {}), "prerequisite %s location_hint" % item_id, problems)
	if item_floors.size() != 3:
		problems.append("prerequisite catalog should contain three floors")
	var choice_ids: Array[String] = []
	for entry_data in catalog.get("ending_language_choices", []):
		if not entry_data is Dictionary:
			problems.append("ending choice is not an object")
			continue
		var entry: Dictionary = entry_data
		var choice_id := str(entry.get("id", ""))
		if choice_id.is_empty():
			problems.append("ending choice missing id")
		elif choice_id in choice_ids:
			problems.append("duplicate ending choice id: %s" % choice_id)
		else:
			choice_ids.append(choice_id)
		_validate_localized_field(entry.get("label", {}), "ending %s label" % choice_id, problems)
		_validate_localized_field(entry.get("output", {}), "ending %s output" % choice_id, problems)
	if choice_ids.size() != 4:
		problems.append("ending language should contain four choices")
	return {"ok": problems.is_empty(), "problems": problems}


static func _localized_line_list(entries: Variant, locale_code: String) -> Array:
	var lines: Array = []
	for entry_data in ContentJsonScript.duplicate_array(entries):
		if entry_data is Dictionary:
			lines.append(_text(entry_data, locale_code))
	return lines


static func _localized_ending_choice(entry: Dictionary, locale_code: String) -> Dictionary:
	return {
		"id": str(entry.get("id", "")),
		"label": _text(entry.get("label", {}), locale_code),
		"output": _text(entry.get("output", {}), locale_code),
	}


static func _text(localized: Variant, locale_code: String) -> String:
	if not localized is Dictionary:
		return str(localized)
	var locale := _normalize_locale(locale_code)
	var value := str((localized as Dictionary).get(locale, ""))
	if value.is_empty() and locale != "zh":
		return str((localized as Dictionary).get("zh", ""))
	return value


static func _normalize_locale(locale_code: String) -> String:
	var normalized := locale_code.to_lower().replace("-", "_")
	if normalized.begins_with("ja"):
		return "ja"
	if normalized.begins_with("en"):
		return "en"
	if normalized.begins_with("zh"):
		return "zh"
	return "zh"


static func _validate_line_list(entries: Variant, label: String, expected_count: int, problems: Array[String]) -> void:
	if typeof(entries) != TYPE_ARRAY:
		problems.append("%s must be an array" % label)
		return
	var ids: Array[String] = []
	for entry_data in entries:
		if not entry_data is Dictionary:
			problems.append("%s entry is not an object" % label)
			continue
		var entry: Dictionary = entry_data
		var line_id := str(entry.get("id", ""))
		if line_id.is_empty():
			problems.append("%s entry missing id" % label)
		elif line_id in ids:
			problems.append("duplicate %s id: %s" % [label, line_id])
		else:
			ids.append(line_id)
		_validate_localized_field(entry, "%s %s" % [label, line_id], problems)
	if ids.size() != expected_count:
		problems.append("%s should contain %d lines" % [label, expected_count])


static func _validate_localized_field(localized: Variant, label: String, problems: Array[String]) -> void:
	if not localized is Dictionary:
		problems.append("%s must be a localized object" % label)
		return
	for locale_code in SUPPORTED_LOCALES:
		if str((localized as Dictionary).get(locale_code, "")).is_empty():
			problems.append("%s missing %s" % [label, locale_code])
