extends RefCounted
class_name FloorComposer
## Decides who stands on one tower floor. The roster is data: id and kind only.
## Catalog display names sit beside the roster. The host never calls this module.

const LanguageCorruptionContentScript = preload("res://scripts/narrative/language_corruption_content.gd")

const ORDINARY_NPC_COUNTS := [4, 3, 2, 0]
const ORDINARY_NPC_LABELS := ["迟到者", "回声住户", "抄写员", "无名信徒", "旧帖目击者"]


static func npc_count_for_floor(floor_number: int) -> int:
	var floor_index := clampi(maxi(1, floor_number), 1, ORDINARY_NPC_COUNTS.size()) - 1
	return int(ORDINARY_NPC_COUNTS[floor_index])


static func compose(snapshot: Dictionary) -> Dictionary:
	var floor_number := maxi(1, int(snapshot.get("tower_floor", 1)))
	var roster: Array[Dictionary] = []
	var display_names := {}
	var world_hints := {}
	if floor_number <= 3:
		var key_id := "key_npc_%d_keynpc" % floor_number
		roster.append({"id": key_id, "kind": "key_npc"})
		var dialogue: Dictionary = LanguageCorruptionContentScript.get_key_npc_dialogue_for_floor(floor_number)
		display_names[key_id] = str(dialogue.get("actor_label", "关键住户"))
		var encounter: Dictionary = LanguageCorruptionContentScript.get_doll_encounter_for_floor(floor_number)
		var doll_id := str(encounter.get("doll_id", ""))
		if not doll_id.is_empty():
			roster.append({"id": doll_id, "kind": "doll"})
			display_names[doll_id] = str(encounter.get("actor_label", "缝线布偶"))
			world_hints[doll_id] = str(encounter.get("world_hint", ""))
	for index in npc_count_for_floor(floor_number):
		var npc_id := "npc_%d_npc%d" % [floor_number, index]
		roster.append({"id": npc_id, "kind": "npc"})
		display_names[npc_id] = str(ORDINARY_NPC_LABELS[index % ORDINARY_NPC_LABELS.size()])
	return {
		"roster": roster,
		"display_names": display_names,
		"world_hints": world_hints,
	}
