extends RefCounted
## The single XZ plan used by buildings, collision, the phone and the journey.

const CELL_SIZE := 8.0
const PASSAGE_WIDTH := 2.8
const GRID_SIZE := Vector2i(25, 25)
const BOUNDS := Rect2(-100.0, -100.0, 200.0, 200.0)
const NORMAL_ONLY_LAYER := 1 << 18
const XRAY_RENDER_LAYER := 1 << 19
const ROWS := [
	"#########################",
	"#####...###...###########",
	"#######.###.#.###########",
	"#####.#.........###.#####",
	"#####.###.#####.###.#####",
	"#####...#...###.#...#####",
	"#######.#.#.###.#.#######",
	"###.......#.###.......###",
	"###.###############.#.###",
	"###...###...###...#...###",
	"###.#.###.#.###.#.###.###",
	"#...#.#...........###...#",
	"#.#####.#####.###.###.#.#",
	"#...#...#####...#.###...#",
	"#.###.#.#######.#.###.###",
	"#...#.#.........#.....###",
	"#####.###.#.#.#####.#####",
	"###...###...#.###...#####",
	"#############.###.#######",
	"#####.........###...#####",
	"#####.#.#################",
	"###...#...###############",
	"#####.###################",
	"#####.###################",
	"#########################",
]
# Fixed topology keeps the map-giving first NPC close to the entrance, then
# teaches perception, a concealed street, and the exit. Side loops keep that order.
const PRIMARY_CORNERS := [Vector2i(5, 23), Vector2i(5, 19), Vector2i(13, 19), Vector2i(13, 15), Vector2i(7, 15), Vector2i(7, 11), Vector2i(17, 11), Vector2i(17, 15), Vector2i(21, 15), Vector2i(21, 7), Vector2i(15, 7), Vector2i(15, 3), Vector2i(9, 3), Vector2i(9, 7), Vector2i(3, 7), Vector2i(3, 11), Vector2i(1, 11), Vector2i(1, 15), Vector2i(3, 15)]
const SPAWN_CELL := Vector2i(5, 23)
const WAYFINDER_CELL := Vector2i(5, 21)
const CARTOGRAPHER_CELL := Vector2i(11, 19)
const TURN_CELLS := [Vector2i(5, 19), Vector2i(9, 19)]
const XRAY_INTRO_CELL := Vector2i(13, 17)
const HIDDEN_PATH_CELL := Vector2i(15, 5)
const HIDDEN_WALL_CELL := Vector2i(17, 9)
const EXIT_CELL := Vector2i(3, 15)


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
			elif _has_road_neighbor(cell):
				buildings.append(residence_at(cell))
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
	var differences := _xray_differences(height_sampler)
	var normal_blocking := passage_blocking_rects(WAYFINDER_CELL, false) + passage_blocking_rects(CARTOGRAPHER_CELL, true)
	var targets: Array[Dictionary] = []
	for difference: Dictionary in differences:
		if difference.normal_visible:
			normal_blocking.append(difference.rect)
		if not str(difference.observation_id).is_empty():
			targets.append({"id": difference.observation_id, "position": difference.observation_point, "max_distance": difference.max_observe_distance, "required_previous": "" if difference.observation_id == "xray_intro" else "xray_intro"})
	var exit_target := point_at_cell(EXIT_CELL, height_sampler, Vector2(0, -3.5)) + Vector3.UP * 1.45
	targets.append({"id": "exit", "position": exit_target, "max_distance": 9.0, "required_previous": "hidden_path"})
	return {
		# Only the perceived facades changed; keep the physical-map version so
		# existing exploration saves survive this purely visual revision.
		"version": 2, "floor": 2, "bounds": BOUNDS, "cell_size": CELL_SIZE,
		"grid_size": GRID_SIZE, "rows": PackedStringArray(ROWS),
		"normal_rows": PackedStringArray(ROWS), "normal_blocking_rects": normal_blocking,
		"xray_differences": differences, "xray_targets": targets,
		"walkable_cells": walkable_cells, "buildings": buildings,
		"spawn": point_at_cell(SPAWN_CELL, height_sampler) + Vector3.UP * 0.12,
		"npcs": {"floor2_wayfinder": wayfinder, "floor2_cartographer": cartographer},
		"turn_points": turns, "exit_position": point_at_cell(EXIT_CELL, height_sampler),
		"primary_route": primary,
		"gatehouse_cells": [WAYFINDER_CELL, CARTOGRAPHER_CELL],
		"blocking_rects": physical_blocking_rects(),
	}


static func _has_road_neighbor(cell: Vector2i) -> bool:
	# Only frontage parcels surround the clipped road network. The unoccupied
	# corners of the 200 m bounding square lie beyond the irregular terrain disc.
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if is_walkable(cell + offset):
			return true
	return false


static func building_rect(cell: Vector2i) -> Rect2:
	# Three perimeter lots keep their full street frontage but shallow backs so
	# even the cornice remains supported by the original irregular terrain disc.
	if cell == Vector2i(5, 0):
		return Rect2(-60, -95, 8, 3)
	if cell == Vector2i(4, 1):
		return Rect2(-63, -92, 3, 8)
	if cell == Vector2i(5, 24):
		return Rect2(-60, 92, 8, 4)
	return Rect2(BOUNDS.position + Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE)


static func residence_at(cell: Vector2i) -> Dictionary:
	# Both solid neighbours and concealed passages use this same parcel grammar.
	var storeys: int = [1, 2, 2, 3, 1, 4][posmod(int(cell.x / 2) + cell.y * 3, 6)]
	return {"id": "house_%02d_%02d" % [cell.x, cell.y], "cell": cell, "rect": building_rect(cell), "storeys": storeys, "height": 3.6 + 3.2 * float(storeys - 1)}


static func hidden_wall_rect() -> Rect2:
	var point := point_at_cell(HIDDEN_WALL_CELL)
	# A half-width partition on a side loop leaves a four-metre route around it.
	return Rect2(Vector2(point.x - 4.0, point.z - 0.18), Vector2(4.0, 0.36))


static func physical_blocking_rects() -> Array[Rect2]:
	var result := passage_blocking_rects(WAYFINDER_CELL, false) + passage_blocking_rects(CARTOGRAPHER_CELL, true)
	result.append(hidden_wall_rect())
	return result


static func _xray_differences(height_sampler: Callable) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in [{"id": "XrayIntroFacade", "observation": "xray_intro", "cell": XRAY_INTRO_CELL}, {"id": "HiddenPathFacade", "observation": "hidden_path", "cell": HIDDEN_PATH_CELL}]:
		var point := point_at_cell(entry.cell, height_sampler)
		var residence := residence_at(entry.cell)
		residence.id = entry.id
		var frontage := Vector2(point.x, point.z + CELL_SIZE * 0.5 + 0.14)
		result.append({"id": entry.id, "observation_id": entry.observation, "kind": "false_residence", "rect": residence.rect, "height": residence.height, "residence": residence, "normal_visible": true, "xray_visible": false, "solid": false, "observation_point": point_at(frontage, height_sampler) + Vector3.UP * 1.45, "max_observe_distance": 9.0})
	result.append({"id": "XraySolidPartition", "observation_id": "", "kind": "hidden_solid_wall", "rect": hidden_wall_rect(), "height": 2.8, "normal_visible": false, "xray_visible": true, "solid": true, "observation_point": point_at_cell(HIDDEN_WALL_CELL, height_sampler) + Vector3.UP * 1.45, "max_observe_distance": 9.0})
	return result


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
	for wall in physical_blocking_rects():
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
			if candidate_cell == HIDDEN_WALL_CELL:
				var forbidden := hidden_wall_rect().grow(margin)
				if forbidden.has_point(candidate):
					var alternatives: Array[Vector2] = [Vector2(candidate.x, forbidden.position.y - 0.01), Vector2(candidate.x, forbidden.end.y + 0.01), Vector2(forbidden.end.x + 0.01, candidate.y)]
					var nearest_distance := INF
					for option in alternatives:
						option = option.clamp(center - half, center + half)
						if not forbidden.has_point(option) and option.distance_squared_to(flat) < nearest_distance:
							candidate = option
							nearest_distance = option.distance_squared_to(flat)
			var distance := candidate.distance_squared_to(flat)
			if distance < best_distance:
				best_distance = distance
				best = candidate
			if candidate_cell == cell and is_zero_approx(distance):
				break
	return point_at(best, height_sampler) + Vector3.UP * 0.12
