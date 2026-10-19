class_name ExplorationMapState
extends RefCounted

const RESOLUTION := 2.0
const REVEAL_RADIUS := 4.0
const MAX_AXIS_CELLS := 256
const RASTER_VERSION := 2

var _bounds := Rect2()
var _columns := 0
var _rows := 0
var _walkable := PackedByteArray()
var _explored := PackedByteArray()
var _walkable_count := 0
var _explored_road_count := 0
var _layout_id := ""
var _layout_version := 0
var _layout_fingerprint := ""


func configure(layout: Dictionary, saved: Dictionary = {}) -> void:
	_reset()
	var bounds_value: Variant = layout.get("bounds")
	var grid_value: Variant = layout.get("grid_size")
	var source_rows: Variant = layout.get("rows")
	if not bounds_value is Rect2 or not grid_value is Vector2i or not (source_rows is Array or source_rows is PackedStringArray):
		return
	var bounds: Rect2 = bounds_value
	var grid: Vector2i = grid_value
	var coarse_size := _number(layout.get("cell_size"), 0.0)
	if not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or coarse_size < RESOLUTION:
		return
	if bounds.size.x > MAX_AXIS_CELLS * RESOLUTION or bounds.size.y > MAX_AXIS_CELLS * RESOLUTION or coarse_size > MAX_AXIS_CELLS * RESOLUTION:
		return
	if grid.x <= 0 or grid.y <= 0 or grid.x > MAX_AXIS_CELLS or grid.y > MAX_AXIS_CELLS or source_rows.size() != grid.y:
		return
	var subdivision := int(round(coarse_size / RESOLUTION))
	if subdivision < 1 or not is_equal_approx(coarse_size, subdivision * RESOLUTION):
		return
	if not bounds.size.is_equal_approx(Vector2(grid) * coarse_size):
		return
	var fine_size := grid * subdivision
	if fine_size.x > MAX_AXIS_CELLS or fine_size.y > MAX_AXIS_CELLS:
		return
	var checked_rows := PackedStringArray()
	for row_value in source_rows:
		if not row_value is String or row_value.length() != grid.x:
			return
		for character in row_value:
			if character != "#" and character != ".":
				return
		checked_rows.append(row_value)
	var source_blockers: Variant = layout.get("blocking_rects", [])
	if not source_blockers is Array or source_blockers.size() > MAX_AXIS_CELLS:
		return
	var checked_blockers: Array[Rect2] = []
	for blocker_value in source_blockers:
		if not blocker_value is Rect2:
			return
		var blocker: Rect2 = blocker_value
		if not blocker.position.is_finite() or not blocker.size.is_finite() or blocker.size.x <= 0.0 or blocker.size.y <= 0.0 or not bounds.encloses(blocker):
			return
		checked_blockers.append(blocker)
	var version := _integer(layout.get("version", 1), 0)
	var id_value: Variant = layout.get("id", "floor_%d" % _integer(layout.get("floor", 2), 2))
	if version < 1 or not id_value is String or id_value.is_empty() or id_value.length() > 128:
		return
	_bounds = bounds
	_columns = fine_size.x
	_rows = fine_size.y
	_layout_id = id_value
	_layout_version = version
	_layout_fingerprint = var_to_bytes([RASTER_VERSION, bounds, coarse_size, checked_rows, checked_blockers]).hex_encode().sha256_text()
	_walkable.resize(_columns * _rows)
	_explored.resize(_columns * _rows)
	_explored.fill(0)
	for y in _rows:
		for x in _columns:
			var is_road := checked_rows[int(y / subdivision)].substr(int(x / subdivision), 1) == "."
			_walkable[y * _columns + x] = 1 if is_road else 0
			if is_road:
				_walkable_count += 1
	for blocker in checked_blockers:
		var first := Vector2i(((blocker.position - _bounds.position) / RESOLUTION).floor())
		var last := Vector2i(((blocker.end - _bounds.position) / RESOLUTION).ceil()).min(Vector2i(_columns, _rows))
		var thin_cell := Vector2i(((blocker.get_center() - _bounds.position) / RESOLUTION).floor())
		for y in range(first.y, last.y):
			for x in range(first.x, last.x):
				var center := _bounds.position + Vector2(x + 0.5, y + 0.5) * RESOLUTION
				var index := y * _columns + x
				# A thin facade can straddle two cells without covering either
				# center. Give its thin axis one deterministic cell; retain center
				# sampling on thick axes so 2.8m entrance passages stay open.
				var covered_x := x == thin_cell.x if blocker.size.x < RESOLUTION else center.x >= blocker.position.x and center.x < blocker.end.x
				var covered_y := y == thin_cell.y if blocker.size.y < RESOLUTION else center.y >= blocker.position.y and center.y < blocker.end.y
				if _walkable[index] == 1 and covered_x and covered_y:
					_walkable[index] = 0
					_walkable_count -= 1
	_restore(saved)


func reveal_at(world_position: Vector3) -> bool:
	if _columns == 0 or not world_position.is_finite():
		return false
	var world_xz := Vector2(world_position.x, world_position.z)
	if not _bounds.has_point(world_xz):
		return false
	var local := (world_xz - _bounds.position) / RESOLUTION
	var origin := Vector2i(floori(local.x), floori(local.y))
	if not _road_at(origin):
		return false
	var radius := REVEAL_RADIUS / RESOLUTION
	var min_x := maxi(0, floori(local.x - radius))
	var max_x := mini(_columns - 1, floori(local.x + radius))
	var min_y := maxi(0, floori(local.y - radius))
	var max_y := mini(_rows - 1, floori(local.y + radius))
	var changed := false
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var index := y * _columns + x
			if _explored[index] == 1 or local.distance_squared_to(Vector2(x + 0.5, y + 0.5)) > radius * radius:
				continue
			if not _has_sight(local, Vector2i(x, y)):
				continue
			_explored[index] = 1
			_explored_road_count += int(_walkable[index])
			changed = true
	return changed


func snapshot(position: Vector3, yaw_radians: float, active: bool = true) -> Dictionary:
	var player_uv := Vector2.ZERO
	var located := false
	if _columns > 0 and position.is_finite():
		var xz := Vector2(position.x, position.z)
		player_uv = ((xz - _bounds.position) / _bounds.size).clamp(Vector2.ZERO, Vector2.ONE)
		if _bounds.has_point(xz):
			var cell := Vector2i(floori((xz.x - _bounds.position.x) / RESOLUTION), floori((xz.y - _bounds.position.y) / RESOLUTION))
			located = _road_at(cell)
	return {
		"columns": _columns, "rows": _rows,
		"explored": _explored.duplicate(), "walkable": _walkable.duplicate(),
		"player_uv": player_uv,
		"heading_radians": wrapf(yaw_radians, -PI, PI) if is_finite(yaw_radians) else 0.0,
		"active": active and located,
		"explored_ratio": float(_explored_road_count) / _walkable_count if _walkable_count > 0 else 0.0,
	}


func to_save_data() -> Dictionary:
	return {
		"layout_id": _layout_id, "layout_version": _layout_version,
		"layout_fingerprint": _layout_fingerprint,
		"columns": _columns, "rows": _rows, "resolution": RESOLUTION,
		"explored": _explored.duplicate(),
	}


func _restore(saved: Dictionary) -> void:
	if saved.get("layout_id") != _layout_id or _integer(saved.get("layout_version"), -1) != _layout_version:
		return
	if _integer(saved.get("columns"), -1) != _columns or _integer(saved.get("rows"), -1) != _rows:
		return
	if not is_equal_approx(_number(saved.get("resolution", RESOLUTION), 0.0), RESOLUTION):
		return
	if saved.get("layout_fingerprint", _layout_fingerprint) != _layout_fingerprint:
		return
	var mask: Variant = saved.get("explored")
	if not (mask is PackedByteArray or mask is Array) or mask.size() != _columns * _rows:
		return
	for value in mask:
		if _integer(value, -1) not in [0, 1]:
			return
	for index in mask.size():
		_explored[index] = int(mask[index])
		if _explored[index] == 1 and _walkable[index] == 1:
			_explored_road_count += 1


func _has_sight(start: Vector2, target: Vector2i) -> bool:
	var cell := Vector2i(floori(start.x), floori(start.y))
	if cell == target:
		return true
	var direction := Vector2(target) + Vector2(0.5, 0.5) - start
	var step := Vector2i(int(signf(direction.x)), int(signf(direction.y)))
	var delta_x := absf(1.0 / direction.x) if step.x != 0 else INF
	var delta_y := absf(1.0 / direction.y) if step.y != 0 else INF
	var edge_x := (float(cell.x + (1 if step.x > 0 else 0)) - start.x) / direction.x if step.x != 0 else INF
	var edge_y := (float(cell.y + (1 if step.y > 0 else 0)) - start.y) / direction.y if step.y != 0 else INF
	for _crossing in range(_columns + _rows + 2):
		if is_equal_approx(edge_x, edge_y):
			# Crossing an exact corner must not see through either blocking wall.
			if not _road_at(cell + Vector2i(step.x, 0)) or not _road_at(cell + Vector2i(0, step.y)):
				return false
			cell += step
			edge_x += delta_x
			edge_y += delta_y
		elif edge_x < edge_y:
			cell.x += step.x
			edge_x += delta_x
		else:
			cell.y += step.y
			edge_y += delta_y
		# The first wall surface is known; the cells behind it are not.
		if cell == target:
			return true
		if not _road_at(cell):
			return false
	return false


func _road_at(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _columns and cell.y < _rows and _walkable[cell.y * _columns + cell.x] == 1


func _reset() -> void:
	_bounds = Rect2()
	_columns = 0
	_rows = 0
	_walkable = PackedByteArray()
	_explored = PackedByteArray()
	_walkable_count = 0
	_explored_road_count = 0
	_layout_id = ""
	_layout_version = 0
	_layout_fingerprint = ""


static func _number(value: Variant, fallback: float) -> float:
	if (value is int or value is float) and is_finite(float(value)):
		return float(value)
	return fallback


static func _integer(value: Variant, fallback: int) -> int:
	var number := _number(value, NAN)
	if is_finite(number) and number >= -2147483648.0 and number <= 2147483647.0 and number == floor(number):
		return int(number)
	return fallback
