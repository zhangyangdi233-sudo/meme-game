class_name WordPhysicsCanvas
extends Control
## 笔记本里的字词物理沙盘:拾到的字受重力落到底边,彼此有碰撞体积,
## 可以像积木一样越堆越高,也可以被玩家抓起来重新摆放。
##
## 用 RigidBody2D + 矩形碰撞体实现;拖动时切成 FREEZE(运动学)跟随指针,
## 松手后恢复动力学并把当时的速度交给物理,手感接近真实抓放。

signal tile_settled(unit: String, position: Vector2)
signal tile_dropped_outside(unit: String, global_position: Vector2)
signal tile_tapped(unit: String)

const WALL_THICKNESS := 64.0
const TILE_SIZE := Vector2(44.0, 40.0)
const DRAG_THRESHOLD := 6.0
const THROW_SPEED_LIMIT := 900.0

var _physics_root: Node2D
var _bodies: Dictionary = {}
var _dragging_body: RigidBody2D = null
var _drag_grab_offset := Vector2.ZERO
var _press_global := Vector2.ZERO
var _drag_started := false
var _last_drag_position := Vector2.ZERO
var _last_drag_delta := Vector2.ZERO
var _tile_size := TILE_SIZE
var _tile_font_size := 0
var _tile_font: Font


## Configure subsequently added tiles. Existing tiles retain their own measured
## footprints, so layout changes never reinterpret their saved top-left position.
func configure_tile_metrics(tile_size: Vector2, font_size: int, font: Font = null) -> void:
	_tile_size = Vector2(maxf(1.0, tile_size.x), maxf(1.0, tile_size.y))
	_tile_font_size = maxi(1, font_size)
	_tile_font = font


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	_physics_root = Node2D.new()
	_physics_root.name = "WordPhysicsRoot"
	add_child(_physics_root)
	_rebuild_walls()
	resized.connect(_rebuild_walls)
	set_process(true)


## 画布四壁:底边接住下坠的字,两侧与顶部防止字被挤出可活动区域。
func _rebuild_walls() -> void:
	if _physics_root == null:
		return
	var existing := _physics_root.get_node_or_null("CanvasWalls")
	if existing != null:
		_physics_root.remove_child(existing)
		existing.queue_free()
	var walls := StaticBody2D.new()
	walls.name = "CanvasWalls"
	_physics_root.add_child(walls)
	var canvas_size := size
	if canvas_size.x <= 0.0 or canvas_size.y <= 0.0:
		canvas_size = custom_minimum_size
	var half := WALL_THICKNESS * 0.5
	var specs := {
		"FloorWall": [Vector2(canvas_size.x * 0.5, canvas_size.y + half), Vector2(canvas_size.x + WALL_THICKNESS * 2.0, WALL_THICKNESS)],
		"CeilingWall": [Vector2(canvas_size.x * 0.5, -half), Vector2(canvas_size.x + WALL_THICKNESS * 2.0, WALL_THICKNESS)],
		"LeftWall": [Vector2(-half, canvas_size.y * 0.5), Vector2(WALL_THICKNESS, canvas_size.y + WALL_THICKNESS * 2.0)],
		"RightWall": [Vector2(canvas_size.x + half, canvas_size.y * 0.5), Vector2(WALL_THICKNESS, canvas_size.y + WALL_THICKNESS * 2.0)],
	}
	for wall_name in specs.keys():
		var spec: Array = specs[wall_name]
		var shape_node := CollisionShape2D.new()
		shape_node.name = str(wall_name)
		var rectangle := RectangleShape2D.new()
		rectangle.size = spec[1]
		shape_node.shape = rectangle
		shape_node.position = spec[0]
		walls.add_child(shape_node)


func clear_tiles() -> void:
	for unit in _bodies.keys():
		var body: RigidBody2D = _bodies[unit]
		if is_instance_valid(body):
			body.queue_free()
	_bodies.clear()
	_dragging_body = null


## 放入一个字:给定初始位置(通常是存档里记下的落点),之后交给物理。
func add_tile(unit: String, spawn_position: Vector2, label_color: Color, panel_style: StyleBox, is_ghost: bool) -> void:
	if _bodies.has(unit):
		return
	var actual_size := _tile_size
	var reading_font := _tile_font if _tile_font != null else get_theme_font("font")
	if _tile_font_size > 0:
		var text_size := reading_font.get_string_size(unit, HORIZONTAL_ALIGNMENT_LEFT, -1, _tile_font_size)
		actual_size.x = maxf(actual_size.x, ceilf(text_size.x) + 18.0)
		actual_size.y = maxf(actual_size.y, ceilf(reading_font.get_height(_tile_font_size)) + 12.0)
	var body := RigidBody2D.new()
	body.name = "WordBody_%s" % unit
	body.position = spawn_position + actual_size * 0.5
	body.gravity_scale = 1.0
	body.mass = 0.6
	body.physics_material_override = PhysicsMaterial.new()
	body.physics_material_override.friction = 0.85
	body.physics_material_override.bounce = 0.02
	body.linear_damp = 1.2
	body.angular_damp = 4.0
	body.contact_monitor = false
	body.set_meta("word_unit", unit)
	body.set_meta("tile_size", actual_size)

	var shape := CollisionShape2D.new()
	shape.name = "TileShape"
	var rectangle := RectangleShape2D.new()
	rectangle.size = actual_size
	shape.shape = rectangle
	body.add_child(shape)

	var panel := Panel.new()
	panel.name = "TileFace"
	panel.size = actual_size
	panel.position = -actual_size * 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if panel_style != null:
		panel.add_theme_stylebox_override("panel", panel_style)
	body.add_child(panel)

	var label := Label.new()
	label.name = "TileLabel"
	label.text = unit
	label.size = actual_size
	label.position = -actual_size * 0.5
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", label_color)
	if _tile_font_size > 0:
		label.add_theme_font_size_override("font_size", _tile_font_size)
		label.add_theme_font_override("font", reading_font)
	label.set_meta("skip_localization", true)
	body.add_child(label)

	if is_ghost:
		body.modulate = Color(1.0, 1.0, 1.0, 0.45)

	_physics_root.add_child(body)
	_bodies[unit] = body


func get_tile_position(unit: String) -> Vector2:
	if not _bodies.has(unit):
		return Vector2.ZERO
	var body: RigidBody2D = _bodies[unit]
	if not is_instance_valid(body):
		return Vector2.ZERO
	return body.position - _body_tile_size(body) * 0.5


func _body_tile_size(body: RigidBody2D) -> Vector2:
	return body.get_meta("tile_size", TILE_SIZE)


func get_tile_count() -> int:
	return _bodies.size()


func has_tile(unit: String) -> bool:
	return _bodies.has(unit)


func is_dragging() -> bool:
	return _dragging_body != null


func _process(_delta: float) -> void:
	# 落定的字把位置回报给存档层,重开游戏时字堆保持原样。
	for unit in _bodies.keys():
		var body: RigidBody2D = _bodies[unit]
		if not is_instance_valid(body) or body == _dragging_body:
			continue
		if body.linear_velocity.length() < 4.0:
			tile_settled.emit(str(unit), body.position - _body_tile_size(body) * 0.5)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button_event := event as InputEventMouseButton
		if button_event.pressed:
			_begin_drag(button_event.position, button_event.global_position)
		else:
			_end_drag(button_event.global_position)
		accept_event()
	elif event is InputEventMouseMotion and _dragging_body != null:
		var motion := event as InputEventMouseMotion
		if not _drag_started and motion.global_position.distance_to(_press_global) < DRAG_THRESHOLD:
			return
		_drag_started = true
		var target := motion.position - _drag_grab_offset
		_last_drag_delta = target - _last_drag_position
		_last_drag_position = target
		_dragging_body.position = target
		accept_event()


func _begin_drag(local_position: Vector2, global_position: Vector2) -> void:
	_dragging_body = _body_at(local_position)
	_drag_started = false
	_press_global = global_position
	if _dragging_body == null:
		return
	_drag_grab_offset = local_position - _dragging_body.position
	_last_drag_position = _dragging_body.position
	_last_drag_delta = Vector2.ZERO
	# 抓起时切成运动学:跟手,且不会被其它字挤走。
	_dragging_body.freeze = true
	_dragging_body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	_dragging_body.z_index = 10


func _end_drag(release_global: Vector2) -> void:
	if _dragging_body == null:
		return
	var body := _dragging_body
	_dragging_body = null
	body.z_index = 0
	body.freeze = false
	# 松手把手上的速度交给物理,轻轻一抛也能堆到别的字上面。
	body.linear_velocity = (_last_drag_delta * 60.0).limit_length(THROW_SPEED_LIMIT)
	var unit := str(body.get_meta("word_unit", ""))
	if not _drag_started:
		tile_tapped.emit(unit)
		return
	if not get_global_rect().has_point(release_global):
		tile_dropped_outside.emit(unit, release_global)
	else:
		tile_settled.emit(unit, body.position - _body_tile_size(body) * 0.5)


func _body_at(local_position: Vector2) -> RigidBody2D:
	var hit: RigidBody2D = null
	var best_z := -1
	for unit in _bodies.keys():
		var body: RigidBody2D = _bodies[unit]
		if not is_instance_valid(body):
			continue
		var actual_size := _body_tile_size(body)
		var rect := Rect2(body.position - actual_size * 0.5, actual_size)
		if rect.has_point(local_position) and body.z_index >= best_z:
			hit = body
			best_z = body.z_index
	return hit
