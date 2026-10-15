class_name FloorTwoJourney
extends RefCounted

const TURN_IDS := ["turn_1", "turn_2"]
const WAYFINDER := "floor2_wayfinder"
const CARTOGRAPHER := "floor2_cartographer"


static func normalize(raw: Variant = {}) -> Dictionary:
	var result := {"accepted": false, "visited_turn_ids": [], "map_unlocked": false, "exit_reached": false}
	if not raw is Dictionary or not _is_true(raw.get("accepted", false)):
		return result
	result.accepted = true
	var visited: Variant = raw.get("visited_turn_ids", [])
	if visited is Array or visited is PackedStringArray:
		# Only the recorded ordered prefix is earned. Never reorder a malformed
		# save into a completed route or infer checkpoints from the reward flag.
		for index in mini(visited.size(), TURN_IDS.size()):
			if visited[index] != TURN_IDS[index]:
				break
			result.visited_turn_ids.append(TURN_IDS[index])
	result.map_unlocked = result.visited_turn_ids.size() == TURN_IDS.size() and _is_true(raw.get("map_unlocked", false))
	result.exit_reached = result.map_unlocked and _is_true(raw.get("exit_reached", false))
	return result


static func visit_turn(progress: Dictionary, checkpoint_id: String) -> Dictionary:
	var result := normalize(progress)
	var next_index: int = result.visited_turn_ids.size()
	if result.accepted and next_index < TURN_IDS.size() and checkpoint_id == TURN_IDS[next_index]:
		result.visited_turn_ids.append(checkpoint_id)
	return result


static func finish_dialogue(progress: Dictionary, actor_id: String) -> Dictionary:
	var result := normalize(progress)
	if actor_id == WAYFINDER:
		result.accepted = true
	elif actor_id == CARTOGRAPHER and result.accepted and result.visited_turn_ids.size() == TURN_IDS.size():
		result.map_unlocked = true
	return result


static func dialogue_for(actor_id: String, progress: Dictionary) -> Dictionary:
	var state := normalize(progress)
	if actor_id == WAYFINDER:
		if not state.accepted:
			return _dialogue("accept_route", "这里的路总会折回来。沿街走过前面两个转角，去找画地图的人。", "我会记住这两个转角，走到他那里。", "别急着找出口，先把脚下的路走完。")
		return _dialogue("remember_route", "沿街走过两个转角，再去找画地图的人。", "我继续沿着街道走。", "走过的路会留下痕迹。")
	if actor_id == CARTOGRAPHER:
		if state.map_unlocked:
			return _dialogue("continue_route", "地图会记住你走过的路。沿着街道继续找出口。", "我继续往前走。", "没有走过的地方，仍然是黑的。")
		if not state.accepted:
			return _dialogue("ask_wayfinder", "先去和入口处的引路人说说话。", "我先问清楚这条路。", "我在这里等你回来。")
		if state.visited_turn_ids.size() < TURN_IDS.size():
			return _dialogue("finish_turns", "先走过引路人说的两个转角，再来找我。", "我会走完，再回来。", "路要自己走过，图才会留下。")
		return _dialogue("receive_map", "你已经认出了这两个转角。这张图给你，它只记得你走过的地方。", "我会带着它，继续往前走。", "地图已经放进手机。剩下的路还在前面。")
	return {}


static func _dialogue(id: String, line: String, sentence: String, result: String) -> Dictionary:
	return {"line": line, "result": result, "choices": [{"id": id, "sentence": sentence}]}


static func _is_true(value: Variant) -> bool:
	return value is bool and value
