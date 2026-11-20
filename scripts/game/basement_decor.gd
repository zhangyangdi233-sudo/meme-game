class_name BasementDecor
extends RefCounted
## What the basement shows that changes from run to run but holds within one, drawn from the run's seed (#114): the
## vase or the book on the exit table each round, and how round three's chairs lie once its light is back. Pure, so one
## seed gives the same room after a save or a walk back.
## The chairs of the pile are solid (planner, 2026-11-20), so a pile laid on a described floor leaves the room walkable:
## every place the round can need is still reached from the foot of the stairs.

const EXIT_TABLE_PROPS := ["vase", "book"]
const SCATTERED_CHAIR_COUNT := 9
## The open floor of the front room (x, z), clear of the stairs, the partition and the CRT's console.
const SCATTER_AREA := Rect2(-1.4, -2.2, 3.6, 5.0)
## A chair's solid box (wide, tall, deep) standing on the chair's own floor point; a tipped chair lies on its side, its
## box running along the chair's own -X from its feet.
const CHAIR_BODY := Vector3(0.5, 1.0, 0.5)
## How near a chair's floor point the player must be able to stand for one chair of the pile to be of use.
const CHAIR_REACH := 0.9
## The floor is checked on squares this wide, by a walker wider than the player (0.34 m), so every way the pile leaves
## open is about 0.9 m across and not a squeeze. Where the walker stands, the player gets nearer by the difference.
const FLOOR_CELL := 0.125
const PLAYER_RADIUS := 0.34
const WALKER_RADIUS := 0.46
## How often one chair is drawn again while it lies in the furniture or would shut the walker out; a chair that finds no
## place lies where it last fell and stops nobody.
const CHAIR_TRIES := 60


## What lies on the exit table in `round_number` of the run seeded `seed`.
static func exit_table_prop(seed: int, round_number: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, round_number, "exit_table"])
	return EXIT_TABLE_PROPS[rng.randi_range(0, EXIT_TABLE_PROPS.size() - 1)]


## Round three's pile of chairs for the run seeded `seed`: each with its `position` on the floor, its `yaw` and `tilt`
## in radians (a tipped chair lies on its side), which of the room's chair models it copies (`model`, an index) and
## whether it is `solid`.
## `floor` describes the room the pile must leave walkable (x, z on the floor): its `area` (Rect2), the `blocks` standing
## on it (Rect2s), `start` and `reach` (lists of [Vector2, radius]: from near a start the player must still get near
## every reach, and near one chair) and `clear` (a list of [Vector2, radius]: where the player may stand when the pile
## appears, which no chair comes near). Chairs then keep out of the blocks. Without a floor nothing is checked.
static func scattered_chairs(seed: int, floor: Dictionary = {}) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "scattered_chairs"])
	var chairs: Array = []
	if floor.is_empty():
		for index in SCATTERED_CHAIR_COUNT:
			chairs.append(_draw_chair(rng))
		return chairs
	# The chairs fall one after another; each is drawn again until it lies clear and the room is still walkable with it.
	var open := _open_floor(floor)
	floor = _with_reachable_places(floor, open)
	for index in SCATTERED_CHAIR_COUNT:
		var chair := {}
		var clear := {}
		var fits := false
		for attempt in CHAIR_TRIES:
			chair = _draw_chair(rng)
			if not _lies_free(chair, floor):
				continue
			clear = chair
			if _leaves_walkable(chairs + [chair], floor, open):
				fits = true
				break
		# A chair that found no place lies where it last fell clear of the furniture, and stops nobody.
		if not fits and not clear.is_empty():
			chair = clear
		chair["solid"] = fits
		chairs.append(chair)
	return chairs


## The floor with only the reach places the walker gets near while no chair lies there. A place the room itself keeps
## out of reach (behind its furniture, after a change to the model) is not the pile's to keep open: left in, it would
## make every chair of every pile unsolid without a word.
static func _with_reachable_places(floor: Dictionary, open: PackedByteArray) -> Dictionary:
	var area: Rect2 = floor["area"]
	var squares := open.duplicate()
	_walk(squares, floor)
	var kept: Array = []
	for reach: Array in floor.get("reach", []):
		if _reached_near(squares, area, reach[0], float(reach[1])):
			kept.append(reach)
		else:
			push_warning("BasementDecor: the room keeps %s (within %.2f m) out of reach before any chair lies there; the pile is laid without it" % [reach[0], float(reach[1])])
	var checked := floor.duplicate()
	checked["reach"] = kept
	return checked


## Whether `chairs`, solid, leave `floor` walkable as `scattered_chairs` promises.
static func leaves_walkable(chairs: Array, floor: Dictionary) -> bool:
	return _leaves_walkable(chairs, floor, _open_floor(floor))


## A chair's footprint on the floor: its `middle`, its `half` size before the turn and its `yaw`.
static func chair_footprint(chair: Dictionary) -> Dictionary:
	var at: Vector3 = chair["position"]
	var yaw := float(chair["yaw"])
	var middle := Vector2(at.x, at.z)
	var half := Vector2(CHAIR_BODY.x, CHAIR_BODY.z) * 0.5
	if float(chair["tilt"]) != 0.0:
		half = Vector2(CHAIR_BODY.y, CHAIR_BODY.z) * 0.5
		middle += Vector2(-cos(yaw), sin(yaw)) * CHAIR_BODY.y * 0.5
	return {"middle": middle, "half": half, "yaw": yaw}


static func _draw_chair(rng: RandomNumberGenerator) -> Dictionary:
	return {
		"position": Vector3(
			rng.randf_range(SCATTER_AREA.position.x, SCATTER_AREA.end.x),
			0.0,
			rng.randf_range(SCATTER_AREA.position.y, SCATTER_AREA.end.y)
		),
		"yaw": rng.randf_range(-PI, PI),
		"tilt": PI * 0.5 if rng.randf() < 0.3 else 0.0,
		"model": rng.randi_range(0, 2),
		"solid": true,
	}


## Whether the chair keeps out of the floor's blocks and away from its clear places (its footprint taken as a circle).
static func _lies_free(chair: Dictionary, floor: Dictionary) -> bool:
	var footprint := chair_footprint(chair)
	var middle: Vector2 = footprint["middle"]
	var radius := (footprint["half"] as Vector2).length()
	for block: Rect2 in floor.get("blocks", []):
		if block.grow(radius).has_point(middle):
			return false
	for place: Array in floor.get("clear", []):
		if (place[0] as Vector2).distance_to(middle) < float(place[1]) + radius + WALKER_RADIUS:
			return false
	return true


## The floor's squares the walker cannot stand on before any chair lies there: 1 where a block is nearer than the walker
## is wide, row after row over the floor's area.
static func _open_floor(floor: Dictionary) -> PackedByteArray:
	var area: Rect2 = floor["area"]
	var columns := _columns(area)
	var squares := PackedByteArray()
	squares.resize(columns * _rows(area))
	for block: Rect2 in floor.get("blocks", []):
		_close(squares, area, block.get_center(), block.size * 0.5, 0.0)
	return squares


static func _columns(area: Rect2) -> int:
	return int(ceil(area.size.x / FLOOR_CELL))


static func _rows(area: Rect2) -> int:
	return int(ceil(area.size.y / FLOOR_CELL))


## Closes the squares the walker cannot stand on beside a box on the floor (`half` its size before the turn `yaw`).
static func _close(squares: PackedByteArray, area: Rect2, middle: Vector2, half: Vector2, yaw: float) -> void:
	var columns := _columns(area)
	var rows := _rows(area)
	var span := half.length() + WALKER_RADIUS
	var from := ((middle - Vector2(span, span) - area.position) / FLOOR_CELL).floor()
	var to := ((middle + Vector2(span, span) - area.position) / FLOOR_CELL).ceil()
	# The box's own axes on the floor (a turn about +Y by `yaw`).
	var along := Vector2(cos(yaw), -sin(yaw))
	var across := Vector2(sin(yaw), cos(yaw))
	for row in range(maxi(int(from.y), 0), mini(int(to.y), rows)):
		for column in range(maxi(int(from.x), 0), mini(int(to.x), columns)):
			var offset := area.position + Vector2(column + 0.5, row + 0.5) * FLOOR_CELL - middle
			var outside := Vector2(maxf(absf(offset.dot(along)) - half.x, 0.0), maxf(absf(offset.dot(across)) - half.y, 0.0))
			if outside.length_squared() < WALKER_RADIUS * WALKER_RADIUS:
				squares[row * columns + column] = 1


## Walks the floor from its starts around the blocks and the solid chairs, and answers whether every reach and one chair
## can still be stood by.
static func _leaves_walkable(chairs: Array, floor: Dictionary, open: PackedByteArray) -> bool:
	var area: Rect2 = floor["area"]
	var columns := _columns(area)
	var squares := open.duplicate()
	for chair: Dictionary in chairs:
		if bool(chair.get("solid", true)):
			var footprint := chair_footprint(chair)
			_close(squares, area, footprint["middle"], footprint["half"], float(footprint["yaw"]))
	_walk(squares, floor)
	for reach: Array in floor.get("reach", []):
		if not _reached_near(squares, area, reach[0], float(reach[1])):
			return false
	for chair: Dictionary in chairs:
		var at: Vector3 = chair["position"]
		if _reached_near(squares, area, Vector2(at.x, at.z), CHAIR_REACH):
			return true
	return chairs.is_empty()


## Walks the open squares (0) from the floor's starts, square to neighbouring square; 2 marks a square the walk reached.
static func _walk(squares: PackedByteArray, floor: Dictionary) -> void:
	var area: Rect2 = floor["area"]
	var columns := _columns(area)
	var queue := PackedInt32Array()
	for start: Array in floor.get("start", []):
		for square in _squares_near(area, start[0], float(start[1])):
			if squares[square] == 0:
				squares[square] = 2
				queue.append(square)
	var head := 0
	while head < queue.size():
		var square := queue[head]
		head += 1
		var column := square % columns
		if column > 0 and squares[square - 1] == 0:
			squares[square - 1] = 2
			queue.append(square - 1)
		if column < columns - 1 and squares[square + 1] == 0:
			squares[square + 1] = 2
			queue.append(square + 1)
		if square >= columns and squares[square - columns] == 0:
			squares[square - columns] = 2
			queue.append(square - columns)
		if square + columns < squares.size() and squares[square + columns] == 0:
			squares[square + columns] = 2
			queue.append(square + columns)


static func _reached_near(squares: PackedByteArray, area: Rect2, point: Vector2, radius: float) -> bool:
	for square in _squares_near(area, point, radius + WALKER_RADIUS - PLAYER_RADIUS):
		if squares[square] == 2:
			return true
	return false


## The squares whose middle lies within `radius` of `point`.
static func _squares_near(area: Rect2, point: Vector2, radius: float) -> PackedInt32Array:
	var columns := _columns(area)
	var rows := _rows(area)
	var from := ((point - Vector2(radius, radius) - area.position) / FLOOR_CELL).floor()
	var to := ((point + Vector2(radius, radius) - area.position) / FLOOR_CELL).ceil()
	var near := PackedInt32Array()
	for row in range(maxi(int(from.y), 0), mini(int(to.y), rows)):
		for column in range(maxi(int(from.x), 0), mini(int(to.x), columns)):
			if (area.position + Vector2(column + 0.5, row + 0.5) * FLOOR_CELL).distance_to(point) <= radius:
				near.append(row * columns + column)
	return near
