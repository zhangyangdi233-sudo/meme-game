extends SceneTree
## 笔记本物理沙盘:字词受重力下坠、落在底边、彼此碰撞可堆叠、可抓放。

const CanvasScript = preload("res://framework/ui/word_physics_canvas.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _test_drag_release_across_physics_frames()
	await _test_window_shake_keeps_tiles_inside()
	await _test_escaped_tile_returns_next_step()
	_test_out_of_bounds_positions_are_clamped()
	await _run()
	if _failures.is_empty():
		print("word physics canvas tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_drag_release_across_physics_frames() -> void:
	# Ported from main (#141).
	var canvas: WordPhysicsCanvas = CanvasScript.new()
	canvas.position = Vector2(240, 110)
	canvas.size = Vector2(520, 400)
	root.add_child(canvas)
	canvas.add_tile("门", Vector2(60, 30), Color.WHITE, null, false)
	for frame in 60:
		await physics_frame
	var body: RigidBody2D = canvas.get_node("WordPhysicsRoot/WordBody_门")
	canvas._begin_drag(body.position, canvas.global_position + body.position)
	var destination := Vector2(340, 90)
	var motion := InputEventMouseMotion.new()
	motion.position = destination
	motion.global_position = canvas.global_position + destination
	canvas._gui_input(motion)
	# Hold still, then release. A stale last-motion delta must not throw the
	# tile sideways, and unfreezing must not restore its old floor position.
	for frame in 12:
		await physics_frame
	# The canvas treats a release as a throw only within 90 ms of the last move.
	OS.delay_msec(120)
	canvas._end_drag(canvas.global_position + destination)
	await physics_frame
	await physics_frame
	_assert_true(absf(body.position.x - destination.x) < 8, "holding the dragged tile still before release must not retain an old fling velocity")
	_assert_true(body.position.y < 150, "physics resumes at the release location instead of the old floor position")
	var release_y := body.position.y
	for frame in 8:
		await physics_frame
	_assert_true(body.position.y > release_y, "gravity continues pulling the released tile downward")
	canvas.free()


const SHAKE_CANVAS_SIZE := Vector2(520, 300)


func _make_shake_canvas() -> WordPhysicsCanvas:
	var canvas: WordPhysicsCanvas = CanvasScript.new()
	canvas.position = Vector2(200, 150)
	canvas.size = SHAKE_CANVAS_SIZE
	root.add_child(canvas)
	return canvas


func _tile_inside(canvas: WordPhysicsCanvas, unit: String) -> bool:
	var tile_position := canvas.get_tile_position(unit)
	var slack := 2.0
	return tile_position.x >= -slack and tile_position.y >= -slack \
		and tile_position.x <= SHAKE_CANVAS_SIZE.x - CanvasScript.TILE_SIZE.x + slack \
		and tile_position.y <= SHAKE_CANVAS_SIZE.y - CanvasScript.TILE_SIZE.y + slack


# #152: dragging the notebook window fast moved the walls through the tiles.
func _test_window_shake_keeps_tiles_inside() -> void:
	var canvas := _make_shake_canvas()
	var units := ["捧", "这", "门", "灯", "开"]
	for index in units.size():
		canvas.add_tile(units[index], Vector2(40.0 + index * 90.0, 200.0), Color.WHITE, null, false)
	for frame in 60:
		await physics_frame
	var body: RigidBody2D = canvas.get_node("WordPhysicsRoot/WordBody_门")
	var rest_x := canvas.get_tile_position("门").x
	# One big jump right: the tiles should sway left inside the canvas, not stay behind it.
	canvas.position += Vector2(600, 0)
	await physics_frame
	await physics_frame
	_assert_true(body.linear_velocity.x < -20.0, "moving the window right should sway the tiles left (vx=%.1f)" % body.linear_velocity.x)
	var swayed_x := canvas.get_tile_position("门").x
	_assert_true(swayed_x < rest_x + 2.0 and swayed_x > rest_x - 60.0, "the swaying tile follows the window instead of being left behind (from %.1f to %.1f)" % [rest_x, swayed_x])
	# A fast shake back and forth, larger than the canvas, then let it settle.
	for swing in 12:
		canvas.position += Vector2(-900 if swing % 2 == 0 else 900, -300 if swing % 3 == 0 else 300)
		await physics_frame
	for frame in 120:
		await physics_frame
	for unit in units:
		_assert_true(_tile_inside(canvas, unit), "after a fast window shake %s stays inside the canvas, got %s" % [unit, canvas.get_tile_position(unit)])
	_assert_true(canvas.get_tile_position("门").y > SHAKE_CANVAS_SIZE.y - CanvasScript.TILE_SIZE.y * 3.0, "the tiles fall back to the bottom")
	canvas.free()


func _test_escaped_tile_returns_next_step() -> void:
	var canvas := _make_shake_canvas()
	canvas.add_tile("捧", Vector2(100, 200), Color.WHITE, null, false)
	for frame in 10:
		await physics_frame
	var body: RigidBody2D = canvas.get_node("WordPhysicsRoot/WordBody_捧")
	body.position = Vector2(-400, 900)
	PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, body.global_transform)
	body.linear_velocity = Vector2(-500, 500)
	await physics_frame
	await physics_frame
	_assert_true(_tile_inside(canvas, "捧"), "a tile outside the canvas is put back on the next physics step, got %s" % canvas.get_tile_position("捧"))
	canvas.free()


func _test_out_of_bounds_positions_are_clamped() -> void:
	var canvas := _make_shake_canvas()
	# An old save may hold a position a shake pushed outside.
	canvas.add_tile("这", Vector2(2000, -500), Color.WHITE, null, false)
	_assert_true(_tile_inside(canvas, "这"), "a saved position outside the canvas is clamped back in, got %s" % canvas.get_tile_position("这"))
	var body: RigidBody2D = canvas.get_node("WordPhysicsRoot/WordBody_这")
	body.position = Vector2(-300, 1200)
	body.linear_velocity = Vector2.ZERO
	var settled: Dictionary = canvas.settled_tile_positions()
	_assert_true(settled.has("这"), "a resting tile is reported")
	var reported: Vector2 = settled.get("这", Vector2.ZERO)
	_assert_true(Rect2(Vector2.ZERO, SHAKE_CANVAS_SIZE - CanvasScript.TILE_SIZE).grow(0.01).has_point(reported), "settled positions are always inside the canvas, got %s" % reported)
	canvas.free()


func _run() -> void:
	var host := Control.new()
	host.size = Vector2(520, 300)
	root.add_child(host)
	var canvas: WordPhysicsCanvas = CanvasScript.new()
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

	# 位置留在方塊上。速度為零可以讀回；還在動或被抓住時不往外送。閒置的畫面也不推送。
	canvas.add_tile("靜", Vector2(80.0, 220.0), Color.WHITE, StyleBoxFlat.new(), false)
	var resting_positions: Dictionary = canvas.settled_tile_positions()
	_assert_true(resting_positions.has("靜"), "a resting tile should be readable from the canvas")
	var pushed: Array = []
	if canvas.has_signal("tile_settled"):
		canvas.connect("tile_settled", func(unit: String, _tile_position: Vector2) -> void: pushed.append(unit))
	for _step in 8:
		await process_frame
	_assert_true(pushed.is_empty(), "idle frames must not push tile positions")
	var resting_body := canvas.get_node_or_null("WordPhysicsRoot/WordBody_靜") as RigidBody2D
	_assert_true(resting_body != null, "the resting tile should have a body")
	if resting_body != null:
		resting_body.linear_velocity = Vector2(280.0, 0.0)
	var moving_positions: Dictionary = canvas.settled_tile_positions()
	_assert_true(not moving_positions.has("靜"), "a moving tile must stay on the canvas until it rests")
	if resting_body != null:
		resting_body.linear_velocity = Vector2.ZERO
		resting_body.sleeping = false
	var held_positions: Dictionary = canvas.settled_tile_positions()
	_assert_true(held_positions.has("靜"), "a stopped tile should be readable again")
	var grab := InputEventMouseButton.new()
	grab.button_index = MOUSE_BUTTON_LEFT
	grab.pressed = true
	grab.position = canvas.get_tile_position("靜") + Vector2(22.0, 20.0)
	canvas._gui_input(grab)
	_assert_true(canvas.is_dragging(), "pressing a tile should grab it")
	var dragged_positions: Dictionary = canvas.settled_tile_positions()
	_assert_true(not dragged_positions.has("靜"), "a grabbed tile must not be reported while dragging")

	host.queue_free()
	await process_frame


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
