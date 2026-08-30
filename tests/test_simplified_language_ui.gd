extends SceneTree
## Runtime UI checks for removed legacy systems (requires main scene adapter).

const Harness = preload("res://tests/harness/minimal_game_harness.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await test_removed_systems_are_absent_from_runtime_ui()
	if _failures.is_empty():
		print("simplified language UI tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_removed_systems_are_absent_from_runtime_ui() -> void:
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "main scene should load")
	if scene == null:
		return
	var root := scene.instantiate()
	get_root().add_child(root)
	await process_frame
	root._locale.set_locale("zh")
	root.new_game()
	root.game.set_active_app("babel")
	root._render()
	var all_text := Harness.collect_control_text(root)
	for removed_copy in ["塔罗", "牌型", "整数倍率", "传播基础", "BABEL-LINK 98", "输入四位缓存编号"]:
		_assert_true(not all_text.contains(removed_copy), "runtime UI should not contain removed copy: %s" % removed_copy)
	for hidden_route_copy in ["已找到的异物", "地点已被说出"]:
		_assert_true(not all_text.contains(hidden_route_copy), "Tower App must not reveal hidden-floor checklist copy: %s" % hidden_route_copy)
	_assert_true(Harness.find_node_by_name(root, "SocialPublishContractPanel") == null, "the card-hand panel should be gone")
	_assert_true(Harness.find_node_by_name(root, "OldWebArchiveCodeInput") == null, "the archive code puzzle should be gone")
	root.game.set_active_app("social")
	root._set_social_screen("publish")
	root._render()
	var publish_text := Harness.collect_control_text(root)
	_assert_true(publish_text.contains("资金") and publish_text.contains("污染"), "the publish screen should preview the two remaining outcomes")
	root.free()


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
