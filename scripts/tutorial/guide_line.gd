class_name GuideLine
extends RefCounted
## What the doll guide and the playtest panel say, worked out from the tutorial progress and the floor facts.

const TutorialDirectorScript = preload("res://scripts/tutorial/tutorial_director.gd")


static func doll_line(progress: Dictionary, tower_floor: int, floor3_task_complete: bool, floor4_task_complete: bool) -> String:
	var step := TutorialDirectorScript.current_step(progress)
	if not bool(step.get("is_complete", false)):
		var line := str(step.get("guide_line", ""))
		# 一步一步教:多次数步骤显示进度(如 拾取三个字 1/3)。
		var required_count := int(step.get("required_count", 0))
		if required_count > 1:
			line += "(%d/%d)" % [clampi(int(step.get("event_count", 0)), 0, required_count), required_count]
		return line
	if tower_floor == 3 and not floor3_task_complete:
		return "门在等一句话。去笔记本里拼给它。"
	if tower_floor == 3 and floor3_task_complete:
		return "门记得这句话。"
	if tower_floor == 4 and not floor4_task_complete:
		return "出口还不存在。让它存在。"
	if tower_floor == 4 and floor4_task_complete:
		return "出口存在了。这里不会记下我们。"
	return str(step.get("guide_line", "你已经会自己走了。至少现在是。"))


static func test_instruction(progress: Dictionary) -> String:
	return str(TutorialDirectorScript.current_step(progress).get("test_instruction", "测试提示：继续探索。"))
