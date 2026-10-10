extends SceneTree
## Guide lines come from the tutorial progress and the floor facts alone.

const DirectorScript = preload("res://scripts/tutorial/tutorial_director.gd")
const GuideLineScript = preload("res://scripts/tutorial/guide_line.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("guide line tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_each_tutorial_step_speaks_its_own_line()
	_test_counted_steps_show_how_far_along_they_are()
	_test_finished_tutorial_follows_the_floor_tasks()
	_test_test_instruction_follows_the_step()


func _test_each_tutorial_step_speaks_its_own_line() -> void:
	var progress := DirectorScript.initial_progress()
	_assert_eq(GuideLineScript.doll_line(progress, 1, false, false), "先找到我。别急着相信我。", "a fresh run should open with the first step")
	progress = DirectorScript.notify(progress, &"guide_found")
	_assert_eq(GuideLineScript.doll_line(progress, 1, false, false), "拿起手机，打开社交媒体。那里有人替你准备了词。", "finding the guide should move to the phone step")


func _test_counted_steps_show_how_far_along_they_are() -> void:
	var progress := DirectorScript.initial_progress()
	for event_id in ["guide_found", "social_opened", "post_opened", "collect_word"]:
		progress = DirectorScript.notify(progress, StringName(event_id))
	_assert_true(GuideLineScript.doll_line(progress, 1, false, false).ends_with("(1/3)"), "a counted step should show one of three")
	progress = DirectorScript.notify(progress, &"collect_word")
	_assert_true(GuideLineScript.doll_line(progress, 1, false, false).ends_with("(2/3)"), "the count should follow the progress")


func _test_finished_tutorial_follows_the_floor_tasks() -> void:
	var done := DirectorScript.skip(DirectorScript.initial_progress())
	_assert_eq(GuideLineScript.doll_line(done, 1, false, false), "你已经会自己走了。至少现在是。", "a finished tutorial on a plain floor should send the player on")
	_assert_eq(GuideLineScript.doll_line(done, 3, false, false), "门在等一句话。去笔记本里拼给它。", "floor three waits for the door sentence")
	_assert_eq(GuideLineScript.doll_line(done, 3, true, false), "门记得这句话。", "floor three remembers the door sentence")
	_assert_eq(GuideLineScript.doll_line(done, 4, true, false), "出口还不存在。让它存在。", "floor four waits for the exit")
	_assert_eq(GuideLineScript.doll_line(done, 4, true, true), "出口存在了。这里不会记下我们。", "floor four has its exit")
	var unfinished := DirectorScript.initial_progress()
	_assert_eq(GuideLineScript.doll_line(unfinished, 3, false, false), "先找到我。别急着相信我。", "the tutorial speaks before any floor task")


func _test_test_instruction_follows_the_step() -> void:
	var progress := DirectorScript.initial_progress()
	_assert_eq(GuideLineScript.test_instruction(progress), "测试提示：转动镜头并靠近缝线布偶。", "the first step should have its test hint")
	progress = DirectorScript.skip(progress)
	_assert_eq(GuideLineScript.test_instruction(progress), "教程完成：继续正常游戏。", "a finished tutorial should say so")
	_assert_eq(GuideLineScript.test_instruction({}), "测试提示：转动镜头并靠近缝线布偶。", "an empty progress should read as a fresh run")


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
