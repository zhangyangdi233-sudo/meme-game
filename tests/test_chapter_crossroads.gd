extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var script := load("res://scripts/reality_floor_generator.gd") as Script
	var world = script.new()
	root.add_child(world)
	var rebuild_arguments := 0
	for info in world.get_method_list():
		if info.name == "rebuild":
			rebuild_arguments = info.args.size()
	if rebuild_arguments < 7:
		failures.append("crossroads needs explicit empty population option")
	else:
		world.rebuild(1, {"bg": "B7D957", "surface": "FFF1C9", "text": "10140F", "ink": "10140F", "accent": "365B2D", "muted": "DDEB8A"}, {}, 1, false, {}, false)
		_check(world.get_interactable_actors().is_empty(), "chapter crossroads has no NPC or doll actors")
		_check(world.get_interactable_items().is_empty(), "chapter crossroads has no legacy collectible")
		_check(world.find_child("CrossroadGround", true, false) != null, "original crossroad collision retained")
		_check(world.find_child("CrossRoad", true, false) != null, "original crossroad geometry retained")
		_check(world.find_child("CoverWatcherEvent", true, false) == null, "empty crossroads does not spawn legacy watcher")
		_check(world.contains_playable_position(Vector3(40, 0.08, 0)), "original crossroad arm remains walkable")
	world.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("chapter crossroads tests passed")
	quit(0 if failures.is_empty() else 1)


func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
