extends SceneTree
## 笔记本物理沙盘:字词受重力下坠、落在底边、彼此碰撞可堆叠、可抓放。

const CanvasScript = preload("res://scripts/ui/word_physics_canvas.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	_test_display_metrics()
	await _run()
	if _failures.is_empty():
		print("word physics canvas tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_display_metrics() -> void:
	var canvas: Control = CanvasScript.new()
	canvas.size = Vector2(900, 400)
	root.add_child(canvas)
	_assert_true(canvas.has_method("configure_tile_metrics"), "each canvas needs its own configurable tile typography")
	if not canvas.has_method("configure_tile_metrics"):
		canvas.free()
		return
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/BoutiqueBitmap9x9.ttf") as Font
	font.spacing_glyph = 1
	canvas.configure_tile_metrics(Vector2(54, 54), 36, font)
	var first_position := Vector2(60, 60)
	canvas.add_tile("门", first_position, Color.BLACK, StyleBoxFlat.new(), false)
	var body := canvas.get_node("WordPhysicsRoot/WordBody_门") as RigidBody2D
	var shape := body.get_node("TileShape") as CollisionShape2D
	var label := body.get_node("TileLabel") as Label
	_assert_true((shape.shape as RectangleShape2D).size == Vector2(54, 54), "36px CRT glyph has a padded 54px collision footprint")
	_assert_true(label.get_theme_font_size("font_size") == 36 and label.get_theme_font("font") == font, "CRT tile explicitly uses the passed reading font across the physics-node boundary")
	_assert_true(canvas.get_tile_position("门") == first_position, "enlarging a tile preserves the saved top-left spawn position")
	var long_position := Vector2(160, 140)
	canvas.add_tile("notebook", long_position, Color.BLACK, StyleBoxFlat.new(), false)
	var long_body := canvas.get_node("WordPhysicsRoot/WordBody_notebook") as RigidBody2D
	var long_shape := long_body.get_node("TileShape") as CollisionShape2D
	var long_label := long_body.get_node("TileLabel") as Label
	var footprint: Vector2 = long_body.get_meta("tile_size", Vector2.ZERO)
	var text_width := font.get_string_size("notebook", HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	_assert_true(footprint.x >= text_width + 18 and footprint.y >= 54, "long English units receive measured width plus readable left/right padding")
	_assert_true((long_shape.shape as RectangleShape2D).size == footprint and long_label.size == footprint, "long-word visual bounds and collision bounds stay aligned")
	var tapped: Array[String] = []
	canvas.tile_tapped.connect(func(unit: String) -> void: tapped.append(unit))
	# Tap near the visible right edge, well outside the former 44px hit box.
	var edge := long_position + Vector2(footprint.x - 2, footprint.y * 0.5)
	_mouse_button(canvas, edge, true)
	_mouse_button(canvas, edge, false)
	_assert_true(tapped == ["notebook"] and not canvas.is_dragging(), "visible right edge of a long tile is clickable exactly once")
	var saved: Dictionary = {}
	canvas.tile_settled.connect(func(unit: String, position: Vector2) -> void: saved[unit] = position)
	canvas._process(0.0)
	_assert_true(saved.get("notebook") == long_position, "settling publishes the actual long tile's top-left, not its center or old-size offset")
	var center := long_position + footprint * 0.5
	_mouse_button(canvas, center, true)
	var drag := InputEventMouseMotion.new()
	drag.position = center + Vector2(45, 28)
	drag.global_position = drag.position
	canvas._gui_input(drag)
	_mouse_button(canvas, drag.position, false)
	var expected := long_position + Vector2(45, 28)
	_assert_true(saved.get("notebook") == expected and canvas.get_tile_position("notebook") == expected, "drag release and save query agree on the same top-left after resizing")
	var phone: Control = CanvasScript.new()
	phone.size = Vector2(900, 400)
	root.add_child(phone)
	phone.add_tile("notebook", expected, Color.BLACK, null, false)
	var phone_body := phone.get_node("WordPhysicsRoot/WordBody_notebook") as RigidBody2D
	_assert_true((phone_body.get_node("TileShape").shape as RectangleShape2D).size == Vector2(44, 40), "an unconfigured phone canvas retains its original 44x40 tiles")
	_assert_true(not (phone_body.get_node("TileLabel") as Label).has_theme_font_size_override("font_size"), "phone tile font inheritance is unchanged")
	_assert_true(phone.get_tile_position("notebook") == expected, "a CRT-saved top-left reloads without offset on the original phone canvas")
	canvas.free()
	phone.free()


func _mouse_button(canvas: Control, point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = pressed
	canvas._gui_input(event)


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
