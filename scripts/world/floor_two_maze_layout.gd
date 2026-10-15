extends RefCounted
## The single XZ plan used by buildings, collision, the phone and the journey.

const CELL_SIZE := 8.0
const PASSAGE_WIDTH := 2.8
const GRID_SIZE := Vector2i(13, 13)
const BOUNDS := Rect2(-52.0, -52.0, 104.0, 104.0)
const ROWS := [
	"#############",
	"###########.#",
	"###########.#",
	"#####.....#.#",
	"#####.###.#.#",
	"#####.#...#.#",
	"#####.#.#.#.#",
	"#.....#...#.#",
	"#.#.#####.#.#",
	"#.#...###...#",
	"#.###.#######",
	"#.###...#####",
	"#############",
]
const PRIMARY_CORNERS := [Vector2i(1, 11), Vector2i(1, 7), Vector2i(5, 7), Vector2i(5, 3), Vector2i(9, 3), Vector2i(9, 9), Vector2i(11, 9), Vector2i(11, 1)]
const SPAWN_CELL := Vector2i(1, 11)
const WAYFINDER_CELL := Vector2i(1, 9)
const CARTOGRAPHER_CELL := Vector2i(7, 3)
const TURN_CELLS := [Vector2i(1, 7), Vector2i(5, 7)]
const EXIT_CELL := Vector2i(11, 1)


static func data() -> Dictionary:
	return build()


static func get_data(height_sampler: Callable = Callable()) -> Dictionary:
	return build(height_sampler)


static func build(height_sampler: Callable = Callable()) -> Dictionary:
	var walkable_cells: Array[Vector2i] = []
	var buildings: Array[Dictionary] = []
	for z in GRID_SIZE.y:
		for x in GRID_SIZE.x:
			var cell := Vector2i(x, z)
			if is_walkable(cell):
				walkable_cells.append(cell)
			else:
				# Heights change by parcel along regular rows, not by random scatter.
				var storeys: int = [1, 2, 2, 3, 1, 4][posmod(int(x / 2) + z * 3, 6)]
				buildings.append({"id": "house_%02d_%02d" % [x, z], "cell": cell, "rect": Rect2(BOUNDS.position + Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE), "storeys": storeys, "height": 3.6 + 3.2 * float(storeys - 1)})
	var turns: Array[Vector3] = []
	for cell in TURN_CELLS:
		turns.append(point_at_cell(cell, height_sampler))
	var primary: Array[Vector3] = []
	for index in range(1, PRIMARY_CORNERS.size()):
		var cell: Vector2i = PRIMARY_CORNERS[index - 1]
		var finish: Vector2i = PRIMARY_CORNERS[index]
		var direction := Vector2i(signi(finish.x - cell.x), signi(finish.y - cell.y))
		while cell != finish:
			primary.append(point_at_cell(cell, height_sampler))
			cell += direction
	primary.append(point_at_cell(EXIT_CELL, height_sampler))
	var wayfinder := point_at_cell(WAYFINDER_CELL, height_sampler, Vector2(1.02, 0.0))
	var cartographer := point_at_cell(CARTOGRAPHER_CELL, height_sampler, Vector2(0.0, 1.02))
	return {
		"version": 1, "floor": 2, "bounds": BOUNDS, "cell_size": CELL_SIZE,
		"grid_size": GRID_SIZE, "rows": PackedStringArray(ROWS),
		"walkable_cells": walkable_cells, "buildings": buildings,
		"spawn": point_at_cell(SPAWN_CELL, height_sampler) + Vector3.UP * 0.12,
		"npcs": {"floor2_wayfinder": wayfinder, "floor2_cartographer": cartographer},
		"turn_points": turns, "exit_position": point_at_cell(EXIT_CELL, height_sampler),
		"primary_route": primary,
		"gatehouse_cells": [WAYFINDER_CELL, CARTOGRAPHER_CELL],
		"blocking_rects": passage_blocking_rects(WAYFINDER_CELL, false) + passage_blocking_rects(CARTOGRAPHER_CELL, true),
	}


static func passage_blocking_rects(cell: Vector2i, east_west: bool) -> Array[Rect2]:
	var center3 := point_at_cell(cell)
	var center := Vector2(center3.x, center3.z)
	var wall_width := (CELL_SIZE - PASSAGE_WIDTH) * 0.5
	var result: Array[Rect2] = []
	if east_west:
		result.append(Rect2(center - Vector2.ONE * CELL_SIZE * 0.5, Vector2(CELL_SIZE, wall_width)))
		result.append(Rect2(center + Vector2(-CELL_SIZE * 0.5, PASSAGE_WIDTH * 0.5), Vector2(CELL_SIZE, wall_width)))
	else:
		result.append(Rect2(center - Vector2.ONE * CELL_SIZE * 0.5, Vector2(wall_width, CELL_SIZE)))
		result.append(Rect2(center + Vector2(PASSAGE_WIDTH * 0.5, -CELL_SIZE * 0.5), Vector2(wall_width, CELL_SIZE)))
	return result


static func is_walkable(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_SIZE.x and cell.y < GRID_SIZE.y and ROWS[cell.y][cell.x] == "."


static func world_to_cell(point: Vector3) -> Vector2i:
	return Vector2i((Vector2(point.x, point.z) - BOUNDS.position).floor() / CELL_SIZE) if BOUNDS.has_point(Vector2(point.x, point.z)) else Vector2i(-1, -1)


static func point_at_cell(cell: Vector2i, height_sampler: Callable = Callable(), offset := Vector2.ZERO) -> Vector3:
	var flat := BOUNDS.position + (Vector2(cell) + Vector2.ONE * 0.5) * CELL_SIZE + offset
	return point_at(flat, height_sampler)


static func point_at(flat: Vector2, height_sampler: Callable = Callable()) -> Vector3:
	var height := float(height_sampler.call(flat.x, flat.y)) if height_sampler.is_valid() else 0.0
	return Vector3(flat.x, height, flat.y)


static func probe(point: Vector3, height_sampler: Callable = Callable()) -> Dictionary:
	var cell := world_to_cell(point)
	var walkable := is_walkable(cell)
	if cell == WAYFINDER_CELL or cell == CARTOGRAPHER_CELL:
		for wall in passage_blocking_rects(cell, cell == CARTOGRAPHER_CELL):
			if wall.has_point(Vector2(point.x, point.z)):
				walkable = false
	var checkpoint := ""
	for index in TURN_CELLS.size():
		if cell == TURN_CELLS[index]:
			checkpoint = "turn_%d" % (index + 1)
	return {"inside": BOUNDS.has_point(Vector2(point.x, point.z)), "walkable": walkable, "cell": cell, "cell_key": "%d:%d" % [cell.x, cell.y], "checkpoint": checkpoint, "ground_height": point_at(Vector2(point.x, point.z), height_sampler).y}


static func nearest_walkable(point: Vector3, height_sampler: Callable = Callable(), inset := 0.48) -> Vector3:
	var cell := world_to_cell(point)
	var margin := clampf(inset, 0.42, 2.0)
	var flat := Vector2(point.x, point.z)
	var best := Vector2.ZERO
	var best_distance := INF
	for z in GRID_SIZE.y:
		for x in GRID_SIZE.x:
			var candidate_cell := Vector2i(x, z)
			if not is_walkable(candidate_cell):
				continue
			var center := Vector2(point_at_cell(candidate_cell).x, point_at_cell(candidate_cell).z)
			var half := Vector2.ONE * (CELL_SIZE * 0.5 - margin)
			# These two roofed entrance rooms have 2.8 m clear central passages.
			if candidate_cell == WAYFINDER_CELL:
				half.x = PASSAGE_WIDTH * 0.5 - minf(margin, 0.65)
			elif candidate_cell == CARTOGRAPHER_CELL:
				half.y = PASSAGE_WIDTH * 0.5 - minf(margin, 0.65)
			var candidate := flat.clamp(center - half, center + half)
			var distance := candidate.distance_squared_to(flat)
			if distance < best_distance:
				best_distance = distance
				best = candidate
			if candidate_cell == cell and is_zero_approx(distance):
				break
	return point_at(best, height_sampler) + Vector3.UP * 0.12
