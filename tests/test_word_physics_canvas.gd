extends SceneTree
## 笔记本物理沙盘:字词受重力下坠、落在底边、彼此碰撞可堆叠、可抓放。

const CanvasScript = preload("res://framework/ui/word_physics_canvas.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _run()
	if _failures.is_empty():
		print("word physics canvas tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	var host := Control.new()
	host.size = Vector2(520, 300)
	root.add_child(host)
	var canvas: Control = CanvasScript.new()
	canvas.size = Vector2(520, 300)
	canvas.custom_minimum_size = Vector2(520, 300)
	host.add_child(canvas)
	await process_frame

	_assert_true(canvas.get_node_or_null("WordPhysicsRoot") != null, "the canvas should host a physics root")
	var walls := canvas.get_node_or_null("WordPhysicsRoot/CanvasWalls")
	_assert_true(walls != null, "the canvas should build its walls")
	if walls != null:
		for wall_name in ["FloorWall", "CeilingWall", "LeftWall", "RightWall"]:
			_assert_true(walls.get_node_or_null(wall_name) != null, "the canvas needs a %s" % wall_name)

	# 一个字从画布上方落下,应当因为重力落到底部附近并停住。
	canvas.add_tile("门", Vector2(60.0, 10.0), Color.WHITE, StyleBoxFlat.new(), false)
	_assert_true(canvas.has_tile("门"), "the tile should be registered")
	var start_position: Vector2 = canvas.get_tile_position("门")
	var start_y: float = start_position.y
	for _step in 90:
		await physics_frame
	var settled: Vector2 = canvas.get_tile_position("门")
	_assert_true(settled.y > start_y + 40.0, "gravity should pull the tile down (from %.1f to %.1f)" % [start_y, settled.y])
	_assert_true(settled.y <= 300.0 - 40.0 + 2.0, "the floor wall should stop the tile inside the canvas, got y=%.1f" % settled.y)

	# 第二个字落在第一个字的正上方:应当堆在它上面,而不是重叠穿过去。
	canvas.add_tile("开", Vector2(settled.x, 10.0), Color.WHITE, StyleBoxFlat.new(), false)
	for _step in 120:
		await physics_frame
	var stacked: Vector2 = canvas.get_tile_position("开")
	var bottom: Vector2 = canvas.get_tile_position("门")
	_assert_true(canvas.get_tile_count() == 2, "both tiles should live in the canvas")
	var vertical_gap: float = absf(stacked.y - bottom.y)
	var horizontal_gap: float = absf(stacked.x - bottom.x)
	_assert_true(vertical_gap > 20.0 or horizontal_gap > 20.0, "tiles must collide instead of overlapping (dy=%.1f dx=%.1f)" % [vertical_gap, horizontal_gap])
	_assert_true(stacked.y <= 300.0 - 40.0 + 2.0 and stacked.y >= -2.0, "stacked tiles should stay inside the canvas")

	# 侧壁:把字扔向左边界外,它应被挡在画布内。
	canvas.add_tile("灯", Vector2(4.0, 10.0), Color.WHITE, StyleBoxFlat.new(), false)
	for _step in 90:
		await physics_frame
	var side: Vector2 = canvas.get_tile_position("灯")
	_assert_true(side.x >= -2.0 and side.x <= 520.0 - 44.0 + 2.0, "side walls should keep tiles inside, got x=%.1f" % side.x)

	canvas.clear_tiles()
	_assert_true(canvas.get_tile_count() == 0, "clearing should remove every tile")

	host.queue_free()
	await process_frame


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
