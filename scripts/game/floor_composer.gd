extends RefCounted
class_name FloorComposer
## Decides who stands on one tower floor, which prerequisite item is there,
## and which of the three self-playing scenes run that day.
## Rosters are id and kind only. Display names sit beside them. Images stay out.
## The scene schedule lives here, not in the content catalog.

const LanguageCorruptionContentScript = preload("res://scripts/narrative/language_corruption_content.gd")
const NarrativeSessionCatalogScript = preload("res://scripts/game/narrative_session_catalog.gd")

const ORDINARY_NPC_COUNTS := [4, 3, 2, 0]
const PEDESTRIAN_LABELS := ["迟到者", "回声住户", "抄写员", "无名信徒", "旧帖目击者"]
const DISTANT_MIRAGE_DAYS := [4, 9]
const SCENE_SCHEDULE := {
	2: [
		["light_memory", "dead_sign"],
		["light_memory"],
		["dead_sign"],
	],
	3: [
		["dead_sign"],
		["light_memory", "dead_sign"],
		["light_memory"],
	],
	4: [
		["light_memory"],
		["dead_sign"],
		["light_memory", "dead_sign"],
	],
}


static func ordinary_npc_count(floor_number: int) -> int:
	var floor_index := clampi(maxi(1, floor_number), 1, ORDINARY_NPC_COUNTS.size()) - 1
	return int(ORDINARY_NPC_COUNTS[floor_index])


static func compose(snapshot: Dictionary) -> Dictionary:
	var progress: Dictionary = snapshot.get("day_progress", {})
	var floor_number := clampi(int(progress.get("tower_floor", 1)), 1, 4)
	var people: Array = []
	var display_names := {}
	if floor_number <= 3:
		_add_key_resident(people, display_names, floor_number)
		_add_doll(people, display_names, floor_number)
	var pedestrian_count := ordinary_npc_count(floor_number)
	for index in pedestrian_count:
		var pedestrian_id := "npc_%d_npc%d" % [floor_number, index]
		people.append({"id": pedestrian_id, "kind": "npc"})
		display_names[pedestrian_id] = PEDESTRIAN_LABELS[index % PEDESTRIAN_LABELS.size()]
	var items: Array = []
	_add_prerequisite_item(items, display_names, floor_number, str(snapshot.get("locale", "zh")))
	var day_number := int(progress.get("day", 1))
	return {
		"people": people,
		"display_names": display_names,
		"items": items,
		"events": _scene_events(floor_number, day_number),
	}


static func _scene_events(floor_number: int, day_number: int) -> Array:
	var floor_schedules: Array = SCENE_SCHEDULE.get(floor_number, [])
	if floor_schedules.is_empty():
		return []
	var normalized_day := maxi(1, day_number)
	var selected_schedule: Array = floor_schedules[posmod(normalized_day - 1, floor_schedules.size())]
	var events: Array = []
	for scene_kind in selected_schedule:
		var kind := str(scene_kind)
		events.append({"id": kind, "kind": kind})
	if floor_number >= 2 and normalized_day in DISTANT_MIRAGE_DAYS:
		events.append({"id": "distant_mirage", "kind": "distant_mirage"})
	return events


static func _add_key_resident(people: Array, display_names: Dictionary, floor_number: int) -> void:
	var resident_id := "key_npc_%d_keynpc" % floor_number
	people.append({"id": resident_id, "kind": "key_npc"})
	var dialogue: Dictionary = LanguageCorruptionContentScript.get_key_npc_dialogue_for_floor(floor_number)
	display_names[resident_id] = str(dialogue.get("actor_label", "关键住户"))


static func _add_prerequisite_item(items: Array, display_names: Dictionary, floor_number: int, locale_code: String) -> void:
	if floor_number > 3:
		return
	var catalog_item: Dictionary = NarrativeSessionCatalogScript.prerequisite_item(floor_number, locale_code)
	var item_id := str(catalog_item.get("id", "")).strip_edges()
	if item_id.is_empty():
		return
	items.append({"id": item_id, "kind": "prerequisite"})
	display_names[item_id] = str(catalog_item.get("label", ""))


static func _add_doll(people: Array, display_names: Dictionary, floor_number: int) -> void:
	var encounter: Dictionary = LanguageCorruptionContentScript.get_doll_encounter_for_floor(floor_number)
	var doll_id := str(encounter.get("doll_id", ""))
	if doll_id.is_empty():
		return
	people.append({"id": doll_id, "kind": "doll"})
	display_names[doll_id] = str(encounter.get("actor_label", "缝线布偶"))
